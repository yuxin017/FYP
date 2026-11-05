import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../visitor_main_page.dart';
import '../widgets/visitor_ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    return VisitorScreen(title: 'Discover', children: [
      Text('Hello, ${name == null || name.isEmpty ? 'Explorer' : name}!', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Your next adventure starts here.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 22),
      ClipRRect(borderRadius: BorderRadius.circular(22), child: Stack(children: [
        Image.asset('assets/images/Background.png', height: 185, width: double.infinity, fit: BoxFit.cover),
        Positioned(left: 18, bottom: 16, right: 18, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .87), borderRadius: BorderRadius.circular(12)), child: const Text('Explore the magic of Theme Park', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))))
      ])),
      const SizedBox(height: 22),
      const Text('Quick access', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ActionTile(icon: Icons.confirmation_number_outlined, title: 'My Tickets', onTap: () => VisitorMainPage.goTo(context, 1))),
        const SizedBox(width: 12),
        Expanded(child: ActionTile(icon: Icons.hourglass_bottom, title: 'Virtual Queue', onTap: () => VisitorMainPage.goTo(context, 3))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ActionTile(icon: Icons.map_outlined, title: 'Park Map', onTap: () => VisitorMainPage.goTo(context, 2))),
        const SizedBox(width: 12),
        Expanded(child: ActionTile(icon: Icons.person_outline, title: 'My Profile', onTap: () => VisitorMainPage.goTo(context, 4))),
      ]),
      const SizedBox(height: 24),
      const VisitorNotice('Demo mode: park attractions and wait times are sample data. Real-time park services require backend integration.'),
    ]);
  }
}
