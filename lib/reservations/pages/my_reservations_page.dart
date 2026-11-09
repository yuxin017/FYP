import 'dart:async';
import 'package:flutter/material.dart';
import '../../attractions/models/park_time.dart';
import '../../attractions/widgets/queue_attraction_card.dart';
import '../data/reservation_store.dart';
import '../data/reservation_repository.dart';
import '../models/reservation.dart';
import '../widgets/reservation_widgets.dart';
import '../../visits/visit_pages.dart';
import '../../visits/visit_repository.dart';

class MyReservationsPage extends StatefulWidget {
  const MyReservationsPage({super.key, required this.store});
  final ReservationStore store;
  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage> {
  late Stream<List<RideReservation>> _stream;
  final _busy = <String>{}, _confirming = <String>{};
  final _requests = <String, String>{};
  Timer? _clock;
  String? _error;
  @override
  void initState() {
    super.initState();
    _stream = widget.store.watchReservations();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _cancel(RideReservation reservation) async {
    if (_busy.contains(reservation.id) ||
        _confirming.contains(reservation.id)) {
      return;
    }
    _confirming.add(reservation.id);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel reservation?'),
          content: Text(
            'Cancel ${reservation.attractionName} at ${ParkTime.time(reservation.startsAt)}? Your place will be released. You may reserve again if another eligible time is available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep reservation'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel reservation'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        _busy.add(reservation.id);
        _error = null;
      });
      await widget.store.cancel(
        reservationId: reservation.id,
        requestId: _requests.putIfAbsent(
          reservation.id,
          widget.store.newRequestId,
        ),
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Reservation cancelled. Your place has been released.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = reservationErrorMessage(error));
    } finally {
      _confirming.remove(reservation.id);
      if (mounted) setState(() => _busy.remove(reservation.id));
    }
  }

  @override
  Widget build(BuildContext context) => ReservationFrame(
    title: 'My Reservations',
    body: StreamBuilder<List<RideReservation>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reservationErrorMessage(snapshot.error!)),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _stream = widget.store.watchReservations(),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(_error!, style: const TextStyle(color: queueRose)),
              ),
            if (records.isEmpty)
              const ReservationPanel(
                child: Text(
                  'No reservations yet. Choose an attraction in Virtual Queue to reserve your return time.',
                ),
              ),
            for (final reservation in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ReservationPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reservation.attractionName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: queueInk,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.confirmation_number_outlined,
                            color: queueRose,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${ParkTime.date(reservation.startsAt)} · ${returnWindow(reservation.startsAt, reservation.endsAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF59636D),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttractionPassPage(
                              repository: FirebaseVisitRepository(),
                              id: reservation.id,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code),
                        label: Text(
                          reservation.status == 'checked_in'
                              ? 'View visit & points'
                              : 'View entrance pass',
                        ),
                      ),
                      Text(
                        reservation.status == 'confirmed' &&
                                !reservation.endsAt.isAfter(DateTime.now())
                            ? 'Past return window'
                            : reservation.status.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: reservation.status == 'cancelled'
                              ? Colors.grey.shade700
                              : queueRose,
                        ),
                      ),
                      if (reservation.status == 'confirmed' &&
                          reservation.endsAt.isAfter(DateTime.now()))
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy.contains(reservation.id)
                                ? null
                                : () => _cancel(reservation),
                            child: Text(
                              _busy.contains(reservation.id)
                                  ? 'Cancelling…'
                                  : 'Cancel reservation',
                            ),
                          ),
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
