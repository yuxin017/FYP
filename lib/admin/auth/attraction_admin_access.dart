import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

bool hasAttractionAdminClaim(Map<String, dynamic>? claims) =>
    claims?['admin'] == true;

/// Portal-only access controller. The customer app never imports this module.
/// Only a verified Auth token can unlock the attraction editors.
/// A visitor profile's role field is deliberately not consulted.
class AttractionAdminAccess extends ValueNotifier<bool> {
  AttractionAdminAccess(this._auth) : super(false) {
    _subscription = _auth.idTokenChanges().listen(
      (user) => unawaited(_verify(user)),
      onError: (Object _) =>
          _deny('Unable to verify account access. Refresh to try again.'),
    );
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;
  int _generation = 0;
  bool _disposed = false;
  bool checking = true;
  String? errorMessage;

  Future<void> refresh() => _verify(_auth.currentUser, forceRefresh: true);

  Future<void> _verify(User? user, {bool forceRefresh = false}) async {
    final generation = ++_generation;
    if (_disposed) return;
    checking = user != null;
    errorMessage = null;
    value = false;
    notifyListeners();
    if (user == null) return;
    try {
      final result = await user.getIdTokenResult(forceRefresh);
      if (_disposed || generation != _generation) return;
      checking = false;
      value = hasAttractionAdminClaim(result.claims);
      notifyListeners();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _deny('Unable to verify account access. Refresh to try again.');
      }
    }
  }

  void _deny(String message) {
    if (_disposed) return;
    ++_generation;
    checking = false;
    errorMessage = message;
    value = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
