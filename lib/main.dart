import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_environment.dart';
import 'splash_screen.dart';
import 'auth/auth_gate.dart';
import 'admin/admin_portal.dart';
import 'admin/cameras/attraction_camera_store.dart';
import 'admin/cameras/camera_station_page.dart';
import 'kiosk/photo_kiosk.dart';
import 'photos/photo_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeFirebaseEnvironment();

  const cameraStation = bool.fromEnvironment('ATTRACTION_CAMERA_STATION');
  runApp(const ThemeParkApp(initialRoute: cameraStation ? '/camera' : null));
}

class ThemeParkApp extends StatelessWidget {
  final String? initialRoute;
  const ThemeParkApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Theme Park Smart Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFDF4EF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFAD7472),
          primary: const Color(0xFFAD7472),
        ),
      ),
      home: const SplashScreen(),
      initialRoute: initialRoute,
      routes: {
        '/admin': (context) => const AdminPortal(),
        if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb)
          '/camera': (context) => AdminPortal(
            staffBuilder: (firebase, user) => CameraStationPage(
              store: AttractionCameraStore(firebase.db, user.uid),
              onSignOut: firebase.auth.signOut,
            ),
          ),
        '/kiosk': (context) => AdminPortal(
          staffBuilder: (firebase, user) => PhotoKiosk(
            repository: FirebasePhotoRepository(
              authentication: firebase.auth,
              firestore: firebase.db,
            ),
            onSignOut: firebase.auth.signOut,
          ),
        ),
      },
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.attractions,
                  size: 90,
                  color: Color(0xFF704B8E),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Theme Park Smart\nManagement System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF704B8E),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your smarter theme park experience starts here!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuthGate(),
                        ),
                      );
                    },
                    child: const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
