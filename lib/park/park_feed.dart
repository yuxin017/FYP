import 'dart:async';

import 'package:flutter/material.dart';

import '../attractions/data/attraction_reader.dart';
import '../attractions/data/slot_reader.dart';
import '../attractions/models/attraction.dart';
import '../attractions/models/attraction_slot.dart';
import '../attractions/models/park_time.dart';
import '../attractions/models/queue_policy.dart';
import '../attractions/widgets/attraction_widgets.dart';
import 'park_visit.dart';

class ParkFeed extends StatefulWidget {
  const ParkFeed({
    super.key,
    required this.attractions,
    required this.slots,
    required this.builder,
    this.clock,
  });

  final AttractionReader attractions;
  final SlotReader slots;
  final Widget Function(
    BuildContext context,
    ParkVisit visit,
    VoidCallback reload,
  )
  builder;
  final DateTime Function()? clock;

  @override
  State<ParkFeed> createState() => _ParkFeedState();
}

class _ParkFeedState extends State<ParkFeed> {
  late Stream<List<Attraction>> _places;
  late Stream<List<AttractionSlot>> _slots;
  late DateTime _day;
  late final Timer _timer;
  DateTime? _updatedAt;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _subscribe();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        if (QueuePolicy.parkDay(_now) != _day) _subscribeSlots();
      });
    });
  }

  void _subscribe() {
    _places = widget.attractions.watchAttractions();
    _subscribeSlots();
  }

  void _subscribeSlots() {
    _day = QueuePolicy.parkDay(_now);
    _updatedAt = null;
    final midnight = ParkTime.instant(_day.year, _day.month, _day.day, 0, 0);
    _slots = widget.slots
        .watchUpcomingSlots(from: midnight, until: ParkTime.dayEnd(midnight))
        .map((slots) {
          _updatedAt = _now;
          return slots;
        });
  }

  void _reload() => setState(_subscribe);

  @override
  void didUpdateWidget(ParkFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attractions != widget.attractions ||
        oldWidget.slots != widget.slots ||
        oldWidget.clock != widget.clock) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Attraction>>(
    key: ValueKey(_places),
    stream: _places,
    builder: (context, places) {
      if (places.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AttractionMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load the park',
              message: attractionErrorMessage(places.error!),
              action: 'Try again',
              onAction: _reload,
            ),
          ),
        );
      }
      if (!places.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return StreamBuilder<List<AttractionSlot>>(
        key: ValueKey(_slots),
        stream: _slots,
        builder: (context, slots) => widget.builder(
          context,
          ParkVisit(
            places: places.data!,
            slots: slots.hasError ? null : slots.data,
            now: _now,
            updatedAt: slots.hasError ? null : _updatedAt,
          ),
          _reload,
        ),
      );
    },
  );
}
