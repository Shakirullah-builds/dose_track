import 'package:dose_tracker/core/widgets/custom_empty_state.dart';
import 'package:dose_tracker/features/widgets/date_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dose_tracker/core/models/medication.dart';
import 'package:dose_tracker/core/providers/medication_provider.dart';
import 'package:dose_tracker/core/constants/app_colors.dart';
import 'package:dose_tracker/core/services/supabase_sync_service.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';

/// History screen — shows all dose logs grouped by date.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLogs = ref.watch(allDoseLogsProvider);
    final medications = ref.watch(medicationListProvider);
    final isSyncing = ref.watch(isInitialSyncingProvider);

    // Build a lookup map for medication names
    final medMap = <String, Medication>{};
    for (final m in medications) {
      medMap[m.id] = m;
    }

    // Group logs by date (descending)
    final grouped = <DateTime, List<DoseLog>>{};
    for (final log in allLogs) {
      final key = DateTime(log.date.year, log.date.month, log.date.day);
      grouped.putIfAbsent(key, () => []).add(log);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const CustomText(
          'History',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        elevation: 0,
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
                        : const CustomEmptyState(
                            title: 'No History Yet',
                            subtitle: 'Your medication history will appear here once you log a dose.',
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

                            final messenger = ScaffoldMessenger.of(context);
                            messenger.clearSnackBars();

                            final snackBar = SnackBar(
                              duration: const Duration(seconds: 3),
                              content: const CustomText('Dose log removed.'),
                              action: SnackBarAction(
                                label: 'UNDO',
                                onPressed: () {
                                  // Because this is inside HistoryScreen, the ref NEVER dies!
                                  ref
                                      .read(doseLogListProvider.notifier)
                                      .restoreLog(deletedLog);
                                },
                              ),
                            );

                            final controller = messenger.showSnackBar(snackBar);

                            Future.delayed(const Duration(seconds: 3), () {
                              try {
                                controller.close();
                              } catch (_) {}
                            });
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
}
