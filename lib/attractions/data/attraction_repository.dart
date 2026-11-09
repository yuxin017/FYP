import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attraction.dart';
import '../models/attraction_slot.dart';
import 'attraction_reader.dart';
import 'slot_reader.dart';

/// Read-only Firestore access for the customer application.
/// Errors propagate to the caller; no fixture or empty-list fallback is used.
class AttractionRepository implements AttractionReader, SlotReader {
  AttractionRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AttractionSlot>> watchUpcomingSlots({
    required DateTime from,
    required DateTime until,
  }) => _firestore
      .collection('attractionSlots')
      .where('startsAt', isGreaterThan: Timestamp.fromDate(from.toUtc()))
      .where('startsAt', isLessThan: Timestamp.fromDate(until.toUtc()))
      .orderBy('startsAt')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => AttractionSlot.fromMap(doc.id, doc.data()))
            .toList(),
      );

  @override
  Stream<List<AttractionSlot>> watchAttractionSlots(String attractionId) {
    _validateId(attractionId);
    return _firestore
        .collection('attractionSlots')
        .where('attractionId', isEqualTo: attractionId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AttractionSlot.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
        );
  }

  @override
  Stream<List<Attraction>> watchAttractions() {
    return _firestore.collection('attractions').snapshots().map((snapshot) {
      final attractions = snapshot.docs
          .where((doc) => doc.data()['deletedAt'] == null)
          .map((doc) => Attraction.fromMap(doc.id, doc.data()))
          .toList();
      attractions.sort((a, b) {
        final byName = a.name.compareTo(b.name);
        return byName == 0 ? a.id.compareTo(b.id) : byName;
      });
      return List<Attraction>.unmodifiable(attractions);
    });
  }

  @override
  Stream<Attraction?> watchAttraction(String attractionId) {
    _validateId(attractionId);
    return _firestore
        .collection('attractions')
        .doc(attractionId)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          return data == null || data['deletedAt'] != null
              ? null
              : Attraction.fromMap(doc.id, data);
        });
  }

  /// [from] is a fixed lower bound. Resubscribe when refreshing the clock.
  Stream<List<AttractionSlot>> watchSlots({
    required String attractionId,
    required DateTime from,
  }) {
    _validateId(attractionId);
    return _firestore
        .collection('attractionSlots')
        .where('attractionId', isEqualTo: attractionId)
        .where('startsAt', isGreaterThan: Timestamp.fromDate(from.toUtc()))
        .orderBy('startsAt')
        .snapshots()
        .map(
          (snapshot) => List<AttractionSlot>.unmodifiable(
            snapshot.docs.map(
              (doc) => AttractionSlot.fromMap(doc.id, doc.data()),
            ),
          ),
        );
  }

  void _validateId(String id) {
    if (id.trim().isEmpty || id.contains('/')) {
      throw ArgumentError.value(id, 'id', 'Expected a document ID');
    }
  }
}
