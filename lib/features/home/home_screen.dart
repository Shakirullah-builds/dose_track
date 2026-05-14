import 'package:dose_tracker/core/constants/app_colors.dart';
import 'package:dose_tracker/core/widgets/custom_empty_state.dart';
import 'package:dose_tracker/features/widgets/completed_card.dart';
import 'package:dose_tracker/features/widgets/header.dart';
import 'package:dose_tracker/features/widgets/upcoming_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dose_tracker/core/models/medication.dart';
import 'package:dose_tracker/core/providers/medication_provider.dart';
import 'package:dose_tracker/core/services/notification_service.dart';
import 'package:dose_tracker/core/services/supabase_sync_service.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _hasNotificationPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialPermissionRequest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quietly check the status. NEVER call requestPermission() in here!
      _quietlyCheckStatus();
    }
  }

  // Called ONLY once when the screen loads to trigger the actual OS popup
  Future<void> _initialPermissionRequest() async {
    await FirebaseMessaging.instance.requestPermission();
    await _quietlyCheckStatus();
  }

  // Safe to call anytime. It just reads the boolean status without waking up the OS dialog.
  Future<void> _quietlyCheckStatus() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() {
        // If it's denied or permanently denied, we show the banner (false). Otherwise, hide it (true).
        _hasNotificationPermission =
            !(status.isDenied || status.isPermanentlyDenied);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final medications = ref.watch(medicationListProvider);
    final doseLogs = ref.watch(doseLogListProvider);
    final isSyncing = ref.watch(isInitialSyncingProvider);
    final upcoming = <Medication>[];
    final completed = <Medication>[];

    for (final med in medications) {
      final hasLog = doseLogs.any((l) => l.medicationId == med.id);
      if (hasLog) {
        completed.add(med);
      } else {
        upcoming.add(med);
      }
    }

    upcoming.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    completed.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    final totalMeds = medications.length;
    final takenCount = doseLogs.where((l) => l.status == 'taken').length;
    final adherence = totalMeds > 0 ? takenCount / totalMeds : 0.0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            if (!_hasNotificationPermission)
              Container(
                color: Colors.orange.shade50,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            'Medication reminders are paused',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                          CustomText(
                            'Enable notifications in settings so you never miss a dose.',
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        await openAppSettings();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.shade100,
                        ),
                        child: CustomText(
                            'Fix',
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: medications.isEmpty
                  ? (isSyncing
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                CustomText('Restoring data...'),
                              ],
                            ),
                          )
                        : const CustomEmptyState(
                            title: 'No medications yet',
                            description:
                                'Tap the + button to add your first medication',
                            icon: Icons.medication_outlined,
                          ))
                  : Column(
                      children: [
                        Header(
                          adherence: adherence,
                          takenCount: takenCount,
                          totalCount: totalMeds,
                        ),
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              if (upcoming.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: _sectionTitle('UPCOMING'),
                                ),
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (_, i) => UpcomingCard(
                                      medication: upcoming[i],
                                      onDelete: () {
                                        final deletedMed = upcoming[i];
                                        ref
                                            .read(
                                              medicationListProvider.notifier,
                                            )
                                            .removeMedication(deletedMed.id);
                                        ref
                                            .read(notificationServiceProvider)
                                            .cancelReminder(deletedMed.id);

                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        messenger.clearSnackBars();

                                        final snackBar = SnackBar(
                                          duration: const Duration(seconds: 3),
                                          //behavior: SnackBarBehavior.floating,
                                          content: const CustomText(
                                            'Medication deleted.',
                                          ),
                                          action: SnackBarAction(
                                            label: 'UNDO',
                                            onPressed: () async {
                                              await ref
                                                  .read(
                                                    medicationListProvider
                                                        .notifier,
                                                  )
                                                  .addMedication(deletedMed);
                                              await ref
                                                  .read(
                                                    notificationServiceProvider,
                                                  )
                                                  .scheduleDoseReminder(
                                                    deletedMed,
                                                  );
                                            },
                                          ),
                                        );

                                        final controller = messenger
                                            .showSnackBar(snackBar);

                                        // THE OVERRIDE
                                        Future.delayed(
                                          const Duration(seconds: 3),
                                          () {
                                            try {
                                              controller.close();
                                            } catch (_) {}
                                          },
                                        );
                                      },
                                    ),
                                    childCount: upcoming.length,
                                  ),
                                ),
                              ],
                              if (completed.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: _sectionTitle('COMPLETED'),
                                ),
                                SliverList(
                                  delegate: SliverChildBuilderDelegate((_, i) {
                                    final med = completed[i];
                                    final log = doseLogs.firstWhere(
                                      (l) => l.medicationId == med.id,
                                    );
                                    return CompletedCard(
                                      medication: med,
                                      doseLog: log,
                                      onDelete: () {
                                        final deletedMed = med;
                                        ref
                                            .read(
                                              medicationListProvider.notifier,
                                            )
                                            .removeMedication(deletedMed.id);
                                        ref
                                            .read(notificationServiceProvider)
                                            .cancelReminder(deletedMed.id);

                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        messenger.clearSnackBars();

                                        final snackBar = SnackBar(
                                          duration: const Duration(seconds: 3),
                                          // behavior: SnackBarBehavior.floating,
                                          content: const CustomText(
                                            'Medication deleted.',
                                          ),
                                          action: SnackBarAction(
                                            label: 'UNDO',
                                            onPressed: () async {
                                              await ref
                                                  .read(
                                                    medicationListProvider
                                                        .notifier,
                                                  )
                                                  .addMedication(deletedMed);
                                              await ref
                                                  .read(
                                                    notificationServiceProvider,
                                                  )
                                                  .scheduleDoseReminder(
                                                    deletedMed,
                                                  );
                                            },
                                          ),
                                        );

                                        final controller = messenger
                                            .showSnackBar(snackBar);

                                        // THE OVERRIDE
                                        Future.delayed(
                                          const Duration(seconds: 3),
                                          () {
                                            try {
                                              controller.close();
                                            } catch (_) {}
                                          },
                                        );
                                      },
                                    );
                                  }, childCount: completed.length),
                                ),
                              ],
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 100),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: CustomText(
      title,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 1.5,
    ),
  );
}
