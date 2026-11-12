import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../visits/visit_repository.dart';
import 'photos/photo_admin_repository.dart';
import 'operations/park_admin_repository.dart';
import '../visitor/models/tickets.dart';
import '../visitor/services/ticket_journey.dart';
import 'admin_models.dart';
import 'cameras/attraction_camera_store.dart';
import '../support/support_repository.dart';
import 'package:flutter/foundation.dart';
import 'attractions/data/admin_attraction_repository.dart';
import 'attractions/data/admin_attraction_store.dart';
import '../attractions/data/attraction_repository.dart';
import '../attractions/data/slot_reader.dart';
import 'auth/attraction_admin_access.dart';
import 'reservations/data/admin_reservation_repository.dart';

/// Same shared Firebase project, with admin sign-in kept separate from the visitor session.
class AdminFirebase {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  AdminFirebase._(this.auth, this.db);
  static Future<AdminFirebase> initialize() async {
    FirebaseApp app;
    try {
      app = Firebase.app('ThemeParkAdmin');
    } catch (_) {
      app = await Firebase.initializeApp(
        name: 'ThemeParkAdmin',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return AdminFirebase._(
      FirebaseAuth.instanceFor(app: app),
      FirebaseFirestore.instanceFor(app: app),
    );
  }
}

abstract class AdminRepository {
  AttractionCameraStore? get cameraStore => null;
  ParkAdminRepository? get parkRepository => null;
  PhotoAdminRepository? get photoRepository => null;
  VisitRepository? get visitRepository => null;
  AdminAttractionStore? get facilityStore => null;
  SlotReader? get facilitySlots => null;
  ValueListenable<bool>? get facilityAccess => null;
  Stream<List<AdminReservation>> reservations(DateTime day) => Stream.value([]);
  void dispose() {}
  SupportRepository? get supportRepository => null;
  String get userId;
  Stream<List<AdminVisitor>> visitors();
  Stream<Map<String, Map<String, dynamic>>> metadata() => Stream.value({});
  Stream<Map<String, Map<String, dynamic>>> access() => Stream.value({});
  Stream<List<AdminPackage>> packages();
  Stream<List<ParkTicket>> tickets();
  Stream<List<TicketOrder>> orders();
  Stream<List<AdminActivity>> sessions() => Stream.value([]);
  Stream<List<AdminActivity>> audit() => Stream.value([]);
  Stream<List<AdminActivity>> admissions() => Stream.value([]);
  Future<void> saveVisitor(
    AdminVisitor visitor,
    Map<String, dynamic> fields,
    Map<String, dynamic> metadata,
  );
  Future<void> setVisitorStatus(List<String> ids, String status, String reason);
  Future<void> setWatchlist(List<AdminVisitor> visitors, bool enabled);
  Future<void> savePackage(String? id, PackageDraft draft);
  Future<ParkTicket> findTicket(String code);
  Future<AdmissionResult> admit(String ticketId, String requestId);
}

class FirebaseAdminRepository extends AdminRepository {
  @override
  AttractionCameraStore get cameraStore => AttractionCameraStore(_db, userId);

  @override
  ParkAdminRepository get parkRepository =>
      FirebaseParkAdminRepository(db: _db, auth: firebase.auth);
  @override
  PhotoAdminRepository get photoRepository =>
      FirebasePhotoAdminRepository(db: _db, auth: firebase.auth);
  @override
  VisitRepository get visitRepository =>
      FirebaseVisitRepository(firestore: _db, authentication: firebase.auth);
  AttractionAdminAccess? _facilityAccess;
  @override
  AdminAttractionStore get facilityStore =>
      AdminAttractionRepository(firestore: _db);
  @override
  SlotReader get facilitySlots => AttractionRepository(firestore: _db);
  @override
  ValueListenable<bool> get facilityAccess =>
      _facilityAccess ??= AttractionAdminAccess(firebase.auth);
  @override
  Stream<List<AdminReservation>> reservations(DateTime day) =>
      AdminReservationRepository(_db).watchDay(day);
  @override
  void dispose() {
    _facilityAccess?.dispose();
    _facilityAccess = null;
  }

  final AdminFirebase firebase;
  FirebaseAdminRepository(this.firebase);
  FirebaseFirestore get _db => firebase.db;
  @override
  String get userId => firebase.auth.currentUser!.uid;
  @override
  SupportRepository get supportRepository => FirebaseSupportRepository(
    firestore: _db,
    userId: userId,
    actorName: firebase.auth.currentUser?.displayName ?? 'Administrator',
    isAdmin: true,
  );
  @override
  Stream<List<AdminVisitor>> visitors() => _db
      .collection('visitors')
      .snapshots()
      .map((s) => s.docs.map((d) => AdminVisitor(d.id, d.data())).toList());
  Stream<Map<String, Map<String, dynamic>>> _maps(String collection) => _db
      .collection(collection)
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: d.data()});
  @override
  Stream<Map<String, Map<String, dynamic>>> metadata() => _maps('visitorAdmin');
  @override
  Stream<Map<String, Map<String, dynamic>>> access() => _maps('visitorAccess');
  @override
  Stream<List<AdminPackage>> packages() => _db
      .collection('ticketPackages')
      .snapshots()
      .map((s) => s.docs.map((d) => AdminPackage(d.id, d.data())).toList());
  @override
  Stream<List<ParkTicket>> tickets() => _db
      .collection('tickets')
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ParkTicket.fromMap(d.id, d.data())).toList(),
      );
  @override
  Stream<List<TicketOrder>> orders() =>
      _db.collection('orders').snapshots().map((s) {
        final list = s.docs
            .map((d) => TicketOrder.fromMap(d.id, d.data()))
            .toList();
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
            a.createdAt ?? DateTime(1970),
          ),
        );
        return list;
      });
  Stream<List<AdminActivity>> _events(String collection) => _db
      .collection(collection)
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map((d) => AdminActivity(d.id, d.data())).toList());
  @override
  Stream<List<AdminActivity>> sessions() => _events('visitorSessions');
  @override
  Stream<List<AdminActivity>> audit() => _events('adminAudit');
  @override
  Stream<List<AdminActivity>> admissions() => _events('admissions');
  Map<String, dynamic> _audit(
    String action,
    List<String> ids,
    Map<String, dynamic> details,
  ) => {
    'action': action,
    'targetIds': ids,
    'actorUid': userId,
    'details': details,
    'createdAt': FieldValue.serverTimestamp(),
  };
  @override
  Future<void> saveVisitor(
    AdminVisitor visitor,
    Map<String, dynamic> fields,
    Map<String, dynamic> metadata,
  ) async {
    final batch = _db.batch();
    if (fields.isNotEmpty) {
      batch.update(_db.collection('visitors').doc(visitor.id), fields);
    }
    batch.set(_db.collection('visitorAdmin').doc(visitor.id), {
      'membership': visitor.membership,
      'riskLevel': visitor.risk,
      'watchlisted': visitor.watchlisted,
      'notes': visitor.note,
      ...metadata,
      'updatedBy': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _db.collection('adminAudit').doc(TicketJourney.newId()),
      _audit(
        'visitor_updated',
        [visitor.id],
        {
          'fields': [...fields.keys, ...metadata.keys],
        },
      ),
    );
    await batch.commit();
  }

  @override
  Future<void> setVisitorStatus(
    List<String> ids,
    String status,
    String reason,
  ) async {
    if (ids.isEmpty || ids.length > 50) {
      throw StateError('Select between 1 and 50 visitors.');
    }
    if (status != 'active' && ids.contains(userId)) {
      throw StateError('You cannot restrict your own administrator account.');
    }
    final batch = _db.batch();
    for (final id in ids) {
      batch.set(_db.collection('visitorAccess').doc(id), {
        'status': status,
        'reason': reason.trim(),
        'updatedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(
      _db.collection('adminAudit').doc(TicketJourney.newId()),
      _audit('visitor_status_updated', ids, {
        'status': status,
        'reason': reason.trim(),
      }),
    );
    await batch.commit();
  }

  @override
  Future<void> setWatchlist(List<AdminVisitor> visitors, bool enabled) async {
    final batch = _db.batch();
    for (final v in visitors) {
      batch.set(_db.collection('visitorAdmin').doc(v.id), {
        'membership': v.membership,
        'riskLevel': v.risk,
        'watchlisted': enabled,
        'notes': v.note,
        'updatedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(
      _db.collection('adminAudit').doc(TicketJourney.newId()),
      _audit(
        enabled ? 'watchlist_added' : 'watchlist_removed',
        visitors.map((v) => v.id).toList(),
        {},
      ),
    );
    await batch.commit();
  }

  @override
  Future<void> savePackage(String? id, PackageDraft draft) async {
    final ref = _db
        .collection('ticketPackages')
        .doc(id ?? TicketJourney.newId());
    await _db.runTransaction((tx) async {
      final old = await tx.get(ref);
      if (id != null && !old.exists) {
        throw StateError('This pass no longer exists. Refresh the catalog.');
      }
      final fields = {
        ...old.data() ?? {},
        ...draft.toMap(),
        'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      };
      if (draft.childPriceMinor == null) fields.remove('childPriceMinor');
      tx.set(ref, fields);
      tx.set(
        _db.collection('adminAudit').doc(TicketJourney.newId()),
        _audit(
          old.exists ? 'package_updated' : 'package_created',
          [ref.id],
          {'name': draft.name},
        ),
      );
    });
  }

  @override
  Future<ParkTicket> findTicket(String code) async {
    var id = code.trim();
    if (id.startsWith('TP1:')) id = id.substring(4);
    if (id.startsWith('TP-')) {
      final ref = await _db
          .collection('ticketReferences')
          .doc(id.toUpperCase())
          .get(const GetOptions(source: Source.server));
      id = ref.data()?['ticketId'] as String? ?? '';
    }
    if (!RegExp(r'^[a-f0-9]{48}_([1-9]|10)$').hasMatch(id)) {
      throw StateError(
        'Ticket not found. Check its ID or scan the QR code again.',
      );
    }
    final doc = await _db
        .collection('tickets')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists) {
      throw StateError(
        'Ticket not found. Check its ID or scan the QR code again.',
      );
    }
    return ParkTicket.fromMap(doc.id, doc.data()!);
  }

  @override
  Future<AdmissionResult> admit(String ticketId, String requestId) async {
    final ref = _db.collection('tickets').doc(ticketId);
    return _db.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) throw StateError('This ticket could not be found.');
      final data = snapshot.data()!;
      final ticket = ParkTicket.fromMap(snapshot.id, data);
      final today = parkToday();
      final dayKey = visitDateString(today);
      final day = Timestamp.fromDate(
        DateTime.utc(today.year, today.month, today.day),
      );
      final days =
          (data['admissionDays'] as List?)?.whereType<Timestamp>().toList() ??
          <Timestamp>[];
      if (data['validationId'] == requestId && data['usedBy'] == userId) {
        return AdmissionResult(
          'accepted',
          'Admission already confirmed for this request.',
          ticket,
          admittedAt: adminDate(data['usedAt']),
        );
      }
      if (days.contains(day) || ticket.status == 'used') {
        return AdmissionResult(
          'already-used',
          'This ticket has already been admitted${days.contains(day) ? ' today' : ''}.',
          ticket,
          admittedAt: adminDate(data['usedAt']),
        );
      }
      if (ticket.status != 'valid') {
        return AdmissionResult(
          'unavailable',
          'This ticket is not active.',
          ticket,
        );
      }
      if (ticket.visitDate.compareTo(dayKey) > 0) {
        return AdmissionResult(
          'future',
          'This ticket is valid from ${displayParkDate(ticket.visitDate)}.',
          ticket,
        );
      }
      if (ticket.endDate.compareTo(dayKey) < 0) {
        return AdmissionResult(
          'expired',
          'This ticket expired on ${displayParkDate(ticket.endDate)}.',
          ticket,
        );
      }
      final change = {
        'status': ticket.endDate == dayKey ? 'used' : 'valid',
        'usedAt': FieldValue.serverTimestamp(),
        'usedBy': userId,
        'validationId': requestId,
        'lastAdmissionDay': day,
        'admissionDays': [...days, day],
      };
      tx.update(ref, change);
      tx.set(_db.collection('admissions').doc(requestId), {
        'ticketId': ticketId,
        'orderId': ticket.orderId,
        'ownerUid': ticket.ownerUid,
        'actorUid': userId,
        'visitDay': day,
        'createdAt': FieldValue.serverTimestamp(),
        'outcome': 'admitted',
      });
      return AdmissionResult(
        'accepted',
        'Admission confirmed. Welcome to the park!',
        ParkTicket.fromMap(ticketId, {
          ...data,
          ...change,
          'usedAt': Timestamp.now(),
        }),
        admittedAt: DateTime.now(),
      );
    });
  }
}
