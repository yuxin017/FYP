import 'package:flutter/material.dart';
import '../../attractions/models/attraction.dart';
import '../../attractions/models/attraction_slot.dart';
import '../../attractions/models/park_time.dart';
import '../../attractions/widgets/queue_attraction_card.dart';
import '../data/reservation_store.dart';
import '../data/reservation_repository.dart';
import '../models/reservation.dart';
import '../widgets/reservation_widgets.dart';
import 'review_reservation_page.dart';

class SelectVisitorPage extends StatefulWidget {
  const SelectVisitorPage({
    super.key,
    required this.attraction,
    required this.slot,
    required this.store,
  });
  final Attraction attraction;
  final AttractionSlot slot;
  final ReservationStore store;
  @override
  State<SelectVisitorPage> createState() => _SelectVisitorPageState();
}

class _SelectVisitorPageState extends State<SelectVisitorPage> {
  late Stream<ReservationVisitor?> _visitor;
  late Stream<List<AdmissionTicket>> _tickets;
  String? _ticket;
  void _subscribe() {
    _visitor = widget.store.watchVisitor();
    _tickets = widget.store.watchAdmissionTickets();
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ReservationVisitor?>(
    stream: _visitor,
    builder: (context, profile) => StreamBuilder<List<AdmissionTicket>>(
      stream: _tickets,
      builder: (context, snapshot) {
        final visitor = profile.hasError ? null : profile.data;
        final valid = snapshot.hasError
            ? <AdmissionTicket>[]
            : (snapshot.data ?? <AdmissionTicket>[])
                  .where((t) => t.covers(ParkTime.date(widget.slot.startsAt)))
                  .toList();
        final ticket = _ticket == null
            ? valid.firstOrNull
            : valid.where((t) => t.id == _ticket).firstOrNull;
        final heightEligible =
            widget.attraction.minHeightCm == 0 ||
            (visitor?.heightCm ?? 0) >= widget.attraction.minHeightCm;
        final eligible = visitor != null && heightEligible && ticket != null;
        return ReservationFrame(
          title: 'Select Visitor',
          action: ReservationButton(
            label: 'Review Reservation',
            onPressed: !eligible
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ReviewReservationPage(
                        attraction: widget.attraction,
                        slot: widget.slot,
                        visitor: visitor,
                        ticket: ticket,
                        store: widget.store,
                      ),
                    ),
                  ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              const ReservationSteps(step: 2),
              const SizedBox(height: 15),
              ReservationSummary(
                attraction: widget.attraction,
                slot: widget.slot,
              ),
              const SizedBox(height: 22),
              const Text(
                'Select Visitor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: queueInk,
                ),
              ),
              const SizedBox(height: 12),
              if (profile.hasError || snapshot.hasError)
                ReservationPanel(
                  child: Column(
                    children: [
                      Text(
                        reservationErrorMessage(
                          profile.error ?? snapshot.error!,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(_subscribe),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              else if (!profile.hasData &&
                      profile.connectionState == ConnectionState.waiting ||
                  !snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(25),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (visitor == null)
                const ReservationPanel(
                  child: Text(
                    'Complete your visitor profile before reserving an attraction.',
                  ),
                )
              else ...[
                ReservationPanel(
                  child: Row(
                    children: [
                      Checkbox(
                        value: eligible,
                        onChanged: null,
                        fillColor: WidgetStatePropertyAll(
                          eligible ? queueRose : Colors.grey.shade300,
                        ),
                      ),
                      VisitorAvatar(visitor: visitor),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${visitor.name} (You)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: queueInk,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              visitor.heightCm == null
                                  ? 'Height not set'
                                  : '${visitor.heightCm} cm',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7C8188),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              ticket == null
                                  ? 'Ticket required'
                                  : ticket.status == 'used'
                                  ? 'Admission used'
                                  : 'Ticket valid',
                              style: TextStyle(
                                fontSize: 11,
                                color: ticket == null
                                    ? queueRose
                                    : Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              eligible
                                  ? 'Eligible'
                                  : !heightEligible
                                  ? 'Height requirement'
                                  : 'Not eligible',
                              style: TextStyle(
                                fontSize: 11,
                                color: eligible
                                    ? Colors.green.shade700
                                    : queueRose,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (valid.isEmpty)
                  const ReservationPanel(
                    child: Text(
                      'No eligible admission ticket is available in your account for this visit date. Add or purchase admission before reserving.',
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: ticket?.id,
                    key: ValueKey(ticket?.id),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Your admission ticket',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final item in valid)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            '${item.label} · ${item.id.substring(0, item.id.length < 8 ? item.id.length : 8)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _ticket = value),
                  ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 17,
                      color: Color(0xFF7C8188),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        heightEligible
                            ? 'Your profile meets the ${widget.attraction.minHeightCm} cm minimum height.'
                            : 'This attraction requires at least ${widget.attraction.minHeightCm} cm. Check your saved profile height.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C8188),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              ReservationPanel(
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, color: queueRose),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        eligible
                            ? '1 visitor selected'
                            : 'Select an eligible admission ticket',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: queueInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
