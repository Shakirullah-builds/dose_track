import 'package:hive_flutter/hive_flutter.dart';
import 'package:dose_tracker/core/models/medication.dart';
import 'package:uuid/uuid.dart';

/// Centralized Hive service — handles init, CRUD for medications and dose logs.
class HiveService {
  static const String _medicationBox = 'medications';
  static const String _doseLogBox = 'dose_logs';

  static final _uuid = const Uuid();

  /// Call once in main() before runApp.
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MedicationAdapter());
    Hive.registerAdapter(DoseLogAdapter());
    await Hive.openBox<Medication>(_medicationBox);
    await Hive.openBox<DoseLog>(_doseLogBox);
  }

  // ── Medication CRUD ──────────────────────────────────────────────

  static Box<Medication> get _medBox => Hive.box<Medication>(_medicationBox);
  static Box<DoseLog> get _logBox => Hive.box<DoseLog>(_doseLogBox);

  static List<Medication> getAllMedications() {
    return _medBox.values.toList();
  }

  static Future<void> addMedication(Medication med) async {
    await _medBox.put(med.id, med);
  }

  static Future<void> deleteMedication(String id) async {
    await _medBox.delete(id);
    // Also remove associated logs
    final logsToDelete = _logBox.values
        .where((log) => log.medicationId == id)
        .toList();
    for (final log in logsToDelete) {
      await log.delete();
    }
  }

  static Future<void> saveAllMedications(List<Medication> meds) async {
    final Map<String, Medication> map = {for (var m in meds) m.id: m};
    await _medBox.putAll(map);
  }

  // ── DoseLog CRUD ─────────────────────────────────────────────────

  static List<DoseLog> getAllDoseLogs() {
    return _logBox.values.toList();
  }

  static List<DoseLog> getDoseLogsForDate(DateTime date) {
    return _logBox.values.where((log) {
      return log.date.year == date.year &&
          log.date.month == date.month &&
          log.date.day == date.day;
    }).toList();
  }

  static DoseLog? getDoseLogForMedicationToday(String medicationId) {
    final now = DateTime.now();
    try {
      return _logBox.values.firstWhere(
        (log) =>
            log.medicationId == medicationId &&
            log.date.year == now.year &&
            log.date.month == now.month &&
            log.date.day == now.day,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> logDose({
    required String medicationId,
    required String status,
  }) async {
    final now = DateTime.now();

    // Remove existing log for today if any (so user can change their mind)
    final existing = getDoseLogForMedicationToday(medicationId);
    if (existing != null) {
      await existing.delete();
    }

    final log = DoseLog(
      id: _uuid.v4(),
      medicationId: medicationId,
      date: DateTime(now.year, now.month, now.day),
      status: status,
      actionTime: now,
    );

    await _logBox.put(log.id, log);
  }

  static Future<void> deleteDoseLog(String logId) async {
    await _logBox.delete(logId);
  }

  static Future<void> restoreDoseLog(DoseLog log) async {
    await _logBox.put(log.id, log);
  }

  static Future<void> saveAllDoseLogs(List<DoseLog> logs) async {
    final Map<String, DoseLog> map = {for (var l in logs) l.id: l};
    await _logBox.putAll(map);
  }

  static String generateId() => _uuid.v4();
}
