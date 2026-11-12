import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../attractions/models/attraction.dart';
import 'attraction_camera_store.dart';
import 'camera_heatmap.dart';
import 'camera_peer.dart';

class CameraStationPage extends StatefulWidget {
  const CameraStationPage({
    super.key,
    required this.store,
    required this.onSignOut,
  });

  final AttractionCameraStore store;
  final Future<void> Function() onSignOut;

  @override
  State<CameraStationPage> createState() => _CameraStationPageState();
}

class _CameraStationPageState extends State<CameraStationPage>
    with WidgetsBindingObserver {
  static const _native = MethodChannel('themepark/attraction-camera');
  late final _places = widget.store.attractions.watchAttractions();
  late final _assignments = widget.store.assignments.snapshots();
  final _preview = RTCVideoRenderer();
  Future<void>? _previewReady;
  MediaStream? _stream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _requests;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _assignment;
  RTCPeerConnection? _peer;
  RTCDataChannel? _channel;
  Timer? _heartbeat;
  String? _selected, _session, _viewId, _error;
  CameraHeatmap? _heat;
  bool _working = false, _pinging = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _native.setMethodCallHandler(_onDetectorEvent);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_session != null &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      unawaited(_stop());
    }
  }

  Future<void> _onDetectorEvent(MethodCall event) async {
    if (!mounted || _session == null) return;
    final trackId = _stream?.getVideoTracks().firstOrNull?.id;
    if (event.method == 'detectorError' && event.arguments == trackId) {
      await _stop(
        message:
            'Person detection could not start. Try starting the camera again.',
      );
    }
    if (event.method != 'detections' || event.arguments is! Map) return;
    final data = event.arguments as Map;
    if (data['trackId'] != trackId) return;
    final boxes = (data['boxes'] as List).map((raw) {
      final edges = (raw as List).cast<double>();
      return Rect.fromLTRB(edges[0], edges[1], edges[2], edges[3]);
    }).toList();
    final heat = CameraHeatmap.fromBoxes(boxes);
    setState(() => _heat = heat);
    final channel = _channel;
    if (channel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        await channel!.send(RTCDataChannelMessage(heat.encode()));
      } catch (_) {
        // The viewer can disconnect between the state check and send.
      }
    }
  }

  Future<void> _start(String id) async {
    final generation = ++_generation;
    setState(() {
      _working = true;
      _error = null;
    });
    final session = widget.store.broadcast(id).parent.doc().id;
    try {
      await (_previewReady ??= _preview.initialize());
      if (!mounted || generation != _generation) return;
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': 'environment',
          'width': 1280,
          'height': 720,
          'frameRate': 15,
        },
      });
      if (!mounted || generation != _generation) {
        await _disposeStream(stream);
        return;
      }
      _stream = stream;
      await widget.store.claim(id, session);
      if (!mounted || generation != _generation) {
        unawaited(widget.store.release(id, session).catchError((Object _) {}));
        return;
      }
      _session = session;
      _preview.srcObject = stream;
      await _native.invokeMethod<void>('start', {
        'trackId': stream.getVideoTracks().single.id,
      });
      if (!mounted || generation != _generation) return;
      _heartbeat = Timer.periodic(
        const Duration(seconds: 6),
        (_) => unawaited(_renew(id, session)),
      );
      _assignment = widget.store.assignments
          .doc(id)
          .snapshots(includeMetadataChanges: true)
          .listen((event) {
            if (!event.exists &&
                !event.metadata.isFromCache &&
                _session == session) {
              unawaited(
                _stop(message: 'This attraction’s camera was disabled.'),
              );
            }
          });
      _requests = widget.store
          .request(id)
          .snapshots()
          .listen(
            (event) {
              if (_session != session) return;
              final data = event.data();
              if (data?['session'] != session) {
                if (_viewId != null) unawaited(_disconnect());
                return;
              }
              final view = data!['viewId'] as String;
              final requestedAt = data['requestedAt'];
              if (view != _viewId &&
                  requestedAt is Timestamp &&
                  DateTime.now().difference(requestedAt.toDate()) <
                      const Duration(seconds: 30)) {
                unawaited(_serve(id, session, view, data['offer'] as String));
              }
            },
            onError: (Object _) {
              if (_session == session) {
                unawaited(_stop(message: 'Camera access was interrupted.'));
              }
            },
          );
    } catch (error) {
      if (generation == _generation) {
        await _stop(
          message: error is StateError
              ? error.message
              : 'Could not start the camera. Check camera permission and Wi-Fi.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _renew(String id, String session) async {
    if (_pinging || _session != session) return;
    _pinging = true;
    try {
      await widget.store.heartbeat(id, session);
    } catch (_) {
      if (_session == session) {
        await _stop(
          message:
              'The camera lost its connection. Start it again when Wi-Fi is available.',
        );
      }
    } finally {
      _pinging = false;
    }
  }

  Future<void> _serve(
    String id,
    String session,
    String view,
    String offer,
  ) async {
    final previous = _peer;
    _viewId = view;
    _peer = null;
    _channel = null;
    await previous?.close();
    await previous?.dispose();
    RTCPeerConnection? peer;
    try {
      peer = await createCameraPeer();
      final stream = _stream;
      if (!mounted ||
          _session != session ||
          _viewId != view ||
          stream == null) {
        await peer.close();
        await peer.dispose();
        return;
      }
      _peer = peer;
      peer.onDataChannel = (channel) {
        if (_viewId == view && channel.label == 'crowd-grid') {
          _channel = channel;
        }
      };
      await peer.setRemoteDescription(RTCSessionDescription(offer, 'offer'));
      await peer.addTrack(stream.getVideoTracks().single, stream);
      final answer = await gatherCameraDescription(
        peer,
        await peer.createAnswer(),
      );
      if (_session == session && _viewId == view) {
        await widget.store.answer(id, session, view, answer);
      }
    } catch (_) {
      if (_viewId == view) {
        await _disconnect();
        if (mounted && _session == session) {
          setState(
            () => _error =
                'The viewer could not connect. Check that both devices are on the same Wi-Fi.',
          );
        }
      }
    }
  }

  Future<void> _disconnect() async {
    _viewId = null;
    _channel = null;
    final peer = _peer;
    _peer = null;
    await peer?.close();
    await peer?.dispose();
  }

  Future<void> _disposeStream(MediaStream? stream) async {
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  Future<void> _stop({String? message, bool disposing = false}) async {
    ++_generation;
    final id = _selected;
    final session = _session;
    final stream = _stream;
    _session = null;
    _stream = null;
    _heartbeat?.cancel();
    unawaited(_requests?.cancel());
    unawaited(_assignment?.cancel());
    _requests = null;
    _assignment = null;
    _heat = null;
    _error = message;
    _working = !disposing;
    if (mounted && !disposing) setState(() {});
    if (id != null && session != null) {
      unawaited(widget.store.release(id, session).catchError((Object _) {}));
    }
    try {
      try {
        if (stream != null) await _native.invokeMethod<void>('stop');
      } on PlatformException {
        // Release the camera and peer even if the native detector stopped.
      }
      if (stream != null) _preview.srcObject = null;
      await _disconnect();
      await _disposeStream(stream);
    } finally {
      if (mounted && !disposing) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _native.setMethodCallHandler(null);
    unawaited(
      _stop(disposing: true).whenComplete(() async {
        final ready = _previewReady;
        if (ready != null) {
          try {
            await ready;
          } finally {
            await _preview.dispose();
          }
        }
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Attraction Camera'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await _stop();
            await widget.onSignOut();
          },
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Select an assigned attraction and keep this screen open while broadcasting.',
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Attraction>>(
          stream: _places,
          builder: (context, places) =>
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _assignments,
                builder: (context, assignments) {
                  if (places.hasError || assignments.hasError) {
                    return const Text(
                      'Could not load camera assignments. Check your connection and staff access.',
                    );
                  }
                  if (!places.hasData || !assignments.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final ids = assignments.data!.docs
                      .map((doc) => doc.id)
                      .toSet();
                  final choices = places.data!
                      .where((place) => ids.contains(place.id))
                      .toList();
                  if (choices.isEmpty) {
                    return const Text(
                      'Assign a camera in Admin → Crowd Monitoring → Live Cameras.',
                    );
                  }
                  final selected = choices.any((place) => place.id == _selected)
                      ? _selected
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey(selected),
                        initialValue: selected,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Attraction',
                        ),
                        items: [
                          for (final place in choices)
                            DropdownMenuItem(
                              value: place.id,
                              child: Text(place.name),
                            ),
                        ],
                        onChanged: _working || _session != null
                            ? null
                            : (value) => setState(() => _selected = value),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _working
                            ? null
                            : _session != null
                            ? () => _stop()
                            : selected == null
                            ? null
                            : () => _start(selected),
                        icon: Icon(
                          _session == null
                              ? Icons.videocam_outlined
                              : Icons.stop_circle_outlined,
                        ),
                        label: Text(
                          _session == null ? 'Start Camera' : 'Stop Camera',
                        ),
                      ),
                    ],
                  );
                },
              ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_session != null) ...[
          const SizedBox(height: 12),
          CameraVideo(renderer: _preview, heat: _heat),
          const SizedBox(height: 8),
          Text(
            _heat == null
                ? 'Starting person detection…'
                : '${_heat!.count} people detected',
          ),
        ],
      ],
    ),
  );
}
