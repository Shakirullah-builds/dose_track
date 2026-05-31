import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/providers/medication_provider.dart';
import 'package:dose_vault/core/services/notification_service.dart';
import 'package:dose_vault/core/widgets/bounce_tap.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Premium "Calm Health Light Mode" Full-Screen Alarm Overlay.
///
/// Features soft sky-blue and white gradients, an organic breathing ambient aura glow,
/// a custom frosted pure-white glass Bento card panel, high-contrast typography,
/// and glowing brand-aligned tactile control buttons wrapped in BounceTap.
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

  int _secondsRemaining = 180; // 3-minute limit
  Timer? _countdownTimer;
  bool _hasActed = false;

  @override
  void initState() {
    super.initState();

    // Parse the medication data from the notification payload
    _medData = jsonDecode(widget.payload) as Map<String, dynamic>;

    // Pulse animation (drives breathing ambient aura and floating pill)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Start the 180-second auto-dismiss countdown
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

    await ref
        .read(doseLogListProvider.notifier)
        .logDose(medicationId: _medData['id'] as String, status: 'taken');

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleSkipped() async {
    if (_hasActed) return;
    _hasActed = true;
    _countdownTimer?.cancel();

    await ref
        .read(doseLogListProvider.notifier)
        .logDose(medicationId: _medData['id'] as String, status: 'skipped');

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleMissed() async {
    if (_hasActed) return;
    _hasActed = true;
    _countdownTimer?.cancel();

    final medId = _medData['id'] as String;

    try {
      // 1. Cancel the active ringing notification to stop the looping sound
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.cancelReminder(medId);

      // 2. Fetch the full Medication object from the provider to issue the persistent tray alert
      final medications = ref.read(medicationListProvider);
      final medication = medications.where((m) => m.id == medId).firstOrNull;
      if (medication != null) {
        await notificationService.showPersistentMissedDoseAlert(medication);
      }
    } catch (_) {
      // Fail-silent to ensure page popping and UX remain uninterrupted
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = _medData['name'] as String? ?? 'Medication';
    final dosage =
        (_medData['dosage'] as num?)?.toDouble().toString().replaceAll(
          RegExp(r'\.0$'),
          '',
        ) ??
        '';
    final unit = _medData['unit'] as String? ?? '';
    final instructions = _medData['instructions'] as String?;
    final now = DateFormat('h:mm a').format(DateTime.now());

    // Countdown progress (1.0 = full, 0.0 = expired)
    final progress = _secondsRemaining / 180;
    final isWarningState = _secondsRemaining < 15;
    final activeColor = isWarningState ? AppColors.missed : AppColors.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          // Soothing Sky Light Gradient Background
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE8F4FD), // AppColors.headerBg (Soft sky blue)
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── 1. Breathing Ambient Aura Glow ──
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.12,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final size = 260.0 + (_pulseController.value * 35.0);
                      final opacity = 0.08 + (_pulseController.value * 0.06);
                      return Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              activeColor.withValues(alpha: opacity),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── 2. Content Layout ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(flex: 3),

                      // ── High-Tech Progress Ring + Floating Capsule ──
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Custom Glowing Circular Indicator
                          SizedBox(
                            width: 170,
                            height: 170,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 5,
                              backgroundColor: AppColors.ringTrack,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                activeColor,
                              ),
                            ),
                          ),

                          // Floating Glassmorphic Capsule
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final translateY = _pulseController.value * -6.0;
                              final scale =
                                  1.0 + (_pulseController.value * 0.05);
                              return Transform.translate(
                                offset: Offset(0, translateY),
                                child: Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '💊',
                                    style: TextStyle(fontSize: 48),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(flex: 2),

                      // ── Frosted Bento Info Card (White Frost) ──
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Time Tracker
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: CustomText(
                                    'Scheduled for $now',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Medication Name (High Contrast)
                                CustomText(
                                  name,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),

                                // Dosage details (using brand primary sky-blue)
                                CustomText(
                                  '$dosage$unit',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  textAlign: TextAlign.center,
                                ),

                                // Custom instructions (using brand warning orange if present)
                                if (instructions != null &&
                                    instructions.trim().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.warning.withValues(
                                          alpha: 0.15,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: AppColors.warning,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: CustomText(
                                            instructions,
                                            fontSize: 13,
                                            color: AppColors.warning,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Countdown urgency text
                      CustomText(
                        'Auto-dismiss in ${_secondsRemaining}s',
                        fontSize: 13,
                        color: isWarningState
                            ? AppColors.missed
                            : AppColors.textSecondary,
                        fontWeight: isWarningState
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),

                      const Spacer(flex: 4),

                      // ── Interactive Control Buttons ──
                      Row(
                        children: [
                          // Soft White "Skip" Button
                          Expanded(
                            child: BounceTap(
                              onTap: _handleSkipped,
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.white,
                                  border: Border.all(
                                    color: AppColors.divider,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const CustomText(
                                  'Skip',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.skippedText,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Glowing Brand-Green "Take" Button
                          Expanded(
                            flex: 2,
                            child: BounceTap(
                              onTap: _handleTaken,
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(
                                        0xFF26C6A0,
                                      ), // AppColors.taken (teal green)
                                      Color(0xFF2EE5B6), // Vibrancy boost
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF26C6A0,
                                      ).withValues(alpha: 0.25),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
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

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
