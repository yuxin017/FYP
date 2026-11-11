import 'package:collaborative_asg/reservations/models/reservation.dart';
import 'package:collaborative_asg/reservations/reminders/reminder_device_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[], pending = <int, Map<String, dynamic>>{};
  var allowed = true;
  RideReservation record({String status = 'confirmed'}) => RideReservation(
    id: 'native-reservation',
    attractionId: 'castle',
    attractionName: 'Sky Castle',
    slotId: 'slot',
    ticketId: 'ticket',
    status: status,
    startsAt: DateTime.now().add(const Duration(hours: 2)),
    endsAt: DateTime.now().add(const Duration(hours: 2, minutes: 15)),
  );
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    allowed = true;
    calls.clear();
    pending.clear();
    SharedPreferences.setMockInitialValues({
      NativeReminderDevice.preference('owner'): true,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if ([
            'initialize',
            'areNotificationsEnabled',
            'canScheduleExactNotifications',
            'requestNotificationsPermission',
            'requestExactAlarmsPermission',
          ].contains(call.method)) {
            return allowed;
          }
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {'notificationLaunchedApp': false};
          }
          if (call.method == 'pendingNotificationRequests') {
            return pending.values.toList();
          }
          if (['zonedSchedule', 'show'].contains(call.method)) {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            pending[args['id'] as int] = {
              'id': args['id'],
              'title': args['title'],
              'body': args['body'],
              'payload': args['payload'],
            };
          }
          if (call.method == 'cancel') {
            pending.remove((call.arguments as Map)['id']);
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'OS scheduling uses the actual instant fifteen minutes before the window and survives stream refreshes',
    () async {
      final device = NativeReminderDevice(), booking = record();
      await device.synchronize('owner', [booking], {booking.id});
      final schedule =
          calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
              as Map;
      expect(schedule['payload'], 'ride:owner:${booking.id}');
      expect(schedule['timeZoneName'], 'UTC');
      expect(
        DateTime.parse('${schedule['scheduledDateTime']}Z')
            .toUtc()
            .difference(
              booking.startsAt.toUtc().subtract(const Duration(minutes: 15)),
            )
            .inSeconds
            .abs(),
        lessThan(2),
      );
      await device.synchronize('owner', [booking], {booking.id});
      expect(calls.where((c) => c.method == 'zonedSchedule'), hasLength(1));
      pending.clear();
      await device.synchronize('owner', [booking], {booking.id});
      expect(calls.where((c) => c.method == 'zonedSchedule'), hasLength(2));
    },
  );
  test(
    'cancellation removes the OS notification and a later opt-in can schedule again',
    () async {
      final device = NativeReminderDevice(), booking = record();
      await device.synchronize('owner', [booking], {booking.id});
      await device.synchronize('owner', [], {});
      expect(pending, isEmpty);
      await device.synchronize('owner', [booking], {booking.id});
      expect(pending, hasLength(1));
      await device.disable('owner');
      expect(pending, isEmpty);
      expect((await device.status('owner')).enabled, false);
    },
  );
  test(
    'permission refusal never reports device reminders as enabled',
    () async {
      SharedPreferences.setMockInitialValues({});
      allowed = false;
      final device = NativeReminderDevice();
      await expectLater(device.enable('owner'), throwsStateError);
      expect((await device.status('owner')).enabled, false);
      expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
    },
  );
  test(
    'ending one account session cancels its scheduled notifications and preserves another owner',
    () async {
      final device = NativeReminderDevice(), booking = record();
      await device.synchronize('owner', [booking], {booking.id});
      pending[123] = {
        'id': 123,
        'title': 'Another owner',
        'body': 'Private',
        'payload': 'ride:other:other-reservation',
      };
      await device.endSession('owner');
      expect(pending.keys, [123]);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          NativeReminderDevice.preference('owner'),
        ),
        true,
      );
    },
  );
}
