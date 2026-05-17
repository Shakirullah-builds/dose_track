import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dose_vault/core/providers/medication_provider.dart';
import 'package:dose_vault/features/home/home_screen.dart';
import 'package:dose_vault/features/history/history_screen.dart';
import 'package:dose_vault/features/medication/add_medication_screen.dart';
import 'package:dose_vault/core/services/supabase_sync_service.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/core/widgets/bounce_tap.dart';
import 'package:dose_vault/features/settings/settings_screen.dart';

/// The main app shell — hosts bottom nav, FAB, and screen switching.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _screens = [
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Run the down-sync without blocking the first frame render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supabaseSyncServiceProvider).syncDownOnLaunch(
        ref,
        onComplete: () {
          // Invalidate to force UI rebuild with fresh local data
          ref.invalidate(medicationListProvider);
          ref.invalidate(doseLogListProvider);
        },
        onError: (message) {
          if (mounted) {
            TopToast.showError(context, message);
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AddMedicationScreen(),
              ),
            );
          },
          child: const Icon(Icons.add, size: 28),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(currentIndex, 0, Icons.home_outlined, Icons.home, 'Home'),
              _buildNavItem(currentIndex, 1, Icons.history_outlined, Icons.history, 'History'),
              _buildNavItem(currentIndex, 2, Icons.settings_outlined, Icons.settings, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int currentIndex, int index, IconData icon, IconData activeIcon, String label) {
    final isActive = currentIndex == index;
    return BounceTap(
      onTap: () => ref.read(bottomNavIndexProvider.notifier).state = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: isActive 
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12) 
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              CustomText(
                label,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
