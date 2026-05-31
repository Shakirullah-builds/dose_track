import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/services/hive_service.dart';
import 'package:dose_vault/core/services/supabase_sync_service.dart';
import 'package:dose_vault/core/services/notification_service.dart';

/// Holds the full medication list. Rebuild when meds are added/removed.
class MedicationListNotifier extends Notifier<List<Medication>> {
  @override
  List<Medication> build() {
    return HiveService.getAllMedications();
  }

  Future<void> addMedication(Medication med) async {
    await HiveService.addMedication(med);
    state = [...state, med];
    
    // Schedule local offline notification
    ref.read(notificationServiceProvider).scheduleDoseReminder(med);
    
    // Fire-and-forget background sync
    ref.read(supabaseSyncServiceProvider).syncMedicationsUp();
  }

  Future<void> updateMedication(Medication med) async {
    await HiveService.addMedication(med);
    state = state.map((m) => m.id == med.id ? med : m).toList();
    
    // Reschedule local offline notification
    ref.read(notificationServiceProvider).scheduleDoseReminder(med);
    
    // Fire-and-forget background sync
    ref.read(supabaseSyncServiceProvider).syncMedicationsUp();
  }

  Future<void> removeMedication(String id) async {
    await HiveService.deleteMedication(id);
    state = state.where((m) => m.id != id).toList();
    // Also refresh dose logs since some were deleted
    ref.invalidate(doseLogListProvider);
    // Fire-and-forget background sync
    ref.read(supabaseSyncServiceProvider).syncMedicationsUp();
  }
}

final medicationListProvider =
    NotifierProvider<MedicationListNotifier, List<Medication>>(
      MedicationListNotifier.new,
    );

/// Holds today's dose logs. Rebuilt when a dose is logged/changed.
class DoseLogListNotifier extends Notifier<List<DoseLog>> {
  @override
  List<DoseLog> build() {
    return HiveService.getDoseLogsForDate(
      HiveService.getLogicalDate(DateTime.now()),
    );
  }

  Future<void> logDose({
    required String medicationId,
    required String status,
  }) async {
    await HiveService.logDose(medicationId: medicationId, status: status);
    // Refresh to get the updated log with its generated ID from Hive, or we can just pull fresh
    state = [
      ...HiveService.getDoseLogsForDate(
        HiveService.getLogicalDate(DateTime.now()),
      ),
    ];
    // Fire-and-forget background sync
    ref.read(supabaseSyncServiceProvider).syncLogsUp();

    // Centralized active notification cleanup & daily rescheduling
    try {
      final medications = ref.read(medicationListProvider);
      final medication = medications.where((m) => m.id == medicationId).firstOrNull;
      if (medication != null) {
        final notificationService = ref.read(notificationServiceProvider);
        await notificationService.cancelReminder(medicationId); // Clear active status bar notification banner
        await notificationService.scheduleDoseReminder(medication); // Auto-reschedules for tomorrow
      }
    } catch (e) {
      // Fail-silent to ensure database logging and UI state updates remain uninterrupted
    }
  }

  Future<void> deleteLog(String logId) async {
    await HiveService.deleteDoseLog(logId);
    state = state.where((l) => l.id != logId).toList();
    // Fire-and-forget background sync
    ref.read(supabaseSyncServiceProvider).syncLogsUp();
  }

  Future<void> restoreLog(DoseLog log) async {
    await HiveService.restoreDoseLog(log);
    state = [...state, log];
    // Fire-and-forget background sync
    ref.read(supabaseSyncServiceProvider).syncLogsUp();
  }

  void refresh() {
    state = HiveService.getDoseLogsForDate(
      HiveService.getLogicalDate(DateTime.now()),
    );
  }
}

final doseLogListProvider =
    NotifierProvider<DoseLogListNotifier, List<DoseLog>>(
      DoseLogListNotifier.new,
    );

/// All dose logs (for History screen).
final allDoseLogsProvider = Provider<List<DoseLog>>((ref) {
  // Re-read whenever today's logs change (they trigger most writes)
  ref.watch(doseLogListProvider);
  return HiveService.getAllDoseLogs();
});

/// Bottom navigation index.
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
