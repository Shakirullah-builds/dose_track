import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:dose_tracker/core/models/medication.dart';

/// Centralized service for scheduling dose reminder notifications.
///
/// Why a dedicated class instead of inline logic?
/// → Keeps notification concerns isolated from UI/state layers.
/// → Easy to swap implementations later (e.g., WorkManager for background).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationService(this._plugin);

  // ── Initialisation ──────────────────────────────────────────────────

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      // Tap handler — expand later if needed
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // TODO: Navigate to the correct dose card when tapped.
    // For the MVP, simply opening the app is enough.
  }

  // ── Permissions ─────────────────────────────────────────────────────

  /// Requests notification permission.
  ///
  /// Android 13+ (API 33) requires explicit runtime permission.
  /// iOS prompts automatically via DarwinInitializationSettings above,
  /// but we call this again to handle the case where the user denied before.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Request POST_NOTIFICATIONS (Android 13+)
      final granted = await android?.requestNotificationsPermission();

      // Request exact alarm permission (Android 14+)
      await android?.requestExactAlarmsPermission();

      return granted ?? false;
    }

    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  // ── Scheduling ──────────────────────────────────────────────────────

  /// Schedules a daily notification at the exact time stored in [med].
  ///
  /// Uses `zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.time`
  /// which tells the OS to repeat the notification every day at that time.
  ///
  /// The notification ID is derived from the medication's UUID hash so each
  /// med gets a unique, stable ID we can cancel later.
  Future<void> scheduleDoseReminder(Medication med) async {
    final scheduledTZ = _nextInstanceOfTime(med.scheduledTime);

    final androidDetails = AndroidNotificationDetails(
      'dose_reminders', // channel ID
      'Dose Reminders', // channel name
      channelDescription: 'Daily medication dose reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id: _notificationId(med.id),
      title: '💊 Time for ${med.name}',
      body:
          '${med.dosage} ${med.unit} — ${med.instructions ?? "Take your dose"}',
      scheduledDate: scheduledTZ, // ✅ correct name
      notificationDetails: details, // ✅ correct name
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Cancellation ────────────────────────────────────────────────────

  /// Cancel reminder for a specific medication (e.g., when deleted).
  Future<void> cancelReminder(String medicationId) async {
    await _plugin.cancel(id: _notificationId(medicationId));
  }

  /// Cancel all scheduled reminders.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Computes the next occurrence of [timeStr] (format "HH:mm") as a
  /// TZDateTime. If the time has already passed today, it schedules for
  /// tomorrow — this prevents the "notification fires immediately" bug.
  tz.TZDateTime _nextInstanceOfTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time already passed today, push to tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Generates a stable 32-bit int ID from the UUID string.
  /// Notification IDs must be int, so we use hashCode.
  int _notificationId(String uuid) => uuid.hashCode;
}

// ── Riverpod Provider ───────────────────────────────────────────────────

/// Single-instance provider. Reads the same FlutterLocalNotificationsPlugin
/// across the app. No static singletons needed.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FlutterLocalNotificationsPlugin());
});
