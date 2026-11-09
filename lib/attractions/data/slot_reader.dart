import '../models/attraction_slot.dart';

abstract class SlotReader {
  Stream<List<AttractionSlot>> watchUpcomingSlots({
    required DateTime from,
    required DateTime until,
  });
  Stream<List<AttractionSlot>> watchAttractionSlots(String attractionId);
}
