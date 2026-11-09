import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../attractions/models/attraction.dart';
import '../attractions/models/attraction_slot.dart';
import '../attractions/models/queue_policy.dart';
import '../attractions/models/park_time.dart';
import '../attractions/widgets/attraction_cover.dart';
import '../attractions/widgets/queue_attraction_card.dart';
import '../reservations/widgets/reservation_widgets.dart';
import '../visits/visit_pages.dart';
import '../visits/visit_repository.dart';
import 'group_repository.dart';
import 'group_pages.dart';

class GroupReservePage extends StatefulWidget {
  final GroupRepository repository;
  final GroupRecord group;
  const GroupReservePage({
    super.key,
    required this.repository,
    required this.group,
  });
  @override
  State<GroupReservePage> createState() => _GroupReservePageState();
}

class _GroupReservePageState extends State<GroupReservePage> {
  late final rides = widget.repository.attractions(),
      people = widget.repository.members(widget.group.id);
  Stream<List<AttractionSlot>>? slots;
  Attraction? ride;
  String? selected;
  final memberIds = <String>{};
  bool initialised = false;
  @override
  Widget build(BuildContext context) => GroupFrame(
    title: 'Reserve for Your Group',
    body: StreamBuilder<List<GroupRecord>>(
      stream: people,
      builder: (context, members) {
        if (members.hasError) {
          return const Center(
            child: Text('Unable to load members. Please return to the group.'),
          );
        }
        if (!members.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = members.data!;
        if (!initialised) {
          memberIds.addAll(list.map((m) => m.data['memberId'] as String));
          initialised = true;
        }
        final chosen = list
            .where((m) => memberIds.contains(m.data['memberId']))
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ReservationPanel(
              child: Row(
                children: [
                  const Icon(Icons.groups_outlined, size: 42, color: queueRose),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text('Visit date: ${widget.group.visitDate}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 23),
            const Text(
              'Who is riding?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ReservationPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final member in list)
                    CheckboxListTile(
                      value: memberIds.contains(member.data['memberId']),
                      onChanged: (value) => setState(() {
                        selected = null;
                        if (value == true) {
                          memberIds.add(member.data['memberId'] as String);
                        } else {
                          memberIds.remove(member.data['memberId']);
                        }
                      }),
                      secondary: MemberAvatar(member: member),
                      title: Text(
                        member.data['displayName'] as String? ?? 'Guest',
                      ),
                      subtitle: Text(
                        member.data['ticketId'] == null
                            ? 'Ticket needs linking'
                            : 'Ticket linked',
                        style: TextStyle(
                          color: member.data['ticketId'] == null
                              ? queueRose
                              : Colors.green.shade700,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 23),
            const Text(
              'Choose an attraction',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Attraction>>(
              stream: rides,
              builder: (context, s) {
                if (s.hasError) {
                  return const Text('Unable to load attractions.');
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final options = s.data!
                    .where((r) => r.isRide && r.status == AttractionStatus.open)
                    .toList();
                return Column(
                  children: [
                    if (options.isEmpty)
                      const ReservationPanel(
                        child: Text(
                          'No attractions are currently available for reservation.',
                        ),
                      ),
                    for (final attraction in options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReservationPanel(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            selected: ride?.id == attraction.id,
                            trailing: Icon(
                              ride?.id == attraction.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: queueRose,
                            ),
                            onTap: () => setState(() {
                              ride = attraction;
                              slots = widget.repository.slots(attraction.id);
                              selected = null;
                            }),
                            leading: AttractionCover(
                              encoded: attraction.coverImageBase64,
                              width: 65,
                              height: 70,
                            ),
                            title: Text(
                              attraction.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Minimum height ${attraction.minHeightCm} cm',
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (ride != null && slots != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Return time for the whole group',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<AttractionSlot>>(
                stream: slots,
                builder: (context, s) {
                  if (s.hasError) {
                    return const Text('Unable to load current return times.');
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final day = DateTime.parse(widget.group.visitDate),
                      options = QueuePolicy.returnTimes(
                        attraction: ride!,
                        slots: s.data!,
                        day: day,
                        now: DateTime.now(),
                      );
                  final fitting = options
                      .where(
                        (s) =>
                            s.remainingCapacity >= chosen.length &&
                            chosen.isNotEmpty,
                      )
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (fitting.isEmpty)
                        const ReservationPanel(
                          child: Text(
                            'No return time currently has enough places for the selected members. Choose fewer members or another attraction.',
                          ),
                        ),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          for (final window in fitting)
                            ChoiceChip(
                              label: Text(
                                '${ParkTime.time(window.startsAt)}\n${window.remainingCapacity} places',
                              ),
                              selected: selected == window.id,
                              onSelected: (_) =>
                                  setState(() => selected = window.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ReservationButton(
                        label: 'Review Group Reservation',
                        onPressed:
                            selected == null ||
                                chosen.isEmpty ||
                                chosen.any((m) => m.data['ticketId'] == null)
                            ? null
                            : () {
                                final window = fitting
                                    .where((s) => s.id == selected)
                                    .firstOrNull;
                                if (window != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GroupReservationReviewPage(
                                            repository: widget.repository,
                                            group: widget.group,
                                            attraction: ride!,
                                            slot: window,
                                            members: chosen,
                                          ),
                                    ),
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Every selected guest must have a linked ticket and meet the ride’s height requirement. All places are confirmed together.',
                        style: TextStyle(
                          color: Color(0xFF6D737A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    ),
  );
}

class GroupReservationReviewPage extends StatefulWidget {
  final GroupRepository repository;
  final GroupRecord group;
  final Attraction attraction;
  final AttractionSlot slot;
  final List<GroupRecord> members;
  const GroupReservationReviewPage({
    super.key,
    required this.repository,
    required this.group,
    required this.attraction,
    required this.slot,
    required this.members,
  });
  @override
  State<GroupReservationReviewPage> createState() =>
      _GroupReservationReviewPageState();
}

class _GroupReservationReviewPageState
    extends State<GroupReservationReviewPage> {
  late final requestId = widget.repository.newRequestId();
  bool busy = false, accepted = false;
  String? error;
  Future<void> confirm() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.request('reserve', {
        'groupId': widget.group.id,
        'slotId': widget.slot.id,
        'memberIds': widget.members.map((m) => m.data['memberId']).toList(),
        'requestId': requestId,
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GroupBookingPassPage(
              repository: widget.repository,
              booking: GroupRecord(result['bookingId'] as String, {
                'attractionName': widget.attraction.name,
                'groupId': widget.group.id,
                'startsAt': Timestamp.fromDate(widget.slot.startsAt),
                'endsAt': Timestamp.fromDate(widget.slot.endsAt),
              }),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GroupFrame(
    title: 'Review Group Reservation',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ReservationPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AttractionCover(
                encoded: widget.attraction.coverImageBase64,
                width: double.infinity,
                height: 200,
                radius: 12,
              ),
              const SizedBox(height: 18),
              Text(
                widget.attraction.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: queueInk,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                '${widget.group.visitDate}\n${returnWindow(widget.slot.startsAt, widget.slot.endsAt)}',
                style: const TextStyle(height: 1.8, fontSize: 16),
              ),
              const Divider(height: 30),
              Text(
                widget.group.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.members.length} guests • Admission tickets linked',
              ),
              const SizedBox(height: 15),
              for (final member in widget.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: MemberAvatar(member: member),
                  title: Text(member.data['displayName'] as String? ?? 'Guest'),
                  trailing: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ReservationPanel(
          child: Column(
            children: [
              const Text(
                'Arrive together during your return window. Keep each guest’s entrance pass available. Staff confirm entry at the attraction.',
                style: TextStyle(height: 1.6),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: accepted,
                onChanged: busy
                    ? null
                    : (v) => setState(() => accepted = v ?? false),
                title: const Text(
                  'I have checked the guests, tickets and return time.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(error!, style: const TextStyle(color: queueRose)),
          ),
        ReservationButton(
          label: 'Confirm Group Reservation',
          onPressed: accepted ? confirm : null,
          busy: busy,
        ),
      ],
    ),
  );
}

class GroupBookingPassPage extends StatefulWidget {
  final GroupRepository repository;
  final GroupRecord booking;
  const GroupBookingPassPage({
    super.key,
    required this.repository,
    required this.booking,
  });
  @override
  State<GroupBookingPassPage> createState() => _GroupBookingPassPageState();
}

class _GroupBookingPassPageState extends State<GroupBookingPassPage> {
  late final stream = widget.repository.passes(
    widget.booking.id,
    widget.booking.data['groupId'] as String,
  );
  @override
  Widget build(BuildContext context) => GroupFrame(
    title: 'Group Entrance Passes',
    body: StreamBuilder<List<AttractionVisit>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load group passes. Please return to the group and try again.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Icon(Icons.check_circle_outline, size: 70, color: queueRose),
            const SizedBox(height: 18),
            const Text(
              'Your group’s adventure',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: queueInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.booking.data['attractionName'] as String? ?? 'Attraction',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21),
            ),
            const SizedBox(height: 15),
            const Text(
              'Choose a pass holder and show their QR at the attraction entrance. Each guest is checked in once.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6D737A), height: 1.6),
            ),
            const SizedBox(height: 25),
            for (final visit in snapshot.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ReservationPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEEDDD8),
                          child: Icon(Icons.person_outline, color: queueRose),
                        ),
                        title: Text(
                          visit.data['guestName'] as String? ?? 'Guest',
                        ),
                        subtitle: Text(visit.stateAt(DateTime.now())),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttractionPassPage(
                              repository: widget.repository.visitRepository,
                              id: visit.id,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Open Entrance Pass'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
