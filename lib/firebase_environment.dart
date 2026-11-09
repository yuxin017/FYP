import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_emulator_session_stub.dart'
    if (dart.library.js_interop) 'firebase_emulator_session_web.dart';

Future<void> initializeFirebaseEnvironment() async {
  resetFirebaseAuthEmulatorCache();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
