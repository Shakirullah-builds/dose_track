import 'dart:math' as math;
import 'dart:ui';

import 'package:dose_vault/core/models/onboarding_model.dart';
import 'package:dose_vault/core/widgets/custom_elevated_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/app_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  double _currentPage = 0.0;

  /// Drives the slow-floating orb animation.
  late AnimationController _bgController;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      icon: Icons.medical_information,
      iconColor: const Color(0xFF2E7D32),
      bgColor: const Color(0xFFE8F5E9),
      title: 'Track Your Medications',
      subtitle:
          'Easily log your prescriptions, manage dosages, and monitor your health.',
    ),
    OnboardingPageData(
      icon: Icons.notifications_active_outlined,
      iconColor: const Color(0xFFEF6C00),
      bgColor: const Color(0xFFFFF3E0),
      title: 'Never Miss a Dose',
      subtitle:
          'Get timely notifications and mark your doses with a simple swipe.',
    ),
    OnboardingPageData(
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFF1565C0),
      bgColor: const Color(0xFFE3F2FD),
      title: '100% Private',
      subtitle:
          'No sign-ups required. Your data stays completely anonymous and secure.',
    ),
  ];

  // ── Hive / routing logic (UNCHANGED) ────────────────────────────────

  Future<void> _completeOnboarding() async {
    final box = await Hive.openBox('settings');
    await box.put('has_seen_onboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(
          milliseconds: 1000,
        ), // A majestic 1-second reveal
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // The Fade: Smoothly brings the opacity from 0 to 1
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          );

          // The Scale: Starts slightly pushed back (0.93) and resolves to full size (1.0)
          final scaleAnimation = Tween<double>(begin: 0.93, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          );
        },
      ),
    );
  }

  // ── Lifecycle ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pageController.addListener(() {
      setState(() => _currentPage = _pageController.page ?? 0);
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pageIndex = _currentPage.round();

    return Scaffold(
      body: Stack(
        children: [
          // ── Layer 1: Living Orbs ─────────────────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, _) {
              final t = _bgController.value * 2 * math.pi;
              return Stack(
                children: [
                  // Orb 1 — primary blue, drifting top-left
                  Transform.translate(
                    offset: Offset(
                      -40 + math.sin(t) * 30,
                      80 + math.cos(t) * 40,
                    ),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  // Orb 2 — soft green/teal, drifting bottom-right
                  Transform.translate(
                    offset: Offset(
                      MediaQuery.of(context).size.width -
                          200 +
                          math.cos(t * 0.8) * 25,
                      MediaQuery.of(context).size.height * 0.45 +
                          math.sin(t * 0.8) * 35,
                    ),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Layer 2: Glass Frost ─────────────────────────────────
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),

          // ── Layer 3: Content with Parallax ──────────────────────
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: pageIndex == 2
                      ? const SizedBox(height: 48)
                      : TextButton(
                          onPressed: _completeOnboarding,
                          child: const CustomText(
                            'Skip',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                ),

                // Pages with parallax
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      final offset = _currentPage - index;
                      // Opacity: fully visible at 0, fading as |offset| → 1
                      final opacity = (1 - offset.abs()).clamp(0.0, 1.0);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon — slowest parallax (100px shift)
                            Transform.translate(
                              offset: Offset(offset * 100, 0),
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: page.bgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    page.icon,
                                    size: 80,
                                    color: page.iconColor,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Title — medium parallax (200px shift)
                            Transform.translate(
                              offset: Offset(offset * 200, 0),
                              child: Opacity(
                                opacity: opacity,
                                child: CustomText(
                                  page.title,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Subtitle — fastest parallax (300px shift)
                            Transform.translate(
                              offset: Offset(offset * 300, 0),
                              child: Opacity(
                                opacity: opacity,
                                child: CustomText(
                                  page.subtitle,
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  textAlign: TextAlign.center,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Animated dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: pageIndex == index ? 24.0 : 8.0,
                            decoration: BoxDecoration(
                              color: pageIndex == index
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // CTA Button
                      CustomElevatedButton(
                        label: pageIndex == 2 ? 'Get Started' : 'Next',
                        onPressed: () {
                          if (pageIndex == 2) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
