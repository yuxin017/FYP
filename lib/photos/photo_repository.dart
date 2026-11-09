import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/application_api.dart';

class ParkPhoto {
  final String id;
  final Map<String, dynamic> data;
  const ParkPhoto(this.id, this.data);
  String get photoId => data['photoId'] as String? ?? id;
  String get title => data['title'] as String? ?? 'Park photo';
  String get place => data['attractionName'] as String? ?? '';
  String get preview => data['previewBase64'] as String? ?? '';
  DateTime? get takenAt => (data['takenAt'] as Timestamp?)?.toDate();
  int? get confidence =>
      data['score'] is num ? ((data['score'] as num) * 100).round() : null;
}

class PhotoCartItem {
  final String photoId, title, preview, format, printSize, finish;
  final int quantity;
  final Map<String, dynamic> edits;
  const PhotoCartItem({
    required this.photoId,
    required this.title,
    required this.preview,
    this.format = 'digital',
    this.quantity = 1,
    this.printSize = '6x8',
    this.finish = 'glossy',
    this.edits = const {},
  });
  Map<String, dynamic> get payload => {
    'photoId': photoId,
    'format': format,
    'quantity': quantity,
    'printSize': printSize,
    'finish': finish,
    'edits': edits,
  };
  Map<String, dynamic> get stored => {
    ...payload,
    'title': title,
    'preview': preview,
  };
  factory PhotoCartItem.fromMap(Map<String, dynamic> value) => PhotoCartItem(
    photoId: value['photoId'] as String,
    title: value['title'] as String,
    preview: value['preview'] as String? ?? '',
    format: value['format'] as String? ?? 'digital',
    quantity: value['quantity'] as int? ?? 1,
    printSize: value['printSize'] as String? ?? '6x8',
    finish: value['finish'] as String? ?? 'glossy',
    edits: Map<String, dynamic>.from(value['edits'] as Map? ?? {}),
  );
  PhotoCartItem copies(int value) => PhotoCartItem(
    photoId: photoId,
    title: title,
    preview: preview,
    format: format,
    quantity: value,
    printSize: printSize,
    finish: finish,
    edits: edits,
  );
}

class PhotoCart extends ChangeNotifier {
  final String uid;
  final bool persist;
  final items = <PhotoCartItem>[];
  String deliveryEmail = '';
  PhotoCart(this.uid, {this.persist = true});
  late final Future<void> ready = restore();
  Future<void> restore() async {
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString('photo_cart_$uid');
      if (raw != null) {
        final decoded = jsonDecode(raw);
        final rows = decoded is List ? decoded : decoded['items'] as List;
        if (decoded is Map) {
          deliveryEmail = decoded['deliveryEmail'] as String? ?? '';
        }
        items.addAll(
          rows
              .take(10)
              .map((r) => PhotoCartItem.fromMap(Map<String, dynamic>.from(r))),
        );
      }
    } catch (_) {
      items.clear();
    }
    notifyListeners();
  }

  Future<void> save() async {
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'photo_cart_$uid',
        jsonEncode({
          'items': items.map((i) => i.stored).toList(),
          'deliveryEmail': deliveryEmail,
        }),
      );
    }
    notifyListeners();
  }

  Future<void> add(PhotoCartItem item) async {
    await ready;
    final existing = items.indexWhere((i) => i.photoId == item.photoId);
    if (existing >= 0) {
      items[existing] = item;
    } else {
      if (items.length >= 10) {
        throw StateError('Your photo cart can hold up to ten photos.');
      }
      items.add(item);
    }
    await save();
  }

  Future<void> remove(String id) async {
    items.removeWhere((i) => i.photoId == id);
    await save();
  }

  Future<void> clear() async {
    items.clear();
    await save();
  }
}

abstract class PhotoRepository {
  String get uid;
  String get email;
  PhotoCart get cart;
  Stream<Map<String, dynamic>> faceProfile();
  Stream<List<ParkPhoto>> matches();
  Stream<List<ParkPhoto>> entitlements();
  Stream<List<ParkPhoto>> orders();
  Stream<ParkPhoto?> order(String id);
  Stream<List<ParkPhoto>> orderPreviews(String id);
  Stream<Map<String, dynamic>> settings();
  Stream<int> balance();
  Stream<Map<String, dynamic>?> kioskRequest(String orderId);
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  );
  Future<void> reauthenticate(String password);
  String newRequestId();
}

class FirebasePhotoRepository implements PhotoRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  FirebasePhotoRepository({
    FirebaseAuth? authentication,
    FirebaseFirestore? firestore,
    this.persistCart = true,
  }) : auth = authentication ?? FirebaseAuth.instance,
       db = firestore ?? FirebaseFirestore.instance;
  @override
  String get uid => auth.currentUser!.uid;
  @override
  String get email => auth.currentUser?.email ?? '';
  final bool persistCart;
  @override
  late final cart = PhotoCart(uid, persist: persistCart);
  Stream<List<ParkPhoto>> records(String collection) => db
      .collection(collection)
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => ParkPhoto(d.id, d.data())).toList());
  @override
  Stream<Map<String, dynamic>> faceProfile() => db
      .collection('faceProfiles')
      .doc(uid)
      .snapshots()
      .map((s) => s.data() ?? {});
  @override
  Stream<List<ParkPhoto>> matches() => records('photoMatches').map(
    (list) =>
        list
            .where(
              (p) => p.data['hidden'] != true && p.data['available'] != false,
            )
            .toList()
          ..sort(
            (a, b) => (b.takenAt ?? DateTime(1970)).compareTo(
              a.takenAt ?? DateTime(1970),
            ),
          ),
  );
  @override
  Stream<List<ParkPhoto>> entitlements() => records('photoEntitlements');
  @override
  Stream<List<ParkPhoto>> orders() => records('photoOrders').map(
    (list) => list
      ..sort(
        (a, b) =>
            ((b.data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970))
                .compareTo(
                  (a.data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime(1970),
                ),
      ),
  );
  @override
  Stream<ParkPhoto?> order(String id) => db
      .collection('photoOrders')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? ParkPhoto(s.id, s.data()!) : null);
  @override
  Stream<List<ParkPhoto>> orderPreviews(String id) => db
      .collection('photoOrderPreviews')
      .where('ownerUid', isEqualTo: uid)
      .where('orderId', isEqualTo: id)
      .snapshots()
      .map((s) => s.docs.map((d) => ParkPhoto(d.id, d.data())).toList());
  @override
  Stream<Map<String, dynamic>> settings() => db
      .collection('parkSettings')
      .doc('photos')
      .snapshots()
      .map((s) => s.data() ?? {});
  @override
  Stream<int> balance() => db
      .collection('visitors')
      .doc(uid)
      .snapshots()
      .map((s) => (s.data()?['loyaltyPoints'] as num?)?.toInt() ?? 0);
  @override
  Stream<Map<String, dynamic>?> kioskRequest(String id) =>
      db.collection('kioskRequests').doc(id).snapshots().map((s) => s.data());
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) => ApplicationApi(auth: auth).post('/v1/photos/$action', data);
  @override
  Future<void> reauthenticate(String password) async {
    final user = auth.currentUser;
    if (user?.email == null) throw StateError('Please sign in again.');
    await user!.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    await user.getIdToken(true);
  }

  @override
  String newRequestId() => List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String photoMoney(num amount) => 'RM ${(amount / 100).toStringAsFixed(2)}';
String photoFormat(String format) => switch (format) {
  'print' => 'Printed Photo',
  'bundle' => 'Digital + Print Bundle',
  _ => 'Digital Photo',
};
String photoOrderReference(String id) =>
    'PH-${id.substring(0, id.length < 12 ? id.length : 12).toUpperCase()}';
String photoError(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' => 'The password is incorrect. Please try again.',
      'too-many-requests' => 'Please wait a moment before trying again.',
      'network-request-failed' => 'Check your connection and try again.',
      _ => 'Please sign in again to confirm your identity.',
    };
  }
  if (error is ApplicationApiException) return error.message;
  return 'Unable to complete this photo action. Please try again.';
}
