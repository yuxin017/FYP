import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/application_api.dart';

abstract class ParkAdminRepository {
  Stream<List<Map<String, dynamic>>> records(String collection);
  Stream<Map<String, dynamic>> settings(String id);
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  );
}

class FirebaseParkAdminRepository implements ParkAdminRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  FirebaseParkAdminRepository({required this.db, required this.auth});
  @override
  Stream<List<Map<String, dynamic>>> records(String collection) {
    if (![
      'campaigns',
      'rewardCatalogue',
      'parkWeather',
      'landmarkReferences',
      'attractions',
    ].contains(collection)) {
      throw ArgumentError('Unknown park section.');
    }
    return db
        .collection(collection)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  @override
  Stream<Map<String, dynamic>> settings(String id) => db
      .collection('parkSettings')
      .doc(id)
      .snapshots()
      .map((d) => d.data() ?? {});
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) => ApplicationApi(auth: auth).post(
    '/v1/${['saveLandmark', 'setLandmarkActive', 'anomalies', 'crowd'].contains(action) ? 'ai' : 'park'}/$action',
    data,
  );
}
