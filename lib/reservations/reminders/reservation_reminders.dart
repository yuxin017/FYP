import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../attractions/models/park_time.dart';
import '../data/reservation_store.dart';
import '../models/reservation.dart';

/// In-app reminders only. This does not claim closed-app push delivery.
abstract final class ReservationReminderSettings {
  static final changes = StreamController<String>.broadcast();
  static String key(String uid, String id) => 'ride_reminder_${uid}_$id';
  static Future<void> save(String uid, String id, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(key(uid, id), enabled)) {
      throw StateError('Reminder preference could not be saved');
    }
    changes.add(uid);
  }
}

class ReservationReminders extends StatefulWidget {
  const ReservationReminders({
    super.key,
    required this.store,
    required this.child,
  });
  final ReservationStore store;
  final Widget child;
  @override
  State<ReservationReminders> createState() => _ReservationRemindersState();
}

class _ReservationRemindersState extends State<ReservationReminders>
    with WidgetsBindingObserver {
  StreamSubscription<List<RideReservation>>? _subscription;
  StreamSubscription<String>? _preferences;
  final _timers = <String, Timer>{};
  final _delivered = <String>{};
  List<RideReservation> _records = [];
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = widget.store.watchReservations().listen(
      (records) {
        _records = records;
        _schedule();
      },
      onError: (_) {
        _records = [];
        _clear();
      },
    );
    _preferences = ReservationReminderSettings.changes.stream.listen((uid) {
      if (uid == widget.store.uid) _schedule();
    });
  }

  void _clear() {
    _generation++;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  Future<void> _schedule() async {
    _clear();
    final generation = _generation;
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Reminder storage is optional and must not break reservation screens.
      return;
    }
    if (!mounted || generation != _generation) return;
    for (final reservation in _records) {
      final key = ReservationReminderSettings.key(
        widget.store.uid,
        reservation.id,
      );
      if (reservation.status != 'confirmed' ||
          !reservation.startsAt.isAfter(DateTime.now()) ||
          prefs.getBool(key) != true ||
          _delivered.contains(key) ||
          prefs.getBool('${key}_delivered') == true) {
        continue;
      }
      final wait = reservation.startsAt
          .subtract(const Duration(minutes: 15))
          .difference(DateTime.now());
      const maxTimerDelay = Duration(hours: 12);
      final refreshBeforeReminder = wait > maxTimerDelay;
      final delay = refreshBeforeReminder
          ? maxTimerDelay
          : wait.isNegative
          ? Duration.zero
          : wait;
      _timers[reservation.id] = Timer(delay, () async {
        if (!mounted ||
            generation != _generation ||
            !_records.any(
              (r) => r.id == reservation.id && r.status == 'confirmed',
            )) {
          return;
        }
        if (refreshBeforeReminder) {
          await _schedule();
          return;
        }
        if (!reservation.startsAt.isAfter(DateTime.now())) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(
              '${reservation.attractionName}: your return window is ${ParkTime.time(reservation.startsAt)}–${ParkTime.time(reservation.endsAt)}.',
            ),
          ),
        );
        _delivered.add(key);
        try {
          await prefs.setBool('${key}_delivered', true);
        } catch (_) {
          // Avoid repeating this reminder within the current app session.
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    _clear();
    _subscription?.cancel();
    _preferences?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
