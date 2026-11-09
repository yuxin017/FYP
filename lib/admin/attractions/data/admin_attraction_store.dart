import '../../../attractions/data/attraction_reader.dart';
import '../../../attractions/models/attraction.dart';

/// Management operations are available only to the separate admin portal.
/// Firebase rules must still authorize every write.
abstract class AdminAttractionStore implements AttractionReader {
  String newAttractionId();
  Future<void> createAttraction(Attraction attraction);
  Future<void> updateAttraction({
    required Attraction original,
    required Attraction replacement,
  });

  /// Removes from active lists while retaining references for booking history.
  Future<void> deleteAttraction(Attraction original);
}

class AttractionConflict implements Exception {
  const AttractionConflict(this.message);
  final String message;
}
