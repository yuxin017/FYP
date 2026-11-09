import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth/login_page.dart';
import 'auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    // Display splash screen for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    // An initial deep link can place another route above the splash screen.
    // Only the visible splash route should perform the startup redirect.
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    // Wait for Firebase to restore the login session
    User? user;

    try {
      user = await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {
      // If session checking fails, show login page
      user = null;
    }

    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user == null ? const LoginPage() : const AuthGate(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen background
          Image.asset('assets/images/Background.png', fit: BoxFit.cover),

          // Main logo
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35),
              child: Image.asset(
                'assets/images/Theme_Park_Main_Logo.png',
                width: 310,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Version number
          const Positioned(
            left: 0,
            right: 0,
            bottom: 55,
            child: Text(
              'Version 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8E7772),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
