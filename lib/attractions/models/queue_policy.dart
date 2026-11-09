import 'attraction.dart';
import 'attraction_slot.dart';
import 'park_time.dart';

/// Queue sizes come from slot confirmedCount, maintained atomically by Module 2.
/// Cadence controls offered start times, not an invented ride/standby duration.
abstract final class QueuePolicy {
  static AttractionCrowd crowd(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    return count < 50
        ? AttractionCrowd.low
        : count <= 100
        ? AttractionCrowd.moderate
        : AttractionCrowd.busy;
  }

  static int intervalMinutes(int count) => switch (crowd(count)) {
    AttractionCrowd.low => 15,
    AttractionCrowd.moderate => 30,
    AttractionCrowd.busy => 45,
  };

  static DateTime opens(DateTime day) =>
      ParkTime.instant(day.year, day.month, day.day, 9, 30);
  static DateTime closes(DateTime day) =>
      ParkTime.instant(day.year, day.month, day.day, 19, 30);
  static DateTime parkDay(DateTime instant) {
    final local = ParkTime.local(instant);
    return DateTime(local.year, local.month, local.day);
  }

  static bool withinHours(DateTime start, DateTime end) {
    final day = parkDay(start);
    return !start.isBefore(opens(day)) &&
        !end.isAfter(closes(day)) &&
        end.isAfter(start);
  }

  /// Published base windows allow the live view to expand/contract start cadence
  /// without moving existing reservations or rewriting their counts.
  static bool baseWindow(DateTime start, DateTime end) =>
      withinHours(start, end) &&
      end.difference(start) == const Duration(minutes: 15) &&
      start.difference(opens(parkDay(start))).inMicroseconds %
              const Duration(minutes: 15).inMicroseconds ==
          0;

  static bool offered(AttractionSlot slot, int count) =>
      !slot.retired &&
      withinHours(slot.startsAt, slot.endsAt) &&
      slot.startsAt.difference(opens(parkDay(slot.startsAt))).inMicroseconds %
              Duration(minutes: intervalMinutes(count)).inMicroseconds ==
          0;

  static int count({
    required String attractionId,
    required Iterable<AttractionSlot> slots,
    required DateTime day,
    required DateTime now,
  }) => slots
      .where(
        (slot) =>
            slot.attractionId == attractionId &&
            !slot.retired &&
            parkDay(slot.startsAt) == DateTime(day.year, day.month, day.day) &&
            slot.endsAt.isAfter(now.toUtc()),
      )
      .fold(0, (total, slot) => total + slot.confirmedCount);

  static List<AttractionSlot> available({
    required String attractionId,
    required Iterable<AttractionSlot> slots,
    required DateTime day,
    required DateTime now,
  }) {
    final records = slots.toList();
    final size = count(
      attractionId: attractionId,
      slots: records,
      day: day,
      now: now,
    );
    return records
        .where(
          (slot) =>
              slot.attractionId == attractionId &&
              parkDay(slot.startsAt) ==
                  DateTime(day.year, day.month, day.day) &&
              slot.startsAt.isAfter(now.toUtc()) &&
              offered(slot, size),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  static List<AttractionSlot> dayWindows({
    required String attractionId,
    required DateTime day,
    required int capacity,
  }) => [
    for (
      var start = opens(day);
      start.isBefore(closes(day));
      start = start.add(const Duration(minutes: 15))
    )
      AttractionSlot(
        id: 'auto_${attractionId}_${ParkTime.date(start)}_${start.millisecondsSinceEpoch}',
        attractionId: attractionId,
        startsAt: start,
        endsAt: start.add(const Duration(minutes: 15)),
        capacity: capacity,
        bookedCount: 0,
      ),
  ];

  /// Fill missing windows from park hours. Keep saved windows and their counts.
  static List<AttractionSlot> returnTimes({
    required Attraction attraction,
    required Iterable<AttractionSlot> slots,
    required DateTime day,
    required DateTime now,
  }) {
    if (!attraction.isRide || attraction.status != AttractionStatus.open) {
      return const [];
    }
    final stored = slots
        .where(
          (slot) =>
              slot.attractionId == attraction.id &&
              (!slot.retired || slot.bookedCount > 0),
        )
        .toList();
    final automatic = dayWindows(
      attractionId: attraction.id,
      day: day,
      capacity: attraction.reservationCapacity,
    );
    return available(
      attractionId: attraction.id,
      slots: [
        ...stored,
        for (final window in automatic)
          if (!stored.any(
            (slot) =>
                slot.id == window.id ||
                (slot.startsAt.isBefore(window.endsAt) &&
                    window.startsAt.isBefore(slot.endsAt)),
          ))
            window,
      ],
      day: day,
      now: now,
    );
  }
}
