import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/member_b_fixture_data.dart';

void main() {
  test(
    'six stable attraction IDs, every status, and twelve valid future slots',
    () {
      final now = DateTime.utc(2026, 11, 6);
      final fixtures = MemberBFixtures.build(now: now);
      final ids = fixtures.attractions.map((a) => a.id).toSet();
      expect(ids.length, 6);
      expect(
        fixtures.attractions.map((a) => a.status).toSet(),
        containsAll(AttractionStatus.values),
      );
      expect(fixtures.slots.length, 12);
      expect(fixtures.slots.map((s) => s.id).toSet().length, 12);
      for (final slot in fixtures.slots) {
        expect(ids, contains(slot.attractionId));
        expect(slot.startsAt.isAfter(now), isTrue);
        expect(slot.bookedCount, 0);
        expect(slot.remainingCapacity, slot.capacity);
      }
      expect(
        MemberBFixtures.build(now: now).slots.map((s) => s.id),
        fixtures.slots.map((s) => s.id),
      );
    },
  );

  test(
    'park-local date changes at Kuala Lumpur midnight, not UTC midnight',
    () {
      expect(
        MemberBFixtures.build(now: DateTime.utc(2026, 11, 6, 15, 59)).visitDate,
        '2026-11-07',
      );
      expect(
        MemberBFixtures.build(now: DateTime.utc(2026, 11, 6, 16)).visitDate,
        '2026-11-08',
      );
      expect(
        MemberBFixtures.build(now: DateTime.utc(2026, 12, 31, 16)).visitDate,
        '2027-01-02',
      );
      expect(
        MemberBFixtures.build(now: DateTime.utc(2028, 2, 28, 12)).visitDate,
        '2028-02-29',
      );
    },
  );

  test(
    'ticket scenarios use UID owners and provide valid, used, cancelled and wrong-date cases',
    () {
      final fixtures = MemberBFixtures.build(now: DateTime.utc(2026, 11, 6));
      expect(fixtures.tickets['fixture-ticket-a-valid']!['status'], 'valid');
      expect(fixtures.tickets['fixture-ticket-a-used']!['status'], 'used');
      expect(
        fixtures.tickets['fixture-ticket-a-cancelled']!['status'],
        'cancelled',
      );
      expect(
        fixtures.tickets['fixture-ticket-a-other-date']!['visitDate'],
        isNot(fixtures.visitDate),
      );
      for (final ticket in fixtures.tickets.values) {
        expect(fixtures.visitors.containsKey(ticket['ownerUid']), isTrue);
        expect(ticket['isDemo'], isTrue);
        expect(ticket['createdAt'], isA<Timestamp>());
      }
      expect(fixtures.toMap()['fixtureOnly'], isTrue);
      expect(
        fixtures.visitors.values.every(
          (v) => !v.containsKey('role') && !v.containsKey('admin'),
        ),
        isTrue,
      );
    },
  );
}
