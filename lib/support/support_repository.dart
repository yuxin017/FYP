import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support_models.dart';
import '../visitor/models/tickets.dart';

String newSupportId() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

abstract class SupportRepository {
  String? get userId;
  bool get isAdmin => false;
  Stream<List<SupportCase>> cases();
  Stream<List<SupportMessage>> messages(String caseId);
  Stream<List<SupportMessage>> notes(String caseId) => Stream.value([]);
  Stream<List<SupportEvent>> events(String caseId) => Stream.value([]);
  Future<SupportCase?> findCase(String id);
  Future<SupportCase> submit(String id, SupportDraft draft);
  Future<void> reply(SupportCase record, String id, String body);
  Future<void> note(SupportCase record, String id, String body) =>
      throw StateError('Please sign in as an administrator.');
  Future<void> updateCase(
    SupportCase record, {
    required String status,
    required String priority,
    required String category,
    required String assigneeUid,
    required String assigneeName,
    String resolution = '',
  }) => throw StateError('Please sign in as an administrator.');
  Future<void> reopen(SupportCase record);
  Future<SupportAttachment> attachment(SupportCase record);
  Stream<List<TicketOrder>> orders() => Stream.value([]);
  Future<TicketOrder?> relatedOrder(SupportCase record) async => null;
}

class FirebaseSupportRepository extends SupportRepository {
  final FirebaseFirestore db;
  final String? uid;
  final String actorName;
  @override
  final bool isAdmin;
  FirebaseSupportRepository({
    FirebaseFirestore? firestore,
    String? userId,
    this.actorName = '',
    this.isAdmin = false,
  }) : db = firestore ?? FirebaseFirestore.instance,
       uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
  @override
  String? get userId => uid;
  String get actor =>
      uid ?? (throw StateError('Please sign in to send a request.'));
  @override
  Stream<List<SupportCase>> cases() {
    if (uid == null) return Stream.value([]);
    Query<Map<String, dynamic>> query = db.collection('supportCases');
    if (!isAdmin) query = query.where('ownerUid', isEqualTo: uid);
    return query.snapshots().map(
      (s) => s.docs.map((d) => SupportCase(d.id, d.data())).toList()
        ..sort(
          (a, b) => (b.updatedAt ?? DateTime(1970)).compareTo(
            a.updatedAt ?? DateTime(1970),
          ),
        ),
    );
  }

  Stream<List<SupportMessage>> _messages(String collection, String caseId) {
    Query<Map<String, dynamic>> query = db
        .collection(collection)
        .where('caseId', isEqualTo: caseId);
    if (!isAdmin) query = query.where('ownerUid', isEqualTo: uid);
    return query.snapshots().map(
      (s) => s.docs.map((d) => SupportMessage(d.id, d.data())).toList()
        ..sort(
          (a, b) => (a.createdAt ?? DateTime(1970)).compareTo(
            b.createdAt ?? DateTime(1970),
          ),
        ),
    );
  }

  @override
  Stream<List<SupportMessage>> messages(String caseId) =>
      _messages('supportMessages', caseId);
  @override
  Stream<List<SupportMessage>> notes(String caseId) =>
      _messages('supportNotes', caseId);
  @override
  Stream<List<SupportEvent>> events(String caseId) {
    Query<Map<String, dynamic>> query = db
        .collection('supportEvents')
        .where('caseId', isEqualTo: caseId);
    if (!isAdmin) query = query.where('ownerUid', isEqualTo: uid);
    return query.snapshots().map(
      (s) => s.docs.map((d) => SupportEvent(d.id, d.data())).toList()
        ..sort(
          (a, b) => (a.createdAt ?? DateTime(1970)).compareTo(
            b.createdAt ?? DateTime(1970),
          ),
        ),
    );
  }

  Future<String> _name(Transaction tx) async {
    final profile = await tx.get(db.collection('visitors').doc(actor));
    final name = (profile.data()?['fullName'] as String? ?? actorName).trim();
    if (name.isEmpty) {
      throw StateError(
        'Please save your name in Profile before sending a request.',
      );
    }
    return name.length > 100 ? name.substring(0, 100) : name;
  }

  @override
  Future<SupportCase?> findCase(String id) async {
    final doc = await db
        .collection('supportCases')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    return doc.exists ? SupportCase(doc.id, doc.data()!) : null;
  }

  @override
  Future<SupportCase> submit(String id, SupportDraft draft) async {
    if (draft.validation != null) throw StateError(draft.validation!);
    final ref = db.collection('supportCases').doc(id);
    return db.runTransaction((tx) async {
      final previous = await tx.get(ref);
      if (previous.exists) {
        if (previous.data()!['ownerUid'] != actor ||
            previous.data()!['fingerprint'] != draft.fingerprint) {
          throw StateError(
            'This request reference has already been used. Open My Requests to review it.',
          );
        }
        return SupportCase(id, previous.data()!);
      }
      final name = await _name(tx);
      if (draft.orderId.isNotEmpty) {
        final booking = await tx.get(
          db.collection('orders').doc(draft.orderId),
        );
        if (!booking.exists || booking.data()!['ownerUid'] != actor) {
          throw StateError('Choose a booking from your own purchase history.');
        }
      }
      final data = <String, dynamic>{
        'ownerUid': actor,
        'ownerName': name,
        'type': draft.type,
        'category': draft.category,
        'subject': draft.subject.trim(),
        'message': draft.message.trim(),
        'orderId': draft.orderId,
        'contactConsent': draft.contactConsent,
        'contactEmail': draft.contactConsent
            ? (FirebaseAuth.instance.currentUser?.email ?? '')
            : '',
        'fingerprint': draft.fingerprint,
        'attachment': draft.attachment?.metadata,
        'status': 'new',
        'priority': 'medium',
        'assigneeUid': '',
        'assigneeName': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'firstResponseAt': null,
        'resolvedAt': null,
        'resolution': '',
        'messageCount': 0,
        'lastMessageId': '',
        'lastEventId': '',
      };
      tx.set(ref, data);
      final file = draft.attachment;
      if (file != null) {
        tx.set(db.collection('supportAttachments').doc(id), {
          'ownerUid': actor,
          'caseId': id,
          ...file.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return SupportCase(id, {
        ...data,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    });
  }

  @override
  Future<void> reply(SupportCase record, String id, String body) async {
    final text = body.trim();
    if (text.length < 2 || text.length > 2000) {
      throw StateError('Enter a reply between 2 and 2,000 characters.');
    }
    final ref = db.collection('supportCases').doc(record.id),
        message = db.collection('supportMessages').doc('${record.id}_$id');
    await db.runTransaction((tx) async {
      final existing = await tx.get(message);
      if (existing.exists) {
        if (existing.data()!['authorUid'] != actor ||
            existing.data()!['body'] != text) {
          throw StateError(
            'This reply has already been sent. Please review the conversation.',
          );
        }
        return;
      }
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('This request could not be found.');
      final current = SupportCase(doc.id, doc.data()!);
      if (current.status == 'resolved') {
        throw StateError('Reopen this request before sending another reply.');
      }
      final name = await _name(tx);
      tx.set(message, {
        'ownerUid': current.ownerUid,
        'caseId': current.id,
        'authorUid': actor,
        'authorName': name,
        'role': isAdmin ? 'admin' : 'visitor',
        'body': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': (current.data['messageCount'] as int) + 1,
        'lastMessageId': message.id,
        if (isAdmin) 'status': 'in_progress',
        if (isAdmin && current.firstResponseAt == null)
          'firstResponseAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> note(SupportCase record, String id, String body) async {
    final text = body.trim();
    if (text.length < 2 || text.length > 2000) {
      throw StateError('Enter a note between 2 and 2,000 characters.');
    }
    final ref = db.collection('supportNotes').doc('${record.id}_$id');
    await db.runTransaction((tx) async {
      final old = await tx.get(ref);
      if (old.exists) {
        if (old.data()!['body'] != text || old.data()!['authorUid'] != actor) {
          throw StateError('This note reference has already been used.');
        }
        return;
      }
      final name = await _name(tx);
      tx.set(ref, {
        'ownerUid': record.ownerUid,
        'caseId': record.id,
        'authorUid': actor,
        'authorName': name,
        'role': 'admin',
        'body': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> updateCase(
    SupportCase record, {
    required String status,
    required String priority,
    required String category,
    required String assigneeUid,
    required String assigneeName,
    String resolution = '',
  }) async {
    if (!supportStatuses.containsKey(status) ||
        !supportPriorities.containsKey(priority) ||
        !supportCategories.contains(category)) {
      throw StateError('Review the case fields.');
    }
    if (status == 'resolved' &&
        (resolution.trim().length < 5 || resolution.trim().length > 500)) {
      throw StateError(
        'Add a resolution summary between 5 and 500 characters.',
      );
    }
    final ref = db.collection('supportCases').doc(record.id),
        event = db
            .collection('supportEvents')
            .doc('${record.id}_${newSupportId()}');
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('This case could not be found.');
      final current = SupportCase(doc.id, doc.data()!);
      if (current.data['updatedAt'] != record.data['updatedAt']) {
        throw StateError(
          'Another update was saved for this case. Reopen it to review the latest details.',
        );
      }
      final name = await _name(tx);
      final finalResolution = status == 'resolved' ? resolution.trim() : '';
      if (current.status == status &&
          current.priority == priority &&
          current.category == category &&
          current.assigneeUid == assigneeUid &&
          current.assigneeName == assigneeName &&
          current.resolution == finalResolution) {
        return;
      }
      final action = current.status != status && status == 'resolved'
          ? 'resolved'
          : current.status == 'resolved' && status != 'resolved'
          ? 'reopened'
          : 'updated';
      tx.set(event, {
        'caseId': record.id,
        'ownerUid': current.ownerUid,
        'actorUid': actor,
        'actorName': name,
        'action': action,
        'fromStatus': current.status,
        'toStatus': status,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'status': status,
        'priority': priority,
        'category': category,
        'assigneeUid': assigneeUid,
        'assigneeName': assigneeName,
        'resolution': finalResolution,
        'resolvedAt': status == 'resolved'
            ? (current.resolvedAt == null
                  ? FieldValue.serverTimestamp()
                  : current.data['resolvedAt'])
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastEventId': event.id,
      });
    });
  }

  @override
  Future<void> reopen(SupportCase record) async {
    final ref = db.collection('supportCases').doc(record.id),
        event = db
            .collection('supportEvents')
            .doc('${record.id}_${newSupportId()}');
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('This request could not be found.');
      final current = SupportCase(doc.id, doc.data()!);
      if (current.status != 'resolved') return;
      final name = await _name(tx);
      tx.set(event, {
        'caseId': current.id,
        'ownerUid': current.ownerUid,
        'actorUid': actor,
        'actorName': name,
        'action': 'reopened',
        'fromStatus': 'resolved',
        'toStatus': 'in_progress',
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'status': 'in_progress',
        'resolution': '',
        'resolvedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastEventId': event.id,
      });
    });
  }

  @override
  Future<SupportAttachment> attachment(SupportCase record) async {
    final doc = await db.collection('supportAttachments').doc(record.id).get();
    if (!doc.exists) throw StateError('This attachment could not be found.');
    return SupportAttachment.fromMap(doc.data()!);
  }

  @override
  Stream<List<TicketOrder>> orders() => uid == null
      ? Stream.value([])
      : db
            .collection('orders')
            .where('ownerUid', isEqualTo: uid)
            .snapshots()
            .map(
              (s) => s.docs
                  .map((d) => TicketOrder.fromMap(d.id, d.data()))
                  .toList(),
            );
  @override
  Future<TicketOrder?> relatedOrder(SupportCase record) async {
    if (record.orderId.isEmpty) return null;
    final doc = await db.collection('orders').doc(record.orderId).get();
    return doc.exists ? TicketOrder.fromMap(doc.id, doc.data()!) : null;
  }
}

class PendingSupportSubmission {
  final String id;
  final SupportDraft draft;
  const PendingSupportSubmission(this.id, this.draft);
}

class PendingSupportStore {
  Future<PendingSupportSubmission?> load(String uid) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      'support_pending_$uid',
    );
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return PendingSupportSubmission(
      data['id'] as String,
      SupportDraft.fromMap(Map<String, dynamic>.from(data['draft'] as Map)),
    );
  }

  Future<void> save(String uid, PendingSupportSubmission pending) async {
    await (await SharedPreferences.getInstance()).setString(
      'support_pending_$uid',
      jsonEncode({'id': pending.id, 'draft': pending.draft.toMap()}),
    );
  }

  Future<void> clear(String uid) async {
    await (await SharedPreferences.getInstance()).remove(
      'support_pending_$uid',
    );
  }
}
