import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/utils/medication_utils.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/features/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Premium Bento Box completed card.
///
/// Same data contract as before but upgraded visuals:
/// rounded-24, premium shadow, and the green/grey icon on the left.
class CompletedCard extends StatelessWidget {
  final Medication medication;
  final DoseLog doseLog;
  final VoidCallback onDelete;
  const CompletedCard({
    super.key,
    required this.medication,
    required this.doseLog,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isTaken = doseLog.status == 'taken';
    final actionStr = doseLog.actionTime != null
        ? DateFormat('h:mm a').format(doseLog.actionTime!)
        : '';

    return Dismissible(
      key: ValueKey('completed_${medication.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.missed,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: premiumCardDecoration,
        child: Row(
          children: [
            // Status icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTaken
                    ? AppColors.taken.withValues(alpha: 0.12)
                    : AppColors.skipped.withValues(alpha: 0.5),
              ),
              child: Icon(
                isTaken
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_rounded,
                color: isTaken ? AppColors.taken : AppColors.skippedText,
                size: 24,
              ),
            ),

            const SizedBox(width: 14),

            // Name + dosage
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    medication.name,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary.withValues(alpha: 0.7),
                    decoration: isTaken ? TextDecoration.lineThrough : null,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  CustomText(
                    dosageLabel(medication),
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Time + action label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CustomText(
                  fmt(medication.scheduledTime),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withValues(alpha: 0.6),
                ),
                if (actionStr.isNotEmpty)
                  CustomText(
                    '${isTaken ? "Taken" : "Skipped"} $actionStr',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isTaken ? AppColors.taken : AppColors.skippedText,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
