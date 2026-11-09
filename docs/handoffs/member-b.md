# Member B handoff — attractions and reservation journey

## Park facility catalogue

**Park Facilities → Add Facility** offers Attraction, Dining, Facilities and
Shops. Non-ride entries reuse the park catalogue, admin access and map
coordinates. They store the selected type as the existing category field.
The park map filters both its pins and Nearby list by type and search. The
ride queue and booking service accept attractions only.

Both Chrome builds and scoped analysis passed. The Member B suite passed 69
tests, and a layout check confirmed all four filters fit at 390 px. The local
backend suite passed 40 tests. All 13 catalogue permission checks also passed
against a copy of the active Firestore rules using isolated test records.

## Module 5 — Admin reservation list

The separate admin portal has a **Reservations** section behind the existing
Firebase admin claim. It reads saved reservations for the selected Kuala Lumpur
visit date and looks up the names of those visitors. The table supports search,
status filters, pagination and read-only details. The selected-date query uses
the existing `startsAt` index and falls back to visitor IDs when profiles are
unavailable.

The layout uses the sidebar, summary cards, filter row and table from the
exported admin design. The Figma connector reached its request limit during this
module.

The isolated Firestore checks cover Kuala Lumpur date boundaries, visitor-name
lookups, cross-visitor denial and blocked direct writes. The page tests cover
search, live status changes, switching dates, details and retry. 67 Member B
Flutter tests, four Firestore access checks and the admin web build passed.
The full-project analyzer reported the same 25 baseline findings.

To review locally, use **FYP Admin Portal - Chrome → Reservations**. Saved
reservations are read from `themeparksmartmanagement`. A live customer booking
still requires Blaze and deployment of the reservation callables. Review the
matching-date ticket → confirmation → admin list journey after that deployment.

## Current update — 7 November 2026

Reserve → time → individual visitor → review → confirmation is implemented with
real Firebase repositories and transactional reserveSlot/cancelReservation
exports in us-central1. History/cancellation are included. Rebooking after
cancellation is allowed; duplicate attraction/day and overlaps are rejected.
See [reservation-journey.md](../reservation-journey.md) for schema/interfaces.

**Live booking is blocked:** billingEnabled=false and Cloud Functions API is
disabled. No Functions were deployed; payment settings were not changed.
My Tickets reads issued Firestore tickets for the signed-in visitor. Add Ticket
requires Member A's ticket issuance and checkout integration.

Reservation read rules were published at 01:43:11 MYT, ruleset
206b290a-47b1-4a60-8a4a-3ec00a759a2e, preserving every previous shared rule.
Only owner/admin reads are enabled; direct writes remain denied and private
transaction/retry records deny client access. No live fixtures were inserted.

60 Member B Flutter tests, 35 backend/rules tests and the actual Flutter web
callable SDK probe passed. Three original opt-in browser-runner tests are
skipped in VM runs. Customer and portal debug web builds passed (64.6s/68.3s).
Analysis retains the same 25 baseline findings (7 warnings, 18 infos); there
are no new findings. The unrelated starter counter test still fails at line 19
because the app no longer contains the template counter. Both builds report
existing flutter_tts WebAssembly dry-run limitations; JavaScript builds pass.

Real widgets were inspected at 390 mobile/1440 desktop and at 320 with enlarged
text for visitor/review pages. Reminder delivery/cancellation and a selected
session filling up are tested. All verification-only emulator processes stopped.
The following Module 1 history is superseded here where it calls booking future
work. GitHub main was checked and remains b18e525; A's foundation is not shared
there yet. Do not start another module or push without the user's instruction.

## Previous Module 1 delivery record

Updated 6 November 2026. Working branch: feat/b-attractions.
Base commit: b18e525039123e027ade9cea43c6b4b48b399d95.
All source is local/uncommitted. No push, PR or merge has been performed.

## Delivered in this revision

Customer Virtual Queue follows copied Figma file ZdNw5WlLhH9sfV6TsOyE6u frame
122:131, with real Firestore photos, details, crowd/wait reports and session
availability. A's shared bottom navigation remains unchanged. The separate
admin website follows the approved adaptation of Figma login/table/sidebar
frames 128:529, 135:551 and 136:583.

The original task split includes slot administration in Module 1. The earlier
handoff incorrectly deferred it. Attractions and sessions can now be created
and edited from the separate portal. Booking/cancellation remains Module 2;
full map, heatmap and itinerary remain Module 3. Stop here until the user's
next instruction; do not start another module automatically.

Entry points:
- Customer: lib/main.dart; select FYP - Chrome, sign in, open Queue → All.
- Portal: lib/admin_main.dart; select FYP Admin Portal - Chrome (port 5411).

The customer import graph contains no admin code or write repositories. Both
clients use the real themeparksmartmanagement Firebase project. No runtime test
fixtures or local database fallback are provided. New photos, description,
legacy crowdLevel, standbyMinutes and server updatedAt are saved to attraction records.
The user explicitly approved these richer fields. Existing records remain
readable; their missing details must be filled through the portal.

New covers are compressed with the existing image dependency, stored as JPEG
Base64 (at most 240,000 characters), and selected/previewed through the form.
No Storage service or dependency was installed. Read-only review aggregates
are supported but not created; the UI shows Not rated until actual reviews
exist. Missing crowd/wait values are reported honestly. Nearby uses a manually
selected starting attraction and schematic distance, without GPS/walk claims.

Session core fields remain attractionId, startsAt, endsAt, capacity, bookedCount.
Optional confirmedCount and retired fields support the updated queue projection.
UI capacity is 1–1,000; new entry windows are 15 minutes within 9:30 AM–7:30 PM.
The repository
reads current counts transactionally, never overwrites them, rejects capacity
below bookings and prevents moving booked sessions. Started sessions are
read-only. IDs are retained across uncertain-save retries. Business conflicts
are thrown outside transaction callbacks to preserve errors in the web SDK.

The portal now also has a Delete action with explicit confirmation. Deletion
sets server deletedAt/updatedAt timestamps and closes the attraction. Active
list/detail readers exclude deletedAt records; linked sessions and reservations
remain for history. Stale confirmations cannot delete concurrent changes, retries
are idempotent, and the rules reject later edits/restoration/new sessions.
No hard erase or live-record cleanup was performed while implementing it.

## Firebase access — repaired and published

The user changed the earlier Keep rules local decision to authorize Firebase
rules publication while continuing to prohibit GitHub pushes.

The original six-field attraction access repair was published at 20:25:43 MYT
on 6 November 2026 as ruleset 0571e1b0-1476-4cd8-9505-296087501cc8. The user
confirmed that live reads/writes worked afterward.

The richer attraction/session block was published at 21:22:59 MYT as ruleset
6473ef70-be65-413c-8389-8cee28e4d357. Its source was read back and matched:
98b3abfe6b768970fa2f2c0e628bf6c93f35665350626e7584165f0f6bc90497.
All shared source outside Module 1 was preserved byte for byte, including A's
latest profile/ticket/order/guest protections. Guards checked concurrent live
changes before publication. No live attraction/session records were seeded.
Revised-form live write acceptance remains a manual user check; emulator SDK
persistence and active policy/read-back verification have passed.

The subsequent Delete update was published at 23:09:39 MYT on 6 November 2026.
That ruleset was 75ec4806-6539-4511-9abc-acd3fe83b99a, merged onto the newer live
862717df-1a7e-41aa-b53c-e5bebcf88a00 source with all non-Module-1 rules unchanged.
Verified released SHA-256:
d8b02629772cc64d0bb8361db1e41dcee397317d552f349b8455166906d65b1d.
No live records were deleted during implementation. Active readers hide
non-null deletedAt values; future history views should explicitly read retained
records rather than using the normal active-detail reader.

Only server-managed boolean Firebase Auth custom claim admin: true grants
management. The user's supplied active/email-verified Auth UID had previously
been granted and reread to verify this claim. Profile roles are not accepted.

Use firestore/firestore.rules as the full policy with firebase.attractions.json.
Never publish the isolated firestore/attractions.rules test fragment as the
complete live source. A must integrate the shared deployment configuration
before future coordinated deployments, always inspecting concurrent live rules.
No Functions, Hosting, indexes, registrations, passwords or IAM were changed
by the Module 1 rule release. See ../attraction-access-fix.md for the history.

## Validation

- 50 focused model/widget/portal tests passed; three opt-in browser-runner tests
  skipped. Includes narrow/enlarged text, photos, filters, read/error/retry,
  live status, admin boundaries, retained edits, session protection and
  confirmed/cancelled/failed/stale/duplicate deletes plus access recovery.
- 20 merged-rule tests passed, including A's owner/profile/ticket/order privacy
  regressions, authenticated reads/writes, immutable deletion, retained linked
  history and rejected new sessions for deleted attractions.
- Actual Flutter web SDK/repository checks passed in isolated headless Chrome
  against temporary emulators: create/read/update/retry/concurrency, rich fields,
  visitor read/denied writes, sessions, booking-count preservation and real
  delete persistence/retries/filtering/immutability with history retained.
- Customer debug web build: passed, 49.6 seconds, build/web.
- Separate portal debug web build: passed, 48.0 seconds, build/admin_web.
  Both used existing packages and --no-pub. No dependencies were upgraded.
- Analysis: same 25 baseline findings (7 warnings, 18 infos), no new findings.
- Real widgets visually inspected at 355/440 customer widths, 390 portal width
  and 1440 desktop width, with fonts/images and isolated test-only records.
- Cloud rules compile successfully; one pre-existing unused index variable
  warning remains. Rule tests exercised the exact published checksum.

The three original Flutter browser-runner tests cannot load their page on the
pinned Windows SDK due to a CanvasKit loader 404. They are not claimed passed;
the separate normal-web SDK probe supplies actual repository validation without
patching the SDK. The stale starter counter test remains a separate baseline
failure. Android/iOS readiness is not established by these web checks.

## Interfaces and shared contract

AttractionReader exposes watchAttractions and watchAttraction(id).
SlotReader exposes watchUpcomingSlots(from, until) and watchAttractionSlots(id).
The customer-facing repository implements both without writes. Portal-only
AdminAttractionStore/AdminSlotStore provide guarded create/update operations.

Active queries use default single-field indexes. The foundation's old
watchSlots(attractionId, from) retains a composite-index definition in
firestore.indexes.json, but the current UI does not use it and no index was
published. Schema errors propagate into visible retry states rather than fixture
fallbacks. Slots use UTC instants, displayed in Asia/Kuala_Lumpur (UTC+8).

Identity remains Auth UID; visitor profiles remain visitors/{uid}. Shared
collections remain visitors, ticketPackages, orders, tickets, attractions,
attractionSlots and reservations. References use document IDs, not names.
Money remains MYR integer minor units; visitDate is park-local YYYY-MM-DD.
Attraction statuses open/closed/maintenance, tickets valid/used/cancelled, and
reservations confirmed/cancelled/checked_in are unchanged.

Future reserveSlot(slotId, ticketId, requestId) and cancelReservation(reservationId,
requestId) return reservationId/status. Module 2 must enforce ticket ownership,
same-day visit, both valid/used admission, ride status, height, future slot,
atomic capacity/counts, one visitor per reservation, multiple different
attractions with one booking per attraction/visit and no overlapping windows,
caller-scoped idempotency and once-only cancellation
release. These are requirements, not implemented booking claims.

## Coordination and setup differences

Coordinate A's reviewed foundation, portal shell, Firebase configuration,
navigation and lockfile changes before merging; do not rewrite their work.
The ignored local VS Code settings select Flutter 3.41.0/Dart 3.11.0. The existing
four coordinated lock differences remain: matcher 0.12.18, meta 1.17.0,
test_api 0.7.8, vector_math 2.2.0 with their hashes. No package manifest,
backend lockfile or engine was changed. Main functions stays Node 22; separate
moderation stays Node 24. No backend feature exports were changed in Module 1.

Ignored env.json remains {} for the baseline asset declaration; A's unshared
pubspec cleanup has not been copied. Web options use the confirmed project,
while .firebaserc/Android metadata still need A's shared old-project cleanup.
Always pass --project themeparksmartmanagement for live Firebase CLI operations.
A's old Home demo notice should be updated separately. Do not run heritage seeds.

Fixture data under test/ is exclusively isolated test data, never runtime.
Fixture IDs from the foundation remain available for later coordinated tests;
they do not represent issued live tickets, provisioned Auth accounts or bookings.
Walking durations need an agreed schematic scale/location source. Full planner
and heatmap controls are disabled pending Module 3. Reviews need an agreed
source; do not manufacture ratings. Use ../member-b-run-guide.md for user checks.

## Latest Module 1 policy revision

The user confirmed Low 0–49 / 15-minute starts, Moderate 50–100 / 30-minute
starts, Busy 101+ / 45-minute starts, with park hours 9:30 AM–7:30 PM KL time.
The old manual crowd selector is removed. Live slot confirmedCount changes
recompute crowd and offered starts without moving existing bookings. Clock
expiry removes elapsed windows from the queue. Standby estimates stay separate.

Publish day persists a real common 15-minute grid, safely replaces unbooked
future legacy sessions with retired history retained, and preserves booked
windows/counts. Repeating publication is idempotent. Firebase SDK tests passed
this operation and a real 50-to-49 queue drop with capacity retained.

Reservation workflows and callable exports remain unimplemented for Module 2,
as explicitly requested. Module 2 must atomically maintain confirmedCount and
bookedCount; checked-in places still consume capacity but leave the confirmed
queue. It must enforce the revised per-attraction and non-overlap rules on the
server, superseding the older global one-active guard. Confirm the cancelled
attraction rebooking policy before implementing that part. See
../module1-queue-policy.md for the complete current contract.

The queue-policy rules were published at 23:50:23 MYT on 6 November 2026 as
73536f67-0e50-4284-8bae-6dd9350cc27d. Read-back SHA-256:
1a4a65da810f87e5bde25a7fd2771e1b69172626089fe536365fbb2aada950c7.
All source outside Module 1 was preserved. Final builds passed (customer 49.6s,
portal 48.0s); analysis retains only the 25 baseline findings. Updated cards,
editor and Publish Day screens were visually inspected at phone/desktop sizes.
No live records were generated or changed for validation, and no code was pushed.
