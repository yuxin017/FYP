import 'package:flutter/material.dart';
import 'account_repository.dart';
import 'account_widgets.dart';
import '../visitor/widgets/rewards_widgets.dart';

class ChangePasswordPage extends StatefulWidget {
  final AccountRepository repository;
  const ChangePasswordPage({super.key, required this.repository});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final form = GlobalKey<FormState>(),
      current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false, done = false;
  String? error;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.changePassword(current.text, next.text);
      if (mounted) {
        setState(() {
          done = true;
          current.clear();
          next.clear();
          confirm.clear();
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
    title: 'Reset Password',
    busy: busy,
    child: ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(28, 35, 28, 28),
      children: [
        Image.asset('assets/images/Theme_Park_Main_Logo.png', height: 130),
        const SizedBox(height: 25),
        if (done) ...[
          const Icon(Icons.check_circle_outline, color: rewardRose, size: 70),
          const SizedBox(height: 18),
          accountHeading('Your password has been updated'),
          accountDescription(
            'Use your new password the next time you sign in.',
          ),
          const SizedBox(height: 24),
          RewardButton(
            'Back to Security',
            onPressed: () => Navigator.pop(context),
          ),
        ] else
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                accountHeading('Choose a new password'),
                AccountPasswordField(
                  controller: current,
                  label: 'Current password',
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Enter your current password.' : null,
                ),
                const SizedBox(height: 20),
                AccountPasswordField(
                  controller: next,
                  label: 'New password',
                  validator: (v) => v == current.text
                      ? 'Choose a different password.'
                      : passwordError(v),
                ),
                const SizedBox(height: 20),
                AccountPasswordField(
                  controller: confirm,
                  label: 'Confirm password',
                  validator: (v) =>
                      v != next.text ? 'Passwords do not match.' : null,
                ),
                const SizedBox(height: 13),
                accountDescription(
                  'At least 8 characters, including uppercase, lowercase and a special character.',
                ),
                accountFailure(error),
                const SizedBox(height: 25),
                RewardButton(
                  busy ? 'Updating…' : 'Reset Password',
                  onPressed: busy ? null : save,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class EmailChangePage extends StatefulWidget {
  final AccountRepository repository;
  const EmailChangePage({super.key, required this.repository});
  @override
  State<EmailChangePage> createState() => _EmailChangePageState();
}

class _EmailChangePageState extends State<EmailChangePage> {
  final form = GlobalKey<FormState>(),
      email = TextEditingController(),
      password = TextEditingController();
  bool busy = false, sent = false;
  String? error, confirmed;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.changeEmail(email.text, password.text);
      if (mounted) {
        setState(() {
          sent = true;
          password.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> check() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await widget.repository.refreshEmail();
      if (mounted) {
        setState(() {
          if (value.toLowerCase() == email.text.trim().toLowerCase()) {
            confirmed = value;
          } else {
            error =
                'The new email has not been verified yet. Open the verification link and try again.';
          }
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
    title: 'Email Address',
    busy: busy,
    child: ListView(
      primary: false,
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.mark_email_read_outlined, size: 74, color: rewardRose),
        const SizedBox(height: 22),
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              accountHeading(
                confirmed != null
                    ? 'Email updated'
                    : sent
                    ? 'Check your new inbox'
                    : 'Change your email',
              ),
              accountDescription(
                confirmed != null
                    ? 'Your verified email is $confirmed.'
                    : sent
                    ? 'Open the verification link sent to ${email.text.trim()}, then return here. Your current email stays in use until verification is complete.'
                    : 'Current email: ${widget.repository.identity?.email ?? ''}',
              ),
              const SizedBox(height: 20),
              if (!sent)
                Form(
                  key: form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: accountInput('New email address'),
                        validator: (v) =>
                            v?.trim().toLowerCase() ==
                                widget.repository.identity?.email.toLowerCase()
                            ? 'Enter a different email address.'
                            : emailError(v),
                      ),
                      const SizedBox(height: 15),
                      AccountPasswordField(
                        controller: password,
                        label: 'Current password',
                        validator: (v) =>
                            (v ?? '').isEmpty ? 'Enter your password.' : null,
                      ),
                    ],
                  ),
                ),
              accountFailure(error),
              const SizedBox(height: 18),
              RewardButton(
                confirmed != null
                    ? 'Done'
                    : busy
                    ? 'Please wait…'
                    : sent
                    ? 'I Have Verified My Email'
                    : 'Send Verification Link',
                onPressed: busy
                    ? null
                    : confirmed != null
                    ? () => Navigator.pop(context)
                    : sent
                    ? check
                    : send,
              ),
              if (sent && confirmed == null)
                TextButton(
                  onPressed: busy ? null : () => setState(() => sent = false),
                  child: const Text('Use a different email'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class LoginSecurityPage extends StatefulWidget {
  final AccountRepository repository;
  const LoginSecurityPage({super.key, required this.repository});
  @override
  State<LoginSecurityPage> createState() => _LoginSecurityPageState();
}

class _LoginSecurityPageState extends State<LoginSecurityPage> {
  List<Map<String, dynamic>>? sessions;
  String? id, error;
  bool busy = false, confirming = false;
  final password = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final records = await widget.repository.sessions(),
          current = await widget.repository.currentSessionId();
      if (mounted) {
        setState(() {
          sessions = records;
          id = current;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    }
  }

  Future<void> revoke() async {
    if (password.text.isEmpty) {
      setState(() => error = 'Enter your password to continue.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.revokeSessions(password.text);
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Login & Security',
    busy: busy,
    child: ListView(
      primary: false,
      padding: const EdgeInsets.all(22),
      children: [
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: accountHeading('Signed-in Devices')),
                  IconButton(
                    tooltip: 'Refresh devices',
                    onPressed: busy ? null : load,
                    icon: const Icon(Icons.refresh, color: rewardRose),
                  ),
                ],
              ),
              accountDescription('Devices that have opened your park account.'),
              const SizedBox(height: 14),
              if (sessions == null && error == null)
                const Center(
                  child: CircularProgressIndicator(color: rewardRose),
                ),
              if (sessions?.isEmpty == true)
                accountDescription('No saved login devices.'),
              for (final record in sessions ?? <Map<String, dynamic>>[])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.devices_outlined,
                        size: 32,
                        color: rewardRose,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record['deviceName'] as String? ?? 'Device',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Last active ${sessionDate(record['lastSeenAt'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: rewardMuted,
                              ),
                            ),
                            if (record['sessionId'] == id)
                              const Text(
                                'This device',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: rewardRose,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              accountHeading('Remove all saved login devices'),
              accountDescription(
                'Sign out of your account on every device, including this one. You can sign in again with your password.',
              ),
              const SizedBox(height: 20),
              if (confirming) ...[
                AccountPasswordField(
                  controller: password,
                  label: 'Current password',
                ),
                const SizedBox(height: 16),
              ],
              RewardButton(
                busy
                    ? 'Signing out…'
                    : confirming
                    ? 'Confirm Sign Out Everywhere'
                    : 'Sign Out All Devices',
                outlined: true,
                onPressed: busy
                    ? null
                    : confirming
                    ? revoke
                    : () => setState(() => confirming = true),
              ),
              if (confirming)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          confirming = false;
                          password.clear();
                        }),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ),
        accountFailure(error),
      ],
    ),
  );
}

class DeleteAccountPage extends StatefulWidget {
  final AccountRepository repository;
  final bool recovering;
  const DeleteAccountPage({
    super.key,
    required this.repository,
    this.recovering = false,
  });
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final confirmation = TextEditingController(),
      password = TextEditingController();
  bool understood = false, busy = false;
  String? error;
  @override
  void dispose() {
    confirmation.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (busy || !understood || confirmation.text != 'DELETE') return;
    if (password.text.isEmpty) {
      setState(() => error = 'Enter your current password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.close(password.text);
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Delete Account',
    busy: busy,
    bottomNav: !widget.recovering,
    child: ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF8E6E3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: rewardRose,
              size: 52,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          widget.recovering
              ? 'Finish deleting your account'
              : 'Are you sure you want to delete your account?',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: rewardInk,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.recovering
              ? 'Your previous deletion was interrupted. Confirm your password to safely finish removing your data.'
              : 'This action is permanent and cannot be undone.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: rewardMuted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 22),
        RewardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              accountHeading('What will be deleted'),
              for (final item in [
                (Icons.person_outline, 'Profile and personal information'),
                (
                  Icons.confirmation_number_outlined,
                  'Linked tickets and visit history',
                ),
                (Icons.discount_outlined, 'Loyalty points and vouchers'),
                (Icons.chat_bubble_outline, 'Support requests and attachments'),
              ]) ...[
                AccountRow(icon: item.$1, title: item.$2),
                if (item.$1 != Icons.chat_bubble_outline)
                  const Divider(height: 1, color: rewardBorder),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        RewardCard(
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: rewardRose),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Unused tickets, points and vouchers will be lost.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: rewardRose,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: understood,
          onChanged: busy
              ? null
              : (v) => setState(() => understood = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I understand that this action cannot be undone.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        accountHeading('Type DELETE to confirm'),
        TextField(
          controller: confirmation,
          enabled: !busy,
          onChanged: (_) => setState(() {}),
          decoration: accountInput('DELETE'),
        ),
        const SizedBox(height: 16),
        AccountPasswordField(controller: password, label: 'Current password'),
        accountFailure(error),
        const SizedBox(height: 16),
        RewardButton(
          busy ? 'Deleting…' : 'Delete My Account',
          onPressed: busy || !understood || confirmation.text != 'DELETE'
              ? null
              : close,
        ),
        const SizedBox(height: 12),
        if (!widget.recovering)
          RewardButton(
            'Keep My Account',
            outlined: true,
            onPressed: busy ? null : () => Navigator.pop(context),
          ),
        const SizedBox(height: 14),
        accountDescription(
          'Cancel active attraction reservations before deleting. Non-personal security and audit records may be retained.',
        ),
      ],
    ),
  );
}
