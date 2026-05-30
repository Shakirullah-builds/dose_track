import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/bounce_tap.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

/// Premium 'Bento Box' header — greeting row + hero progress card.
///
/// The old version was a single tall block with a centered ring.
/// This version splits the header into two visual "boxes":
/// 1. A greeting row (Today + date + notification bell)
/// 2. A hero card with a compact side-by-side ring + label layout
///
/// This feels more spacious and modern while keeping the same data props.
class Header extends StatelessWidget {
  final double adherence;
  final int takenCount;
  final int totalCount;
  final DateTime logicalDate;
  final VoidCallback? onBellTap;
  final bool hasMissedDoses;
  const Header({
    required this.adherence,
    required this.takenCount,
    required this.totalCount,
    required this.logicalDate,
    this.onBellTap,
    this.hasMissedDoses = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    //final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Greeting Row ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomText(
                    'Today',
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  CustomText(
                    DateFormat('EEEE, MMM d').format(logicalDate),
                    //fontWeight: FontWeight.normal,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              BounceTap(
                onTap: onBellTap ?? () {},
                child: Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    // Red badge dot — only visible when there are missed doses
                    if (hasMissedDoses)
                      Positioned(
                        top: 6,
                        right: 8,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.scaffoldBg,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Hero Progress Card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: premiumCardDecoration.copyWith(
              color: AppColors.primary,
            ),
            child: Row(
              children: [
                // Left — Circular ring
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularPercentIndicator(
                    rotateLinearGradient: true,
                    radius: 40,
                    lineWidth: 8,
                    percent: adherence.clamp(0.0, 1.0),
                    center: CustomText(
                      '${(adherence.clamp(0.0, 1.0) * 100).round()}%',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    progressColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    circularStrokeCap: CircularStrokeCap.round,
                    animation: true,
                    animationDuration: 800,
                  ),
                ),

                const SizedBox(width: 20),

                // Right — Labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CustomText(
                        'Daily Progress',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.scaffoldBg,
                      ),
                      const SizedBox(height: 4),
                      CustomText(
                        '$takenCount of $totalCount medications taken',
                        fontSize: 14,
                        color: AppColors.scaffoldBg,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Shared premium card decoration — single source of truth.
///
/// Every "bento box" card in the app uses this so the visual rhythm
/// stays consistent. Change radius/shadow here → changes everywhere.
final BoxDecoration premiumCardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(24),
  boxShadow: [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.12),
      blurRadius: 16,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ],
);
