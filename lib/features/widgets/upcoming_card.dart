import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/providers/medication_provider.dart';
import 'package:dose_vault/core/utils/medication_utils.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/core/widgets/pill_chip.dart';
import 'package:dose_vault/features/widgets/action_button.dart';
import 'package:dose_vault/features/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium Bento Box upcoming medication card.
///
/// If the scheduled time has passed, the action buttons are replaced
/// with an "Overdue" pill chip so the user sees it at a glance.
class UpcomingCard extends ConsumerWidget {
  final Medication medication;
  final VoidCallback onDelete;
  const UpcomingCard({
    required this.medication,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    DateTime scheduledTime = medication.scheduledDateTime;

    // ── 1. THE CINDERELLA FIX (Logical Day) ──
    // Pull late-night PM pills back to "Yesterday"
    if (now.hour < 3 && scheduledTime.hour > 12) {
      scheduledTime = scheduledTime.subtract(const Duration(days: 1));
    }

    // ── 2. THE TIME TRAVEL FIX (Creation Boundary) ──
    // If the calculated time happened BEFORE the user even created this medication profile,
    // they cannot be overdue for it. We must push it forward to its first real occurrence.
    if (scheduledTime.isBefore(medication.createdAt)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // STATE 1: Pending (Time hasn't arrived yet)
    final isPending = scheduledTime.isAfter(now);

    // STATE 3: Overdue (15 minutes late)
    final isOverdue = scheduledTime.isBefore(
      now.subtract(const Duration(minutes: 15)),
    );

    return Dismissible(
      key: ValueKey('upcoming_${medication.id}'),
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
        child: Column(
          children: [
            // ── Top row: icon + title + time ──
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: AppColors.primaryDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: CustomText(
                              medication.name,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: CustomText(
                              dosageLabel(medication),
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PillChip(
                            label: fmt(medication.scheduledTime),
                            leadingIcon: Icons.access_time,
                            fontSize: 12,
                            textColor: AppColors.textPrimary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 8),
                            PillChip(
                              label: 'Pending',
                              leadingIcon: Icons.hourglass_empty,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              // statusColor: AppColors.primary,
                              // iconColor: AppColors.primary,
                            ),
                          ],
                          if (!isPending && isOverdue) ...[
                            const SizedBox(width: 8),
                            const PillChip(
                              label: 'Overdue',
                              leadingIcon: Icons.access_time_rounded,
                              backgroundColor: Color(0xFFFFF3E0),
                              textColor: AppColors.warning,
                              iconColor: AppColors.warning,
                              // statusColor: AppColors.warning,
                              // iconColor: AppColors.warning,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── BOTTOM SECTION: The 4-State Machine ──

            // If it's NOT pending, the time has arrived. Show the action buttons!
            if (!isPending) ...[
              const SizedBox(height: 14),
              // The buttons ALWAYS appear as long as it's not Pending
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      'Skipped',
                      true,
                      () => ref
                          .read(doseLogListProvider.notifier)
                          .logDose(
                            medicationId: medication.id,
                            status: 'skipped',
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton('Taken', false, () {
                      HapticFeedback.mediumImpact();
                      ref
                          .read(doseLogListProvider.notifier)
                          .logDose(
                            medicationId: medication.id,
                            status: 'taken',
                          );
                    }),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
