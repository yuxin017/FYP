import 'package:cloud_firestore/cloud_firestore.dart';

class AdmissionTicket {
  const AdmissionTicket({
    required this.id,
    required this.visitDate,
    required this.validUntil,
    required this.status,
    this.label = 'Admission ticket',
    this.guestEmail,
  });
  final String id, visitDate, validUntil, status, label;
  final String? guestEmail;
  bool covers(String day) =>
      (status == 'valid' || status == 'used') &&
      visitDate.compareTo(day) <= 0 &&
      validUntil.compareTo(day) >= 0;
  factory AdmissionTicket.fromMap(String id, Map<String, dynamic> data) =>
      AdmissionTicket(
        id: id,
        visitDate: data['visitDate'] as String? ?? '',
        validUntil:
            data['validUntil'] as String? ?? data['visitDate'] as String? ?? '',
        status: data['status'] as String? ?? '',
        label: data['packageName'] as String? ?? 'Admission ticket',
        guestEmail: data['guestEmail'] as String?,
      );
}

class ReservationVisitor {
  const ReservationVisitor({
    required this.uid,
    required this.name,
    this.heightCm,
    this.photo,
  });
  final String uid, name;
  final int? heightCm;
  final String? photo;
}

class RideReservation {
  const RideReservation({
    required this.id,
    required this.attractionId,
    required this.attractionName,
    required this.slotId,
    required this.ticketId,
    required this.status,
    required this.startsAt,
    required this.endsAt,
  });
  final String id, attractionId, attractionName, slotId, ticketId, status;
  final DateTime startsAt, endsAt;
  factory RideReservation.fromMap(String id, Map<String, dynamic> data) =>
      RideReservation(
        id: id,
        attractionId: data['attractionId'] as String,
        attractionName: data['attractionName'] as String? ?? 'Attraction',
        slotId: data['slotId'] as String,
        ticketId: data['ticketId'] as String,
        status: data['status'] as String,
        startsAt: (data['startsAt'] as Timestamp).toDate(),
        endsAt: (data['endsAt'] as Timestamp).toDate(),
      );
}

class ReservationResult {
  const ReservationResult(this.reservationId, this.status);
  final String reservationId, status;
}
