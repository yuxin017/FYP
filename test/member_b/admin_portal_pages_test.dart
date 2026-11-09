import 'dart:async';

import 'package:collaborative_asg/admin/attractions/attractions_admin_page.dart';
import 'package:collaborative_asg/admin/auth/admin_sign_in_page.dart';
import 'package:collaborative_asg/admin/portal/admin_portal_shell.dart';
import 'package:collaborative_asg/admin/portal/admin_theme.dart';
import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_attraction_store.dart';

void main() {
  Widget app(Widget child) => MaterialApp(theme: AdminTheme.data, home: child);

  void surface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'portal validates credentials and submits once with the selected persistence',
    (tester) async {
      surface(tester, const Size(1440, 1000));
      var calls = 0;
      var remember = false;
      final pending = Completer<void>();
      await tester.pumpWidget(
        app(
          AdminSignInPage(
            onSignIn: (email, password, selected) async {
              calls++;
              expect(email, 'admin@example.test');
              expect(password, 'test-password');
              remember = selected;
              await pending.future;
            },
            onResetPassword: (_) async {},
          ),
        ),
      );
      await tester.tap(find.text('Sign In Securely'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Enter a valid work email.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('admin-email')),
        ' admin@example.test ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('admin-password')),
        'test-password',
      );
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Sign In Securely'));
      await tester.pump();
      expect(calls, 1);
      expect(remember, isTrue);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.completeError(FirebaseAuthException(code: 'invalid-credential'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.text('Sign In Securely'), findsOneWidget);
    },
  );

  testWidgets(
    'portal password reset validates email and does not reveal account existence',
    (tester) async {
      surface(tester, const Size(1440, 1000));
      var calls = 0;
      await tester.pumpWidget(
        app(
          AdminSignInPage(
            onSignIn: (_, _, _) async {},
            onResetPassword: (email) async {
              calls++;
              expect(email, 'admin@example.test');
              throw FirebaseAuthException(code: 'user-not-found');
            },
          ),
        ),
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(
        find.byKey(const ValueKey('admin-email')),
        'admin@example.test',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.textContaining('If this account is registered'),
        findsOneWidget,
      );
    },
  );

  testWidgets('portal login fits a narrow browser with enlarged text', (
    tester,
  ) async {
    surface(tester, const Size(360, 900));
    await tester.pumpWidget(
      app(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: AdminSignInPage(
            onSignIn: (_, _, _) async {},
            onResetPassword: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Sign In Securely'));
    expect(find.text('Sign In Securely'), findsOneWidget);
  });

  testWidgets(
    'portal table filters and paginates actual records with live summaries',
    (tester) async {
      surface(tester, const Size(1440, 1100));
      final store = MemoryAttractionStore();
      final access = ValueNotifier(true);
      addTearDown(store.dispose);
      addTearDown(access.dispose);
      for (var index = 0; index < 12; index++) {
        store.put(
          testAttraction(
            id: 'ride-$index',
            name: 'Ride $index',
            status: index.isEven
                ? AttractionStatus.open
                : AttractionStatus.closed,
          ),
        );
      }
      await tester.pumpWidget(
        app(AttractionsAdminPage(store: store, adminAccess: access)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 to 10 of 12 results'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 11 to 12 of 12 results'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ride-11');
      await tester.pumpAndSettle();
      expect(find.text('Ride 11'), findsOneWidget);
      expect(find.text('Showing 1 to 1 of 1 results'), findsOneWidget);
      expect(store.readCalls, 1);
      store.put(testAttraction(id: 'ride-11', name: 'Updated attraction'));
      await tester.pumpAndSettle();
      expect(find.text('Updated attraction'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'portal shell has working account actions and mobile navigation',
    (tester) async {
      surface(tester, const Size(390, 900));
      var signedOut = false;
      var refreshed = false;
      AdminPortalSection? selected;
      await tester.pumpWidget(
        app(
          AdminPortalShell(
            accountName: 'Test administrator',
            onSignOut: () => signedOut = true,
            onRefreshAccess: () => refreshed = true,
            section: AdminPortalSection.attractions,
            onSelectSection: (section) => selected = section,
            child: const Center(child: Text('Attraction content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh account access'));
      await tester.pumpAndSettle();
      expect(refreshed, isTrue);
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      expect(find.text('Park Facilities'), findsOneWidget);
      await tester.tap(find.text('Reservations'));
      await tester.pumpAndSettle();
      expect(selected, AdminPortalSection.reservations);
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(signedOut, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
