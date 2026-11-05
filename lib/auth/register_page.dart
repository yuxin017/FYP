import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_gate.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _agreed = false;
  bool _loading = false;
  String _dialCode = '+60';

  static const rose = Color(0xFFA87D7E);
  static const dark = Color(0xFF292626);


  Widget _passwordRequirement(String text, bool fulfilled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            fulfilled
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: fulfilled ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: fulfilled ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Include a lowercase letter';
    if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(value)) return 'Include a special character';
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      _message('Please review and agree to the Terms and Privacy Policy.');
      return;
    }
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final user = credential.user;
      if (user == null) throw StateError('No Firebase user was returned');
      await FirebaseFirestore.instance.collection('visitors').doc(user.uid).set({
        'uid': user.uid,
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'phoneNumber': '$_dialCode${_phone.text.trim()}',
        'role': 'visitor',
        'loyaltyPoints': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await user.updateDisplayName(_name.text.trim());
      await user.sendEmailVerification();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      final messages = {
        'email-already-in-use': 'This email is already registered.',
        'invalid-email': 'Please enter a valid email address.',
        'weak-password': 'Please use a stronger password.',
        'operation-not-allowed': 'Enable Email/Password in Firebase Authentication.',
      };
      _message(messages[e.code] ?? e.message ?? 'Registration failed.');
    } on FirebaseException catch (e) {
      _message('Account may have been created, but profile saving failed: ${e.message ?? e.code}. Check Firebase before retrying.');
    } catch (e) {
      _message('Registration could not finish. Check Firebase before trying again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: rose, fontSize: 15),
      suffixIcon: suffix ?? Icon(icon, color: rose, size: 23),
      suffixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 40),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 17),
      border: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF929292))),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF929292))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: rose, width: 2)),
    );
  }

  Widget _field(TextEditingController controller, String hint, IconData icon,
      {TextInputType? keyboard, String? Function(String?)? validator, Widget? suffix,
        bool obscure = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(color: dark, fontSize: 16),
      decoration: _decoration(hint, icon, suffix: suffix),
      validator: validator,
    );
  }

  void _policyInfo(String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('The final policy document has not been added yet. This screen is for development testing only. Add the actual document before release.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/Background.png', fit: BoxFit.cover),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_ios_new, color: dark)),
                          IconButton(onPressed: () => _message('Help centre is coming soon.'), icon: const Icon(Icons.help_outline, color: dark)),
                        ]),
                        const SizedBox(height: 36),
                        Image.asset('assets/images/Theme_Park_Main_Logo.png', width: 170, height: 145, fit: BoxFit.contain),
                        const SizedBox(height: 14),
                        const Text('Create Account', textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold, color: dark)),
                        const SizedBox(height: 27),

                        _field(
                          _name,
                          'Full Name',
                          Icons.person,
                          validator: (v) {
                            final name = v?.trim() ?? '';

                            if (name.isEmpty) {
                              return 'Please enter your full name.';
                            }

                            if (name.length < 2) {
                              return 'Full name must contain at least 2 letters.';
                            }

                            if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(name)) {
                              return 'Full name must contain letters only.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        _field(_email, 'Email Address', Icons.email, keyboard: TextInputType.emailAddress,
                            validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email'),
                        const SizedBox(height: 12),
                        Row(children: [
                          DropdownButtonHideUnderline(child: DropdownButton<String>(
                            value: _dialCode,
                            dropdownColor: const Color(0xFFFFF8F4),
                            style: const TextStyle(color: rose, fontSize: 15),
                            items: const ['+60', '+65', '+86', '+1', '+44'].map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                            onChanged: (v) { if (v != null) setState(() => _dialCode = v); },
                          )),
                          const SizedBox(width: 10),
                          Container(width: 1, height: 28, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_phone, 'Phone Number', Icons.phone, keyboard: TextInputType.phone,
                              validator: (v) => RegExp(r'^\d{7,12}$').hasMatch(v?.trim() ?? '') ? null : 'Please enter a valid phone number (e.g. 123456789).')),
                        ]),
                        const Divider(height: 1, color: Color(0xFF929292)),
                        const SizedBox(height: 12),
                        _field(_password, 'Password', Icons.visibility_off, obscure: _hidePassword,
                            validator: _passwordValidator,
                            suffix: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility, color: rose))),
                        const SizedBox(height: 12),
                        _field(_confirm, 'Confirm Password', Icons.visibility_off, obscure: _hideConfirm,
                            validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                            suffix: IconButton(onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                                icon: Icon(_hideConfirm ? Icons.visibility_off : Icons.visibility, color: rose))),
                        const SizedBox(height: 10),

                        AnimatedBuilder(
                          animation: _password,
                          builder: (context, child) {
                            final password = _password.text;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _passwordRequirement(
                                  'At least 8 characters',
                                  password.length >= 8,
                                ),
                                _passwordRequirement(
                                  'One uppercase letter (A-Z)',
                                  RegExp(r'[A-Z]').hasMatch(password),
                                ),
                                _passwordRequirement(
                                  'One lowercase letter (a-z)',
                                  RegExp(r'[a-z]').hasMatch(password),
                                ),
                                _passwordRequirement(
                                  'One special character (!@#...)',
                                  RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/~`]')
                                      .hasMatch(password),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 13),
                        Row(children: [
                          Checkbox(value: _agreed, activeColor: rose, onChanged: (v) => setState(() => _agreed = v ?? false)),
                          Expanded(child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                            const Text('I agree to the ', style: TextStyle(fontSize: 12, color: dark)),
                            GestureDetector(onTap: () => _policyInfo('Terms'), child: const Text('Terms', style: TextStyle(fontSize: 12, color: rose))),
                            const Text(' and ', style: TextStyle(fontSize: 12, color: dark)),
                            GestureDetector(onTap: () => _policyInfo('Privacy Policy'), child: const Text('Privacy Policy', style: TextStyle(fontSize: 12, color: rose))),
                          ])),
                        ]),
                        const SizedBox(height: 15),
                        SizedBox(height: 52, child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          style: ElevatedButton.styleFrom(backgroundColor: rose, foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                          child: _loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Create Account', style: TextStyle(fontSize: 17)),
                        )),
                        const SizedBox(height: 14),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('Already have an account?', style: TextStyle(fontSize: 13, color: Color(0xFF777777))),
                          TextButton(onPressed: () => Navigator.maybePop(context), child: const Text('Log In', style: TextStyle(color: rose))),
                        ]),
                        const SizedBox(height: 65),
                        const Text('Version 1.0.0', textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF555555))),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
