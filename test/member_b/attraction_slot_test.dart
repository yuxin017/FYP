import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collaborative_asg/attractions/models/attraction_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.parse('2026-11-07T10:00:00+08:00');
  Map<String, dynamic> data() => {
    'attractionId': 'sky_coaster',
    'startsAt': Timestamp.fromDate(start),
    'endsAt': Timestamp.fromDate(start.add(const Duration(minutes: 30))),
    'capacity': 20,
    'bookedCount': 19,
  };

  test(
    'Firestore timestamps preserve the actual instant and document reference',
    () {
      final slot = AttractionSlot.fromMap('slot-1', data());
      expect(slot.attractionId, 'sky_coaster');
      expect(slot.startsAt, DateTime.utc(2026, 11, 7, 2));
      expect(slot.startsAt.isUtc, isTrue);
      expect(slot.toMap()['startsAt'], isA<Timestamp>());
      expect(
        AttractionSlot.fromMap(slot.id, slot.toMap()).toMap(),
        slot.toMap(),
      );
    },
  );

  test('represents the last available place and a full slot correctly', () {
    expect(AttractionSlot.fromMap('slot-1', data()).remainingCapacity, 1);
    expect(
      AttractionSlot.fromMap('slot-1', {
        ...data(),
        'bookedCount': 20,
      }).remainingCapacity,
      0,
    );
  });

  test('rejects overbooking, negative counts and nonpositive capacity', () {
    for (final invalid in [
      {...data(), 'bookedCount': 21},
      {...data(), 'bookedCount': -1},
      {...data(), 'capacity': 0},
      {...data(), 'capacity': -1},
      {...data(), 'confirmedCount': -1},
      {...data(), 'confirmedCount': 20},
    ]) {
      expect(
        () => AttractionSlot.fromMap('slot-1', invalid),
        throwsArgumentError,
      );
    }
  });

  test('rejects empty or reversed time windows', () {
    for (final end in [start, start.subtract(const Duration(seconds: 1))]) {
      expect(
        () => AttractionSlot.fromMap('slot-1', {
          ...data(),
          'endsAt': Timestamp.fromDate(end),
        }),
        throwsArgumentError,
      );
    }
  });

  test(
    'does not accept date strings or fractional counters as Firestore schema',
    () {
      for (final invalid in [
        {...data(), 'startsAt': start.toIso8601String()},
        {...data(), 'capacity': 20.5},
        {...data(), 'confirmedCount': 1.5},
        {...data(), 'retired': 'true'},
        {...data()}..remove('bookedCount'),
      ]) {
        expect(
          () => AttractionSlot.fromMap('slot-1', invalid),
          throwsFormatException,
        );
      }
      expect(
        () => AttractionSlot.fromMap('slot-1', {
          ...data(),
          'attractionId': 'attractions/ride',
        }),
        throwsArgumentError,
      );
    },
  );
}
