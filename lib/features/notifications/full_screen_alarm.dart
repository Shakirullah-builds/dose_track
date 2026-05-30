import 'dart:async';
import 'dart:convert';

import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/services/hive_service.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Full-screen alarm that takes over the display when a dose reminder fires.
///
/// Why a full-screen activity instead of a standard notification banner?
/// → Alpha testers reported that standard banner notifications are too easy
///   to swipe away, causing missed doses. This screen forces engagement
///   by presenting a full-screen alert with Take/Skip/auto-dismiss actions.
///
/// The screen auto-dismisses after 60 seconds and logs the dose as "missed"
/// if the user doesn't interact.
class FullScreenAlarm extends ConsumerStatefulWidget {
  /// JSON-encoded medication payload from the notification.
  final String payload;

  const FullScreenAlarm({super.key, required this.payload});

  @override
  ConsumerState<FullScreenAlarm> createState() => _FullScreenAlarmState();
}

class _FullScreenAlarmState extends ConsumerState<FullScreenAlarm>
    with SingleTickerProviderStateMixin {
  late final Map<String, dynamic> _medData;
  late final AnimationController _pulseController;

  int _secondsRemaining = 60;
  Timer? _countdownTimer;
  bool _hasActed = false;

  @override
  void initState() {
    super.initState();

    // Parse the medication data from the notification payload
    _medData = jsonDecode(widget.payload) as Map<String, dynamic>;

    // Pulse animation for the pill icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Start the 60-second auto-dismiss countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _handleMissed();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _handleTaken() async {
    if (_hasActed) return;
    _hasActed = true;
    _countdownTimer?.cancel();

    await HiveService.logDose(
      medicationId: _medData['id'] as String,
      status: 'taken',
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleSkipped() async {
    if (_hasActed) return;
    _hasActed = true;
    _countdownTimer?.cancel();

    await HiveService.logDose(
      medicationId: _medData['id'] as String,
      status: 'skipped',
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleMissed() async {
    if (_hasActed) return;
    _hasActed = true;
    _countdownTimer?.cancel();

    // Log as missed (we use 'skipped' status with a note, since
    // the DoseLog model uses 'taken' or 'skipped' as the only statuses)
    await HiveService.logDose(
      medicationId: _medData['id'] as String,
      status: 'skipped',
    );

    if (mounted) Navigator.of(context).pop();
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = _medData['name'] as String? ?? 'Medication';
    final dosage = (_medData['dosage'] as num?)
            ?.toDouble()
            .toString()
            .replaceAll(RegExp(r'\.0$'), '') ??
        '';
    final unit = _medData['unit'] as String? ?? '';
    final instructions = _medData['instructions'] as String?;
    final now = DateFormat('h:mm a').format(DateTime.now());

    // Countdown progress (1.0 = full, 0.0 = expired)
    final progress = _secondsRemaining / 60;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Countdown Ring + Pill Icon ──
              Stack(
                alignment: Alignment.center,
                children: [
                  // Countdown ring
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.3
                            ? AppColors.accent
                            : AppColors.warning,
                      ),
                    ),
                  ),
                  // Pulsing pill emoji
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale =
                          1.0 + (_pulseController.value * 0.08);
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: CustomText(
                      '💊',
                      fontSize: 64,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Medication Name ──
              CustomText(
                name,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // ── Dosage ──
              CustomText(
                '$dosage$unit',
                fontSize: 20,
                color: Colors.white.withValues(alpha: 0.7),
                textAlign: TextAlign.center,
              ),

              if (instructions != null && instructions.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                CustomText(
                  instructions,
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.5),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 16),

              // ── Current Time ──
              CustomText(
                now,
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.4),
              ),

              const SizedBox(height: 8),

              // ── Countdown Label ──
              CustomText(
                'Auto-dismiss in ${_secondsRemaining}s',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.3),
              ),

              const Spacer(flex: 3),

              // ── Action Buttons ──
              Row(
                children: [
                  // Skip Button
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _handleSkipped,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const CustomText(
                          'Skip',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Take Button
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _handleTaken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const CustomText(
                          'Take',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
