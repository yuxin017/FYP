
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'verify_email_page.dart';
import '../visitor_home_page.dart';
import 'login_page.dart';
import '../visitor/visitor_main_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Unable to check login status.'),
            ),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;

          if (!user.emailVerified) {
            return const VerifyEmailPage();
          }

          return const VisitorMainPage();
        }

        return const LoginPage();
      },
    );
  }
}
