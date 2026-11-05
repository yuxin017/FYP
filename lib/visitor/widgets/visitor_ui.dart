import 'package:flutter/material.dart';

const visitorRose = Color(0xFFAD7472);
const visitorBackground = Color(0xFFFDF4EF);

class VisitorScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const VisitorScreen({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: visitorBackground,
    child: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF263238)))), const Icon(Icons.auto_awesome, color: visitorRose)]),
      const SizedBox(height: 22), ...children,
    ])),
  );
}
class ActionTile extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback onTap;
  const ActionTile({super.key, required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: Colors.white, borderRadius: BorderRadius.circular(17), child: InkWell(borderRadius: BorderRadius.circular(17), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8), child: Column(children: [Icon(icon, size: 32, color: visitorRose), const SizedBox(height: 12), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600))]))));
}
class VisitorNotice extends StatelessWidget {
  final String message; const VisitorNotice(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFECE8), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.info_outline, color: visitorRose), const SizedBox(width: 10), Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFF694D4A))))]));
}
class VisitorButton extends StatelessWidget {
  final String label; final VoidCallback? onPressed;
  const VisitorButton({super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(backgroundColor: visitorRose, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), child: Text(label)));
}
