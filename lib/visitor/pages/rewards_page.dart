import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/rewards.dart';
import '../models/tickets.dart';
import '../services/rewards_repository.dart';
import '../services/rewards_store.dart';
import '../visitor_main_page.dart';
import '../widgets/rewards_widgets.dart';
import '../widgets/visitor_bottom_nav.dart';

class RewardsPage extends StatefulWidget {
  final String initialSection;
  final RewardsRepository? repository;
  const RewardsPage({
    super.key,
    this.initialSection = 'points',
    this.repository,
  });
  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  late RewardsStore store;
  late String section = widget.initialSection;
  final history = <String>[];
  String activityFilter = 'All', voucherFilter = 'Available', category = 'All';
  ParkReward? offer;
  RewardVoucher? selected;
  Timer? clock;
  @override
  void initState() {
    super.initState();
    store = RewardsStore(widget.repository ?? FirebaseRewardsRepository())
      ..start();
    clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    store.dispose();
    super.dispose();
  }

  void go(String page) => setState(() {
    history.add(section);
    section = page;
  });
  void back() {
    if (store.busy) return;
    if (history.isEmpty) {
      Navigator.pop(context);
    } else {
      setState(() => section = history.removeLast());
    }
  }

  void openVoucher(RewardVoucher value) {
    selected = value;
    go('detail');
  }

  void help() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your park rewards',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            const Text(
              'Earn as you explore',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Earn 1 point for each full RM1 of the final ticket total, after points discounts. Points belong to the purchaser. Completed purchases can be collected once from Points & History.',
            ),
            const SizedBox(height: 18),
            const Text(
              'Choose how to spend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use 100 points for RM1 off tickets at checkout, or exchange points for a voucher in the redemption catalogue. A voucher is saved in My Vouchers with its own expiry and terms.',
            ),
            const SizedBox(height: 18),
            const Text(
              'Grow your membership',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rewards membership is based on total points earned: Normal below 500, Silver from 500, Gold from 1,500 and Platinum from 3,000. Spending points does not reduce your level.',
            ),
            const SizedBox(height: 18),
            const Text(
              'At the counter',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Show the voucher to staff. Press Use Voucher only when staff are ready to accept it. Once confirmed, it moves to Used and cannot be used again. Vouchers are valid until 11:59 pm Malaysia time on the date shown.',
            ),
            const SizedBox(height: 22),
            RewardButton('Got it', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    ),
  );

  Future<void> redeem() async {
    final reward = offer!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redeem this reward?'),
        content: Text(
          '${reward.name}\n\n${groupedPoints(reward.cost)} points will be exchanged for one voucher, valid for ${reward.validityDays} days including today.\n\nBalance after redemption: ${groupedPoints(store.balance - reward.cost)} points.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Browsing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Redemption'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final voucher = await store.redeem(reward);
    if (voucher != null && mounted) {
      setState(() {
        selected = voucher;
        history.add('vouchers');
        section = 'detail';
        voucherFilter = 'Available';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reward redeemed. Your voucher is ready.'),
        ),
      );
    }
  }

  Future<void> useVoucher(RewardVoucher voucher) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use this voucher now?'),
        content: Text(
          'Show ${voucher.reward.name} to staff before confirming. This marks the voucher as used and it cannot be used again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Use'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final result = await store.use(voucher.id);
    if (result == true && mounted) {
      setState(() {
        selected = RewardVoucher(voucher.id, {
          ...voucher.data,
          'status': 'used',
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voucher used successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: rewardRose,
        primary: rewardRose,
        surface: Colors.white,
      ),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: rewardInk, displayColor: rewardInk),
    ),
    child: PopScope(
      canPop: history.isEmpty && !store.busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: ColoredBox(
        color: rewardBackground,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Scaffold(
              backgroundColor: rewardBackground,
              bottomNavigationBar: VisitorBottomNav(
                selectedIndex: 4,
                onTap: (index) {
                  if (store.busy) return;
                  Navigator.pop(context);
                  VisitorMainPage.goTo(context, index);
                },
              ),
              body: RewardsBackground(
                child: SafeArea(
                  child: AnimatedBuilder(
                    animation: store,
                    builder: (context, _) {
                      final title = switch (section) {
                        'vouchers' => 'My Vouchers',
                        'catalogue' => 'Redemption Catalogue',
                        'offer' => 'Reward Details',
                        'detail' => 'Voucher Details',
                        _ => 'Points & History',
                      };
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Back',
                                  onPressed: store.busy ? null : back,
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: rewardRose,
                                    size: 20,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Rewards help',
                                  onPressed: help,
                                  icon: const Icon(
                                    Icons.help_outline,
                                    color: rewardRose,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (store.busy)
                            const LinearProgressIndicator(
                              minHeight: 2,
                              color: rewardRose,
                            ),
                          if (store.error != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                              child: RewardCard(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: rewardRose,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        store.error!,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Reload rewards',
                                      onPressed: store.busy
                                          ? null
                                          : () {
                                              setState(() {
                                                store.dispose();
                                                store = RewardsStore(
                                                  widget.repository ??
                                                      FirebaseRewardsRepository(),
                                                )..start();
                                              });
                                            },
                                      icon: const Icon(
                                        Icons.refresh,
                                        color: rewardRose,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Expanded(
                            child: store.loading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: rewardRose,
                                    ),
                                  )
                                : Semantics(
                                    container: true,
                                    explicitChildNodes: true,
                                    key: ValueKey(
                                      '$section:${section == 'offer'
                                          ? offer?.id
                                          : section == 'detail'
                                          ? selected?.id
                                          : ''}',
                                    ),
                                    child: switch (section) {
                                      'vouchers' => vouchers(),
                                      'catalogue' => catalogue(),
                                      'offer' => offerDetails(),
                                      'detail' => voucherDetails(),
                                      _ => points(),
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget points() {
    final tier = store.tier;
    final rows = store.activity
        .where(
          (e) =>
              activityFilter == 'All' ||
              (activityFilter == 'Earned' ? e.delta > 0 : e.delta < 0),
        )
        .toList();
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB67D7C), Color(0xFF9F6465)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24684443),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFF8F1),
                        width: 6,
                      ),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Color(0xFFFFF8F1),
                      size: 46,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tier.name} Member',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: groupedPoints(store.balance),
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' pts',
                                  style: TextStyle(fontSize: 21),
                                ),
                              ],
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                tier.next == null
                    ? 'Platinum membership unlocked'
                    : '${groupedPoints(tier.remaining)} pts to ${tier.next}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 11),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: tier.progress,
                  minHeight: 9,
                  color: const Color(0xFFFFF5EE),
                  backgroundColor: const Color(0xFFBD8988),
                ),
              ),
              const SizedBox(height: 7),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: monthlyCard(true)),
            const SizedBox(width: 14),
            Expanded(child: monthlyCard(false)),
          ],
        ),
        if (store.pendingPoints > 0) ...[
          const SizedBox(height: 20),
          RewardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your purchases have earned points',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  '${groupedPoints(store.pendingPoints)} points from ${store.uncollected.length} completed purchase${store.uncollected.length == 1 ? '' : 's'} are ready to collect.',
                  style: const TextStyle(
                    color: rewardMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                RewardButton(
                  'Collect ${groupedPoints(store.pendingPoints)} Points',
                  onPressed: store.busy
                      ? null
                      : () async {
                          if (await store.collect() == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Your purchase points have been added.',
                                ),
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),
        const Text(
          'Points Activity',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        RewardTabs(
          labels: const ['All', 'Earned', 'Redeemed'],
          selected: activityFilter,
          onChanged: (value) => setState(() => activityFilter = value),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          empty(
            Icons.stars_outlined,
            'Your rewards journey starts here',
            activityFilter == 'All'
                ? 'Points from ticket purchases and redeemed rewards will appear here.'
                : 'No ${activityFilter.toLowerCase()} points yet.',
          )
        else
          RewardCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: rewardBorder),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      children: [
                        RewardCircle(rows[i].category, size: 43),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Text(
                            rows[i].title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${rows[i].delta > 0 ? '+' : ''}${groupedPoints(rows[i].delta)} pts',
                              style: const TextStyle(
                                color: rewardRose,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              activityDate(rows[i].date),
                              style: const TextStyle(
                                color: rewardMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 22),
        TextButton(
          onPressed: () => go('catalogue'),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'View Redemption Catalogue',
                  style: TextStyle(
                    color: rewardRose,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              SizedBox(width: 5),
              Icon(Icons.chevron_right, color: rewardRose),
            ],
          ),
        ),
      ],
    );
  }

  Widget monthlyCard(bool earned) => RewardCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
    child: Row(
      children: [
        Image.asset(
          'assets/images/rewards/${earned ? 'earned' : 'redeemed'}.png',
          width: 34,
          height: 37,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${earned ? 'Earned' : 'Redeemed'} This Month',
                style: const TextStyle(fontSize: 11, color: rewardInk),
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${earned ? '+' : '-'}${groupedPoints(store.monthTotal(earned))}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: rewardRose,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget vouchers() {
    final available = store.vouchers
        .where((v) => v.state == 'Available')
        .length;
    final rows = store.vouchers.where((v) => v.state == voucherFilter).toList();
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 9, 22, 20),
      children: [
        Text(
          '$available available voucher${available == 1 ? '' : 's'}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: rewardMuted),
        ),
        const SizedBox(height: 20),
        RewardTabs(
          labels: const ['Available', 'Used', 'Expired'],
          selected: voucherFilter,
          segmented: true,
          onChanged: (v) => setState(() => voucherFilter = v),
        ),
        const SizedBox(height: 24),
        if (rows.isEmpty)
          empty(
            Icons.local_offer_outlined,
            'No ${voucherFilter.toLowerCase()} vouchers',
            voucherFilter == 'Available'
                ? 'Exchange your points for dining, shopping and photo rewards.'
                : 'Your ${voucherFilter.toLowerCase()} vouchers will appear here.',
          ),
        for (final voucher in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: CouponSurface(
              child: Row(
                children: [
                  RewardCircle(voucher.reward.category),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voucher.reward.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          voucher.reward.subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: rewardMuted,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 15,
                              color: rewardRose,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Valid until ${voucher.validUntil}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: rewardMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  const RewardDashes(vertical: true),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 88,
                    child: Column(
                      children: [
                        RewardStatus(voucher.state),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: rewardRose,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            onPressed: () => openVoucher(voucher),
                            child: const Text(
                              'View Voucher',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => go('catalogue'),
          child: const Text(
            'Browse Rewards',
            style: TextStyle(color: rewardRose, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Terms and conditions apply.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: rewardMuted),
        ),
      ],
    );
  }

  Widget catalogue() {
    final rows = store.catalogue
        .where(
          (r) =>
              category == 'All' ||
              r.category ==
                  {
                    'Dining': 'dining',
                    'Shopping': 'shopping',
                    'Photos': 'photo',
                  }[category],
        )
        .toList();
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      children: [
        RewardCard(
          child: Row(
            children: [
              const Icon(Icons.stars, color: rewardRose, size: 35),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your points balance',
                      style: TextStyle(color: rewardMuted, fontSize: 12),
                    ),
                    Text(
                      '${groupedPoints(store.balance)} pts',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: rewardRose,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'A little extra for your next adventure',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a reward, review its terms and turn your points into a voucher.',
          style: TextStyle(fontSize: 13, color: rewardMuted, height: 1.5),
        ),
        const SizedBox(height: 18),
        RewardTabs(
          labels: const ['All', 'Dining', 'Shopping', 'Photos'],
          selected: category,
          onChanged: (v) => setState(() => category = v),
        ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          empty(
            Icons.redeem_outlined,
            'More rewards are on their way',
            'Available rewards will appear here.',
          ),
        for (final reward in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: CouponSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RewardCircle(reward.category, size: 54),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reward.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              reward.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: rewardMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const RewardDashes(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.stars_outlined,
                        color: rewardRose,
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${groupedPoints(reward.cost)} points',
                          style: const TextStyle(
                            color: rewardRose,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${reward.validityDays} days validity',
                        style: const TextStyle(
                          fontSize: 11,
                          color: rewardMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  RewardButton(
                    'View Reward',
                    onPressed: () {
                      offer = reward;
                      go('offer');
                    },
                    outlined: true,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget offerDetails() {
    final reward = offer!;
    final current = store.catalogue.where((r) => r.id == reward.id).firstOrNull;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
      children: [
        CouponSurface(
          child: Column(
            children: [
              RewardCircle(reward.category, size: 68),
              const SizedBox(height: 16),
              Text(
                reward.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reward.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: rewardMuted),
              ),
              const SizedBox(height: 23),
              const RewardDashes(),
              const SizedBox(height: 23),
              Text(
                '${groupedPoints(reward.cost)} pts',
                style: const TextStyle(
                  color: rewardRose,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Valid for ${reward.validityDays} days including redemption day',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: rewardMuted),
              ),
              const SizedBox(height: 18),
              Text(
                reward.benefit,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 23),
              RewardButton(
                current == null
                    ? 'Reward Unavailable'
                    : store.balance < reward.cost
                    ? 'Need ${groupedPoints(reward.cost - store.balance)} More Points'
                    : 'Redeem Reward',
                onPressed:
                    !store.busy &&
                        current != null &&
                        store.balance >= reward.cost
                    ? redeem
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        instructions(reward),
        const SizedBox(height: 12),
        terms(reward),
      ],
    );
  }

  Widget voucherDetails() {
    final voucher =
        store.vouchers.where((v) => v.id == selected!.id).firstOrNull ??
        selected!;
    final reward = voucher.reward;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
      children: [
        CouponSurface(
          child: Column(
            children: [
              RewardCircle(reward.category, size: 60),
              const SizedBox(height: 12),
              Text(
                reward.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reward.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: rewardMuted),
              ),
              const SizedBox(height: 10),
              RewardStatus(voucher.state),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 17,
                    color: rewardRose,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Valid until ${voucher.validUntil}',
                    style: const TextStyle(fontSize: 12, color: rewardMuted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const RewardDashes(),
              const SizedBox(height: 14),
              if (voucher.state == 'Available')
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: rewardBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: voucher.qrData,
                    size: 128,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Icon(
                    voucher.state == 'Used'
                        ? Icons.check_circle_outline
                        : Icons.event_busy_outlined,
                    size: 80,
                    color: rewardRose,
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Voucher Code',
                style: TextStyle(color: rewardMuted, fontSize: 12),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      voucher.shortCode,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy full voucher code',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    icon: const Icon(
                      Icons.copy_outlined,
                      size: 17,
                      color: rewardRose,
                    ),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: voucher.code),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Voucher code copied.')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                voucher.state == 'Available'
                    ? 'Show this QR code to the cashier before payment.'
                    : voucher.state == 'Used'
                    ? 'This voucher has been used${voucher.usedAt == null ? '.' : ' on ${activityDate(voucher.usedAt)}.'}'
                    : 'This voucher is no longer valid.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: rewardMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 17),
              RewardButton(
                voucher.state == 'Available'
                    ? 'Use Voucher'
                    : 'Voucher ${voucher.state}',
                onPressed: voucher.state == 'Available' && !store.busy
                    ? () => useVoucher(voucher)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        instructions(reward),
        const SizedBox(height: 12),
        terms(reward),
      ],
    );
  }

  Widget instructions(ParkReward reward) => RewardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How to use',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < reward.instructions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF8ECE7),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontSize: 11, color: rewardRose),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reward.instructions[i],
                    style: const TextStyle(
                      fontSize: 12,
                      color: rewardMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  Widget terms(ParkReward reward) => RewardCard(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.description_outlined, color: rewardRose),
      title: const Text(
        'Terms & Conditions',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      iconColor: rewardRose,
      collapsedIconColor: rewardRose,
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      children: reward.terms
          .map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: rewardRose)),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12,
                        color: rewardMuted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );
  Widget empty(IconData icon, String title, String message) => RewardCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Icon(icon, size: 42, color: rewardRose),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: rewardMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
  String activityDate(DateTime? date) {
    if (date == null) return 'Just now';
    final day = parkToday(date);
    if (day == parkToday()) return 'Today';
    return displayParkDate(visitDateString(day));
  }
}
