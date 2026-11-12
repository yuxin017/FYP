import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../photos/photo_widgets.dart';
import '../services/application_api.dart';
import 'location_repository.dart';
import 'venue_configuration.dart';
import 'venue_map.dart';

class LiveLocationPage extends StatefulWidget {
  final ParkLocationRepository? repository;
  const LiveLocationPage({super.key, this.repository});
  @override
  State<LiveLocationPage> createState() => _LiveLocationPageState();
}

class _LiveLocationPageState extends State<LiveLocationPage>
    with WidgetsBindingObserver {
  late final repository = widget.repository ?? FirebaseParkLocationRepository();
  final map = MapController();
  Position? position;
  String? session, error;
  bool busy = false, fetching = false;
  Timer? refresh;
  int generation = 0;
  bool disposed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(stop());
    }
  }

  Future<void> stop() async {
    generation++;
    refresh?.cancel();
    refresh = null;
    final current = session;
    session = null;
    if (mounted && !disposed) setState(() {});
    if (current != null) {
      try {
        await repository.request('stop', {'sessionId': current});
      } catch (_) {
        /* Server positions expire automatically. */
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(stop());
    map.dispose();
    super.dispose();
  }

  Future<void> begin() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use live location?'),
        content: const Text(
          'Your location appears on your map and contributes to the park’s combined crowd and movement information. Sharing runs only while this screen is open and the app is in the foreground. Live positions expire after two minutes; movement samples expire after 24 hours. You can stop at any time.',
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
    final attempt = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on location services to find your position.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location access was not granted. You can still choose a starting point on Park Map.',
        );
      }
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted || attempt != generation) return;
      final result = await repository.request('start', {'consent': true});
      final id = result['sessionId'] as String;
      if (!mounted || attempt != generation) {
        await repository.request('stop', {'sessionId': id});
        return;
      }
      session = id;
      await publish(fix);
      if (!mounted || attempt != generation || session == null) return;
      map.move(LatLng(fix.latitude, fix.longitude), 18);
      refresh = Timer.periodic(const Duration(seconds: 30), (_) => obtainFix());
    } catch (e) {
      await stop();
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String message(Object e) => e is ApplicationApiException
      ? e.message
      : e is StateError
      ? e.message.toString()
      : 'Your location could not be updated. Check permission and your connection.';
  Future<void> obtainFix() async {
    if (fetching || session == null) return;
    fetching = true;
    try {
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (mounted && session != null) await publish(fix);
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      fetching = false;
    }
  }

  Future<void> publish(Position fix) async {
    final id = session;
    if (id == null) return;
    await repository.request('update', {
      'sessionId': id,
      'latitude': fix.latitude,
      'longitude': fix.longitude,
      'accuracy': fix.accuracy,
      'observedAt': fix.timestamp.toUtc().toIso8601String(),
      'source': 'gps',
    });
    if (mounted && session == id) {
      setState(() {
        position = fix;
        error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'My Live Location',
    selectedIndex: 2,
    helpTitle: 'Location and crowd information',
    helpText:
        'Share your current position to see yourself on the campus map. The crowd view combines voluntary, recent positions without showing names.',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          VenueConfiguration.name,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: photoInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          session == null
              ? 'Location sharing is off.'
              : 'Sharing while this screen is open.',
          style: const TextStyle(color: photoRose),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 390,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: FlutterMap(
              mapController: map,
              options: const MapOptions(
                initialCenter: LatLng(
                  VenueConfiguration.latitude,
                  VenueConfiguration.longitude,
                ),
                initialZoom: 17,
                maxZoom: 21,
                minZoom: 10,
              ),
              children: [
                const ProviderTileLayer(),
                if (position case final p?) ...[
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(p.latitude, p.longitude),
                        radius: p.accuracy,
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: .12),
                        borderColor: Colors.blue.withValues(alpha: .35),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(p.latitude, p.longitude),
                        width: 40,
                        height: 40,
                        child: const Tooltip(
                          message: 'Your position',
                          child: Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const ProviderAttribution(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (position case final p?)
          Text(
            'Accuracy: ${p.accuracy.round()} m • Updated ${TimeOfDay.fromDateTime(p.timestamp.toLocal()).format(context)}',
            style: const TextStyle(fontSize: 12),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 14),
        PhotoButton(
          session == null ? 'Use My Live Location' : 'Stop Sharing',
          busy: busy,
          onPressed: busy
              ? null
              : session == null
              ? begin
              : stop,
        ),
        const SizedBox(height: 15),
        const Text(
          'Sharing is available inside the campus boundary with a recent, sufficiently accurate position. GPS accuracy can vary inside buildings.',
          style: TextStyle(height: 1.6, color: Color(0xFF7C8289)),
        ),
      ],
    ),
  );
}
