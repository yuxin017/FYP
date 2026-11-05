import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/visitor_ui.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});
  @override
  State<TicketsPage> createState() => _TicketsPageState();
}
class _TicketsPageState extends State<TicketsPage> {
  int quantity = 1; int saved = 0; bool busy = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final prefs = await SharedPreferences.getInstance(); if (mounted) setState(() => saved = prefs.getInt('demo_ticket_count') ?? 0); }
  Future<void> _reserve() async {
    setState(() => busy = true);
    try { final prefs = await SharedPreferences.getInstance(); final total = saved + quantity; await prefs.setInt('demo_ticket_count', total); if (!mounted) return; setState(() => saved = total); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo tickets added. No payment was made.'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => VisitorScreen(title: 'Tickets', children: [
    const Text('My Tickets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
    Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.confirmation_number, color: visitorRose, size: 38), const SizedBox(height: 10), Text('$saved demo admission ticket(s)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('Tickets saved on this device only. These are not valid park admission QR codes.'),
    ]))),
    const SizedBox(height: 24), const Text('Plan a Visit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8), const Text('General Admission · Demo reservation'), const SizedBox(height: 14),
    Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Expanded(child: Text('Visitors', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))), IconButton(onPressed: quantity > 1 ? () => setState(() => quantity--) : null, icon: const Icon(Icons.remove_circle_outline)), Text('$quantity', style: const TextStyle(fontSize: 19)), IconButton(onPressed: quantity < 10 ? () => setState(() => quantity++) : null, icon: const Icon(Icons.add_circle_outline, color: visitorRose))]))),
    const SizedBox(height: 16), VisitorButton(label: busy ? 'Saving...' : 'Add Demo Tickets', onPressed: busy ? null : _reserve),
    const SizedBox(height: 22), const VisitorNotice('Checkout, real ticket issuance, payment gateway and entry scanning are not connected. No money will be charged.'),
  ]);
}
