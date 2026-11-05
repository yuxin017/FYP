
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'login_page.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _loading = false;
  bool _sending = false;

  Future<void> _checkVerification() async {
    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.currentUser?.reload();

      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      } else {
        _showMessage('Email not verified yet. Please check your inbox.');
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Unable to check verification status.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _sending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage('Session expired. Please log in again.');
        return;
      }

      await user.sendEmailVerification();
      _showMessage('Verification email sent. Please check your inbox.');
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Unable to send verification email.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _backToLogin() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Email Verification')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: Color(0xFFB77B83),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We have sent a verification link to:\n$email',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Open your email, click the verification link, '
                    'then return here to continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _checkVerification,
                child: Text(
                  _loading ? 'Checking...' : "I've Verified My Email",
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _sending ? null : _resendEmail,
                child: Text(
                  _sending ? 'Sending...' : 'Resend Verification Email',
                ),
              ),
              TextButton(
                onPressed: _backToLogin,
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
