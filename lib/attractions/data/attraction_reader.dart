import '../models/attraction.dart';

/// Customer screens can read attractions, but have no management operations.
abstract class AttractionReader {
  Stream<List<Attraction>> watchAttractions();
  Stream<Attraction?> watchAttraction(String attractionId);
}
