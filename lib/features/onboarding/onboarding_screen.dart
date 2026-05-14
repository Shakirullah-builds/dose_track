import 'package:dose_tracker/core/models/onboarding_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dose_tracker/core/constants/app_colors.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';
import 'package:dose_tracker/app_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      icon: Icons.medical_information,
      iconColor: const Color(0xFF2E7D32), // Dark green
      bgColor: const Color(0xFFE8F5E9), // Soft green bg
      title: 'Track Your Medications',
      subtitle:
          'Easily log your prescriptions, manage dosages, and monitor your health.',
    ),
    OnboardingPageData(
      icon: Icons.notifications_active_outlined,
      iconColor: const Color(0xFFEF6C00), // Dark orange
      bgColor: const Color(0xFFFFF3E0), // Soft orange bg
      title: 'Never Miss a Dose',
      subtitle:
          'Get timely notifications and mark your doses with a simple swipe.',
    ),
    OnboardingPageData(
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFF1565C0), // Dark blue
      bgColor: const Color(0xFFE3F2FD), // Soft blue bg
      title: '100% Private',
      subtitle:
          'No sign-ups required. Your data stays completely anonymous and secure.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    // Already opened in main.dart via HiveService.init(), so we can use box directly
    // but the instruction says:
    // "Open the Hive settings box: final box = await Hive.openBox('settings');"
    // To strictly follow the instructions without conflict, we can do it:
    final box = await Hive.openBox('settings');
    await box.put('has_seen_onboarding', true);

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Align(
              alignment: Alignment.topRight,
              child: _currentPage == 2
                  ? const SizedBox(
                      height: 48,
                    ) // Placeholder to keep height consistent
                  : TextButton(
                      onPressed: _completeOnboarding,
                      child: const CustomText(
                        'Skip',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),

            // Center Content (The Pages)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
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
                        const SizedBox(height: 32),
                        CustomText(
                          page.title,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        CustomText(
                          page.subtitle,
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          textAlign: TextAlign.center,
                          height: 1.5,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Animated dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        height: 8.0,
                        width: _currentPage == index ? 24.0 : 8.0,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Elevated Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                      ),
                      onPressed: () {
                        if (_currentPage == 2) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: CustomText(
                        _currentPage == 2 ? 'Get Started' : 'Next',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
