import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/bounce_tap.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

/// Reusable full-width elevated button wrapped in BounceTap.
///
/// Why wrap in BounceTap instead of relying on ElevatedButton's built-in splash?
/// → BounceTap gives us the high-fidelity iOS spring animation + haptic
///   feedback we set up earlier. The spring overshoot feels far more premium
///   than the default Material ripple, and it's consistent across the app.
///
/// Supports an optional [isLoading] state that swaps the label for a spinner
/// and disables taps — used by the "Save Medication" flow.
class CustomElevatedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;
  final double height;
  final double fontSize;

  const CustomElevatedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 16,
    this.height = 56,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary;
    final fg = textColor ?? Colors.white;
    final disabled = isLoading || onPressed == null;

    final button = SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : CustomText(
                label,
                color: fg,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
      ),
    );

    // When disabled (loading or null onPressed), skip BounceTap
    // so the user can't trigger double-submits.
    if (disabled) return button;

    return BounceTap(
      onTap: onPressed!,
      child: AbsorbPointer(child: button),
    );
  }
}
