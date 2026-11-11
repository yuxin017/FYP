# Combined application handover

Updated: 10 November 2026. The primary project is
`C:\Users\seowy\Documents\Codex\FYP`. Member B's incoming folder at
`C:\Users\seowy\Documents\FYP\FYP` is preserved separately.

Member A and B's source is integrated. The main proposal modules are ready for
hands-on review. The earlier approximately 85% estimate preceded the 10 November
OTP, currency-confirmation and live-location additions. Full completion still
requires provider setup, physical checks and a full Figma visual sign-off.
Read `START_HERE.txt` for launch commands and hands-on flows. Earlier module
handover files describe milestones before this integration.

## Included application flows

- Existing Firebase registration/sign-in, verified email, password reset,
  profile/avatar/height/interests/food preferences, sessions, account restrictions,
  recent-auth sensitive changes and resumable account closure. Authentication
  uses email/password and email OTP recovery; phone/SMS sign-in was removed at
  the user's request. Native retained-session unlock uses local_auth.
- Ticket catalogue and package details, cart, per-guest data, points, promotions,
  confirmation, digital QR/NFC passes, wallet, receipts and combined history.
  Foreign confirmations use trusted 15-minute currency quotes; the confirmed
  currency/amount/rate appear in history and receipts. Accounting uses MYR.
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
  controls are accessible from this screen. Queue demand and voluntary live
  visitor positions have separate views. GPS/Situm fixes feed aggregate KDE,
  hourly visitor counts and movement between campus zones. Positions expire
  after two minutes and private movement samples after 24 hours.
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

The revised proposal is `output/pdf/FYP Proposal - Updated.pdf`, generated by
`tool/update-proposal.py` from the original PDF in Downloads. Its technology
page replaces the required Cloud Functions backend with Node.js application
services and Python workers, states the presentation-PC runtime requirement,
retains Firebase Spark, and names IndoorAtlas as the selected planned provider.
All five pages remain. The first revision preserved pages 2-5; the latest
email-only scope revision also changes the authentication bullet on page 2.
Pages 3-5 and the rest of page 2 remain pixel-identical to the original. This
does not claim that indoor positioning or physical-device checks are complete.

See `SETUP_CONNECTIONS.txt` for exact versions and steps:

- Venue alignment of attraction positions and indoor floorplans. Mapbox's public
  token and TAR UMT Penang campus bounds are configured in shared Firebase;
  a live tile request and the running campus map were verified on 2026-11-10.
- Indoor positioning is LAST. The user selected IndoorAtlas; replacing the
  existing Situm SDK, creating the venue, mapping floorplans/paths and completing
  an on-site survey remain pending. No SDK replacement code was changed before
  the user deferred this work.
- Gmail SMTP authentication passed from shared server-only Firebase settings.
  The user confirmed receiving both a password OTP and a purchased-photo email
  on 10 November 2026, after uploading a real photo, claiming its photo code and
  completing a digital-photo order. The backend retrieves
  credentials into memory; local sender files are no longer required or retained.
- Phone/SMS authentication was removed from scope to retain Spark. Contact phone
  numbers remain in profiles. No phone provider setup is required.
- The user enabled weather benefits on 10 November 2026. Firebase read-back
  verified TAR UMT Penang, its campus coordinates, 2 mm rain threshold, one
  complimentary drink at the park café, and 30-day validity. The latest weather
  record had 0 mm precipitation and rainQualified=false. Live rain-voucher
  issuance/redemption remains unverified. Loyalty rules/reward catalogue are
  next; the missed-reservation policy remains disabled until configured.
- Physical camera/microphone/location/biometric/NFC/USB/printer checks. Android
  pass HCE and staff reading are implemented; compatible hardware is required.
  iOS speech input falls back to typing; native Android/browser speech is wired.
- iOS build/signing on a Mac. No iOS binary was compiled on Windows.
- Sign in with an existing admin account and perform the staff checklist.
- The user chose Node.js/Python services on the presentation PC with Firebase
  Spark. Cloud Functions deployment is outside the selected presentation setup;
  its prepared entry point remains available for a future explicit request.
  A read-only check on 10 November confirmed billing and phone sign-in remain
  disabled. Phone/SMS authentication was subsequently removed at the user's request.
- A complete Figma screen-by-screen visual sign-off is still pending. Password
  recovery now follows Figma's six-digit authentication and new-password steps;
  password-OTP inbox delivery was confirmed by the user. Legacy links remain supported.

The local authenticated Node API reuses Member B's transaction handlers and
serves the combined features without deploying Cloud Functions. It must be
running for API features. Cloud hosting/Functions deployment was not performed;
Firebase billing was not changed. No GitHub push or Git merge was performed.

Backups, model/provider details and lockfiles remain in the project. Current
feature-to-technology mapping is in `docs/FEATURE_TECHNOLOGIES.txt`.

## 10 November update

- Figma recovery frames 21:166, 21:168 and 24:189 guide the OTP flow. Codes are
  cryptographically generated, hashed in private records, valid for five minutes,
  limited to five guesses and single-use. Resend cooldowns survive API restarts.
  A successful OTP obtains a Firebase password-reset grant; Firebase handles the
  final password change. No shared account passwords were changed during checks.
- Currency quotes bind the authenticated owner, guests, selected passes, points,
  promotion and total. Altered or expired quotes cannot confirm orders. Uncertain
  retries preserve the original quote and order reference. Bank charges remain
  outside the agreed confirmation flow.
- TAR UMT Penang is the selected venue. Its map outline is from OpenStreetMap,
  not an indoor survey. Optional live GPS sharing is available from Map; the
  Situm screen can publish actual SDK fixes after opt-in and venue configuration.
  Expired locations never contribute to KDE even before bounded record cleanup.
- Prepared themepark-only Cloud Functions: individual/group reservations, visit
  check-in/ratings, weather-benefit claiming, scheduled weather and no-show jobs.
  Deployment has not been run. The original unrelated image functions are not
  loaded by the new entry point. Node/Python API services are still required.
- Gmail authentication and OTP/photo inbox delivery are verified and Mapbox
  is connected. Next are administrator policies and presentation-PC
  rehearsal. IndoorAtlas positioning is deferred until LAST. NFC/device hardware
  remains on hold. See FINISH_SETUP.txt for remaining checks and current choices.

Latest verification: 135 Flutter tests passed (3 optional browser checks skipped),
145 backend/access-rule tests passed, 12 Python tests passed, and full Flutter
analysis reported no issues. All PowerShell scripts parse under Windows
PowerShell 5.1. The release web build succeeded and the primary launcher restarted
both real-Firebase services successfully. Browser review confirmed the live
TAR UMT Penang weather card and campus map without requesting device location.
Logs: .local/remaining-all-flutter-tests.txt, remaining-all-backend-tests.txt,
remaining-analysis.txt and remaining-accounts-final.txt. Local browser screenshots:
docs/integration/penang-weather-20261110.png and penang-live-location-20261110.png.
The isolated check services were stopped. New source changes are not pushed yet.

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

## Shared configuration for presentation PCs, 10 November

The user chose to run a Git clone on another PC. Application settings now live
in applicationConfiguration/mobile; email settings live separately in the
server-only serverConfiguration/services document in themeparksmartmanagement.
The published Firestore rules were read and matched the checked source before
migration. Both collections are inaccessible to visitor/admin client accounts.

The launcher signs the operator into the project, downloads only allowlisted
client settings and generates .local/mobile.defines.json. The Node backend reads
email credentials into memory and injects them privately into mail-worker calls.
No SMTP credentials enter the generated configuration or compiled Flutter bundle.
Email, Mapbox, Situm and deployment configuration commands update the shared
documents. The old env.json and .local/services.json were removed after cloud
round-trip verification and SMTP authentication succeeded.

A 572-file source-only copy under .local/portable clone 20261110 restored its
locked dependencies, generated settings from Firebase, authenticated the shared
SMTP sender and launched the release web app and correct-workspace API without
either old local settings file. This used the existing operator sign-in on this
computer; another PC must complete its own authorized Firebase project sign-in.
No actual email was sent by the verification.

The clean-copy test exposed a split AppData Python installation under Windows
application path redirection. Setup now checks pip's actual installer import and
restores the same checksum-pinned Python in the writable project if necessary.
It preserves pip's resource security checks. The repaired clean-copy setup and
launch succeeded. The primary project was restored as the final running copy.

Verification: 150 backend/access-rule checks and 13 Python checks passed; all
PowerShell scripts parse under Windows PowerShell 5.1. Logs are in .local:
shared-config-checks.txt, shared-config-all-backend-tests.txt,
shared-config-clean-clone-setup.txt, shared-config-clean-clone-final-start.txt,
shared-config-primary-final-start.txt and shared-config-final-verification.json.
New source changes still need publication before another PC clones this update.

## Completion corrections, 10 November afternoon

Resumed implementation after the user clarified that the current priority is
finishing the application. Password-OTP and purchased-photo email delivery were
already confirmed by the user. Weather and loyalty policies are saved; the
existing active reward catalogue needs no additional sample-data setup.

The compact admin sidebar now has a persistent draggable scrollbar. Promotions,
Reward Catalogue, Loyalty Rules, Photo Prices and Weather Benefits wrap onto
additional rows instead of hiding settings beyond a horizontal scroll area.
Existing page structure, artwork and colours are retained.

The proposal specifies penalties for repeated no-shows. The settlement job now
counts missed reservations per visitor and policy period, with a staff-configured
threshold of 2–20 (default 2). The first miss keeps points while releasing capacity.
Transactions serialize concurrent misses, settle each reservation once and cap
deductions at the available balance. Disabling and re-enabling the policy starts
a fresh count. Private counters are inaccessible to Firebase client accounts and
are included in account deletion. Existing visitor histories were not edited or
used as test fixtures; previously posted deductions were not rewritten.

Verification: 18 targeted Flutter checks passed, including a 420-pixel settings
layout and scrolling to the final compact-menu item and back. Twelve isolated
backend/rule checks and twelve account-service checks passed. Dart analysis of
the changed application files reported no issues. The release web build succeeded
in 43.1 seconds, and the primary web/API services respond successfully. Browser
review verified the visible sidebar scrollbar, all five policy tabs, the saved
loyalty summary and the new threshold input without saving policy changes.

Logs: .local/admin-loyalty-flutter-checks.txt, admin-sidebar-final-checks.txt,
admin-loyalty-backend-checks.txt, admin-loyalty-account-checks.txt,
admin-loyalty-analysis.txt and admin-loyalty-restart.txt. Browser proof:
docs/integration/admin-loyalty-completion-20261110.png. The normal application
continues to use themeparksmartmanagement. No Git push or billing change occurred.

IndoorAtlas integration and the actual floorplan/signal survey remain last, as
requested. Physical NFC/printer and native-device checks remain on hold. This
update does not claim that those integrations are complete.

## Email-only authentication scope, 10 November

The user chose to retain Firebase Spark and remove all mobile-number login.
Removed the phone-number login selector, SMS linking/removal screen and its
backend profile-sync route. Device-unlock guidance now directs visitors to sign
in with email/password. Profile and registration contact numbers are retained;
no existing visitor contacts, credentials or accounts were changed.

The revised proposal now specifies email/password registration and sign-in,
with biometric unlock for a retained session on supported devices. Its original
source in Downloads is unchanged. Actual phone-authentication text was removed
from page 2, rather than hidden by a white overlay. Pages 3-5 and every pixel
outside the authentication block on page 2 were verified against the original.
The updated five-page PDF was rendered and visually reviewed.

Verification: 12 account/login Flutter checks and 12 account-service checks
passed. Analysis of the changed login/security screens reported no issues.
Firebase read-back confirmed billingEnabled=false and phoneEnabled=false.
Logs: .local/email-only-account-checks.txt, email-only-backend-checks.txt and
email-only-analysis.txt. Remaining software work includes IndoorAtlas and
closed-app reservation notifications; physical-device/NFC/printer checks remain.
No billing change, shared-account mutation or GitHub push was performed.

The release web rebuild succeeded in 125.5 seconds. Browser review confirmed
the email-only login label with no method dropdown and the Security & Account
card with no SMS-linking entry. The existing visitor session restored normally.
Proof: docs/integration/email-only-login-20261110.png and
email-only-security-20261110.png. The primary web/API services remain running.

## Closed-app reservation reminders, 10 November

IndoorAtlas remains explicitly on hold. Reminders now use scheduled native OS
notifications on Android/iOS and encrypted Web Push in supported browsers, with
the selected Firebase Spark and Node/Python backend. Profile's bell and Security
& Account -> Notifications open device settings. Review Reservation requests
permission when the visitor opts in; My Reservations includes per-booking switches.
Permission refusal keeps reminders off and shows a recovery message. Existing
in-app reminders remain a fallback. Notification taps open the visitor's own
reservations, including cold starts after notification-device initialization.

Android includes notification/alarm permissions, the icon and reboot/scheduling
receivers. UTC schedules preserve the actual booking instant, deduplicate refreshes
and clear on cancellation, opt-out or sign-out. iOS includes its notification
delegate but has not been built/tested on a Mac/iPhone. Native changes made on
another device while closed synchronize on next launch; saved native schedules
otherwise run without the backend.

Signing keys are created once in private serverConfiguration/reminders. Only the
public key reaches verified clients. Private browser subscriptions and jobs are
server-written and included in account closure/expiry cleanup. Sending checks live
booking/account status, revoked sessions, concurrent workers and bounded retries.
The worker rejects expired/off-site/wrong-device payloads and duplicate deliveries.
Browser sending needs the running Node service, internet, notification permission
and an available browser background service. OS Focus/power settings and force-
stopping/shutting down the app, browser or PC can affect delivery.

Verification: full Flutter suite 143 passed, 3 optional browser checks skipped;
10 final targeted checks passed after cold-start handling was added. Thirty-four
backend/rule/browser-worker/account checks passed on isolated fixtures. Final
analysis reported no issues. Android APK built in 372.7 seconds and release web
in 117.8 seconds. Firebase read-back verified shared signing keys without exposing
the private key. No visitor fixture bookings/accounts were created in shared Firebase.

Browser review restored the existing visitor and opened Notifications with its
switch off. No notification permission was granted or message sent on the user's
behalf. Actual arrival after closing the tab/app remains a hands-on device check
after enabling notifications and opting into an upcoming reservation. Physical
Android/iPhone delivery and reboot behavior are not claimed as verified.

Logs: .local/closed-reminders-all-flutter-tests.txt,
closed-reminders-final-targeted-tests.txt, closed-reminders-final-backend-tests.txt,
closed-reminders-final-analysis.txt, closed-reminders-android-build.txt and
closed-reminders-app-restart.txt. Screenshot:
docs/integration/closed-app-reminders-20261110.png. Isolated test services stopped;
primary web/API remain running. No Git push/merge or billing change was performed.

## Publication package, 11 November

The user requested publication to the existing yuxin017/FYP repository. The
target remains feat/a-foundation. The package includes the shared Firebase
configuration/startup changes, email OTP, currency confirmations, venue/weather
and live-location additions, repeated-miss rules, email-only authentication,
closed-app reminder implementation, updated proposal and corresponding tests.

The repository credential review compared candidate files with the protected
email and notification signing credentials without printing their values.
Runtime files, credentials, dependencies, builds and local review screenshots
remain excluded. Shared credentials stay in Firebase and are loaded by each
authorized PC. The new-PC instructions point to feat/a-foundation, and the
documented lockfile checksums match this publication package.

Existing verification evidence remains applicable: Android/release-web builds,
143 full-suite Flutter checks, 10 final targeted reminder checks and 34 final
backend/rule/account/browser-worker checks passed. Actual notification arrival,
native-device/NFC/printer checks and IndoorAtlas remain as described above.
IndoorAtlas is explicitly on hold; this publication does not claim full completion.
