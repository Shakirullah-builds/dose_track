import 'package:flutter/material.dart';
import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/custom_elevated_button.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';

class BatteryExemptionBottomSheet extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onCancel;

  const BatteryExemptionBottomSheet({
    super.key,
    required this.onEnable,
    required this.onCancel,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onEnable,
    required VoidCallback onCancel,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BatteryExemptionBottomSheet(
        onEnable: onEnable,
        onCancel: onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: AppColors.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const CustomText(
            'Never Miss a Dose',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          const SizedBox(height: 12),

          // Description
          const CustomText(
            'To ensure DoseVault can reliably alert you even when your phone is offline or locked, we need permission to run in the background.',
            fontSize: 15,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
            height: 1.5,
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.battery_charging_full_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomText(
                    "Don't worry—DoseVault is highly optimized and will not drain your battery!",
                    fontSize: 13,
                    color: Colors.green.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: CustomElevatedButton(
              label: 'Enable Reliable Alarms',
              onPressed: () {
                Navigator.pop(context); // Close bottom sheet
                onEnable(); // Trigger permission request
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); // Close bottom sheet
                onCancel(); // Proceed without permission
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const CustomText(
                'Not Now',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Padding for safe area (bottom navigation bar)
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
