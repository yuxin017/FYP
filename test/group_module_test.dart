import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaborative_asg/groups/group_repository.dart';
import 'package:collaborative_asg/groups/group_pages.dart';
import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:collaborative_asg/attractions/models/attraction_slot.dart';
import 'package:collaborative_asg/visits/visit_repository.dart';
import 'visit_module_test.dart' show FixtureVisits;

class FixtureGroups implements GroupRepository {
  final calls = <Map<String, dynamic>>[];
  final record = const GroupRecord('group', {
    'name': 'Park Friends',
    'ownerUid': 'alice',
    'visitDate': '2090-11-09',
    'inviteCode': '1234567890abcdef1234567890abcdef',
  });
  final member = const GroupRecord('member', {
    'memberId': 'alice',
    'ownerUid': 'alice',
    'displayName': 'Alice',
    'isGuest': false,
    'ticketId': null,
  });
  @override
  String get uid => 'alice';
  @override
  String newRequestId() => 'fixture-request-unique-123456';
  @override
  Stream<List<GroupRecord>> groups() => Stream.value([record]);
  @override
  Stream<GroupRecord?> group(String id) => Stream.value(record);
  @override
  Stream<List<GroupRecord>> members(String id) => Stream.value([member]);
  @override
  Stream<List<GroupRecord>> bookings(String id) => Stream.value([]);
  @override
  Stream<List<GroupRecord>> locations(String id) => Stream.value([]);
  @override
  Stream<List<AttractionVisit>> passes(String bookingId, String groupId) =>
      Stream.value([]);
  @override
  Stream<List<Attraction>> attractions() => Stream.value([]);
  @override
  Stream<List<AttractionSlot>> slots(String id) => Stream.value([]);
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) async {
    calls.add({'action': action, ...data});
    return action == 'tickets'
        ? {
            'tickets': [
              {
                'id': 'admission-ticket',
                'label': 'Day Pass',
                'guestName': 'Alice',
                'visitDate': '2090-11-09',
                'validUntil': '2090-11-09',
              },
            ],
          }
        : {'groupId': 'group'};
  }

  @override
  VisitRepository get visitRepository => FixtureVisits();
}

Future<void> reveal(WidgetTester tester, Finder target, double delta) async {
  for (var i = 0; i < 12 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, Offset(0, delta));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  testWidgets(
    'group list opens the full member and reservation detail screen',
    (tester) async {
      final f = FixtureGroups();
      await tester.pumpWidget(MaterialApp(home: GroupsPage(repository: f)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Park Friends'));
      await tester.pumpAndSettle();
      expect(find.text('Group Reservations'), findsOneWidget);
      expect(find.text('Alice (You)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'create group validates the name then saves through the shared repository',
    (tester) async {
      final f = FixtureGroups();
      await tester.pumpWidget(MaterialApp(home: GroupFormPage(repository: f)));
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.widgetWithText(FilledButton, 'Create Group'),
        -350,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Group'));
      await tester.pumpAndSettle();
      expect(f.calls, isEmpty);
      await reveal(tester, find.byType(TextField).first, 350);
      await tester.enterText(find.byType(TextField).first, 'Park Friends');
      await reveal(
        tester,
        find.widgetWithText(FilledButton, 'Create Group'),
        -350,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Group'));
      await tester.pumpAndSettle();
      expect(f.calls.single['action'], 'create');
      expect(find.text('Group Reservations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'ticket linking saves the selected real ticket and member reference',
    (tester) async {
      final f = FixtureGroups();
      await tester.pumpWidget(
        MaterialApp(
          home: GroupLinkTicketPage(
            repository: f,
            groupId: 'group',
            member: f.member,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day Pass'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Link Ticket'));
      await tester.pumpAndSettle();
      expect(f.calls.last['action'], 'link');
      expect(f.calls.last['ticketId'], 'admission-ticket');
      expect(f.calls.last['memberId'], 'alice');
      expect(tester.takeException(), isNull);
    },
  );
}
