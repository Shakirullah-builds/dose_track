import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dose_vault/core/services/hive_service.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final isInitialSyncingProvider = StateProvider<bool>((ref) => false);

/// Provider for the Supabase Sync Service
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService(Supabase.instance.client);
});

/// A background worker service that syncs local Hive data to Supabase.
class SupabaseSyncService {
  final SupabaseClient _supabase;

  SupabaseSyncService(this._supabase);

  /// Fetches all cloud data from Supabase and merges it into the local Hive boxes.
  Future<void> syncDownOnLaunch(
    WidgetRef ref, {
    required VoidCallback onComplete,
    required Function(String) onError,
  }) async {
    // ── Fresh user fast-path ──────────────────────────────────────────
    // If there's no authenticated user (brand new install or signed out),
    // skip the sync entirely. Don't even set the syncing flag — this
    // prevents the "Restoring data..." spinner from flashing for new users.
    if (_supabase.auth.currentUser == null) {
      onComplete();
      return;
    }

    // ── Fresh anonymous user fast-path ────────────────────────────────
    // On a fresh install the app auto-signs-in anonymously, so currentUser
    // is NOT null. But there's nothing in the cloud to restore. We detect
    // this by checking a local flag + empty Hive. Once a real sync succeeds
    // we flip the flag so returning users DO get the spinner.
    final settingsBox = await Hive.openBox('settings');
    final hasSyncedBefore = settingsBox.get('has_synced_before', defaultValue: false);
    if (!hasSyncedBefore && HiveService.getAllMedications().isEmpty) {
      onComplete();
      return;
    }

    ref.read(isInitialSyncingProvider.notifier).state = true;
    try {

      // 1. Fetch Medications
      final medsData = await _supabase.from('medications').select();
      final List<Medication> medsToSave = [];
      for (final json in medsData) {
        medsToSave.add(
          Medication(
            id: json['id'],
            name: json['name'],
            dosage: (json['dosage'] as num).toDouble(),
            unit: json['unit'],
            scheduledTime: json['scheduled_time'],
            instructions: json['instructions'],
            createdAt: DateTime.parse(json['created_at']),
          ),
        );
      }

      // 2. Fetch Dose Logs
      final logsData = await _supabase.from('dose_logs').select();
      final List<DoseLog> logsToSave = [];
      for (final json in logsData) {
        logsToSave.add(
          DoseLog(
            id: json['id'],
            medicationId: json['medication_id'],
            date: DateTime.parse(json['date']),
            status: json['status'],
            actionTime: json['action_time'] != null
                ? DateTime.parse(json['action_time'])
                : null,
          ),
        );
      }

      // 3. Save to Hive
      await HiveService.saveAllMedications(medsToSave);
      await HiveService.saveAllDoseLogs(logsToSave);

      // Mark that we've synced at least once so the fresh-install
      // fast-path doesn't skip future syncs on reinstall/new device.
      await settingsBox.put('has_synced_before', true);

      debugPrint('Sync: Successfully synced down from Supabase on launch.');

      // 4. Trigger UI update
      onComplete();
    } on SocketException catch (_) {
      onError("Offline: Could not check for backed-up data.");
    } catch (e) {
      // Some networking errors in Supabase might not surface as a pure SocketException depending on the platform/wrapper
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        onError("Offline: Could not check for backed-up data.");
      } else {
        debugPrint('Sync Error (DownSync): $e');
      }
    } finally {
      ref.read(isInitialSyncingProvider.notifier).state = false;
    }
  }

  /// Reads all medications from Hive and performs an upsert to the 'medications' table.
  Future<void> syncMedicationsUp() async {
    try {
      final meds = HiveService.getAllMedications();
      if (meds.isEmpty) return;

      final List<Map<String, dynamic>> medsData = meds
          .map(
            (m) => {
              'id': m.id,
              'user_id': _supabase.auth.currentUser!.id,
              'name': m.name,
              'dosage': m.dosage,

              'unit': m.unit,
              'scheduled_time': m.scheduledTime,
              'instructions': m.instructions,
              'created_at': m.createdAt.toIso8601String(),
            },
          )
          .toList();

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

      final List<Map<String, dynamic>> logsData = logs
          .map(
            (l) => {
              'id': l.id,
              'user_id': _supabase.auth.currentUser!.id,
              'medication_id': l.medicationId,
              'date': l.date.toIso8601String(),
              'status': l.status,
              'action_time': l.actionTime?.toIso8601String(),
            },
          )
          .toList();

      // Upsert dose logs
      await _supabase.from('dose_logs').upsert(logsData);
      debugPrint('Sync: Dose logs synced up to Supabase successfully.');
    } catch (e) {
      debugPrint('Sync Error (Dose Logs): $e');
    }
  }

  /// Captures the device FCM token and syncs it to Supabase
  Future<void> syncDeviceToken() async {
    try {
      if (_supabase.auth.currentUser == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _supabase.from('user_tokens').upsert({
          'user_id': _supabase.auth.currentUser!.id,
          'fcm_token': token,
        });
        debugPrint('Sync: Device FCM token synced to Supabase successfully.');
      }
    } catch (e) {
      debugPrint('Sync Error (Device Token): $e');
    }
  }
}
