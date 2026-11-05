
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VisitorHomePage extends StatelessWidget {
  const VisitorHomePage({super.key});

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF4EF),
      appBar: AppBar(
        title: const Text('Theme Park'),
        backgroundColor: const Color(0xFFFDF4EF),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.celebration,
                size: 80,
                color: Color(0xFF704B8E),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${user?.displayName ?? 'Visitor'}!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?.email ?? '',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              const Text(
                'Your theme park adventure starts here!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
