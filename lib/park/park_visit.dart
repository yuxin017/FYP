import '../attractions/models/attraction.dart';
import '../attractions/models/attraction_slot.dart';
import '../attractions/models/queue_policy.dart';
import '../reservations/models/reservation.dart';

class ParkVisit {
  const ParkVisit({
    required this.places,
    required this.slots,
    required this.now,
    this.updatedAt,
  });

  final List<Attraction> places;
  final List<AttractionSlot>? slots;
  final DateTime now;
  final DateTime? updatedAt;

  DateTime get day => QueuePolicy.parkDay(now);

  Attraction? place(String? id) =>
      places.where((place) => place.id == id).firstOrNull;

  Iterable<AttractionSlot> get _activeWindows =>
      (slots ?? const <AttractionSlot>[]).where(
        (slot) =>
            !slot.retired &&
            QueuePolicy.parkDay(slot.startsAt) == day &&
            slot.endsAt.isAfter(now),
      );

  AttractionCrowd? crowdFor(Attraction place) {
    if (!place.isRide ||
        place.status != AttractionStatus.open ||
        slots == null) {
      return null;
    }
    return QueuePolicy.crowd(
      QueuePolicy.count(
        attractionId: place.id,
        slots: slots!,
        day: day,
        now: now,
      ),
    );
  }

  AttractionCrowd? get parkCrowd {
    final openIds = places
        .where((place) => place.isRide && place.status == AttractionStatus.open)
        .map((place) => place.id)
        .toSet();
    final windows = _activeWindows.where(
      (slot) => openIds.contains(slot.attractionId),
    );
    if (slots == null || openIds.isEmpty) return null;
    return QueuePolicy.crowd(
      windows.fold(0, (total, slot) => total + slot.confirmedCount),
    );
  }

  Iterable<AttractionSlot> available(Attraction place) {
    final recorded = slots;
    if (recorded == null) return const [];
    return QueuePolicy.returnTimes(
      attraction: place,
      slots: recorded,
      day: day,
      now: now,
    ).where((slot) => slot.remainingCapacity > 0);
  }
}

double parkDistanceSquared(Attraction a, Attraction b) {
  final dx = a.mapX - b.mapX;
  final dy = a.mapY - b.mapY;
  return dx * dx + dy * dy;
}

bool matchesParkInterest(Attraction place, Iterable<String> interests) =>
    interests.any(
      (interest) => interest.toLowerCase() == place.category.toLowerCase(),
    );

bool eligibleParkRide(Attraction place, int? heightCm) =>
    place.isRide &&
    place.status == AttractionStatus.open &&
    (place.minHeightCm == 0 ||
        (heightCm != null && heightCm >= place.minHeightCm));

class ItineraryStop {
  const ItineraryStop({
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.reason,
    this.attraction,
    this.slot,
  });

  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final String reason;
  final Attraction? attraction;
  final AttractionSlot? slot;
}

List<ItineraryStop> planParkVisit({
  required ParkVisit visit,
  required List<RideReservation> reservations,
  required Iterable<String> interests,
  required int? heightCm,
  Attraction? origin,
  Map<String, double> relevance = const {},
}) {
  final activeToday = reservations.where(
    (booking) =>
        (booking.status == 'confirmed' || booking.status == 'checked_in') &&
        QueuePolicy.parkDay(booking.startsAt) == visit.day,
  );
  final taken = activeToday.map((booking) => booking.attractionId).toSet();
  final occupied = [
    for (final booking in activeToday)
      if (booking.endsAt.isAfter(visit.now)) (booking.startsAt, booking.endsAt),
  ];
  final stops = [
    for (final booking in activeToday)
      if (booking.status == 'confirmed' && booking.endsAt.isAfter(visit.now))
        ItineraryStop(
          name: booking.attractionName,
          startsAt: booking.startsAt,
          endsAt: booking.endsAt,
          attraction: visit.place(booking.attractionId),
          reason: 'Kept in your plan because you already reserved this time.',
        ),
  ];

  // Leave a planning gap between return windows. Coordinates have no measured
  // walking scale, so this gap is never presented as a travel estimate.
  const gap = Duration(minutes: 15);
  for (var count = 0; count < 4; count++) {
    final options = <(Attraction, AttractionSlot)>[];
    for (final place in visit.places) {
      if (taken.contains(place.id) || !eligibleParkRide(place, heightCm)) {
        continue;
      }
      final slot = visit
          .available(place)
          .where(
            (slot) => occupied.every(
              (window) =>
                  !slot.endsAt.add(gap).isAfter(window.$1) ||
                  !window.$2.add(gap).isAfter(slot.startsAt),
            ),
          )
          .firstOrNull;
      if (slot != null) options.add((place, slot));
    }
    if (options.isEmpty) break;

    double score((Attraction, AttractionSlot) option) {
      final start = option.$2.startsAt.difference(visit.now).inMinutes;
      final preference = matchesParkInterest(option.$1, interests) ? 20 : 0;
      final crowd = (visit.crowdFor(option.$1)?.index ?? 1) * 12;
      return start - preference + crowd - (relevance[option.$1.id] ?? 0) * 35;
    }

    options.sort((a, b) {
      final priority = score(a).compareTo(score(b));
      if (priority != 0) return priority;
      if (origin != null) {
        final distance = parkDistanceSquared(
          a.$1,
          origin,
        ).compareTo(parkDistanceSquared(b.$1, origin));
        if (distance != 0) return distance;
      }
      return a.$1.id.compareTo(b.$1.id);
    });

    final (place, slot) = options.first;
    taken.add(place.id);
    occupied.add((slot.startsAt, slot.endsAt));
    stops.add(
      ItineraryStop(
        name: place.name,
        startsAt: slot.startsAt,
        endsAt: slot.endsAt,
        attraction: place,
        slot: slot,
        reason: matchesParkInterest(place, interests)
            ? 'Recommended because it matches your park interests.'
            : 'This return time is available and fits around your planned stops.',
      ),
    );
  }

  return stops..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}
