import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/custom_elevated_button.dart';
import 'package:dose_vault/core/widgets/custom_empty_state.dart';
import 'package:dose_vault/features/widgets/completed_card.dart';
import 'package:dose_vault/features/widgets/header.dart';
import 'package:dose_vault/features/widgets/upcoming_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/providers/medication_provider.dart';
import 'package:dose_vault/core/services/notification_service.dart';
import 'package:dose_vault/core/services/supabase_sync_service.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/core/widgets/top_toast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dose_vault/features/medication/add_medication_screen.dart' as dose_vault_add_medication;

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
    final now = DateTime.now();
    final todayLogs = doseLogs.where((l) =>
        l.date.year == now.year &&
        l.date.month == now.month &&
        l.date.day == now.day);
    final takenCount = todayLogs.where((l) => l.status == 'taken').length.clamp(0, totalMeds);
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
                  //vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomText(
                            'DoseVault needs notifications enabled to remind you of your medication.',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize:
                            Size.zero, // No minimum size for text buttons
                            padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        await openAppSettings();
                      },
                      child: CustomText(
                        'Go to settings',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
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
                        : CustomEmptyState(
                            title: 'No Medications Yet',
                            subtitle:
                                'Add your first medication to start tracking. Never miss a dose!',
                            icon: Icons.medication_outlined,
                            actionButton: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: CustomElevatedButton(
                                label: '+ Add Medication',
                                borderRadius: 30,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const dose_vault_add_medication.AddMedicationScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
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
                                  child: _sectionTitle('Upcoming Schedule'),
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

                                        TopToast.showWithUndo(
                                          context,
                                          message: 'Medication deleted.',
                                          onUndo: () async {
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
                                        );
                                      },
                                    ),
                                    childCount: upcoming.length,
                                  ),
                                ),
                              ],
                              if (completed.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: _sectionTitle('Completed'),
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

                                        TopToast.showWithUndo(
                                          context,
                                          message: 'Medication deleted.',
                                          onUndo: () async {
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
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: CustomText(
      title,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
  );
}

