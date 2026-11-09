import 'package:collaborative_asg/reservations/models/reservation.dart';
import 'package:collaborative_asg/reservations/reminders/reservation_reminders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/memory_reservation_store.dart';

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
  Future<void> show(WidgetTester tester, MemoryReservationStore store) async {
    SharedPreferences.setMockInitialValues({
      ReservationReminderSettings.key(store.uid, 'reminder-test'): true,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationReminders(
          store: store,
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
}
