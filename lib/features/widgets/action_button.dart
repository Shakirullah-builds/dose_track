import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

/// Pill-shaped action button for Taken / Skipped.
///
/// The borderRadius is 20 (pill shape as per the Bento Box spec).
/// 'Skipped' gets a neutral grey fill, 'Taken' gets a soft green fill.
class ActionButton extends StatelessWidget {
  final String label;
  final bool isSkip;
  final VoidCallback onTap;
  const ActionButton(this.label, this.isSkip, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSkip
          ? AppColors.skipped
          : AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isSkip) ...[
                const Icon(Icons.check, size: 18, color: AppColors.primaryDark),
                const SizedBox(width: 6),
              ],
              CustomText(
                label,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSkip ? AppColors.skippedText : AppColors.primaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
