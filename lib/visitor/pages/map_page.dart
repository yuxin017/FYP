import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../attractions/data/attraction_reader.dart';
import '../../attractions/data/attraction_repository.dart';
import '../../attractions/data/slot_reader.dart';
import '../../attractions/models/attraction.dart';
import '../../attractions/pages/attraction_details_page.dart';
import '../../attractions/widgets/attraction_cover.dart';
import '../../attractions/widgets/attraction_widgets.dart';
import '../../attractions/widgets/queue_attraction_card.dart';
import '../../park/park_feed.dart';
import '../../park/park_map_canvas.dart';
import '../../park/park_visit.dart';
import '../../park/assistant_page.dart';
import '../../park/intelligence_repository.dart';
import '../../park/landmark_page.dart';
import '../../park/situm_venue_page.dart';
import '../../park/venue_configuration.dart';
import '../../reservations/data/reservation_repository.dart';
import '../../reservations/pages/my_reservations_page.dart';
import '../../reservations/pages/reserve_attraction_page.dart';
import '../../reservations/widgets/reservation_widgets.dart';
import 'profile_settings_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.startPlace, this.attractions, this.slots});

  final ValueNotifier<String?>? startPlace;
  final AttractionReader? attractions;
  final SlotReader? slots;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final _catalogue = AttractionRepository(
    firestore: FirebaseFirestore.instance,
  );
  final _search = TextEditingController();
  String? _localStart, _selectedId, _destinationId;
  ParkPlaceKind? _kind = ParkPlaceKind.attractions;
  bool _filterChosen = false;
  bool _showAll = false, _heatmap = false;

  AttractionReader get _attractions => widget.attractions ?? _catalogue;
  SlotReader get _slots => widget.slots ?? _catalogue;
  String? get _startId => widget.startPlace?.value ?? _localStart;
  Future<void> landmark() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => LandmarkLocationPage(
          repository: FirebaseParkIntelligenceRepository(),
        ),
      ),
    );
    if (id != null && mounted) {
      setState(() {
        _localStart = id;
        widget.startPlace?.value = id;
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ReservationRepository? _reservations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return ReservationRepository(
      uid: user.uid,
      email: user.email,
      firestore: FirebaseFirestore.instance,
      functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
    );
  }

  void _details(Attraction place, ParkVisit visit) {
    final reservations = place.isRide ? _reservations() : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          if (reservations != null) {
            return ReserveAttractionPage(
              attraction: place,
              attractions: _attractions,
              slots: _slots,
              reservations: reservations,
              day: visit.day,
            );
          }
          return AttractionDetailsPage(
            store: _attractions,
            attractionId: place.id,
            slotReader: place.isRide ? _slots : null,
            day: visit.day,
            placeKind: place.placeKind,
          );
        },
      ),
    );
  }

  Future<Attraction?> _chooseStart(
    ParkVisit visit,
  ) => showModalBottomSheet<Attraction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      var selected = visit.place(_startId);
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Find My Location',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  const ReservationPanel(
                    child: Text(
                      'Select a nearby landmark to set your starting point on the park map.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selected?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Nearby landmark',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final place in visit.places)
                        DropdownMenuItem(
                          value: place.id,
                          child: Text(
                            place.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => selected = visit.place(value)),
                  ),
                  const SizedBox(height: 14),
                  ReservationButton(
                    label: 'Use This Landmark',
                    onPressed: selected == null
                        ? null
                        : () => Navigator.pop(context, selected),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  Future<void> _setStart(ParkVisit visit, {Attraction? destination}) async {
    final origin = await _chooseStart(visit);
    if (origin == null || !mounted) return;
    widget.startPlace?.value = origin.id;
    setState(() {
      _localStart = origin.id;
      _destinationId = destination?.id == origin.id ? null : destination?.id;
    });
  }

  void _directions(Attraction destination, ParkVisit visit) {
    if (visit.place(_startId) == null) {
      _setStart(visit, destination: destination);
    } else {
      setState(() => _destinationId = destination.id);
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: queueBackground,
    child: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ParkFeed(
            attractions: _attractions,
            slots: _slots,
            builder: (context, visit, reload) {
              final origin = visit.place(_startId);
              final destination = visit.place(_destinationId);
              if (origin != null &&
                  destination != null &&
                  origin.id != destination.id) {
                return _route(visit, origin, destination);
              }
              return _browse(visit, origin);
            },
          ),
        ),
      ),
    ),
  );

  Widget _browse(ParkVisit visit, Attraction? origin) {
    final query = _search.text.trim().toLowerCase();
    final activeKind = !_filterChosen && query.isNotEmpty ? null : _kind;
    final matches = visit.places
        .where(
          (place) =>
              (activeKind == null || place.placeKind == activeKind) &&
              '${place.name} ${place.category} ${place.placeKind.label}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    if (origin != null) {
      matches.sort((a, b) {
        final distance = parkDistanceSquared(
          a,
          origin,
        ).compareTo(parkDistanceSquared(b, origin));
        return distance == 0 ? a.name.compareTo(b.name) : distance;
      });
    }
    final selected = matches
        .where((place) => place.id == _selectedId)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 18),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Park Map',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: queueInk,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Park Assistant',
                    icon: const Icon(Icons.support_agent, color: queueRose),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParkAssistantPage(
                          repository: FirebaseParkIntelligenceRepository(),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Profile settings',
                    icon: const Icon(Icons.settings_outlined, color: queueRose),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileSettingsPage(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reservations and reminders',
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: queueRose,
                    ),
                    onPressed: () {
                      final store = _reservations();
                      if (store != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MyReservationsPage(store: store),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {
                  _selectedId = null;
                  _showAll = false;
                }),
                decoration: InputDecoration(
                  hintText: 'Search attractions & facilities',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF69727A),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEEDCD8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: queueRose),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final kind in ParkPlaceKind.values)
                    ChoiceChip(
                      label: Text(kind.label),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      labelPadding: const EdgeInsets.only(left: 3, right: 1),
                      visualDensity: VisualDensity.compact,
                      avatarBoxConstraints: const BoxConstraints.tightFor(
                        width: 16,
                        height: 16,
                      ),
                      avatar: Icon(
                        parkPlaceIcon(kind),
                        size: 16,
                        color: activeKind == kind ? Colors.white : queueRose,
                      ),
                      selected: activeKind == kind,
                      showCheckmark: false,
                      selectedColor: const Color(0xFFAD7472),
                      backgroundColor: queueBackground,
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: activeKind == kind
                            ? const Color(0xFFAD7472)
                            : const Color(0xFFEADBD7),
                      ),
                      labelStyle: TextStyle(
                        color: activeKind == kind ? Colors.white : queueInk,
                        fontSize: 12,
                      ),
                      onSelected: (selected) => setState(() {
                        _filterChosen = true;
                        _kind = selected ? kind : null;
                        _selectedId = null;
                        _showAll = false;
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: .98,
          child: Stack(
            children: [
              Positioned.fill(
                child: ParkMapCanvas(
                  visit: visit,
                  visible: matches,
                  origin: origin,
                  heatmap: _heatmap,
                  selectedId: _selectedId,
                  onPlace: (place) => setState(() => _selectedId = place.id),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 12,
                child: Column(
                  children: [
                    _mapButton(
                      _heatmap ? 'Hide crowd heatmap' : 'Show crowd heatmap',
                      Icons.layers_outlined,
                      () => setState(() => _heatmap = !_heatmap),
                    ),
                    const SizedBox(height: 8),
                    _mapButton(
                      'Locate a Landmark',
                      Icons.photo_camera_outlined,
                      landmark,
                    ),
                    const SizedBox(height: 8),
                    _mapButton(
                      'Find My Location',
                      Icons.my_location,
                      visit.places.isEmpty ? null : () => _setStart(visit),
                    ),
                    if (VenueConfiguration.situmReady) ...[
                      const SizedBox(height: 8),
                      _mapButton(
                        'Live Park Navigation',
                        Icons.near_me_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SitumVenuePage(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ReservationPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4D9D6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nearby',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: queueInk,
                      ),
                    ),
                  ),
                  if (selected != null || matches.length > 2)
                    TextButton(
                      onPressed: () => setState(() {
                        _showAll = selected != null || !_showAll;
                        _selectedId = null;
                      }),
                      child: Text(
                        selected == null && _showAll ? 'See less' : 'See all',
                      ),
                    ),
                ],
              ),
              if (origin == null)
                const Text(
                  'Choose a starting point to sort by nearby places.',
                  style: TextStyle(fontSize: 12),
                )
              else
                Text(
                  'Starting point: ${origin.name}',
                  style: const TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 8),
              if (selected != null) ...[
                _placeRow(selected, visit),
                OutlinedButton.icon(
                  onPressed: origin?.id == selected.id
                      ? null
                      : () => _directions(selected, visit),
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Directions'),
                ),
              ] else if (matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No places match this view.'),
                )
              else
                for (final place in (_showAll ? matches : matches.take(2)))
                  _placeRow(place, visit),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeRow(Attraction place, ParkVisit visit) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: AttractionCover(
      encoded: place.coverImageBase64,
      width: 48,
      height: 52,
      placeholderIcon: parkPlaceIcon(place.placeKind),
    ),
    title: Text(
      place.name,
      style: const TextStyle(fontWeight: FontWeight.w700, color: queueInk),
    ),
    subtitle: Text(
      place.description ?? place.category,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _details(place, visit),
  );

  Widget _mapButton(String label, IconData icon, VoidCallback? action) =>
      IconButton.filled(
        tooltip: label,
        onPressed: action,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: queueInk,
        ),
        icon: Icon(icon),
      );

  Widget _route(
    ParkVisit visit,
    Attraction origin,
    Attraction destination,
  ) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      ReservationPanel(
        child: Row(
          children: [
            const Icon(Icons.directions_outlined, color: queueRose, size: 35),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Towards ${destination.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'From ${origin.name}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: .9,
        child: ParkMapCanvas(
          visit: visit,
          visible: [destination],
          origin: origin,
          destination: destination,
          selectedId: destination.id,
          onPlace: (place) => _details(place, visit),
        ),
      ),
      const SizedBox(height: 12),
      ReservationPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Schematic direction preview',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'Walking distance and arrival estimates require a surveyed path map.',
            ),
            const SizedBox(height: 12),
            if (VenueConfiguration.situmReady) ...[
              ReservationButton(
                label: 'Start Live Navigation',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SitumVenuePage(destinationId: destination.id),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ReservationButton(
              label: 'End Navigation',
              onPressed: () => setState(() => _destinationId = null),
            ),
          ],
        ),
      ),
    ],
  );
}
