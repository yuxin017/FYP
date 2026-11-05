import 'package:flutter/material.dart';
import '../widgets/visitor_ui.dart';

class MapPage extends StatefulWidget { const MapPage({super.key}); @override State<MapPage> createState() => _MapPageState(); }
class _MapPageState extends State<MapPage> {
  String filter = 'All';
  static const spots = [('Castle Plaza','Landmark', Icons.castle_outlined),('Sky Coaster','Attraction',Icons.attractions),('River Adventure','Attraction',Icons.water_drop_outlined),('Food Court','Dining',Icons.restaurant),('First Aid','Service',Icons.medical_services_outlined),('Restrooms','Service',Icons.wc)];
  @override Widget build(BuildContext context) => VisitorScreen(title: 'Park Map', children: [
    Container(height: 235, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0xFFFFE7E0)), child: Stack(children: [
      Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Opacity(opacity: .55, child: Image.asset('assets/images/Background.png', fit: BoxFit.cover)))),
      const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map_outlined, size: 65, color: visitorRose), Text('Park directory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text('Illustrative view · not GPS navigation', style: TextStyle(fontSize: 12))])),
    ])), const SizedBox(height: 18),
    Wrap(spacing: 7, children: ['All','Attraction','Dining','Service','Landmark'].map((s) => ChoiceChip(label: Text(s), selected: filter == s, selectedColor: const Color(0xFFFFDAD4), onSelected: (_) => setState(() => filter = s))).toList()),
    const SizedBox(height: 14),
    ...spots.where((s) => filter == 'All' || s.$2 == filter).map((s) => Card(color: Colors.white, child: ListTile(leading: Icon(s.$3, color: visitorRose), title: Text(s.$1), subtitle: Text(s.$2), trailing: const Icon(Icons.chevron_right), onTap: () => showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(s.$1), content: const Text('This is a sample park directory entry. Indoor positioning and turn-by-turn directions are not yet connected.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))]))))),
    const SizedBox(height: 10), const VisitorNotice('Wi-Fi RTT, PDR, indoor floor plans and live location require real site calibration and supported devices.'),
  ]);
}
