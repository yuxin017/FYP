import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../attractions/data/attraction_repository.dart';

class AttractionCameraStore {
  AttractionCameraStore(this.db, this.uid);

  final FirebaseFirestore db;
  final String uid;
  static const freshness = Duration(seconds: 24);

  AttractionRepository get attractions => AttractionRepository(firestore: db);

  CollectionReference<Map<String, dynamic>> get assignments =>
      db.collection('attractionCameras');

  DocumentReference<Map<String, dynamic>> broadcast(String attractionId) =>
      db.collection('cameraBroadcasts').doc(attractionId);

  DocumentReference<Map<String, dynamic>> request(String attractionId) =>
      db.collection('cameraViewRequests').doc(attractionId);

  Future<void> setEnabled(String id, bool enabled) => enabled
      ? assignments.doc(id).set({'enabled': true})
      : assignments.doc(id).delete();

  static bool isFresh(Map<String, dynamic>? data, DateTime now) {
    final timestamp = data?['updatedAt'];
    return timestamp is Timestamp &&
        now.difference(timestamp.toDate()) < freshness;
  }

  Future<void> claim(String id, String session) => db.runTransaction((
    tx,
  ) async {
    final ref = broadcast(id);
    final current = (await tx.get(ref)).data();
    if (isFresh(current, DateTime.now())) {
      throw StateError('This attraction already has a camera broadcasting.');
    }
    tx.set(ref, {
      'session': session,
      'ownerUid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  Future<void> heartbeat(String id, String session) =>
      db.runTransaction((tx) async {
        final ref = broadcast(id);
        if ((await tx.get(ref)).data()?['session'] != session) {
          throw StateError('This camera session has ended.');
        }
        tx.update(ref, {'updatedAt': FieldValue.serverTimestamp()});
      });

  Future<void> release(String id, String session) =>
      _deleteIfCurrent(broadcast(id), 'session', session);

  Future<void> closeView(String id, String viewId) =>
      _deleteIfCurrent(request(id), 'viewId', viewId);

  Future<void> _deleteIfCurrent(
    DocumentReference<Map<String, dynamic>> ref,
    String field,
    String value,
  ) => db.runTransaction((tx) async {
    if ((await tx.get(ref)).data()?[field] == value) tx.delete(ref);
  });

  Future<void> offer(
    String id,
    String session,
    String viewId,
    RTCSessionDescription description,
  ) => request(id).set({
    'session': session,
    'viewId': viewId,
    'viewerUid': uid,
    'offer': description.sdp!,
    'requestedAt': FieldValue.serverTimestamp(),
  });

  Future<void> answer(
    String id,
    String session,
    String viewId,
    RTCSessionDescription description,
  ) => db.runTransaction((tx) async {
    final ref = request(id);
    final current = (await tx.get(ref)).data();
    if (current?['session'] == session && current?['viewId'] == viewId) {
      tx.update(ref, {'answer': description.sdp!});
    }
  });
}
