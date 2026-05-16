import 'package:dose_tracker/core/constants/app_colors.dart';
import 'package:dose_tracker/core/models/medication.dart';
import 'package:dose_tracker/core/providers/medication_provider.dart';
import 'package:dose_tracker/core/utils/medication_utils.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';
import 'package:dose_tracker/features/widgets/action_button.dart';
import 'package:dose_tracker/features/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium Bento Box upcoming medication card.
///
/// Layout:
/// ┌─────────────────────────────────────────┐
/// │  [icon]  MedName              3:00 PM   │
/// │          250mg • Tablet                 │
/// │                                         │
/// │  [ Skipped ]         [ ✓ Taken ]        │
/// └─────────────────────────────────────────┘
///
/// If the scheduled time has passed, the action buttons are replaced
/// with an "Overdue" status chip so the user sees it at a glance.
class UpcomingCard extends ConsumerWidget {
  final Medication medication;
  final VoidCallback onDelete;
  const UpcomingCard({required this.medication, required this.onDelete, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = medication.scheduledDateTime.isBefore(DateTime.now());

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
                            ),
                          ),
                          CustomText(
                            fmt(medication.scheduledTime),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                      CustomText(
                        dosageLabel(medication),
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Bottom row: action buttons OR overdue chip ──
            if (isOverdue)
              _OverdueChip()
            else
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
                    child: ActionButton(
                      'Taken',
                      false,
                      () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(doseLogListProvider.notifier)
                            .logDose(
                              medicationId: medication.id,
                              status: 'taken',
                            );
                      },
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

/// Small overdue status chip — replaces action buttons when the dose time passed.
class _OverdueChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0), // soft orange
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFE65100)),
            SizedBox(width: 6),
            CustomText(
              'Overdue',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE65100),
            ),
          ],
        ),
      ),
    );
  }
}