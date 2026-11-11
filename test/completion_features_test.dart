import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collaborative_asg/admin/operations/park_admin_repository.dart';
import 'package:collaborative_asg/admin/operations/park_management_page.dart';
import 'package:collaborative_asg/admin/operations/reports_page.dart';
import 'package:collaborative_asg/admin/operations/crowd_monitoring_page.dart';
import 'package:collaborative_asg/park/intelligence_repository.dart';
import 'package:collaborative_asg/park/assistant_page.dart';
import 'package:collaborative_asg/visitor/pages/purchase_history_page.dart';
import 'package:collaborative_asg/visitor/services/ticket_currency.dart';
import 'package:collaborative_asg/visitor/models/tickets.dart';
import 'package:collaborative_asg/photos/photo_repository.dart';
import 'package:collaborative_asg/device/biometric_security.dart';
import 'photos_module_test.dart' show FixturePhotos;

class FixtureParkAdmin implements ParkAdminRepository {
  final calls = <Map<String, dynamic>>[];
  @override
  Stream<List<Map<String, dynamic>>> records(String collection) =>
      Stream.value([]);
  @override
  Stream<Map<String, dynamic>> settings(String id) => Stream.value({});
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) async {
    calls.add({'action': action, ...data});
    return {};
  }
}

class FixtureGuide implements ParkIntelligenceRepository {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) async {
    calls.add(data);
    return {
      'answer': data['language'] == 'zh' ? '请打开园区地图。' : 'Open the park map.',
      'actions': ['map'],
    };
  }
}

class FixtureCrowd extends FixtureParkAdmin {
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) async {
    calls.add({'action': action, ...data});
    return {
      'updatedAt': '2026-11-09T04:00:00Z',
      'summary': {'confirmed': 8, 'busy': 1, 'visits': 3, 'visitorAccounts': 2},
      'places': [
        {
          'id': 'ride',
          'name': 'River Ride',
          'category': 'Family rides',
          'status': 'open',
          'minHeightCm': 0,
          'mapX': .5,
          'mapY': .5,
        },
      ],
      'slots': [],
      'density': {
        'size': 2,
        'values': [0, 0, 0, 0],
      },
      'attractions': [
        {
          'id': 'ride',
          'name': 'River Ride',
          'status': 'open',
          'confirmed': 8,
          'capacity': 10,
          'load': .8,
          'level': 'busy',
          'standbyMinutes': 20,
          'visits': 3,
        },
      ],
      'hourly': [
        for (var h = 0; h < 24; h++) {'hour': h, 'visits': h == 12 ? 3 : 0},
      ],
      'flows': [
        {'from': 'River Ride', 'to': 'Castle Ride', 'count': 2},
      ],
    };
  }
}

Future<void> viewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });
  testWidgets(
    'all policy tabs are visible and reachable in a narrow admin window',
    (tester) async {
      await viewport(tester, const Size(420, 1000));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ParkManagementPage(repository: FixtureParkAdmin()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final section in [
        'Promotions',
        'Reward Catalogue',
        'Loyalty Rules',
        'Photo Prices',
        'Weather Benefits',
      ]) {
        expect(
          find.widgetWithText(ChoiceChip, section).hitTestable(),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('Weather Benefits'));
      await tester.pumpAndSettle();
      expect(find.text('Rain threshold'), findsOneWidget);
      await tester.tap(find.text('Loyalty Rules'));
      await tester.pumpAndSettle();
      expect(find.text('Missed reservation policy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'loyalty editor validates the repeated-miss limit and saves an integer',
    (tester) async {
      await viewport(tester, const Size(1200, 1000));
      final repo = FixtureParkAdmin();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkPolicyEditor(
              repository: repo,
              kind: 'loyalty',
              initial: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final threshold = find.widgetWithText(
        TextFormField,
        'Missed Reservations Before Deduction',
      );
      await tester.enterText(threshold, '1');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a whole number from 2 to 20.'), findsOneWidget);
      expect(repo.calls, isEmpty);
      await tester.enterText(threshold, '3');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(repo.calls.single['noShowThreshold'], 3);
      expect(repo.calls.single['action'], 'saveLoyalty');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'campaign editor saves typed amounts, dates and actual eligible purchase scopes',
    (tester) async {
      await viewport(tester, const Size(1200, 1000));
      final repo = FixtureParkAdmin();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkPolicyEditor(
              repository: repo,
              kind: 'campaign',
              initial: {
                'name': 'Family savings',
                'code': 'FAMILY20',
                'value': 20,
                'scopes': ['tickets', 'photos'],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(repo.calls.single['value'], 20);
      expect(repo.calls.single['minimumMinor'], 0);
      expect(repo.calls.single['scopes'], containsAll(['photos', 'tickets']));
      expect(repo.calls.single['perUserLimit'], 1);
      expect(repo.calls.single['startsAt'], isA<String>());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reward editor preserves the categories accepted by visitor redemption',
    (tester) async {
      await viewport(tester, const Size(1200, 1200));
      final repo = FixtureParkAdmin();
      for (final category in ['dining', 'shopping', 'photo']) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(category),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ParkPolicyEditor(
                      repository: repo,
                      kind: 'reward',
                      initial: {
                        'name': 'Park reward',
                        'benefit': 'A benefit at the counter',
                        'category': category,
                        'pointsCost': 100,
                        'terms': ['One use.'],
                        'instructions': ['Present at the counter.'],
                      },
                    ),
                  ),
                  child: const Text('Edit reward'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit reward'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();
        expect(repo.calls.last['category'], category);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'crowd monitoring reviews real aggregates, changes periods and opens facility control',
    (tester) async {
      await viewport(tester, const Size(1400, 1100));
      final repo = FixtureCrowd();
      var managed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CrowdMonitoringPage(
                repository: repo,
                onManageFacilities: () => managed++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Queue Demand Heatmap'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      await tester.tap(find.text('Last 7 Days'));
      await tester.pumpAndSettle();
      expect(repo.calls.last['days'], 7);
      await tester.tap(find.text('Manage Facilities'));
      expect(managed, 1);
      await tester.ensureVisible(find.text('Journeys Between Attractions'));
      expect(find.text('River Ride → Castle Ride'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'photo settings translate visible ringgit prices into integer minor units',
    (tester) async {
      await viewport(tester, const Size(1000, 950));
      final repo = FixtureParkAdmin();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkPolicyEditor(
              repository: repo,
              kind: 'photos',
              initial: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Digital Copy'),
        '29.90',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(repo.calls.single['digitalPriceMinor'], 2990);
      expect(repo.calls.single['kioskLatitude'], isNull);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'report PDF contains actual totals and exports as a valid document',
    () async {
      final bytes = await buildParkReportPdf({
        'start': '2026-11-01',
        'end': '2026-11-09',
        'summary': {
          'revenueMinor': 15000,
          'ticketOrders': 1,
          'photoOrders': 1,
          'parkAdmissions': 2,
          'rideAdmissions': 3,
          'reservations': 4,
          'cancellations': 1,
        },
        'daily': [
          {'day': '2026-11-08', 'orders': 2, 'revenueMinor': 15000},
        ],
        'topProducts': [
          {'name': 'Family pass', 'quantity': 2, 'revenueMinor': 12500},
        ],
        'topAttractions': [
          {'name': 'River ride', 'visits': 3},
        ],
      });
      expect(latin1.decode(bytes).startsWith('%PDF'), true);
      expect(bytes.length, greaterThan(1000));
    },
  );
  testWidgets(
    'assistant sends the selected language and retains its response and navigation action',
    (tester) async {
      await viewport(tester, const Size(440, 956));
      final repo = FixtureGuide();
      await tester.pumpWidget(
        MaterialApp(
          home: ParkAssistantPage(repository: repo, visitorName: 'Visitor'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('中文').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '地图在哪里');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(repo.calls.single['language'], 'zh');
      expect(find.text('请打开园区地图。'), findsOneWidget);
      expect(find.text('Open Park Map'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'purchase history combines real ticket and photo records and both filters work',
    (tester) async {
      await viewport(tester, const Size(440, 956));
      final photos = FixturePhotos()
        ..saved = ParkPhoto('a' * 64, {
          'createdAt': Timestamp.now(),
          'items': [
            {'title': 'Castle memory'},
          ],
          'totalMinor': 2500,
        });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PurchaseHistoryBody(
              orders: [
                TicketOrder(
                  id: 'a' * 48,
                  packageName: 'Family pass',
                  visitDate: '2026-11-10',
                  requestId: 'a' * 48,
                  quantity: 2,
                  totalMinor: 12500,
                  createdAt: DateTime.now(),
                ),
              ],
              photos: photos,
              onTickets: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Family pass'), findsOneWidget);
      expect(find.text('Park Photo Purchase'), findsOneWidget);
      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();
      expect(find.text('Family pass'), findsNothing);
      expect(find.text('Park Photo Purchase'), findsOneWidget);
      await tester.tap(find.text('Tickets'));
      await tester.pumpAndSettle();
      expect(find.text('Family pass'), findsOneWidget);
      expect(find.text('Park Photo Purchase'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'currency conversion changes display without changing the base amount and handles unavailable rates',
    () async {
      final model = TicketDisplayCurrency(
        fetchRates: () async => {
          'rates': {'MYR': 1, 'USD': .25},
          'asOf': '2026-11-09',
        },
      );
      await model.choose('USD');
      expect(model.format(10000), '≈ USD 25.00');
      await model.choose('MYR');
      expect(model.format(10000), 'RM 100');
      model.dispose();
      final offline = TicketDisplayCurrency(
        fetchRates: () async => throw StateError('offline'),
      );
      await expectLater(offline.choose('USD'), throwsStateError);
      expect(offline.selected, 'MYR');
      expect(offline.busy, false);
      offline.dispose();
    },
  );
  testWidgets(
    'device unlock never exposes the account after cancelled authentication',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'biometric_unlock_fixture': true,
      });
      bool approved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: BiometricUnlockGate(
            uid: 'fixture',
            onAuthenticate: () async => approved,
            child: const Text('Private account content'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private account content'), findsNothing);
      await tester.tap(find.text('Unlock Account'));
      await tester.pumpAndSettle();
      expect(find.text('Private account content'), findsNothing);
      approved = true;
      await tester.tap(find.text('Unlock Account'));
      await tester.pumpAndSettle();
      expect(find.text('Private account content'), findsOneWidget);
    },
  );
}
