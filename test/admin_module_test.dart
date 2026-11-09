import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaborative_asg/admin/admin_models.dart';
import 'package:collaborative_asg/admin/admin_repository.dart';
import 'package:collaborative_asg/admin/admin_portal.dart';
import 'package:collaborative_asg/admin/admin_shell.dart';
import 'package:collaborative_asg/visitor/models/tickets.dart';

class FixtureAdmin extends AdminRepository {
  @override
  String get userId => 'fixture-admin';
  PackageDraft? savedPackage;
  int admissionCalls = 0;
  final visitorList = [
    AdminVisitor('visitor-alice', {
      'fullName': 'Alice Visitor',
      'email': 'alice@example.com',
      'phoneNumber': '+60123456789',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
      'loyaltyPoints': 350,
      'heightCm': 165,
    }),
    const AdminVisitor('visitor-bob', {
      'fullName': 'Bob Visitor',
      'email': 'bob@example.com',
    }),
  ];
  final ticket = ParkTicket(
    id: '${'a' * 48}_1',
    orderId: 'a' * 48,
    packageName: '1-Day Theme Park Pass',
    visitDate: visitDateString(parkToday()),
    status: 'valid',
    guestName: 'Alice Visitor',
    ownerUid: 'visitor-alice',
  );
  @override
  Stream<List<AdminVisitor>> visitors() => Stream.value(visitorList);
  @override
  Stream<List<AdminPackage>> packages() => Stream.value(const [
    AdminPackage('general-admission', {
      'name': '1-Day Theme Park Pass',
      'description': 'A day of park adventures.',
      'priceMinor': 14000,
      'childPriceMinor': 11000,
      'currency': 'MYR',
      'active': true,
      'category': 'day',
      'durationDays': 1,
      'sortOrder': 1,
    }),
  ]);
  @override
  Stream<List<ParkTicket>> tickets() => Stream.value([ticket]);
  @override
  Stream<List<TicketOrder>> orders() => Stream.value([]);
  @override
  Future<void> saveVisitor(
    AdminVisitor visitor,
    Map<String, dynamic> fields,
    Map<String, dynamic> metadata,
  ) async {}
  @override
  Future<void> setVisitorStatus(
    List<String> ids,
    String status,
    String reason,
  ) async {}
  @override
  Future<void> setWatchlist(List<AdminVisitor> visitors, bool enabled) async {}
  @override
  Future<void> savePackage(String? id, PackageDraft draft) async {
    savedPackage = draft;
  }

  @override
  Future<ParkTicket> findTicket(String code) async {
    if (code != ticket.id && code != ticket.qrData) {
      throw StateError('Ticket not found.');
    }
    return ticket;
  }

  @override
  Future<AdmissionResult> admit(String ticketId, String requestId) async {
    admissionCalls++;
    return AdmissionResult(
      'accepted',
      'Admission confirmed. Welcome to the park!',
      ticket,
    );
  }
}

Future<void> openAdmin(
  WidgetTester tester,
  FixtureAdmin repository, {
  Size size = const Size(1512, 982),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Theme(
          data: adminTheme(context),
          child: RepaintBoundary(
            key: const Key('admin-proof'),
            child: AdminShell(
              repository: repository,
              adminName: 'Park Administrator',
              adminEmail: 'admin@example.com',
              onSignOut: () async {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('admin-proof')),
  );
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 1);
    final data = await picture.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.local/admin-qa').create(recursive: true);
    await File(
      '.local/admin-qa/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    picture.dispose();
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
    if (fonts == null) {
      throw StateError(
        'Flutter material fonts were not found for visual checks.',
      );
    }
    for (final item in <String, List<String>>{
      'Roboto': ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'],
      'MaterialIcons': ['materialicons-regular.otf'],
    }.entries) {
      final loader = FontLoader(item.key);
      for (final name in item.value) {
        loader.addFont(
          File('${fonts.path}/$name').readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
  });
  test(
    'money parsing uses exact minor units and CSV protects spreadsheet cells',
    () {
      expect(parseMoneyMinor('150.50'), 15050);
      expect(parseMoneyMinor('1.01'), 101);
      expect(parseMoneyMinor('0'), isNull);
      expect(parseMoneyMinor('1.001'), isNull);
      final csv = csvContent(
        ['Name', 'Email'],
        [
          ['=1+1', 'a,"b"@example.com'],
        ],
      );
      expect(csv, contains("'=1+1"));
      expect(csv, contains('a,""b""@example.com'));
    },
  );
  test(
    'multi-day passes show used today and become upcoming on another valid day',
    () {
      final today = parkToday(), key = visitDateString(today);
      final end = visitDateString(today.add(const Duration(days: 2)));
      ParkTicket ticket(List<DateTime> days) => ParkTicket(
        id: 'a' * 48,
        orderId: 'a' * 48,
        packageName: '3-Day Pass',
        visitDate: key,
        validUntil: end,
        status: 'valid',
        admissionDays: days,
      );
      expect(
        ticket([DateTime.utc(today.year, today.month, today.day)]).filter,
        'Used',
      );
      expect(
        ticket([
          DateTime.utc(
            today.year,
            today.month,
            today.day,
          ).subtract(const Duration(days: 1)),
        ]).filter,
        'Upcoming',
      );
    },
  );
  testWidgets('visitor search and profile follow separate admin screens', (
    tester,
  ) async {
    await openAdmin(tester, FixtureAdmin());
    expect(find.text('Visitor Accounts'), findsOneWidget);
    expect(find.text('Alice Visitor'), findsOneWidget);
    await capture(tester, 'visitors');
    await tester.tap(find.text('Visitor'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Bob Visitor')).dy,
      lessThan(tester.getTopLeft(find.text('Alice Visitor')).dy),
    );
    await tester.enterText(
      find.byKey(const Key('visitor-search')),
      'alice@example.com',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bob Visitor'), findsNothing);
    await tester.tap(find.text('Alice Visitor'));
    await tester.pumpAndSettle();
    expect(find.text('VISITOR PROFILE DETAILS'), findsOneWidget);
    expect(find.text('350'), findsOneWidget);
    await capture(tester, 'visitor-profile');
    expect(tester.takeException(), isNull);
  });
  testWidgets('package edits preserve exact adult and child fares', (
    tester,
  ) async {
    final repo = FixtureAdmin();
    await openAdmin(tester, repo);
    await tester.tap(find.text('Pass Packages').first);
    await tester.pumpAndSettle();
    await capture(tester, 'packages');
    await tester.tap(find.text('Edit Pass'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Adult Fare (RM)'),
      '150.50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Child Fare (RM)'),
      '120',
    );
    await tester.tap(find.text('Save Package'));
    await tester.pumpAndSettle();
    expect(repo.savedPackage!.priceMinor, 15050);
    expect(repo.savedPackage!.childPriceMinor, 12000);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'ticket validation previews first and prevents a duplicate admit tap',
    (tester) async {
      final repo = FixtureAdmin();
      await openAdmin(tester, repo);
      for(int i=0;i<20 && find.text('Ticket Validation').hitTestable().evaluate().isEmpty;i++){
        await tester.drag(find.byKey(const Key('admin-sidebar-list')),const Offset(0,-120));await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Ticket Validation').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'TP-… or ticket QR value'),
        repo.ticket.id,
      );
      await tester.tap(find.text('Find Ticket'));
      await tester.pumpAndSettle();
      expect(repo.admissionCalls, 0);
      expect(find.text('Alice Visitor'), findsOneWidget);
      await capture(tester, 'admission');
      await tester.ensureVisible(find.text('Admit Visitor'));
      await tester.tap(find.text('Admit Visitor'));
      await tester.pumpAndSettle();
      expect(repo.admissionCalls, 1);
      await tester.tap(find.text('Admission Confirmed'));
      await tester.pump();
      expect(repo.admissionCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('compact admin layout uses a drawer and retains usable tables', (
    tester,
  ) async {
    await openAdmin(tester, FixtureAdmin(), size: const Size(420, 900));
    expect(find.byTooltip('Open admin navigation'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Open admin navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    await tester.tap(find.text('Pass Packages').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'admin sign-in preserves Figma layout and validates missing credentials',
    (tester) async {
      tester.view.physicalSize = const Size(1512, 982);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Theme(
              data: adminTheme(context),
              child: AdminLoginPage(
                onSignIn: (e, p, r) async {
                  calls++;
                },
                onReset: ({required String email}) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign In Securely'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
