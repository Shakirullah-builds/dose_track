import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/features/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Premium Bento Box history tile.
///
/// Layout:
/// ┌──────────────────────────────────────────────┐
/// │  [✓]   MedName               Scheduled 3 PM  │
/// │         250mg                  Taken at 3:02  │
/// └──────────────────────────────────────────────┘
///
/// Uses premiumCardDecoration for consistent radius/shadow with home cards.
class HistoryTile extends StatelessWidget {
  final DoseLog log;
  final Medication? medication;
  final VoidCallback onDelete;
  const HistoryTile({
    required this.log,
    this.medication,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isTaken = log.status == 'taken';
    final name = medication?.name ?? 'Unknown';
    final dosageStr = medication != null
        ? '${medication!.dosage.truncateToDouble() == medication!.dosage ? medication!.dosage.toInt() : medication!.dosage}${medication!.unit}'
        : '';
    final scheduledStr = medication != null
        ? _formatTime(medication!.scheduledTime)
        : '';
    final actionStr = log.actionTime != null
        ? DateFormat('h:mm a').format(log.actionTime!)
        : '';

    return Dismissible(
      key: ValueKey('history_${log.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.missed,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.undo, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: premiumCardDecoration,
        child: Row(
          children: [
            // Left — circular status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTaken
                    ? AppColors.taken.withValues(alpha: 0.12)
                    : AppColors.missed.withValues(alpha: 0.1),
              ),
              child: Icon(
                isTaken
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_outline,
                color: isTaken ? AppColors.taken : AppColors.skippedText,
                size: 22,
              ),
            ),

            const SizedBox(width: 14),

            // Center — name + dosage
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    name,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dosageStr.isNotEmpty)
                    CustomText(
                      dosageStr,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Right — scheduled time + action time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (scheduledStr.isNotEmpty)
                  CustomText(
                    scheduledStr,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                if (actionStr.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomText(
                        '${isTaken ? "Taken at" : "Skipped at"}: $actionStr',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      if (log.actionTime != null && log.actionTime!.hour < 3) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.nightlight_round,
                          size: 11,
                          color: Colors.amber,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String t) {
    try {
      final p = t.split(':');
      final d = DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1]));
      return DateFormat('h:mm a').format(d);
    } catch (_) {
      return t;
    }
  }
}
