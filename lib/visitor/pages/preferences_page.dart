import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});
  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  static const rose = Color(0xFFAD7472);
  final height = TextEditingController();
  final food = <String>{};
  final interests = <String>{};
  bool loaded = false, saving = false;
  static const foodOptions = ['Halal', 'Vegetarian', 'Vegan', 'No pork', 'No seafood', 'No preference'];
  static const interestOptions = ['Thrill rides', 'Family rides', 'Water rides', 'Shows', 'Food & dining', 'Photo spots'];
  @override
  void dispose() { height.dispose(); super.dispose(); }

  Widget choices(String title, List<String> options, Set<String> selected) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
      Wrap(spacing: 8, runSpacing: 5, children: options.map((option) => FilterChip(
        label: Text(option), selected: selected.contains(option),
        selectedColor: const Color(0xFFF0DDDA), checkmarkColor: rose,
        onSelected: (value) => setState(() { if (value) { selected.add(option); } else { selected.remove(option); } }),
      )).toList()),
    ],
  );

  Future<void> save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final raw = height.text.trim();
    final value = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && (value == null || value < 50 || value > 250)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid height between 50 and 250 cm.')));
      return;
    }
    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection('visitors').doc(user.uid).update({
        'heightCm': value,
        'foodPreferences': food.toList(),
        'parkInterests': interests.toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences saved successfully.')));
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
      appBar: AppBar(title: const Text('Preferences & Interests'), backgroundColor: const Color(0xFFFDF4EF), foregroundColor: const Color(0xFF263238)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('visitors').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Unable to load preferences.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!loaded) {
            final data = snapshot.data!.data() ?? {};
            height.text = data['heightCm']?.toString() ?? '';
            food.addAll((data['foodPreferences'] as List<dynamic>? ?? []).whereType<String>());
            interests.addAll((data['parkInterests'] as List<dynamic>? ?? []).whereType<String>());
            loaded = true;
          }
          return ListView(padding: const EdgeInsets.all(24), children: [
            const Text('Personalize your park experience', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            TextField(controller: height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (cm) · optional', prefixIcon: Icon(Icons.height), border: OutlineInputBorder())),
            choices('Food preferences', foodOptions, food),
            choices('Park interests', interestOptions, interests),
            const SizedBox(height: 28),
            FilledButton(onPressed: saving ? null : save, style: FilledButton.styleFrom(backgroundColor: rose, minimumSize: const Size.fromHeight(52)), child: Text(saving ? 'Saving...' : 'Save Preferences')),
          ]);
        },
      ),
    );
  }
}
