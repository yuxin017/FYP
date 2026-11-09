import 'package:flutter/material.dart';
import 'package:situm_flutter/wayfinding.dart';
import 'package:situm_flutter/sdk.dart';
import 'venue_configuration.dart';
import '../photos/photo_widgets.dart';

class SitumVenuePage extends StatefulWidget {
  final String? destinationId;
  const SitumVenuePage({super.key, this.destinationId});
  @override
  State<SitumVenuePage> createState() => _SitumVenuePageState();
}

class _SitumVenuePageState extends State<SitumVenuePage> {
  MapViewController? controller;
  String? error;
  @override
  void dispose() {
    if (VenueConfiguration.situmReady) SitumSdk().removeUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Live Park Navigation',
    helpTitle: 'Finding your way',
    helpText:
        'Use the venue map to locate yourself, choose a destination and follow its walking directions. Live positioning requires a supported phone and location permission. If positioning is unavailable, use the park map to select your starting point.',
    selectedIndex: 2,
    body: !VenueConfiguration.situmReady
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                'Live venue navigation is unavailable on this device. Use the park map to choose your starting point.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : Stack(
            children: [
              MapView(
                key: const ValueKey('situm-venue-map'),
                configuration: MapViewConfiguration(
                  situmApiKey: VenueConfiguration.situmApiKey,
                  buildingIdentifier: VenueConfiguration.situmBuildingId,
                  profile: VenueConfiguration.situmProfile.isEmpty
                      ? null
                      : VenueConfiguration.situmProfile,
                  lockCameraToBuilding: true,
                  enableDebugging: false,
                ),
                onLoad: (value) {
                  controller = value;
                  final poi = widget.destinationId == null
                      ? null
                      : VenueConfiguration.poiFor(widget.destinationId!);
                  if (poi != null) value.navigateToPoi(poi);
                },
                onError: (_) {
                  if (mounted) {
                    setState(
                      () => error =
                          'The venue map could not load. Check your connection or return to Park Map.',
                    );
                  }
                },
              ),
              if (error != null)
                Positioned(
                  left: 15,
                  right: 15,
                  top: 15,
                  child: PhotoPanel(
                    child: Text(
                      error!,
                      style: const TextStyle(color: photoRose),
                    ),
                  ),
                ),
            ],
          ),
  );
}
