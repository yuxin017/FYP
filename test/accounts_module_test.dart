import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:collaborative_asg/accounts/account_repository.dart';
import 'package:collaborative_asg/accounts/recovery_pages.dart';
import 'package:collaborative_asg/accounts/security_pages.dart';
import 'package:collaborative_asg/visitor/pages/profile_settings_page.dart';
import 'package:collaborative_asg/visitor/pages/personal_information_page.dart';
import 'package:collaborative_asg/visitor/pages/preferences_page.dart';
import 'package:collaborative_asg/visitor/pages/security_account_page.dart';

class FixtureAccount extends AccountRepository {
  AccountIdentity user = const AccountIdentity(
    'fixture-account',
    'visitor@example.com',
  );
  Map<String, dynamic> data = {
    'fullName': 'Alice Visitor',
    'email': 'visitor@example.com',
    'phoneNumber': '+60123456789',
    'heightCm': 165,
    'foodPreferences': ['Halal'],
    'parkInterests': ['Thrill rides'],
    'dateOfBirth': '2002-05-18',
    'gender': 'Female',
  };
  final changes = StreamController<Map<String, dynamic>?>.broadcast();
  Map<String, dynamic>? saved;
  int sends = 0, resets = 0, closed = 0, revoked = 0, created = 0;
  String? resetCode;
  bool verifiedNewEmail = false;
  @override
  AccountIdentity get identity => user;
  @override
  Stream<Map<String, dynamic>?> profile() async* {
    yield data;
    yield* changes.stream;
  }

  @override
  Future<void> save(
    Map<String, dynamic> base,
    Map<String, dynamic> updates,
  ) async {
    saved = Map.from(updates);
    data = {...data, ...updates};
    changes.add(data);
  }

  @override
  Future<void> createProfile(String name, String phone) async {
    created++;
    data = {...data, 'fullName': name, 'phoneNumber': phone};
    changes.add(data);
  }

  @override
  Future<void> resetEmail(String email) async {
    sends++;
  }

  @override
  Future<String> verifyReset(String code) async {
    if (code != 'real-fixture-code') throw StateError('This link has expired.');
    resetCode = code;
    return user.email;
  }

  @override
  Future<void> confirmReset(String code, String password) async {
    resets++;
    resetCode = code;
  }

  @override
  Future<void> reauthenticate(String password) async {
    if (password != 'Current123!') {
      throw StateError('The password is incorrect. Please try again.');
    }
  }

  @override
  Future<void> changeEmail(String email, String password) async {
    await reauthenticate(password);
    sends++;
  }

  @override
  Future<String> refreshEmail() async {
    if (verifiedNewEmail) {
      user = const AccountIdentity('fixture-account', 'new@example.com');
    }
    return user.email;
  }

  @override
  Future<void> changePassword(String current, String next) async {
    await reauthenticate(current);
    resets++;
  }

  @override
  Future<List<Map<String, dynamic>>> sessions() async => [
    {
      'sessionId': 'current',
      'deviceName': 'Chrome · Windows',
      'lastSeenAt': '2026-11-07T02:00:00Z',
    },
    {
      'sessionId': 'other',
      'deviceName': 'Edge · Windows',
      'lastSeenAt': '2026-11-06T12:00:00Z',
    },
  ];
  @override
  Future<String?> currentSessionId() async => 'current';
  @override
  Future<void> revokeSessions(String password) async {
    await reauthenticate(password);
    revoked++;
  }

  @override
  Future<void> close(String password) async {
    await reauthenticate(password);
    closed++;
  }

  @override
  Future<void> signOut() async {}
}

final proof = GlobalKey();
Future<void> app(WidgetTester t, Widget page, {double width = 440}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 956);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFAD7472)),
      ),
      builder: (context, child) => RepaintBoundary(key: proof, child: child!),
      home: page,
    ),
  );
  await t.pumpAndSettle();
}

Future<void> visible(WidgetTester t, Finder target, {bool up = false}) async {
  if (target.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      target,
      up ? -250 : 250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 20,
    );
  } else {
    await t.ensureVisible(target);
  }
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder target, {bool up = false}) async {
  await visible(t, target, up: up);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> shot(WidgetTester t, String name) async {
  await t.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await t.pumpAndSettle();
  final boundary =
      proof.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.local/accounts-qa').create(recursive: true);
    await File(
      '.local/accounts-qa/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
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
    'profile validation accepts real names, bounds fields and crops avatars',
    () {
      expect(nameError('李 O’Connor'), isNull);
      expect(nameError('x'), isNotNull);
      expect(phoneError('+60123456789'), isNull);
      expect(passwordError('short'), isNotNull);
      expect(
        profileCompletion({
          'fullName': 'Alice',
          'email': 'alice@example.com',
          'phoneNumber': '123456789',
        }),
        0.6,
      );
      final image = img.Image(width: 400, height: 200);
      final result = prepareAvatar(Uint8List.fromList(img.encodePng(image)));
      final decoded = img.decodeJpg(result)!;
      expect(decoded.width, 200);
      expect(decoded.height, 200);
    },
  );
  testWidgets(
    'settings retain the Figma sections and open detailed preferences',
    (t) async {
      final repo = FixtureAccount();
      await app(t, ProfileSettingsPage(repository: repo));
      expect(find.text('Profile 100% complete'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Security & Account'), findsOneWidget);
      await shot(t, 'settings');
      await tap(t, find.text('Preferences & Interests'));
      expect(find.text('About You'), findsOneWidget);
      expect(find.text('Park Interests'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      await shot(t, 'preferences');
    },
  );
  testWidgets(
    'preferences save nickname, exclusive food choices and preserve compatible interests',
    (t) async {
      final repo = FixtureAccount();
      await app(t, PreferencesPage(repository: repo));
      await t.enterText(find.byType(TextField).first, 'Ally');
      await tap(t, find.text('All', skipOffstage: false));
      await tap(t, find.text('Save Preferences'));
      expect(repo.saved!['nickname'], 'Ally');
      expect(repo.saved!['foodPreferences'], ['No preference']);
      expect(repo.data['parkInterests'], ['Thrill rides']);
      expect(find.text('Preferences saved.'), findsOneWidget);
    },
  );
  testWidgets(
    'personal information edits validate and leaving unsaved changes asks before discarding',
    (t) async {
      final repo = FixtureAccount();
      await app(t, PersonalInformationPage(repository: repo));
      await shot(t, 'personal');
      await tap(t, find.byTooltip('Edit Full Name'));
      await t.enterText(find.byType(TextFormField), '李 O’Connor');
      await tap(t, find.text('Done'));
      await tap(t, find.byTooltip('Back'));
      expect(find.text('Discard changes?'), findsOneWidget);
      await tap(t, find.text('Keep Editing'));
      await tap(t, find.text('Save Changes'));
      expect(repo.saved!['fullName'], '李 O’Connor');
      expect(repo.data['email'], 'visitor@example.com');
      await tap(t, find.byTooltip('Edit Phone Number'));
      await t.enterText(find.byType(TextFormField), 'bad');
      await tap(t, find.text('Done'));
      expect(
        find.text('Use a phone number such as +60123456789.'),
        findsOneWidget,
      );
      await tap(t, find.text('Cancel'));
    },
  );
  testWidgets(
    'security follows the Figma cards and password changes require a matching confirmation',
    (t) async {
      final repo = FixtureAccount();
      await app(t, SecurityAccountPage(repository: repo));
      await shot(t, 'security');
      await tap(t, find.text('Reset Password'));
      await t.enterText(find.byType(TextFormField).at(0), 'Current123!');
      await t.enterText(find.byType(TextFormField).at(1), 'NextPassword123!');
      await t.enterText(find.byType(TextFormField).at(2), 'mismatch');
      await tap(t, find.widgetWithText(FilledButton, 'Reset Password'));
      expect(repo.resets, 0);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await t.enterText(find.byType(TextFormField).at(2), 'NextPassword123!');
      await tap(t, find.widgetWithText(FilledButton, 'Reset Password'));
      expect(repo.resets, 1);
      expect(find.text('Your password has been updated'), findsOneWidget);
    },
  );
  testWidgets(
    'email change waits for actual verification before reporting success',
    (t) async {
      final repo = FixtureAccount();
      await app(t, EmailChangePage(repository: repo));
      await t.enterText(find.byType(TextFormField).at(0), 'new@example.com');
      await t.enterText(find.byType(TextFormField).at(1), 'Current123!');
      await tap(t, find.text('Send Verification Link'));
      expect(repo.sends, 1);
      await tap(t, find.text('I Have Verified My Email'));
      expect(find.textContaining('has not been verified yet'), findsOneWidget);
      repo.verifiedNewEmail = true;
      await tap(t, find.text('I Have Verified My Email'));
      expect(find.text('Email updated'), findsOneWidget);
    },
  );
  testWidgets(
    'password recovery uses an actual reset link and validates the new password',
    (t) async {
      final repo = FixtureAccount();
      await app(t, PasswordRecoveryPage(repository: repo));
      await t.enterText(find.byType(TextFormField), 'visitor@example.com');
      await tap(t, find.widgetWithText(FilledButton, 'Reset Password'));
      expect(repo.sends, 1);
      await t.enterText(
        find.byType(TextField).last,
        'https://example.test/action?mode=resetPassword&oobCode=real-fixture-code',
      );
      await tap(t, find.text('Continue'));
      expect(repo.resetCode, 'real-fixture-code');
      await t.enterText(find.byType(TextFormField).at(0), 'NextPassword123!');
      await t.enterText(find.byType(TextFormField).at(1), 'NextPassword123!');
      await tap(t, find.widgetWithText(FilledButton, 'Reset Password'));
      expect(repo.resets, 1);
      expect(find.text('Password Updated'), findsOneWidget);
    },
  );
  testWidgets(
    'delete account is disabled until explicit confirmation and password entry',
    (t) async {
      final repo = FixtureAccount();
      await app(t, DeleteAccountPage(repository: repo), width: 360);
      await shot(t, 'delete');
      await visible(t, find.text('Delete My Account'));
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Delete My Account'),
            )
            .onPressed,
        isNull,
      );
      await tap(t, find.byType(Checkbox), up: true);
      await t.enterText(find.byType(TextField).first, 'DELETE');
      await tap(t, find.text('Delete My Account'));
      expect(repo.closed, 0);
      expect(find.text('Enter your current password.'), findsOneWidget);
      await t.enterText(find.byType(TextFormField), 'Current123!');
      await tap(t, find.text('Delete My Account'));
      expect(repo.closed, 1);
    },
  );
  testWidgets(
    'device management lists actual records and requires password confirmation before revocation',
    (t) async {
      final repo = FixtureAccount();
      await app(t, LoginSecurityPage(repository: repo));
      expect(find.text('Chrome · Windows'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
      await shot(t, 'sessions');
      await tap(t, find.text('Sign Out All Devices'));
      await t.enterText(find.byType(TextFormField), 'wrong');
      await tap(t, find.text('Confirm Sign Out Everywhere'));
      expect(repo.revoked, 0);
      expect(find.textContaining('password is incorrect'), findsOneWidget);
      await t.enterText(find.byType(TextFormField), 'Current123!');
      await tap(t, find.text('Confirm Sign Out Everywhere'));
      expect(repo.revoked, 1);
    },
  );
  testWidgets(
    'interrupted account setup has a genuine profile completion flow',
    (t) async {
      final repo = FixtureAccount();
      await app(t, CompleteProfilePage(repository: repo));
      await tap(t, find.text('Save and Continue'));
      expect(repo.created, 0);
      await t.enterText(find.byType(TextFormField).at(0), 'New Visitor');
      await t.enterText(find.byType(TextFormField).at(1), '+60123456789');
      await tap(t, find.text('Save and Continue'));
      expect(repo.created, 1);
    },
  );
}
