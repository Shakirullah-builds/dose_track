import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/providers/medication_provider.dart';
import 'package:dose_vault/core/services/notification_service.dart';
import 'package:dose_vault/core/services/supabase_sync_service.dart';
import 'package:dose_vault/core/widgets/custom_elevated_button.dart';
import 'package:dose_vault/core/widgets/custom_empty_state.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/core/widgets/top_toast.dart';
import 'package:dose_vault/features/widgets/upcoming_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full screen view displaying all upcoming scheduled medications.
class UpcomingMedicationsScreen extends ConsumerWidget {
  const UpcomingMedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationListProvider);
    final doseLogs = ref.watch(doseLogListProvider);
    final isSyncing = ref.watch(isInitialSyncingProvider);

    final now = DateTime.now();

    // ── THE LOGICAL DAY FIX (3:00 AM Rollover) ──
    final isLateNight = now.hour < 3;
    final logicalDate = isLateNight
        ? now.subtract(const Duration(days: 1))
        : now;

    // Define the exact 24-hour window: 3:00 AM to 3:00 AM next day
    final logicalStart = DateTime(
      logicalDate.year,
      logicalDate.month,
      logicalDate.day,
      3,
      0,
    );
    final logicalEnd = logicalStart.add(const Duration(hours: 24));

    // ONLY grab logs that happened during this logical 24-hour shift
    final currentLogs = doseLogs.where((l) {
      final time = l.actionTime ?? l.date;
      return time.isAfter(logicalStart.subtract(const Duration(seconds: 1))) &&
          time.isBefore(logicalEnd);
    }).toList();

    final upcoming = <Medication>[];

    for (final med in medications) {
      final hasLog = currentLogs.any((l) => l.medicationId == med.id);
      if (!hasLog) {
        upcoming.add(med);
      }
    }

    upcoming.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: AppColors.scaffoldBg,
        centerTitle: true,
        title: const CustomText(
          'Upcoming Schedule',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: SafeArea(
        child: upcoming.isEmpty
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
                    title: 'All caught up! 🎉',
                    subtitle:
                        "You've taken or skipped all scheduled medications for today.",
                    icon: Icons.check_circle_outline,
                    actionButton: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: CustomElevatedButton(
                        label: 'Go Home',
                        borderRadius: 30,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: upcoming.length,
                itemBuilder: (context, index) {
                  final med = upcoming[index];
                  return UpcomingCard(
                    medication: med,
                    onDelete: () {
                      ref
                          .read(medicationListProvider.notifier)
                          .removeMedication(med.id);
                      ref
                          .read(notificationServiceProvider)
                          .cancelReminder(med.id);

                      TopToast.showWithUndo(
                        context,
                        message: 'Medication deleted.',
                        onUndo: () async {
                          await ref
                              .read(medicationListProvider.notifier)
                              .addMedication(med);
                          await ref
                              .read(notificationServiceProvider)
                              .scheduleDoseReminder(med);
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
