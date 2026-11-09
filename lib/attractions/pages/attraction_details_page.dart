import 'package:flutter/material.dart';

import '../../visitor/widgets/visitor_ui.dart';
import '../data/attraction_reader.dart';
import '../models/attraction.dart';
import '../widgets/attraction_widgets.dart';
import '../widgets/attraction_cover.dart';
import '../data/slot_reader.dart';
import '../widgets/attraction_queue_summary.dart';

class AttractionDetailsPage extends StatefulWidget {
  const AttractionDetailsPage({
    super.key,
    required this.store,
    required this.attractionId,
    this.visitorHeightCm,
    this.slotReader,
    this.day,
    this.placeKind = ParkPlaceKind.attractions,
  });
  final AttractionReader store;
  final String attractionId;
  final int? visitorHeightCm;
  final SlotReader? slotReader;
  final DateTime? day;
  final ParkPlaceKind placeKind;

  @override
  State<AttractionDetailsPage> createState() => _AttractionDetailsPageState();
}

class _AttractionDetailsPageState extends State<AttractionDetailsPage> {
  late Stream<Attraction?> _stream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(AttractionDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.attractionId != widget.attractionId) {
      _subscribe();
    }
  }

  void _subscribe() =>
      _stream = widget.store.watchAttraction(widget.attractionId);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: visitorBackground,
    appBar: AppBar(
      title: Text(
        widget.placeKind == ParkPlaceKind.attractions
            ? 'Attraction details'
            : 'Place details',
      ),
      backgroundColor: visitorBackground,
    ),
    body: StreamBuilder<Attraction?>(
      stream: _stream,
      builder: (context, snapshot) {
        Widget child;
        if (snapshot.hasError) {
          child = AttractionMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load ${widget.placeKind.itemName}',
            message: attractionErrorMessage(snapshot.error!),
            action: 'Try again',
            onAction: () => setState(_subscribe),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          child = const Center(child: CircularProgressIndicator());
        } else if (snapshot.data == null) {
          child = AttractionMessage(
            icon: Icons.search_off,
            title: widget.placeKind == ParkPlaceKind.attractions
                ? 'Attraction not found'
                : 'Place not found',
            message:
                'This ${widget.placeKind.itemName} is no longer available. Return to the list to choose another.',
          );
        } else {
          final attraction = snapshot.data!;
          final height = widget.visitorHeightCm;
          final kind = attraction.placeKind;
          child = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECE8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    AttractionCover(
                      encoded: attraction.coverImageBase64,
                      width: double.infinity,
                      height: 220,
                      radius: 14,
                      placeholderIcon: attraction.isRide
                          ? Icons.image_outlined
                          : parkPlaceIcon(kind),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      attraction.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(attraction.category),
                    const SizedBox(height: 14),
                    AttractionStatusBadge(status: attraction.status),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (attraction.description?.isNotEmpty == true) ...[
                Text(
                  'About this ${kind.itemName}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(attraction.description!),
                const SizedBox(height: 24),
              ],
              if (attraction.isRide) ...[
                AttractionQueueSummary(
                  attractionId: attraction.id,
                  reader: widget.slotReader,
                  day: widget.day,
                ),
                const SizedBox(height: 12),
                if (attraction.standbyMinutes != null) ...[
                  Text('${attraction.standbyMinutes} min standby'),
                  const SizedBox(height: 24),
                ],
              ],
              const Text(
                'Current availability',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(switch (attraction.status) {
                AttractionStatus.open =>
                  'This ${kind.itemName} is currently open.',
                AttractionStatus.closed =>
                  'This ${kind.itemName} is currently closed.',
                AttractionStatus.maintenance =>
                  'This ${kind.itemName} is unavailable while maintenance is in progress.',
              }),
              if (attraction.isRide) ...[
                const SizedBox(height: 24),
                const Text(
                  'Height requirement',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  attraction.minHeightCm == 0
                      ? 'No minimum height is listed for this attraction.'
                      : 'Visitors must be at least ${attraction.minHeightCm} cm tall.',
                ),
                if (attraction.minHeightCm > 0) ...[
                  const SizedBox(height: 12),
                  VisitorNotice(
                    height == null
                        ? 'Add your height in Profile → Preferences & Interests to check this requirement.'
                        : height < attraction.minHeightCm
                        ? 'Your saved height is $height cm, below this attraction’s minimum height.'
                        : 'Your saved height is $height cm and meets this height requirement.',
                  ),
                ],
              ],
            ],
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [child],
            ),
          ),
        );
      },
    ),
  );
}
