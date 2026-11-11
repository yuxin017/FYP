import 'package:collaborative_asg/reservations/models/reservation.dart';
import 'package:collaborative_asg/reservations/reminders/reservation_reminders.dart';
import 'package:collaborative_asg/reservations/reminders/reminder_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/memory_reservation_store.dart';

class ScheduledReminderFixture implements ReminderDevice {
  ScheduledReminderFixture({this.coldStart = false});
  final bool coldStart;
  bool initialized = false;
  String? initial;
  int ended = 0;
  Set<String> scheduled = {};
  @override
  Stream<String> get openings => const Stream.empty();
  @override
  String? takeInitialOpening() {
    final value = initial;
    initial = null;
    return value;
  }

  @override
  Future<ReminderDeviceStatus> status(String uid) async {
    if (!initialized && coldStart) initial = 'reminder-test';
    initialized = true;
    return const ReminderDeviceStatus(supported: true, enabled: true);
  }

  @override
  Future<void> enable(String uid) async {}
  @override
  Future<void> disable(String uid) async {
    scheduled.clear();
  }

  @override
  Future<void> endSession(String uid) async {
    ended++;
    scheduled.clear();
  }

  @override
  Future<void> synchronize(
    String uid,
    List<RideReservation> records,
    Set<String> enabled,
  ) async {
    scheduled = {
      for (final r in records)
        if (r.status == 'confirmed' && enabled.contains(r.id)) r.id,
    };
  }
}

void main() {
  RideReservation record(String status) => RideReservation(
    id: 'reminder-test',
    attractionId: 'castle',
    attractionName: 'Sky Castle',
    slotId: 'slot',
    ticketId: 'ticket',
    status: status,
    startsAt: DateTime.now().add(const Duration(minutes: 16)),
    endsAt: DateTime.now().add(const Duration(minutes: 31)),
  );
  Future<void> show(
    WidgetTester tester,
    MemoryReservationStore store, {
    ReminderDevice? device,
  }) async {
    SharedPreferences.setMockInitialValues({
      ReservationReminderSettings.key(store.uid, 'reminder-test'): true,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationReminders(
          store: store,
          device: device,
          child: const Scaffold(body: Text('Customer application')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'enabled in-app reminder appears once and survives a record refresh without repeating',
    (tester) async {
      final store = MemoryReservationStore()..records = [record('confirmed')];
      addTearDown(store.dispose);
      await show(tester, store);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.pump();
      expect(
        find.textContaining('Sky Castle: your return window is'),
        findsOneWidget,
      );
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      store.changed();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 2));
      expect(
        find.textContaining('Sky Castle: your return window is'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('cancelling a reservation removes its scheduled reminder', (
    tester,
  ) async {
    final store = MemoryReservationStore()..records = [record('confirmed')];
    addTearDown(store.dispose);
    await show(tester, store);
    store.records = [record('cancelled')];
    store.changed();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(
      find.textContaining('Sky Castle: your return window is'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'scheduled delivery suppresses a duplicate in-app reminder and follows cancellation',
    (tester) async {
      final store = MemoryReservationStore()..records = [record('confirmed')],
          device = ScheduledReminderFixture();
      addTearDown(store.dispose);
      await show(tester, store, device: device);
      expect(device.scheduled, {'reminder-test'});
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(
        find.textContaining('Sky Castle: your return window is'),
        findsNothing,
      );
      store.records = [record('cancelled')];
      store.changed();
      await tester.pumpAndSettle();
      expect(device.scheduled, isEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(device.ended, 1);
    },
  );
  testWidgets(
    'a notification cold start opens the signed-in visitor reservations after device initialization',
    (tester) async {
      final store = MemoryReservationStore()..records = [record('confirmed')],
          device = ScheduledReminderFixture(coldStart: true);
      addTearDown(store.dispose);
      await show(tester, store, device: device);
      await tester.pumpAndSettle();
      expect(find.text('My Reservations'), findsOneWidget);
      expect(find.text('Sky Castle'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
