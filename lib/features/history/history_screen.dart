import 'package:dose_vault/core/widgets/custom_empty_state.dart';
import 'package:dose_vault/core/services/pdf_export_service.dart';
import 'package:dose_vault/features/widgets/date_group.dart';
import 'package:dose_vault/core/widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/providers/medication_provider.dart';
import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/services/supabase_sync_service.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/core/widgets/custom_text_field.dart';

/// History screen — shows all dose logs grouped by date,
/// with search-by-name and filter-by-status controls.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'taken', 'skipped'

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allLogs = ref.watch(allDoseLogsProvider);
    final medications = ref.watch(medicationListProvider);
    final isSyncing = ref.watch(isInitialSyncingProvider);

    // Build a lookup map for medication names
    final medMap = <String, Medication>{};
    for (final m in medications) {
      medMap[m.id] = m;
    }

    // ── APPLY SEARCH + FILTER ──
    final filteredLogs = allLogs.where((log) {
      // 1. Filter by status
      if (_filterStatus != 'all' && log.status != _filterStatus) return false;

      // 2. Filter by medication name
      if (_searchQuery.isNotEmpty) {
        final med = medMap[log.medicationId];
        if (med == null) return false;
        if (!med.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();

    // Group filtered logs by date (descending)
    final grouped = <DateTime, List<DoseLog>>{};
    for (final log in filteredLogs) {
      final key = DateTime(log.date.year, log.date.month, log.date.day);
      grouped.putIfAbsent(key, () => []).add(log);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final hasAnyHistory = allLogs.isNotEmpty;

    // Pre-compute stats for the PDF (use ALL logs, not filtered)
    final totalTaken = allLogs.where((l) => l.status == 'taken').length;
    final totalSkipped = allLogs.where((l) => l.status == 'skipped').length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.scaffoldBg,
        centerTitle: true,
        title: const CustomText(
          'History',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        elevation: 0,
        // ── Export PDF button (only visible when there IS history) ────
        actions: hasAnyHistory
            ? [
                IconButton(
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Export Report',
                  onPressed: () async {
                    try {
                      await PdfExportService.generateAndShareReport(
                        logs: allLogs,
                        medMap: medMap,
                        totalTaken: totalTaken,
                        totalSkipped: totalSkipped,
                      );
                    } catch (e) {
                      debugPrint('Failed to generate report: $e');
                      if (context.mounted) {
                        TopToast.showError(
                          context,
                          'Failed to generate report: $e',
                        );
                      }
                    }
                  },
                ),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SEARCH & FILTER HEADER (only when history exists) ──
            if (hasAnyHistory) ...[
              _buildSearchBar(),
              _buildFilterChips(),
            ],

            Expanded(
              child: sortedDates.isEmpty
                  ? (isSyncing
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                CustomText('Restoring data...'),
                              ],
                            ),
                          )
                        : hasAnyHistory
                            // Filtered results are empty, but history exists
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 56,
                                      color: AppColors.textHint.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const CustomText(
                                      'No matching results',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 4),
                                    const CustomText(
                                      'Try a different search or filter.',
                                      fontSize: 13,
                                      color: AppColors.textHint,
                                    ),
                                  ],
                                ),
                              )
                            // Genuinely no history at all
                            : const CustomEmptyState(
                                title: 'No History Yet',
                                subtitle:
                                    'Your medication history will appear here once you log a dose.',
                                icon: Icons.history_rounded,
                              ))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        final date = sortedDates[index];
                        final logs = grouped[date]!;
                        return DateGroup(
                          date: date,
                          logs: logs,
                          medMap: medMap,
                          // HOISTED LOGIC: The delete action now runs in the top-level screen!
                          onLogDeleted: (DoseLog deletedLog) {
                            ref
                                .read(doseLogListProvider.notifier)
                                .deleteLog(deletedLog.id);

                            TopToast.showWithUndo(
                              context,
                              message: 'Dose log removed.',
                              onUndo: () {
                                ref
                                    .read(doseLogListProvider.notifier)
                                    .restoreLog(deletedLog);
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SEARCH BAR ──
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CustomTextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        hintText: 'Search by medication name...',
        hintStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textHint,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
          size: 22,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                  setState(() => _searchQuery = '');
                },
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.cardBg,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  // ── FILTER CHIPS ──
  Widget _buildFilterChips() {
    const filters = [
      {'key': 'all', 'label': 'All'},
      {'key': 'taken', 'label': 'Taken'},
      {'key': 'skipped', 'label': 'Skipped'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filterStatus == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: CustomText(
                f['label']!,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _filterStatus = f['key']!);
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: 1,
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }
}
