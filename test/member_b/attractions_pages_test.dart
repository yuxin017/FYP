import 'dart:async';

import 'package:collaborative_asg/admin/attractions/attraction_editor_page.dart';
import 'package:collaborative_asg/admin/attractions/attractions_admin_page.dart';
import 'package:collaborative_asg/admin/auth/attraction_admin_access.dart';
import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:collaborative_asg/attractions/pages/attraction_details_page.dart';
import 'package:collaborative_asg/attractions/pages/attractions_page.dart';
import 'package:collaborative_asg/attractions/widgets/attraction_widgets.dart';
import 'package:collaborative_asg/visitor/widgets/visitor_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_attraction_store.dart';
import '../support/attraction_photo.dart';

void main() {
  late MemoryAttractionStore store;
  late ValueNotifier<bool> access;

  setUp(() {
    store = MemoryAttractionStore();
    access = ValueNotifier(true);
  });
  tearDown(() async {
    access.dispose();
    await store.dispose();
  });

  Widget app(Widget home) => MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: visitorBackground,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF704B8E)),
    ),
    home: Scaffold(body: home),
  );

  void tallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder field(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(TextFormField))
      .first;

  Future<void> tapSave(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Save attraction'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save attraction'));
  }

  test(
    'admin access requires the boolean token claim; profile roles and strings never grant it',
    () {
      expect(hasAttractionAdminClaim({'admin': true}), isTrue);
      for (final claims in [
        null,
        <String, dynamic>{},
        {'admin': false},
        {'admin': 'true'},
        {'admin': 1},
        {'role': 'admin'},
      ]) {
        expect(hasAttractionAdminClaim(claims), isFalse);
      }
    },
  );

  testWidgets('loading does not display empty or invented attractions', (
    tester,
  ) async {
    store.loading = true;
    await tester.pumpWidget(app(AttractionsPage(store: store)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No attractions available'), findsNothing);
    expect(find.text('Sky Coaster'), findsNothing);
  });

  testWidgets(
    'empty collection shows an honest empty state with no admin controls for visitors',
    (tester) async {
      await tester.pumpWidget(app(AttractionsPage(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('No attractions available'), findsOneWidget);
      expect(find.text('Manage attractions'), findsNothing);
    },
  );

  testWidgets(
    'read error retries the actual source instead of falling back to sample records',
    (tester) async {
      store.readFailures = 1;
      store.put(testAttraction());
      await tester.pumpWidget(app(AttractionsPage(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('Could not load attractions'), findsOneWidget);
      expect(find.text('Mountain Falls'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(store.readCalls, 2);
      expect(find.text('Mountain Falls'), findsOneWidget);
    },
  );

  testWidgets(
    'search and status filters can be cleared without resubscribing',
    (tester) async {
      tallSurface(tester);
      store.put(testAttraction());
      store.put(
        testAttraction(
          id: 'theatre',
          name: 'Starlight Theatre',
          category: 'Shows',
          status: AttractionStatus.closed,
        ),
      );
      await tester.pumpWidget(app(AttractionsPage(store: store)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'MOUNTAIN');
      await tester.pumpAndSettle();
      expect(find.text('Mountain Falls'), findsOneWidget);
      expect(find.text('Starlight Theatre'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Available Now'));
      await tester.pumpAndSettle();
      expect(find.text('No matching attractions'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Mountain Falls'), findsOneWidget);
      expect(find.text('Starlight Theatre'), findsOneWidget);
      expect(store.readCalls, 1);
    },
  );

  testWidgets(
    'details follow live status/name changes and handle deleted records',
    (tester) async {
      store.put(testAttraction());
      await tester.pumpWidget(
        app(
          AttractionDetailsPage(
            store: store,
            attractionId: 'mountain_falls',
            visitorHeightCm: 100,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('below this attraction'), findsOneWidget);
      store.put(
        testAttraction(
          name: 'Renamed Falls',
          status: AttractionStatus.maintenance,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Renamed Falls'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      store.remove('mountain_falls');
      await tester.pumpAndSettle();
      expect(find.text('Attraction not found'), findsOneWidget);
      expect(find.text('Renamed Falls'), findsNothing);
    },
  );

  testWidgets(
    'zero minimum height is not described as proof of full booking eligibility',
    (tester) async {
      store.put(testAttraction(minHeightCm: 0));
      await tester.pumpWidget(
        app(
          AttractionDetailsPage(store: store, attractionId: 'mountain_falls'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No minimum height is listed for this attraction.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('meets this height requirement'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'admin list is protected and editors disappear when access is revoked',
    (tester) async {
      access.value = false;
      await tester.pumpWidget(
        app(AttractionsAdminPage(store: store, adminAccess: access)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Administrator access required'), findsOneWidget);
      expect(find.text('Add Facility'), findsNothing);
      access.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Add Facility'), findsOneWidget);
      access.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Add Facility'), findsNothing);
      expect(store.createCalls, 0);
    },
  );

  testWidgets(
    'new attraction form rejects missing fields and invalid coordinates without writing',
    (tester) async {
      tallSurface(tester);
      await tester.pumpWidget(
        app(AttractionEditorPage(store: store, adminAccess: access)),
      );
      await tester.pumpAndSettle();
      await tapSave(tester);
      await tester.pumpAndSettle();
      expect(find.text('Enter an attraction name.'), findsOneWidget);
      expect(find.text('Choose a category.'), findsOneWidget);
      expect(
        find.text('Enter a valid number using a decimal point.'),
        findsNWidgets(2),
      );
      expect(store.createCalls, 0);
    },
  );

  testWidgets('failed create retains the form and reuses its ID on retry', (
    tester,
  ) async {
    tallSurface(tester);
    store.writeError = StateError('Test network failure');
    await tester.pumpWidget(
      app(
        AttractionEditorPage(
          store: store,
          adminAccess: access,
          pickCover: () async => attractionTestPhoto(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(field('Attraction name'), 'Night Parade');
    await tester.enterText(
      field('Attraction description'),
      'An evening parade through the park.',
    );
    await tester.tap(find.text('Choose cover photo'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField<String>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shows').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Map X'), '.4');
    await tester.enterText(field('Map Y'), '.6');
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(store.createCalls, 1);
    expect(
      find.textContaining('Your entered details have been kept'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(field('Attraction name')).controller!.text,
      'Night Parade',
    );
    store.writeError = null;
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(store.createCalls, 2);
    expect(store.createdIds.toSet().length, 1);
    expect(store.records.values.single.name, 'Night Parade');
    expect(store.records.values.single.status, AttractionStatus.closed);
  });

  testWidgets(
    'save cannot submit twice while pending or submit again after access revocation',
    (tester) async {
      tallSurface(tester);
      final original = testAttraction();
      store.put(original);
      store.saveGate = Completer<void>();
      await tester.pumpWidget(
        app(
          AttractionEditorPage(
            store: store,
            adminAccess: access,
            attraction: original,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapSave(tester);
      await tester.pump();
      expect(store.updateCalls, 1);
      final button = tester.widget<FilledButton>(
        find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(button.onPressed, isNull);
      access.value = false;
      await tester.pump();
      expect(find.text('Administrator access required'), findsOneWidget);
      expect(find.text('Saving...'), findsNothing);
      store.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(store.updateCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'conflicting edits are shown and loading latest requires an explicit action',
    (tester) async {
      tallSurface(tester);
      final original = testAttraction();
      store.put(original);
      await tester.pumpWidget(
        app(
          AttractionEditorPage(
            store: store,
            adminAccess: access,
            attraction: original,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('Attraction name'), 'My unsaved edit');
      store.put(testAttraction(name: 'Another admin edit'));
      await tapSave(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Another administrator changed'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(field('Attraction name')).controller!.text,
        'My unsaved edit',
      );
      await tester.tap(find.text('Load latest (discard my edits)'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field('Attraction name')).controller!.text,
        'Another admin edit',
      );
    },
  );

  testWidgets(
    'admin status save returns to the list and displays the persisted result',
    (tester) async {
      tallSurface(tester);
      store.put(testAttraction());
      await tester.pumpWidget(
        app(AttractionsAdminPage(store: store, adminAccess: access)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mountain Falls'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<AttractionStatus>,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maintenance').last);
      await tester.pumpAndSettle();
      await tapSave(tester);
      await tester.pumpAndSettle();
      expect(store.updateCalls, 1);
      expect(store.createCalls, 0);
      expect(
        store.records['mountain_falls']!.status,
        AttractionStatus.maintenance,
      );
      expect(find.text('Facility Management'), findsOneWidget);
      expect(find.text('Attraction saved successfully.'), findsOneWidget);
      expect(
        find.widgetWithText(AttractionStatusBadge, 'Maintenance'),
        findsOneWidget,
      );
    },
  );

  testWidgets('cancelling the add form creates no attraction', (tester) async {
    tallSurface(tester);
    await tester.pumpWidget(
      app(AttractionsAdminPage(store: store, adminAccess: access)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Facility'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attraction'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Attraction name'), 'Unsaved attraction');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.createCalls, 0);
    expect(store.records, isEmpty);
    expect(find.text('Facility Management'), findsOneWidget);
  });

  testWidgets(
    'admin can save dining, facility and shop records through Add Facility',
    (tester) async {
      tallSurface(tester);
      await tester.pumpWidget(
        app(AttractionsAdminPage(store: store, adminAccess: access)),
      );
      await tester.pumpAndSettle();

      for (final (kind, heading, name) in [
        (ParkPlaceKind.dining, 'Dining location', 'Garden Cafe'),
        (ParkPlaceKind.facilities, 'Facility', 'First Aid Station'),
        (ParkPlaceKind.shops, 'Shop', 'Castle Gifts'),
      ]) {
        await tester.tap(find.text('Add Facility'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(SimpleDialogOption, kind.label));
        await tester.pumpAndSettle();
        expect(find.text('Minimum height (cm)'), findsNothing);
        expect(find.text('Standby wait (minutes)'), findsNothing);
        await tester.enterText(field('$heading name'), name);
        await tester.enterText(
          field('$heading description'),
          'A park location for visitors.',
        );
        await tester.enterText(field('Map X'), '0.2');
        await tester.enterText(field('Map Y'), '0.4');
        final save = find.text('Save ${kind.itemName}');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final saved = store.records.values.singleWhere(
          (place) => place.name == name,
        );
        expect(saved.category, kind.label);
        expect(saved.placeKind, kind);
        expect(saved.minHeightCm, 0);
        expect(find.text(name), findsOneWidget);
      }
      expect(store.createCalls, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long attraction names and statuses fit a narrow screen with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      store.put(
        testAttraction(
          name: 'A long attraction name for the family adventure experience',
          status: AttractionStatus.maintenance,
        ),
      );
      await tester.pumpWidget(
        app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: AttractionsPage(store: store),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Maintenance'), findsWidgets);
    },
  );
}
