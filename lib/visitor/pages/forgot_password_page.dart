
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const Color rose = Color(0xFFAD7472);
  static const Color dark = Color(0xFF263238);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate() || _sending) return;

    setState(() => _sending = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Check Your Email'),
          content: const Text(
            'If an account exists for this email address, '
                'you will receive a password reset link. '
                'Please check your inbox and spam folder.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'OK',
                style: TextStyle(color: rose),
              ),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Unable to send reset email. Please try again.';

      if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many requests. Please try again later.';
      } else if (e.code == 'network-request-failed') {
        message = 'Please check your internet connection.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF4EF),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.55,
              child: Image.asset(
                'assets/images/Background.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: dark,
                              ),
                            ),
                            const Icon(
                              Icons.help_outline,
                              color: dark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 55),
                        Image.asset(
                          'assets/images/Theme_Park_Main_Logo.png',
                          width: 180,
                          height: 145,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 42),
                        const Text(
                          'Forgot Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: dark,
                          ),
                        ),
                        const SizedBox(height: 65),
                        Row(
                          children: [
                            const Text(
                              'Reset using',
                              style: TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Email Address',
                              style: TextStyle(
                                color: rose,
                                fontSize: 13,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: rose,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.mail_outline,
                                color: dark,
                              ),
                              hintText: 'Email Address',
                              border: UnderlineInputBorder(),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: rose),
                              ),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email)) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 85),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _sending ? null : _sendResetEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: rose,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _sending
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              'Reset Password',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Remember your password? ',
                              style: TextStyle(fontSize: 12),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Back to Log In',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: rose,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 100),
                        const Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
