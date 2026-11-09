import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/application_api.dart';
import '../attractions/data/attraction_repository.dart';
import '../attractions/models/attraction.dart';
import '../attractions/models/attraction_slot.dart';
import '../visits/visit_repository.dart';

class GroupRecord {
  final String id;
  final Map<String, dynamic> data;
  const GroupRecord(this.id, this.data);
  String get name => data['name'] as String? ?? 'Park group';
  String get ownerUid => data['ownerUid'] as String? ?? '';
  String get visitDate => data['visitDate'] as String? ?? '';
}

abstract class GroupRepository {
  String get uid;
  String newRequestId();
  Stream<List<GroupRecord>> groups();
  Stream<GroupRecord?> group(String id);
  Stream<List<GroupRecord>> members(String id);
  Stream<List<GroupRecord>> bookings(String id);
  Stream<List<GroupRecord>> locations(String id);
  Stream<List<AttractionVisit>> passes(String bookingId, String groupId);
  Stream<List<Attraction>> attractions();
  Stream<List<AttractionSlot>> slots(String attractionId);
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  );
  VisitRepository get visitRepository;
}

class FirebaseGroupRepository implements GroupRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  FirebaseGroupRepository({
    FirebaseAuth? authentication,
    FirebaseFirestore? firestore,
  }) : auth = authentication ?? FirebaseAuth.instance,
       db = firestore ?? FirebaseFirestore.instance;
  @override
  String get uid => auth.currentUser!.uid;
  @override
  String newRequestId() => List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  Stream<List<GroupRecord>> records(Query<Map<String, dynamic>> query) => query
      .snapshots()
      .map((s) => s.docs.map((d) => GroupRecord(d.id, d.data())).toList());
  @override
  Stream<List<GroupRecord>> groups() =>
      records(db.collection('groups').where('memberUids', arrayContains: uid));
  @override
  Stream<GroupRecord?> group(String id) => db
      .collection('groups')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? GroupRecord(d.id, d.data()!) : null);
  @override
  Stream<List<GroupRecord>> members(String id) =>
      records(db.collection('groupMembers').where('groupId', isEqualTo: id));
  @override
  Stream<List<GroupRecord>> bookings(String id) =>
      records(db.collection('groupBookings').where('groupId', isEqualTo: id));
  @override
  Stream<List<GroupRecord>> locations(String id) =>
      records(db.collection('groupLocations').where('groupId', isEqualTo: id));
  @override
  Stream<List<AttractionVisit>> passes(String bookingId, String groupId) => db
      .collection('reservations')
      .where('groupBookingId', isEqualTo: bookingId)
      .where('groupId', isEqualTo: groupId)
      .snapshots()
      .map((s) => s.docs.map((d) => AttractionVisit(d.id, d.data())).toList());
  @override
  Stream<List<Attraction>> attractions() =>
      AttractionRepository(firestore: db).watchAttractions();
  @override
  Stream<List<AttractionSlot>> slots(String attractionId) =>
      AttractionRepository(firestore: db).watchAttractionSlots(attractionId);
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) => ApplicationApi(auth: auth).post('/v1/groups/$action', data);
  @override
  VisitRepository get visitRepository =>
      FirebaseVisitRepository(firestore: db, authentication: auth);
}
