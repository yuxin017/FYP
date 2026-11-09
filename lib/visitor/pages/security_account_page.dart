import 'package:flutter/material.dart';
import '../../accounts/account_repository.dart';
import '../../accounts/account_widgets.dart';
import '../../accounts/security_pages.dart';
import '../widgets/rewards_widgets.dart';
import 'face_recognition_settings_page.dart';
import '../../device/biometric_security.dart';
import '../../auth/phone_auth_page.dart';

class SecurityAccountPage extends StatefulWidget {
  final AccountRepository? repository;
  const SecurityAccountPage({super.key, this.repository});
  @override
  State<SecurityAccountPage> createState() => _SecurityAccountPageState();
}

class _SecurityAccountPageState extends State<SecurityAccountPage> {
  late final repo = widget.repository ?? FirebaseAccountRepository();
  bool busy = false;
  String? error;
  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  Future<void> logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign in again anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await repo.signOut();
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Security & Account',
    busy: busy,
    child: ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 43, 22, 24),
      children: [
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              accountHeading('Security'),
              AccountRow(
                icon: Icons.lock_outline,
                title: 'Reset Password',
                subtitle: 'Change your account password',
                onTap: () => open(ChangePasswordPage(repository: repo)),
              ),
              const Divider(height: 1, color: rewardBorder),
              AccountRow(
                icon: Icons.phone_android_outlined,
                title: 'Linked Phone Number',
                subtitle: 'Verify a number for SMS sign-in',
                onTap: () => open(const PhoneAuthPage(link: true)),
              ),
              const Divider(height: 1, color: rewardBorder),
              AccountRow(
                icon: Icons.fingerprint,
                title: 'Device Authentication',
                subtitle: 'Face ID, fingerprint and device unlock',
                onTap: () => open(const DeviceSecurityPage()),
              ),
              const Divider(height: 1, color: rewardBorder),
              AccountRow(
                icon: Icons.shield_outlined,
                title: 'Login & Security',
                subtitle: 'Manage signed-in devices',
                onTap: () => open(LoginSecurityPage(repository: repo)),
              ),
              const Divider(height: 1, color: rewardBorder),
              AccountRow(
                icon: Icons.face_retouching_natural,
                title: 'Face Recognition',
                subtitle: 'Optional photo-matching profile',
                onTap: () => open(const FaceRecognitionSettingsPage()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              accountHeading('Account Actions'),
              RewardButton(
                'Log Out',
                outlined: true,
                onPressed: busy ? null : logout,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => open(DeleteAccountPage(repository: repo)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text(
                  'Delete Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              accountDescription(
                'Permanently removes your profile and personal data.',
              ),
            ],
          ),
        ),
        accountFailure(error),
      ],
    ),
  );
}
