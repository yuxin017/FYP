import 'package:cloud_firestore/cloud_firestore.dart';

enum ParkPlaceKind {
  attractions('Attractions', 'attraction'),
  dining('Dining', 'dining location'),
  facilities('Facilities', 'facility'),
  shops('Shops', 'shop');

  const ParkPlaceKind(this.label, this.itemName);
  final String label, itemName;

  // The category field already supports park places. Retain the historical
  // aliases for records saved before the portal offered a type selector.
  static ParkPlaceKind fromCategory(String value) {
    final category = value.toLowerCase();
    if (category.contains('dining') ||
        category.contains('restaurant') ||
        category.contains('café') ||
        category.contains('cafe')) {
      return dining;
    }
    if (category.contains('shop') || category.contains('retail')) return shops;
    if (category.contains('facilit') ||
        category.contains('service') ||
        category.contains('restroom') ||
        category.contains('first aid')) {
      return facilities;
    }
    return attractions;
  }
}

enum AttractionStatus {
  open,
  closed,
  maintenance;

  static AttractionStatus parse(Object? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    throw FormatException('Unknown attraction status: $value');
  }
}

enum AttractionCrowd {
  low,
  moderate,
  busy;

  String get label => switch (this) {
    low => 'Low',
    moderate => 'Moderate',
    busy => 'Busy',
  };
}

/// An attraction's ID is its Firestore document ID, never its display name.
class Attraction {
  static const defaultReservationCapacity = 10;

  Attraction({
    required this.id,
    required String name,
    required String category,
    required this.status,
    required this.minHeightCm,
    required this.mapX,
    required this.mapY,
    String? description,
    this.coverImageBase64,
    this.crowdLevel,
    this.standbyMinutes,
    this.updatedAt,
    this.ratingAverage,
    this.ratingCount = 0,
    this.reservationCapacity = defaultReservationCapacity,
  }) : name = name.trim(),
       category = category.trim(),
       description = description?.trim() {
    if (id.trim().isEmpty || id.contains('/')) {
      throw ArgumentError.value(id, 'id', 'Expected a document ID');
    }
    if (this.name.isEmpty || this.category.isEmpty) {
      throw ArgumentError('Attraction name and category must not be empty');
    }
    if (minHeightCm < 0) {
      throw ArgumentError.value(minHeightCm, 'minHeightCm', 'Must be >= 0');
    }
    if (reservationCapacity < 1 || reservationCapacity > 1000) {
      throw ArgumentError.value(reservationCapacity, 'reservationCapacity');
    }
    if (!mapX.isFinite || !mapY.isFinite) {
      throw ArgumentError('Map coordinates must be finite numbers');
    }
    if ((this.description?.length ?? 0) > 1200 ||
        (coverImageBase64?.length ?? 0) > 240000 ||
        (standbyMinutes != null &&
            (standbyMinutes! < 0 || standbyMinutes! > 600))) {
      throw ArgumentError(
        'Invalid attraction description, cover image or standby wait',
      );
    }
  }

  final String id;
  final String name;
  final String category;
  final AttractionStatus status;
  final int minHeightCm;
  final int reservationCapacity;

  ParkPlaceKind get placeKind => ParkPlaceKind.fromCategory(category);
  bool get isRide => placeKind == ParkPlaceKind.attractions;

  // Coordinate units/origin must be agreed before the map module is connected.
  final double mapX;
  final double mapY;
  // Optional additions approved for the Virtual Queue design. Existing six-field
  // documents remain readable without inventing operational values.
  final String? description;
  final String? coverImageBase64;
  final AttractionCrowd? crowdLevel;
  final int? standbyMinutes;
  final DateTime? updatedAt;
  // Read-only review aggregates; administrators do not submit these in toMap.
  final double? ratingAverage;
  final int ratingCount;

  factory Attraction.fromMap(String id, Map<String, dynamic> data) {
    final name = data['name'];
    final category = data['category'];
    final height = data['minHeightCm'];
    final x = data['mapX'];
    final y = data['mapY'];
    if (name is! String ||
        category is! String ||
        height is! int ||
        x is! num ||
        y is! num) {
      throw const FormatException('Invalid attraction document fields');
    }
    return Attraction(
      id: id,
      name: name,
      category: category,
      status: AttractionStatus.parse(data['status']),
      minHeightCm: height,
      mapX: x.toDouble(),
      mapY: y.toDouble(),
      description: data['description'] as String?,
      coverImageBase64: data['coverImageBase64'] as String?,
      crowdLevel: AttractionCrowd.values
          .where((value) => value.name == data['crowdLevel'])
          .firstOrNull,
      standbyMinutes: data['standbyMinutes'] as int?,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      ratingAverage: data['ratingAverage'] is num
          ? (data['ratingAverage'] as num).toDouble()
          : null,
      ratingCount: data['ratingCount'] is int ? data['ratingCount'] as int : 0,
      reservationCapacity:
          data['reservationCapacity'] as int? ?? defaultReservationCapacity,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'status': status.name,
    'minHeightCm': minHeightCm,
    'mapX': mapX,
    'mapY': mapY,
    'description': description,
    'coverImageBase64': coverImageBase64,
    'crowdLevel': crowdLevel?.name,
    'standbyMinutes': standbyMinutes,
    if (reservationCapacity != defaultReservationCapacity)
      'reservationCapacity': reservationCapacity,
  };
}
