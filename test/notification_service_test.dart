import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dose_vault/core/services/notification_service.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// 1. Create a Fake Plugin
class MockLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

// 2. Register fallback values for non-primitive types mocktail needs
class FakeTZDateTime extends Fake implements tz.TZDateTime {}
class FakeNotificationDetails extends Fake implements NotificationDetails {}

void main() {
  late NotificationService notificationService;
  late MockLocalNotificationsPlugin mockPlugin;

  setUpAll(() {
    // Mocktail requires fallback values for custom types used with any()
    registerFallbackValue(FakeTZDateTime());
    registerFallbackValue(FakeNotificationDetails());
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);

    // Initialize timezone data so _nextInstanceOfTime works
    tz_data.initializeTimeZones();
  });

  setUp(() {
    mockPlugin = MockLocalNotificationsPlugin();
    notificationService = NotificationService(mockPlugin);
  });

  test('scheduleDoseReminder calls zonedSchedule with correct Max Priority parameters', () async {
    // Arrange: Create a fake medication
    final testMed = Medication(
      id: '123',
      name: 'Amoxicillin',
      dosage: 500,
      unit: 'mg',
      scheduledTime: '08:00',
      createdAt: DateTime.now(),
    );

    // Stub: Use NAMED parameters to match the actual API signature
    when(() => mockPlugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
        )).thenAnswer((_) async {});

    // Act: Run your method
    await notificationService.scheduleDoseReminder(testMed);

    // Assert: Verify the plugin was told to fire an alarm with correct config
    verify(() => mockPlugin.zonedSchedule(
          id: testMed.id.hashCode,
          title: '💊 Time for Amoxicillin',
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        )).called(1);
  });
}