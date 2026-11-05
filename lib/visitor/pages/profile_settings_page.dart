import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'personal_information_page.dart';
import 'preferences_page.dart';
import 'face_recognition_settings_page.dart';
import 'security_account_page.dart';
import 'dart:convert';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  static const Color rose = Color(0xFFAD7472);
  static const Color background = Color(0xFFFDF4EF);
  static const Color dark = Color(0xFF263238);
  static const Color muted = Color(0xFF7C8188);

  void _notReady(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('visitors').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load profile settings.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: rose));
            }
            final data = snapshot.data!.data();
            if (data == null) {
              return const Center(child: Text('Visitor profile not found.'));
            }

            final name = (data['fullName'] as String?)?.trim().isNotEmpty == true
                ? data['fullName'] as String
                : (user.displayName ?? 'Visitor');
            final hasName = (data['fullName'] as String? ?? '').trim().isNotEmpty;
            final hasEmail = (data['email'] as String? ?? '').trim().isNotEmpty;
            final hasPhone = (data['phoneNumber'] as String? ?? '').trim().isNotEmpty;
            final progress = [hasName, hasEmail, hasPhone].where((x) => x).length / 3;
            final percentage = (progress * 100).round();

            return Stack(
              children: [
                // The original theme-park artwork appears only at the top.
                // It is softened and fades into the solid blush background.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 330,
                          width: double.infinity,
                          child: ClipRect(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Opacity(
                                    opacity: 0.85,
                                    child: Image.asset(
                                      'assets/images/Background.png',
                                      width: double.infinity,
                                      fit: BoxFit.fitWidth,
                                      alignment: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: [0.0, 0.38, 0.75, 1.0],
                                      colors: [
                                        Color(0x55FDF4EF),
                                        Color(0x88FDF4EF),
                                        Color(0xEAFDF4EF),
                                        Color(0xFFFDF4EF),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: rose),
                        ),
                        const Expanded(
                          child: Text(
                            'Profile Settings',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: dark),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _notReady(context, 'Help & Support'),
                          icon: const Icon(Icons.help_outline, size: 23, color: rose),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF0DDDA),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(child: (data['profilePhotoBase64'] is String && (data['profilePhotoBase64'] as String).isNotEmpty) ? Image.memory(base64Decode(data['profilePhotoBase64'] as String), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: rose, size: 62)) : const Icon(Icons.person, color: rose, size: 62)),
                          ),
                          Positioned(
                            right: -3,
                            bottom: 0,
                            child: Material(
                              color: rose,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PersonalInformationPage())),
                                child: const SizedBox(
                                  width: 31,
                                  height: 31,
                                  child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 17),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: dark),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      'Profile $percentage% complete',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: SizedBox(
                        width: 235,
                        height: 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFEBDAD7),
                            valueColor: const AlwaysStoppedAnimation<Color>(rose),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _settingsCard(
                      context,
                      icon: Icons.person_outline,
                      title: 'Personal Information',
                      subtitle: 'Name, email and phone number',
                    ),
                    const SizedBox(height: 11),
                    _settingsCard(
                      context,
                      icon: Icons.tune,
                      title: 'Preferences & Interests',
                      subtitle: 'Height, food choices and park interests',
                    ),
                    const SizedBox(height: 11),
                    _settingsCard(
                      context,
                      icon: Icons.face_retouching_natural_outlined,
                      title: 'Face Recognition',
                      subtitle: 'Optional selfie for automatic photo matching',
                      badge: data['faceRecognitionConsent'] == true ? 'Consent On' : 'Not Set Up',
                    ),
                    const SizedBox(height: 11),
                    _settingsCard(
                      context,
                      icon: Icons.shield_outlined,
                      title: 'Security & Account',
                      subtitle: 'Password, login devices and account controls',
                    ),
                    const SizedBox(height: 23),
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, color: rose, size: 15),
                          SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              'Your data is private and secure.',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _settingsCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        String? badge,
      }) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: const Color(0x18AD7472),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (title == 'Personal Information') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PersonalInformationPage(),
              ),
            );
          } else if (title == 'Preferences & Interests') {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreferencesPage()));
          } else if (title == 'Face Recognition') {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FaceRecognitionSettingsPage()));
          } else if (title == 'Security & Account') {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecurityAccountPage()));
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 77),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3E9E5), width: 0.8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 39,
                child: Icon(icon, color: rose, size: 30),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 10.5, height: 1.35, color: muted),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: rose, width: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge, style: const TextStyle(fontSize: 9, color: rose)),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: rose),
            ],
          ),
        ),
      ),
    );
  }
}

