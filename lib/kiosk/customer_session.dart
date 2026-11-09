import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../auth/login_error_message.dart';
import '../photos/photo_repository.dart';
import '../photos/photo_gallery_pages.dart';
import '../photos/photo_widgets.dart';
import '../photos/photo_session_scope.dart';

class KioskCustomerSession extends StatefulWidget {
  const KioskCustomerSession({super.key});
  @override
  State<KioskCustomerSession> createState() => _KioskCustomerSessionState();
}

class _KioskCustomerSessionState extends State<KioskCustomerSession> {
  final email = TextEditingController(), password = TextEditingController();
  late final authReady = initialize();
  FirebaseAuth? auth;
  FirebasePhotoRepository? repository;
  Timer? idle;
  bool busy = false, ending = false;
  String? error;
  Future<FirebaseAuth> initialize() async {
    FirebaseApp app;
    try {
      app = Firebase.app('PhotoKioskCustomer');
    } catch (_) {
      app = await Firebase.initializeApp(
        name: 'PhotoKioskCustomer',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final service = FirebaseAuth.instanceFor(app: app);
    if (kIsWeb) await service.setPersistence(Persistence.NONE);
    await service.signOut();
    auth = service;
    return service;
  }

  void touch() {
    idle?.cancel();
    if (repository != null && !ending) {
      idle = Timer(
        const Duration(minutes: 5),
        () => finish(null, timeout: true),
      );
    }
  }

  Future<void> login() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = await authReady;
      final signed = await service.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
      password.clear();
      if (signed.user?.emailVerified != true) {
        await service.signOut();
        throw StateError(
          'Verify your email using your own device before signing in at the kiosk.',
        );
      }
      final repo = FirebasePhotoRepository(
        authentication: service,
        firestore: FirebaseFirestore.instanceFor(app: service.app),
        persistCart: false,
      );
      await repo.cart.ready;
      if (mounted) setState(() => repository = repo);
      touch();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : loginErrorMessage(
                  e is FirebaseAuthException ? e.code : 'unknown',
                ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> finish(String? pass, {bool timeout = false}) async {
    if (ending) return;
    if (pass == null && !timeout) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End your session?'),
          content: const Text(
            'Your confirmed purchases stay in your account. The kiosk will sign you out and clear your cart.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue Shopping'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End Session'),
            ),
          ],
        ),
      );
      if (approved != true) return;
    }
    ending = true;
    idle?.cancel();
    final uid = repository?.uid;
    await auth?.signOut();
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('photo_purchase_pending_$uid');
    }
    repository?.cart.dispose();
    repository = null;
    password.clear();
    if (mounted) Navigator.of(context).pop(pass);
  }

  @override
  void dispose() {
    idle?.cancel();
    password.dispose();
    email.dispose();
    auth?.signOut();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: repository == null,
    child: Listener(
      onPointerDown: (_) => touch(),
      child: repository != null
          ? PhotoSessionScope(
              finish: finish,
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => PhotoHubPage(repository: repository!),
                ),
              ),
            )
          : Scaffold(
              backgroundColor: photoBackground,
              appBar: AppBar(
                title: const Text('Photo Kiosk • Visitor Sign In'),
              ),
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: PhotoPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.photo_library_outlined,
                            size: 65,
                            color: photoRose,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Choose your park memories',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Sign in to view your photos, apply edits and use your loyalty points. Your account will be signed out when you finish.',
                            textAlign: TextAlign.center,
                            style: TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 25),
                          TextField(
                            controller: email,
                            enabled: !busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [],
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 17),
                          TextField(
                            controller: password,
                            enabled: !busy,
                            obscureText: true,
                            autofillHints: const [],
                            onSubmitted: (_) => login(),
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FutureBuilder<FirebaseAuth>(
                            future: authReady,
                            builder: (context, s) => PhotoButton(
                              'Sign In',
                              busy: busy,
                              onPressed: s.hasData && !busy ? login : null,
                            ),
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 16),
                          const Text(
                            'Already purchased? Return to Scan Pass to collect your prints.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}
