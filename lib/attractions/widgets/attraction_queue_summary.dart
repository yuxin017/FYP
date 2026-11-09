import 'dart:async';
import 'package:flutter/material.dart';
import '../data/slot_reader.dart';
import '../models/attraction_slot.dart';
import '../models/queue_policy.dart';
import 'queue_attraction_card.dart';

/// Read-only queue projection. No reservation creation or client count writes.
class AttractionQueueSummary extends StatefulWidget {
  const AttractionQueueSummary({
    super.key,
    required this.attractionId,
    this.reader,
    this.day,
  });
  final String attractionId;
  final SlotReader? reader;
  final DateTime? day;
  @override
  State<AttractionQueueSummary> createState() => _AttractionQueueSummaryState();
}

class _AttractionQueueSummaryState extends State<AttractionQueueSummary> {
  Stream<List<AttractionSlot>>? _stream;
  Timer? _timer;
  void _subscribe() =>
      _stream = widget.reader?.watchAttractionSlots(widget.attractionId);
  @override
  void initState() {
    super.initState();
    _subscribe();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(AttractionQueueSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader ||
        oldWidget.attractionId != widget.attractionId) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AttractionSlot>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: () => setState(_subscribe),
          icon: const Icon(Icons.refresh),
          label: const Text('Queue unavailable · Retry'),
        );
      }
      if (!snapshot.hasData) {
        return const Text(
          'Crowd and booking intervals are calculated from confirmed reservations.',
        );
      }
      final now = DateTime.now();
      final count = QueuePolicy.count(
        attractionId: widget.attractionId,
        slots: snapshot.data!,
        day: widget.day ?? QueuePolicy.parkDay(now),
        now: now,
      );
      final crowd = QueuePolicy.crowd(count);
      return Text(
        '${crowd.label} crowd · $count queuing\nBooking starts every ${QueuePolicy.intervalMinutes(count)} minutes · Park hours 9:30 AM–7:30 PM',
        style: TextStyle(color: crowdColor(crowd), height: 1.6),
      );
    },
  );
}
