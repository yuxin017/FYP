# Member A: Module 2 handover

Updated 6 November 2026. Module 2 is ready for hands-on checking. Do not start a
new module without the user's next instruction. No GitHub commit/push/merge made.

## Scope and design

Administrator web portal: http://localhost:5173/#/admin. Main target is desktop web;
smaller windows use a drawer and horizontally scrollable data tables. Original
Figma admin sign-in 128:529, Visitor Accounts 135:551, Visitor Profile 135:552 and
Activity Monitoring 135:553 supply the layout/style. Original login brand artwork
is assets/images/admin/login-brand.png; source references are docs/design/admin.
Data comes from Firebase, not the names/counts/dates in Figma. Supporting ticket,
package and validation screens extend the same style where frames are incomplete.

Includes visitor search/filter/sort/pagination, profile overview/editing, private
notes, manual membership/risk/watchlist tags, reversible suspension/archive,
ticket/order records, PDF receipts, CSV export, live pass-package management,
dashboard/activity summaries and atomic QR admission. Separate role management,
automated risk scoring, complaint handling, merchandise and Member B's reservation
work were not implemented as part of this bounded module.

## Authentication and integration

AdminFirebase uses a named SDK instance ThemeParkAdmin with the SAME existing
themeparksmartmanagement options and registered web app. This does not create a
Firebase project or registered app. Admin auth/Firestore use that instance so the
visitor's primary sign-in remains intact. Admin access requires the existing trusted
Firebase Auth custom claim admin=true, and the UI requires verified email. Existing
administrator accounts were found; no new user, claim or role was created for QA.
Do not trust visitors.role for admin authorisation or offer client-side role grants.

main.dart adds /admin. SplashScreen now checks that its route is still current
before redirecting, fixing initial /admin deep links being overwritten after two
seconds. AuthGate wraps the normal visitor app in AccountAccessGate. Existing
visitor/ticket screens remain in the primary session and project.

The deployed Firestore rules were fetched again immediately before the merge.
Member B's current attractions rules, legacy ticket_types, existing profile rules
and all Module 1 purchase rules were preserved. The admin addition was deployed and
the released source was verified against local firestore.rules. Billing is unchanged;
there are no new Cloud Functions or privileged credentials in the Flutter app.

## Data additions

- visitorAdmin/{uid}: private membership/riskLevel/watchlisted/notes, updatedAt,
  updatedBy. Only trusted admins can read or write. Points and roles are not editable.
- visitorAccess/{uid}: active/suspended/archived status, reason, updatedAt/by.
  The owner may read their own access notice; only admins can write. Self-restriction
  is rejected. These are application access controls, not Firebase Auth account deletion.
- visitorSessions/{uid}_YYYY-MM-DD: ownerUid/day/session_opened action, createdAt,
  lastSeenAt. The visitor records one real application session per Malaysia day and
  updates lastSeenAt on later opens. Admin summaries read these records. No IP,
  location or device fingerprint is collected. createdAt cannot be rewritten.
- adminAudit/{random48hex}: action, targetIds, actorUid, details, createdAt.
  Immutable admin-management records. The caller and server timestamp are enforced.
- admissions/{requestId}: ticketId, orderId, ownerUid, actorUid, visitDay,
  createdAt, outcome=admitted. Created atomically with the ticket's admission update.

Pass management writes the SAME ticketPackages used by Module 1, not ticket_types.
Editor supports exact integer MYR sen fares, optional child fare, day/annual/add-on
category, validity days, display order and active status. Existing bookings keep their
recorded price and dates. Deactivate rather than delete. Existing ticket_types is
preserved for later integration and must not silently be treated as ticketPackages.

Suspended/archived visitors cannot enter the normal visitor app or issue new tickets
through direct client writes. Existing records and previously issued admission rights
are retained. The status check is in ticket-create rules rather than order-create rules
to preserve the ten-ticket per-operation access limit. The five-pass/ten-guest/points
boundary still passes the total atomic rule-access limit.

## Ticket validation

Input is the existing TP1:<ticket-document-id> QR, full ID, or readable ticket code.
Known legacy readable IDs may be resolved through the admin's loaded ticket list.
The admin previews before pressing Admit Visitor. A Firestore transaction rechecks
the persisted status and Malaysia visit day. Fields added to tickets are usedAt,
usedBy, validationId, lastAdmissionDay (UTC-midnight timestamp encoding the Malaysia
calendar day), and admissionDays (list of those day timestamps).

Each ticket can enter once per valid day. Single-day/final-day scans set status=used;
multi-day/annual passes remain valid for later dates and retain their history. The
visitor ParkTicket model includes admissionDays and shows Used on the admission day,
returning a still-valid multi-day pass to Upcoming on another valid day. Entry writes
are coupled to immutable admission receipts. Concurrent scans admit exactly once.
Repeating an uncertain requestId returns the recorded confirmation without a new write.
The visitor UI and QR IDs remain compatible; Member B should continue using valid/used
ticket status plus date/validUntil for reservation eligibility, not active-day filter labels.

## Verification

15 Flutter tests passed: all Module 1 cases plus admin search/sort/profile navigation,
exact fare editing, preview-before-admission, duplicate taps, compact layout, sign-in
validation and a regression for splash deep-link routing. Test-only visual captures
under .local/admin-qa use isolated fixtures and loaded real Flutter fonts/artwork.
They are not a separate running app and were not seeded to the shared project.

18 isolated backend checks passed: existing checkout, five passes/ten guests/points,
admin/visitor separation, private notes, protected identity/points, soft deactivation,
suspension enforcement, daily sessions, immutable audits, date rejection, duplicate-scan
races and multi-day admission validity. The scoped analyzer is clean and the final
JavaScript web build passed. The normal app never uses the isolated rule-check services.

Browser verified the live admin sign-in at the Figma desktop size, empty-credential
validation, stable /admin deep links, no admin-page console errors, and the primary
visitor app reopening with the existing Seow Yong Kang session. Privileged admin CRUD
and admissions were exercised with isolated authorised fixtures, not by impersonating
another existing shared-project administrator. The user's hands-on checklist covers
those live actions after they enter their own authorised administrator credentials.

## Running and handover

build/app-preview is copied to the existing build/ticket-preview server on port 5173.
tool/run-app.cmd starts normal Flutter Chrome development after stopping an existing
server on that port. No new package versions were introduced; pubspec adds the admin
artwork folder. Keep the Module 1 dependency lockfile with the source. Flutter 3.41.0 /
Dart 3.11.0, Node 22.23.4, npm 10.9.9, Firebase CLI 15.35.0, FlutterFire CLI 1.4.1.

User checklist: docs/MEMBER_A_MODULE_2.txt. Leave Module 3 until the user requests it.
