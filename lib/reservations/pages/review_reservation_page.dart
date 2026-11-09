import 'package:flutter/material.dart';
import '../../attractions/models/attraction.dart';
import '../../attractions/models/attraction_slot.dart';
import '../../attractions/widgets/queue_attraction_card.dart';
import '../data/reservation_store.dart';
import '../data/reservation_repository.dart';
import '../models/reservation.dart';
import '../widgets/reservation_widgets.dart';
import '../reminders/reservation_reminders.dart';
import 'reservation_confirmation_page.dart';

class ReviewReservationPage extends StatefulWidget {
  const ReviewReservationPage({
    super.key,
    required this.attraction,
    required this.slot,
    required this.visitor,
    required this.ticket,
    required this.store,
  });
  final Attraction attraction;
  final AttractionSlot slot;
  final ReservationVisitor visitor;
  final AdmissionTicket ticket;
  final ReservationStore store;
  @override
  State<ReviewReservationPage> createState() => _ReviewReservationPageState();
}

class _ReviewReservationPageState extends State<ReviewReservationPage> {
  late final String _requestId;
  bool _saving = false, _reminder = false, _completed = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _requestId = widget.store.newRequestId();
  }

  Future<void> _confirm() async {
    if (_saving || _completed) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.store.reserve(
        slotId: widget.slot.id,
        ticketId: widget.ticket.id,
        requestId: _requestId,
      );
      String? reminderIssue;
      try {
        await ReservationReminderSettings.save(
          widget.store.uid,
          result.reservationId,
          _reminder,
        );
      } catch (_) {
        reminderIssue =
            'Your reservation was saved, but the reminder could not be saved.';
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _completed = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ReservationConfirmationPage(
                result: result,
                attraction: widget.attraction,
                slot: widget.slot,
                store: widget.store,
                notice: reminderIssue,
              ),
            ),
          );
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = reservationErrorMessage(error));
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRemind =
        widget.slot.startsAt.difference(DateTime.now()) >=
        const Duration(minutes: 15);
    return PopScope(
      canPop: !_saving,
      child: ReservationFrame(
        title: 'Review Reservation',
        action: ReservationButton(
          label: _saving ? 'Confirming…' : 'Confirm Reservation',
          busy: _saving || _completed,
          onPressed: _confirm,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            const ReservationSteps(step: 3),
            const SizedBox(height: 15),
            ReservationSummary(
              attraction: widget.attraction,
              slot: widget.slot,
              review: true,
            ),
            const SizedBox(height: 25),
            const Text(
              'Visitor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: queueInk,
              ),
            ),
            const SizedBox(height: 13),
            ReservationPanel(
              child: Row(
                children: [
                  VisitorAvatar(visitor: widget.visitor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.visitor.name} (You)',
                      style: const TextStyle(fontSize: 13, color: queueInk),
                    ),
                  ),
                  const Text(
                    '1 visitor',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7C8188)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ReservationPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_none, color: queueRose),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Text(
                          'Notify me 15 minutes before',
                          style: TextStyle(fontSize: 12, color: queueInk),
                        ),
                      ),
                      Switch(
                        value: _reminder && canRemind,
                        onChanged: _saving || !canRemind
                            ? null
                            : (value) => setState(() => _reminder = value),
                        activeThumbColor: Colors.white,
                        activeTrackColor: queueRose,
                      ),
                    ],
                  ),
                  Text(
                    canRemind
                        ? 'In-app reminder while this app is open.'
                        : 'Reminders require a return time at least 15 minutes away.',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF7C8188),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const ReservationPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: queueRose),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      'Arrive during your return window. Your place is confirmed only after the reservation is saved.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: Color(0xFF59636D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: queueRose, height: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
