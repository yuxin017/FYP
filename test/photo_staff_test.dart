import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaborative_asg/admin/photos/photo_admin_repository.dart';
import 'package:collaborative_asg/admin/photos/photo_management.dart';
import 'package:collaborative_asg/kiosk/photo_kiosk.dart';
import 'package:collaborative_asg/photos/photo_repository.dart';
import 'package:collaborative_asg/photos/photo_session_scope.dart';
import 'package:collaborative_asg/photos/photo_gallery_pages.dart';
import 'photos_module_test.dart' show FixturePhotos;

class StaffPhotos extends FixturePhotos {
  final statuses = <String>[];
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) async {
    if (action == 'kioskRetrieve') {
      return {
        'requestId': 'a' * 64,
        'status': 'ready',
        'images': [
          {
            'photoId': photo.id,
            'title': photo.title,
            'imageBase64': photo.preview,
            'quantity': 2,
            'printSize': '6x8',
            'finish': 'glossy',
          },
        ],
      };
    }
    if (action == 'kioskStatus') {
      statuses.add(data['status'] as String);
      return {'status': data['status']};
    }
    return super.request(action, data);
  }
}

class AdminPhotos implements PhotoAdminRepository {
  final fixture = FixturePhotos();
  @override
  Stream<List<ParkPhoto>> records(String collection) => Stream.value(
    collection == 'parkPhotos'
        ? [
            ParkPhoto(fixture.photo.id, {
              ...fixture.photo.data,
              'status': 'active',
              'faceCount': 1,
              'matchedVisitorCount': 1,
              'claimCode': 'a' * 32,
            }),
          ]
        : [],
  );
  @override
  Stream<List<Map<String, dynamic>>> places() => Stream.value([]);
  @override
  String newRequestId() => 'isolated-upload-1234567890';
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) async => {};
}

Future<void> visible(WidgetTester tester, Finder target) async {
  for (int i = 0; i < 15 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  test(
    'kiosk creates one correctly sized PDF page per requested copy',
    () async {
      final f = FixturePhotos(),
          pdf = await buildKioskPrintPdf([
            {'imageBase64': f.photo.preview, 'quantity': 2, 'printSize': '6x8'},
          ]);
      final text = latin1.decode(pdf);
      expect(text.startsWith('%PDF'), true);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(text).length, 2);
      expect(RegExp(r'/MediaBox\s*\[0 0 432 576\]').hasMatch(text), true);
    },
  );
  testWidgets(
    'cancelling print does not advance collection; successful spool requires explicit collection',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = StaffPhotos();
      bool send = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoKiosk(
            repository: repo,
            onSignOut: () async {},
            printDocument: (_, _) async => send,
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'PK1:${'a' * 64}:${'b' * 32}',
      );
      await visible(tester, find.text('Open Photo Order'));
      await tester.tap(find.text('Open Photo Order'));
      await tester.pumpAndSettle();
      await visible(tester, find.text('Print Photos'));
      await tester.tap(find.text('Print Photos'));
      await tester.pumpAndSettle();
      expect(repo.statuses, isEmpty);
      send = true;
      await tester.tap(find.text('Print Photos'));
      await tester.pumpAndSettle();
      expect(repo.statuses, isEmpty);
      await tester.tap(find.text('Job Sent to Printer'));
      await tester.pumpAndSettle();
      expect(repo.statuses, ['spooled']);
      await visible(tester, find.text('Confirm Printed & Collected'));
      await tester.tap(find.text('Confirm Printed & Collected'));
      await tester.pumpAndSettle();
      expect(repo.statuses, ['spooled']);
      await tester.tap(find.text('Confirm Collected'));
      await tester.pumpAndSettle();
      expect(repo.statuses, ['spooled', 'collected']);
      await visible(tester, find.text('Next Visitor'));
      await tester.tap(find.text('Next Visitor'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to the photo kiosk'), findsOneWidget);
      expect(find.text('Ride memories'), findsNothing);
    },
  );
  testWidgets(
    'photo admin shows the actual gallery and separate review and order tabs',
    (tester) async {
      tester.view.physicalSize = const Size(1300, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PhotoManagement(
                repository: AdminPhotos(),
                visitors: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ride memories'), findsOneWidget);
      expect(find.text('Upload Park Photo'), findsOneWidget);
      expect(find.text('Review Requests'), findsOneWidget);
      expect(find.text('Orders'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'kiosk customer frames expose session exit without visitor tab navigation',
    (tester) async {
      bool ended = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoSessionScope(
            finish: (_) async {
              ended = true;
            },
            child: PhotoHubPage(repository: FixturePhotos()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('End My Kiosk Session'), findsOneWidget);
      await tester.tap(find.text('End My Kiosk Session'));
      await tester.pumpAndSettle();
      expect(ended, true);
    },
  );
}
