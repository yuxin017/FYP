import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaborative_asg/splash_screen.dart';

void main() {
  testWidgets('splash startup never replaces an administrator deep link', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/admin',
        home: const SplashScreen(),
        routes: {
          '/admin': (_) => const Scaffold(body: Text('Administrator route')),
        },
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Administrator route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
