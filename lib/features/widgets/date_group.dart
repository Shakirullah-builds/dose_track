import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/services/hive_service.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/features/widgets/history_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DateGroup extends ConsumerWidget {
  final DateTime date;
  final List<DoseLog> logs;
  final Map<String, Medication> medMap;
  final Function(DoseLog) onLogDeleted;

  const DateGroup({
    super.key,
    required this.date,
    required this.logs,
    required this.medMap,
    required this.onLogDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = _isToday(date);
    final isYesterday = _isYesterday(date);
    final label = isToday
        ? 'Today'
        : (isYesterday ? 'Yesterday' : DateFormat('EEEE, MMM d').format(date));
    final takenCount = logs.where((l) => l.status == 'taken').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText(
                label,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              CustomText(
                '$takenCount/${logs.length} taken',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        ...logs.map((log) {
          final med = medMap[log.medicationId];
          return HistoryTile(
            log: log,
            medication: med,
            onDelete: () => onLogDeleted(log),
          );
        }),
      ],
    );
  }

  bool _isToday(DateTime d) {
    final logicalToday = HiveService.getLogicalDate(DateTime.now());
    return d.year == logicalToday.year &&
        d.month == logicalToday.month &&
        d.day == logicalToday.day;
  }

  bool _isYesterday(DateTime d) {
    final logicalToday = HiveService.getLogicalDate(DateTime.now());
    final logicalYesterday = logicalToday.subtract(const Duration(days: 1));
    return d.year == logicalYesterday.year &&
        d.month == logicalYesterday.month &&
        d.day == logicalYesterday.day;
  }
}