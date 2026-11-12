import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

Future<RTCPeerConnection> createCameraPeer() => createPeerConnection({
  'iceServers': <Object>[],
  'sdpSemantics': 'unified-plan',
});

// Exchange a complete local-network offer or answer in one Firestore write.
Future<RTCSessionDescription> gatherCameraDescription(
  RTCPeerConnection peer,
  RTCSessionDescription description,
) async {
  final gathered = Completer<void>();
  peer.onIceGatheringState = (state) {
    if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
        !gathered.isCompleted) {
      gathered.complete();
    }
  };
  try {
    await peer.setLocalDescription(description);
    if (peer.iceGatheringState !=
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      await gathered.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
    }
    final local = await peer.getLocalDescription();
    if (local?.sdp?.contains('a=candidate:') != true) {
      throw StateError('No local network connection was found. Check Wi-Fi.');
    }
    return local!;
  } finally {
    peer.onIceGatheringState = null;
  }
}
