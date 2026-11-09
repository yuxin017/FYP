import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../attractions/data/attraction_repository.dart';
import '../../attractions/models/attraction.dart';
import '../../attractions/models/attraction_slot.dart';
import '../../attractions/models/queue_policy.dart';
import '../../attractions/pages/attractions_page.dart';
import '../../attractions/widgets/attraction_widgets.dart';
import '../../park/crowd_heatmap_page.dart';
import '../../park/smart_itinerary_page.dart';
import '../../park/intelligence_repository.dart';
import '../../groups/group_pages.dart';
import '../../groups/group_repository.dart';
import '../widgets/visitor_ui.dart';
import '../visitor_main_page.dart';
import '../../reservations/data/reservation_repository.dart';
import '../../reservations/pages/reserve_attraction_page.dart';
import '../../reservations/reminders/reservation_reminders.dart';

/// Customer attraction browsing and individual ride reservations.
class QueuePage extends StatefulWidget {
  const QueuePage({super.key, this.startPlace});

  final ValueNotifier<String?>? startPlace;

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  late final AttractionRepository _store;
  late Stream<User?> _users;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _store = AttractionRepository(firestore: _firestore);
    _users = _auth.authStateChanges();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _users,
    initialData: _auth.currentUser,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return VisitorScreen(
          title: 'Attractions',
          children: [
            AttractionMessage(
              icon: Icons.lock_outline,
              title: 'Could not check your session',
              message: 'Please try again or sign in again.',
              action: 'Try again',
              onAction: () => setState(() => _users = _auth.authStateChanges()),
            ),
          ],
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting &&
          snapshot.data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final user = snapshot.data;
      if (user == null) {
        return const VisitorScreen(
          title: 'Attractions',
          children: [
            AttractionMessage(
              icon: Icons.login,
              title: 'Please sign in',
              message: 'Sign in to view the park attractions.',
            ),
          ],
        );
      }
      return _SignedInAttractions(
        key: ValueKey(user.uid),
        uid: user.uid,
        firestore: _firestore,
        store: _store,
        startPlace: widget.startPlace,
      );
    },
  );
}

class _SignedInAttractions extends StatefulWidget {
  const _SignedInAttractions({
    super.key,
    required this.uid,
    required this.firestore,
    required this.store,
    this.startPlace,
  });
  final String uid;
  final FirebaseFirestore firestore;
  final AttractionRepository store;
  final ValueNotifier<String?>? startPlace;

  @override
  State<_SignedInAttractions> createState() => _SignedInAttractionsState();
}

class _SignedInAttractionsState extends State<_SignedInAttractions> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profile;
  late final ReservationRepository _reservations;

  @override
  void initState() {
    super.initState();
    _reservations = ReservationRepository(
      uid: widget.uid,
      firestore: widget.firestore,
      functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
      email: FirebaseAuth.instance.currentUser?.email,
    );
    _profile = widget.firestore
        .collection('visitors')
        .doc(widget.uid)
        .snapshots();
  }

  void _openPlace(Attraction place, AttractionSlot? slot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReserveAttractionPage(
          attraction: place,
          attractions: widget.store,
          slots: widget.store,
          reservations: _reservations,
          day: QueuePolicy.parkDay(slot?.startsAt ?? DateTime.now()),
          initialSlotId: slot?.id,
        ),
      ),
    );
  }

  void _selectTab(int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    VisitorMainPage.goTo(context, index);
  }

  void _openHeatmap(int? height, List<String> interests) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CrowdHeatmapPage(
          intelligence: FirebaseParkIntelligenceRepository(),
          attractions: widget.store,
          slots: widget.store,
          onPlace: _openPlace,
          onTab: _selectTab,
          heightCm: height,
          interests: interests,
          originId: widget.startPlace?.value,
        ),
      ),
    );
  }

  void _openItinerary() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SmartItineraryPage(
          intelligence: FirebaseParkIntelligenceRepository(),
          attractions: widget.store,
          slots: widget.store,
          reservations: _reservations,
          watchProfile: () => widget.firestore
              .collection('visitors')
              .doc(widget.uid)
              .snapshots()
              .map((snapshot) => snapshot.data()),
          onPlace: _openPlace,
          onTab: _selectTab,
          originId: widget.startPlace?.value,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _profile,
    builder: (context, snapshot) {
      final rawHeight = snapshot.data?.data()?['heightCm'];
      final height = rawHeight is int && rawHeight >= 50 && rawHeight <= 250
          ? rawHeight
          : null;
      final interests =
          (snapshot.data?.data()?['parkInterests'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      return ReservationReminders(
        store: _reservations,
        child: AttractionsPage(
          store: widget.store,
          slotReader: widget.store,
          reservations: _reservations,
          visitorHeightCm: height,
          parkInterests: interests,
          onHeatmap: () => _openHeatmap(height, interests),
          onPlan: _openItinerary,
          onGroups: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupsPage(repository: FirebaseGroupRepository()),
            ),
          ),
          notice: snapshot.hasError
              ? 'Your saved height could not be loaded. Attraction height requirements are still shown.'
              : null,
        ),
      );
    },
  );
}
