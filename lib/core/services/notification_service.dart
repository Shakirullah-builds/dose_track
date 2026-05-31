import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dose_vault/features/notifications/full_screen_alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:dose_vault/core/models/medication.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Centralized service for scheduling dose reminder notifications.
///
/// Why a dedicated class instead of inline logic?
/// → Keeps notification concerns isolated from UI/state layers.
/// → Easy to swap implementations later (e.g., WorkManager for background).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  String? _initialPayload;

  NotificationService(this._plugin);

  String? get initialPayload => _initialPayload;
  void clearInitialPayload() => _initialPayload = null;

  // ── Initialisation ──────────────────────────────────────────────────

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      'ic_notification',
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
      // Tap handler
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Retrieve notification that launched the app from terminated state
    final notificationAppLaunchDetails =
        await _plugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      _initialPayload =
          notificationAppLaunchDetails?.notificationResponse?.payload;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => FullScreenAlarm(payload: payload),
        ),
      );
    }
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
    final tz.TZDateTime scheduledTime = _nextInstanceOfTime(med.scheduledTime);

    // Encode medication details into the payload so the full-screen
    // alarm screen can display the medication name, dosage, and unit.
    final payload = jsonEncode({
      'id': med.id,
      'name': med.name,
      'dosage': med.dosage,
      'unit': med.unit,
      'instructions': med.instructions,
    });

    await _plugin.zonedSchedule(
      id: _notificationId(med.id),
      title: '💊 Time for ${med.name} (${med.dosage.toString().replaceAll(RegExp(r'\.0$'), '')}${med.unit})',
      body: (med.instructions != null && med.instructions!.trim().isNotEmpty)
          ? 'Note: ${med.instructions}'
          : 'Open DoseVault to log your dose.',
      scheduledDate: scheduledTime,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          // New channel ID — forces Android to create a fresh channel
          // with our custom sound, bypassing the cached old channel.
          'dose_alarm_channel_v3',
          'Medication Alarms',
          channelDescription: 'Time-critical medication dose reminders',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_notification',
          color: const Color(0xFF4A90D9),
          
          // Custom sound from res/raw/dose_alarm.mp3
          sound: const RawResourceAndroidNotificationSound('dose_alarm'),
          playSound: true,
          // Full-screen intent — takes over the lock screen
          fullScreenIntent: true,
          // Tell Android this is a time-critical alarm, not a social notification
          category: AndroidNotificationCategory.alarm,
          // Treat as an alarm for audio focus and routing
          audioAttributesUsage: AudioAttributesUsage.alarm,
          // Looping (insistent) flag: 4 corresponds to native Android's FLAG_INSISTENT.
          // This will loop the notification sound continuously until clicked or dismissed.
          additionalFlags: Int32List.fromList(<int>[4]),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  // ── Cancellation ────────────────────────────────────────────────────

  /// Cancel reminder for a specific medication (e.g., when deleted).
  Future<void> cancelReminder(String medicationId) async {
    await _plugin.cancel(id: _notificationId(medicationId));
  }

  /// Cancel all scheduled local alarms.
  Future<void> cancelAllLocalAlarms() async {
    await _plugin.cancelAll();
  }

  /// Cancel all scheduled reminders (legacy).
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
