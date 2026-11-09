import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'account_repository.dart';
import 'recovery_pages.dart';
import 'security_pages.dart';

class AccountReadyGate extends StatefulWidget {
  final User user;
  final Widget child;
  const AccountReadyGate({super.key, required this.user, required this.child});
  @override
  State<AccountReadyGate> createState() => _AccountReadyGateState();
}

class _AccountReadyGateState extends State<AccountReadyGate> {
  late final repository = FirebaseAccountRepository(),
      security = FirebaseFirestore.instance
          .collection('accountSecurity')
          .doc(widget.user.uid)
          .snapshots(),
      profile = repository.profile();
  Timer? timer;
  int? authTime;
  bool leaving = false;
  bool refreshing = false;
  @override
  void initState() {
    super.initState();
    unawaited(start());
    timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(heartbeat()),
    );
  }

  Future<void> start() async {
    try {
      final result = await widget.user.getIdTokenResult();
      if (mounted) {
        setState(
          () => authTime = (result.claims?['auth_time'] as num?)?.toInt(),
        );
      }
    } catch (_) {}
    await heartbeat();
  }

  Future<void> heartbeat() async {
    if (refreshing) return;
    refreshing = true;
    try {
      await widget.user.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      await repository.recordSession();
      await repository.refreshEmail();
    } on FirebaseAuthException catch (e) {
      if ([
        'user-not-found',
        'user-disabled',
        'user-token-expired',
        'invalid-user-token',
      ].contains(e.code)) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {
      /* Network/service interruptions must not erase the existing account session. */
    } finally {
      refreshing = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: security,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to check account security. Please reconnect.',
                ),
                TextButton(
                  onPressed: FirebaseAuth.instance.signOut,
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final data = snapshot.data!.data() ?? {};
      if (data['closing'] == true) {
        return DeleteAccountPage(repository: repository, recovering: true);
      }
      final cutoff = (data['revokedBefore'] as num?)?.toInt();
      if (authTime != null && cutoff != null && authTime! <= cutoff) {
        if (!leaving) {
          leaving = true;
          unawaited(Future.microtask(() => FirebaseAuth.instance.signOut()));
        }
        return const Scaffold(
          body: Center(child: Text('Please sign in again.')),
        );
      }
      return StreamBuilder<Map<String, dynamic>?>(
        stream: profile,
        builder: (context, s) {
          if (s.hasError) {
            return const Scaffold(
              body: Center(
                child: Text('Unable to load your profile. Please reconnect.'),
              ),
            );
          }
          if (s.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return s.data == null
              ? CompleteProfilePage(repository: repository)
              : widget.child;
        },
      );
    },
  );
}
