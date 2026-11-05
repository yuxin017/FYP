import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/visitor_ui.dart';

class QueuePage extends StatefulWidget { const QueuePage({super.key}); @override State<QueuePage> createState() => _QueuePageState(); }
class _QueuePageState extends State<QueuePage> {
  String? selected;
  static const rides = [('Sky Coaster', 'Thrill', 35), ('Magic Carousel', 'Family', 10), ('River Adventure', 'Water', 25), ('Castle Express', 'Family', 15)];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final prefs = await SharedPreferences.getInstance(); if (mounted) setState(() => selected = prefs.getString('demo_queue_ride')); }
  Future<void> _setRide(String? name) async { final prefs = await SharedPreferences.getInstance(); if (name == null) { await prefs.remove('demo_queue_ride'); } else { await prefs.setString('demo_queue_ride', name); } if (mounted) setState(() => selected = name); }
  @override Widget build(BuildContext context) => VisitorScreen(title: 'Virtual Queue', children: [
    const VisitorNotice('Estimated waits below are illustrative, not live. Demo queue selections are saved locally and do not reserve real attraction capacity.'),
    const SizedBox(height: 20),
    if (selected != null) Card(color: const Color(0xFFFFECE8), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('My Demo Queue', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(selected!, style: const TextStyle(fontSize: 20)), const SizedBox(height: 10), VisitorButton(label: 'Leave Demo Queue', onPressed: () => _setRide(null))]))),
    const SizedBox(height: 12), const Text('Attractions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
    ...rides.map((ride) => Card(color: Colors.white, margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
      CircleAvatar(backgroundColor: const Color(0xFFFFECE8), child: Icon(ride.$2 == 'Water' ? Icons.water_drop_outlined : Icons.attractions, color: visitorRose)), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ride.$1, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${ride.$2} · Sample wait ${ride.$3} min', style: const TextStyle(fontSize: 12, color: Colors.black54))])),
      TextButton(onPressed: selected == null ? () => _setRide(ride.$1) : null, child: Text(selected == ride.$1 ? 'Joined' : 'Join')),
    ])))),
  ]);
}
