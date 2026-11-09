import 'dart:async';
import 'package:flutter/foundation.dart';
import '../visitor/models/tickets.dart';
import '../visitor/services/ticket_journey.dart';
import 'admin_models.dart';
import 'admin_repository.dart';

class AdminStore extends ChangeNotifier {
  final AdminRepository repository;
  AdminStore(this.repository);
  List<AdminVisitor> _raw = [];
  Map<String, Map<String, dynamic>> _meta = {}, _access = {};
  List<AdminVisitor> get visitors => _raw
      .map(
        (v) => AdminVisitor(
          v.id,
          v.data,
          metadata: _meta[v.id] ?? {},
          access: _access[v.id] ?? {},
        ),
      )
      .toList();
  List<AdminPackage> packages = [];
  List<ParkTicket> tickets = [];
  List<TicketOrder> orders = [];
  List<AdminActivity> sessions = [], audit = [], admissions = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool loading = true, busy = false, _disposed = false;
  String? error;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void start() {
    void failure(Object e) {
      loading = false;
      error = adminError(e);
      notifyListeners();
    }

    void listen<T>(Stream<T> stream, void Function(T) update) {
      _subscriptions.add(
        stream.listen((value) {
          update(value);
          notifyListeners();
        }, onError: failure),
      );
    }

    listen(repository.visitors(), (v) {
      _raw = v;
      loading = false;
    });
    listen(repository.metadata(), (v) => _meta = v);
    listen(repository.access(), (v) => _access = v);
    listen(repository.packages(), (v) => packages = v);
    listen(repository.tickets(), (v) => tickets = v);
    listen(repository.orders(), (v) => orders = v);
    listen(repository.sessions(), (v) => sessions = v);
    listen(repository.audit(), (v) => audit = v);
    listen(repository.admissions(), (v) => admissions = v);
  }

  Future<bool> perform(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = adminError(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  List<ParkTicket> visitorTickets(AdminVisitor v) => tickets
      .where(
        (t) =>
            t.ownerUid == v.id ||
            t.guestEmail.toLowerCase() == v.email.toLowerCase(),
      )
      .toList();
  List<TicketOrder> visitorOrders(String uid) => orders
      .where((o) => tickets.any((t) => t.orderId == o.id && t.ownerUid == uid))
      .toList();
  DateTime? lastSeen(String uid) {
    final list =
        sessions
            .where((s) => s.ownerUid == uid)
            .map((s) => adminDate(s.data['lastSeenAt']) ?? s.at)
            .whereType<DateTime>()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return list.firstOrNull;
  }

  int get activeToday => sessions
      .where((s) => s.data['day'] == visitDateString(parkToday()))
      .map((s) => s.ownerUid)
      .toSet()
      .length;
  int get newThisMonth {
    final today = parkToday();
    return visitors.where((v) {
      final d = v.joined?.toUtc().add(const Duration(hours: 8));
      return d?.year == today.year && d?.month == today.month;
    }).length;
  }

  int get flagged =>
      visitors.where((v) => v.watchlisted || v.risk != 'normal').length;
  String newRequestId() => TicketJourney.newId();
  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}

String adminError(Object error) {
  if (error is StateError) return error.message;
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Your account does not have permission for this action. Refresh your administrator sign-in and try again.';
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return 'Unable to connect. Check your connection and retry.';
  }
  return 'This action could not be completed. Please try again.';
}
