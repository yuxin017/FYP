import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaborative_asg/visitor/models/rewards.dart';
import 'package:collaborative_asg/visitor/models/tickets.dart';
import 'package:collaborative_asg/visitor/pages/rewards_page.dart';
import 'package:collaborative_asg/visitor/services/rewards_repository.dart';
import 'package:collaborative_asg/visitor/services/rewards_store.dart';

final rewards = [
  const ParkReward('dining', {
    'name': '20% Off Dining',
    'subtitle': 'Selected park restaurants',
    'category': 'dining',
    'benefit': 'Enjoy 20% off eligible dining items.',
    'pointsCost': 150,
    'validityDays': 30,
    'sortOrder': 1,
    'instructions': [
      'Choose a participating restaurant.',
      'Show this voucher before payment.',
      'Confirm use when staff are ready.',
    ],
    'terms': ['One use per voucher.', 'Cannot be exchanged for cash.'],
  }),
  const ParkReward('shopping', {
    'name': 'RM10 Souvenir Voucher',
    'subtitle': 'Minimum spend RM50',
    'category': 'shopping',
    'benefit': 'RM10 off an eligible purchase of RM50 or more.',
    'pointsCost': 200,
    'validityDays': 30,
    'sortOrder': 2,
    'instructions': [
      'Choose your souvenirs.',
      'Show the voucher at the counter.',
    ],
    'terms': ['One use only.'],
  }),
  const ParkReward('photo', {
    'name': 'Free Digital Photo',
    'subtitle': 'One standard digital download',
    'category': 'photo',
    'benefit': 'Present at the photo counter for one standard photo.',
    'pointsCost': 300,
    'validityDays': 30,
    'sortOrder': 3,
    'instructions': [
      'Choose one photo at the counter.',
      'Show this voucher to staff.',
    ],
    'terms': ['One photo only.'],
  }),
];

class FixtureRewards extends RewardsRepository {
  int points = 2450, redemptions = 0, uses = 0, collections = 0;
  bool failNext = false;
  List<TicketOrder> purchases = [];
  final balanceChanges = StreamController<int>.broadcast();
  final voucherChanges = StreamController<List<RewardVoucher>>.broadcast();
  final eventChanges = StreamController<List<LoyaltyEvent>>.broadcast();
  late List<RewardVoucher> saved = List.generate(
    3,
    (i) => RewardVoucher('${i + 1}'.padLeft(48, 'a'), {
      'ownerUid': 'fixture-visitor',
      'rewardId': rewards[i].id,
      'reward': rewards[i].snapshot,
      'pointsCost': rewards[i].cost,
      'status': 'available',
      'issuedAt': Timestamp.now(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    }),
  );
  late List<LoyaltyEvent> ledger = [
    LoyaltyEvent('earn_previous', {
      'delta': 2450,
      'sourceId': 'previous',
      'createdAt': Timestamp.now(),
    }),
  ];
  @override
  Stream<int> balance() async* {
    yield points;
    yield* balanceChanges.stream;
  }

  @override
  Stream<List<ParkReward>> catalogue() => Stream.value(rewards);
  @override
  Stream<List<RewardVoucher>> vouchers() async* {
    yield saved;
    yield* voucherChanges.stream;
  }

  @override
  Stream<List<LoyaltyEvent>> events() async* {
    yield ledger;
    yield* eventChanges.stream;
  }

  @override
  Stream<List<TicketOrder>> orders() => Stream.value(purchases);
  @override
  Future<void> collectOrder(String id) async {
    collections++;
    final order = purchases.firstWhere((o) => o.id == id);
    final delta = order.totalMinor ~/ 100;
    points += delta;
    ledger = [
      ...ledger,
      LoyaltyEvent('earn_$id', {
        'delta': delta,
        'sourceId': id,
        'createdAt': Timestamp.now(),
      }),
    ];
    balanceChanges.add(points);
    eventChanges.add(ledger);
  }

  @override
  Future<RewardVoucher> redeem(ParkReward reward) async {
    redemptions++;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (failNext) {
      failNext = false;
      throw StateError('Connection interrupted. Please try again.');
    }
    final voucher = RewardVoucher('b' * 48, {
      'ownerUid': 'fixture-visitor',
      'rewardId': reward.id,
      'reward': reward.snapshot,
      'pointsCost': reward.cost,
      'status': 'available',
      'issuedAt': Timestamp.now(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });
    points -= reward.cost;
    saved = [voucher, ...saved];
    ledger = [
      ...ledger,
      LoyaltyEvent('redeem_${voucher.id}', {
        'delta': -reward.cost,
        'sourceId': voucher.id,
        'createdAt': Timestamp.now(),
      }),
    ];
    balanceChanges.add(points);
    voucherChanges.add(saved);
    eventChanges.add(ledger);
    return voucher;
  }

  @override
  Future<void> useVoucher(String id) async {
    uses++;
    saved = saved
        .map(
          (v) => v.id == id
              ? RewardVoucher(id, {
                  ...v.data,
                  'status': 'used',
                  'usedAt': Timestamp.now(),
                })
              : v,
        )
        .toList();
    voucherChanges.add(saved);
  }

  Future<void> close() async {
    await balanceChanges.close();
    await voucherChanges.close();
    await eventChanges.close();
  }
}

Future<void> open(
  WidgetTester tester,
  FixtureRewards repo, {
  String section = 'points',
  Size size = const Size(440, 956),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: const Key('rewards-proof'),
        child: RewardsPage(repository: repo, initialSection: section),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> proof(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('rewards-proof')),
  );
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.local/rewards-qa').create(recursive: true);
    await File(
      '.local/rewards-qa/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    img.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    var directory = File(Platform.resolvedExecutable).parent;
    Directory? fonts;
    for (var i = 0; i < 10; i++) {
      final candidate = Directory(
        '${directory.path}/bin/cache/artifacts/material_fonts',
      );
      if (await candidate.exists()) {
        fonts = candidate;
        break;
      }
      directory = directory.parent;
    }
    if (fonts == null) throw StateError('Flutter fonts unavailable.');
    for (final entry in {
      'Roboto': ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'],
      'MaterialIcons': ['materialicons-regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        loader.addFont(
          File('${fonts.path}/$name').readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
  });
  test(
    'voucher expiry uses the actual instant and used vouchers stay in Used',
    () {
      final expiry = DateTime.utc(2026, 11, 7, 16);
      final voucher = RewardVoucher('a' * 48, {
        'status': 'available',
        'expiresAt': Timestamp.fromDate(expiry),
      });
      expect(
        voucher.stateAt(expiry.subtract(const Duration(microseconds: 1))),
        'Available',
      );
      expect(voucher.stateAt(expiry), 'Expired');
      expect(
        RewardVoucher(voucher.id, {
          ...voucher.data,
          'status': 'used',
        }).stateAt(expiry),
        'Used',
      );
      expect(voucher.validUntil, '7 Nov 2026');
      expect(RewardsTier.forEarned(2450).remaining, 550);
      expect(RewardsTier.forEarned(3000).next, isNull);
    },
  );
  testWidgets(
    'points keep the Figma sections and filter actual earned and redeemed activity',
    (tester) async {
      final repo = FixtureRewards();
      addTearDown(repo.close);
      repo.ledger = [
        ...repo.ledger,
        LoyaltyEvent('redeem_old', {
          'delta': -150,
          'sourceId': repo.saved.first.id,
          'createdAt': Timestamp.now(),
        }),
      ];
      await open(tester, repo);
      expect(find.text('Gold Member'), findsOneWidget);
      expect(find.text('550 pts to Platinum'), findsOneWidget);
      expect(find.text('Earned This Month'), findsOneWidget);
      expect(find.text('Redeemed This Month'), findsOneWidget);
      await proof(tester, 'points');
      await tester.tap(find.text('Redeemed'));
      await tester.pumpAndSettle();
      expect(find.text('Ticket Purchase'), findsNothing);
      expect(find.text('Redeemed 20% Off Dining'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'voucher detail requires confirmation and moves to Used after one use',
    (tester) async {
      final repo = FixtureRewards();
      addTearDown(repo.close);
      await open(tester, repo, section: 'vouchers');
      expect(find.text('3 available vouchers'), findsOneWidget);
      await proof(tester, 'vouchers');
      await tester.tap(find.text('View Voucher').first);
      await tester.pumpAndSettle();
      await proof(tester, 'voucher-details');
      await tester.ensureVisible(find.text('Use Voucher'));
      await tester.tap(find.text('Use Voucher'));
      await tester.pumpAndSettle();
      expect(repo.uses, 0);
      await tester.tap(find.text('Not Yet'));
      await tester.pumpAndSettle();
      expect(repo.uses, 0);
      await tester.tap(find.text('Use Voucher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Use'));
      await tester.pumpAndSettle();
      expect(repo.uses, 1);
      expect(find.text('Voucher Used'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Used'));
      await tester.pumpAndSettle();
      expect(find.text('20% Off Dining'), findsOneWidget);
      expect(find.text('RM10 Souvenir Voucher'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'redemption reviews terms, handles retry, and saves one voucher with live points',
    (tester) async {
      final repo = FixtureRewards();
      addTearDown(repo.close);
      await open(tester, repo, section: 'catalogue');
      await proof(tester, 'catalogue');
      await tester.tap(find.text('View Reward').first);
      await tester.pumpAndSettle();
      await proof(tester, 'reward-details');
      repo.failNext = true;
      await tester.ensureVisible(find.text('Redeem Reward'));
      await tester.tap(find.text('Redeem Reward'));
      await tester.pumpAndSettle();
      expect(repo.redemptions, 0);
      await tester.tap(find.text('Confirm Redemption'));
      await tester.pumpAndSettle();
      expect(
        find.text('Connection interrupted. Please try again.'),
        findsOneWidget,
      );
      expect(repo.points, 2450);
      await tester.ensureVisible(find.text('Redeem Reward'));
      await tester.tap(find.text('Redeem Reward'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Redemption'));
      await tester.pumpAndSettle();
      expect(repo.points, 2300);
      expect(repo.saved.length, 4);
      expect(find.text('Voucher Details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'insufficient points and narrow layouts retain the complete reward flow',
    (tester) async {
      final repo = FixtureRewards()..points = 0;
      addTearDown(repo.close);
      await open(
        tester,
        repo,
        section: 'catalogue',
        size: const Size(360, 800),
      );
      await tester.tap(find.text('View Reward').first);
      await tester.pumpAndSettle();
      expect(find.text('Need 150 More Points'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Need 150 More Points'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('catalogue opens at the top after scrolling points history', (
    tester,
  ) async {
    final repo = FixtureRewards();
    repo.purchases = [TicketOrder(id: 'c' * 48, packageName: 'Day Pass', visitDate: '2026-11-07', requestId: 'c' * 48, quantity: 1, totalMinor: 14000)];
    addTearDown(repo.close);
    await open(tester, repo, size: const Size(440, 700));
    await tester.scrollUntilVisible(
      find.text('View Redemption Catalogue'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('View Redemption Catalogue'));
    await tester.pumpAndSettle();
    expect(find.text('Your points balance'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Your points balance')).dy,
      inInclusiveRange(70, 150),
    );
    expect(tester.takeException(), isNull);
  });
  test(
    'store separates checkout discounts from voucher spending and prevents overlapping mutations',
    () async {
      final repo = FixtureRewards();
      final store = RewardsStore(repo);
      store.start();
      await Future<void>.delayed(Duration.zero);
      repo.purchases = [
        TicketOrder(
          id: 'c' * 48,
          packageName: 'Day Pass',
          visitDate: '2026-11-06',
          requestId: 'c' * 48,
          quantity: 1,
          totalMinor: 12000,
          pointsUsed: 100,
          createdAt: DateTime.now(),
        ),
      ];
      store.orders = repo.purchases;
      expect(store.pendingPoints, 120);
      expect(store.monthTotal(false), 100);
      final first = store.redeem(rewards.first),
          second = store.redeem(rewards.first);
      expect(await second, isNull);
      expect(await first, isNotNull);
      expect(repo.redemptions, 1);
      await store.collect();
      await Future<void>.delayed(Duration.zero);
      expect(repo.collections, 1);
      expect(store.uncollected, isEmpty);
      store.dispose();
      await repo.close();
    },
  );
}
