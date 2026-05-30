import 'package:dose_vault/app_shell.dart';
import 'package:dose_vault/core/services/hive_service.dart';
import 'package:dose_vault/core/services/notification_service.dart';
import 'package:dose_vault/core/theme/app_theme.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dose_vault/firebase_options.dart';
import 'package:dose_vault/core/services/supabase_sync_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dose_vault/features/onboarding/onboarding_screen.dart';

void main() async {
  try {
    // Ensure the native bridge is locked in before we run async code
    WidgetsFlutterBinding.ensureInitialized();

    // Make the status bar transparent to blend with the app background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Catch all uncaught "fatal" errors from the Flutter framework
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Catch all uncaught asynchronous errors that aren't handled by the Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // 1. Initialize Local Database
    await HiveService.init();

    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    // 2. Initialize Timezones (CRITICAL for exact background alarms)
    tz.initializeTimeZones();

    // 3. Set tz.local to the device's actual timezone
    _setLocalTimezone();

    // 4. Initialize the Notification Engine
    final plugin = FlutterLocalNotificationsPlugin();
    final notificationService = NotificationService(plugin);
    await notificationService.init();

    // Wipe legacy alarms to prevent conflicts with new push system
    await notificationService.cancelAllLocalAlarms();

    final settingsBox = Hive.box('settings');
    final hasSeenOnboarding = settingsBox.get('has_seen_onboarding', defaultValue: false);

    runApp(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'DoseVault',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: hasSeenOnboarding ? const AppShell() : const OnboardingScreen(),
        ),
      ),
    );

    // Fire-and-forget background network tasks so the UI doesn't freeze on boot!
    Future.microtask(() async {
      try {
        // 1.5 Silent Anonymous Login (Moved here so it doesn't block runApp if network hangs)
        if (Supabase.instance.client.auth.currentSession == null) {
          await Supabase.instance.client.auth.signInAnonymously().timeout(const Duration(seconds: 10));
        }

        // Capture FCM token and sync it to Supabase
        await SupabaseSyncService(Supabase.instance.client).syncDeviceToken();
      } catch (e) {
        debugPrint('Background Boot Task Error: $e');
      }
    });
  } catch (e, stack) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(
                'CRITICAL BOOT ERROR:\n\n$e\n\n$stack',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      debugPrint(
        '🕐 Timezone set to: ${location.name} (UTC${offset.isNegative ? "" : "+"}${offset.inHours})',
      );
      return;
    }
  }

  // Fallback: if no exact match found, stay on UTC (shouldn't happen)
  debugPrint('⚠️ Could not detect timezone, defaulting to UTC');
}
