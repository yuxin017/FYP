import 'dart:async';
import 'package:collaborative_asg/admin/attractions/attractions_admin_page.dart';
import 'package:collaborative_asg/admin/portal/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/memory_attraction_store.dart';

void main() {
  late MemoryAttractionStore store;
  late ValueNotifier<bool> access;
  setUp(() {
    store = MemoryAttractionStore()..put(testAttraction());
    access = ValueNotifier(true);
  });
  tearDown(() async {
    access.dispose();
    await store.dispose();
  });
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.data,
        home: AttractionsAdminPage(store: store, adminAccess: access),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Mountain Falls'));
    await tester.pumpAndSettle();
  }

  testWidgets('delete requires confirmation and Cancel preserves the record', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Delete attraction?'), findsOneWidget);
    expect(find.textContaining('booking history'), findsWidgets);
    expect(store.deleteCalls, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.deleteCalls, 0);
    expect(store.records.containsKey('mountain_falls'), isTrue);
  });
  testWidgets(
    'failed deletion leaves the row available and a confirmed retry removes it',
    (tester) async {
      store.writeError = StateError('Test connection failure');
      await open(tester);
      await tester.tap(find.text('Delete attraction'));
      await tester.pumpAndSettle();
      expect(store.deleteCalls, 1);
      expect(
        find.textContaining('Could not delete the attraction'),
        findsOneWidget,
      );
      expect(find.text('Mountain Falls'), findsOneWidget);
      store.writeError = null;
      await tester.tap(find.byTooltip('Delete Mountain Falls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete attraction'));
      await tester.pumpAndSettle();
      expect(store.deleteCalls, 2);
      expect(store.records, isEmpty);
      expect(store.deletedRecords.containsKey('mountain_falls'), isTrue);
      expect(find.text('Mountain Falls'), findsNothing);
      expect(find.text('No park places yet'), findsOneWidget);
      expect(find.text('Attraction deleted.'), findsOneWidget);
    },
  );
  testWidgets(
    'stale delete confirmation cannot remove a concurrently changed attraction',
    (tester) async {
      await open(tester);
      store.put(testAttraction(name: 'Changed by another administrator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete attraction'));
      await tester.pumpAndSettle();
      expect(
        store.records.values.single.name,
        'Changed by another administrator',
      );
      expect(
        find.textContaining('Refresh the list before deleting'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'access revocation disables confirmation and pending deletion cannot submit twice',
    (tester) async {
      await open(tester);
      access.value = false;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Delete attraction'),
            )
            .onPressed,
        isNull,
      );
      expect(store.deleteCalls, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      access.value = true;
      await tester.pumpAndSettle();
      store.saveGate = Completer<void>();
      await tester.tap(find.byTooltip('Delete Mountain Falls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete attraction'));
      await tester.pump();
      expect(store.deleteCalls, 1);
      final button = find.byTooltip('Delete Mountain Falls');
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(of: button, matching: find.byType(IconButton))
                  .first,
            )
            .onPressed,
        isNull,
      );
      store.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(store.deleteCalls, 1);
      expect(store.records, isEmpty);
    },
  );
}
