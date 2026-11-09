import 'package:flutter/material.dart';

import '../attractions/data/attraction_reader.dart';
import '../attractions/data/slot_reader.dart';
import '../attractions/models/attraction.dart';
import '../attractions/models/attraction_slot.dart';
import '../attractions/models/park_time.dart';
import '../attractions/widgets/attraction_cover.dart';
import '../attractions/widgets/queue_attraction_card.dart';
import '../reservations/data/reservation_store.dart';
import '../reservations/models/reservation.dart';
import '../reservations/pages/my_reservations_page.dart';
import '../reservations/widgets/reservation_widgets.dart';
import '../visitor/pages/preferences_page.dart';
import 'park_feature_frame.dart';
import 'park_feed.dart';
import 'park_visit.dart';
import 'intelligence_repository.dart';

class SmartItineraryPage extends StatefulWidget {
  const SmartItineraryPage({
    super.key,
    required this.attractions,
    required this.slots,
    required this.reservations,
    required this.watchProfile,
    required this.onPlace,
    required this.onTab,
    this.originId,
    this.clock,
    this.intelligence,
  });

  final AttractionReader attractions;
  final SlotReader slots;
  final ReservationStore reservations;
  final Stream<Map<String, dynamic>?> Function() watchProfile;
  final void Function(Attraction, AttractionSlot?) onPlace;
  final ValueChanged<int> onTab;
  final String? originId;
  final DateTime Function()? clock;
  final ParkIntelligenceRepository? intelligence;

  @override
  State<SmartItineraryPage> createState() => _SmartItineraryPageState();
}

class _SmartItineraryPageState extends State<SmartItineraryPage> {
  late Stream<List<RideReservation>> _bookings = widget.reservations
      .watchReservations();
  late Stream<Map<String, dynamic>?> _profile = widget.watchProfile();
  int _refresh = 0;
  late Future<Map<String, dynamic>>? learned = widget.intelligence?.request(
    'recommendations',
    {},
  );

  void _reload() => setState(() {
    _bookings = widget.reservations.watchReservations();
    _profile = widget.watchProfile();
    _refresh++;
    learned = widget.intelligence?.request('recommendations', {});
  });

  void _preferences() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const PreferencesPage()));

  @override
  Widget build(BuildContext context) => ParkFeatureFrame(
    title: 'Your Smart Itinerary',
    onTab: widget.onTab,
    action: IconButton(
      tooltip: 'Refresh itinerary',
      icon: const Icon(Icons.auto_awesome_outlined, color: queueRose),
      onPressed: _reload,
    ),
    body: ParkFeed(
      key: ValueKey(_refresh),
      attractions: widget.attractions,
      slots: widget.slots,
      clock: widget.clock,
      builder: (context, visit, _) => StreamBuilder<Map<String, dynamic>?>(
        stream: _profile,
        builder: (context, profile) => StreamBuilder<List<RideReservation>>(
          stream: _bookings,
          builder: (context, bookings) {
            if (profile.hasError || bookings.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ReservationPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not load your profile or reservations.',
                        ),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (!bookings.hasData ||
                profile.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return FutureBuilder<Map<String, dynamic>>(
              future: learned,
              builder: (context, ranked) => _content(
                visit,
                profile.data ?? {},
                bookings.data!,
                ranked.data,
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _content(
    ParkVisit visit,
    Map<String, dynamic> profile,
    List<RideReservation> bookings,
    Map<String, dynamic>? ranked,
  ) {
    final interests =
        (profile['parkInterests'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final foods =
        (profile['foodPreferences'] as List?)?.whereType<String>() ??
        const <String>[];
    final savedHeight = profile['heightCm'];
    final height = savedHeight is int && savedHeight >= 50 && savedHeight <= 250
        ? savedHeight
        : null;
    final name = profile['fullName'] as String? ?? 'You';
    final stops = planParkVisit(
      visit: visit,
      reservations: bookings,
      interests: interests,
      heightCm: height,
      origin: visit.place(widget.originId),
      relevance: {
        for (final row
            in (ranked?['recommendations'] as List? ?? []).cast<Map>())
          row['id'] as String: (row['score'] as num).toDouble(),
      },
    );
    final suggested = stops.where((stop) => stop.slot != null).toList();
    final actionText = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontSize: 12, fontWeight: FontWeight.w600);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 16),
      children: [
        ReservationPanel(
          child: Row(
            children: [
              VisitorAvatar(
                visitor: ReservationVisitor(
                  uid: widget.reservations.uid,
                  name: name,
                  heightCm: height,
                  photo: profile['profilePhotoBase64'] as String?,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recommended for',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        color: queueInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        for (final interest in interests)
                          _preferenceChip(interest, Icons.attractions_outlined),
                        for (final food in foods)
                          if (food != 'No preference')
                            _preferenceChip(
                              '$food dining',
                              Icons.restaurant_outlined,
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (stops.isEmpty)
          ReservationPanel(
            child: Text(
              visit.slots == null
                  ? 'Return times are loading or unavailable. Refresh to check again.'
                  : 'No suitable stops fit your visit today. Check your preferences or browse the queue.',
            ),
          )
        else
          ReservationPanel(
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                Positioned(
                  left: 70,
                  top: 24,
                  bottom: 0,
                  width: 1,
                  child: ColoredBox(color: queueRose.withValues(alpha: .55)),
                ),
                Column(
                  children: [for (final stop in stops) _stop(visit, stop)],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: queueRose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 10,
                  ),
                  textStyle: actionText,
                ),
                onPressed: suggested.isEmpty
                    ? null
                    : () => _suggestions(suggested),
                child: const Text(
                  'Reserve Suggested Slots',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: queueRose,
                  side: const BorderSide(color: queueRose),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 10,
                  ),
                  textStyle: actionText,
                ),
                onPressed: _preferences,
                child: const Text(
                  'Adjust Preferences',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _preferenceChip(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: queueRose.withValues(alpha: .50)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: queueRose, size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: queueRose, fontSize: 11),
          ),
        ),
      ],
    ),
  );

  Widget _stop(ParkVisit visit, ItineraryStop stop) {
    final place = stop.attraction;
    final crowd = place == null ? null : visit.crowdFor(place);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 59,
                child: Text(
                  ParkTime.time(stop.startsAt),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: queueRose,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 13,
                height: 13,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: queueRose),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () {
                        final slot = stop.slot;
                        if (slot != null && place != null) {
                          widget.onPlace(place, slot);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MyReservationsPage(
                                store: widget.reservations,
                              ),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          AttractionCover(
                            encoded: place?.coverImageBase64,
                            width: 65,
                            height: 68,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop.name,
                                  style: const TextStyle(
                                    color: queueInk,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  stop.slot == null
                                      ? 'Reserved return window'
                                      : 'Return slot available',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (crowd != null)
                                  Text(
                                    '${crowd.label} crowd',
                                    style: TextStyle(
                                      color: crowdColor(crowd),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 17),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: queueBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.star_border,
                            color: queueRose,
                            size: 16,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              stop.reason,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1E8E5)),
      ],
    );
  }

  void _suggestions(List<ItineraryStop> stops) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Reserve Suggested Slots',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 5),
        const Text('Select a return time to review and confirm.'),
        for (final stop in stops)
          ListTile(
            title: Text(stop.name),
            subtitle: Text(returnWindow(stop.startsAt, stop.endsAt)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(sheetContext).pop();
              widget.onPlace(stop.attraction!, stop.slot!);
            },
          ),
      ],
    ),
  );
}
