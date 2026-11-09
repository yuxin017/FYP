import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../accounts/account_widgets.dart';
import '../photos/photo_widgets.dart';
import '../services/application_api.dart';
import 'auth_gate.dart';

String phoneAuthError(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-phone-number' =>
        'Enter your phone number with its country code, for example +60.',
      'invalid-verification-code' =>
        'The verification code is incorrect. Please try again.',
      'session-expired' =>
        'This verification code has expired. Request a new code.',
      'too-many-requests' || 'quota-exceeded' =>
        'SMS is temporarily unavailable. Please try later or sign in with email.',
      'operation-not-allowed' ||
      'billing-not-enabled' ||
      'app-not-authorized' ||
      'captcha-check-failed' =>
        'Phone verification is unavailable right now. Please use email sign-in or contact park support.',
      'credential-already-in-use' =>
        'This phone is linked to another account. Use that account or choose another number.',
      'requires-recent-login' =>
        'Please sign in again with your password before changing your linked phone.',
      _ => 'Phone verification could not finish. Please try again.',
    };
  }
  return 'Check your connection and try again.';
}

class PhoneAuthPage extends StatefulWidget {
  final bool link;
  const PhoneAuthPage({super.key, this.link = false});
  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final phone = TextEditingController(),
      code = TextEditingController(),
      auth = FirebaseAuth.instance;
  ConfirmationResult? confirmation;
  String? verificationId, error;
  int? resendToken;
  int cooldown = 0;
  Timer? timer;
  bool busy = false, finishing = false, finished = false;
  @override
  void initState() {
    super.initState();
    if (widget.link) phone.text = auth.currentUser?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    timer?.cancel();
    super.dispose();
  }

  void countdown() {
    timer?.cancel();
    cooldown = 60;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => cooldown--);
      if (cooldown <= 0) t.cancel();
    });
  }

  Future<void> complete(UserCredential result) async {
    if (finished) return;
    if (!widget.link && result.additionalUserInfo?.isNewUser == true) {
      await result.user?.delete();
      await auth.signOut();
      throw StateError(
        'This phone is not linked to a park account. Sign in with email, then link your phone in Security & Account.',
      );
    }
    if (widget.link) {
      await auth.currentUser?.reload();
      await ApplicationApi().post('/v1/profile/sync-phone');
      if (mounted) {
        finished = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number verified and linked.')),
        );
        Navigator.pop(context);
      }
    } else if (mounted) {
      finished = true;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (r) => false,
      );
    }
  }

  Future<void> accept(PhoneAuthCredential credential) async {
    if (finishing || finished) return;
    finishing = true;
    try {
      final result = widget.link
          ? await auth.currentUser!.linkWithCredential(credential)
          : await auth.signInWithCredential(credential);
      await complete(result);
    } finally {
      finishing = false;
    }
  }

  Future<void> send() async {
    if (busy || cooldown > 0) return;
    final number = phone.text.replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(number)) {
      setState(
        () => error = 'Enter your phone number including the country code.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (kIsWeb) {
        confirmation = widget.link
            ? await auth.currentUser!.linkWithPhoneNumber(number)
            : await auth.signInWithPhoneNumber(number);
        verificationId = confirmation!.verificationId;
        if (mounted) setState(countdown);
      } else {
        final sent = Completer<void>();
        await auth.verifyPhoneNumber(
          phoneNumber: number,
          forceResendingToken: resendToken,
          verificationCompleted: (credential) async {
            try {
              await accept(credential);
              if (!sent.isCompleted) sent.complete();
            } catch (e) {
              if (!sent.isCompleted) {
                sent.completeError(e);
              } else if (mounted) {
                setState(() => error = phoneAuthError(e));
              }
            }
          },
          verificationFailed: (e) {
            if (!sent.isCompleted) sent.completeError(e);
          },
          codeSent: (id, token) {
            if (mounted) {
              setState(() {
                verificationId = id;
                resendToken = token;
                countdown();
              });
            }
            if (!sent.isCompleted) sent.complete();
          },
          codeAutoRetrievalTimeout: (id) {
            verificationId = id;
            if (!sent.isCompleted) sent.complete();
          },
        );
        await sent.future.timeout(const Duration(seconds: 65));
      }
    } catch (e) {
      if (mounted) setState(() => error = phoneAuthError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (busy || finished) return;
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => error = 'Enter the six-digit SMS code.');
      return;
    }
    setState(() => busy = true);
    try {
      if (kIsWeb) {
        await complete(await confirmation!.confirm(code.text.trim()));
      } else {
        await accept(
          PhoneAuthProvider.credential(
            verificationId: verificationId!,
            smsCode: code.text.trim(),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = phoneAuthError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> unlink() async {
    final okay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove linked phone?'),
        content: const Text(
          'You can continue signing in with your email and password. Link a new phone after removing this number.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Phone'),
          ),
        ],
      ),
    );
    if (okay != true) return;
    setState(() => busy = true);
    try {
      if (auth.currentUser!.providerData
          .where((p) => p.providerId != 'phone')
          .isEmpty) {
        throw StateError(
          'Add another sign-in method before removing your phone.',
        );
      }
      await auth.currentUser!.unlink('phone');
      if (mounted) {
        setState(() {
          phone.clear();
          verificationId = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = phoneAuthError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linked = widget.link && auth.currentUser?.phoneNumber != null;
    return AccountScaffold(
      title: widget.link ? 'Linked Phone Number' : 'Phone Number Sign In',
      bottomNav: widget.link,
      busy: busy,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PhotoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  verificationId == null
                      ? Icons.phone_android_outlined
                      : Icons.sms_outlined,
                  size: 72,
                  color: photoRose,
                ),
                const SizedBox(height: 23),
                Text(
                  linked
                      ? 'Your phone is linked'
                      : verificationId == null
                      ? 'Continue with your phone'
                      : 'Verify your phone number',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  linked
                      ? '${auth.currentUser!.phoneNumber} can be used to sign in to this same account.'
                      : widget.link
                      ? 'Verify your phone with an SMS code to add another way to sign in.'
                      : 'Use a phone number already linked to your park account. You can link a phone after signing in with email.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 24),
                if (linked)
                  PhotoButton(
                    'Remove Linked Phone',
                    outlined: true,
                    onPressed: busy ? null : unlink,
                  )
                else ...[
                  TextField(
                    controller: phone,
                    enabled: !busy && verificationId == null,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+60',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (verificationId != null) ...[
                    TextField(
                      controller: code,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        labelText: 'SMS Verification Code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    PhotoButton(
                      'Verify & Continue',
                      busy: busy,
                      onPressed: busy ? null : verify,
                    ),
                    const SizedBox(height: 13),
                    TextButton(
                      onPressed: busy || cooldown > 0 ? null : send,
                      child: Text(
                        cooldown > 0
                            ? 'Resend code in ${cooldown}s'
                            : 'Resend Code',
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              verificationId = null;
                              confirmation = null;
                              code.clear();
                              cooldown = 0;
                              timer?.cancel();
                            }),
                      child: const Text('Use Another Number'),
                    ),
                  ] else
                    PhotoButton(
                      'Send Verification Code',
                      busy: busy,
                      onPressed: busy ? null : send,
                    ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, height: 1.5),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'SMS messages are sent by Firebase. Standard messaging rates may apply.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF7C8289)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
