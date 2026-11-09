import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../visitor/models/tickets.dart';

const foodChoices = <String, String>{
  'No preference': 'All',
  'Asian': 'Asian',
  'Halal': 'Halal',
  'Middle Eastern': 'Middle Eastern',
  'Vegetarian': 'Vegetarian',
  'Western': 'Western',
  'Vegan': 'Vegan',
  'No pork': 'No pork',
  'No seafood': 'No seafood',
};
const interestChoices = <String, String>{
  'Family rides': 'Family Rides',
  'Thrill rides': 'Thrill Rides',
  'Adventure rides': 'Adventure Rides',
  'Shows': 'Live Entertainment',
  'Food & dining': 'Dining & Snacks',
  'Shopping & souvenirs': 'Shopping & Souvenirs',
  'Photo spots': 'Instagrammable Moments',
  'Water rides': 'Water Rides',
};
String? nameError(String? input) {
  final value = input?.trim() ?? '';
  return value.length < 2 ||
          value.length > 100 ||
          RegExp(r'[\r\n\t]').hasMatch(value)
      ? 'Enter a name between 2 and 100 characters.'
      : null;
}

String? emailError(String? value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Enter a valid email address.';
String? phoneError(String? value) =>
    RegExp(r'^\+?[0-9]{9,15}$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Use a phone number such as +60123456789.';
String? passwordError(String? value) =>
    value == null ||
        value.length < 8 ||
        value.length > 128 ||
        !RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[^a-zA-Z0-9]').hasMatch(value)
    ? 'Use 8–128 characters, with uppercase, lowercase and a special character.'
    : null;
String accountError(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'wrong-password' ||
      'invalid-credential' => 'The password is incorrect. Please try again.',
      'requires-recent-login' => 'Confirm your password again to continue.',
      'email-already-in-use' => 'That email is already registered.',
      'expired-action-code' || 'invalid-action-code' =>
        'This link has expired or has already been used. Request a new one.',
      'too-many-requests' => 'Please wait a moment before trying again.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'user-disabled' ||
      'user-token-expired' => 'Please sign in again to continue.',
      _ => 'Unable to complete this account action. Please try again.',
    };
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'This change could not be saved. Reload your profile and try again.';
  }
  return 'Unable to connect. Check your connection and try again.';
}

Object? comparable(dynamic value) =>
    value is Timestamp ? value.toDate().toUtc().toIso8601String() : value;
bool accountSame(dynamic a, dynamic b) =>
    jsonEncode(comparable(a)) == jsonEncode(comparable(b));
Uint8List prepareAvatar(Uint8List bytes) {
  if (bytes.length > 10000000) {
    throw StateError('Choose a photo smaller than 10 MB.');
  }
  final image = img.decodeImage(bytes);
  if (image == null) throw StateError('Choose a JPG or PNG photo.');
  final square = img.copyResizeCropSquare(
    img.bakeOrientation(image),
    size: 200,
  );
  return Uint8List.fromList(img.encodeJpg(square, quality: 80));
}

DateTime? profileDate(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is String
    ? DateTime.tryParse(value)
    : null;
double profileCompletion(Map<String, dynamic> data) =>
    [
      (data['fullName'] as String? ?? '').trim().isNotEmpty,
      (data['email'] as String? ?? '').trim().isNotEmpty,
      (data['phoneNumber'] as String? ?? '').trim().isNotEmpty,
      data['dateOfBirth'] != null,
      (data['gender'] as String? ?? '').isNotEmpty,
    ].where((x) => x).length /
    5;

class AccountIdentity {
  final String uid, email;
  final bool verified;
  const AccountIdentity(this.uid, this.email, {this.verified = true});
}

abstract class AccountRepository {
  AccountIdentity? get identity;
  Stream<Map<String, dynamic>?> profile();
  Future<void> save(Map<String, dynamic> base, Map<String, dynamic> updates);
  Future<void> createProfile(String name, String phone);
  Future<void> resetEmail(String email);
  Future<String> verifyReset(String code);
  Future<void> confirmReset(String code, String password);
  Future<void> reauthenticate(String password);
  Future<void> changeEmail(String email, String password);
  Future<String> refreshEmail();
  Future<void> changePassword(String current, String next);
  Future<List<Map<String, dynamic>>> sessions();
  Future<void> revokeSessions(String password);
  Future<void> close(String password);
  Future<void> signOut();
  Future<String?> currentSessionId() async => null;
}

class FirebaseAccountRepository extends AccountRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  FirebaseAccountRepository({FirebaseAuth? auth, FirebaseFirestore? db})
    : auth = auth ?? FirebaseAuth.instance,
      db = db ?? FirebaseFirestore.instance;
  @override
  AccountIdentity? get identity {
    final user = auth.currentUser;
    return user == null
        ? null
        : AccountIdentity(
            user.uid,
            user.email ?? '',
            verified: user.emailVerified,
          );
  }

  @override
  Stream<Map<String, dynamic>?> profile() => identity == null
      ? Stream.value(null)
      : db
            .collection('visitors')
            .doc(identity!.uid)
            .snapshots()
            .map((d) => d.data());
  @override
  Future<void> save(
    Map<String, dynamic> base,
    Map<String, dynamic> updates,
  ) async {
    if (identity == null) throw StateError('Please sign in again.');
    final ref = db.collection('visitors').doc(identity!.uid);
    await db.runTransaction((tx) async {
      final latest = await tx.get(ref);
      final data = latest.data();
      if (data == null) {
        throw StateError(
          'Your profile could not be found. Please sign in again.',
        );
      }
      for (final key in updates.keys) {
        if (!accountSame(data[key], base[key])) {
          throw StateError(
            'Your profile changed on another device. Reopen this page to review the latest details before saving.',
          );
        }
      }
      tx.update(ref, updates);
    });
    if (updates['fullName'] is String) {
      try {
        await auth.currentUser?.updateDisplayName(updates['fullName']);
      } catch (_) {
        /* Firestore is the canonical profile. */
      }
    }
  }

  @override
  Future<void> createProfile(String name, String phone) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    final ref = db.collection('visitors').doc(user.uid);
    await db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) return;
      tx.set(ref, {
        'uid': user.uid,
        'fullName': name.trim(),
        'email': user.email,
        'phoneNumber': phone.trim(),
        'role': 'visitor',
        'loyaltyPoints': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    await user.updateDisplayName(name.trim());
  }

  @override
  Future<void> resetEmail(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found') rethrow;
    }
  }

  @override
  Future<String> verifyReset(String code) => auth.verifyPasswordResetCode(code);
  @override
  Future<void> confirmReset(String code, String password) =>
      auth.confirmPasswordReset(code: code, newPassword: password);
  @override
  Future<void> reauthenticate(String password) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('Please sign in again.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    await user.getIdToken(true);
  }

  @override
  Future<void> changeEmail(String email, String password) async {
    await reauthenticate(password);
    await auth.currentUser!.verifyBeforeUpdateEmail(email.trim());
  }

  @override
  Future<String> refreshEmail() async {
    await auth.currentUser?.reload();
    await auth.currentUser?.getIdToken(true);
    await call('/v1/profile/sync');
    return auth.currentUser?.email ?? '';
  }

  @override
  Future<void> changePassword(String current, String next) async {
    await reauthenticate(current);
    await auth.currentUser!.updatePassword(next);
  }

  Future<Map<String, dynamic>> call(
    String route, [
    Map<String, dynamic> body = const {},
  ]) async {
    final token = await auth.currentUser?.getIdToken();
    if (token == null) throw StateError('Please sign in again.');
    const origin = String.fromEnvironment(
      'ACCOUNT_SERVICE_URL',
      defaultValue: 'http://127.0.0.1:8787',
    );
    final response = await http
        .post(
          Uri.parse('$origin$route'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(Duration(seconds: route == '/v1/account/close' ? 90 : 10));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
        data['message'] as String? ??
            'Account services are unavailable. Please try again.',
      );
    }
    return data;
  }

  @override
  Future<List<Map<String, dynamic>>> sessions() async =>
      ((await call('/v1/sessions/list'))['sessions'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  @override
  Future<void> revokeSessions(String password) async {
    await reauthenticate(password);
    await call('/v1/sessions/revoke-all');
    await signOut();
  }

  @override
  Future<void> close(String password) async {
    await reauthenticate(password);
    await call('/v1/account/close', {'confirmation': 'DELETE'});
    final uid = identity?.uid;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      for (final key
          in prefs.getKeys().where((k) => k.contains(uid)).toList()) {
        await prefs.remove(key);
      }
    }
    await signOut();
  }

  @override
  Future<String?> currentSessionId() async =>
      (await SharedPreferences.getInstance()).getString(
        'account_session_${identity?.uid}',
      );
  @override
  Future<void> signOut() async {
    final id = await currentSessionId(), uid = identity?.uid;
    if (id != null) {
      try {
        await call('/v1/sessions/end', {
          'id': id,
        }).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('account_session_$uid');
    }
    await auth.signOut();
  }

  Future<void> recordSession() async {
    final uid = identity?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final result = await call('/v1/sessions/open', {
      'id': prefs.getString('account_session_$uid'),
      'deviceName': kIsWeb
          ? 'Web browser · ${defaultTargetPlatform.name}'
          : defaultTargetPlatform.name,
    });
    await prefs.setString('account_session_$uid', result['id'] as String);
  }
}

String sessionDate(dynamic value) {
  final date = value is String
      ? DateTime.tryParse(value)
      : value is DateTime
      ? value
      : null;
  if (date == null) return 'Recently';
  final local = date.toUtc().add(const Duration(hours: 8));
  return '${displayParkDate(visitDateString(parkToday(date)))} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
