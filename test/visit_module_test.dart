import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaborative_asg/visits/visit_repository.dart';
import 'package:collaborative_asg/visits/visit_pages.dart';

class FixtureVisits implements VisitRepository {
  final visitRecord = AttractionVisit('fixture-reservation', {
    'attractionName': 'River Rapids',
    'attractionId': 'river',
    'status': 'checked_in',
    'startsAt': Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 2)),
    ),
    'endsAt': Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 1)),
    ),
    'earnedPoints': 10,
  });
  int? savedStars;
  @override
  Stream<List<AttractionVisit>> visits() => Stream.value([visitRecord]);
  @override
  Stream<AttractionVisit?> visit(String id) => Stream.value(visitRecord);
  @override
  Stream<Map<String, dynamic>> attraction(String id) => Stream.value({});
  @override
  Stream<int> balance() => Stream.value(50);
  @override
  Future<Map<String, dynamic>> checkIn(String id) async => {};
  @override
  Future<void> rate(
    String id,
    int stars,
    List<String> categories,
    String message,
    bool anonymous,
    String? photo,
  ) async {
    savedStars = stars;
  }
}

void main() {
  test('visit state follows the real return window and entry status', () {
    final f = FixtureVisits();
    expect(f.visitRecord.completedAt(DateTime.now()), true);
    expect(f.visitRecord.stateAt(DateTime.now()), 'Completed');
    final upcoming = AttractionVisit('upcoming', {
      ...f.visitRecord.data,
      'status': 'confirmed',
      'startsAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 1)),
      ),
      'endsAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 2)),
      ),
    });
    expect(upcoming.stateAt(DateTime.now()), 'Upcoming');
  });
  testWidgets(
    'visited attractions retain history and open their full pass details',
    (tester) async {
      final f = FixtureVisits();
      await tester.pumpWidget(
        MaterialApp(home: VisitHistoryPage(repository: f)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visited'));
      await tester.pumpAndSettle();
      expect(find.text('River Rapids'), findsOneWidget);
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Attraction Entrance Pass'), findsOneWidget);
      expect(find.text('View Points Earned'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('rating validates stars before saving the selected experience', (
    tester,
  ) async {
    final f = FixtureVisits();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      RateVisitPage(repository: f, visit: f.visitRecord),
                ),
              ),
              child: const Text('Open rating'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open rating'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Submit Rating'), 350, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Submit Rating'));
    await tester.pumpAndSettle();
    expect(f.savedStars, isNull);
    expect(
      find.text('Choose a star rating before submitting.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.byTooltip('4 stars'), -350, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('4 stars'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Submit Rating'), 350, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Submit Rating'));
    await tester.pumpAndSettle();
    expect(f.savedStars, 4);
    expect(find.text('Open rating'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
