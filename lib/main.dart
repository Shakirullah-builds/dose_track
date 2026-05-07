import 'package:dose_tracker/app_shell.dart';
import 'package:dose_tracker/core/services/hive_service.dart';
import 'package:dose_tracker/core/services/notification_service.dart';
import 'package:dose_tracker/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  // Ensure the native bridge is locked in before we run async code
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Local Database
  await HiveService.init();

  // 2. Initialize Timezones (CRITICAL for exact background alarms)
  tz.initializeTimeZones();

  // 3. Set tz.local to the device's actual timezone
  //    Without this, tz.local defaults to UTC and all alarms fire at wrong times.
  _setLocalTimezone();

  // 4. Initialize the Notification Engine
  final plugin = FlutterLocalNotificationsPlugin();
  final notificationService = NotificationService(plugin);
  await notificationService.init();

  // 5. Request permissions (Android 13+ requires POST_NOTIFICATIONS)
  await notificationService.requestPermissions();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: MaterialApp(
        title: 'Dose Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppShell(),
      ),
    ),
  );
}

/// Detects the device's UTC offset and sets tz.local to a matching timezone.
///
/// Why this matters: The `timezone` package defaults tz.local to UTC.
/// If your device is UTC+1 (WAT/Lagos), a "6:00 PM" TZDateTime in UTC
/// actually means 7:00 PM on your wall clock. This function fixes that.
void _setLocalTimezone() {
  final now = DateTime.now();
  final offset = now.timeZoneOffset;

  // Search the timezone database for a location matching our offset
  for (final location in tz.timeZoneDatabase.locations.values) {
    final locNow = tz.TZDateTime.now(location);
    if (locNow.timeZoneOffset == offset) {
      tz.setLocalLocation(location);
      debugPrint('🕐 Timezone set to: ${location.name} (UTC${offset.isNegative ? "" : "+"}${offset.inHours})');
      return;
    }
  }

  // Fallback: if no exact match found, stay on UTC (shouldn't happen)
  debugPrint('⚠️ Could not detect timezone, defaulting to UTC');
}