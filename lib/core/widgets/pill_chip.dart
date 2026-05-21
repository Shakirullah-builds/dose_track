// lib/core/widgets/pill_chip.dart

import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

/// A reusable pill-shaped chip with optional leading/trailing icons
/// and an optional onTap callback.
///
/// Usage:
/// ```dart
/// // Time chip (leading icon, no tap)
/// PillChip(
///   label: '3:00 PM',
///   leadingIcon: Icons.access_time,
/// )
///
/// // Status chip
/// PillChip(
///   label: 'Overdue',
///   leadingIcon: Icons.access_time_rounded,
///   backgroundColor: Color(0xFFFFF3E0),
///   textColor: AppColors.warning,
///   iconColor: AppColors.warning,
/// )
///
/// // View All button (trailing icon, tappable)
/// PillChip(
///   label: 'View All',
///   trailingIcon: Icons.arrow_forward_ios,
///   onTap: () => ...,
/// )
/// ```
class PillChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double iconSize;
  final Color? iconColor;
  final VoidCallback? onTap;

  const PillChip({
    required this.label,
    this.backgroundColor = const Color(0x1F3B82F6), // primary @ 12%
    this.textColor = AppColors.primary,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w600,
    this.leadingIcon,
    this.trailingIcon,
    this.iconSize = 12,
    this.iconColor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: iconSize, color: iconColor ?? textColor),
            const SizedBox(width: 4),
          ],
          CustomText(
            label,
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: textColor,
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: iconSize, color: iconColor ?? textColor),
          ],
        ],
      ),
    );

    // Wrap with InkWell only if tappable
    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: chip,
      );
    }

    return chip;
  }
}
