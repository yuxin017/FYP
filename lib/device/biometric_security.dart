import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../accounts/account_widgets.dart';
import '../photos/photo_widgets.dart';

class DeviceBiometrics {
  static final authentication = LocalAuthentication();
  static Future<bool> enabled(String uid) async =>
      !kIsWeb &&
      (await SharedPreferences.getInstance()).getBool(
            'biometric_unlock_$uid',
          ) ==
          true;
  static Future<bool> supported() async =>
      !kIsWeb && await authentication.isDeviceSupported();
  static Future<bool> unlock() async =>
      await supported() &&
      await authentication.authenticate(
        localizedReason: 'Unlock your Theme Park account',
        biometricOnly: defaultTargetPlatform != TargetPlatform.windows,
        persistAcrossBackgrounding: true,
      );
  static Future<void> setEnabled(String uid, bool value) async {
    if (value && !await unlock()) {
      throw StateError('Device authentication was not completed.');
    }
    await (await SharedPreferences.getInstance()).setBool(
      'biometric_unlock_$uid',
      value,
    );
  }
}

class BiometricUnlockGate extends StatefulWidget {
  final String uid;
  final Widget child;
  final Future<bool> Function()? onAuthenticate;
  const BiometricUnlockGate({
    super.key,
    required this.uid,
    required this.child,
    this.onAuthenticate,
  });
  @override
  State<BiometricUnlockGate> createState() => _BiometricUnlockGateState();
}

class _BiometricUnlockGateState extends State<BiometricUnlockGate>
    with WidgetsBindingObserver {
  late final ready = DeviceBiometrics.enabled(widget.uid);
  bool? required;
  bool unlocked = false, busy = false;
  String? error;
  DateTime? leftAt;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ready.then((enabled) {
      if (mounted) setState(() => required = enabled);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) leftAt = DateTime.now();
    if (state == AppLifecycleState.resumed &&
        leftAt != null &&
        DateTime.now().difference(leftAt!) > const Duration(minutes: 2)) {
      DeviceBiometrics.enabled(widget.uid).then((enabled) {
        if (mounted && enabled) setState(() => unlocked = false);
      });
    }
  }

  Future<void> unlock() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final okay = await (widget.onAuthenticate ?? DeviceBiometrics.unlock)();
      if (mounted) {
        setState(() {
          unlocked = okay;
          error = okay
              ? null
              : 'Authentication was cancelled. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Device authentication is unavailable. You can sign out and use your email and password.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (required == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (required == false || unlocked) return widget.child;
    return Scaffold(
      backgroundColor: photoBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: PhotoPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/images/Face_ID_Icon.png', height: 72),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 13),
                  const Text(
                    'Unlock your account with your device authentication.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 25),
                  PhotoButton(
                    busy ? 'Authenticating…' : 'Unlock Account',
                    onPressed: busy ? null : unlock,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await FirebaseAuth.instance.signOut();
                          },
                    child: const Text('Sign In with Email Instead'),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: photoRose, height: 1.5),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DeviceSecurityPage extends StatefulWidget {
  const DeviceSecurityPage({super.key});
  @override
  State<DeviceSecurityPage> createState() => _DeviceSecurityPageState();
}

class _DeviceSecurityPageState extends State<DeviceSecurityPage> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  bool? supported, enabled;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final can = await DeviceBiometrics.supported(),
          on = await DeviceBiometrics.enabled(uid);
      if (mounted) {
        setState(() {
          supported = can;
          enabled = on;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          supported = false;
          enabled = false;
        });
      }
    }
  }

  Future<void> toggle(bool value) async {
    setState(() => busy = true);
    try {
      await DeviceBiometrics.setEnabled(uid, value);
      if (mounted) setState(() => enabled = value);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Set up Face ID or a fingerprint in your device settings, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Device Authentication',
    busy: busy,
    child: ListView(
      padding: const EdgeInsets.all(23),
      children: [
        PhotoPanel(
          child: Column(
            children: [
              Image.asset('assets/images/Face_ID_Icon.png', height: 75),
              const SizedBox(height: 22),
              const Text(
                'A quicker way back to your account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 15),
              const Text(
                'Use Face ID, a fingerprint or your supported device authentication to unlock an existing sign-in. Your biometric data stays with your device.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 20),
              if (supported == null)
                const CircularProgressIndicator()
              else
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Unlock on this device'),
                  value: enabled ?? false,
                  onChanged: !supported! || busy ? null : toggle,
                ),
              if (supported == false)
                const Text(
                  'Open the installed app on a supported device to enable device authentication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: photoRose, height: 1.6),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const PhotoPanel(
          child: Text(
            'Signing out still ends the Firebase sign-in. On a new device, sign in with your email or linked phone first. Face matching for park photos is managed separately in Face Recognition.',
            style: TextStyle(height: 1.6),
          ),
        ),
      ],
    ),
  );
}
