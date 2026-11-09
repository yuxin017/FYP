import 'dart:convert';
import 'package:flutter/material.dart';
import '../../accounts/account_repository.dart';
import '../../accounts/account_widgets.dart';
import '../../accounts/recovery_pages.dart';
import '../widgets/rewards_widgets.dart';
import 'personal_information_page.dart';
import 'preferences_page.dart';
import 'face_recognition_settings_page.dart';
import 'security_account_page.dart';

class ProfileSettingsPage extends StatefulWidget {
  final AccountRepository? repository;
  const ProfileSettingsPage({super.key, this.repository});
  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late final repo = widget.repository ?? FirebaseAccountRepository(),
      stream = repo.profile();
  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Profile Settings',
    child: StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: accountDescription(
              'Unable to load your profile settings. Reopen this page to retry.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: rewardRose),
          );
        }
        final data = snapshot.data!, progress = profileCompletion(data);
        ImageProvider? photo;
        try {
          final value = data['profilePhotoBase64'] as String? ?? '';
          if (value.isNotEmpty) photo = MemoryImage(base64Decode(value));
        } catch (_) {}
        return ListView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: const Color(0xFFF1DEDB),
                    backgroundImage: photo,
                    child: photo == null
                        ? const Icon(Icons.person, size: 64, color: rewardRose)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: rewardRose,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            open(PersonalInformationPage(repository: repo)),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            Text(
              data['fullName'] as String? ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: rewardInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Profile ${(progress * 100).round()}% complete',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: rewardMuted),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  color: rewardRose,
                  backgroundColor: const Color(0xFFEEDDD8),
                ),
              ),
            ),
            const SizedBox(height: 30),
            for (final item in [
              (
                Icons.person_outline,
                'Personal Information',
                'Name, email and phone number',
                () => open(PersonalInformationPage(repository: repo)),
              ),
              (
                Icons.tune,
                'Preferences & Interests',
                'Height, food choices and park interests',
                () => open(PreferencesPage(repository: repo)),
              ),
              (
                Icons.face_retouching_natural,
                'Face Recognition',
                'Optional photo-matching preference',
                () => open(const FaceRecognitionSettingsPage()),
              ),
              (
                Icons.shield_outlined,
                'Security & Account',
                'Password, login devices and account controls',
                () => open(SecurityAccountPage(repository: repo)),
              ),
            ]) ...[
              RewardCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 0,
                ),
                child: AccountRow(
                  icon: item.$1,
                  title: item.$2,
                  subtitle: item.$3,
                  badge: item.$2 == 'Face Recognition'
                      ? (data['faceRecognitionEnabled'] == true
                            ? 'Active'
                            : 'Not Set Up')
                      : null,
                  onTap: item.$4,
                ),
              ),
              const SizedBox(height: 13),
            ],
            Row(
              children: [
                const Icon(Icons.lock_outline, color: rewardRose, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: accountDescription(
                    'Your information and privacy choices.',
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => open(const DataPrivacyPage()),
                child: const Text('View Privacy Policy'),
              ),
            ),
          ],
        );
      },
    ),
  );
}
