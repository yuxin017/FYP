import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'verify_email_page.dart';
import 'account_access_gate.dart';
import 'login_page.dart';
import '../accounts/account_ready_gate.dart';
import '../visitor/visitor_main_page.dart';
import '../device/biometric_security.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to check login status.')),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;

          if (!user.emailVerified) {
            return const VerifyEmailPage();
          }

          return AccountReadyGate(
            key: ValueKey(user.uid),
            user: user,
            child: AccountAccessGate(
              user: user,
              child: BiometricUnlockGate(
                key: ValueKey('device-${user.uid}'),
                uid: user.uid,
                child: const VisitorMainPage(),
              ),
            ),
          );
        }

        return const LoginPage();
      },
    );
  }
}
