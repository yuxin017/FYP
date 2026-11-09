# Combined application handover

Updated: 9 November 2026. The primary project is
`C:\Users\seowy\Documents\Codex\FYP`. Member B's incoming folder at
`C:\Users\seowy\Documents\FYP\FYP` is preserved separately.

Member A and B's source is integrated. The main proposal modules are ready for
hands-on review. Overall completion against every PDF requirement was estimated
at approximately 85%; this is not a fully verified completion claim. Provider
setup, device checks and remaining PDF-specific differences are listed below.
Read `START_HERE.txt` for launch commands and hands-on flows. Earlier module
handover files describe milestones before this integration.

## Included application flows

- Existing Firebase registration/sign-in, verified email, password reset,
  profile/avatar/height/interests/food preferences, sessions, account restrictions,
  recent-auth sensitive changes and resumable account closure. Phone linking and
  sign-in use Firebase SMS; native retained-session unlock uses local_auth.
- Ticket catalogue and package details, cart, per-guest data, points, promotions,
  confirmation, digital QR/NFC passes, wallet, receipts and combined history.
  Foreign currency is a dated reference display; checkout/accounting uses MYR.
- Facilities/attractions/status/height rules, map, details, return windows,
  individual reservations, cancellation, reminders, entrance passes, staff
  check-in, one-time ride points, completed visits and ratings.
- Group creation/editing/deletion, invitations/join/leave/removal, registered and
  guest members, ticket linking, opt-in location sharing and atomic multi-person
  reservations. Guest admission is checked against the actual group/pass records.
- Points ledger, catalogue, voucher redemption/expiry/use, membership tiers and
  ticket earning-rate snapshots. Optional no-show deductions have an effective
  date and idempotent guards; points cannot fall below zero.
- Support guides/search/feedback/complaints/attachments, visitor conversations,
  administrator case handling, private notes, resolution and case history.
- Smart Photos optional consent/re-authenticated face enrolment, removal, YuNet
  and SFace matching, watermarked private galleries, photographer codes, favorites,
  review/Not Me, real pixel edits, formats/copies/print options, promotions/points,
  idempotent confirmation, entitlements, downloads, receipts and order history.
- Staff photo upload/archive/recheck/review/orders. Separate kiosk customer
  shopping/sign-in/cart session, inactivity exit, paid QR/NFC retrieval, edits,
  correctly sized print PDFs, explicit sent-to-printer and collected stages.
- Administrator visitor/access/ticket/package/facility/reservation/admission and
  support management, campaigns, reward items, loyalty/photo/weather settings,
  landmark references and unusual-activity review.
- Crowd Monitoring with 30-second refresh, queue KDE, demand search, busy-place
  indicators, peak check-in hours and aggregated same-pass journeys. Facility
  controls are accessible from this screen. Heat represents confirmed queue
  places; continuous GPS visitor distribution is not inferred from bookings.
- Weather compensation issues automatically for eligible ticket owners after a
  qualifying observation, in bounded resumable batches with private cursors.
  Duplicate grants, late purchases and closing/restricted accounts are checked.
- Date-range sales/attendance/top-products/top-attractions charts and PDF reports,
  voucher issuance/use events and issued-cohort redemption rates.
- Python TF-IDF/cosine personalized recommendations, weighted Gaussian KDE,
  English/Malay/Chinese retrieval assistant, ORB/RANSAC landmark matching and
  IsolationForest plus explicit activity-review rules. No automatic account
  suspension is based on these activity signals.

## UI reference

Original Figma artwork, rose/cream palette, separate screens, forms, selection
steps and visitor bottom navigation are reused. Inspected reference sets include
photo frames 125:320-401, groups 117:26/27/29/30/31 and 118:73, attraction entry/
ratings/points 123:170/174/179, landmark 99:239 and assistant 101:261/268. Missing
states and management screens follow the established application style.

Review screenshots are in `docs/integration/`. Browser review uses the existing
visitor's real records. Staff login is separate; staff mutations were checked
with isolated fixtures rather than changing live visitor records during QA.

## Verification evidence

- Full Flutter suite: **132 passed, 3 optional browser checks skipped**.
  Log: `.local/combined-flutter-final.txt`.
- Full backend and access-rule suite: **131 passed, zero failures**.
  Log: `.local/combined-backend-final.txt`.
- Full source analysis: **No issues found**.
  Log: `.local/combined-final-analysis.txt`.
- Actual Python inference/SMTP-adapter checks: **11 passed**.
  Log: `.local/ai-all-results.txt`. No actual SMTP email was sent.
- Actual Java Type 4 NDEF APDU checks: **7 passed**.
  Source: `test/native/NdefApduCheck.java`.
- Android debug APK built successfully at
  `build/app/outputs/flutter-apk/app-debug.apk`.
  Log: `.local/android-build-final.txt`.
- Release web is compiled/served by `tool/run-app.cmd`; runtime log:
  `.local/combined-app-runtime.txt`.
- Current authenticated API health reports `themeparksmartmanagement` on 8787.
- Combined Firebase rules were published and deployed source verified. Normalized
  SHA256: `4d7b4c83de61326687aea5a6983af7018fe4368108460ab37be2a127751c1485`.
  Source backup: `.local/integration-20261109/published-final.rules`.

The running application uses the real shared Firebase project. Automated
mutations use isolated Auth/Firestore fixtures. No fixture accounts or records
were created in the shared project. Ticket and photo confirmation make no bank
or card charge, as agreed; PAN, expiry dates and CVVs are not persisted.

## User setup / hands-on checks remaining

See `SETUP_CONNECTIONS.txt` for exact versions and steps:

- Actual Mapbox public token and calibrated park bounds.
- Actual Situm venue, survey, positioning setup, floorplans, paths and POI IDs.
- SMTP provider/from address/credentials, followed by a real delivery check.
- Firebase Phone Authentication/SMS settings and native app fingerprints.
- Actual park coordinates and reviewed weather/loyalty policies. Weather and
  no-show policies were not enabled on the user's behalf.
- Physical camera/microphone/location/biometric/NFC/USB/printer checks. Android
  pass HCE and staff reading are implemented; compatible hardware is required.
  iOS speech input falls back to typing; native Android/browser speech is wired.
- iOS build/signing on a Mac. No iOS binary was compiled on Windows.
- Sign in with an existing admin account and perform the staff checklist.
- Password recovery currently uses Firebase email reset links; the PDF's OTP
  password recovery flow still differs. Currency conversion is a reference
  display with MYR checkout. Continuous visitor-location density is still
  outstanding; current heatmaps use confirmed queue demand. A complete Figma
  screen-by-screen visual sign-off is also pending.

The local authenticated Node API reuses Member B's transaction handlers and
serves the combined features without deploying Cloud Functions. It must be
running for API features. Cloud hosting/Functions deployment was not performed;
Firebase billing was not changed. No GitHub push or Git merge was performed.

Backups, model/provider details and lockfiles remain in the project. Current
feature-to-technology mapping is in `docs/FEATURE_TECHNOLOGIES.txt`.

## Final browser review

The latest release web build compiled in 57.7 seconds and is served on 5173.
After a full reload, the existing visitor session loaded successfully. The home
Buy Tickets action opens the real catalogue. The map opens its landmark flow;
contextual help describes that flow. Assistant requests against the restarted
API returned actual guidance and feature links. Photo setup/empty states,
current purchase history, offers and separate admin/kiosk sign-in gates were
reviewed without creating live fixture bookings or uploading face images.
Screenshots: final-home.jpg, final-assistant.jpg, final-photos.jpg,
final-history.jpg and final-landmark.jpg in docs/integration/.
The isolated check services were stopped after verification. The real Firebase
application API and release web server are left running for the user's review.

## Portable startup repair, 9 November evening

The reported failure was a second server attempting to bind occupied port 5173.
The launcher now verifies/reuses the running app, guards concurrent startup and
supports explicit restart/stop commands. An unrelated local server is preserved.

Windows first-run setup restores checksum-pinned Flutter 3.41.0, Node 22.23.4
and Python 3.12.14, project-local Firebase CLI 15.35.0, locked dependencies and
verified AI models. Runtime paths are generated per PC; Codex and author-specific
tool paths are not required. Each PC still needs its own authorized Firebase
operator sign-in. Source/credentials are separated by the repository ignore rules.

Project-local Flutter target flags keep web/mobile setup from requiring native
desktop plugin symlinks, Windows Developer Mode or Visual Studio. Android SDK
and iOS setup remain separate from the browser application.

Validation: a 544-file source-only copy under a path containing spaces restored
its dependencies/models and compiled/served the web application. Repeated launch,
safe stopping, cross-folder API protection and actual YuNet/SFace worker health
passed. Windows PowerShell 5.1 parses all scripts; 13 API/startup checks passed.
The Flutter suite was rerun using the independently installed SDK: 132 passed
and 3 optional browser checks skipped. A fresh web-only package-restore probe
created no desktop plugin symlinks. The primary folder is the final running copy.

Logs are in .local: clean-clone-start.txt, clean-clone-repeat.txt,
clean-clone-latest-start.txt, clean-clone-latest-stop.txt, startup-node-checks.txt,
portable-flutter-tests.txt, web-portability-check.txt and final-portable-restart.txt.
Current branch: feat/a-foundation. No commit, push, merge or billing change was
made during this repair. RUN_ON_ANOTHER_PC.txt documents the matching clone branch.

Final repaired-runtime browser check: reloaded the primary application, restored
its existing visitor session and received an authenticated assistant response
through the project-local CLI/Node/Python setup. Screenshot is saved locally at
docs/integration/portable-startup-verified.jpg and excluded from Git. Primary
web and API servers remain running. Re-running the ordinary launcher exits
successfully and preserves the existing server. The restart command was also
verified from Windows PowerShell 5.1.
