import 'package:dose_tracker/features/widgets/custom_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dose_tracker/core/models/medication.dart';
import 'package:dose_tracker/core/providers/medication_provider.dart';
import 'package:dose_tracker/core/constants/app_colors.dart';

/// History screen — shows all dose logs grouped by date.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLogs = ref.watch(allDoseLogsProvider);
    final medications = ref.watch(medicationListProvider);

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
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'History',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: sortedDates.isEmpty
                  ? CustomEmptyState(
                      title: 'No history yet',
                      description: 'Your dose logs will appear here',
                      icon: Icons.history_outlined,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        final date = sortedDates[index];
                        final logs = grouped[date]!;
                        return _DateGroup(
                          date: date,
                          logs: logs,
                          medMap: medMap,
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

class _DateGroup extends ConsumerWidget {
  final DateTime date;
  final List<DoseLog> logs;
  final Map<String, Medication> medMap;

  const _DateGroup({
    required this.date,
    required this.logs,
    required this.medMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = _isToday(date);
    final label = isToday ? 'Today' : DateFormat('EEEE, MMM d').format(date);
    final takenCount = logs.where((l) => l.status == 'taken').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$takenCount/${logs.length} taken',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        ...logs.map((log) {
          final med = medMap[log.medicationId];
          return _HistoryTile(
            log: log,
            medication: med,
            onDelete: () {
              final deletedLog = log;
              ref.read(doseLogListProvider.notifier).deleteLog(deletedLog.id);

              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  content: const Text('Dose log removed.'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () {
                      ref.read(doseLogListProvider.notifier).restoreLog(deletedLog);
                    },
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _HistoryTile extends StatelessWidget {
  final DoseLog log;
  final Medication? medication;
  final VoidCallback onDelete;
  const _HistoryTile({required this.log, this.medication, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isTaken = log.status == 'taken';
    final name = medication?.name ?? 'Unknown';
    final timeStr = log.actionTime != null
        ? DateFormat('h:mm a').format(log.actionTime!)
        : '';

    return Dismissible(
      key: ValueKey('history_${log.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.missed,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.undo, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        //borderRadius: BorderRadius.circular(14),
        //border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            //padding: ,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTaken
                  ? AppColors.taken.withValues(alpha: 0.12)
                  : AppColors.missed.withValues(alpha: 0.1),
              // borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isTaken
                  ? Icons.check_circle_outline
                  : Icons.remove_circle_outline,
              color: isTaken ? AppColors.taken : AppColors.skippedText,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (medication != null)
                  Text(
                    '${medication!.dosage.truncateToDouble() == medication!.dosage ? medication!.dosage.toInt() : medication!.dosage}${medication!.unit}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isTaken ? 'Taken' : 'Skipped',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isTaken ? AppColors.taken : AppColors.skippedText,
                ),
              ),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
