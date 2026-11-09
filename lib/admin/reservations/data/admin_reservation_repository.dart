import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../attractions/models/park_time.dart';
import '../../../reservations/models/reservation.dart';

class AdminReservation {
  const AdminReservation({
    required this.booking,
    required this.visitorId,
    this.visitorName,
  });

  final RideReservation booking;
  final String visitorId;
  final String? visitorName;
}

class AdminReservationRepository {
  const AdminReservationRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<AdminReservation>> watchDay(DateTime day) {
    final start = ParkTime.instant(day.year, day.month, day.day, 0, 0);
    final names = <String, String?>{};
    return _db
        .collection('reservations')
        .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where(
          'startsAt',
          isLessThan: Timestamp.fromDate(ParkTime.dayEnd(start)),
        )
        .orderBy('startsAt')
        .snapshots()
        .asyncMap((snapshot) async {
          final records = snapshot.docs.map((doc) {
            final data = doc.data();
            return (
              booking: RideReservation.fromMap(doc.id, data),
              visitorId: data['ownerUid'] as String? ?? '',
            );
          }).toList();
          final pending = records
              .map((record) => record.visitorId)
              .where((id) => id.isNotEmpty && !names.containsKey(id))
              .toSet()
              .toList();
          // Fetch only the visitors on this date. Firestore allows 30 IDs per query.
          for (var offset = 0; offset < pending.length; offset += 30) {
            final ids = pending.skip(offset).take(30).toList();
            try {
              final profiles = await _db
                  .collection('visitors')
                  .where(FieldPath.documentId, whereIn: ids)
                  .get();
              for (final id in ids) {
                names[id] = null;
              }
              for (final profile in profiles.docs) {
                final name = profile.data()['fullName'];
                if (name is String && name.trim().isNotEmpty) {
                  names[profile.id] = name.trim();
                }
              }
            } on FirebaseException {
              // Booking references are still useful if profiles cannot be loaded.
            }
          }
          return [
            for (final record in records)
              AdminReservation(
                booking: record.booking,
                visitorId: record.visitorId,
                visitorName: names[record.visitorId],
              ),
          ];
        });
  }
}
