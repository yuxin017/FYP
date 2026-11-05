// Standalone diagnostic script - NOT part of the app itself.
//
// Queries OpenStreetMap's free Overpass API directly for every
// `amenity=bicycle_rental` node (i.e. every community-mapped bike-share /
// bike-rental station) inside a bounding box covering Penang Island and
// the George Town area, and prints each one's name and exact coordinates.
//
// Why this exists: the in-app OsmBikeShareService only searches within
// 1.2km of whatever From/To the user typed, so a "not found near this
// route" result doesn't tell you where the real stations actually are.
// This script answers that directly - run it once, see the full list, then
// pick a real From/To pair that's actually near two of them.
//
// Run with:
//   dart run tool/list_osm_bike_stations.dart
//
// (Plain `dart run`, not `flutter run` - this has nothing to do with the
// Flutter app UI, it's just a quick HTTP call + print, so it's much faster
// to iterate on than launching the whole app every time.)

import 'dart:convert';
import 'package:http/http.dart' as http;

// Covers all of Penang Island plus a bit of the mainland (Butterworth) -
// wide enough to catch George Town, Gurney Drive, Tanjung Bungah, Bayan
// Lepas, etc. all in one query.
const _southLat = 5.20;
const _westLng = 100.15;
const _northLat = 5.50;
const _eastLng = 100.40;

Future<void> main() async {
  final query =
      '[out:json][timeout:25];'
      'node["amenity"="bicycle_rental"]($_southLat,$_westLng,$_northLat,$_eastLng);'
      'out body;';

  final uri = Uri.parse(
    'https://overpass-api.de/api/interpreter',
  ).replace(queryParameters: {'data': query});

  print('Querying Overpass for bicycle_rental stations in the Penang area...');
  print('(bbox: $_southLat,$_westLng to $_northLat,$_eastLng)\n');

  final http.Response response;
  try {
    // Overpass's server returns "406 Not Acceptable" to requests with no
    // User-Agent / Accept header at all (which is what http.get sends by
    // default) - the in-app OsmBikeShareService already sends a
    // User-Agent for exactly this reason, this script just needs the same.
    response = await http
        .get(
          uri,
          headers: const {
            'User-Agent': 'collab_assignment_flutter_app/1.0',
            'Accept': '*/*',
          },
        )
        .timeout(const Duration(seconds: 20));
  } catch (error) {
    print('Request failed: $error');
    return;
  }

  if (response.statusCode != 200) {
    print('Overpass returned HTTP ${response.statusCode}:');
    print(response.body);
    return;
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final elements = (body['elements'] as List?) ?? const [];

  if (elements.isEmpty) {
    print('Zero bicycle_rental nodes found in this bounding box.');
    print('=> OSM has no community-mapped bike-share stations for Penang at all.');
    return;
  }

  print('Found ${elements.length} station(s):\n');
  for (final raw in elements) {
    final element = raw as Map<String, dynamic>;
    final lat = element['lat'];
    final lon = element['lon'];
    final tags = element['tags'] as Map<String, dynamic>? ?? const {};
    final name = tags['name'] ?? tags['network'] ?? tags['operator'] ?? '(unnamed)';
    print('- $name');
    print('    lat: $lat, lng: $lon');
    if (tags.isNotEmpty) print('    tags: $tags');
    print('');
  }
}
