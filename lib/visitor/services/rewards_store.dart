import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/rewards.dart';
import '../models/tickets.dart';
import 'rewards_repository.dart';
import 'ticket_journey.dart' show bookingError;

class RewardsStore extends ChangeNotifier {
  final RewardsRepository repository;
  RewardsStore(this.repository);
  int balance = 0;
  List<ParkReward> catalogue = [];
  List<RewardVoucher> vouchers = [];
  List<LoyaltyEvent> events = [];
  List<TicketOrder> orders = [];
  bool busy = false, loading = true;
  String? error;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _ready = <String>{};
  bool _disposed = false;
  void start() {
    void listen<T>(String key, Stream<T> stream, void Function(T) apply) {
      _subscriptions.add(
        stream.listen(
          (value) {
            if (_disposed) return;
            apply(value);
            _ready.add(key);
            loading = _ready.length < 5;
            notifyListeners();
          },
          onError: (Object e) {
            if (!_disposed) {
              error = bookingError(e);
              loading = false;
              notifyListeners();
            }
          },
        ),
      );
    }

    listen('balance', repository.balance(), (v) => balance = v);
    listen('catalogue', repository.catalogue(), (v) => catalogue = v);
    listen('vouchers', repository.vouchers(), (v) => vouchers = v);
    listen('events', repository.events(), (v) => events = v);
    listen('orders', repository.orders(), (v) => orders = v);
  }

  int get lifetimeEarned =>
      events.where((e) => e.delta > 0).fold(0, (sum, e) => sum + e.delta);
  RewardsTier get tier => RewardsTier.forEarned(lifetimeEarned);
  List<TicketOrder> get uncollected => orders
      .where(
        (o) =>
            o.totalMinor >= 100 &&
            o.loyaltyEarnRate > 0 &&
            !events.any((e) => e.id == 'earn_${o.id}'),
      )
      .toList();
  int get pendingPoints => uncollected.fold(
    0,
    (sum, o) => sum + (o.totalMinor ~/ 100) * o.loyaltyEarnRate,
  );
  List<PointsActivity> get activity {
    final result = events.map((e) {
      final voucher = vouchers.where((v) => v.id == e.sourceId).firstOrNull;
      return PointsActivity(
        e.id,
        e.data['kind'] == 'no_show'
            ? 'Missed Reservation · ${e.data['title'] ?? 'Attraction'}'
            : e.data['kind'] == 'ride'
            ? 'Attraction Visit · ${e.data['title'] ?? 'Park attraction'}'
            : e.data['kind'] == 'photo'
            ? 'Photo Purchase'
            : e.data['kind'] == 'photo_spent'
            ? 'Points Used for Photos'
            : e.delta > 0
            ? 'Ticket Purchase'
            : 'Redeemed ${voucher?.reward.name ?? 'Park Reward'}',
        ['ride', 'no_show'].contains(e.data['kind'])
            ? 'attraction'
            : ['photo', 'photo_spent'].contains(e.data['kind'])
            ? 'photo'
            : e.delta > 0
            ? 'ticket'
            : voucher?.reward.category ?? 'shopping',
        e.delta,
        e.createdAt,
      );
    }).toList();
    for (final o in orders.where((o) => o.pointsUsed > 0)) {
      result.add(
        PointsActivity(
          'checkout_${o.id}',
          'Points Used for Tickets',
          'ticket',
          -o.pointsUsed,
          o.createdAt,
        ),
      );
    }
    result.sort(
      (a, b) => (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)),
    );
    return result;
  }

  int monthTotal(bool earned, [DateTime? now]) {
    final today = parkToday(now);
    return activity
        .where((e) {
          if (e.date == null || (e.delta > 0) != earned) return false;
          final day = parkToday(e.date);
          return day.year == today.year && day.month == today.month;
        })
        .fold(0, (sum, e) => sum + e.delta.abs());
  }

  Future<T?> run<T>(Future<T> Function() action) async {
    if (busy) return null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      return await action();
    } catch (e) {
      error = bookingError(e);
      return null;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool?> collect() => run(() async {
    for (final order in [...uncollected]) {
      await repository.collectOrder(order.id);
    }
    return true;
  });
  Future<RewardVoucher?> redeem(ParkReward reward) =>
      run(() => repository.redeem(reward));
  Future<bool?> use(String id) => run(() async {
    await repository.useVoucher(id);
    return true;
  });
  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
