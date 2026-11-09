import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collaborative_asg/support/support_attachment.dart';
import 'package:collaborative_asg/support/support_models.dart';
import 'package:collaborative_asg/support/support_page.dart';
import 'package:collaborative_asg/support/support_repository.dart';
import 'package:collaborative_asg/admin/admin_portal.dart';
import 'package:collaborative_asg/admin/admin_shell.dart';
import 'admin_module_test.dart' show FixtureAdmin;

class FixtureSupport extends SupportRepository {
  bool admin = false, loggedOut = false, loseAcknowledgement = false;
  int submitCalls = 0, creations = 0, replyCalls = 0, noteCalls = 0;
  List<SupportCase> saved = [];
  List<SupportMessage> posted = [], privateNotes = [];
  List<SupportEvent> history = [];
  final caseChanges = StreamController<List<SupportCase>>.broadcast(),
      messageChanges = StreamController<List<SupportMessage>>.broadcast(),
      noteChanges = StreamController<List<SupportMessage>>.broadcast(),
      eventChanges = StreamController<List<SupportEvent>>.broadcast();
  FixtureSupport({bool seed = false}) {
    if (seed) {
      saved = [
        SupportCase('a' * 48, {
          'ownerUid': 'fixture-visitor',
          'ownerName': 'Alice Visitor',
          'type': 'problem',
          'category': 'Tickets & Admission',
          'subject': 'Lost ticket help',
          'message': 'Please help me find the ticket for my visit.',
          'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          'updatedAt': Timestamp.now(),
          'status': 'new',
          'priority': 'medium',
          'assigneeUid': '',
          'assigneeName': '',
          'orderId': '',
          'contactEmail': '',
          'messageCount': 0,
          'firstResponseAt': null,
          'resolvedAt': null,
          'resolution': '',
        }),
      ];
    }
  }
  @override
  String? get userId => loggedOut
      ? null
      : admin
      ? 'fixture-admin'
      : 'fixture-visitor';
  @override
  bool get isAdmin => admin;
  @override
  Stream<List<SupportCase>> cases() async* {
    yield saved;
    yield* caseChanges.stream;
  }

  @override
  Stream<List<SupportMessage>> messages(String id) async* {
    yield posted.where((m) => m.data['caseId'] == id).toList();
    yield* messageChanges.stream.map(
      (list) => list.where((m) => m.data['caseId'] == id).toList(),
    );
  }

  @override
  Stream<List<SupportMessage>> notes(String id) async* {
    yield privateNotes;
    yield* noteChanges.stream;
  }

  @override
  Stream<List<SupportEvent>> events(String id) async* {
    yield history;
    yield* eventChanges.stream;
  }

  @override
  Future<SupportCase?> findCase(String id) async =>
      saved.where((r) => r.id == id).firstOrNull;
  @override
  Future<SupportCase> submit(String id, SupportDraft draft) async {
    submitCalls++;
    final previous = await findCase(id);
    if (previous != null) return previous;
    final record = SupportCase(id, {
      ...draft.toMap(),
      'attachment': draft.attachment?.metadata,
      'fingerprint': draft.fingerprint,
      'ownerUid': userId,
      'ownerName': 'Alice Visitor',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'status': 'new',
      'priority': 'medium',
      'assigneeUid': '',
      'assigneeName': '',
      'firstResponseAt': null,
      'resolvedAt': null,
      'resolution': '',
      'messageCount': 0,
    });
    creations++;
    saved = [record, ...saved];
    caseChanges.add(saved);
    if (loseAcknowledgement) {
      loseAcknowledgement = false;
      throw StateError(
        'Connection interrupted before confirmation. Please retry.',
      );
    }
    return record;
  }

  void patch(String id, Map<String, dynamic> patch) {
    saved = saved
        .map(
          (r) => r.id == id
              ? SupportCase(id, {
                  ...r.data,
                  ...patch,
                  'updatedAt': Timestamp.now(),
                })
              : r,
        )
        .toList();
    caseChanges.add(saved);
  }

  @override
  Future<void> reply(SupportCase record, String id, String body) async {
    if (body.trim().length < 2) {
      throw StateError('Enter a reply between 2 and 2,000 characters.');
    }
    replyCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    posted = [
      ...posted,
      SupportMessage(id, {
        'caseId': record.id,
        'body': body.trim(),
        'role': admin ? 'admin' : 'visitor',
        'authorName': admin ? 'Park Support' : 'Alice Visitor',
        'createdAt': Timestamp.now(),
      }),
    ];
    messageChanges.add(posted);
    patch(record.id, {
      'messageCount': posted.length,
      if (admin) 'status': 'in_progress',
      if (admin) 'firstResponseAt': Timestamp.now(),
    });
  }

  @override
  Future<void> note(SupportCase record, String id, String body) async {
    noteCalls++;
    privateNotes = [
      ...privateNotes,
      SupportMessage(id, {
        'caseId': record.id,
        'body': body,
        'role': 'admin',
        'authorName': 'Park Support',
        'createdAt': Timestamp.now(),
      }),
    ];
    noteChanges.add(privateNotes);
  }

  @override
  Future<void> updateCase(
    SupportCase record, {
    required String status,
    required String priority,
    required String category,
    required String assigneeUid,
    required String assigneeName,
    String resolution = '',
  }) async {
    patch(record.id, {
      'status': status,
      'priority': priority,
      'category': category,
      'assigneeUid': assigneeUid,
      'assigneeName': assigneeName,
      'resolution': resolution,
      'resolvedAt': status == 'resolved' ? Timestamp.now() : null,
    });
    history = [
      ...history,
      SupportEvent(newSupportId(), {
        'action': status == 'resolved' ? 'resolved' : 'updated',
        'actorName': 'Park Support',
        'createdAt': Timestamp.now(),
      }),
    ];
    eventChanges.add(history);
  }

  @override
  Future<void> reopen(SupportCase record) async {
    patch(record.id, {
      'status': 'in_progress',
      'resolvedAt': null,
      'resolution': '',
    });
    history = [
      ...history,
      SupportEvent(newSupportId(), {
        'action': 'reopened',
        'actorName': 'Alice Visitor',
        'createdAt': Timestamp.now(),
      }),
    ];
    eventChanges.add(history);
  }

  @override
  Future<SupportAttachment> attachment(SupportCase record) async =>
      SupportAttachment(
        'details.pdf',
        'application/pdf',
        Uint8List.fromList(utf8.encode('%PDF-1.4\nattachment')),
      );
  Future<void> close() async {
    await caseChanges.close();
    await messageChanges.close();
    await noteChanges.close();
    await eventChanges.close();
  }
}

class FixtureSupportAdmin extends FixtureAdmin {
  final FixtureSupport support;
  FixtureSupportAdmin(this.support);
  @override
  SupportRepository get supportRepository => support;
}

Future<void> size(WidgetTester tester, Size value) async {
  tester.view.physicalSize = value;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> openSupport(
  WidgetTester tester,
  FixtureSupport repository, {
  String section = 'home',
  Size viewport = const Size(440, 956),
}) async {
  await size(tester, viewport);
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: const Key('support-proof'),
        child: SupportPage(repository: repository, initialSection: section),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> captureSupport(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('support-proof')),
  );
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 1);
    final data = await picture.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.local/support-qa').create(recursive: true);
    await File(
      '.local/support-qa/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    picture.dispose();
  });
}

Future<void> visible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
    'attachments enforce file formats and limits; response targets skip weekends',
    () {
      final pdf = prepareSupportAttachment(
        '../details.pdf',
        Uint8List.fromList(utf8.encode('%PDF-1.4\nDetails\n%%EOF')),
      );
      expect(pdf.name.contains('/'), false);
      expect(pdf.mime, 'application/pdf');
      final png = img.encodePng(img.Image(width: 12, height: 12));
      expect(prepareSupportAttachment('photo.png', png).mime, 'image/png');
      expect(
        () => prepareSupportAttachment(
          'bad.png',
          Uint8List.fromList(utf8.encode('<html>not an image</html>')),
        ),
        throwsStateError,
      );
      final large = Uint8List(512001)..setRange(0, 5, utf8.encode('%PDF-'));
      expect(
        () => prepareSupportAttachment('large.pdf', large),
        throwsStateError,
      );
      expect(
        supportDueDate(DateTime.utc(2026, 11, 6, 2)),
        DateTime.utc(2026, 11, 13, 16),
      );
      expect(
        supportDueDate(DateTime.utc(2026, 11, 7, 2)),
        DateTime.utc(2026, 11, 13, 16),
      );
    },
  );
  testWidgets(
    'help retains the Figma sections and routes to the full guides and FAQs',
    (tester) async {
      final repo = FixtureSupport();
      addTearDown(repo.close);
      await openSupport(tester, repo);
      expect(find.text('Learn & Explore'), findsOneWidget);
      expect(find.text('Contact Us'), findsOneWidget);
      await captureSupport(tester, 'help');
      await tester.tap(find.text('Tutorials & User Guides'));
      await tester.pumpAndSettle();
      await captureSupport(tester, 'guides');
      await tester.tap(find.text('How to Log In'));
      await tester.pumpAndSettle();
      expect(find.text('Log in to your account'), findsOneWidget);
      await captureSupport(tester, 'guide-detail');
      await visible(tester, find.text('Next: Register'));
      await tester.tap(find.text('Next: Register'));
      await tester.pumpAndSettle();
      expect(find.text('Create an Account'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'FAQ search and categories find useful answers with working guide links',
    (tester) async {
      final repo = FixtureSupport();
      addTearDown(repo.close);
      await openSupport(tester, repo, section: 'faq');
      await captureSupport(tester, 'faq');
      await tester.enterText(find.byKey(const Key('support-search')), 'forgot');
      await tester.pumpAndSettle();
      expect(
        find.text('What should I do if I forgot my password?'),
        findsOneWidget,
      );
      expect(find.text('How do I add a purchased ticket?'), findsNothing);
      await tester.tap(find.text('View related guide'));
      await tester.pumpAndSettle();
      expect(find.text('Reset a Forgotten Password'), findsWidgets);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('support-search')),
        'zzzz-no-match',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching questions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'submission validates, survives uncertain acknowledgement and returns one saved request',
    (tester) async {
      final repo = FixtureSupport()..loseAcknowledgement = true;
      addTearDown(repo.close);
      await openSupport(tester, repo, section: 'form');
      await captureSupport(tester, 'form');
      await visible(tester, find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 0);
      await tester.enterText(
        find.byKey(const Key('support-subject')),
        'Please help find my pass',
      );
      await tester.enterText(
        find.byKey(const Key('support-message')),
        'I need help finding the pass saved for my visit.',
      );
      await visible(tester, find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(repo.creations, 1);
      expect(find.text('Retry Submission'), findsOneWidget);
      final pending = await PendingSupportStore().load(repo.userId!);
      expect(pending, isNotNull);
      final id = pending!.id;
      await visible(tester, find.text('Retry Submission'));
      await tester.tap(find.text('Retry Submission'));
      await tester.pumpAndSettle();
      expect(repo.creations, 1);
      expect(repo.saved.single.id, id);
      expect(find.text('Thank you for reaching out'), findsOneWidget);
      expect(await PendingSupportStore().load(repo.userId!), isNull);
      await tester.tap(find.text('View My Request'));
      await tester.pumpAndSettle();
      expect(find.text('Please help find my pass'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pending drafts restore attachment and request ID across reopening',
    (tester) async {
      final repo = FixtureSupport();
      addTearDown(repo.close);
      final draft = SupportDraft(
        type: 'complaint',
        subject: 'Visit feedback',
        message: 'Please review the details of my visit.',
        attachment: prepareSupportAttachment(
          'details.pdf',
          Uint8List.fromList(utf8.encode('%PDF-1.4\nDetails')),
        ),
      );
      await PendingSupportStore().save(
        repo.userId!,
        PendingSupportSubmission('b' * 48, draft),
      );
      await openSupport(tester, repo, section: 'form');
      expect(find.text('Visit feedback'), findsOneWidget);
      expect(find.text('details.pdf'), findsOneWidget);
      expect(find.text('Retry Submission'), findsOneWidget);
      await visible(tester, find.text('Check Submission / Edit Draft'));
      await tester.tap(find.text('Check Submission / Edit Draft'));
      await tester.pumpAndSettle();
      expect(await PendingSupportStore().load(repo.userId!), isNull);
      expect(find.text('Submit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'visitor conversations append once and resolved requests reopen with their history',
    (tester) async {
      final repo = FixtureSupport(seed: true);
      addTearDown(repo.close);
      await openSupport(tester, repo, section: 'requests');
      await tester.tap(find.text('Lost ticket help'));
      await tester.pumpAndSettle();
      await captureSupport(tester, 'request');
      await visible(tester, find.byKey(const Key('support-reply')));
      await tester.enterText(
        find.byKey(const Key('support-reply')),
        'Here is my visit date.',
      );
      await visible(tester, find.text('Send Reply'));
      await tester.tap(find.text('Send Reply'));
      await tester.pumpAndSettle();
      expect(repo.replyCalls, 1);
      repo.patch(repo.saved.first.id, {
        'status': 'resolved',
        'resolution': 'The pass is available in My Tickets.',
        'resolvedAt': Timestamp.now(),
      });
      await tester.pumpAndSettle();
      await visible(tester, find.text('Reopen Request'));
      await tester.tap(find.text('Reopen Request'));
      await tester.pumpAndSettle();
      expect(repo.saved.first.status, 'in_progress');
      expect(find.text('Internal Notes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'public help is usable without an account and sending requests asks for sign-in',
    (tester) async {
      final repo = FixtureSupport()..loggedOut = true;
      addTearDown(repo.close);
      await openSupport(
        tester,
        repo,
        section: 'form',
        viewport: const Size(360, 800),
      );
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byKey(const Key('support-message')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'admin case workflow keeps notes private, sends replies and records resolutions',
    (tester) async {
      final repo = FixtureSupport(seed: true)..admin = true;
      addTearDown(repo.close);
      await size(tester, const Size(1512, 982));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Theme(
              data: adminTheme(context),
              child: RepaintBoundary(
                key: const Key('support-proof'),
                child: AdminShell(
                  repository: FixtureSupportAdmin(repo),
                  adminName: 'Park Support',
                  adminEmail: 'support@example.com',
                  onSignOut: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for(int i=0;i<20 && find.text('Feedback & Complaints').hitTestable().evaluate().isEmpty;i++){
        await tester.drag(find.byKey(const Key('admin-sidebar-list')),const Offset(0,-120));await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Feedback & Complaints'));
      await tester.pumpAndSettle();
      await captureSupport(tester, 'admin-inbox');
      await tester.tap(find.text('Lost ticket help'));
      await tester.pumpAndSettle();
      await captureSupport(tester, 'admin-case');
      await visible(tester, find.text('Internal Notes'));
      await tester.tap(find.text('Internal Notes'));
      await tester.pumpAndSettle();
      await visible(tester, find.byKey(const Key('support-note')));
      await tester.enterText(
        find.byKey(const Key('support-note')),
        'Private staff follow-up.',
      );
      await visible(tester, find.text('Save Internal Note'));
      await tester.tap(find.text('Save Internal Note'));
      await tester.pumpAndSettle();
      expect(repo.noteCalls, 1);
      expect(find.text('Private staff follow-up.'), findsOneWidget);
      await visible(tester, find.text('Details'));
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await visible(tester, find.byKey(const Key('support-reply')));
      await tester.enterText(
        find.byKey(const Key('support-reply')),
        'Your pass is available in My Tickets.',
      );
      await visible(tester, find.text('Send Reply'));
      await tester.tap(find.text('Send Reply'));
      await tester.pumpAndSettle();
      expect(repo.replyCalls, 1);
      expect(repo.saved.first.status, 'in_progress');
      await visible(tester, find.text('Resolve Case'));
      await tester.tap(find.text('Resolve Case'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('resolution-summary')),
        'The visitor can open their saved pass.',
      );
      await tester.tap(find.text('Confirm Resolution'));
      await tester.pumpAndSettle();
      expect(repo.saved.first.status, 'resolved');
      expect(
        repo.saved.first.resolution,
        'The visitor can open their saved pass.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
