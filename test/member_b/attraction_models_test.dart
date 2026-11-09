import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> data() => {
    'name': 'Sky Coaster',
    'category': 'Thrill rides',
    'status': 'open',
    'minHeightCm': 140,
    'mapX': .2,
    'mapY': .25,
  };

  test('document identity remains stable when an attraction is renamed', () {
    final attraction = Attraction.fromMap('sky_coaster', {
      ...data(),
      'name': 'New name',
    });
    expect(attraction.id, 'sky_coaster');
    expect(attraction.name, 'New name');
    expect(attraction.toMap().containsKey('id'), isFalse);
    expect(
      Attraction.fromMap(attraction.id, attraction.toMap()).toMap(),
      attraction.toMap(),
    );
  });

  test('all agreed statuses round-trip; unknown and missing statuses fail', () {
    for (final status in AttractionStatus.values) {
      expect(
        Attraction.fromMap('ride', {...data(), 'status': status.name}).status,
        status,
      );
    }
    for (final status in [null, '', 'OPEN', 'available']) {
      expect(
        () => Attraction.fromMap('ride', {...data(), 'status': status}),
        throwsFormatException,
      );
    }
  });

  test(
    'rejects malformed document fields instead of silently substituting defaults',
    () {
      for (final invalid in [
        {...data()}..remove('name'),
        {...data(), 'minHeightCm': 140.5},
        {...data(), 'mapX': '.2'},
      ]) {
        expect(
          () => Attraction.fromMap('ride', invalid),
          throwsFormatException,
        );
      }
      for (final invalid in [
        {...data(), 'name': ' '},
        {...data(), 'category': ''},
        {...data(), 'minHeightCm': -1},
        {...data(), 'mapX': double.nan},
        {...data(), 'mapY': double.infinity},
      ]) {
        expect(() => Attraction.fromMap('ride', invalid), throwsArgumentError);
      }
      expect(
        () => Attraction.fromMap('rides/ride', data()),
        throwsArgumentError,
      );
    },
  );

  test('accepts numeric coordinates and a zero minimum height', () {
    final attraction = Attraction.fromMap('ride', {
      ...data(),
      'minHeightCm': 0,
      'mapX': 0,
    });
    expect(attraction.minHeightCm, 0);
    expect(attraction.mapX, 0.0);
  });
}
