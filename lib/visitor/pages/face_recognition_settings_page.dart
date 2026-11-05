import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FaceRecognitionSettingsPage extends StatefulWidget {
  const FaceRecognitionSettingsPage({super.key});
  @override
  State<FaceRecognitionSettingsPage> createState() => _FaceRecognitionSettingsPageState();
}

class _FaceRecognitionSettingsPageState extends State<FaceRecognitionSettingsPage> {
  static const rose = Color(0xFFAD7472);
  bool? consent;
  bool saving = false;
  Future<void> save(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection('visitors').doc(user.uid).update({'faceRecognitionConsent': value});
      if (!mounted) return;
      setState(() => consent = value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? 'Consent preference saved. Face matching is not yet active.' : 'Face recognition consent disabled.')));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save: ${e.code}')));
    } finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in again.')));
    return Scaffold(
      backgroundColor: const Color(0xFFFDF4EF),
      appBar: AppBar(title: const Text('Face Recognition'), backgroundColor: const Color(0xFFFDF4EF)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('visitors').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final enabled = consent ?? (snapshot.data!.data()?['faceRecognitionConsent'] == true);
          return ListView(padding: const EdgeInsets.all(24), children: [
            const Icon(Icons.face_retouching_natural, size: 80, color: rose),
            const SizedBox(height: 20),
            const Text('Optional photo matching', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('This setting records whether you consent to future face-based photo matching. It does not upload a biometric template or activate face recognition.'),
            const SizedBox(height: 20),
            SwitchListTile(title: const Text('Allow face recognition'), subtitle: const Text('Optional · can be turned off'), value: enabled, activeThumbColor: rose, onChanged: saving ? null : save),
            const SizedBox(height: 12),
            const Text('Face recognition requires a separate secure backend, selfie enrollment, deletion controls and an explicit privacy policy.', style: TextStyle(color: Colors.grey)),
          ]);
        },
      ),
    );
  }
}
