import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dose_tracker/core/providers/medication_provider.dart';
import 'package:dose_tracker/features/home/home_screen.dart';
import 'package:dose_tracker/features/history/history_screen.dart';
import 'package:dose_tracker/features/medication/add_medication_screen.dart';
import 'package:dose_tracker/core/services/supabase_sync_service.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: CustomText(message), duration: const Duration(seconds: 3)),
            );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddMedicationScreen(),
            ),
          );
        },
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // selectedItemColor: AppColors.primaryDark,
        // unselectedItemColor: AppColors.textHint,
        currentIndex: currentIndex,
        onTap: (i) => ref.read(bottomNavIndexProvider.notifier).state = i,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
