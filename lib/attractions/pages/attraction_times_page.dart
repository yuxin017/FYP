import 'dart:async';
import 'package:flutter/material.dart';
import '../data/slot_reader.dart';
import '../data/attraction_reader.dart';
import '../models/attraction.dart';
import '../models/attraction_slot.dart';
import '../models/park_time.dart';
import '../models/queue_policy.dart';
import '../widgets/attraction_widgets.dart';
import '../widgets/queue_attraction_card.dart';

/// Session availability only. Admission checks/booking belong to the reservation flow.
class AttractionTimesPage extends StatefulWidget {
  const AttractionTimesPage({
    super.key,
    required this.attraction,
    required this.reader,
    required this.day,
    required this.attractions,
  });
  final Attraction attraction;
  final SlotReader reader;
  final DateTime day;
  final AttractionReader attractions;
  @override
  State<AttractionTimesPage> createState() => _AttractionTimesPageState();
}

class _AttractionTimesPageState extends State<AttractionTimesPage> {
  late Stream<List<AttractionSlot>> _stream;
  late Stream<Attraction?> _live;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _subscribe();
    _live = widget.attractions.watchAttraction(widget.attraction.id);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _subscribe() =>
      _stream = widget.reader.watchAttractionSlots(widget.attraction.id);
  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Attraction?>(
    stream: _live,
    builder: (context, ride) => Scaffold(
      backgroundColor: queueBackground,
      appBar: AppBar(
        title: const Text('Available Times'),
        backgroundColor: queueBackground,
      ),
      body: StreamBuilder<List<AttractionSlot>>(
        stream: _stream,
        builder: (context, snapshot) {
          final day = ParkTime.date(
            ParkTime.instant(
              widget.day.year,
              widget.day.month,
              widget.day.day,
              12,
              0,
            ),
          );
          final records = snapshot.hasError
              ? <AttractionSlot>[]
              : snapshot.data ?? <AttractionSlot>[];
          final count = QueuePolicy.count(
            attractionId: widget.attraction.id,
            slots: records,
            day: widget.day,
            now: DateTime.now(),
          );
          final attraction = ride.hasError ? null : ride.data;
          final slots = attraction == null
              ? const <AttractionSlot>[]
              : QueuePolicy.returnTimes(
                  attraction: attraction,
                  slots: records,
                  day: widget.day,
                  now: DateTime.now(),
                );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                ride.data?.name ?? widget.attraction.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: queueInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$day · Kuala Lumpur time',
                style: const TextStyle(color: Color(0xFF788087)),
              ),
              const SizedBox(height: 20),
              const Text('Park hours: 9:30 AM–7:30 PM'),
              if (snapshot.hasData && !snapshot.hasError)
                Text(
                  '${QueuePolicy.crowd(count).label} crowd · $count queuing · starts every ${QueuePolicy.intervalMinutes(count)} minutes',
                ),
              const SizedBox(height: 12),
              if (snapshot.hasError)
                AttractionMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load times',
                  message: attractionErrorMessage(snapshot.error!),
                  action: 'Try again',
                  onAction: () => setState(_subscribe),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (slots.isEmpty)
                const AttractionMessage(
                  icon: Icons.event_busy_outlined,
                  title: 'No return times available',
                  message:
                      'There are no upcoming sessions on this date. Choose another date or check again later.',
                )
              else
                for (final slot in slots)
                  Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: const Icon(Icons.schedule, color: queueRose),
                      title: Text(
                        '${ParkTime.time(slot.startsAt)} – ${ParkTime.time(slot.endsAt)}',
                      ),
                      subtitle: Text(
                        '${slot.remainingCapacity} of ${slot.capacity} places available',
                      ),
                      trailing: Text(
                        slot.remainingCapacity == 0
                            ? 'Full'
                            : ride.data?.status == AttractionStatus.open
                            ? 'Available'
                            : 'Ride unavailable',
                        style: TextStyle(
                          color:
                              slot.remainingCapacity > 0 &&
                                  ride.data?.status == AttractionStatus.open
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    ),
  );
}
