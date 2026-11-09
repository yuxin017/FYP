import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../visitor/models/tickets.dart';

class AccountAccessGate extends StatefulWidget {
  final User user;
  final Widget child;
  const AccountAccessGate({super.key, required this.user, required this.child});
  @override
  State<AccountAccessGate> createState() => _AccountAccessGateState();
}

class _AccountAccessGateState extends State<AccountAccessGate> {
  late final stream = FirebaseFirestore.instance
      .collection('visitorAccess')
      .doc(widget.user.uid)
      .snapshots();
  bool recorded = false;
  Future<void> _recordSession() async {
    try {
      final db = FirebaseFirestore.instance;
      final day = visitDateString(parkToday());
      final ref = db
          .collection('visitorSessions')
          .doc('${widget.user.uid}_$day');
      await db.runTransaction((tx) async {
        final old = await tx.get(ref);
        if (old.exists) {
          tx.update(ref, {'lastSeenAt': FieldValue.serverTimestamp()});
        } else {
          tx.set(ref, {
            'ownerUid': widget.user.uid,
            'day': day,
            'action': 'session_opened',
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeenAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (_) {
      /* Session statistics must not prevent an otherwise authorised sign-in. */
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to check account access. Please reconnect and try again.',
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: FirebaseAuth.instance.signOut,
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFAD7472)),
          ),
        );
      }
      final data = snapshot.data!.data() ?? {};
      final status = data['status'] as String? ?? 'active';
      if (status == 'active') {
        if (!recorded) {
          recorded = true;
          unawaited(_recordSession());
        }
        return widget.child;
      }
      return Scaffold(
        backgroundColor: const Color(0xFFFDF4EF),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Color(0xFFAD7472),
                        size: 55,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        status == 'suspended'
                            ? 'Account Suspended'
                            : 'Account Unavailable',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        (data['reason'] as String?)?.isNotEmpty == true
                            ? data['reason'] as String
                            : 'Please contact the park support team about your account access.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: FirebaseAuth.instance.signOut,
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
