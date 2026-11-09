import 'dart:async';
import 'dart:convert';

import 'package:collaborative_asg/admin/attractions/data/admin_attraction_store.dart';
import 'package:collaborative_asg/attractions/models/attraction.dart';

/// Widget-test double only. Real persistence/rules use separate emulator tests.
class MemoryAttractionStore implements AdminAttractionStore {
  final records = <String, Attraction>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  bool loading = false;
  int readFailures = 0;
  int readCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  final deletedRecords = <String, Attraction>{};
  int _nextId = 0;
  Object? writeError;
  Completer<void>? saveGate;
  final createdIds = <String>[];

  void put(Attraction attraction) {
    records[attraction.id] = attraction;
    _changes.add(null);
  }

  void remove(String id) {
    records.remove(id);
    _changes.add(null);
  }

  @override
  Stream<List<Attraction>> watchAttractions() async* {
    readCalls++;
    if (readFailures > 0) {
      readFailures--;
      throw StateError('Test read failure');
    }
    List<Attraction> current() =>
        records.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    if (!loading) yield current();
    yield* _changes.stream.map((_) => current());
  }

  @override
  Stream<Attraction?> watchAttraction(String attractionId) async* {
    yield records[attractionId];
    yield* _changes.stream.map((_) => records[attractionId]);
  }

  @override
  String newAttractionId() => 'test-attraction-${++_nextId}';

  @override
  Future<void> createAttraction(Attraction attraction) async {
    createCalls++;
    createdIds.add(attraction.id);
    await saveGate?.future;
    if (writeError != null) throw writeError!;
    put(attraction);
  }

  @override
  Future<void> updateAttraction({
    required Attraction original,
    required Attraction replacement,
  }) async {
    updateCalls++;
    await saveGate?.future;
    if (writeError != null) throw writeError!;
    final current = records[original.id];
    if (current == null ||
        jsonEncode(current.toMap()) != jsonEncode(original.toMap())) {
      throw const AttractionConflict(
        'Another administrator changed this attraction. Reopen it to load the latest information before editing.',
      );
    }
    put(replacement);
  }

  @override
  Future<void> deleteAttraction(Attraction original) async {
    deleteCalls++;
    await saveGate?.future;
    if (writeError != null) throw writeError!;
    final current = records[original.id];
    if (current == null) return;
    if (jsonEncode(current.toMap()) != jsonEncode(original.toMap())) {
      throw const AttractionConflict(
        'Another administrator changed this attraction. Refresh the list before deleting it.',
      );
    }
    deletedRecords[original.id] = current;
    remove(original.id);
  }

  Future<void> dispose() => _changes.close();
}

Attraction testAttraction({
  String id = 'mountain_falls',
  String name = 'Mountain Falls',
  String category = 'Water rides',
  AttractionStatus status = AttractionStatus.open,
  int minHeightCm = 110,
  String? description = 'A waterside attraction with park safety guidance.',
}) => Attraction(
  id: id,
  name: name,
  category: category,
  status: status,
  minHeightCm: minHeightCm,
  mapX: .3,
  mapY: .7,
  description: description,
);
