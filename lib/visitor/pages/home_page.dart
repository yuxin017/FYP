import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../visitor_main_page.dart';
import '../widgets/visitor_ui.dart';
import '../../groups/group_pages.dart';
import '../../groups/group_repository.dart';
import '../../photos/photo_gallery_pages.dart';
import '../../photos/photo_repository.dart';
import '../../park/assistant_page.dart';
import '../../park/intelligence_repository.dart';
import '../../park/offers_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    return VisitorScreen(
      title: 'Discover',
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('visitors')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? {};
            final nickname = (data['nickname'] as String? ?? '').trim();
            final display = nickname.isNotEmpty
                ? nickname
                : (data['fullName'] as String? ?? name ?? 'Explorer');
            return Text(
              'Hello, ${display.isEmpty ? 'Explorer' : display}!',
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Your next adventure starts here.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 22),
        Semantics(
          label: 'Buy Tickets',
          button: true,
          child: Material(
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => VisitorMainPage.openTickets(context, 'catalog'),
              child: Image.asset(
                'assets/images/ticketing/hero.png',
                height: 185,
                width: double.infinity,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Quick access',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ActionTile(
          icon: Icons.local_offer_outlined,
          title: 'Park Offers',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ParkOffersPage(repository: FirebaseParkOffersRepository()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ActionTile(
          icon: Icons.support_agent,
          title: 'Park Assistant',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParkAssistantPage(
                repository: FirebaseParkIntelligenceRepository(),
                visitorName: name ?? '',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ActionTile(
          icon: Icons.groups_outlined,
          title: 'My Groups',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupsPage(repository: FirebaseGroupRepository()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ActionTile(
          icon: Icons.photo_library_outlined,
          title: 'My Park Photos',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'photos-hub'),
              builder: (_) =>
                  PhotoHubPage(repository: FirebasePhotoRepository()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ActionTile(
                icon: Icons.confirmation_number_outlined,
                title: 'My Tickets',
                onTap: () => VisitorMainPage.openTickets(context, 'tickets'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ActionTile(
                icon: Icons.hourglass_bottom,
                title: 'Virtual Queue',
                onTap: () => VisitorMainPage.goTo(context, 3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ActionTile(
                icon: Icons.map_outlined,
                title: 'Park Map',
                onTap: () => VisitorMainPage.goTo(context, 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ActionTile(
                icon: Icons.person_outline,
                title: 'My Profile',
                onTap: () => VisitorMainPage.goTo(context, 4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
