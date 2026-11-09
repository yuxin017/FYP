import 'dart:convert';
import 'dart:typed_data';
import 'package:collaborative_asg/admin/attractions/cover_photo.dart';
import 'package:collaborative_asg/attractions/data/slot_reader.dart';
import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:collaborative_asg/attractions/models/attraction_slot.dart';
import 'package:collaborative_asg/attractions/models/park_time.dart';
import 'package:collaborative_asg/attractions/models/queue_policy.dart';
import 'package:collaborative_asg/attractions/pages/attractions_page.dart';
import 'package:collaborative_asg/attractions/widgets/queue_attraction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import '../support/attraction_photo.dart';
import '../support/memory_attraction_store.dart';

class _Slots implements SlotReader {
  _Slots(this.records);
  final List<AttractionSlot> records;
  @override
  Stream<List<AttractionSlot>> watchUpcomingSlots({
    required DateTime from,
    required DateTime until,
  }) => Stream.value(
    records
        .where(
          (slot) =>
              slot.startsAt.isAfter(from) && slot.startsAt.isBefore(until),
        )
        .toList(),
  );
  @override
  Stream<List<AttractionSlot>> watchAttractionSlots(String id) =>
      Stream.value(records.where((slot) => slot.attractionId == id).toList());
}

void main() {
  test(
    'cover selection produces a decodable compressed photo and rejects invalid files',
    () {
      final encoded = encodeAttractionCover(attractionTestPhoto());
      expect(encoded.length, lessThanOrEqualTo(240000));
      expect(image.decodeImage(base64Decode(encoded)), isNotNull);
      expect(
        () => encodeAttractionCover(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    },
  );
  test(
    'legacy records remain readable and do not invent crowd, wait, photo or reviews',
    () {
      final ride = Attraction.fromMap('legacy', {
        'name': 'Legacy ride',
        'category': 'Family rides',
        'status': 'open',
        'minHeightCm': 0,
        'mapX': 0,
        'mapY': 0,
      });
      expect(ride.coverImageBase64, isNull);
      expect(ride.standbyMinutes, isNull);
      expect(ride.crowdLevel, isNull);
      expect(ride.ratingCount, 0);
    },
  );
  test(
    'review aggregates remain read-only while approved attraction details round-trip',
    () {
      final ride = Attraction.fromMap('ride', {
        ...testAttraction().toMap(),
        'ratingAverage': 4.8,
        'ratingCount': 10,
        'crowdLevel': 'moderate',
        'standbyMinutes': 35,
        'coverImageBase64': encodeAttractionCover(attractionTestPhoto()),
      });
      expect(ride.ratingAverage, 4.8);
      expect(ride.toMap().containsKey('ratingAverage'), isFalse);
      expect(Attraction.fromMap(ride.id, ride.toMap()).standbyMinutes, 35);
    },
  );
  test('park dates and sessions are independent of the computer timezone', () {
    final instant = ParkTime.instant(2026, 11, 6, 14, 30);
    expect(instant, DateTime.utc(2026, 11, 6, 6, 30));
    expect(ParkTime.time(instant), '2:30 PM');
    expect(ParkTime.date(DateTime.utc(2026, 11, 6, 23)), '2026-11-07');
  });
  testWidgets(
    'Figma-style card displays supplied information and opens details/times',
    (tester) async {
      tester.view.physicalSize = const Size(355, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var details = false, times = false;
      final ride = Attraction(
        id: 'ride',
        name: 'Visitor ride',
        category: 'Family rides',
        status: AttractionStatus.open,
        minHeightCm: 0,
        mapX: .3,
        mapY: .4,
        coverImageBase64: encodeAttractionCover(attractionTestPhoto()),
        crowdLevel: AttractionCrowd.moderate,
        standbyMinutes: 35,
      );
      final start = DateTime.now().toUtc().add(const Duration(hours: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(14),
              child: QueueAttractionCard(
                attraction: ride,
                queueCount: 75,
                nextSlot: AttractionSlot(
                  id: 'slot',
                  attractionId: 'ride',
                  startsAt: start,
                  endsAt: start.add(const Duration(minutes: 30)),
                  capacity: 10,
                  bookedCount: 2,
                ),
                onDetails: () => details = true,
                onTimes: () => times = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not rated'), findsOneWidget);
      expect(find.text('Moderate crowd'), findsOneWidget);
      expect(find.text('35 min standby'), findsOneWidget);
      expect(find.text('Slots available'), findsOneWidget);
      await tester.tap(find.text('Visitor ride'));
      await tester.tap(find.text('View Times'));
      expect(details, isTrue);
      expect(times, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Available Now uses actual future capacity and recommendations respect height',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryAttractionStore();
      addTearDown(store.dispose);
      store.put(
        testAttraction(id: 'eligible', name: 'Eligible ride', minHeightCm: 100),
      );
      store.put(
        testAttraction(id: 'tall', name: 'Tall ride', minHeightCm: 180),
      );
      final now = DateTime.utc(2026, 11, 6);
      final slots = _Slots([
        for (final window in QueuePolicy.dayWindows(
          attractionId: 'tall',
          day: QueuePolicy.parkDay(now),
          capacity: 1,
        ))
          AttractionSlot(
            id: window.id,
            attractionId: window.attractionId,
            startsAt: window.startsAt,
            endsAt: window.endsAt,
            capacity: 1,
            bookedCount: 1,
          ),
        AttractionSlot(
          id: 'open',
          attractionId: 'eligible',
          startsAt: now.add(const Duration(hours: 2)),
          endsAt: now.add(const Duration(hours: 2, minutes: 15)),
          capacity: 10,
          bookedCount: 2,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttractionsPage(
              store: store,
              slotReader: slots,
              visitorHeightCm: 150,
              clock: () => now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Virtual Queue'), findsOneWidget);
      expect(find.text('Tall ride'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(find.text('Tall ride'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Available Now'));
      await tester.pumpAndSettle();
      expect(find.text('Eligible ride'), findsOneWidget);
      expect(find.text('Tall ride'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
