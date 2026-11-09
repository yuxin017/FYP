import 'dart:async';
import 'package:collaborative_asg/reservations/data/reservation_store.dart';
import 'package:collaborative_asg/reservations/models/reservation.dart';

/// Test-only store. Production always uses authenticated Firebase callables.
class MemoryReservationStore implements ReservationStore {
  @override
  String get uid => 'visitor-test';
  ReservationVisitor? visitor = const ReservationVisitor(
    uid: 'visitor-test',
    name: 'Test Visitor',
    heightCm: 173,
  );
  List<AdmissionTicket> tickets = [];
  List<RideReservation> records = [];
  final _changes = StreamController<void>.broadcast(sync: true);
  final requests = <String>[];
  final cancellations = <String>[];
  Object? error;
  Completer<ReservationResult>? reserveGate;
  int _next = 0;
  @override
  Stream<ReservationVisitor?> watchVisitor() async* {
    yield visitor;
    yield* _changes.stream.map((_) => visitor);
  }

  @override
  Stream<List<AdmissionTicket>> watchAdmissionTickets() async* {
    yield tickets;
    yield* _changes.stream.map((_) => tickets);
  }

  @override
  Stream<List<RideReservation>> watchReservations() async* {
    yield records;
    yield* _changes.stream.map((_) => records);
  }

  void changed() => _changes.add(null);
  @override
  String newRequestId() => 'request-for-testing-${++_next}';
  @override
  Future<ReservationResult> reserve({
    required String slotId,
    required String ticketId,
    required String requestId,
  }) async {
    requests.add(requestId);
    if (error != null) throw error!;
    return reserveGate?.future ??
        Future.value(const ReservationResult('saved-reservation', 'confirmed'));
  }

  @override
  Future<ReservationResult> cancel({
    required String reservationId,
    required String requestId,
  }) async {
    cancellations.add(requestId);
    if (error != null) throw error!;
    records = records
        .map(
          (r) => r.id != reservationId
              ? r
              : RideReservation(
                  id: r.id,
                  attractionId: r.attractionId,
                  attractionName: r.attractionName,
                  slotId: r.slotId,
                  ticketId: r.ticketId,
                  status: 'cancelled',
                  startsAt: r.startsAt,
                  endsAt: r.endsAt,
                ),
        )
        .toList();
    changed();
    return ReservationResult(reservationId, 'cancelled');
  }

  Future<void> dispose() => _changes.close();
}
