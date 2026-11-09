import '../models/reservation.dart';

abstract class ReservationStore {
  String get uid;
  Stream<ReservationVisitor?> watchVisitor();
  Stream<List<AdmissionTicket>> watchAdmissionTickets();
  Stream<List<RideReservation>> watchReservations();
  String newRequestId();
  Future<ReservationResult> reserve({
    required String slotId,
    required String ticketId,
    required String requestId,
  });
  Future<ReservationResult> cancel({
    required String reservationId,
    required String requestId,
  });
}
