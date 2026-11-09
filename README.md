# Theme Park Smart Management System

Flutter application for the final year project. The application uses the existing Firebase project `themeparksmartmanagement` and its registered visitor accounts.

Member A and Member B are now combined in this primary folder. Start with
[START_HERE.txt](START_HERE.txt) for launch commands and the hands-on checklist,
and [SETUP_CONNECTIONS.txt](SETUP_CONNECTIONS.txt) for provider/device setup.
The older module handovers describe individual milestones before integration.
For a new Windows PC, follow [RUN_ON_ANOTHER_PC.txt](RUN_ON_ANOTHER_PC.txt).

## Run the app

From the project folder:

```powershell
.\tool\run-app.cmd
```

Open http://localhost:5173 and sign in with an existing registered account. If the app is already running, refresh the page.

The launcher installs missing pinned Flutter/Node/Python tools, restores locked
application and project-local Firebase CLI dependencies, verifies AI models and
checks Firebase project access. First-time setup can take several minutes.
Complete your own Google/Firebase sign-in when prompted. Codex is not required.
Flutter packages are restored with `flutter pub get --enforce-lockfile`, so
missing QR/scanner packages are downloaded using the exact locked versions.
Keep the launcher terminal open while using the app. It compiles and serves the
release web application on IPv4 127.0.0.1, without requiring a Chrome debugger
connection. Open the localhost URL once Flutter reports the app is being served.
This also avoids IPv6-only localhost binding in browser previews. After restarting
the computer, start the launcher again.
If it is already running, the launcher verifies and reuses it. After pulling
source changes, use `.\tool\run-app.cmd -Restart`. Stop this project's web/API
processes with `.\tool\stop-app.cmd`.

The launcher also starts the Node account service on 127.0.0.1:8787 using your
existing Firebase CLI sign-in and the same cloud Firebase project. It restores
the existing functions dependencies if needed; no Cloud Functions deployment
or billing upgrade is required for local use of the combined service. Core
technology details are in docs/FEATURE_TECHNOLOGIES.txt.

Use Flutter 3.41.0 with Dart 3.11.0, Node 22.23.4, npm 10.9.9,
Firebase CLI 15.35.0 and Python 3.12.14. The launcher prepares them.
FlutterFire CLI 1.4.1 is needed only when intentionally regenerating Firebase
configuration, not for running a clone. Keep all checked-in lockfiles.

## Module 1: tickets and booking

- Firebase sign-in and the existing visitor profile data.
- My Tickets with Upcoming, Used and Expired filters.
- Figma ticket hub, day/annual catalog and pass details with separate adult/child fares.
- Cart editing, guest details, loyalty-points review, payment selection and confirmation.
- Digital QR tickets, account-authorised scan/ID lookup, in-app wallet and PDF receipts.
- Atomic Firestore transactions, ownership checks, price validation and safe retry.

Prices and packages come from the shared Firebase catalogue. The payment action
confirms the booking without making a bank/card charge, as requested. Card
numbers, expiry dates and CVVs are never persisted. Android passes support NFC
and QR. The in-app ticket wallet works across supported application targets.

## Module 2: administrator web portal

Open http://localhost:5173/#/admin and sign in with an existing verified administrator account.
The portal uses the same Firebase project and registered web app. Its sign-in is separate
from the visitor session. Administrator access uses the existing trusted `admin: true`
Firebase Auth custom claim; the client cannot grant roles.

Included: visitor search/filter/sort/pagination, profile details/editing, private admin notes,
membership/watchlist tags, reversible access suspension/archive, live pass-package CRUD,
booking/ticket records, PDF receipts, CSV exports, dashboard/activity records and atomic
QR admission validation. Multi-day and annual tickets can enter once per valid day.
An inactive package stays available for historical records but cannot be newly booked.

See docs/MEMBER_A_MODULE_2.txt for the hands-on checklist. Shared `ticket_types` and
Member B's attraction rules remain preserved. Gate validation uses Firestore transactions,
so this module does not require changing the Firebase billing plan.

Use the Figma file linked in AGENTS.md as the UI reference. See docs/MEMBER_A_MODULE_1.txt for the hands-on checklist and docs/handoffs/member-a.md for integration details.

## Module 3: visitor points and vouchers

Profile now opens Points & History and My Vouchers. Completed ticket purchases
earn points at the rate saved with the confirmed order, once. Visitors can exchange points
for dining, souvenir and photo counter vouchers, view their QR/expiry/terms and
confirm single use. The redemption catalogue follows the Figma profile/rewards
design with original artwork. Balances, activity and voucher status are saved in
the same Firebase project. See docs/MEMBER_A_MODULE_3.txt for the hands-on checklist
and docs/handoffs/member-a-module3.md for data/integration details.

## Module 4: help and visitor support

Open Profile > Help & Support for searchable guides, FAQs, feedback/problem/
complaint submissions, optional attachments and My Requests conversations.
The administrator portal's Feedback & Complaints section provides a live case
inbox, assignment, priority/status/category, private notes, replies, resolution
and history. All records use the existing Firebase project; no new Cloud Functions
or billing setup is required. See docs/MEMBER_A_MODULE_4.txt and
docs/handoffs/member-a-module4.md for hands-on and integration details.

## Module 5: accounts, profile and security

Profile Settings now follows the full Figma account screens. Personal information,
avatar, nickname, height and preferences persist in Firebase. Email changes wait
for verification; password changes require reauthentication; password recovery
uses actual Firebase reset links. Remember me controls web persistence. Signed-in
devices, sign-out-everywhere and resumable account deletion use authenticated
server actions. See docs/MEMBER_A_MODULE_5.txt for hands-on steps.

## Combined proposal features

The combined app includes facilities and maps, individual/group reservations,
group membership and optional location sharing, staff attraction entry, visit
history/ratings, and configurable no-show/loyalty rules. Smart Photos includes
optional face matching, photo codes, editing, digital/print purchases, history,
downloads, staff photo management and a separate printing kiosk.

Administration also includes promotions/reward items, weather policies and
automatic compensation, crowd demand/peak hours/recorded journey monitoring,
landmark references, unusual-activity review, voucher usage and analytical PDF
reports. Python handles recommendations, queue KDE, multilingual assistance,
landmark matching, face recognition and activity analysis.

Mapbox, Situm, SMTP email, phone authentication and physical NFC/printing need
the user's accounts, venue configuration or devices. Connections and setup steps
are prepared; these services have not been represented as live when unconfigured.
Android compilation is verified. An iOS binary needs a Mac and signing setup.
See docs/IMPLEMENTATION_PROGRESS.md for current verification evidence.

## Automated checks

```powershell
flutter test --no-pub
.\tool\start-rule-checks.cmd
```

With those check services running, in another terminal:

```powershell
$env:GCLOUD_PROJECT = 'demo-themepark-fyp'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
$checks = @(Get-ChildItem functions/test/*.test.js | ForEach-Object FullName) + @(Get-ChildItem test/emulator/*.test.cjs | ForEach-Object FullName)
node --test --test-concurrency=1 --test-timeout=120000 @checks
```

Rule checks use isolated fixtures. They do not switch the application away from the shared Firebase project.
