import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:collaborative_asg/attractions/models/attraction_slot.dart';
import 'package:collaborative_asg/attractions/models/park_time.dart';
import 'package:collaborative_asg/attractions/pages/attractions_page.dart';
import 'package:collaborative_asg/park/crowd_heatmap_page.dart';
import 'package:collaborative_asg/park/park_visit.dart';
import 'package:collaborative_asg/park/smart_itinerary_page.dart';
import 'package:collaborative_asg/reservations/models/reservation.dart';
import 'package:collaborative_asg/reservations/pages/reserve_attraction_page.dart';
import 'package:collaborative_asg/visitor/pages/map_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_attraction_store.dart';
import '../support/memory_reservation_store.dart';
import '../support/memory_slot_store.dart';

final _now = ParkTime.instant(2026, 11, 7, 10, 0);

AttractionSlot _slot(
  String ride,
  int minutes, {
  int booked = 0,
  int capacity = 140,
}) {
  final start = _now.add(Duration(minutes: minutes));
  return AttractionSlot(
    id: '$ride-$minutes',
    attractionId: ride,
    startsAt: start,
    endsAt: start.add(const Duration(minutes: 15)),
    capacity: capacity,
    bookedCount: booked,
  );
}

Attraction _place(
  String id,
  String name,
  double x,
  double y, {
  String category = 'Family rides',
  int height = 0,
  AttractionStatus status = AttractionStatus.open,
}) => Attraction(
  id: id,
  name: name,
  category: category,
  status: status,
  minHeightCm: height,
  mapX: x,
  mapY: y,
);

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(440, 956);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

void main() {
  final castle = _place('castle', 'Sky Castle', .48, .32);
  final carousel = _place('carousel', 'Family Carousel', .78, .58);
  final coaster = _place('coaster', 'Adventure Coaster', .18, .18, height: 150);
  final cafe = _place(
    'cafe',
    'Central Plaza Cafe',
    .32,
    .73,
    category: 'Dining',
  );
  final aid = _place(
    'aid',
    'Central Plaza First Aid',
    .27,
    .49,
    category: 'Facilities',
  );
  final shop = _place('shop', 'Castle Gifts', .74, .83, category: 'Shops');

  testWidgets('a preselected suggestion is rechecked when capacity fills', (
    tester,
  ) async {
    final attractions = MemoryAttractionStore()..put(castle);
    final offer = _slot(castle.id, 30, capacity: 1);
    final slots = MemorySlotStore()..replace([offer]);
    final reservations = MemoryReservationStore();
    addTearDown(attractions.dispose);
    addTearDown(slots.dispose);
    addTearDown(reservations.dispose);
    await _show(
      tester,
      ReserveAttractionPage(
        attraction: castle,
        attractions: attractions,
        slots: slots,
        reservations: reservations,
        day: DateTime(2026, 11, 7),
        initialSlotId: offer.id,
        clock: () => _now,
      ),
    );
    expect(find.text('Continue with 10:30 AM'), findsOneWidget);
    slots.replace([_slot(castle.id, 30, booked: 1, capacity: 1)]);
    await tester.pumpAndSettle();
    expect(find.text('Continue with 10:30 AM'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'the itinerary keeps real reservations and skips unsafe, full and conflicting windows',
    () {
      final bookingSlot = _slot(castle.id, 30);
      final booking = RideReservation(
        id: 'booking',
        attractionId: castle.id,
        attractionName: castle.name,
        slotId: bookingSlot.id,
        ticketId: 'ticket',
        status: 'confirmed',
        startsAt: bookingSlot.startsAt,
        endsAt: bookingSlot.endsAt,
      );
      final closed = _place(
        'closed',
        'Closed ride',
        .2,
        .5,
        status: AttractionStatus.closed,
      );
      final plan = planParkVisit(
        visit: ParkVisit(
          places: [castle, carousel, coaster, cafe, closed],
          now: _now,
          slots: [
            bookingSlot,
            _slot(castle.id, 120),
            _slot(carousel.id, 15),
            _slot(carousel.id, 45),
            _slot(carousel.id, 60, booked: 10, capacity: 10),
            _slot(carousel.id, 75),
            _slot(coaster.id, 90),
            _slot(cafe.id, 105),
            _slot(closed.id, 120),
          ],
        ),
        reservations: [booking],
        interests: const ['Family rides'],
        heightCm: 130,
      );
      expect(plan.map((stop) => stop.name), [castle.name, carousel.name]);
      expect(plan.first.slot, isNull);
      expect(plan.last.slot!.id, 'carousel-75');
    },
  );

  testWidgets(
    'park search finds a dining place and the location picker drives directions',
    (tester) async {
      final attractions = MemoryAttractionStore()
        ..put(castle)
        ..put(carousel)
        ..put(cafe);
      final slots = MemorySlotStore();
      final start = ValueNotifier<String?>(null);
      addTearDown(attractions.dispose);
      addTearDown(slots.dispose);
      addTearDown(start.dispose);
      await _show(
        tester,
        Scaffold(
          body: MapPage(
            attractions: attractions,
            slots: slots,
            startPlace: start,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'central plaza');
      await tester.pumpAndSettle();
      expect(find.text(cafe.name), findsOneWidget);
      expect(find.text(castle.name), findsNothing);
      await tester.tap(find.byTooltip('Find My Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nearby landmark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(castle.name).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use This Landmark'));
      await tester.pumpAndSettle();
      expect(start.value, castle.id);
      await tester.tap(find.byTooltip(cafe.name));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Directions'));
      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      expect(find.text('Towards ${cafe.name}'), findsOneWidget);
      await tester.ensureVisible(find.text('End Navigation'));
      await tester.tap(find.text('End Navigation'));
      await tester.pumpAndSettle();
      expect(find.text('central plaza'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'each map filter shows its pins and nonrides stay out of the queue',
    (tester) async {
      final attractions = MemoryAttractionStore()
        ..put(castle)
        ..put(cafe)
        ..put(aid)
        ..put(shop);
      final slots = MemorySlotStore();
      addTearDown(attractions.dispose);
      addTearDown(slots.dispose);
      await _show(
        tester,
        Scaffold(
          body: MapPage(attractions: attractions, slots: slots),
        ),
      );

      for (final (label, place) in [
        ('Attractions', castle),
        ('Dining', cafe),
        ('Facilities', aid),
        ('Shops', shop),
      ]) {
        if (label != 'Attractions') {
          await tester.tap(find.widgetWithText(ChoiceChip, label));
          await tester.pumpAndSettle();
        }
        for (final candidate in [castle, cafe, aid, shop]) {
          expect(
            find.byTooltip(candidate.name),
            candidate == place ? findsOneWidget : findsNothing,
          );
        }
      }

      await tester.tap(find.widgetWithText(ChoiceChip, 'Dining'));
      await tester.enterText(find.byType(TextField), 'central plaza');
      await tester.pumpAndSettle();
      expect(find.byTooltip(cafe.name), findsOneWidget);
      expect(find.byTooltip(aid.name), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Dining'));
      await tester.pumpAndSettle();
      expect(find.byTooltip(aid.name), findsOneWidget);
      await tester.ensureVisible(find.text(aid.name));
      await tester.tap(find.text(aid.name));
      await tester.pumpAndSettle();
      expect(find.text('Place details'), findsOneWidget);
      expect(find.text('Height requirement'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('queue'),
          home: Scaffold(body: AttractionsPage(store: attractions)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(castle.name), findsOneWidget);
      expect(find.text(cafe.name), findsNothing);
      expect(find.text(aid.name), findsNothing);
      expect(find.text(shop.name), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'heatmap updates from real counts and opens the next available slot',
    (tester) async {
      final attractions = MemoryAttractionStore()
        ..put(castle)
        ..put(carousel);
      final slots = MemorySlotStore()
        ..replace([_slot(castle.id, 30, booked: 60)]);
      addTearDown(attractions.dispose);
      addTearDown(slots.dispose);
      AttractionSlot? selectedSlot;
      await _show(
        tester,
        CrowdHeatmapPage(
          attractions: attractions,
          slots: slots,
          clock: () => _now,
          onPlace: (_, slot) => selectedSlot = slot,
          onTab: (_) {},
        ),
      );
      expect(find.text('Moderate crowd'), findsOneWidget);
      slots.replace([_slot(castle.id, 30, booked: 5)]);
      await tester.pumpAndSettle();
      expect(find.text('Low crowd'), findsNWidgets(2));
      expect(find.text('Moderate crowd'), findsNothing);
      await tester.tap(find.byTooltip(castle.name));
      expect(selectedSlot?.attractionId, castle.id);
      expect(selectedSlot?.startsAt, _now.add(const Duration(minutes: 15)));
      await tester.tap(find.text('Open Full Heatmap'));
      await tester.pumpAndSettle();
      expect(find.text('Recommended for You'), findsNothing);
      expect(find.text('Crowd Heatmap'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'itinerary reads saved preferences and sends the selected return slot to review',
    (tester) async {
      final attractions = MemoryAttractionStore()
        ..put(castle)
        ..put(carousel);
      final slots = MemorySlotStore()..replace([_slot(carousel.id, 30)]);
      final reservations = MemoryReservationStore();
      addTearDown(attractions.dispose);
      addTearDown(slots.dispose);
      addTearDown(reservations.dispose);
      AttractionSlot? selectedSlot;
      await _show(
        tester,
        SmartItineraryPage(
          attractions: attractions,
          slots: slots,
          reservations: reservations,
          watchProfile: () => Stream.value({
            'fullName': 'Park Visitor',
            'foodPreferences': ['Halal'],
            'parkInterests': ['Family rides'],
          }),
          clock: () => _now,
          onPlace: (_, slot) => selectedSlot = slot,
          onTab: (_) {},
        ),
      );
      expect(find.text('Park Visitor'), findsOneWidget);
      expect(find.text('Halal dining'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh itinerary'));
      await tester.pumpAndSettle();
      expect(find.text('Park Visitor'), findsOneWidget);
      await tester.ensureVisible(find.text('Reserve Suggested Slots'));
      await tester.tap(find.text('Reserve Suggested Slots'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, carousel.name));
      await tester.pumpAndSettle();
      expect(selectedSlot?.attractionId, carousel.id);
      expect(selectedSlot?.startsAt, _now.add(const Duration(minutes: 15)));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
