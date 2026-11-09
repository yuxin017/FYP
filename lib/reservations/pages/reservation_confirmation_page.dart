import 'package:flutter/material.dart';
import '../../attractions/models/attraction.dart';
import '../../attractions/models/attraction_slot.dart';
import '../../attractions/widgets/queue_attraction_card.dart';
import '../data/reservation_store.dart';
import '../data/reservation_repository.dart';
import '../models/reservation.dart';
import '../widgets/reservation_widgets.dart';
import 'my_reservations_page.dart';
import '../../visits/visit_pages.dart';
import '../../visits/visit_repository.dart';

class ReservationConfirmationPage extends StatefulWidget {
  const ReservationConfirmationPage({
    super.key,
    required this.result,
    required this.attraction,
    required this.slot,
    required this.store,
    this.notice,
  });
  final ReservationResult result;
  final Attraction attraction;
  final AttractionSlot slot;
  final ReservationStore store;
  final String? notice;
  @override
  State<ReservationConfirmationPage> createState() =>
      _ReservationConfirmationPageState();
}

class _ReservationConfirmationPageState
    extends State<ReservationConfirmationPage> {
  late Stream<List<RideReservation>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = widget.store.watchReservations();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<RideReservation>>(
    stream: _stream,
    builder: (context, snapshot) {
      final saved = snapshot.data
          ?.where((r) => r.id == widget.result.reservationId)
          .firstOrNull;
      final confirmed = saved?.status == 'confirmed';
      return ReservationFrame(
        title: confirmed ? 'Reservation Confirmed' : 'Reservation Saved',
        action: ReservationButton(
          label: 'Done',
          onPressed: () =>
              Navigator.popUntil(context, (route) => route.isFirst),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),
            Icon(
              confirmed
                  ? Icons.check_circle_outline
                  : Icons.receipt_long_outlined,
              size: 65,
              color: confirmed ? Colors.green.shade700 : queueRose,
            ),
            const SizedBox(height: 16),
            Text(
              confirmed
                  ? 'Your place is reserved'
                  : saved == null
                  ? 'Checking the saved reservation…'
                  : 'Reservation ${saved.status.replaceAll('_', ' ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: queueInk,
              ),
            ),
            const SizedBox(height: 25),
            ReservationSummary(
              attraction: widget.attraction,
              slot: widget.slot,
              review: true,
            ),
            const SizedBox(height: 18),
            Text(
              'Reservation reference: ${widget.result.reservationId.substring(0, widget.result.reservationId.length < 12 ? widget.result.reservationId.length : 12)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF7C8188)),
            ),
            if (snapshot.hasError) ...[
              const SizedBox(height: 16),
              Text(
                'The reservation was saved, but its current status could not be loaded. ${reservationErrorMessage(snapshot.error!)}',
                style: const TextStyle(color: queueRose),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _stream = widget.store.watchReservations()),
                child: const Text('Refresh status'),
              ),
            ],
            if (widget.notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  widget.notice!,
                  style: const TextStyle(color: queueRose),
                ),
              ),
            const SizedBox(height: 24),
            if (saved != null &&
                ['confirmed', 'checked_in'].contains(saved.status)) ...[
              ReservationButton(
                label: 'View Entrance Pass',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttractionPassPage(
                      repository: FirebaseVisitRepository(),
                      id: saved.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MyReservationsPage(store: widget.store),
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('My reservations'),
            ),
          ],
        ),
      );
    },
  );
}
