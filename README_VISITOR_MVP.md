# Visitor App MVP — implementation notes

This project is derived from the supplied Flutter project. Existing Firebase authentication, registration, profile, profile settings, and personal information screens are retained. Added visitor-facing Home, Tickets, Virtual Queue and Park Directory pages, retaining the rose/pink theme and existing assets.

## Start

1. Open this folder in VS Code with Flutter installed.
2. Run `flutter pub get`.
3. Run `flutter analyze`, resolve any environment-specific issues, then `flutter run -d chrome` or run on a configured Android device.
4. Confirm Firebase project configuration and Firestore security rules for profile updates.

## Functional scope and limitations

- Existing Firebase Authentication and visitor profile pages remain from the source project. They have not been end-to-end tested in this environment.
- Home provides navigation to main tabs.
- Tickets can create **demo-only** tickets stored in SharedPreferences on the current device. No payment, backend issuance, QR entry validation or cross-device sync.
- Virtual Queue can join/leave one **demo-only** attraction queue stored locally. Wait times are sample values. No live queue backend or capacity control.
- Map is a sample directory, not a real georeferenced park map or Wi-Fi RTT/PDR navigation.
- User profile and settings are based on the supplied source code; changing email, account deletion, group location sharing, vouchers, loyalty earning, photo recognition and kiosk are not implemented in this MVP.
- UI uses existing theme and assets but is **not verified as a pixel-perfect reproduction of every Figma frame**.
- No Flutter SDK was available in the packaging environment, so compilation, device testing and Firebase connectivity **could not be verified**. Do not treat this ZIP as a production-ready app.

## Important security

Do not enable unrestricted Firestore write rules. A real ticketing/queue/payment workflow needs trusted server-side enforcement. Never store payment card details in Firestore or issue authentic admission QR codes from untrusted local state.
