import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collaborative_asg/visitor/models/tickets.dart';
import 'package:collaborative_asg/visitor/services/ticket_repository.dart';
import 'package:collaborative_asg/visitor/services/ticket_journey.dart';
import 'package:collaborative_asg/visitor/pages/tickets_page.dart';
import 'package:collaborative_asg/visitor/pages/ticket_wallet_screens.dart';

class FakeTickets extends TicketRepository {
  @override
  final String? userId;
  bool failOnce = false;
  Completer<void>? completion;
  final requests = <TicketCheckout>[];
  FakeTickets({this.userId = 'alice'});
  @override
  Stream<List<TicketPackage>> packages() => Stream.value(const [
    TicketPackage(
      id: 'general-admission',
      name: '1-Day Theme Park Pass',
      priceMinor: 14000,
      childPriceMinor: 11000,
    ),
  ]);
  @override
  Stream<List<ParkTicket>> tickets() => Stream.value([]);
  @override
  Stream<List<TicketOrder>> orders() => Stream.value([]);
  @override
  Stream<BookingProfile> profile() => Stream.value(
    const BookingProfile(
      uid: 'alice',
      fullName: 'Alice Visitor',
      email: 'alice@example.com',
      points: 2450,
    ),
  );
  @override
  Future<void> checkout(TicketCheckout request) async {
    requests.add(request);
    if (failOnce) {
      failOnce = false;
      throw StateError('Offline');
    }
    if (completion != null) await completion!.future;
  }
}

TicketCartLine line({int adults = 1, int children = 0}) => TicketCartLine(
  id: 'line',
  packageId: 'general-admission',
  packageName: '1-Day Theme Park Pass',
  visitDate: visitDateString(parkToday()),
  adults: adults,
  children: children,
  adultPriceMinor: 14000,
  childPriceMinor: 11000,
);
Future<TicketJourney> ready(FakeTickets repo) async {
  final j = TicketJourney(repo, PendingTicketCheckoutStore());
  await j.start();
  await Future<void>.delayed(Duration.zero);
  return j;
}

void fillGuests(TicketJourney j) {
  for (final g in [...j.guests]) {
    j.updateGuest(
      g.copyWith(fullName: 'Guest Visitor', email: 'guest@example.com'),
    );
  }
  j.acceptTerms(true);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'ticket QR cards fit narrow phones and preserve real ticket identifiers',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final j = TicketJourney(FakeTickets(), PendingTicketCheckoutStore());
      await j.start();
      addTearDown(j.dispose);
      final ticket = ParkTicket(
        id: '${'a' * 48}_1',
        orderId: 'a' * 48,
        packageName: '1-Day Theme Park Pass',
        visitDate: visitDateString(parkToday()),
        status: 'valid',
        guestName: 'Alice Visitor',
      );
      j.tickets = [ticket];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DigitalTicketsScreen(journey: j, tickets: [ticket]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alice Visitor'), findsOneWidget);
      expect(ticket.qrData, 'TP1:${ticket.id}');
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Add to Wallet'));
      await tester.tap(find.text('Add to Wallet'));
      await tester.pumpAndSettle();
      expect(j.wallet, contains(ticket.id));
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'Malaysia dates and adult/child totals are independent of local timezone',
    () {
      expect(
        visitDateString(parkToday(DateTime.utc(2026, 11, 6, 18))),
        '2026-11-07',
      );
      expect(line(adults: 2, children: 1).subtotal, 39000);
    },
  );
  test(
    'guest requirements, actual points balance, and cart limits are enforced',
    () async {
      final j = await ready(FakeTickets());
      addTearDown(j.dispose);
      j.add(line(adults: 2, children: 1));
      expect(j.quantity, 3);
      expect(j.guestsComplete, false);
      expect(j.subtotal, 39000);
      expect(await j.pay('fpx'), false);
      fillGuests(j);
      expect(j.guestsComplete, true);
      j.setPoints(99999);
      expect(j.pointsUsed, 2400);
      expect(j.total, 36600);
      expect(() => j.add(line(adults: 8)), throwsStateError);
      j.changeCount('line', 1, 1);
      expect(j.guests.length, 2);
      expect(j.termsAccepted, false);
    },
  );
  test('double pay and uncertain retry reuse one immutable checkout', () async {
    final repo = FakeTickets()..completion = Completer<void>();
    final j = await ready(repo);
    addTearDown(j.dispose);
    j.add(line());
    fillGuests(j);
    final first = j.pay('fpx');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await j.pay('fpx'), false);
    expect(repo.requests.length, 1);
    repo.completion!.complete();
    expect(await first, true);
    expect(j.cart, isEmpty);
    final failed = FakeTickets()..failOnce = true;
    final a = await ready(failed);
    a.add(line());
    fillGuests(a);
    expect(await a.pay('fpx'), false);
    final id = failed.requests.single.requestId;
    a.dispose();
    final restored = await ready(failed);
    addTearDown(restored.dispose);
    expect(restored.pending!.requestId, id);
    expect(await restored.pay('card'), true);
    expect(failed.requests.last.requestId, id);
    expect(failed.requests.last.paymentMethod, 'fpx');
  });
  test('saved cart and pending checkout are scoped to each account', () async {
    final a = await ready(FakeTickets());
    a.add(line());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    a.dispose();
    final b = await ready(FakeTickets(userId: 'bob'));
    addTearDown(b.dispose);
    expect(b.cart, isEmpty);
    final restored = await ready(FakeTickets());
    addTearDown(restored.dispose);
    expect(restored.cart.single.quantity, 1);
  });
  testWidgets(
    'separate Figma screens retain adult and child fares through checkout',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repo = FakeTickets();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketsPage(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day & Annual\nPasses'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Your Day Pass'), findsOneWidget);
      await tester.tap(find.byKey(const Key('select-general-admission')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('More children'));
      await tester.tap(find.byTooltip('More children'));
      await tester.pump();
      expect(find.text('RM 250'), findsOneWidget);
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      expect(find.text('Your Cart'), findsOneWidget);
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
      expect(find.text('Guest Details'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continue to Review'),
            )
            .onPressed,
        isNull,
      );
      final state = tester.state<TicketsPageState>(find.byType(TicketsPage));
      fillGuests(state.journey);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to Review'));
      await tester.pumpAndSettle();
      expect(find.text('Review Order'), findsOneWidget);
      await tester.tap(find.text('Proceed to Payment'));
      await tester.pumpAndSettle();
      expect(find.text('Payment Method'), findsOneWidget);
      await tester.tap(find.text('Pay RM 250'));
      await tester.pumpAndSettle();
      expect(find.text('Your adventure is confirmed!'), findsOneWidget);
      expect(repo.requests.single.total, 25000);
      expect(repo.requests.single.guests.length, 2);
      expect(repo.requests.single.toMap().containsKey('cardNumber'), false);
      expect(tester.takeException(), isNull);
    },
  );
}
