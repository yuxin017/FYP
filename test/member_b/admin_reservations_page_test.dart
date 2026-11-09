import 'dart:async';

import 'package:collaborative_asg/admin/portal/admin_theme.dart';
import 'package:collaborative_asg/admin/reservations/data/admin_reservation_repository.dart';
import 'package:collaborative_asg/admin/reservations/reservations_admin_page.dart';
import 'package:collaborative_asg/attractions/models/park_time.dart';
import 'package:collaborative_asg/reservations/models/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void surface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  AdminReservation reservation(
    String id,
    String name,
    String status, {
    String ride = 'Castle',
  }) => AdminReservation(
    visitorId: 'visitor-$id',
    visitorName: name,
    booking: RideReservation(
      id: id,
      attractionId: 'ride-$ride',
      attractionName: ride,
      slotId: 'slot-$id',
      ticketId: 'ticket-$id',
      status: status,
      startsAt: ParkTime.instant(2026, 11, 7, 16, 45),
      endsAt: ParkTime.instant(2026, 11, 7, 17, 0),
    ),
  );

  Widget page(Stream<List<AdminReservation>> Function(DateTime) watchDay) =>
      MaterialApp(
        theme: AdminTheme.data,
        home: ReservationsAdminPage(watchDay: watchDay),
      );

  testWidgets(
    'staff can find and inspect a saved booking as its status updates',
    (tester) async {
      surface(tester, const Size(1280, 900));
      final stream = StreamController<List<AdminReservation>>();
      addTearDown(stream.close);
      await tester.pumpWidget(page((_) => stream.stream));
      stream.add([
        reservation('r-1', 'Amir Tan', 'confirmed'),
        reservation('r-2', 'Lin Wei', 'checked_in', ride: 'Carousel'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 to 2 of 2 results'), findsOneWidget);
      expect(find.text('4:45 PM–5:00 PM'), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'amir');
      await tester.pumpAndSettle();
      expect(find.text('Amir Tan'), findsOneWidget);
      expect(find.text('Lin Wei'), findsNothing);
      await tester.tap(find.byTooltip('View details for r-1'));
      await tester.pumpAndSettle();
      expect(find.text('Reservation details'), findsOneWidget);
      expect(find.text('ticket-r-1'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      stream.add([reservation('r-1', 'Amir Tan', 'cancelled')]);
      await tester.pumpAndSettle();
      expect(find.text('Cancelled'), findsNWidgets(2));
      await tester.tap(find.text('All Statuses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmed').last);
      await tester.pumpAndSettle();
      expect(find.text('No matching reservations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visit date switches the data source and clears the previous date results',
    (tester) async {
      surface(tester, const Size(1280, 900));
      final requested = <DateTime>[];
      await tester.pumpWidget(
        page((date) {
          requested.add(date);
          return Stream.value(
            requested.length == 1
                ? [reservation('r-1', 'Amir Tan', 'confirmed')]
                : <AdminReservation>[],
          );
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Amir Tan'), findsOneWidget);
      final today = requested.single;
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(ReservationsAdminPage)),
      );
      await tester.tap(find.textContaining('Visit date  '));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).last,
        localizations.formatCompactDate(tomorrow),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(requested.last, tomorrow);
      expect(find.text('No reservations for this date'), findsOneWidget);
      expect(find.text('Amir Tan'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a narrow screen can retry a failed Firestore read', (
    tester,
  ) async {
    surface(tester, const Size(390, 900));
    var requests = 0;
    await tester.pumpWidget(
      page((_) {
        requests++;
        return requests == 1
            ? Stream.error(StateError('Could not read bookings'))
            : Stream.value(<AdminReservation>[]);
      }),
    );
    await tester.pumpAndSettle();
    final retry = find.text('Try again');
    await tester.scrollUntilVisible(
      retry,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('No reservations for this date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
