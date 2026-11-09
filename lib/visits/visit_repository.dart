import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/application_api.dart';

class AttractionVisit {
  final String id;
  final Map<String, dynamic> data;
  const AttractionVisit(this.id, this.data);
  String get name => data['attractionName'] as String? ?? 'Attraction';
  String get attractionId => data['attractionId'] as String? ?? '';
  String get status => data['status'] as String? ?? '';
  String? get groupName => data['groupName'] as String?;
  DateTime? get startsAt => (data['startsAt'] as Timestamp?)?.toDate();
  DateTime? get endsAt => (data['endsAt'] as Timestamp?)?.toDate();
  bool get rated => data['ratedAt'] != null;
  int get points => (data['earnedPoints'] as num?)?.toInt() ?? 0;
  bool completedAt(DateTime now) =>
      status == 'checked_in' && endsAt != null && !endsAt!.isAfter(now);
  String stateAt(DateTime now) {
    if (status == 'checked_in') {
      return completedAt(now) ? 'Completed' : 'Checked in';
    }
    if (status == 'cancelled') return 'Cancelled';
    if (status == 'no_show') return 'Missed visit';
    if (endsAt == null || !endsAt!.isAfter(now)) return 'Return window ended';
    if (startsAt == null || startsAt!.isAfter(now)) return 'Upcoming';
    return 'Ready to enter';
  }
}

abstract class VisitRepository {
  Stream<List<AttractionVisit>> visits();
  Stream<AttractionVisit?> visit(String id);
  Stream<Map<String, dynamic>> attraction(String id);
  Stream<int> balance();
  Future<Map<String, dynamic>> checkIn(String id);
  Future<void> rate(
    String id,
    int stars,
    List<String> categories,
    String message,
    bool anonymous,
    String? photo,
  );
}

class FirebaseVisitRepository implements VisitRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  late final api = ApplicationApi(auth: auth);
  FirebaseVisitRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? authentication,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = authentication ?? FirebaseAuth.instance;
  String get uid => auth.currentUser!.uid;
  @override
  Stream<List<AttractionVisit>> visits() => db
      .collection('reservations')
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => AttractionVisit(d.id, d.data())).toList()..sort(
              (a, b) => (b.startsAt ?? DateTime(1970)).compareTo(
                a.startsAt ?? DateTime(1970),
              ),
            ),
      );
  @override
  Stream<AttractionVisit?> visit(String id) => db
      .collection('reservations')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? AttractionVisit(d.id, d.data()!) : null);
  @override
  Stream<Map<String, dynamic>> attraction(String id) => db
      .collection('attractions')
      .doc(id)
      .snapshots()
      .map((d) => d.data() ?? {});
  @override
  Stream<int> balance() => db
      .collection('visitors')
      .doc(uid)
      .snapshots()
      .map((d) => (d.data()?['loyaltyPoints'] as num?)?.toInt() ?? 0);
  @override
  Future<Map<String, dynamic>> checkIn(String id) =>
      api.post('/v1/visits/check-in', {'reservationId': id});
  @override
  Future<void> rate(
    String id,
    int stars,
    List<String> categories,
    String message,
    bool anonymous,
    String? photo,
  ) async {
    await api.post('/v1/visits/rate', {
      'reservationId': id,
      'stars': stars,
      'categories': categories,
      'message': message,
      'anonymous': anonymous,
      'photoBase64': ?photo,
    });
  }
}
