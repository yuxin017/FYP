import 'package:cloud_firestore/cloud_firestore.dart';
import 'tickets.dart';

DateTime? rewardDate(dynamic value) =>
    value is Timestamp ? value.toDate() : null;
String groupedPoints(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);

class ParkReward {
  final String id;
  final Map<String, dynamic> data;
  const ParkReward(this.id, this.data);
  String get name => data['name'] as String? ?? 'Park reward';
  String get subtitle => data['subtitle'] as String? ?? '';
  String get category => data['category'] as String? ?? 'shopping';
  String get benefit => data['benefit'] as String? ?? '';
  int get cost => (data['pointsCost'] as num?)?.toInt() ?? 0;
  int get validityDays => (data['validityDays'] as num?)?.toInt() ?? 30;
  int get sortOrder => (data['sortOrder'] as num?)?.toInt() ?? 0;
  List<String> get terms =>
      (data['terms'] as List?)?.whereType<String>().toList() ?? [];
  List<String> get instructions =>
      (data['instructions'] as List?)?.whereType<String>().toList() ?? [];
  Map<String, dynamic> get snapshot => {
    'name': name,
    'subtitle': subtitle,
    'category': category,
    'benefit': benefit,
    'terms': terms,
    'instructions': instructions,
    'validityDays': validityDays,
  };
}

class RewardVoucher {
  final String id;
  final Map<String, dynamic> data;
  const RewardVoucher(this.id, this.data);
  String get ownerUid => data['ownerUid'] as String? ?? '';
  String get rewardId => data['rewardId'] as String? ?? '';
  ParkReward get reward => ParkReward(rewardId, {
    ...Map<String, dynamic>.from(data['reward'] as Map? ?? {}),
    'pointsCost': data['pointsCost'] ?? 0,
  });
  DateTime? get issuedAt => rewardDate(data['issuedAt']);
  DateTime? get expiresAt => rewardDate(data['expiresAt']);
  DateTime? get usedAt => rewardDate(data['usedAt']);
  String stateAt(DateTime now) {
    if (data['status'] == 'used') return 'Used';
    if (expiresAt == null || !now.isBefore(expiresAt!)) return 'Expired';
    return 'Available';
  }

  String get state => stateAt(DateTime.now());
  String get code => 'RV-${id.toUpperCase()}';
  String get shortCode =>
      'RV-${id.substring(0, id.length < 12 ? id.length : 12).toUpperCase()}';
  String get qrData => 'RV1:$id';
  String get validUntil => expiresAt == null
      ? '—'
      : displayParkDate(
          visitDateString(
            parkToday(expiresAt!.subtract(const Duration(seconds: 1))),
          ),
        );
}

class LoyaltyEvent {
  final String id;
  final Map<String, dynamic> data;
  const LoyaltyEvent(this.id, this.data);
  int get delta => (data['delta'] as num?)?.toInt() ?? 0;
  String get sourceId => data['sourceId'] as String? ?? '';
  DateTime? get createdAt => rewardDate(data['createdAt']);
}

class PointsActivity {
  final String id, title, category;
  final int delta;
  final DateTime? date;
  const PointsActivity(
    this.id,
    this.title,
    this.category,
    this.delta,
    this.date,
  );
}

class RewardsTier {
  final String name;
  final String? next;
  final int start, target, earned;
  const RewardsTier(this.name, this.next, this.start, this.target, this.earned);
  factory RewardsTier.forEarned(int earned) {
    if (earned >= 3000) {
      return RewardsTier('Platinum', null, 3000, 3000, earned);
    }
    if (earned >= 1500) {
      return RewardsTier('Gold', 'Platinum', 1500, 3000, earned);
    }
    if (earned >= 500) return RewardsTier('Silver', 'Gold', 500, 1500, earned);
    return RewardsTier('Normal', 'Silver', 0, 500, earned);
  }
  double get progress =>
      next == null ? 1 : ((earned - start) / (target - start)).clamp(0, 1);
  int get remaining => (target - earned).clamp(0, target);
}
