import 'dart:async';
import 'package:collaborative_asg/reservations/models/reservation.dart';
import 'package:collaborative_asg/reservations/reminders/reminder_device.dart';
import 'package:collaborative_asg/reservations/reminders/notification_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ReminderFixture implements ReminderDevice {
  bool enabled = false, denied = false;
  int enables = 0, disables = 0;
  @override
  Stream<String> get openings => const Stream.empty();
  @override
  String? takeInitialOpening() => null;
  @override
  Future<ReminderDeviceStatus> status(String uid) async =>
      ReminderDeviceStatus(supported: true, enabled: enabled);
  @override
  Future<void> enable(String uid) async {
    enables++;
    if (denied) {
      throw StateError('Allow notifications in your device settings.');
    }
    enabled = true;
  }

  @override
  Future<void> disable(String uid) async {
    disables++;
    enabled = false;
  }

  @override
  Future<void> synchronize(
    String uid,
    List<RideReservation> records,
    Set<String> enabled,
  ) async {}
  @override
  Future<void> endSession(String uid) async {}
}

void main() {
  testWidgets(
    'device reminders can be enabled and disabled without changing reservations',
    (tester) async {
      final device = ReminderFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsPage(uid: 'owner', device: device),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('Enabled'), findsOneWidget);
      expect(device.enables, 1);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget);
      expect(device.disables, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'denied notification permission shows a useful recovery message and keeps reminders off',
    (tester) async {
      final device = ReminderFixture()..denied = true;
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsPage(uid: 'owner', device: device),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        find.text('Allow notifications in your device settings.'),
        findsOneWidget,
      );
      expect(find.text('Off'), findsOneWidget);
      expect(device.enabled, false);
      expect(tester.takeException(), isNull);
    },
  );
}
