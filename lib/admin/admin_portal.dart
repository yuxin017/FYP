import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../auth/login_error_message.dart';
import 'admin_repository.dart';
import 'admin_shell.dart';
import 'admin_widgets.dart';

class AdminPortal extends StatefulWidget {
  final Widget Function(AdminFirebase, User)? staffBuilder;
  const AdminPortal({super.key, this.staffBuilder});
  @override
  State<AdminPortal> createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  late final Future<AdminFirebase> firebase = AdminFirebase.initialize();
  @override
  Widget build(BuildContext context) => Theme(
    data: adminTheme(context),
    child: FutureBuilder<AdminFirebase>(
      future: firebase,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: AdminEmpty(
              'Unable to open Admin Portal',
              'Check your connection and refresh the page.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: adminRose)),
          );
        }
        final service = snapshot.data!;
        return StreamBuilder<User?>(
          stream: service.auth.idTokenChanges(),
          builder: (context, state) {
            final user = state.data;
            if (user == null) {
              return AdminLoginPage(
                onSignIn: (email, password, remember) async {
                  if (kIsWeb) {
                    await service.auth.setPersistence(
                      remember ? Persistence.LOCAL : Persistence.SESSION,
                    );
                  }
                  final result = await service.auth.signInWithEmailAndPassword(
                    email: email.trim(),
                    password: password,
                  );
                  await result.user?.getIdTokenResult(true);
                },
                onReset: service.auth.sendPasswordResetEmail,
              );
            }
            return FutureBuilder<IdTokenResult>(
              future: user.getIdTokenResult(),
              builder: (context, token) {
                if (!token.hasData && !token.hasError) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: adminRose),
                    ),
                  );
                }
                if (token.data?.claims?['admin'] != true ||
                    !user.emailVerified) {
                  return Scaffold(
                    body: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: AdminCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 55,
                                  color: adminRose,
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Administrator access required',
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  !user.emailVerified
                                      ? 'Verify your account email before opening the admin portal.'
                                      : 'This account does not have administrator access.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: adminMuted),
                                ),
                                const SizedBox(height: 20),
                                AdminButton(
                                  'Refresh Access',
                                  onPressed: () async {
                                    await user.reload();
                                    await user.getIdTokenResult(true);
                                    if (mounted) setState(() {});
                                  },
                                ),
                                const SizedBox(height: 10),
                                AdminButton(
                                  'Use Another Account',
                                  outlined: true,
                                  onPressed: service.auth.signOut,
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamedAndRemoveUntil(
                                        '/',
                                        (route) => false,
                                      ),
                                  child: const Text('Return to visitor app'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                if (widget.staffBuilder != null) {
                  return widget.staffBuilder!(service, user);
                }
                return AdminShell(
                  repository: FirebaseAdminRepository(service),
                  adminName: user.displayName?.trim().isNotEmpty == true
                      ? user.displayName!
                      : user.email?.split('@').first ?? 'Administrator',
                  adminEmail: user.email ?? '',
                  onSignOut: service.auth.signOut,
                );
              },
            );
          },
        );
      },
    ),
  );
}

ThemeData adminTheme(BuildContext context) => Theme.of(context).copyWith(
  scaffoldBackgroundColor: adminBackground,
  colorScheme: ColorScheme.fromSeed(
    seedColor: adminRose,
    primary: adminRose,
    surface: Colors.white,
  ),
  textTheme: Theme.of(context).textTheme.apply(
    fontFamily: 'Roboto',
    bodyColor: adminDark,
    displayColor: adminDark,
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(color: adminMuted, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: adminBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: adminBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: adminRose),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  ),
  dividerColor: adminBorder,
  dataTableTheme: const DataTableThemeData(
    headingRowColor: WidgetStatePropertyAll(Color(0xFFFEFCFB)),
  ),
);

class AdminLoginPage extends StatefulWidget {
  final Future<void> Function(String email, String password, bool remember)
  onSignIn;
  final Future<void> Function({required String email}) onReset;
  const AdminLoginPage({
    super.key,
    required this.onSignIn,
    required this.onReset,
  });
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool remember = false, obscure = true, busy = false;
  String? error, message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await widget.onSignIn(email.text, password.text, remember);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = loginErrorMessage(e.code));
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Unable to sign in. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reset() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())) {
      setState(() => error = 'Enter your work email first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await widget.onReset(email: email.text.trim());
      if (mounted) {
        setState(
          () => message =
              'Password reset instructions have been sent if this account is registered.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to send reset instructions. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final card = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: AdminCard(
            padding: EdgeInsets.all(wide ? 48 : 24),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Admin Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: wide ? 40 : 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sign in to manage park operations',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, color: adminMuted),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Work Email',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  TextFormField(
                    key: const Key('admin-email'),
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      hintText: 'Enter your work email',
                      prefixIcon: Icon(
                        Icons.mail_outline,
                        color: adminMuted,
                        size: 21,
                      ),
                    ),
                    validator: (v) =>
                        RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch((v ?? '').trim())
                        ? null
                        : 'Enter a valid email address.',
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Password',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  TextFormField(
                    key: const Key('admin-password'),
                    controller: password,
                    enabled: !busy,
                    obscureText: obscure,
                    enableSuggestions: false,
                    autocorrect: false,
                    onFieldSubmitted: (_) => signIn(),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: adminMuted,
                        size: 21,
                      ),
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: adminMuted,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Enter your password.' : null,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: remember,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => remember = v ?? false),
                          ),
                          const Text(
                            'Remember this device',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: busy ? null : reset,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(color: adminRose, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        message!,
                        style: const TextStyle(
                          color: Color(0xFF278D52),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: busy ? null : signIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: adminRose,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(busy ? 'Signing in…' : 'Sign In Securely'),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(
                          Icons.shield_outlined,
                          color: adminMuted,
                          size: 23,
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Authorized personnel only',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: adminMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        );
        final login = SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 42 : 20,
            vertical: 28,
          ),
          child: Column(
            children: [
              if (!wide) ...[
                Image.asset(
                  'assets/images/Theme_Park_Main_Logo.png',
                  height: 110,
                ),
                const SizedBox(height: 20),
              ],
              card,
              const SizedBox(height: 30),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: adminMuted,
                    size: 23,
                  ),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Access is restricted to authorized park administrators.',
                      style: TextStyle(color: adminMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false),
                child: const Text(
                  'Return to visitor app',
                  style: TextStyle(color: adminMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        );
        return wide
            ? Row(
                children: [
                  Expanded(
                    flex: 45,
                    child: SizedBox.expand(
                      child: Image.asset(
                        'assets/images/admin/login-brand.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Expanded(flex: 55, child: Center(child: login)),
                ],
              )
            : Center(child: login);
      },
    ),
  );
}
