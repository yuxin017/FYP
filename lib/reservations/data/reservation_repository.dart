import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/reservation.dart';
import 'reservation_store.dart';
import '../../services/application_api.dart';

class ReservationRepository implements ReservationStore {
  ReservationRepository({
    required this.uid,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    this.email,
    this.useFunctions = const bool.fromEnvironment(
      'USE_FIREBASE_FUNCTIONS',
      defaultValue: false,
    ),
  }) : _db = firestore,
       _functions = functions;
  @override
  final String uid;
  final String? email;
  final bool useFunctions;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  @override
  Stream<ReservationVisitor?> watchVisitor() =>
      _db.collection('visitors').doc(uid).snapshots().map((doc) {
        final data = doc.data();
        if (data == null) return null;
        return ReservationVisitor(
          uid: uid,
          name: data['fullName'] as String? ?? 'You',
          heightCm: data['heightCm'] is int ? data['heightCm'] as int : null,
          photo: data['profilePhotoBase64'] as String?,
        );
      });
  @override
  Stream<List<AdmissionTicket>> watchAdmissionTickets() =>
      watchAccountTickets(firestore: _db, uid: uid, email: email);

  static Stream<List<AdmissionTicket>> watchAccountTickets({
    required FirebaseFirestore firestore,
    required String uid,
    required String? email,
  }) {
    late StreamController<List<AdmissionTicket>> output;
    final owned = <String, AdmissionTicket>{},
        assigned = <String, AdmissionTicket>{};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownerSubscription,
        guestSubscription;
    bool ownerLoaded = false, guestLoaded = email == null;
    void emit() {
      if (!ownerLoaded || !guestLoaded || output.isClosed) return;
      final records = {...owned, ...assigned};
      output.add(
        records.values
            .where(
              (t) =>
                  t.guestEmail == null ||
                  t.guestEmail!.isEmpty ||
                  t.guestEmail!.toLowerCase() == email?.toLowerCase(),
            )
            .toList(),
      );
    }

    output = StreamController<List<AdmissionTicket>>(
      onListen: () {
        ownerSubscription = firestore
            .collection('tickets')
            .where('ownerUid', isEqualTo: uid)
            .snapshots()
            .listen((s) {
              owned.clear();
              for (final d in s.docs) {
                owned[d.id] = AdmissionTicket.fromMap(d.id, d.data());
              }
              ownerLoaded = true;
              emit();
            }, onError: output.addError);
        if (email != null) {
          guestSubscription = firestore
              .collection('tickets')
              .where('guestEmail', isEqualTo: email.toLowerCase())
              .snapshots()
              .listen((s) {
                assigned.clear();
                for (final d in s.docs) {
                  assigned[d.id] = AdmissionTicket.fromMap(d.id, d.data());
                }
                guestLoaded = true;
                emit();
              }, onError: output.addError);
        }
      },
      onCancel: () async {
        await ownerSubscription?.cancel();
        await guestSubscription?.cancel();
      },
    );
    return output.stream;
  }

  @override
  Stream<List<RideReservation>> watchReservations() => _db
      .collection('reservations')
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => RideReservation.fromMap(doc.id, doc.data()))
                .toList()
              ..sort((a, b) => b.startsAt.compareTo(a.startsAt)),
      );
  @override
  String newRequestId() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<ReservationResult> _call(
    String name,
    Map<String, dynamic> input,
  ) async {
    final Map<String, dynamic> data;
    if (useFunctions) {
      data =
          (await _functions
                  .httpsCallable(name)
                  .call<Map<String, dynamic>>(input))
              .data;
    } else {
      data = await ApplicationApi().post(
        name == 'reserveSlot'
            ? '/v1/reservations/reserve'
            : '/v1/reservations/cancel',
        input,
      );
    }
    return ReservationResult(
      data['reservationId'] as String,
      data['status'] as String,
    );
  }

  @override
  Future<ReservationResult> reserve({
    required String slotId,
    required String ticketId,
    required String requestId,
  }) => _call('reserveSlot', {
    'slotId': slotId,
    'ticketId': ticketId,
    'requestId': requestId,
  });
  @override
  Future<ReservationResult> cancel({
    required String reservationId,
    required String requestId,
  }) => _call('cancelReservation', {
    'reservationId': reservationId,
    'requestId': requestId,
  });
}

String reservationErrorMessage(Object error) {
  if (error is ApplicationApiException) return error.message;
  if (error is FirebaseFunctionsException) {
    if ((error.code == 'not-found' && error.details == null) ||
        error.code == 'unavailable' ||
        error.code == 'internal' ||
        error.code == 'unknown' ||
        error.code == 'deadline-exceeded') {
      return 'The reservation service is unavailable right now. Your selected details have been kept. Try again later.';
    }
    return error.message?.trim().isNotEmpty == true
        ? error.message!
        : 'Unable to complete this reservation. Please retry.';
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'You do not have permission to load this information. Please sign in again.';
  }
  return 'Unable to complete this request. Your selected details have been kept. Please retry.';
}
