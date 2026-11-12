import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../attractions/models/attraction.dart';
import '../admin_widgets.dart';
import 'attraction_camera_store.dart';
import 'camera_heatmap.dart';
import 'camera_peer.dart';

class LiveCamerasPanel extends StatefulWidget {
  const LiveCamerasPanel({super.key, required this.store});
  final AttractionCameraStore store;

  @override
  State<LiveCamerasPanel> createState() => _LiveCamerasPanelState();
}

class _LiveCamerasPanelState extends State<LiveCamerasPanel> {
  late final _places = widget.store.attractions.watchAttractions();
  late final _assignments = widget.store.assignments.snapshots();
  String? _selected;
  bool _saving = false;
  String? _error;

  Future<void> _save(String id, bool enabled) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.setEnabled(id, enabled);
      if (mounted) setState(() => _selected = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The camera assignment could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Attraction>>(
    stream: _places,
    builder: (context, places) =>
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _assignments,
          builder: (context, assignments) {
            if (places.hasError || assignments.hasError) {
              return const AdminEmpty(
                'Cameras could not load',
                'Check your connection and administrator access.',
              );
            }
            if (!places.hasData || !assignments.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final enabled = assignments.data!.docs.map((doc) => doc.id).toSet();
            final rides = places.data!.where((place) => place.isRide).toList();
            final available = rides
                .where((place) => !enabled.contains(place.id))
                .toList();
            final assigned = rides.where((place) => enabled.contains(place.id));
            final selected = available.any((place) => place.id == _selected)
                ? _selected
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assign an Attraction Camera',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Assign an attraction here, then select it on the Android camera station.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 300,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(selected),
                              initialValue: selected,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Attraction',
                              ),
                              items: [
                                for (final place in available)
                                  DropdownMenuItem(
                                    value: place.id,
                                    child: Text(place.name),
                                  ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (id) => setState(() => _selected = id),
                            ),
                          ),
                          AdminButton(
                            'Assign Camera',
                            icon: Icons.add,
                            onPressed: selected == null || _saving
                                ? null
                                : () => _save(selected, true),
                          ),
                        ],
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (assigned.isEmpty)
                  const AdminEmpty(
                    'No attraction cameras assigned',
                    'Choose an attraction to add a camera.',
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 900
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final place in assigned)
                          SizedBox(
                            key: ValueKey(place.id),
                            width: width,
                            child: _CameraTile(
                              place: place,
                              store: widget.store,
                              onRemove: _saving
                                  ? null
                                  : () => _save(place.id, false),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
  );
}

class _CameraTile extends StatefulWidget {
  const _CameraTile({
    required this.place,
    required this.store,
    required this.onRemove,
  });
  final Attraction place;
  final AttractionCameraStore store;
  final VoidCallback? onRemove;
  @override
  State<_CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends State<_CameraTile> {
  late final _feed = widget.store.broadcast(widget.place.id).snapshots();
  Timer? _clock;
  String? _watching;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 3), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _feed,
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final online =
              !snapshot.hasError &&
              AttractionCameraStore.isFresh(data, DateTime.now());
          final session = online ? data!['session'] as String : null;
          final viewing = session != null && session == _watching;
          return AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.place.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove camera assignment',
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.link_off),
                    ),
                  ],
                ),
                Text(
                  snapshot.hasError
                      ? 'Camera status unavailable'
                      : online
                      ? 'Camera online'
                      : 'Camera offline',
                  style: TextStyle(
                    color: online ? Colors.green.shade800 : adminMuted,
                  ),
                ),
                const SizedBox(height: 12),
                if (viewing)
                  _CameraViewer(
                    key: ValueKey(session),
                    store: widget.store,
                    attractionId: widget.place.id,
                    session: session,
                  ),
                if (online)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _watching = viewing ? null : session),
                      icon: Icon(
                        viewing
                            ? Icons.stop_circle_outlined
                            : Icons.videocam_outlined,
                      ),
                      label: Text(viewing ? 'Close Feed' : 'View Camera'),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _CameraViewer extends StatefulWidget {
  const _CameraViewer({
    super.key,
    required this.store,
    required this.attractionId,
    required this.session,
  });
  final AttractionCameraStore store;
  final String attractionId, session;
  @override
  State<_CameraViewer> createState() => _CameraViewerState();
}

class _CameraViewerState extends State<_CameraViewer> {
  final _renderer = RTCVideoRenderer();
  late final Future<void> _ready;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _answers;
  RTCPeerConnection? _peer;
  Timer? _timeout, _heatExpiry;
  String? _view, _error;
  CameraHeatmap? _heat;
  bool _showHeat = true, _connected = false;

  @override
  void initState() {
    super.initState();
    _ready = _renderer.initialize();
    unawaited(_open());
  }

  Future<void> _open() async {
    final ref = widget.store.request(widget.attractionId);
    final view = ref.parent.doc().id;
    _view = view;
    try {
      await _ready;
      if (!mounted || _view != view) return;
      final peer = await createCameraPeer();
      if (!mounted || _view != view) {
        await peer.close();
        await peer.dispose();
        return;
      }
      _peer = peer;
      peer.onTrack = (event) {
        if (!mounted || _view != view || event.streams.isEmpty) return;
        _renderer.srcObject = event.streams.first;
      };
      _renderer.onResize = () {
        if (!mounted ||
            _view != view ||
            _renderer.videoWidth == 0 ||
            _connected) {
          return;
        }
        _timeout?.cancel();
        setState(() => _connected = true);
      };
      peer.onConnectionState = (state) {
        if (_view == view &&
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _fail(
            'Camera connection failed. Check that both devices can reach each other on Wi-Fi.',
          );
        }
      };
      await peer.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      final channel = await peer.createDataChannel(
        'crowd-grid',
        RTCDataChannelInit()
          ..ordered = false
          ..maxRetransmits = 0,
      );
      channel.onMessage = (message) {
        if (!mounted || _view != view || message.isBinary) return;
        final heat = CameraHeatmap.decode(message.text);
        if (heat == null) return;
        setState(() => _heat = heat);
        _heatExpiry?.cancel();
        _heatExpiry = Timer(const Duration(seconds: 4), () {
          if (mounted && _view == view) setState(() => _heat = null);
        });
      };
      final offer = await gatherCameraDescription(
        peer,
        await peer.createOffer(),
      );
      if (!mounted || _view != view) return;
      _timeout = Timer(
        const Duration(seconds: 20),
        () => _fail(
          'No video received. Check that the camera is broadcasting and both devices are on the same Wi-Fi.',
        ),
      );
      await widget.store.offer(
        widget.attractionId,
        widget.session,
        view,
        offer,
      );
      if (!mounted || _view != view) {
        unawaited(
          widget.store
              .closeView(widget.attractionId, view)
              .catchError((Object _) {}),
        );
        return;
      }
      var answered = false;
      _answers = ref.snapshots(includeMetadataChanges: true).listen((
        snapshot,
      ) async {
        if (!mounted || _view != view || snapshot.metadata.isFromCache) return;
        final data = snapshot.data();
        if (data?['viewId'] != view) {
          _fail('The view has ended. Reopen the feed to reconnect.');
          return;
        }
        final answer = data?['answer'];
        if (!answered && answer is String) {
          answered = true;
          try {
            await peer.setRemoteDescription(
              RTCSessionDescription(answer, 'answer'),
            );
          } catch (_) {
            if (_view == view) {
              _fail('Could not open the video. Reopen the feed to try again.');
            }
          }
        }
      }, onError: (Object _) => _fail('Camera access was interrupted.'));
    } catch (_) {
      if (_view == view) {
        _fail(
          'Could not start the live feed. Check Wi-Fi and administrator access.',
        );
      }
    }
  }

  void _fail(String message) {
    if (!mounted || _view == null) return;
    setState(() {
      _error = message;
      _connected = false;
      _heat = null;
    });
    unawaited(_close());
  }

  Future<void> _close() async {
    _timeout?.cancel();
    _heatExpiry?.cancel();
    _renderer.onResize = null;
    final view = _view;
    final peer = _peer;
    _view = null;
    _peer = null;
    unawaited(_answers?.cancel());
    _answers = null;
    if (view != null) {
      unawaited(
        widget.store
            .closeView(widget.attractionId, view)
            .catchError((Object _) {}),
      );
    }
    await peer?.close();
    await peer?.dispose();
  }

  @override
  void dispose() {
    unawaited(
      _close().whenComplete(() async {
        try {
          await _ready;
        } finally {
          await _renderer.dispose();
        }
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CameraVideo(renderer: _renderer, heat: _showHeat ? _heat : null),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              !_connected
                  ? 'Connecting to camera…'
                  : _heat == null
                  ? 'Waiting for person detection…'
                  : '${_heat!.count} people detected',
            ),
            FilterChip(
              label: const Text('Heatmap'),
              selected: _showHeat,
              onSelected: (value) => setState(() => _showHeat = value),
            ),
          ],
        ),
      ],
    );
  }
}
