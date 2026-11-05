# Cultural & Heritage Module Development

This version is integrated into the uploaded `collaborative-main` Flutter project.

## Implemented pages and functions

### 1. Cultural & Heritage list
File: `lib/views/cultural_heritage_page.dart`

- Follows the supplied black-background Cultural & Heritage design.
- Search by attraction, location or keyword.
- Five starter attractions matching the supplied design:
  - Sultan Abdul Samad Building
  - Jonker Street
  - Batu Caves
  - A Famosa
  - Kek Lok Si Temple
- Tap a card to open Heritage Details.
- Tap `View On Map` to open the attraction coordinates in Google Maps.
- The top camera button opens AI Attraction Recognition.

### 2. AI Attraction Recognition
File: `lib/views/ai_attraction_recognition_page.dart`

- Camera capture and gallery upload.
- Sends the image to `heritage_backend`.
- Backend calls Google Cloud Vision Landmark Detection with Web Detection fallback.
- Returned names are matched against local attraction aliases.
- Successful results are saved to recognition history.

### 3. Heritage Details
File: `lib/views/heritage_detail_page.dart`

- Historical background.
- Cultural significance.
- Visitor etiquette.
- Sustainable travel tip.
- Opening hours / recommended time / best time.
- Multilingual audio guide using device TTS:
  - English
  - Bahasa Melayu
  - Chinese
- Add to Travel Diary.
- Open map.

### 4. Digital Travel Diary
File: `lib/views/heritage_diary_page.dart`

- Saves attraction IDs locally using SharedPreferences.
- Search saved places.
- Remove from diary.
- Open saved attraction details.

### 5. Nearby Heritage
File: `lib/views/nearby_heritage_page.dart`

- Requests the current device location only when the user taps Check Nearby Heritage.
- Finds supported heritage attractions within 1 km.
- Sends a local notification for the nearest result.

### 6. Recognition History
File: `lib/views/recognition_history_page.dart`

- Stores recent successful recognitions locally.
- Opens the full heritage detail page.

## Existing project integration

The existing `HomePage` now contains a Cultural & Heritage module card without removing the existing authentication/logout flow.

## Fastest way to preview only this module

Run the supplied preview target:

```powershell
flutter pub get
flutter run -d emulator-5554 -t lib/cultural_heritage_preview.dart
```

This bypasses the existing Firebase login/admin start page and opens Cultural & Heritage directly for development.

## Normal project flow

The original `main.dart` remains unchanged, so your team's existing Firebase/Admin startup is preserved.
After a normal user reaches `HomePage`, tap the **Cultural & Heritage** card.

## Google Cloud recognition setup

Recognition requires the included `heritage_backend` to be running. See:

`heritage_backend/README.md`

The heritage list, details, diary and UI preview work without the backend.
