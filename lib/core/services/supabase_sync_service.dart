import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dose_tracker/core/services/hive_service.dart';

/// Provider for the Supabase Sync Service
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService(Supabase.instance.client);
});

/// A background worker service that syncs local Hive data to Supabase.
class SupabaseSyncService {
  final SupabaseClient _supabase;

  SupabaseSyncService(this._supabase);

  /// Reads all medications from Hive and performs an upsert to the 'medications' table.
  Future<void> syncMedicationsUp() async {
    try {
      final meds = HiveService.getAllMedications();
      if (meds.isEmpty) return;

      final List<Map<String, dynamic>> medsData = meds.map((m) => {
        'id': m.id,
        'name': m.name,
        'dosage': m.dosage,
        'unit': m.unit,
        'scheduled_time': m.scheduledTime,
        'instructions': m.instructions,
        'created_at': m.createdAt.toIso8601String(),
      }).toList();

      // Upsert medications (matches by 'id' primary key usually configured in Supabase)
      await _supabase.from('medications').upsert(medsData);
      debugPrint('Sync: Medications synced up to Supabase successfully.');
    } catch (e) {
      debugPrint('Sync Error (Medications): $e');
      // In a real production app, we could log this to a crash reporter
    }
  }

  /// Reads all dose logs from Hive and performs an upsert to the 'dose_logs' table.
  Future<void> syncLogsUp() async {
    try {
      final logs = HiveService.getAllDoseLogs();
      if (logs.isEmpty) return;

      final List<Map<String, dynamic>> logsData = logs.map((l) => {
        'id': l.id,
        'medication_id': l.medicationId,
        'date': l.date.toIso8601String(),
        'status': l.status,
        'action_time': l.actionTime?.toIso8601String(),
      }).toList();

      // Upsert dose logs
      await _supabase.from('dose_logs').upsert(logsData);
      debugPrint('Sync: Dose logs synced up to Supabase successfully.');
    } catch (e) {
      debugPrint('Sync Error (Dose Logs): $e');
    }
  }
}
