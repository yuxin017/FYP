import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../accounts/account_widgets.dart';
import '../accounts/account_repository.dart' show accountError;
import '../visitor/widgets/rewards_widgets.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});
  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool busy = false;
  String? message;
  int cooldown = 0;
  Timer? timer;
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> check() async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user?.emailVerified == true) {
        await user!.getIdToken(true);
      } else if (mounted) {
        setState(
          () => message =
              'Email not verified yet. Open the link in your inbox, then return here.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    if (busy || cooldown > 0) return;
    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        setState(() {
          message =
              'Verification email sent. Check your inbox and spam folder.';
          cooldown = 60;
        });
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) {
            t.cancel();
            return;
          }
          setState(() => cooldown--);
          if (cooldown <= 0) t.cancel();
        });
      }
    } catch (e) {
      if (mounted) setState(() => message = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Email Verification',
    bottomNav: false,
    busy: busy,
    child: ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
      children: [
        Image.asset('assets/images/Theme_Park_Main_Logo.png', height: 150),
        const SizedBox(height: 36),
        const Icon(
          Icons.mark_email_unread_outlined,
          color: rewardRose,
          size: 70,
        ),
        const SizedBox(height: 25),
        const Text(
          'Verify Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: rewardInk,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Open the verification link sent to\n${FirebaseAuth.instance.currentUser?.email ?? ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: rewardMuted, height: 1.6),
        ),
        const SizedBox(height: 25),
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              accountHeading('Before you continue'),
              accountDescription(
                '1. Open your email inbox.\n2. Tap the verification link.\n3. Return here and confirm your email.',
              ),
            ],
          ),
        ),
        accountFailure(message),
        const SizedBox(height: 25),
        RewardButton(
          busy ? 'Checking…' : 'I Have Verified My Email',
          onPressed: busy ? null : check,
        ),
        const SizedBox(height: 12),
        RewardButton(
          cooldown > 0 ? 'Resend in ${cooldown}s' : 'Resend Verification Email',
          outlined: true,
          onPressed: busy || cooldown > 0 ? null : resend,
        ),
        TextButton(
          onPressed: busy ? null : FirebaseAuth.instance.signOut,
          child: const Text('Back to Log In'),
        ),
      ],
    ),
  );
}
