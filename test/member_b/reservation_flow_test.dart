import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collaborative_asg/attractions/models/attraction_slot.dart';
import 'package:collaborative_asg/attractions/models/park_time.dart';
import 'package:collaborative_asg/attractions/models/queue_policy.dart';
import 'package:collaborative_asg/reservations/models/reservation.dart';
import 'package:collaborative_asg/reservations/pages/reserve_attraction_page.dart';
import 'package:collaborative_asg/reservations/pages/select_visitor_page.dart';
import 'package:collaborative_asg/reservations/pages/review_reservation_page.dart';
import 'package:collaborative_asg/reservations/pages/reservation_confirmation_page.dart';
import 'package:collaborative_asg/reservations/pages/my_reservations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/memory_attraction_store.dart';
import '../support/memory_slot_store.dart';
import '../support/memory_reservation_store.dart';

Future<void> revealFlow(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 20 && target.hitTestable().evaluate().isEmpty; i++) {
    final above =
        target.evaluate().isNotEmpty && tester.getCenter(target).dy < 70;
    await tester.drag(
      find.byType(ListView).first,
      Offset(0, above ? 220 : -220),
    );
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  final day = QueuePolicy.parkDay(DateTime.now());
  final ride = testAttraction(
    id: 'castle',
    name: 'Sky Castle',
    minHeightCm: 100,
  );
  final window = QueuePolicy.dayWindows(
    attractionId: ride.id,
    day: day,
    capacity: 10,
  )[2];
  final ticket = AdmissionTicket(
    id: 'real-ticket',
    visitDate: day.toIso8601String().substring(0, 10),
    validUntil: day.toIso8601String().substring(0, 10),
    status: 'used',
  );
  RideReservation record({String status = 'confirmed'}) => RideReservation(
    id: 'saved-reservation',
    attractionId: ride.id,
    attractionName: ride.name,
    slotId: window.id,
    ticketId: ticket.id,
    status: status,
    startsAt: DateTime.now().add(const Duration(hours: 2)),
    endsAt: DateTime.now().add(const Duration(hours: 2, minutes: 15)),
  );
  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'a selected session filling up disables continuation and asks for another time',
    (tester) async {
      final store = MemoryReservationStore(),
          attractions = MemoryAttractionStore()..put(ride),
          slots = MemorySlotStore()..replace([window]);
      addTearDown(store.dispose);
      addTearDown(attractions.dispose);
      addTearDown(slots.dispose);
      await show(
        tester,
        ReserveAttractionPage(
          attraction: ride,
          attractions: attractions,
          slots: slots,
          reservations: store,
          day: day,
          clock: () =>
              QueuePolicy.opens(day).subtract(const Duration(minutes: 5)),
        ),
      );
      await revealFlow(tester, find.text('10:00 AM'));
      await tester.tap(find.text('10:00 AM'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continue with 10:00 AM'),
            )
            .onPressed,
        isNotNull,
      );
      slots.replace([
        AttractionSlot(
          id: window.id,
          attractionId: window.attractionId,
          startsAt: window.startsAt,
          endsAt: window.endsAt,
          capacity: 10,
          bookedCount: 10,
          confirmedCount: 10,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Choose a return time'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'The selected session changed. Choose another available time.',
        ),
        findsOneWidget,
      );
      expect(store.requests, isEmpty);
    },
  );
  testWidgets(
    'available return time opens the real individual visitor selection',
    (tester) async {
      final store = MemoryReservationStore()..tickets = [ticket],
          attractions = MemoryAttractionStore()..put(ride),
          slots = MemorySlotStore()..replace([window]);
      addTearDown(store.dispose);
      addTearDown(attractions.dispose);
      addTearDown(slots.dispose);
      await show(
        tester,
        ReserveAttractionPage(
          attraction: ride,
          attractions: attractions,
          slots: slots,
          reservations: store,
          day: day,
          clock: () =>
              QueuePolicy.opens(day).subtract(const Duration(minutes: 5)),
        ),
      );
      expect(find.text('Virtual Queue Time Slots'), findsOneWidget);
      await revealFlow(tester, find.text('10:00 AM'));
      await tester.tap(find.text('10:00 AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with 10:00 AM'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectVisitorPage), findsOneWidget);
      expect(find.text('Admission used'), findsOneWidget);
      expect(find.text('1 visitor selected'), findsOneWidget);
      expect(find.text('Weekend Adventure'), findsNothing);
    },
  );
  testWidgets(
    'a future date gets automatic times and review requires a ticket for that date',
    (tester) async {
      final futureDay = DateTime(day.year, day.month, day.day + 1);
      final visitDate = ParkTime.date(QueuePolicy.opens(futureDay));
      final store = MemoryReservationStore()..tickets = [ticket];
      final attractions = MemoryAttractionStore()..put(ride);
      final slots = MemorySlotStore();
      addTearDown(store.dispose);
      addTearDown(attractions.dispose);
      addTearDown(slots.dispose);
      await show(
        tester,
        ReserveAttractionPage(
          attraction: ride,
          attractions: attractions,
          slots: slots,
          reservations: store,
          day: futureDay,
          clock: () => QueuePolicy.opens(day),
        ),
      );
      await revealFlow(tester, find.text('9:30 AM'));
      await tester.tap(find.text('9:30 AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with 9:30 AM'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectVisitorPage), findsOneWidget);
      expect(
        find.textContaining('No eligible admission ticket'),
        findsOneWidget,
      );
      store.tickets = [
        AdmissionTicket(
          id: 'future-admission',
          visitDate: visitDate,
          validUntil: visitDate,
          status: 'valid',
        ),
      ];
      store.changed();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review Reservation'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewReservationPage), findsOneWidget);
    },
  );
  testWidgets(
    'missing admission or insufficient height blocks review without fabricated eligibility',
    (tester) async {
      final store = MemoryReservationStore();
      addTearDown(store.dispose);
      await show(
        tester,
        SelectVisitorPage(attraction: ride, slot: window, store: store),
      );
      expect(
        find.textContaining('No eligible admission ticket'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review Reservation'),
            )
            .onPressed,
        isNull,
      );
      store.tickets = [ticket];
      store.visitor = const ReservationVisitor(
        uid: 'visitor-test',
        name: 'Short visitor',
        heightCm: 90,
      );
      store.changed();
      await tester.pumpAndSettle();
      expect(find.text('Height requirement'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review Reservation'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'eligible single visitor reaches review with their ticket and return window',
    (tester) async {
      final store = MemoryReservationStore()..tickets = [ticket];
      addTearDown(store.dispose);
      await show(
        tester,
        SelectVisitorPage(attraction: ride, slot: window, store: store),
      );
      await tester.tap(find.text('Review Reservation'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewReservationPage), findsOneWidget);
      expect(find.text('Test Visitor (You)'), findsOneWidget);
      expect(find.textContaining('10:00 AM–10:15 AM'), findsOneWidget);
      expect(find.text('Confirm Reservation'), findsOneWidget);
      expect(store.requests, isEmpty);
    },
  );
  testWidgets(
    'failed confirmation keeps the same request identity on retry and shows saved server status',
    (tester) async {
      final store = MemoryReservationStore()
        ..error = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Offline',
        );
      addTearDown(store.dispose);
      await show(
        tester,
        ReviewReservationPage(
          attraction: ride,
          slot: window,
          visitor: store.visitor!,
          ticket: ticket,
          store: store,
        ),
      );
      await tester.tap(find.text('Confirm Reservation'));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationConfirmationPage), findsNothing);
      await revealFlow(
        tester,
        find.textContaining('Your selected details have been kept'),
      );
      expect(
        find.textContaining('Your selected details have been kept'),
        findsOneWidget,
      );
      store.error = null;
      store.records = [record()];
      store.changed();
      await tester.tap(find.text('Confirm Reservation'));
      await tester.pumpAndSettle();
      expect(store.requests.length, 2);
      expect(store.requests.toSet().length, 1);
      expect(find.text('Reservation Confirmed'), findsOneWidget);
      expect(find.text('Your place is reserved'), findsOneWidget);
    },
  );
  testWidgets(
    'confirm disables repeated taps while the server request is pending',
    (tester) async {
      final store = MemoryReservationStore()
        ..reserveGate = Completer<ReservationResult>();
      addTearDown(store.dispose);
      await show(
        tester,
        ReviewReservationPage(
          attraction: ride,
          slot: window,
          visitor: store.visitor!,
          ticket: ticket,
          store: store,
        ),
      );
      await tester.tap(find.text('Confirm Reservation'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirming…'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Confirming…'));
      await tester.pump();
      expect(store.requests.length, 1);
      store.records = [record()];
      store.reserveGate!.complete(
        const ReservationResult('saved-reservation', 'confirmed'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your place is reserved'), findsOneWidget);
    },
  );
  testWidgets(
    'replayed response reflects a cancelled record instead of showing false confirmation',
    (tester) async {
      final store = MemoryReservationStore()
        ..records = [record(status: 'cancelled')];
      addTearDown(store.dispose);
      await show(
        tester,
        ReservationConfirmationPage(
          result: const ReservationResult('saved-reservation', 'confirmed'),
          attraction: ride,
          slot: window,
          store: store,
        ),
      );
      expect(find.text('Reservation cancelled'), findsOneWidget);
      expect(find.text('Your place is reserved'), findsNothing);
    },
  );
  testWidgets(
    'cancellation requires confirmation and retries with one request identity',
    (tester) async {
      final store = MemoryReservationStore()
        ..records = [record()]
        ..error = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Offline',
        );
      addTearDown(store.dispose);
      await show(tester, MyReservationsPage(store: store));
      await tester.tap(find.text('Cancel reservation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep reservation'));
      await tester.pumpAndSettle();
      expect(store.cancellations, isEmpty);
      await tester.tap(find.text('Cancel reservation'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel reservation'));
      await tester.pumpAndSettle();
      expect(store.cancellations.length, 1);
      store.error = null;
      await tester.tap(find.text('Cancel reservation'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel reservation'));
      await tester.pumpAndSettle();
      expect(store.cancellations.toSet().length, 1);
      expect(find.text('cancelled'), findsOneWidget);
      expect(find.text('Cancel reservation'), findsNothing);
    },
  );
}
