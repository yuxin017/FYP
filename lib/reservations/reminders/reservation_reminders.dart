import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../attractions/models/park_time.dart';
import '../data/reservation_store.dart';
import '../models/reservation.dart';
import '../pages/my_reservations_page.dart';
import 'reminder_delivery.dart';

abstract final class ReservationReminderSettings {
  static final changes = StreamController<String>.broadcast();
  static final synchronizers = <String, Future<void> Function()>{};
  static final deliveryError = ValueNotifier<String?>(null);
  static Future<void> refresh(String uid) async => synchronizers[uid]?.call();
  static String key(String uid, String id) => 'ride_reminder_${uid}_$id';
  static Future<void> save(String uid, String id, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(key(uid, id), enabled)) {
      throw StateError('Reminder preference could not be saved');
    }
    await refresh(uid);
    changes.add(uid);
  }
}

class ReservationReminders extends StatefulWidget {
  const ReservationReminders({
    super.key,
    required this.store,
    required this.child,
    this.device,
  });
  final ReservationStore store;
  final Widget child;
  final ReminderDevice? device;
  @override
  State<ReservationReminders> createState() => _ReservationRemindersState();
}

class _ReservationRemindersState extends State<ReservationReminders>
    with WidgetsBindingObserver {
  StreamSubscription<List<RideReservation>>? _subscription;
  StreamSubscription<String>? _openings;
  late final device = widget.device ?? reservationReminderDevice;
  late final Future<void> Function() refresh = _refresh;
  Future<void> _work = Future.value();
  String? _opening;
  final _timers = <String, Timer>{};
  final _delivered = <String>{};
  List<RideReservation> _records = [];
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReservationReminderSettings.deliveryError.value = null;
    ReservationReminderSettings.synchronizers[widget.store.uid] = refresh;
    _opening = device.takeInitialOpening();
    _openings = device.openings.listen((id) {
      _opening = id;
      _openReservation();
    });
    _subscription = widget.store.watchReservations().listen(
      (records) {
        _records = records;
        _refresh().catchError(_deliveryFailed);
        _openReservation();
      },
      onError: (_) {
        _records = [];
        _refresh().catchError(_deliveryFailed);
      },
    );
  }

  void _deliveryFailed(Object _) {
    if (mounted) {
      ReservationReminderSettings.deliveryError.value =
          'A reminder could not be synchronized. Reopen Notifications when your connection is available.';
    }
  }

  Future<void> _refresh() {
    final next = _work.catchError((Object _) {}).then((_) => _schedule());
    _work = next;
    return next;
  }

  void _openReservation() {
    if (!mounted ||
        _opening == null ||
        !_records.any((r) => r.id == _opening)) {
      return;
    }
    _opening = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MyReservationsPage(store: widget.store),
          ),
        );
      }
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
    if (!mounted) return;
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
    final enabled = {
      for (final r in _records)
        if (prefs.getBool(
              ReservationReminderSettings.key(widget.store.uid, r.id),
            ) ==
            true)
          r.id,
    };
    final state = await device.status(widget.store.uid);
    if (!mounted || generation != _generation) return;
    final launch = device.takeInitialOpening();
    if (launch != null) {
      _opening = launch;
      _openReservation();
    }
    if (state.supported) {
      await device.synchronize(widget.store.uid, _records, enabled);
    }
    if (!mounted || generation != _generation) return;
    ReservationReminderSettings.deliveryError.value = null;
    if (state.enabled) return;
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
    if (state == AppLifecycleState.resumed) {
      _refresh().catchError(_deliveryFailed);
    }
  }

  @override
  void dispose() {
    _clear();
    _subscription?.cancel();
    _openings?.cancel();
    if (identical(
      ReservationReminderSettings.synchronizers[widget.store.uid],
      refresh,
    )) {
      ReservationReminderSettings.synchronizers.remove(widget.store.uid);
    }
    device.endSession(widget.store.uid).catchError((Object _) {});
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
