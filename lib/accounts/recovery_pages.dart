import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'account_repository.dart';
import 'account_widgets.dart';
import '../visitor/widgets/rewards_widgets.dart';

class PasswordRecoveryPage extends StatefulWidget {
  final AccountRepository? repository;
  final String? initialCode;
  const PasswordRecoveryPage({super.key, this.repository, this.initialCode});
  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  late final repo = widget.repository ?? FirebaseAccountRepository();
  final form = GlobalKey<FormState>(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  final digits = List.generate(6, (_) => TextEditingController());
  final digitFocus = List.generate(6, (_) => FocusNode());
  String stage = 'email', code = '', challengeId = '';
  String? error, resetEmail;
  bool busy = false;
  int cooldown = 0;
  int secondsLeft = 0;
  DateTime? expiresAt, resendAt;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      code =
          Uri.tryParse(widget.initialCode!)?.queryParameters['oobCode'] ??
          widget.initialCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => verifyLink());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    for (final controller in digits) {
      controller.dispose();
    }
    for (final focus in digitFocus) {
      focus.dispose();
    }
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void countdown() {
    timer?.cancel();
    void update() {
      final now = DateTime.now();
      cooldown = ((resendAt!.difference(now).inMilliseconds + 999) ~/ 1000)
          .clamp(0, 60);
      secondsLeft = ((expiresAt!.difference(now).inMilliseconds + 999) ~/ 1000)
          .clamp(0, 300);
    }

    update();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(update);
      if (cooldown <= 0 && secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> send() async {
    if (busy || cooldown > 0) return;
    if (stage == 'email' && !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await repo.sendResetOtp(email.text);
      if (mounted) {
        setState(() {
          stage = 'sent';
          challengeId = result['challengeId'] as String;
          expiresAt = DateTime.parse(result['expiresAt'] as String);
          resendAt = DateTime.now().add(
            Duration(seconds: result['resendAfterSeconds'] as int),
          );
          for (final digit in digits) {
            digit.clear();
          }
          countdown();
        });
        digitFocus.first.requestFocus();
      }
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verifyLink() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final address = await repo.verifyReset(code);
      if (mounted) {
        setState(() {
          resetEmail = address;
          stage = 'password';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verifyOtp() async {
    if (busy) return;
    final otp = digits.map((d) => d.text).join();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => error = 'Enter all six digits from your email.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await repo.verifyResetOtp(challengeId, otp);
      if (!mounted) return;
      timer?.cancel();
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        code = result['code'] as String;
        resetEmail = result['email'] as String;
        stage = 'password';
        for (final digit in digits) {
          digit.clear();
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void enterDigits(int index, String value) {
    if (value.length > 1) {
      final start = value.length == 6 ? 0 : index;
      for (var i = start; i < 6 && i - start < value.length; i++) {
        digits[i].text = value[i - start];
      }
      digitFocus[(start + value.length).clamp(0, 5)].requestFocus();
    } else if (value.isNotEmpty && index < 5) {
      digitFocus[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      digitFocus[index - 1].requestFocus();
    }
  }

  Future<void> reset() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.confirmReset(code, password.text);
      if (mounted) {
        setState(() {
          password.clear();
          confirm.clear();
          code = '';
          stage = 'done';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: stage == 'password'
        ? 'Reset Password'
        : stage == 'sent'
        ? 'Authentication'
        : 'Forgot Password',
    bottomNav: false,
    showHeaderTitle: false,
    busy: busy,
    child: ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(34, 22, 34, 25),
      children: [
        Image.asset('assets/images/Theme_Park_Main_Logo.png', height: 150),
        const SizedBox(height: 32),
        Text(
          stage == 'password'
              ? 'Reset Password'
              : stage == 'sent'
              ? 'Authentication'
              : stage == 'done'
              ? 'Password Updated'
              : 'Forgot Password',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: rewardInk,
          ),
        ),
        const SizedBox(height: 38),
        if (stage == 'email')
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Reset using   Email Address',
                  style: TextStyle(
                    color: rewardRose,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: accountInput('Email Address').copyWith(
                    prefixIcon: const Icon(Icons.mail_outline),
                    filled: false,
                    border: const UnderlineInputBorder(),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: rewardRose),
                    ),
                  ),
                  validator: emailError,
                ),
                const SizedBox(height: 40),
                RewardButton(
                  busy ? 'Sending…' : 'Reset Password',
                  onPressed: busy ? null : send,
                ),
              ],
            ),
          ),
        if (stage == 'sent')
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'You will receive an OTP if you have registered a profile with us.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: rewardInk, height: 1.5),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        label: 'OTP digit ${i + 1}',
                        child: TextField(
                          key: ValueKey('reset-otp-$i'),
                          controller: digits[i],
                          focusNode: digitFocus[i],
                          enabled: !busy && secondsLeft > 0,
                          keyboardType: TextInputType.number,
                          textInputAction: i == 5
                              ? TextInputAction.done
                              : TextInputAction.next,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                          autofillHints: i == 0
                              ? const [AutofillHints.oneTimeCode]
                              : null,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: .85),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          onChanged: (v) => enterDigits(i, v),
                          onTap: () => digits[i].selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: digits[i].text.length,
                          ),
                          onSubmitted: (_) => verifyOtp(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text(
                secondsLeft > 0
                    ? 'OTP will expire in ${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}'
                    : 'Your OTP has expired. Request a new code.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 70),
              RewardButton(
                busy ? 'Checking…' : 'Verify',
                onPressed: busy || secondsLeft == 0 ? null : verifyOtp,
              ),
              const SizedBox(height: 16),
              const Text(
                'Didn’t receive your OTP?',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: busy || cooldown > 0 ? null : send,
                child: Text(
                  cooldown > 0 ? 'Try again in ${cooldown}s' : 'Try again',
                ),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        timer?.cancel();
                        setState(() {
                          stage = 'email';
                          error = null;
                        });
                      },
                child: const Text('Use another email address'),
              ),
            ],
          ),
        if (stage == 'password')
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                accountDescription('Choose a new password for $resetEmail.'),
                const SizedBox(height: 20),
                AccountPasswordField(
                  controller: password,
                  label: 'New password',
                  underlined: true,
                  validator: passwordError,
                ),
                const SizedBox(height: 20),
                AccountPasswordField(
                  controller: confirm,
                  label: 'Confirm password',
                  underlined: true,
                  validator: (v) =>
                      v != password.text ? 'Passwords do not match.' : null,
                ),
                const SizedBox(height: 14),
                accountDescription(
                  'At least 8 characters, including uppercase, lowercase and a special character.',
                ),
                const SizedBox(height: 35),
                RewardButton(
                  busy ? 'Resetting…' : 'Reset Password',
                  onPressed: busy ? null : reset,
                ),
              ],
            ),
          ),
        if (stage == 'done')
          Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 75,
                color: rewardRose,
              ),
              const SizedBox(height: 20),
              accountDescription(
                'Your new password is ready. Sign in to continue your adventure.',
              ),
            ],
          ),
        accountFailure(error),
        const SizedBox(height: 20),
        TextButton(
          onPressed: busy ? null : () => Navigator.maybePop(context),
          child: const Text('Back to Log In'),
        ),
        const SizedBox(height: 40),
        const Text(
          'Version 1.0.0',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF918584), fontSize: 12),
        ),
      ],
    ),
  );
}

class CompleteProfilePage extends StatefulWidget {
  final AccountRepository repository;
  const CompleteProfilePage({super.key, required this.repository});
  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final form = GlobalKey<FormState>(),
      name = TextEditingController(),
      phone = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.createProfile(name.text, phone.text);
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Complete Your Profile',
    bottomNav: false,
    busy: busy,
    child: ListView(
      primary: false,
      padding: const EdgeInsets.all(28),
      children: [
        Image.asset('assets/images/Theme_Park_Main_Logo.png', height: 140),
        const SizedBox(height: 24),
        accountHeading('Let’s finish setting up your account'),
        accountDescription(
          'Your sign-in is ready. Add your name and phone number to continue.',
        ),
        const SizedBox(height: 22),
        Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: name,
                decoration: accountInput('Full name'),
                validator: nameError,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: accountInput('Phone number'),
                validator: phoneError,
              ),
            ],
          ),
        ),
        accountFailure(error),
        const SizedBox(height: 24),
        RewardButton(
          busy ? 'Saving…' : 'Save and Continue',
          onPressed: busy ? null : save,
        ),
        TextButton(
          onPressed: busy ? null : widget.repository.signOut,
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );
}

class DataPrivacyPage extends StatelessWidget {
  final bool terms;
  const DataPrivacyPage({super.key, this.terms = false});
  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: terms ? 'Terms of Use' : 'Privacy Policy',
    bottomNav: false,
    child: ListView(
      primary: false,
      padding: const EdgeInsets.all(24),
      children: [
        accountHeading(
          terms ? 'Your park account' : 'Your information and choices',
        ),
        for (final item
            in (terms
                    ? <String, String>{
                        'Account access':
                            'Use your own registered account and keep your sign-in details private. Verify your email before using bookings and account services.',
                        'Tickets and bookings':
                            'Check visit dates, guest information and the order summary before confirming. Ticket validity and admission use are shown with each pass.',
                        'Payments':
                            'Booking confirmation saves your selected payment method and order. No bank or card charge is made by the current checkout.',
                        'Using rewards':
                            'Review voucher terms before confirming use. Used vouchers cannot be redeemed again.',
                        'Support':
                            'Contact Help & Support with a booking reference when you need assistance.',
                      }
                    : <String, String>{
                        'Information you provide':
                            'Your account stores your name, email and phone number. Date of birth, gender, profile photo, height, nickname and interests are optional profile details.',
                        'How your information is used':
                            'Details support sign-in, tickets, rewards and your park experience. Your height and preferences can be used by attraction and recommendation features.',
                        'Bookings and support':
                            'Orders, tickets, rewards and support conversations are linked to your account. Staff with administrator access handle relevant park records. Private staff notes are restricted to administrators.',
                        'Photos and recognition':
                            'A profile avatar does not activate face recognition. The separate photo-matching preference is optional.',
                        'Live location':
                            'Location sharing is optional and runs while its screen is open in the foreground. Recent positions contribute to combined crowd information without displaying visitor names. Live positions expire after two minutes and private movement samples expire after 24 hours.',
                        'Your controls':
                            'Edit your profile and preferences, change your password or verified email, sign out of saved login devices, and permanently delete your account from Security & Account. Non-personal security and audit records may be retained.',
                        'Get in touch':
                            'Use Help & Support for questions about your information or account.',
                      })
                .entries) ...[
          const SizedBox(height: 18),
          RewardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                accountHeading(item.key),
                accountDescription(item.value),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
