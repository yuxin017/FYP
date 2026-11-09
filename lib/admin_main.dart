import 'package:flutter/material.dart';
import 'firebase_environment.dart';
import 'main.dart' show ThemeParkApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseEnvironment();
  runApp(const ThemeParkApp(initialRoute: '/admin'));
}
