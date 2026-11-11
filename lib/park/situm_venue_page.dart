import 'dart:async';
import 'package:flutter/material.dart';
import 'package:situm_flutter/wayfinding.dart';
import 'package:situm_flutter/sdk.dart';
import 'venue_configuration.dart';
import '../photos/photo_widgets.dart';
import '../services/application_api.dart';
import 'location_repository.dart';

class SitumVenuePage extends StatefulWidget {
  final String? destinationId;
  const SitumVenuePage({super.key, this.destinationId});
  @override
  State<SitumVenuePage> createState() => _SitumVenuePageState();
}

class _SitumVenuePageState extends State<SitumVenuePage>
    with WidgetsBindingObserver {
  MapViewController? controller;
  String? error;
  final locations = FirebaseParkLocationRepository();
  String? sharingSession;
  bool publishing = false, sharingBusy = false, disposed = false;
  DateTime? lastPublished;
  int sharingGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      unawaited(stopSharing());
    }
  }

  Future<void> stopSharing() async {
    sharingGeneration++;
    final session = sharingSession;
    sharingSession = null;
    if (mounted && !disposed) setState(() {});
    if (session != null) {
      try {
        await locations.request('stop', {'sessionId': session});
      } catch (_) {}
    }
  }

  Future<void> toggleSharing() async {
    if (sharingBusy) return;
    if (sharingSession != null) {
      await stopSharing();
      return;
    }
    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contribute to live crowd information?'),
        content: const Text(
          'Share your Situm position while this navigation screen is open and the app is in the foreground. The crowd view combines positions without names. Live positions expire after two minutes and movement samples expire after 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Share Location'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    final attempt = ++sharingGeneration;
    setState(() {
      sharingBusy = true;
      error = null;
    });
    try {
      final data = await locations.request('start', {'consent': true});
      if (!mounted || disposed || attempt != sharingGeneration) {
        await locations.request('stop', {'sessionId': data['sessionId']});
        return;
      }
      lastPublished = null;
      setState(() => sharingSession = data['sessionId'] as String);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApplicationApiException
              ? e.message
              : 'Location sharing could not start. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => sharingBusy = false);
    }
  }

  Future<void> publish(Location location) async {
    final session = sharingSession;
    if (session == null ||
        disposed ||
        publishing ||
        location.buildingIdentifier != VenueConfiguration.situmBuildingId ||
        lastPublished != null &&
            DateTime.now().difference(lastPublished!) <
                const Duration(seconds: 30)) {
      return;
    }
    publishing = true;
    try {
      final millis = location.timestamp < 100000000000
          ? location.timestamp * 1000
          : location.timestamp;
      await locations.request('update', {
        'sessionId': session,
        'latitude': location.coordinate.latitude,
        'longitude': location.coordinate.longitude,
        'accuracy': location.accuracy,
        'observedAt': DateTime.fromMillisecondsSinceEpoch(
          millis,
          isUtc: true,
        ).toIso8601String(),
        'source': 'situm',
      });
      lastPublished = DateTime.now();
      if (mounted && !disposed) setState(() => error = null);
    } catch (e) {
      if (mounted && !disposed) {
        setState(
          () => error = e is ApplicationApiException
              ? e.message
              : 'Location sharing could not update.',
        );
      }
    } finally {
      publishing = false;
    }
  }

  @override
  void dispose() {
    disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(stopSharing());
    if (VenueConfiguration.situmReady) {
      SitumSdk().onLocationUpdate((_) {});
      SitumSdk().removeUpdates();
    }
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
                  SitumSdk().onLocationUpdate(publish);
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
              Positioned(
                left: 15,
                right: 15,
                bottom: 20,
                child: FilledButton.icon(
                  onPressed: sharingBusy ? null : toggleSharing,
                  icon: Icon(
                    sharingSession == null
                        ? Icons.location_on_outlined
                        : Icons.location_off_outlined,
                  ),
                  label: Text(
                    sharingSession == null
                        ? 'Share for Crowd Information'
                        : 'Stop Sharing Location',
                  ),
                ),
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
