import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collaborative_asg/admin/attractions/data/admin_attraction_repository.dart';
import 'package:collaborative_asg/admin/attractions/data/admin_attraction_store.dart';
import 'package:collaborative_asg/attractions/data/attraction_repository.dart';
import 'package:collaborative_asg/attractions/models/attraction.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../support/memory_attraction_store.dart' show testAttraction;

// Explicit opt-in, local ports and an unregistered test project. Never live data.
const _enabled = bool.fromEnvironment('RUN_M1_EMULATOR');
const _project = 'demo-fyp-module1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('real Firestore SDK / local emulator', skip: !_enabled || !kIsWeb, () {
    late FirebaseApp adminApp;
    late FirebaseApp visitorApp;
    late FirebaseAuth adminAuth;
    late FirebaseAuth visitorAuth;
    late FirebaseFirestore adminDb;
    late FirebaseFirestore visitorDb;
    late AdminAttractionRepository adminStore;
    late AttractionRepository visitorStore;
    late AdminAttractionRepository visitorWriteAttempts;

    setUpAll(() async {
      const options = FirebaseOptions(
        apiKey: 'emulator-only-key',
        appId: '1:123456789:web:0000000000000000000000',
        messagingSenderId: '123456789',
        projectId: _project,
        authDomain: '$_project.firebaseapp.com',
      );
      final suffix = DateTime.now().microsecondsSinceEpoch;
      adminApp = await Firebase.initializeApp(
        name: 'm1-admin-$suffix',
        options: options,
      );
      visitorApp = await Firebase.initializeApp(
        name: 'm1-visitor-$suffix',
        options: options,
      );
      adminAuth = FirebaseAuth.instanceFor(app: adminApp);
      visitorAuth = FirebaseAuth.instanceFor(app: visitorApp);
      await adminAuth.useAuthEmulator('127.0.0.1', 9192);
      await visitorAuth.useAuthEmulator('127.0.0.1', 9192);
      await adminAuth.setPersistence(Persistence.NONE);
      await visitorAuth.setPersistence(Persistence.NONE);
      adminDb = FirebaseFirestore.instanceFor(app: adminApp);
      visitorDb = FirebaseFirestore.instanceFor(app: visitorApp);
      const settings = Settings(
        host: '127.0.0.1:8832',
        sslEnabled: false,
        persistenceEnabled: false,
      );
      adminDb.settings = settings;
      visitorDb.settings = settings;
      final admin = await adminAuth.signInAnonymously();
      await visitorAuth.signInAnonymously();
      final result = await http.post(
        Uri.parse(
          'http://127.0.0.1:9192/identitytoolkit.googleapis.com/v1/projects/$_project/accounts:update',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer owner',
        },
        body: jsonEncode({
          'localId': admin.user!.uid,
          'customAttributes': jsonEncode({'admin': true}),
        }),
      );
      expect(
        result.statusCode,
        200,
        reason: 'Emulator test-account setup must succeed',
      );
      expect((await admin.user!.getIdTokenResult(true)).claims?['admin'], true);
      adminStore = AdminAttractionRepository(firestore: adminDb);
      visitorStore = AttractionRepository(firestore: visitorDb);
      // Test denied writes with visitor credentials, outside the customer app.
      visitorWriteAttempts = AdminAttractionRepository(firestore: visitorDb);
    });

    tearDownAll(() async {
      await adminDb.terminate();
      await visitorDb.terminate();
      await adminAuth.signOut();
      await visitorAuth.signOut();
      await adminApp.delete();
      await visitorApp.delete();
    });

    test(
      'real repository persists creates/updates and publishes changes to another client',
      () async {
        final id = adminStore.newAttractionId();
        final original = testAttraction(id: id);
        await adminStore.createAttraction(original);
        final fromVisitor = await visitorStore.watchAttraction(id).first;
        expect(fromVisitor!.name, original.name);
        final observed = visitorStore
            .watchAttraction(id)
            .where((value) => value?.status == AttractionStatus.maintenance)
            .first;
        final updated = testAttraction(
          id: id,
          status: AttractionStatus.maintenance,
        );
        await adminStore.updateAttraction(
          original: original,
          replacement: updated,
        );
        expect((await observed)!.status, AttractionStatus.maintenance);
        // Same generated ID and payload make a repeated create safe.
        await adminStore.createAttraction(updated);
        expect(
          (await adminDb.collection('attractions').doc(id).get())
              .data()!['name'],
          original.name,
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'concurrent administrator edits cannot silently overwrite one another',
      () async {
        final id = adminStore.newAttractionId();
        final original = testAttraction(id: id);
        await adminStore.createAttraction(original);
        Future<bool> attempt(String name) async {
          try {
            await adminStore.updateAttraction(
              original: original,
              replacement: testAttraction(id: id, name: name),
            );
            return true;
          } on AttractionConflict {
            return false;
          }
        }

        final outcomes = await Future.wait([
          attempt('Edit A'),
          attempt('Edit B'),
        ]);
        expect(outcomes.where((success) => success).length, 1);
        final saved = await visitorStore.watchAttraction(id).first;
        expect(['Edit A', 'Edit B'], contains(saved!.name));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'a visitor using the real repository cannot create or change an attraction',
      () async {
        final id = adminStore.newAttractionId();
        final original = testAttraction(id: id);
        await adminStore.createAttraction(original);
        final permissionDenied = throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        );
        await expectLater(
          visitorWriteAttempts.createAttraction(
            testAttraction(id: visitorWriteAttempts.newAttractionId()),
          ),
          permissionDenied,
        );
        await expectLater(
          visitorWriteAttempts.updateAttraction(
            original: original,
            replacement: testAttraction(
              id: id,
              status: AttractionStatus.closed,
            ),
          ),
          permissionDenied,
        );
        expect(
          (await adminStore.watchAttraction(id).first)!.status,
          AttractionStatus.open,
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
