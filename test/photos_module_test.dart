import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collaborative_asg/photos/photo_repository.dart';
import 'package:collaborative_asg/photos/photo_gallery_pages.dart';
import 'package:collaborative_asg/photos/photo_checkout_pages.dart';
import 'package:collaborative_asg/photos/photo_editor.dart';
import 'package:collaborative_asg/services/application_api.dart';

class FixturePhotos implements PhotoRepository {
  @override
  String get uid => 'isolated-photo-visitor';
  @override
  String get email => 'visitor@example.test';
  @override
  late final cart = PhotoCart(uid, persist: false);
  late final photo = ParkPhoto('photo-123456789', {
    'photoId': 'photo-123456789',
    'title': 'Ride memories',
    'attractionName': 'River Rapids',
    'previewBase64': base64Encode(
      img.encodeJpg(img.Image(width: 320, height: 240)),
    ),
    'takenAt': Timestamp.now(),
    'score': .92,
  });
  ParkPhoto? saved;
  bool loseAcknowledgement = false;
  int checkoutCalls = 0;
  @override
  Stream<Map<String, dynamic>> faceProfile() =>
      Stream.value({'enabled': true, 'matchingStatus': 'complete'});
  @override
  Stream<List<ParkPhoto>> matches() => Stream.value([photo]);
  @override
  Stream<List<ParkPhoto>> entitlements() => Stream.value([]);
  @override
  Stream<List<ParkPhoto>> orders() =>
      Stream.value(saved == null ? [] : [saved!]);
  @override
  Stream<ParkPhoto?> order(String id) => Stream.value(saved);
  @override
  Stream<List<ParkPhoto>> orderPreviews(String id) => Stream.value([photo]);
  @override
  Stream<Map<String, dynamic>> settings() => Stream.value({});
  @override
  Stream<int> balance() => Stream.value(1000);
  @override
  Stream<Map<String, dynamic>?> kioskRequest(String id) => Stream.value(null);
  @override
  Future<void> reauthenticate(String password) async {}
  @override
  String newRequestId() => 'isolated-photo-request-123456789';
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) async {
    if (action == 'quote') {
      return {
        'subtotalMinor': 2500,
        'discountMinor': 0,
        'pointsUsed': data['pointsUsed'] ?? 0,
        'totalMinor': 2500 - (data['pointsUsed'] as int? ?? 0),
        'maxPoints': 1000,
        'pointsEarned': 25,
        'currency': 'MYR',
      };
    }
    if (action == 'purchaseState') {
      return saved == null
          ? {'found': false}
          : {'found': true, 'orderId': saved!.id};
    }
    if (action == 'checkout') {
      checkoutCalls++;
      saved = ParkPhoto('a' * 64, {
        'ownerUid': uid,
        'createdAt': Timestamp.now(),
        'status': 'confirmed',
        'items': [
          Map<String, dynamic>.from((data['items'] as List).first as Map)
            ..addAll({'title': 'Ride memories', 'priceMinor': 2500}),
        ],
        'subtotalMinor': 2500,
        'discountMinor': 0,
        'totalMinor': data['expectedTotalMinor'],
        'pointsUsed': data['pointsUsed'] ?? 0,
        'pointsEarned': 25,
        'emailStatus': 'pending',
      });
      if (loseAcknowledgement) {
        throw const ApplicationApiException(
          'unavailable',
          'Connection interrupted.',
        );
      }
      return {'orderId': saved!.id};
    }
    return {};
  }
}

Future<void> revealPhoto(WidgetTester tester, Finder target) async {
  for (int i = 0; i < 20 && target.hitTestable().evaluate().isEmpty; i++) {
    final above =
        target.evaluate().isNotEmpty && tester.getCenter(target).dy < 70;
    await tester.drag(
      find.byType(ListView).first,
      Offset(0, above ? 240 : -240),
    );
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'photo edits change pixels and crop dimensions while preserving the source',
    () {
      final original = img.Image(width: 320, height: 240);
      img.fill(original, color: img.ColorRgb8(160, 70, 40));
      final bytes = Uint8List.fromList(img.encodeJpg(original));
      final edited = applyPhotoChanges({
        'source': bytes,
        'edits': {
          'filter': 'mono',
          'crop': {'x': .125, 'y': 0, 'width': .75, 'height': 1},
        },
      });
      final result = img.decodeJpg(edited)!;
      expect(result.width, 240);
      expect(result.height, 240);
      expect(
        (result.getPixel(20, 20).r - result.getPixel(20, 20).g).abs(),
        lessThan(3),
      );
      expect(img.decodeJpg(bytes)!.width, 320);
    },
  );
  testWidgets(
    'photo preview retains the full purchase and kiosk routes without layout errors',
    (tester) async {
      final f = FixturePhotos();
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoPreviewPage(repository: f, photo: f.photo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Photo Preview'), findsOneWidget);
      expect(f.photo.confidence, 92);
      expect(find.textContaining('92% score'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'digital photo follows format, cart, payment and its saved confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = FixturePhotos();
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoFormatPage(
            repository: f,
            photo: f.photo,
            preview: f.photo.preview,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await revealPhoto(tester, find.text('Add to Photo Cart'));
      await tester.tap(find.text('Add to Photo Cart'));
      await tester.pumpAndSettle();
      expect(find.text('Photo Cart'), findsOneWidget);
      await revealPhoto(tester, find.text('Proceed to Payment'));
      await tester.tap(find.text('Proceed to Payment'));
      await tester.pumpAndSettle();
      await revealPhoto(tester, find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await revealPhoto(tester, find.text('Pay RM 25.00'));
      await tester.tap(find.text('Pay RM 25.00'));
      await tester.pumpAndSettle();
      expect(find.text('Your photos are ready!'), findsOneWidget);
      expect(f.checkoutCalls, 1);
      expect(f.cart.items, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'a lost purchase acknowledgement is recovered without another checkout or points mutation',
    () async {
      final f = FixturePhotos()..loseAcknowledgement = true;
      await f.cart.add(
        PhotoCartItem(
          photoId: f.photo.photoId,
          title: f.photo.title,
          preview: f.photo.preview,
        ),
      );
      final body = {
        'items': f.cart.items.map((i) => i.payload).toList(),
        'pointsUsed': 0,
        'promoCode': '',
        'expectedTotalMinor': 2500,
      };
      await expectLater(
        confirmPhotoPurchase(f, body),
        throwsA(isA<ApplicationApiException>()),
      );
      expect(f.checkoutCalls, 1);
      final result = await confirmPhotoPurchase(f, body);
      expect(result['recovered'], true);
      expect(f.checkoutCalls, 1);
      expect(f.cart.items, isEmpty);
    },
  );
}
