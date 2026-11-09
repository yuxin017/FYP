import 'package:cloud_firestore/cloud_firestore.dart';
import '../visitor/models/tickets.dart';

DateTime? adminDate(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
    ? value
    : null;
String adminDateLabel(DateTime? date) => date == null
    ? 'Not recorded'
    : displayParkDate(
        visitDateString(date.toUtc().add(const Duration(hours: 8))),
      );
String adminTimeLabel(DateTime? date) {
  if (date == null) return 'Not recorded';
  final value = date.toUtc().add(const Duration(hours: 8));
  return '${adminDateLabel(date)}, ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String visitorReference(String uid) =>
    'VST-${uid.substring(0, uid.length < 8 ? uid.length : 8).toUpperCase()}';
String titleCase(String value) =>
    value.isEmpty ? '' : value[0].toUpperCase() + value.substring(1);

class AdminVisitor {
  final String id;
  final Map<String, dynamic> data, metadata, access;
  const AdminVisitor(
    this.id,
    this.data, {
    this.metadata = const {},
    this.access = const {},
  });
  String get name => data['fullName'] as String? ?? 'Visitor';
  String get email => data['email'] as String? ?? '';
  String get phone => data['phoneNumber'] as String? ?? '';
  String get photo => data['profilePhotoBase64'] as String? ?? '';
  String get status => access['status'] as String? ?? 'active';
  String get membership => metadata['membership'] as String? ?? 'normal';
  String get risk => metadata['riskLevel'] as String? ?? 'normal';
  String get note => metadata['notes'] as String? ?? '';
  bool get watchlisted => metadata['watchlisted'] == true;
  int get points => (data['loyaltyPoints'] as num?)?.toInt() ?? 0;
  DateTime? get joined => adminDate(data['createdAt']);
  DateTime? get birthday => adminDate(data['dateOfBirth']);
  String get gender => data['gender'] as String? ?? 'Not provided';
  String get height =>
      data['heightCm'] == null ? 'Not provided' : '${data['heightCm']} cm';
  List<String> get interests =>
      (data['parkInterests'] as List?)?.whereType<String>().toList() ?? [];
  List<String> get food =>
      (data['foodPreferences'] as List?)?.whereType<String>().toList() ?? [];
}

class AdminPackage {
  final String id;
  final Map<String, dynamic> data;
  const AdminPackage(this.id, this.data);
  TicketPackage get pass => TicketPackage.fromMap(id, data);
  bool get active => data['active'] == true;
}

class PackageDraft {
  final String name, description, category;
  final int priceMinor, durationDays, sortOrder;
  final int? childPriceMinor;
  final bool active;
  const PackageDraft({
    required this.name,
    required this.description,
    required this.category,
    required this.priceMinor,
    required this.durationDays,
    this.childPriceMinor,
    this.sortOrder = 0,
    this.active = true,
  });
  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'description': description.trim(),
    'category': category,
    'priceMinor': priceMinor,
    if (childPriceMinor != null) 'childPriceMinor': childPriceMinor,
    'durationDays': durationDays,
    'sortOrder': sortOrder,
    'active': active,
    'currency': 'MYR',
    'imageAsset': category == 'annual' ? ticketAnnualAsset : ticketCastleAsset,
  };
}

int? parseMoneyMinor(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final result =
      int.parse(parts[0]) * 100 +
      (parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return result > 0 && result <= 10000000 ? result : null;
}

class AdminActivity {
  final String id;
  final Map<String, dynamic> data;
  const AdminActivity(this.id, this.data);
  DateTime? get at => adminDate(data['createdAt']);
  String get action => data['outcome'] == 'admitted'
      ? 'park_admission'
      : data['action'] as String? ?? 'session_opened';
  String get ownerUid => data['ownerUid'] as String? ?? '';
}

class AdmissionResult {
  final String state, message;
  final ParkTicket ticket;
  final DateTime? admittedAt;
  const AdmissionResult(
    this.state,
    this.message,
    this.ticket, {
    this.admittedAt,
  });
  bool get accepted => state == 'accepted';
}

String csvContent(List<String> headers, List<List<Object?>> rows) {
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  return '\uFEFF${[headers, ...rows].map((row) => row.map(cell).join(',')).join('\r\n')}\r\n';
}
