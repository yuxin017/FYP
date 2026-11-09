import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:collaborative_asg/attractions/models/attraction_slot.dart';

/// Isolated test data. Never imported by lib/ or automatically written to Firebase.
class MemberBFixtures {
  MemberBFixtures({
    required this.visitDate,
    required this.attractions,
    required this.slots,
    required this.visitors,
    required this.tickets,
  });

  static const visitorA = 'fixture-visitor-a';
  static const visitorB = 'fixture-visitor-b';

  final String visitDate;
  final List<Attraction> attractions;
  final List<AttractionSlot> slots;
  final Map<String, Map<String, dynamic>> visitors;
  final Map<String, Map<String, dynamic>> tickets;

  /// Uses the next park-local day so fixtures remain future-dated at any hour.
  /// The reservation integration tests must set their test clock to that day.
  static MemberBFixtures build({required DateTime now}) {
    final utcNow = now.toUtc();
    final parkNow = utcNow.add(const Duration(hours: 8));
    final nextParkDay = DateTime.utc(
      parkNow.year,
      parkNow.month,
      parkNow.day + 1,
    );
    final visitDate = _date(nextParkDay);
    final attractions = <Attraction>[
      Attraction(
        id: 'sky_coaster',
        name: 'Sky Coaster',
        category: 'Thrill rides',
        status: AttractionStatus.open,
        minHeightCm: 140,
        mapX: .2,
        mapY: .25,
      ),
      Attraction(
        id: 'magic_carousel',
        name: 'Magic Carousel',
        category: 'Family rides',
        status: AttractionStatus.open,
        minHeightCm: 0,
        mapX: .45,
        mapY: .35,
      ),
      Attraction(
        id: 'river_adventure',
        name: 'River Adventure',
        category: 'Water rides',
        status: AttractionStatus.open,
        minHeightCm: 110,
        mapX: .75,
        mapY: .6,
      ),
      Attraction(
        id: 'castle_express',
        name: 'Castle Express',
        category: 'Family rides',
        status: AttractionStatus.open,
        minHeightCm: 0,
        mapX: .4,
        mapY: .7,
      ),
      Attraction(
        id: 'jungle_swing',
        name: 'Jungle Swing',
        category: 'Thrill rides',
        status: AttractionStatus.maintenance,
        minHeightCm: 120,
        mapX: .15,
        mapY: .65,
      ),
      Attraction(
        id: 'starlight_theatre',
        name: 'Starlight Theatre',
        category: 'Shows',
        status: AttractionStatus.closed,
        minHeightCm: 0,
        mapX: .7,
        mapY: .2,
      ),
    ];
    final slots = <AttractionSlot>[];
    for (final attraction in attractions) {
      for (final parkHour in [10, 14]) {
        // Park time is UTC+08:00; 10:00 in Kuala Lumpur is 02:00 UTC.
        final startsAt = nextParkDay.add(Duration(hours: parkHour - 8));
        slots.add(
          AttractionSlot(
            id: '${attraction.id}_${visitDate.replaceAll('-', '')}_${parkHour}00',
            attractionId: attraction.id,
            startsAt: startsAt,
            endsAt: startsAt.add(const Duration(minutes: 30)),
            capacity: 20,
            bookedCount: 0,
          ),
        );
      }
    }
    Map<String, dynamic> ticket(
      String ownerUid,
      String status,
      String date,
    ) => {
      'ownerUid': ownerUid,
      'orderId': ownerUid == visitorA ? 'fixture-order-a' : 'fixture-order-b',
      'visitDate': date,
      'status': status,
      'isDemo': true,
      'createdAt': Timestamp.fromDate(utcNow),
    };

    return MemberBFixtures(
      visitDate: visitDate,
      attractions: List.unmodifiable(attractions),
      slots: List.unmodifiable(slots),
      visitors: {
        visitorA: {
          'heightCm': 175,
          'parkInterests': ['Thrill rides', 'Water rides'],
          'foodPreferences': ['Halal'],
        },
        visitorB: {
          'heightCm': 100,
          'parkInterests': ['Family rides'],
          'foodPreferences': ['No preference'],
        },
      },
      tickets: {
        'fixture-ticket-a-valid': ticket(visitorA, 'valid', visitDate),
        'fixture-ticket-a-used': ticket(visitorA, 'used', visitDate),
        'fixture-ticket-a-cancelled': ticket(visitorA, 'cancelled', visitDate),
        'fixture-ticket-b-valid': ticket(visitorB, 'valid', visitDate),
        'fixture-ticket-a-other-date': ticket(
          visitorA,
          'valid',
          _date(nextParkDay.add(const Duration(days: 1))),
        ),
      },
    );
  }

  Map<String, dynamic> toMap() => {
    'fixtureOnly': true,
    'target': 'isolated tests or emulator only',
    'visitDate': visitDate,
    'collections': {
      'attractions': {for (final a in attractions) a.id: a.toMap()},
      'attractionSlots': {for (final s in slots) s.id: s.toMap()},
      'visitors': visitors,
      'tickets': tickets,
    },
  };

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
