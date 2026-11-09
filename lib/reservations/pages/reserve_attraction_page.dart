import 'dart:async';
import 'package:flutter/material.dart';
import '../../attractions/data/attraction_reader.dart';
import '../../attractions/data/slot_reader.dart';
import '../../attractions/models/attraction.dart';
import '../../attractions/models/attraction_slot.dart';
import '../../attractions/models/park_time.dart';
import '../../attractions/models/queue_policy.dart';
import '../../attractions/widgets/attraction_cover.dart';
import '../../attractions/widgets/attraction_widgets.dart';
import '../../attractions/widgets/queue_attraction_card.dart';
import '../data/reservation_store.dart';
import '../widgets/reservation_widgets.dart';
import 'select_visitor_page.dart';

class ReserveAttractionPage extends StatefulWidget {
  const ReserveAttractionPage({
    super.key,
    required this.attraction,
    required this.attractions,
    required this.slots,
    required this.reservations,
    required this.day,
    this.initialSlotId,
    this.clock,
  });
  final Attraction attraction;
  final AttractionReader attractions;
  final SlotReader slots;
  final ReservationStore reservations;
  final DateTime day;
  final String? initialSlotId;
  final DateTime Function()? clock;
  @override
  State<ReserveAttractionPage> createState() => _ReserveAttractionPageState();
}

class _ReserveAttractionPageState extends State<ReserveAttractionPage> {
  late Stream<Attraction?> _ride;
  late Stream<List<AttractionSlot>> _slots;
  late DateTime _day;
  String? _selected;
  Timer? _timer;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  void _subscribe() {
    _ride = widget.attractions.watchAttraction(widget.attraction.id);
    _slots = widget.slots.watchAttractionSlots(widget.attraction.id);
  }

  @override
  void initState() {
    super.initState();
    _day = widget.day;
    _selected = widget.initialSlotId;
    _subscribe();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _date() async {
    final today = QueuePolicy.parkDay(_now);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(today) ? today : _day,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null && mounted) {
      setState(() {
        _day = picked;
        _selected = null;
      });
    }
  }

  Widget _metric(
    IconData icon,
    String value,
    String label, {
    Color color = queueRose,
  }) => Expanded(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: Color(0xFF748089)),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<Attraction?>(
    stream: _ride,
    initialData: widget.attraction,
    builder: (context, ride) => StreamBuilder<List<AttractionSlot>>(
      stream: _slots,
      builder: (context, snapshot) {
        final attraction = ride.hasError ? null : ride.data;
        final records = snapshot.hasError
            ? <AttractionSlot>[]
            : snapshot.data ?? <AttractionSlot>[];
        final count = QueuePolicy.count(
          attractionId: widget.attraction.id,
          slots: records,
          day: _day,
          now: _now,
        );
        final offered =
            attraction == null || !snapshot.hasData || snapshot.hasError
            ? const <AttractionSlot>[]
            : QueuePolicy.returnTimes(
                attraction: attraction,
                slots: records,
                day: _day,
                now: _now,
              );
        final selected = offered
            .where((s) => s.id == _selected && s.remainingCapacity > 0)
            .firstOrNull;
        final open = attraction?.status == AttractionStatus.open;
        final ready =
            attraction != null &&
            open &&
            selected != null &&
            !snapshot.hasError;
        return ReservationFrame(
          title: attraction?.name ?? widget.attraction.name,
          action: ReservationButton(
            label: selected == null
                ? 'Choose a return time'
                : 'Continue with ${ParkTime.time(selected.startsAt)}',
            onPressed: !ready
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SelectVisitorPage(
                        attraction: attraction,
                        slot: selected,
                        store: widget.reservations,
                      ),
                    ),
                  ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              if (ride.hasError)
                AttractionMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load attraction',
                  message: attractionErrorMessage(ride.error!),
                  action: 'Try again',
                  onAction: () => setState(_subscribe),
                )
              else if (attraction == null)
                const AttractionMessage(
                  icon: Icons.search_off,
                  title: 'Attraction unavailable',
                  message:
                      'This attraction is no longer available. Choose another attraction.',
                )
              else ...[
                AspectRatio(
                  aspectRatio: 1.65,
                  child: AttractionCover(
                    encoded: attraction.coverImageBase64,
                    width: double.infinity,
                    height: 250,
                    radius: 14,
                  ),
                ),
                const SizedBox(height: 15),
                ReservationPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _metric(
                            Icons.circle,
                            attractionStatusLabel(attraction.status),
                            'Status',
                            color: open ? Colors.green.shade700 : queueRose,
                          ),
                          _metric(
                            Icons.star,
                            attraction.ratingCount > 0 &&
                                    attraction.ratingAverage != null
                                ? attraction.ratingAverage!.toStringAsFixed(1)
                                : 'Not rated',
                            'Rating',
                          ),
                          _metric(
                            Icons.height,
                            '${attraction.minHeightCm} cm+',
                            'Height Req.',
                          ),
                          _metric(
                            Icons.groups_outlined,
                            snapshot.hasData && !snapshot.hasError
                                ? QueuePolicy.crowd(count).label
                                : '—',
                            'Crowd',
                          ),
                          _metric(
                            Icons.schedule,
                            attraction.standbyMinutes == null
                                ? '—'
                                : '${attraction.standbyMinutes} min',
                            'Standby',
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFF0E6E3)),
                      ),
                      Text(
                        attraction.description?.isNotEmpty == true
                            ? attraction.description!
                            : 'Check the height requirement and available return times before reserving.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.65,
                          color: Color(0xFF59636D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                ReservationPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Virtual Queue Time Slots',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: queueInk,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _date,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(
                          reservationDayLabel(QueuePolicy.opens(_day)),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: queueInk,
                          side: const BorderSide(color: Color(0xFFF0E6E3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 5, bottom: 10),
                        child: Text(
                          'Choose a visit date covered by your admission ticket.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF59636D),
                          ),
                        ),
                      ),
                      if (snapshot.hasError)
                        AttractionMessage(
                          icon: Icons.cloud_off_outlined,
                          title: 'Could not load times',
                          message: attractionErrorMessage(snapshot.error!),
                          action: 'Try again',
                          onAction: () => setState(_subscribe),
                        )
                      else if (!snapshot.hasData)
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (offered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            open
                                ? 'No return times remain for this date. Choose another date or attraction.'
                                : 'This attraction is currently ${attractionStatusLabel(attraction.status).toLowerCase()}.',
                          ),
                        )
                      else ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final slot in offered)
                                Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: OutlinedButton(
                                    onPressed:
                                        !open || slot.remainingCapacity == 0
                                        ? null
                                        : () => setState(
                                            () => _selected = slot.id,
                                          ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _selected == slot.id
                                          ? queueRose
                                          : slot.remainingCapacity == 0
                                          ? const Color(0xFFF4F3F3)
                                          : Colors.white,
                                      foregroundColor: _selected == slot.id
                                          ? Colors.white
                                          : queueRose,
                                      side: BorderSide(
                                        color: slot.remainingCapacity == 0
                                            ? const Color(0xFFE3DFDE)
                                            : queueRose,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          ParkTime.time(slot.startsAt),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (slot.remainingCapacity == 0)
                                          const Text(
                                            'Unavailable',
                                            style: TextStyle(fontSize: 9),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '$count queuing · starts every ${QueuePolicy.intervalMinutes(count)} minutes',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF7C8188),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: queueBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF1E6E3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 17,
                              color: Color(0xFF7B858B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selected == null
                                    ? 'Choose your return time'
                                    : 'Return between  ${returnWindow(selected.startsAt, selected.endsAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selected == null
                                      ? const Color(0xFF7B858B)
                                      : queueRose,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selected != null && selected == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'The selected session changed. Choose another available time.',
                            style: TextStyle(color: queueRose, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                const ReservationPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visitor',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: queueInk,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: queueRose,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You · Individual reservation · 1 visitor',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF59636D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
