import 'package:dose_tracker/core/constants/app_colors.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

/// Premium 'Bento Box' header — greeting row + hero progress card.
///
/// The old version was a single tall block with a centered ring.
/// This version splits the header into two visual "boxes":
/// 1. A greeting row (Today + date + avatar)
/// 2. A hero card with a compact side-by-side ring + label layout
///
/// This feels more spacious and modern while keeping the same data props.
class Header extends StatelessWidget {
  final double adherence;
  final int takenCount;
  final int totalCount;
  const Header({
    required this.adherence,
    required this.takenCount,
    required this.totalCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
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
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  CustomText(
                    DateFormat('EEEE, MMM d').format(now),
                    //fontWeight: FontWeight.normal,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.scaffoldBg,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Hero Progress Card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: premiumCardDecoration,
            child: Row(
              children: [
                // Left — Circular ring
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularPercentIndicator(
                    radius: 40,
                    lineWidth: 8,
                    percent: adherence.clamp(0.0, 1.0),
                    center: CustomText(
                      '${(adherence * 100).round()}%',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    progressColor: AppColors.primaryDark,
                    backgroundColor: AppColors.divider,
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
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(height: 4),
                      CustomText(
                        '$takenCount of $totalCount medications taken',
                        fontSize: 14,
                        color: AppColors.textSecondary,
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
