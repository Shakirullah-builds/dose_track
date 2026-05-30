import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/providers/medication_provider.dart';
import 'package:dose_vault/core/widgets/custom_empty_state.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Shows today's notification activity feed — every dose that was
/// triggered, taken, skipped, or missed during the current logical day.
///
/// Why a separate screen instead of reusing HistoryScreen?
/// → HistoryScreen shows ALL past logs across all dates. This screen
///   is laser-focused on TODAY's activity, making it feel like an
///   "inbox" for medication alerts.
class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationListProvider);
    final doseLogs = ref.watch(doseLogListProvider);

    // ── Logical Day Calculation (same 3AM rollover as HomeScreen) ──
    final now = DateTime.now();
    final isLateNight = now.hour < 3;
    final logicalDate = isLateNight
        ? now.subtract(const Duration(days: 1))
        : now;

    final logicalStart = DateTime(
      logicalDate.year,
      logicalDate.month,
      logicalDate.day,
      3,
      0,
    );
    final logicalEnd = logicalStart.add(const Duration(hours: 24));

    // Filter logs to today's logical window only
    final todayLogs = doseLogs.where((l) {
      final time = l.actionTime ?? l.date;
      return time.isAfter(logicalStart.subtract(const Duration(seconds: 1))) &&
          time.isBefore(logicalEnd);
    }).toList();

    // Build a combined list: logged meds + pending meds (no log yet)
    final entries = <_NotificationEntry>[];

    for (final med in medications) {
      final log = todayLogs.where((l) => l.medicationId == med.id).firstOrNull;

      if (log != null) {
        // This medication has been acted on today
        entries.add(
          _NotificationEntry(
            medication: med,
            status: log.status, // 'taken' or 'skipped'
            actionTime: log.actionTime,
          ),
        );
      } else {
        // No log yet — check if the scheduled time has passed (pending/overdue)
        final scheduledParts = med.scheduledTime.split(':');
        final scheduledToday = DateTime(
          logicalDate.year,
          logicalDate.month,
          logicalDate.day,
          int.parse(scheduledParts[0]),
          int.parse(scheduledParts[1]),
        );

        if (now.isAfter(scheduledToday)) {
          entries.add(
            _NotificationEntry(
              medication: med,
              status: 'overdue',
              actionTime: scheduledToday,
            ),
          );
        } else {
          entries.add(
            _NotificationEntry(
              medication: med,
              status: 'pending',
              actionTime: scheduledToday,
            ),
          );
        }
      }
    }

    // Sort: most recent activity first
    entries.sort((a, b) {
      final timeA = a.actionTime ?? DateTime(2000);
      final timeB = b.actionTime ?? DateTime(2000);
      return timeB.compareTo(timeA);
    });

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const CustomText(
          "Today's Alerts",
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: entries.isEmpty
          ? const CustomEmptyState(
              title: 'No Alerts Today',
              subtitle: 'You have no medications scheduled for today.',
              icon: Icons.notifications_off_outlined,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _NotificationTile(entry: entry);
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DATA MODEL (private to this file)
// ═══════════════════════════════════════════════════════════════════════

class _NotificationEntry {
  final Medication medication;
  final String status; // 'taken', 'skipped', 'overdue', 'pending'
  final DateTime? actionTime;

  _NotificationEntry({
    required this.medication,
    required this.status,
    this.actionTime,
  });
}

// ═══════════════════════════════════════════════════════════════════════
// TILE WIDGET (private to this file)
// ═══════════════════════════════════════════════════════════════════════

class _NotificationTile extends StatelessWidget {
  final _NotificationEntry entry;

  const _NotificationTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (icon, iconBg, iconColor, label) = _statusVisuals(entry.status);

    final timeStr = entry.actionTime != null
        ? DateFormat('h:mm a').format(entry.actionTime!)
        : '--:--';

    final dosageStr = entry.medication.dosage.toString().replaceAll(
      RegExp(r'\.0$'),
      '',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),

          // Medication Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  entry.medication.name,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(height: 2),
                CustomText(
                  '$dosageStr${entry.medication.unit} · $timeStr',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          // Status Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: CustomText(
              label,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns (icon, backgroundColor, iconColor, label) for each status.
  (IconData, Color, Color, String) _statusVisuals(String status) {
    return switch (status) {
      'taken' => (
        Icons.check_circle_rounded,
        AppColors.accent.withValues(alpha: 0.1),
        AppColors.accent,
        'Taken',
      ),
      'skipped' => (
        Icons.skip_next_rounded,
        Colors.orange.withValues(alpha: 0.1),
        Colors.orange,
        'Skipped',
      ),
      'overdue' => (
        Icons.warning_amber_rounded,
        AppColors.warning.withValues(alpha: 0.1),
        AppColors.warning,
        'Overdue',
      ),
      _ => (
        Icons.schedule_rounded,
        AppColors.primary.withValues(alpha: 0.1),
        AppColors.primary,
        'Pending',
      ),
    };
  }
}
