import 'dart:async';
import 'package:collaborative_asg/attractions/data/slot_reader.dart';
import 'package:collaborative_asg/attractions/models/attraction_slot.dart';

class MemorySlotStore implements SlotReader {
  final records = <AttractionSlot>[];
  final _changes = StreamController<void>.broadcast(sync: true);
  void replace(List<AttractionSlot> values) {
    records
      ..clear()
      ..addAll(values);
    _changes.add(null);
  }

  @override
  Stream<List<AttractionSlot>> watchAttractionSlots(String id) async* {
    yield records.where((s) => s.attractionId == id).toList();
    yield* _changes.stream.map(
      (_) => records.where((s) => s.attractionId == id).toList(),
    );
  }

  @override
  Stream<List<AttractionSlot>> watchUpcomingSlots({
    required DateTime from,
    required DateTime until,
  }) async* {
    List<AttractionSlot> selected() => records
        .where((s) => s.startsAt.isAfter(from) && s.startsAt.isBefore(until))
        .toList();
    yield selected();
    yield* _changes.stream.map((_) => selected());
  }

  Future<void> dispose() => _changes.close();
}
