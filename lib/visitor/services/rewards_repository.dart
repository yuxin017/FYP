import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewards.dart';
import '../models/tickets.dart';

abstract class RewardsRepository {
  Stream<int> balance();
  Stream<List<ParkReward>> catalogue();
  Stream<List<RewardVoucher>> vouchers();
  Stream<List<LoyaltyEvent>> events();
  Stream<List<TicketOrder>> orders();
  Future<void> collectOrder(String orderId);
  Future<RewardVoucher> redeem(ParkReward reward);
  Future<void> useVoucher(String id);
}

class FirebaseRewardsRepository extends RewardsRepository {
  final FirebaseFirestore db;
  final String uid;
  FirebaseRewardsRepository({FirebaseFirestore? firestore, String? userId})
    : db = firestore ?? FirebaseFirestore.instance,
      uid = userId ?? FirebaseAuth.instance.currentUser!.uid;
  @override
  Stream<int> balance() => db
      .collection('visitors')
      .doc(uid)
      .snapshots()
      .map((d) => (d.data()?['loyaltyPoints'] as num?)?.toInt() ?? 0);
  @override
  Stream<List<ParkReward>> catalogue() => db
      .collection('rewardCatalogue')
      .where('active', isEqualTo: true)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => ParkReward(d.id, d.data())).toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
  @override
  Stream<List<RewardVoucher>> vouchers() => db
      .collection('rewardVouchers')
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => RewardVoucher(d.id, d.data())).toList()
          ..sort(
            (a, b) => (b.issuedAt ?? DateTime(1970)).compareTo(
              a.issuedAt ?? DateTime(1970),
            ),
          ),
      );
  @override
  Stream<List<LoyaltyEvent>> events() => db
      .collection('loyaltyEvents')
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => LoyaltyEvent(d.id, d.data())).toList());
  @override
  Stream<List<TicketOrder>> orders() => db
      .collection('orders')
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => s.docs
            .where(
              (d) =>
                  d.data()['version'] == 2 && d.data()['status'] == 'completed',
            )
            .map((d) => TicketOrder.fromMap(d.id, d.data()))
            .toList(),
      );

  @override
  Future<void> collectOrder(String orderId) async {
    final event = db.collection('loyaltyEvents').doc('earn_$orderId');
    final profile = db.collection('visitors').doc(uid);
    await db.runTransaction((tx) async {
      if ((await tx.get(event)).exists) return;
      final order = await tx.get(db.collection('orders').doc(orderId));
      final account = await tx.get(profile);
      final data = order.data();
      if (data == null ||
          data['ownerUid'] != uid ||
          data['version'] != 2 ||
          data['status'] != 'completed') {
        throw StateError(
          'Points are available for completed ticket purchases only.',
        );
      }
      final points =
          ((data['totalMinor'] as int) ~/ 100) *
          (data['loyaltyEarnRate'] as int? ?? 1);
      if (points < 1) return;
      tx.set(event, {
        'ownerUid': uid,
        'kind': 'earned',
        'sourceId': orderId,
        'delta': points,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(profile, {
        'loyaltyPoints': (account.data()!['loyaltyPoints'] as int) + points,
        'lastLoyaltyEventId': event.id,
      });
    });
  }

  @override
  Future<RewardVoucher> redeem(ParkReward reward) async {
    // An uncertain network response must reuse the same reference after reopening.
    final prefs = await SharedPreferences.getInstance();
    final key = 'reward_pending_${uid}_${reward.id}';
    final id =
        prefs.getString(key) ??
        List.generate(
          24,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    await prefs.setString(key, id);
    final voucher = db.collection('rewardVouchers').doc(id);
    final event = db.collection('loyaltyEvents').doc('redeem_$id');
    final profile = db.collection('visitors').doc(uid);
    final result = await db.runTransaction<RewardVoucher>((tx) async {
      final previous = await tx.get(voucher);
      if (previous.exists) {
        if (previous.data()!['ownerUid'] != uid ||
            previous.data()!['rewardId'] != reward.id) {
          throw StateError(
            'This redemption reference belongs to another reward.',
          );
        }
        return RewardVoucher(id, previous.data()!);
      }
      final offer = await tx.get(
        db.collection('rewardCatalogue').doc(reward.id),
      );
      final account = await tx.get(profile);
      if (!offer.exists || offer.data()!['active'] != true) {
        throw StateError(
          'This reward is no longer available. Please choose another.',
        );
      }
      final current = ParkReward(offer.id, offer.data()!);
      if (current.cost != reward.cost ||
          jsonEncode(current.snapshot) != jsonEncode(reward.snapshot)) {
        throw StateError('This reward has changed. Please review it again.');
      }
      final points = (account.data()?['loyaltyPoints'] as num?)?.toInt() ?? 0;
      if (points < current.cost) {
        throw StateError(
          'You need ${current.cost - points} more points for this reward.',
        );
      }
      final day = parkToday();
      final expiry = DateTime.utc(day.year, day.month, day.day)
          .add(Duration(days: current.validityDays))
          .subtract(const Duration(hours: 8));
      final data = <String, dynamic>{
        'ownerUid': uid,
        'rewardId': reward.id,
        'reward': current.snapshot,
        'pointsCost': current.cost,
        'status': 'available',
        'issuedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiry),
        'usedAt': null,
        'usedBy': '',
      };
      tx.set(voucher, data);
      tx.set(event, {
        'ownerUid': uid,
        'kind': 'redeemed',
        'sourceId': id,
        'delta': -current.cost,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(profile, {
        'loyaltyPoints': points - current.cost,
        'lastLoyaltyEventId': event.id,
      });
      return RewardVoucher(id, {...data, 'issuedAt': Timestamp.now()});
    });
    await prefs.remove(key);
    return result;
  }

  @override
  Future<void> useVoucher(String id) async {
    final reference = db.collection('rewardVouchers').doc(id);
    await db.runTransaction((tx) async {
      final doc = await tx.get(reference);
      if (!doc.exists || doc.data()!['ownerUid'] != uid) {
        throw StateError('This voucher could not be found.');
      }
      final voucher = RewardVoucher(id, doc.data()!);
      if (voucher.state == 'Used') return;
      if (voucher.state != 'Available') {
        throw StateError('This voucher has expired.');
      }
      tx.update(reference, {
        'status': 'used',
        'usedAt': FieldValue.serverTimestamp(),
        'usedBy': uid,
      });
    });
  }
}
