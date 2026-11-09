import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../attractions/data/attraction_repository.dart';
import '../attractions/attractions_admin_page.dart';
import '../attractions/data/admin_attraction_repository.dart';
import '../auth/admin_sign_in_page.dart';
import '../auth/attraction_admin_access.dart';
import '../reservations/data/admin_reservation_repository.dart';
import '../reservations/reservations_admin_page.dart';
import 'admin_portal_shell.dart';
import 'admin_theme.dart';

class AdminPortalApp extends StatelessWidget {
  const AdminPortalApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Theme Park - Admin Portal',
    debugShowCheckedModeBanner: false,
    theme: AdminTheme.data,
    home: const _AdminAuthGate(),
  );
}

class _AdminAuthGate extends StatefulWidget {
  const _AdminAuthGate();
  @override
  State<_AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<_AdminAuthGate> {
  late final FirebaseAuth _auth;
  late final AttractionAdminAccess _access;
  late final AdminAttractionRepository _store;
  late final AttractionRepository _slotReader;
  late final AdminReservationRepository _reservations;
  var _section = AdminPortalSection.attractions;
  var _sectionNavigator = GlobalKey<NavigatorState>();
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _access = AttractionAdminAccess(_auth);
    _store = AdminAttractionRepository(firestore: FirebaseFirestore.instance);
    _slotReader = AttractionRepository(firestore: FirebaseFirestore.instance);
    _reservations = AdminReservationRepository(FirebaseFirestore.instance);
  }

  @override
  void dispose() {
    _access.dispose();
    super.dispose();
  }

  Future<void> _signIn(String email, String password, bool remember) async {
    if (kIsWeb) {
      await _auth.setPersistence(
        remember ? Persistence.LOCAL : Persistence.SESSION,
      );
    }
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _access.refresh();
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        setState(() {
          _sessionError = null;
          _section = AdminPortalSection.attractions;
          _sectionNavigator = GlobalKey<NavigatorState>();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sessionError = 'Unable to sign out. Please try again.');
      }
    }
  }

  void _selectSection(AdminPortalSection section) {
    if (section == _section || !_access.value) return;
    if (_sectionNavigator.currentState?.canPop() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Close the current screen before switching sections.'),
        ),
      );
      return;
    }
    setState(() {
      _section = section;
      _sectionNavigator = GlobalKey<NavigatorState>();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _access,
    builder: (context, _) {
      if (_access.checking) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = _auth.currentUser;
      if (user == null && _access.errorMessage == null) {
        return AdminSignInPage(
          onSignIn: _signIn,
          onResetPassword: (email) =>
              _auth.sendPasswordResetEmail(email: email),
        );
      }
      if (!_access.value || user == null) {
        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 40,
                          color: AdminTheme.rose,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Administrator access required',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _sessionError ??
                              _access.errorMessage ??
                              'This account is not authorized to manage the park. Contact the project administrator.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _access.refresh,
                          child: const Text('Refresh account access'),
                        ),
                        TextButton(
                          onPressed: _signOut,
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return AdminPortalShell(
        section: _section,
        onSelectSection: _selectSection,
        accountName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!
            : user.email ?? 'Administrator',
        onSignOut: _signOut,
        onRefreshAccess: _access.refresh,
        child: Column(
          children: [
            if (_sessionError != null)
              MaterialBanner(
                content: Text(_sessionError!),
                actions: [
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            Expanded(
              child: Navigator(
                key: _sectionNavigator,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => switch (_section) {
                    AdminPortalSection.attractions => AttractionsAdminPage(
                      store: _store,
                      adminAccess: _access,
                      slotReader: _slotReader,
                    ),
                    AdminPortalSection.reservations => ReservationsAdminPage(
                      watchDay: _reservations.watchDay,
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
