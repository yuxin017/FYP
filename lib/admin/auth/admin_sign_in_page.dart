import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../portal/admin_theme.dart';

typedef AdminSignIn =
    Future<void> Function(String email, String password, bool remember);

/// Portal login is separate from A's customer authentication/navigation.
class AdminSignInPage extends StatefulWidget {
  const AdminSignInPage({
    super.key,
    required this.onSignIn,
    required this.onResetPassword,
  });
  final AdminSignIn onSignIn;
  final Future<void> Function(String email) onResetPassword;

  @override
  State<AdminSignInPage> createState() => _AdminSignInPageState();
}

class _AdminSignInPageState extends State<AdminSignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _hidden = true;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Enter a valid work email.';

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onSignIn(_email.text.trim(), _password.text, _remember);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _message = switch (error.code) {
            'invalid-credential' ||
            'wrong-password' ||
            'user-not-found' => 'Incorrect email or password.',
            'user-disabled' => 'This account has been disabled.',
            'too-many-requests' => 'Too many attempts. Please try again later.',
            'network-request-failed' => 'Check your connection and try again.',
            _ => 'Unable to sign in. Please try again.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    final invalid = _validateEmail(_email.text);
    if (invalid != null) {
      setState(
        () => _message = 'Enter your work email first to reset your password.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onResetPassword(_email.text.trim());
      if (mounted) {
        setState(
          () => _message =
              'If this account is registered, a password reset email will arrive shortly.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _message = error.code == 'user-not-found'
              ? 'If this account is registered, a password reset email will arrive shortly.'
              : 'Unable to send the reset email. Please try again later.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Unable to send the reset email. Please try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final form = Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 48 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  if (!wide) ...[
                    Image.asset(
                      'assets/images/Theme_Park_Main_Logo.png',
                      width: 160,
                    ),
                    const SizedBox(height: 24),
                  ],
                  Container(
                    padding: EdgeInsets.all(wide ? 40 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AdminTheme.border),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .045),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Admin Portal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Sign in to manage park operations',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AdminTheme.muted),
                            ),
                            const SizedBox(height: 34),
                            const Text(
                              'Work Email',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              key: const ValueKey('admin-email'),
                              controller: _email,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              validator: _validateEmail,
                              decoration: const InputDecoration(
                                hintText: 'Enter your work email',
                                prefixIcon: Icon(Icons.mail_outline, size: 19),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Password',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              key: const ValueKey('admin-password'),
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _hidden,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter your password.'
                                  : null,
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 19,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _hidden
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                            setState(() => _hidden = !_hidden),
                                  icon: Icon(
                                    _hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: _remember,
                                      onChanged: _busy
                                          ? null
                                          : (value) => setState(
                                              () => _remember = value!,
                                            ),
                                    ),
                                    const Flexible(
                                      child: Text(
                                        'Remember this device',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: _busy ? null : _resetPassword,
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _message!,
                                  key: const ValueKey('admin-login-message'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AdminTheme.ink,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign In Securely'),
                            ),
                            const SizedBox(height: 24),
                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(
                                    Icons.shield_outlined,
                                    size: 20,
                                    color: AdminTheme.muted,
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Authorized personnel only',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AdminTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 23,
                        color: AdminTheme.muted,
                      ),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Use your authorized park account.\nAdministrator access is verified after sign-in.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AdminTheme.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        if (!wide) return form;
        return Row(
          children: [
            Expanded(
              flex: 46,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/Background.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: .66,
                        child: Image.asset(
                          'assets/images/Theme_Park_Main_Logo.png',
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Text(
                        'Version 1.0.0',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8C6E66),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(flex: 54, child: form),
          ],
        );
      },
    ),
  );
}
