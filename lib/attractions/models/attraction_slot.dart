import 'package:cloud_firestore/cloud_firestore.dart';

class AttractionSlot {
  AttractionSlot({
    required this.id,
    required this.attractionId,
    required DateTime startsAt,
    required DateTime endsAt,
    required this.capacity,
    required this.bookedCount,
    int? confirmedCount,
    this.retired = false,
  }) : confirmedCount = confirmedCount ?? bookedCount,
       startsAt = startsAt.toUtc(),
       endsAt = endsAt.toUtc() {
    if (id.trim().isEmpty ||
        id.contains('/') ||
        attractionId.trim().isEmpty ||
        attractionId.contains('/')) {
      throw ArgumentError('Slot and attraction IDs must be document IDs');
    }
    if (!this.endsAt.isAfter(this.startsAt)) {
      throw ArgumentError('Slot end must be after its start');
    }
    if (capacity <= 0 ||
        bookedCount < 0 ||
        bookedCount > capacity ||
        this.confirmedCount < 0 ||
        this.confirmedCount > bookedCount) {
      throw ArgumentError(
        'Slot counts must satisfy 0 <= bookedCount <= capacity, with capacity > 0',
      );
    }
  }

  final String id;
  final String attractionId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final int bookedCount;

  /// Active confirmed reservations; checked-in places still consume capacity.
  final int confirmedCount;
  final bool retired;

  int get remainingCapacity => capacity - bookedCount;

  factory AttractionSlot.fromMap(String id, Map<String, dynamic> data) {
    final attractionId = data['attractionId'];
    final startsAt = data['startsAt'];
    final endsAt = data['endsAt'];
    final capacity = data['capacity'];
    final bookedCount = data['bookedCount'];
    if (attractionId is! String ||
        startsAt is! Timestamp ||
        endsAt is! Timestamp ||
        capacity is! int ||
        bookedCount is! int ||
        (data['confirmedCount'] != null && data['confirmedCount'] is! int) ||
        (data['retired'] != null && data['retired'] is! bool)) {
      throw const FormatException(
        'Slots require Firestore timestamps and integer counts',
      );
    }
    return AttractionSlot(
      id: id,
      attractionId: attractionId,
      startsAt: startsAt.toDate(),
      endsAt: endsAt.toDate(),
      capacity: capacity,
      bookedCount: bookedCount,
      confirmedCount: data['confirmedCount'] as int?,
      retired: data['retired'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'attractionId': attractionId,
    'startsAt': Timestamp.fromDate(startsAt),
    'endsAt': Timestamp.fromDate(endsAt),
    'capacity': capacity,
    'bookedCount': bookedCount,
    'confirmedCount': confirmedCount,
    if (retired) 'retired': true,
  };
}
