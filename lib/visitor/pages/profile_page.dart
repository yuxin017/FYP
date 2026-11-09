import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'profile_settings_page.dart';
import '../visitor_main_page.dart';
import '../services/ticket_repository.dart';
import '../models/rewards.dart';
import '../services/rewards_repository.dart';
import 'rewards_page.dart';
import '../../support/support_page.dart';
import '../../visits/visit_repository.dart';
import '../../visits/visit_pages.dart';
import 'purchase_history_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const Color _primary = Color(0xFFAD7472);
  static const Color _background = Color(0xFFFDF4EF);
  static const Color _dark = Color(0xFF263238);
  static const Color _border = Color(0xFFE9D9D3);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please log in to view your profile.'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('visitors')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load your profile.'));
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        final data = snapshot.data!.data();

        if (data == null) {
          return const Center(child: Text('Visitor profile not found.'));
        }

        final name = data['fullName'] as String? ?? 'Visitor';
        final email = data['email'] as String? ?? user.email ?? '';
        final points = (data['loyaltyPoints'] as num?)?.toInt() ?? 0;

        return Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.38, 1.0],
                    colors: [_background, Color(0xFFFEF8F5), Color(0xFFFFFCFA)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 370,
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/Background.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.35, 0.7, 1],
                          colors: [
                            Color(0x99FDF4EF),
                            Color(0xBFFDF4EF),
                            Color(0xF0FDF4EF),
                            _background,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                children: [
                  _header(context),
                  const SizedBox(height: 20),
                  _userCard(context, name, email, data),
                  const SizedBox(height: 16),
                  _statistics(context, points),
                  const SizedBox(height: 14),
                  _scanButton(context),
                  const SizedBox(height: 28),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                  ),
                  _accountMenu(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileSettingsPage()));
  }

  void _openRewards(BuildContext context, String section) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RewardsPage(initialSection: section)),
    );
  }

  ImageProvider? _profileImage(Map<String, dynamic> data) {
    final value = data['profilePhotoBase64'];
    if (value is! String || value.trim().isEmpty) return null;
    try {
      final raw = value.contains(',') ? value.split(',').last : value;
      return MemoryImage(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Language',
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (sheetContext) => SafeArea(
              child: ListTile(
                title: const Text('English'),
                trailing: const Icon(Icons.check, color: _primary),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ),
          ),
          icon: const Icon(Icons.language, color: _primary),
        ),
        IconButton(
          tooltip: 'Profile Settings',
          onPressed: () => _openSettings(context),
          icon: const Icon(Icons.settings_outlined, color: _primary),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Notifications'),
              content: const Text('No notifications yet.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.notifications_none, color: _primary),
        ),
      ],
    );
  }

  // Membership levels: Normal, Silver, Gold.
  // New accounts default to Normal; membershipLevel can be set by a trusted backend.
  String _membershipLabel(Map<String, dynamic> data) {
    final level = (data['membershipLevel'] as String? ?? 'normal')
        .toLowerCase();
    switch (level) {
      case 'gold':
        return 'Gold Member';
      case 'silver':
        return 'Silver Member';
      default:
        return 'Normal Member';
    }
  }

  Widget _userCard(
    BuildContext context,
    String name,
    String email,
    Map<String, dynamic> data,
  ) {
    final photo = _profileImage(data);
    final membershipLabel = _membershipLabel(data);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFF0DDDA),
            backgroundImage: photo,
            child: photo == null
                ? const Icon(Icons.person, size: 38, color: _primary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F6),
                    border: Border.all(color: _primary),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: StreamBuilder<List<LoyaltyEvent>>(
                    stream: FirebaseRewardsRepository().events(),
                    builder: (context, snapshot) => Text(
                      snapshot.hasData
                          ? '${RewardsTier.forEarned(snapshot.data!.where((e) => e.delta > 0).fold<int>(0, (total, e) => total + e.delta)).name} Member'
                          : membershipLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => _openSettings(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
              side: const BorderSide(color: _primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              disabledForegroundColor: _primary,
            ),
            child: const Text('Edit Profile', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _statistics(BuildContext context, int points) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFCDB7B0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseTicketRepository().tickets(),
              builder: (context, snapshot) => InkWell(
                onTap: () => VisitorMainPage.openTickets(context, 'tickets'),
                child: Row(
                  children: [
                    _statItem(
                      Icons.confirmation_number,
                      '${snapshot.data?.where((t) => t.filter == 'Upcoming').length ?? 0}',
                      'My Tickets',
                    ),
                  ],
                ),
              ),
            ),
          ),
          _statDivider(),
          _statItem(
            Icons.stars,
            groupedPoints(points),
            'Points',
            onTap: () => _openRewards(context, 'points'),
          ),
          _statDivider(),
          Expanded(
            child: StreamBuilder<List<RewardVoucher>>(
              stream: FirebaseRewardsRepository().vouchers(),
              builder: (context, snapshot) => Row(
                children: [
                  _statItem(
                    Icons.local_offer,
                    snapshot.hasError
                        ? '—'
                        : '${snapshot.data?.where((v) => v.state == 'Available').length ?? 0}',
                    'Vouchers',
                    onTap: () => _openRewards(context, 'vouchers'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 64, color: _border);
  }

  Widget _statItem(
    IconData icon,
    String value,
    String label, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _primary, size: 25),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanButton(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: () => VisitorMainPage.openTickets(context, 'scan'),
        icon: const Icon(Icons.qr_code, size: 25),
        label: const Text(
          'Scan & Add Ticket',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _accountMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _menuItem(
            Icons.shopping_bag_outlined,
            'Purchase History',
            'Tickets, photos and purchases',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CombinedPurchaseHistoryPage(),
              ),
            ),
          ),
          _divider(),
          _menuItem(
            Icons.bar_chart,
            'Visited Attractions',
            'Current and past visits',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    VisitHistoryPage(repository: FirebaseVisitRepository()),
              ),
            ),
          ),
          _divider(),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Color(0xFFAD7472)),
            title: const Text(
              'Profile Settings',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Personal details, preferences and security',
              style: TextStyle(fontSize: 9),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              _openSettings(context);
            },
          ),
          _divider(),
          _menuItem(
            Icons.help_outline,
            'Help & Support',
            'Guides, feedback and complaints',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SupportPage())),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 14, endIndent: 14, color: _border);
  }

  Widget _menuItem(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 62,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(icon, color: _primary, size: 26),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}
