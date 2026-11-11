import '../models/reservation.dart';

class ReminderDeviceStatus {
  const ReminderDeviceStatus({
    required this.supported,
    required this.enabled,
    this.message,
  });
  final bool supported, enabled;
  final String? message;
}

abstract class ReminderDevice {
  Stream<String> get openings;
  String? takeInitialOpening();
  Future<ReminderDeviceStatus> status(String uid);
  Future<void> enable(String uid);
  Future<void> synchronize(
    String uid,
    List<RideReservation> records,
    Set<String> enabled,
  );
  Future<void> disable(String uid);
  Future<void> endSession(String uid);
}
