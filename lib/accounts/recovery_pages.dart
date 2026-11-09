import 'dart:async';
import 'package:flutter/material.dart';
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
      link = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  String stage = 'email', code = '';
  String? error, resetEmail;
  bool busy = false;
  int cooldown = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      link.text = widget.initialCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => verify());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    link.dispose();
    password.dispose();
    confirm.dispose();
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

  Future<void> send() async {
    if (busy || cooldown > 0) return;
    if (stage == 'email' && !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.resetEmail(email.text);
      if (mounted) {
        setState(() {
          stage = 'sent';
          countdown();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (busy) return;
    final raw = link.text.trim();
    final uri = Uri.tryParse(raw);
    code = uri?.queryParameters['oobCode'] ?? raw;
    if (code.isEmpty) {
      setState(() => error = 'Paste the password reset link from your email.');
      return;
    }
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
          link.clear();
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
    title: stage == 'password' ? 'Reset Password' : 'Forgot Password',
    bottomNav: false,
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
              ? 'Check Your Email'
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
                  decoration: accountInput(
                    'Email Address',
                  ).copyWith(prefixIcon: const Icon(Icons.mail_outline)),
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
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 65,
                color: rewardRose,
              ),
              const SizedBox(height: 20),
              accountDescription(
                'If an account exists for ${email.text.trim()}, a password reset link will arrive in its inbox. Check spam or junk folders too.',
              ),
              const SizedBox(height: 20),
              RewardButton(
                cooldown > 0 ? 'Resend in ${cooldown}s' : 'Resend Reset Email',
                outlined: true,
                onPressed: busy || cooldown > 0 ? null : send,
              ),
              const SizedBox(height: 25),
              accountHeading('Already have your reset link?'),
              accountDescription(
                'You can reset in the email link, or paste that link here to continue.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: link,
                decoration: accountInput('Paste password reset link'),
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 12),
              RewardButton(
                busy ? 'Checking…' : 'Continue',
                onPressed: busy ? null : verify,
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
                  validator: passwordError,
                ),
                const SizedBox(height: 20),
                AccountPasswordField(
                  controller: confirm,
                  label: 'Confirm password',
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
