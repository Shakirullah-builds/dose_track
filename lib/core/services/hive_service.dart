import 'package:hive_flutter/hive_flutter.dart';
import 'package:dose_vault/core/models/medication.dart';
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
    await Hive.openBox('settings');

    // Run one-off database migration to repair physical-to-logical dates for alpha testers
    await _migratePhysicalToLogicalDates();
  }

  static Future<void> _migratePhysicalToLogicalDates() async {
    try {
      final logs = _logBox.values.toList();
      var migratedCount = 0;
      for (final log in logs) {
        final actionTime = log.actionTime ?? log.date;
        final correctLogical = getLogicalDate(actionTime);
        if (log.date.year != correctLogical.year ||
            log.date.month != correctLogical.month ||
            log.date.day != correctLogical.day) {
          final updatedLog = DoseLog(
            id: log.id,
            medicationId: log.medicationId,
            date: correctLogical,
            status: log.status,
            actionTime: log.actionTime,
          );
          await _logBox.put(log.id, updatedLog);
          migratedCount++;
        }
      }
      if (migratedCount > 0) {
        // ignore: avoid_print
        print('📦 HiveService: Migrated $migratedCount physical logs to logical rollover dates.');
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ HiveService Migration Error: $e');
    }
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

  static DateTime getLogicalDate(DateTime time) {
    final isLateNight = time.hour < 3;
    final logical = isLateNight ? time.subtract(const Duration(days: 1)) : time;
    return DateTime(logical.year, logical.month, logical.day);
  }

  static List<DoseLog> getDoseLogsForDate(DateTime date) {
    return _logBox.values.where((log) {
      return log.date.year == date.year &&
          log.date.month == date.month &&
          log.date.day == date.day;
    }).toList();
  }

  static DoseLog? getDoseLogForMedicationToday(String medicationId) {
    final logicalToday = getLogicalDate(DateTime.now());
    try {
      return _logBox.values.firstWhere(
        (log) =>
            log.medicationId == medicationId &&
            log.date.year == logicalToday.year &&
            log.date.month == logicalToday.month &&
            log.date.day == logicalToday.day,
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
    final logicalToday = getLogicalDate(now);

    // Remove existing log for today if any (so user can change their mind)
    final existing = getDoseLogForMedicationToday(medicationId);
    if (existing != null) {
      await existing.delete();
    }

    final log = DoseLog(
      id: _uuid.v4(),
      medicationId: medicationId,
      date: logicalToday,
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

  static Future<void> clearAll() async {
    await _medBox.clear();
    await _logBox.clear();
  }

  static String generateId() => _uuid.v4();
}
