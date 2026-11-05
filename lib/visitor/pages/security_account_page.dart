import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SecurityAccountPage extends StatefulWidget {
  const SecurityAccountPage({super.key});
  @override
  State<SecurityAccountPage> createState() => _SecurityAccountPageState();
}

class _SecurityAccountPageState extends State<SecurityAccountPage> {
  static const rose = Color(0xFFAD7472);
  bool busy = false;
  Future<void> resetPassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email requested. Check your inbox and spam folder.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to send email: ${e.code}')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFFDF4EF),
      appBar: AppBar(title: const Text('Security & Account'), backgroundColor: const Color(0xFFFDF4EF)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(child: ListTile(leading: const Icon(Icons.verified_user_outlined, color: rose), title: const Text('Email verification'), subtitle: Text(user?.emailVerified == true ? 'Verified' : 'Not verified'))),
        Card(child: ListTile(leading: const Icon(Icons.lock_reset, color: rose), title: const Text('Reset password'), subtitle: const Text('Send a secure password reset link to your email'), trailing: busy ? const CircularProgressIndicator() : const Icon(Icons.chevron_right), onTap: busy ? null : resetPassword)),
        Card(child: ListTile(leading: const Icon(Icons.logout, color: rose), title: const Text('Log out'), onTap: () async {
          final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Log out?'), content: const Text('You can sign in again anytime.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out'))]));
          if (confirm != true) return;
          await FirebaseAuth.instance.signOut();
          if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        })),
        const Padding(padding: EdgeInsets.all(12), child: Text('Changing email and permanently deleting an account require a separate verified account-management flow. These actions are not enabled here.', style: TextStyle(color: Colors.grey))),
      ]),
    );
  }
}
