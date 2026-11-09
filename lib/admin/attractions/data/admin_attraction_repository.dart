import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../attractions/data/attraction_repository.dart';
import '../../../attractions/models/attraction.dart';
import 'admin_attraction_store.dart';

/// Portal-only writes. The customer entry point never imports this repository.
class AdminAttractionRepository implements AdminAttractionStore {
  AdminAttractionRepository({required FirebaseFirestore firestore})
    : _firestore = firestore,
      _reader = AttractionRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final AttractionRepository _reader;

  @override
  Stream<List<Attraction>> watchAttractions() => _reader.watchAttractions();

  @override
  Stream<Attraction?> watchAttraction(String attractionId) =>
      _reader.watchAttraction(attractionId);

  @override
  String newAttractionId() => _firestore.collection('attractions').doc().id;

  @override
  Future<void> createAttraction(Attraction attraction) async {
    final ref = _firestore.collection('attractions').doc(attraction.id);
    final conflict = await _firestore.runTransaction<String?>((
      transaction,
    ) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        if (existing.data()!['deletedAt'] != null) {
          return 'This attraction was deleted. Create a new attraction instead.';
        }
        final current = Attraction.fromMap(existing.id, existing.data()!);
        // The form retains its generated ID after an uncertain network result.
        if (_sameFields(current, attraction)) return null;
        return 'An attraction with this ID already exists. Reopen the form and try again.';
      }
      transaction.set(ref, {
        ...attraction.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    });
    // Throw after the callback returns: the web SDK wraps custom Dart errors
    // thrown inside a transaction in an opaque JavaScript Future error.
    if (conflict != null) throw AttractionConflict(conflict);
  }

  @override
  Future<void> updateAttraction({
    required Attraction original,
    required Attraction replacement,
  }) async {
    if (original.id != replacement.id) {
      throw ArgumentError(
        'An attraction document ID cannot change during editing',
      );
    }
    final ref = _firestore.collection('attractions').doc(original.id);
    final conflict = await _firestore.runTransaction<String?>((
      transaction,
    ) async {
      final existing = await transaction.get(ref);
      if (!existing.exists) {
        return 'This attraction no longer exists. Return to the list and refresh.';
      }
      if (existing.data()!['deletedAt'] != null) {
        return 'This attraction was deleted. Return to the list and refresh.';
      }
      final current = Attraction.fromMap(existing.id, existing.data()!);
      if (_sameFields(current, replacement)) return null;
      if (!_sameFields(current, original)) {
        return 'Another administrator changed this attraction. Reopen it to load the latest information before editing.';
      }
      // Preserve unrelated fields if A extends the attraction document later.
      transaction.update(ref, {
        ...replacement.toMap(),
        if (current.reservationCapacity != replacement.reservationCapacity)
          'reservationCapacity': replacement.reservationCapacity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    });
    if (conflict != null) throw AttractionConflict(conflict);
  }

  @override
  Future<void> deleteAttraction(Attraction original) async {
    final ref = _firestore.collection('attractions').doc(original.id);
    final conflict = await _firestore.runTransaction<String?>((
      transaction,
    ) async {
      final existing = await transaction.get(ref);
      // An uncertain save can be retried without deleting linked records.
      if (!existing.exists || existing.data()!['deletedAt'] != null) {
        return null;
      }
      final current = Attraction.fromMap(existing.id, existing.data()!);
      if (!_sameFields(current, original)) {
        return 'Another administrator changed this attraction. Refresh the list before deleting it.';
      }
      transaction.update(ref, {
        'status': AttractionStatus.closed.name,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    });
    if (conflict != null) throw AttractionConflict(conflict);
  }

  bool _sameFields(Attraction a, Attraction b) {
    final fields = b.toMap();
    return a.reservationCapacity == b.reservationCapacity &&
        a.toMap().entries.every((entry) => fields[entry.key] == entry.value);
  }
}
