import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../attractions/models/attraction.dart';
import '../attractions/widgets/queue_attraction_card.dart';
import 'park_visit.dart';
import 'venue_configuration.dart';

LatLng venueCoordinate(Attraction place, List<Attraction> all) {
  final normalized = all.every(
    (p) => p.mapX >= 0 && p.mapX <= 1 && p.mapY >= 0 && p.mapY <= 1,
  );
  double relative(double value, Iterable<double> range) {
    final low = range.reduce(math.min), high = range.reduce(math.max);
    return high == low ? 0.5 : (value - low) / (high - low);
  }

  final x = normalized
          ? place.mapX
          : relative(place.mapX, all.map((p) => p.mapX)),
      y = normalized
          ? place.mapY
          : relative(place.mapY, all.map((p) => p.mapY));
  return LatLng(
    VenueConfiguration.north! -
        y * (VenueConfiguration.north! - VenueConfiguration.south!),
    VenueConfiguration.west! +
        x * (VenueConfiguration.east! - VenueConfiguration.west!),
  );
}

class ProviderTileLayer extends StatelessWidget {
  const ProviderTileLayer({super.key});
  @override
  Widget build(BuildContext context) => TileLayer(
    urlTemplate: VenueConfiguration.mapboxReady
        ? VenueConfiguration.mapboxTiles
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    tileDimension: VenueConfiguration.mapboxReady ? 512 : 256,
    zoomOffset: VenueConfiguration.mapboxReady ? -1 : 0,
    userAgentPackageName: 'my.edu.tarumt.collaborative_asg',
  );
}

class ProviderAttribution extends StatelessWidget {
  const ProviderAttribution({super.key});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (VenueConfiguration.mapboxReady)
        Positioned(
          left: 8,
          bottom: 6,
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://www.mapbox.com/')),
            child: SvgPicture.asset(
              'assets/images/mapbox-logo.svg',
              width: 88,
              height: 22,
            ),
          ),
        ),
      RichAttributionWidget(
        attributions: [
          if (VenueConfiguration.mapboxReady)
            TextSourceAttribution(
              '© Mapbox',
              onTap: () => launchUrl(Uri.parse('https://www.mapbox.com/')),
            ),
          TextSourceAttribution(
            '© OpenStreetMap',
            onTap: () =>
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
          ),
          if (VenueConfiguration.mapboxReady)
            TextSourceAttribution(
              'Improve this map',
              onTap: () =>
                  launchUrl(Uri.parse('https://apps.mapbox.com/feedback/')),
            ),
        ],
      ),
    ],
  );
}

class GeographicParkMap extends StatelessWidget {
  final ParkVisit visit;
  final List<Attraction> visible;
  final ValueChanged<Attraction> onPlace;
  final Attraction? origin, destination;
  final Map<String, dynamic>? density;
  const GeographicParkMap({
    super.key,
    required this.visit,
    required this.visible,
    required this.onPlace,
    this.origin,
    this.destination,
    this.density,
  });
  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds(
          LatLng(VenueConfiguration.south!, VenueConfiguration.west!),
          LatLng(VenueConfiguration.north!, VenueConfiguration.east!),
        ),
        count = density?['size'] as int? ?? 0,
        values = density?['values'] as List? ?? [];
    final circleRadius =
        (VenueConfiguration.north! - VenueConfiguration.south!) *
        111000 /
        (count == 0 ? 32 : count) *
        .8;
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(25),
        ),
        maxZoom: 21,
        minZoom: 10,
      ),
      children: [
        const ProviderTileLayer(),
        if (count > 0 && values.length == count * count)
          CircleLayer(
            circles: [
              for (int y = 0; y < count; y++)
                for (int x = 0; x < count; x++)
                  if ((values[y * count + x] as num) > .05)
                    CircleMarker(
                      point: LatLng(
                        VenueConfiguration.north! -
                            (y + .5) /
                                count *
                                (VenueConfiguration.north! -
                                    VenueConfiguration.south!),
                        VenueConfiguration.west! +
                            (x + .5) /
                                count *
                                (VenueConfiguration.east! -
                                    VenueConfiguration.west!),
                      ),
                      radius: circleRadius,
                      useRadiusInMeter: true,
                      color: Color.lerp(
                        Colors.green,
                        Colors.red,
                        (values[y * count + x] as num).toDouble(),
                      )!.withValues(alpha: .35),
                    ),
            ],
          ),
        if (origin != null && destination != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  venueCoordinate(origin!, visit.places),
                  venueCoordinate(destination!, visit.places),
                ],
                color: queueRose,
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final place in visible)
              Marker(
                point: venueCoordinate(place, visit.places),
                width: 95,
                height: 70,
                child: GestureDetector(
                  onTap: () => onPlace(place),
                  child: Tooltip(
                    message: place.name,
                    child: Column(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 36,
                          color: place.status == AttractionStatus.open
                              ? queueRose
                              : Colors.grey,
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (origin != null)
              Marker(
                point: venueCoordinate(origin!, visit.places),
                width: 38,
                height: 38,
                child: const Icon(
                  Icons.my_location,
                  size: 30,
                  color: Colors.blue,
                ),
              ),
          ],
        ),
        const ProviderAttribution(),
      ],
    );
  }
}
