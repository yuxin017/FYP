import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../visitor/models/tickets.dart';

const supportCategories = [
  'App Experience',
  'Tickets & Admission',
  'Payments & Billing',
  'Rides & Attractions',
  'Food & Beverage',
  'Photo Services',
  'Accessibility',
  'Guest Services',
  'Compliments',
];
const supportTypes = {
  'feedback': 'Feedback',
  'problem': 'Problem',
  'complaint': 'Complaint',
};
const supportStatuses = {
  'new': 'New',
  'in_progress': 'In Progress',
  'resolved': 'Resolved',
};
const supportPriorities = {'low': 'Low', 'medium': 'Medium', 'high': 'High'};
DateTime? supportDate(dynamic value) =>
    value is Timestamp ? value.toDate() : null;
String supportDay(DateTime? date) => date == null
    ? 'Just now'
    : displayParkDate(visitDateString(parkToday(date)));
String supportTime(DateTime? date) {
  if (date == null) return 'Just now';
  final local = date.toUtc().add(const Duration(hours: 8));
  return '${supportDay(date)} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

DateTime supportDueDate(DateTime createdAt) {
  var day = parkToday(createdAt);
  var count = 0;
  while (count < 5) {
    day = day.add(const Duration(days: 1));
    if (day.weekday <= 5) count++;
  }
  return DateTime.utc(
    day.year,
    day.month,
    day.day + 1,
  ).subtract(const Duration(hours: 8));
}

class SupportAttachment {
  final String name, mime;
  final Uint8List bytes;
  SupportAttachment(this.name, this.mime, this.bytes);
  int get size => bytes.length;
  String get hash => sha256.convert(bytes).toString();
  Map<String, dynamic> get metadata => {
    'name': name,
    'mime': mime,
    'size': size,
    'sha256': hash,
  };
  Map<String, dynamic> toMap() => {...metadata, 'base64': base64Encode(bytes)};
  factory SupportAttachment.fromMap(Map<String, dynamic> data) =>
      SupportAttachment(
        data['name'] as String,
        data['mime'] as String,
        base64Decode(data['base64'] as String),
      );
}

class SupportDraft {
  final String type, category, subject, message, orderId;
  final bool contactConsent;
  final SupportAttachment? attachment;
  const SupportDraft({
    this.type = 'feedback',
    this.category = 'App Experience',
    this.subject = '',
    this.message = '',
    this.orderId = '',
    this.contactConsent = false,
    this.attachment,
  });
  String? get validation {
    if (!supportTypes.containsKey(type) ||
        !supportCategories.contains(category)) {
      return 'Choose a submission type and category.';
    }
    if (subject.trim().length < 3 || subject.trim().length > 100) {
      return 'Enter a subject between 3 and 100 characters.';
    }
    if (message.trim().length < 10 || message.trim().length > 500) {
      return 'Enter a message between 10 and 500 characters.';
    }
    if (attachment != null &&
        (attachment!.size < 1 || attachment!.size > 512000)) {
      return 'Choose a photo or PDF no larger than 500 KB.';
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    'category': category,
    'subject': subject.trim(),
    'message': message.trim(),
    'orderId': orderId,
    'contactConsent': contactConsent,
    'attachment': attachment?.toMap(),
  };
  String get fingerprint =>
      sha256.convert(utf8.encode(jsonEncode(toMap()))).toString();
  factory SupportDraft.fromMap(Map<String, dynamic> data) => SupportDraft(
    type: data['type'] as String,
    category: data['category'] as String,
    subject: data['subject'] as String,
    message: data['message'] as String,
    orderId: data['orderId'] as String? ?? '',
    contactConsent: data['contactConsent'] as bool,
    attachment: data['attachment'] == null
        ? null
        : SupportAttachment.fromMap(
            Map<String, dynamic>.from(data['attachment'] as Map),
          ),
  );
}

class SupportCase {
  final String id;
  final Map<String, dynamic> data;
  const SupportCase(this.id, this.data);
  String get ownerUid => data['ownerUid'] as String? ?? '';
  String get ownerName => data['ownerName'] as String? ?? 'Visitor';
  String get type => data['type'] as String? ?? 'feedback';
  String get subject => data['subject'] as String? ?? '';
  String get message => data['message'] as String? ?? '';
  String get category => data['category'] as String? ?? 'App Experience';
  String get status => data['status'] as String? ?? 'new';
  String get priority => data['priority'] as String? ?? 'medium';
  String get assigneeUid => data['assigneeUid'] as String? ?? '';
  String get assigneeName => data['assigneeName'] as String? ?? '';
  String get resolution => data['resolution'] as String? ?? '';
  String get contactEmail => data['contactEmail'] as String? ?? '';
  String get orderId => data['orderId'] as String? ?? '';
  DateTime? get createdAt => supportDate(data['createdAt']);
  DateTime? get updatedAt => supportDate(data['updatedAt']);
  DateTime? get firstResponseAt => supportDate(data['firstResponseAt']);
  DateTime? get resolvedAt => supportDate(data['resolvedAt']);
  Map<String, dynamic>? get attachment => data['attachment'] is Map
      ? Map<String, dynamic>.from(data['attachment'] as Map)
      : null;
  bool get overdue =>
      status != 'resolved' &&
      createdAt != null &&
      DateTime.now().isAfter(supportDueDate(createdAt!));
  String get reference {
    final prefix =
        {'feedback': 'FDB', 'problem': 'PRB', 'complaint': 'CMP'}[type] ??
        'CASE';
    final day = visitDateString(parkToday(createdAt));
    return '$prefix-${day.replaceAll('-', '')}-${id.substring(0, id.length < 10 ? id.length : 10).toUpperCase()}';
  }

  bool matches(String query) =>
      '$id $reference $ownerName $subject $message $category $assigneeName'
          .toLowerCase()
          .contains(query.trim().toLowerCase());
}

class SupportMessage {
  final String id;
  final Map<String, dynamic> data;
  const SupportMessage(this.id, this.data);
  String get body => data['body'] as String? ?? '';
  String get role => data['role'] as String? ?? 'visitor';
  String get author => data['authorName'] as String? ?? 'Support Team';
  DateTime? get createdAt => supportDate(data['createdAt']);
}

class SupportEvent {
  final String id;
  final Map<String, dynamic> data;
  const SupportEvent(this.id, this.data);
  DateTime? get createdAt => supportDate(data['createdAt']);
  String get description => switch (data['action']) {
    'resolved' => 'Case resolved',
    'reopened' => 'Case reopened',
    _ => 'Case details updated',
  };
  String get actor => data['actorName'] as String? ?? 'Support Team';
}
