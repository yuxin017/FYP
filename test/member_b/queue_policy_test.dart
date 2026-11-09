import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:collaborative_asg/attractions/models/attraction_slot.dart';
import 'package:collaborative_asg/attractions/models/park_time.dart';
import 'package:collaborative_asg/attractions/models/queue_policy.dart';
import 'package:collaborative_asg/attractions/pages/attractions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/memory_attraction_store.dart';
import '../support/memory_slot_store.dart';

void main() {
  final day = DateTime(2026, 11, 7);
  test(
    'exact threshold boundaries select 15, 30 and 45 minute booking starts',
    () {
      for (final value in [0, 49]) {
        expect(QueuePolicy.crowd(value), AttractionCrowd.low);
        expect(QueuePolicy.intervalMinutes(value), 15);
      }
      for (final value in [50, 51, 99, 100]) {
        expect(QueuePolicy.crowd(value), AttractionCrowd.moderate);
        expect(QueuePolicy.intervalMinutes(value), 30);
      }
      for (final value in [101, 150]) {
        expect(QueuePolicy.crowd(value), AttractionCrowd.busy);
        expect(QueuePolicy.intervalMinutes(value), 45);
      }
      expect(() => QueuePolicy.crowd(-1), throwsArgumentError);
    },
  );
  test(
    'all offered starts and entry windows stay within 9:30 AM–7:30 PM Kuala Lumpur',
    () {
      final windows = QueuePolicy.dayWindows(
        attractionId: 'ride',
        day: day,
        capacity: 200,
      );
      expect(windows.length, 40);
      expect(ParkTime.time(windows.first.startsAt), '9:30 AM');
      expect(ParkTime.time(windows.last.endsAt), '7:30 PM');
      expect(
        windows.every((s) => QueuePolicy.baseWindow(s.startsAt, s.endsAt)),
        isTrue,
      );
      for (final (count, size) in [(0, 40), (50, 20), (101, 14)]) {
        final offered = windows
            .where((s) => QueuePolicy.offered(s, count))
            .toList();
        expect(offered.length, size);
        for (var i = 1; i < offered.length; i++) {
          expect(
            offered[i].startsAt.difference(offered[i - 1].startsAt).inMinutes,
            QueuePolicy.intervalMinutes(count),
          );
        }
      }
      expect(
        QueuePolicy.baseWindow(
          ParkTime.instant(2026, 11, 7, 9, 15),
          ParkTime.instant(2026, 11, 7, 9, 30),
        ),
        isFalse,
      );
      expect(
        QueuePolicy.baseWindow(
          ParkTime.instant(2026, 11, 7, 19, 30),
          ParkTime.instant(2026, 11, 7, 19, 45),
        ),
        isFalse,
      );
    },
  );
  test(
    'queue excludes checked-in places, expired/retired windows, other dates and rides',
    () {
      final start = QueuePolicy.opens(day),
          now = start.add(const Duration(minutes: 10));
      AttractionSlot slot(
        String id,
        DateTime time, {
        String ride = 'ride',
        int booked = 10,
        int confirmed = 7,
        bool retired = false,
      }) => AttractionSlot(
        id: id,
        attractionId: ride,
        startsAt: time,
        endsAt: time.add(const Duration(minutes: 15)),
        capacity: 200,
        bookedCount: booked,
        confirmedCount: confirmed,
        retired: retired,
      );
      final records = [
        slot('active', start),
        slot('expired', start.subtract(const Duration(minutes: 30))),
        slot('retired', start, retired: true),
        slot('other-ride', start, ride: 'other'),
        slot('tomorrow', start.add(const Duration(days: 1))),
      ];
      expect(
        QueuePolicy.count(
          attractionId: 'ride',
          slots: records,
          day: day,
          now: now,
        ),
        7,
      );
      expect(
        records.first.bookedCount,
        10,
      ); // check-in must not release capacity.
    },
  );
  testWidgets(
    'live confirmed counts cross thresholds and change offered times without moving booked windows',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rides = MemoryAttractionStore()
        ..put(testAttraction(id: 'ride', name: 'Live ride'));
      final slots = MemorySlotStore();
      addTearDown(rides.dispose);
      addTearDown(slots.dispose);
      final windows = QueuePolicy.dayWindows(
        attractionId: 'ride',
        day: day,
        capacity: 200,
      );
      void count(int n) => slots.replace([
        AttractionSlot(
          id: windows.first.id,
          attractionId: 'ride',
          startsAt: windows.first.startsAt,
          endsAt: windows.first.endsAt,
          capacity: 200,
          bookedCount: n,
          confirmedCount: n,
        ),
        ...windows.skip(1),
      ]);
      count(50);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttractionsPage(
              store: rides,
              slotReader: slots,
              clock: () =>
                  QueuePolicy.opens(day).add(const Duration(minutes: 10)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Moderate crowd'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
      count(49);
      await tester.pumpAndSettle();
      expect(find.text('Low crowd'), findsOneWidget);
      expect(find.text('9:45 AM'), findsOneWidget);
      count(101);
      await tester.pumpAndSettle();
      expect(find.text('Busy crowd'), findsOneWidget);
      expect(find.text('10:15 AM'), findsOneWidget);
      expect(slots.records.first.startsAt, windows.first.startsAt);
      expect(slots.records.first.endsAt, windows.first.endsAt);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('automatic windows fill gaps without replacing saved capacity', () {
    final ride = testAttraction();
    final opening = QueuePolicy.opens(day);
    final saved = AttractionSlot(
      id: 'legacy-opening',
      attractionId: ride.id,
      startsAt: opening,
      endsAt: opening.add(const Duration(minutes: 15)),
      capacity: 12,
      bookedCount: 4,
    );
    final times = QueuePolicy.returnTimes(
      attraction: ride,
      slots: [saved],
      day: day,
      now: opening.subtract(const Duration(minutes: 1)),
    );
    expect(times, hasLength(40));
    expect(times.first, same(saved));
    expect(times[1].capacity, Attraction.defaultReservationCapacity);
    expect(times[1].bookedCount, 0);
    expect(times[1].id, startsWith('auto_'));
  });
}
