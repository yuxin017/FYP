# Profile Settings Update

Added working navigation and UI for Preferences & Interests, Face Recognition consent, and Security & Account. Profile avatar is read from Firestore Base64 and camera shortcut opens Personal Information. Preferences and consent persist in Firestore after rules are updated per FIRESTORE_RULES_PROFILE_SETTINGS.txt. Password reset sends a Firebase Authentication email. Log out signs out via Firebase Authentication.

**Not implemented:** real biometric enrollment/matching, email change, account deletion, login device management, production payment/queue/location features. These must not be represented as functional.

Run `flutter pub get`, `flutter analyze`, `flutter run -d chrome`. Flutter SDK is not available in the build environment; this package was not compiled here.
