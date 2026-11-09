import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../data/attraction_reader.dart';
import '../data/slot_reader.dart';
import '../models/attraction.dart';
import '../models/attraction_slot.dart';
import '../models/park_time.dart';
import '../models/queue_policy.dart';
import '../widgets/attraction_widgets.dart';
import '../widgets/queue_attraction_card.dart';
import 'attraction_details_page.dart';
import 'attraction_times_page.dart';
import '../../reservations/data/reservation_store.dart';
import '../../reservations/pages/reserve_attraction_page.dart';
import '../../reservations/pages/my_reservations_page.dart';

/// Customer Virtual Queue, matching Figma frame 122:131. Records are never seeded
/// or substituted by this view. Reservation/planner callbacks are separate flows.
class AttractionsPage extends StatefulWidget {
  const AttractionsPage({
    super.key,
    required this.store,
    this.slotReader,
    this.visitorHeightCm,
    this.parkInterests = const [],
    this.notice,
    this.onPlan,
    this.onHeatmap,
    this.onGroups,
    this.clock,
    this.reservations,
  });
  final AttractionReader store;
  final SlotReader? slotReader;
  final int? visitorHeightCm;
  final List<String> parkInterests;
  final String? notice;
  final VoidCallback? onPlan;
  final VoidCallback? onHeatmap;
  final VoidCallback? onGroups;
  final DateTime Function()? clock;
  final ReservationStore? reservations;
  @override
  State<AttractionsPage> createState() => _AttractionsPageState();
}

class _AttractionsPageState extends State<AttractionsPage> {
  late Stream<List<Attraction>> _stream;
  late Stream<List<AttractionSlot>> _slots;
  final _search = TextEditingController();
  String _filter = 'Recommended';
  Attraction? _origin;
  late DateTime _day;
  Timer? _clock;
  DateTime? _lastSlotUpdate;
  bool _followToday = true;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    final date = ParkTime.local(_now);
    _day = DateTime(date.year, date.month, date.day);
    _subscribe();
    _subscribeSlots();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          final today = QueuePolicy.parkDay(_now);
          if (_followToday && _day != today) {
            _day = today;
            _subscribeSlots();
          }
        });
      }
    });
  }

  void _subscribe() => _stream = widget.store.watchAttractions();
  void _subscribeSlots() {
    final start = ParkTime.instant(_day.year, _day.month, _day.day, 0, 0);
    _lastSlotUpdate = null;
    _slots =
        widget.slotReader
            ?.watchUpcomingSlots(from: start, until: ParkTime.dayEnd(start))
            .map((slots) {
              _lastSlotUpdate = _now;
              return slots;
            }) ??
        Stream.value(const []);
  }

  @override
  void didUpdateWidget(AttractionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) _subscribe();
    if (oldWidget.slotReader != widget.slotReader) _subscribeSlots();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {
    _subscribe();
    _subscribeSlots();
  });
  void _clearFilters() => setState(() {
    _search.clear();
    _filter = 'All';
  });

  void _openBooking(Attraction attraction) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReserveAttractionPage(
        attraction: attraction,
        attractions: widget.store,
        slots: widget.slotReader!,
        reservations: widget.reservations!,
        day: _day,
      ),
    ),
  );

  Future<void> _chooseDate() async {
    final now = ParkTime.local(_now);
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(today) ? today : _day,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Choose your park visit date',
    );
    if (date != null && mounted) {
      setState(() {
        _day = date;
        _followToday = _day == today;
        _subscribeSlots();
      });
    }
  }

  Future<void> _chooseOrigin(List<Attraction> attractions) async {
    final origin = await showModalBottomSheet<Attraction>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: math.min(480, MediaQuery.sizeOf(context).height * .7),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Where are you in the park?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Choose your starting attraction to sort nearby places.',
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final attraction in attractions)
                      ListTile(
                        leading: const Icon(
                          Icons.place_outlined,
                          color: queueRose,
                        ),
                        title: Text(attraction.name),
                        onTap: () => Navigator.pop(context, attraction),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (origin != null && mounted) {
      setState(() {
        _origin = origin;
        _filter = 'Nearby';
      });
    }
  }

  Widget _headerAction(IconData icon, String tooltip, VoidCallback? action) =>
      SizedBox(
        width: 38,
        height: 36,
        child: IconButton.outlined(
          onPressed: action,
          tooltip: tooltip,
          icon: Icon(icon, size: 22),
          style: IconButton.styleFrom(
            foregroundColor: queueRose,
            side: const BorderSide(color: Color(0xFFCB7D85)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      );
  String _updated(bool ready) {
    if (!ready || _lastSlotUpdate == null) return 'Queue count unavailable';
    final minutes = _now.difference(_lastSlotUpdate!).inMinutes;
    return minutes < 1
        ? 'Updated just now'
        : minutes < 60
        ? 'Updated $minutes min ago'
        : 'Updated ${ParkTime.date(_lastSlotUpdate!)}';
  }

  Widget _crowd(
    List<Attraction> attractions,
    List<AttractionSlot> slots,
    bool ready,
  ) {
    final count = attractions.fold(
      0,
      (sum, a) =>
          sum +
          QueuePolicy.count(
            attractionId: a.id,
            slots: slots,
            day: _day,
            now: _now,
          ),
    );
    final crowd = ready ? QueuePolicy.crowd(count) : null;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3E9E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFFFF5E9),
            child: Icon(
              Icons.groups_rounded,
              color: crowdColor(crowd),
              size: 25,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message:
                      'Total confirmed places in attraction queues for the selected park date. Cancelled, checked-in and expired places do not count.',
                  child: Wrap(
                    spacing: 3,
                    children: [
                      const Text(
                        'Park crowd:',
                        style: TextStyle(fontSize: 12, color: queueInk),
                      ),
                      Text(
                        crowd?.label ?? 'Not reported',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: crowdColor(crowd),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 12,
                      color: Color(0xFF7F8487),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _updated(ready),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF71797D),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.textScalerOf(context).scale(10) > 12
                  ? 100
                  : 110,
            ),
            child: OutlinedButton.icon(
              onPressed: widget.onHeatmap,
              icon: const Icon(Icons.bar_chart, size: 15),
              label: const Text('View Heatmap'),
              style: OutlinedButton.styleFrom(
                foregroundColor: queueRose,
                side: const BorderSide(color: Color(0xFFCC8087)),
                textStyle: const TextStyle(fontSize: 10, fontFamily: 'Roboto'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: queueBackground,
    child: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: StreamBuilder<List<Attraction>>(
            stream: _stream,
            builder: (context, snapshot) => StreamBuilder<List<AttractionSlot>>(
              stream: _slots,
              builder: (context, slotSnapshot) {
                final all = snapshot.hasError
                    ? <Attraction>[]
                    : (snapshot.data ?? const <Attraction>[])
                          .where((place) => place.isRide)
                          .toList();
                final slots = slotSnapshot.hasError
                    ? <AttractionSlot>[]
                    : slotSnapshot.data ?? <AttractionSlot>[];
                final now = _now.toUtc();
                final queueReady =
                    widget.slotReader != null &&
                    slotSnapshot.hasData &&
                    slotSnapshot.connectionState != ConnectionState.waiting &&
                    !slotSnapshot.hasError;
                final nextSlots = <String, AttractionSlot?>{};
                AttractionSlot? next(Attraction attraction) => !queueReady
                    ? null
                    : nextSlots.putIfAbsent(attraction.id, () {
                        final future = QueuePolicy.returnTimes(
                          attraction: attraction,
                          slots: slots,
                          day: _day,
                          now: now,
                        );
                        return future
                                .where((slot) => slot.remainingCapacity > 0)
                                .firstOrNull ??
                            future.firstOrNull;
                      });

                final query = _search.text.trim().toLowerCase();
                final interests = widget.parkInterests
                    .map((value) => value.toLowerCase())
                    .toSet();
                final visible = all.where((a) {
                  if (!a.name.toLowerCase().contains(query)) return false;
                  if (_filter == 'Recommended') {
                    return a.status == AttractionStatus.open &&
                        (widget.visitorHeightCm == null ||
                            widget.visitorHeightCm! >= a.minHeightCm);
                  }
                  if (_filter == 'Available Now') {
                    return a.status == AttractionStatus.open &&
                        (next(a)?.remainingCapacity ?? 0) > 0;
                  }
                  return true;
                }).toList();
                if (_filter == 'Nearby' && _origin != null) {
                  visible.sort((a, b) {
                    double distance(Attraction a) =>
                        math.pow(a.mapX - _origin!.mapX, 2).toDouble() +
                        math.pow(a.mapY - _origin!.mapY, 2).toDouble();
                    return distance(a).compareTo(distance(b));
                  });
                }
                if (_filter == 'Recommended') {
                  visible.sort((a, b) {
                    final aMatch = interests.contains(a.category.toLowerCase())
                        ? 0
                        : 1;
                    final bMatch = interests.contains(b.category.toLowerCase())
                        ? 0
                        : 1;
                    final preference = aMatch.compareTo(bMatch);
                    return preference != 0
                        ? preference
                        : (a.standbyMinutes ?? 601).compareTo(
                            b.standbyMinutes ?? 601,
                          );
                  });
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Virtual Queue',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: queueInk,
                            ),
                          ),
                        ),
                        _headerAction(
                          Icons.groups_outlined,
                          'My Groups',
                          widget.onGroups,
                        ),
                        const SizedBox(width: 10),
                        _headerAction(
                          Icons.route_outlined,
                          'Plan your visit',
                          widget.onPlan,
                        ),
                        const SizedBox(width: 10),
                        _headerAction(
                          Icons.calendar_month_outlined,
                          'Choose visit date',
                          _chooseDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _crowd(all, slots, queueReady),
                    if (widget.reservations != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MyReservationsPage(
                                store: widget.reservations!,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                          ),
                          label: const Text('My reservations'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Available Attractions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: queueInk,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _refresh,
                          tooltip: 'Refresh attractions',
                          icon: const Icon(
                            Icons.refresh,
                            size: 18,
                            color: queueRose,
                          ),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    if (widget.notice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          widget.notice!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF785F59),
                          ),
                        ),
                      ),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search attractions',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: Color(0xFF9A9CA0),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFEEDDD9),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFEEDDD9),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 8,
                        runSpacing: 7,
                        children: [
                          for (final label in [
                            'Recommended',
                            'Available Now',
                            'Nearby',
                            'All',
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _filter == label,
                              showCheckmark: false,
                              selectedColor: queueRose,
                              backgroundColor: queueBackground,
                              padding: EdgeInsets.zero,
                              labelPadding: EdgeInsets.symmetric(
                                horizontal: constraints.maxWidth < 350 ? 8 : 12,
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: _filter == label
                                    ? Colors.white
                                    : queueRose,
                              ),
                              side: const BorderSide(color: Color(0xFFBF6B77)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onSelected: (_) => label == 'Nearby'
                                  ? _chooseOrigin(all)
                                  : setState(() => _filter = label),
                            ),
                        ],
                      ),
                    ),
                    if (_filter == 'Nearby' && _origin != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Starting at ${_origin!.name}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7E7472),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (snapshot.hasError)
                      AttractionMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load attractions',
                        message: attractionErrorMessage(snapshot.error!),
                        action: 'Try again',
                        onAction: _refresh,
                      )
                    else if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (all.isEmpty)
                      const AttractionMessage(
                        icon: Icons.attractions_outlined,
                        title: 'No attractions available',
                        message:
                            'There are no attractions to display yet. Please check again later.',
                      )
                    else if (visible.isEmpty)
                      AttractionMessage(
                        icon: Icons.search_off,
                        title: 'No matching attractions',
                        message:
                            'Try another search or choose All to see every attraction.',
                        action: 'Clear filters',
                        onAction: _clearFilters,
                      )
                    else
                      for (final attraction in visible)
                        QueueAttractionCard(
                          key: ValueKey(attraction.id),
                          attraction: attraction,
                          reservable: widget.reservations != null,
                          queueCount: queueReady
                              ? QueuePolicy.count(
                                  attractionId: attraction.id,
                                  slots: slots,
                                  day: _day,
                                  now: now,
                                )
                              : null,
                          nextSlot: next(attraction),
                          timesLoading:
                              widget.slotReader != null &&
                              slotSnapshot.connectionState ==
                                  ConnectionState.waiting,
                          timesUnavailable: slotSnapshot.hasError,
                          onDetails: () =>
                              widget.reservations != null &&
                                  widget.slotReader != null
                              ? _openBooking(attraction)
                              : Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AttractionDetailsPage(
                                      store: widget.store,
                                      attractionId: attraction.id,
                                      visitorHeightCm: widget.visitorHeightCm,
                                      slotReader: widget.slotReader,
                                      day: _day,
                                    ),
                                  ),
                                ),
                          onTimes: () =>
                              widget.reservations != null &&
                                  widget.slotReader != null
                              ? _openBooking(attraction)
                              : widget.slotReader == null
                              ? Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AttractionDetailsPage(
                                      store: widget.store,
                                      attractionId: attraction.id,
                                      visitorHeightCm: widget.visitorHeightCm,
                                      slotReader: widget.slotReader,
                                      day: _day,
                                    ),
                                  ),
                                )
                              : Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AttractionTimesPage(
                                      attraction: attraction,
                                      reader: widget.slotReader!,
                                      day: _day,
                                      attractions: widget.store,
                                    ),
                                  ),
                                ),
                        ),
                    if (slotSnapshot.hasError)
                      TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry session availability'),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF0E3E0)),
                      ),
                      child: ListTile(
                        dense: true,
                        onTap: widget.onPlan,
                        enabled: widget.onPlan != null,
                        leading: const CircleAvatar(
                          radius: 19,
                          backgroundColor: Color(0xFFFFF0ED),
                          child: Icon(
                            Icons.auto_awesome_outlined,
                            color: queueRose,
                            size: 22,
                          ),
                        ),
                        title: const Text(
                          'Need a plan?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: queueInk,
                          ),
                        ),
                        subtitle: const Text(
                          'View your personalised itinerary',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF77777C),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
