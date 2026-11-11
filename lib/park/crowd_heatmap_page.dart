import 'dart:async';
import 'package:flutter/material.dart';

import '../attractions/data/attraction_reader.dart';
import '../attractions/data/slot_reader.dart';
import '../attractions/models/attraction.dart';
import '../attractions/models/attraction_slot.dart';
import '../attractions/models/park_time.dart';
import '../attractions/widgets/attraction_cover.dart';
import '../attractions/widgets/queue_attraction_card.dart';
import '../reservations/widgets/reservation_widgets.dart';
import 'park_feature_frame.dart';
import 'park_feed.dart';
import 'park_map_canvas.dart';
import 'park_visit.dart';
import 'intelligence_repository.dart';
import 'location_repository.dart';

class CrowdHeatmapPage extends StatefulWidget {
  const CrowdHeatmapPage({
    super.key,
    required this.attractions,
    required this.slots,
    required this.onPlace,
    required this.onTab,
    this.originId,
    this.heightCm,
    this.interests = const [],
    this.clock,
    this.intelligence,
    this.locations,
  });

  final AttractionReader attractions;
  final SlotReader slots;
  final void Function(Attraction, AttractionSlot?) onPlace;
  final ValueChanged<int> onTab;
  final String? originId;
  final int? heightCm;
  final List<String> interests;
  final DateTime Function()? clock;
  final ParkIntelligenceRepository? intelligence;
  final ParkLocationRepository? locations;

  @override
  State<CrowdHeatmapPage> createState() => _CrowdHeatmapPageState();
}

class _CrowdHeatmapPageState extends State<CrowdHeatmapPage> {
  bool _full = false;
  bool live = false;
  late final locations = widget.locations ?? FirebaseParkLocationRepository();
  late Future<Map<String, dynamic>>? density = widget.intelligence?.request(
    'density',
    {},
  );
  Timer? refresh;
  Future<Map<String, dynamic>>? requestDensity() => live
      ? locations.request('density', {})
      : widget.intelligence?.request('density', {});
  @override
  void initState() {
    super.initState();
    if (widget.intelligence != null) {
      refresh = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) {
          setState(() => density = requestDensity());
        }
      });
    }
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ParkFeatureFrame(
    title: _full ? 'Crowd Heatmap' : 'Virtual Queue',
    onTab: widget.onTab,
    onBack: _full ? () => setState(() => _full = false) : null,
    action: IconButton(
      tooltip: 'Crowd heatmap help',
      icon: const Icon(Icons.help_outline, color: queueRose),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Crowd Heatmap'),
          content: const Text(
            'Queue Demand uses confirmed places in remaining return windows. Live Visitors combines recent, voluntarily shared positions. The live view does not identify individual visitors.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
    body: ParkFeed(
      attractions: widget.attractions,
      slots: widget.slots,
      clock: widget.clock,
      builder: (context, visit, reload) => _content(visit, reload),
    ),
  );

  Widget _content(ParkVisit visit, VoidCallback reload) {
    final origin = visit.place(widget.originId);
    final crowd = visit.parkCrowd;
    final compact =
        MediaQuery.sizeOf(context).width < 370 ||
        MediaQuery.textScalerOf(context).scale(12) > 17;
    final candidates = <(Attraction, AttractionSlot)>[];
    for (final place in visit.places) {
      if (!eligibleParkRide(place, widget.heightCm)) continue;
      final slot = visit.available(place).firstOrNull;
      if (slot != null) candidates.add((place, slot));
    }
    candidates.sort((a, b) {
      final aMatches = matchesParkInterest(a.$1, widget.interests);
      final bMatches = matchesParkInterest(b.$1, widget.interests);
      if (aMatches != bMatches) return aMatches ? -1 : 1;
      final crowdOrder = (visit.crowdFor(a.$1)?.index ?? 3).compareTo(
        visit.crowdFor(b.$1)?.index ?? 3,
      );
      if (crowdOrder != 0) return crowdOrder;
      if (origin != null) {
        final proximity = parkDistanceSquared(
          a.$1,
          origin,
        ).compareTo(parkDistanceSquared(b.$1, origin));
        if (proximity != 0) return proximity;
      }
      return a.$2.startsAt.compareTo(b.$2.startsAt);
    });
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 16),
      children: [
        ReservationPanel(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFF8F0E5),
                child: Icon(Icons.groups, color: crowdColor(crowd), size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Park crowd right now',
                      style: TextStyle(color: queueInk, fontSize: 12),
                    ),
                    Text(
                      crowd?.label ?? 'Not reported',
                      style: TextStyle(
                        color: crowdColor(crowd),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (visit.updatedAt case final updated?)
                      Text(
                        'Updated ${ParkTime.time(updated)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final level in AttractionCrowd.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: crowdColor(level), size: 9),
                          const SizedBox(width: 6),
                          Text(
                            level.label,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        if (!_full) ...[
          const Text(
            'Crowd Heatmap',
            style: TextStyle(
              color: queueInk,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.intelligence != null) ...[
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Queue Demand'),
                selected: !live,
                onSelected: (_) => setState(() {
                  live = false;
                  density = requestDensity();
                }),
              ),
              ChoiceChip(
                label: const Text('Live Visitors'),
                selected: live,
                onSelected: (_) => setState(() {
                  live = true;
                  density = requestDensity();
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        AspectRatio(
          aspectRatio: _full ? .78 : 1.35,
          child: FutureBuilder<Map<String, dynamic>>(
            future: density,
            builder: (context, grid) => Stack(
              children: [
                Positioned.fill(
                  child: ParkMapCanvas(
                    visit: visit,
                    visible: visit.places
                        .where((place) => place.isRide)
                        .toList(),
                    origin: origin,
                    heatmap: true,
                    density: live
                        ? (grid.data ?? {'size': 0, 'values': []})
                        : grid.data,
                    onPlace: (place) => widget.onPlace(
                      place,
                      visit.available(place).firstOrNull,
                    ),
                  ),
                ),
                if (live && grid.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator()),
                if (live &&
                    (grid.hasError ||
                        (grid.hasData && grid.data?['visitorCount'] == 0)))
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          grid.hasError
                              ? 'Live crowd information could not load. Please try again.'
                              : 'No recent visitor locations are being shared.',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (visit.slots == null)
          TextButton(
            onPressed: reload,
            child: const Text('Reload crowd information'),
          ),
        if (!_full) ...[
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: () => setState(() => _full = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: queueRose,
              side: const BorderSide(color: Color(0xFFCF949B)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            icon: const Icon(Icons.open_in_full, size: 16),
            label: const Text('Open Full Heatmap'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Recommended for You',
            style: TextStyle(
              color: queueInk,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            origin != null
                ? 'Personalised using your starting point and interests'
                : 'Personalised using your interests and available times',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (candidates.isEmpty)
            const ReservationPanel(
              child: Text('No suitable return times are available right now.'),
            )
          else
            for (final (place, slot) in candidates.take(4)) ...[
              ReservationPanel(
                padding: const EdgeInsets.all(9),
                child: InkWell(
                  onTap: () => widget.onPlace(place, slot),
                  child: Row(
                    children: [
                      AttractionCover(
                        encoded: place.coverImageBase64,
                        width: 68,
                        height: 76,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: const TextStyle(
                                color: queueInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (visit.crowdFor(place) case final level?)
                              Text(
                                '${level.label} crowd',
                                style: TextStyle(
                                  color: crowdColor(level),
                                  fontSize: 12,
                                ),
                              ),
                            if (place.ratingCount > 0 &&
                                place.ratingAverage != null)
                              Text(
                                '★ ${place.ratingAverage!.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (compact) _nextSlot(slot),
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 8),
                        SizedBox(width: 104, child: _nextSlot(slot)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }

  Widget _nextSlot(AttractionSlot slot) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Next available', style: TextStyle(fontSize: 11)),
      const SizedBox(height: 3),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: queueRose,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Wrap(
          spacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.schedule, size: 13, color: Colors.white),
            Text(
              ParkTime.time(slot.startsAt),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}
