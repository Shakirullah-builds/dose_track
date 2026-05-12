import 'package:dose_tracker/core/constants/app_colors.dart';
import 'package:dose_tracker/core/widgets/custom_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:dose_tracker/core/models/medication.dart';
import 'package:dose_tracker/core/providers/medication_provider.dart';
import 'package:dose_tracker/core/services/notification_service.dart';
import 'package:dose_tracker/core/services/supabase_sync_service.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    description: 'Tap the + button to add your first medication',
                    icon: Icons.medication_outlined,
                  ))
            : Column(
                children: [
                  _Header(
                    adherence: adherence,
                    takenCount: takenCount,
                    totalCount: totalMeds,
                  ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        if (upcoming.isNotEmpty) ...[
                          const SliverToBoxAdapter(
                            child: _SectionTitle('UPCOMING'),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _UpcomingCard(
                                medication: upcoming[i],
                                onDelete: () {
                                  final deletedMed = upcoming[i];
                                  ref
                                      .read(medicationListProvider.notifier)
                                      .removeMedication(deletedMed.id);
                                  ref
                                      .read(notificationServiceProvider)
                                      .cancelReminder(deletedMed.id);

                                  final messenger = ScaffoldMessenger.of(context);
                                  messenger.clearSnackBars();

                                  final snackBar = SnackBar(
                                    duration: const Duration(seconds: 3),
                                    //behavior: SnackBarBehavior.floating,
                                    content: const CustomText('Medication deleted.'),
                                    action: SnackBarAction(
                                      label: 'UNDO',
                                      onPressed: () async {
                                        await ref
                                            .read(medicationListProvider.notifier)
                                            .addMedication(deletedMed);
                                        await ref
                                            .read(notificationServiceProvider)
                                            .scheduleDoseReminder(deletedMed);
                                      },
                                    ),
                                  );

                                  final controller = messenger.showSnackBar(snackBar);

                                  // THE OVERRIDE
                                  Future.delayed(const Duration(seconds: 3), () {
                                    try {
                                      controller.close();
                                    } catch (_) {}
                                  });
                                },
                              ),
                              childCount: upcoming.length,
                            ),
                          ),
                        ],
                        if (completed.isNotEmpty) ...[
                          const SliverToBoxAdapter(
                            child: _SectionTitle('COMPLETED'),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate((_, i) {
                              final med = completed[i];
                              final log = doseLogs.firstWhere(
                                (l) => l.medicationId == med.id,
                              );
                              return _CompletedCard(
                                medication: med,
                                doseLog: log,
                                onDelete: () {
                                  final deletedMed = med;
                                  ref
                                      .read(medicationListProvider.notifier)
                                      .removeMedication(deletedMed.id);
                                  ref
                                      .read(notificationServiceProvider)
                                      .cancelReminder(deletedMed.id);

                                  final messenger = ScaffoldMessenger.of(context);
                                  messenger.clearSnackBars();

                                  final snackBar = SnackBar(
                                    duration: const Duration(seconds: 3),
                                   // behavior: SnackBarBehavior.floating,
                                    content: const CustomText('Medication deleted.'),
                                    action: SnackBarAction(
                                      label: 'UNDO',
                                      onPressed: () async {
                                        await ref
                                            .read(medicationListProvider.notifier)
                                            .addMedication(deletedMed);
                                        await ref
                                            .read(notificationServiceProvider)
                                            .scheduleDoseReminder(deletedMed);
                                      },
                                    ),
                                  );

                                  final controller = messenger.showSnackBar(snackBar);

                                  // THE OVERRIDE
                                  Future.delayed(const Duration(seconds: 3), () {
                                    try {
                                      controller.close();
                                    } catch (_) {}
                                  });
                                },
                              );
                            }, childCount: completed.length),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final double adherence;
  final int takenCount;
  final int totalCount;
  const _Header({
    required this.adherence,
    required this.takenCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      //margin: const EdgeInsets.all(16),
      //padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CustomText(
                      'Today',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    CustomText(
                      DateFormat('EEEE, MMM d').format(now),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: CircularPercentIndicator(
                radius: 70,
                lineWidth: 10,
                percent: adherence.clamp(0.0, 1.0),
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomText(
                      '${(adherence * 100).round()}%',
                      fontSize: 33,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    const CustomText(
                      'ADHERENCE',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ],
                ),
                progressColor: AppColors.primaryDark,
                backgroundColor: AppColors.ringTrack,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animationDuration: 800,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: CustomText(
                '$takenCount of $totalCount medications taken',
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
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
}

class _UpcomingCard extends ConsumerWidget {
  final Medication medication;
  final VoidCallback onDelete;
  const _UpcomingCard({required this.medication, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('upcoming_${medication.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: AppColors.missed),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          //borderRadius: BorderRadius.circular(16),
          //border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.iconBg,
                    //borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: AppColors.primaryDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomText(
                            medication.name,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          CustomText(
                            _fmt(medication.scheduledTime),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ],
                      ),
                      CustomText(
                        _dosageLabel(medication),
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    'Skipped',
                    true,
                    () => ref
                        .read(doseLogListProvider.notifier)
                        .logDose(
                          medicationId: medication.id,
                          status: 'skipped',
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionBtn(
                    'Taken',
                    false,
                    () => ref
                        .read(doseLogListProvider.notifier)
                        .logDose(medicationId: medication.id, status: 'taken'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final Medication medication;
  final DoseLog doseLog;
  final VoidCallback onDelete;
  const _CompletedCard({
    required this.medication,
    required this.doseLog,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isTaken = doseLog.status == 'taken';
    final actionStr = doseLog.actionTime != null
        ? DateFormat('h:mm a').format(doseLog.actionTime!)
        : '';
    return Dismissible(
      key: ValueKey('completed_${medication.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: AppColors.missed),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTaken
                    ? AppColors.taken.withValues(alpha: 0.12)
                    : AppColors.skipped.withValues(alpha: 0.5),
                //borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isTaken
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_rounded,
                color: isTaken ? AppColors.taken : AppColors.skippedText,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    medication.name,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary.withValues(alpha: 0.7),
                    decoration: isTaken ? TextDecoration.lineThrough : null,
                  ),
                  CustomText(
                    _dosageLabel(medication),
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CustomText(
                  _fmt(medication.scheduledTime),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withValues(alpha: 0.6),
                ),
                if (actionStr.isNotEmpty)
                  CustomText(
                    '${isTaken ? "Taken" : "Skipped"} $actionStr',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isTaken ? AppColors.taken : AppColors.skippedText,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final bool isSkip;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.isSkip, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSkip
          ? AppColors.skipped
          : AppColors.taken.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isSkip) ...[
                const Icon(Icons.check, size: 18, color: AppColors.taken),
                const SizedBox(width: 6),
              ],
              CustomText(
                label,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSkip ? AppColors.skippedText : AppColors.taken,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmt(String t) {
  try {
    final p = t.split(':');
    final d = DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1]));
    return DateFormat('h:mm a').format(d);
  } catch (_) {
    return t;
  }
}

String _dosageLabel(Medication m) {
  final d = m.dosage.truncateToDouble() == m.dosage
      ? m.dosage.toInt().toString()
      : m.dosage.toString();
  return '$d${m.unit} • Tablet';
}
