import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dose_tracker/core/models/medication.dart';
import 'package:dose_tracker/core/services/hive_service.dart';

/// Holds the full medication list. Rebuild when meds are added/removed.
class MedicationListNotifier extends Notifier<List<Medication>> {
  @override
  List<Medication> build() {
    return HiveService.getAllMedications();
  }

  Future<void> addMedication(Medication med) async {
    await HiveService.addMedication(med);
    state = HiveService.getAllMedications();
  }

  Future<void> removeMedication(String id) async {
    await HiveService.deleteMedication(id);
    state = HiveService.getAllMedications();
    // Also refresh dose logs since some were deleted
    ref.invalidate(doseLogListProvider);
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
    return HiveService.getDoseLogsForDate(DateTime.now());
  }

  Future<void> logDose({
    required String medicationId,
    required String status,
  }) async {
    await HiveService.logDose(medicationId: medicationId, status: status);
    state = HiveService.getDoseLogsForDate(DateTime.now());
  }

  Future<void> deleteLog(String logId) async {
    await HiveService.deleteDoseLog(logId);
    state = HiveService.getDoseLogsForDate(DateTime.now());
  }

  Future<void> restoreLog(DoseLog log) async {
    await HiveService.restoreDoseLog(log);
    state = HiveService.getDoseLogsForDate(DateTime.now());
  }

  void refresh() {
    state = HiveService.getDoseLogsForDate(DateTime.now());
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
