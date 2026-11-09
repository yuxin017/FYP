# Module 1: attractions and session administration

Updated 6 November 2026. Branch: feat/b-attractions. Source remains local and
uncommitted; no GitHub push, PR or merge has been performed.

## Design and scope

The customer Virtual Queue follows copied Figma file ZdNw5WlLhH9sfV6TsOyE6u,
frame 122:131. The white photo cards, rose controls, crowd banner, filters and
next-session presentation were compared with its screenshot. Frames 128:529,
135:551 and 136:583, plus the supplied Admin Design PDF, inform the portal.
The user approved adapting their sidebar/colour/card/table style because the
file has no attraction-specific form. Screenshots are not runtime UI/data.

The original task split includes attraction AND slot administration in Module 1.
The earlier handoff incorrectly deferred slots; this revision includes them.
Booking/cancellation stays Module 2, and the full map/heatmap/itinerary Module 3.

Customer entry: lib/main.dart. Separate portal entry: lib/admin_main.dart.
The customer import graph contains no admin repository, editor or claim tool.
Both clients use the existing cloud Firebase project, not a local data service.

## Implemented behavior

- Real-time catalogue, name search, design filters, details and session
  availability for a selected Kuala Lumpur park date.
- Recommended shows open, height-eligible attractions, prioritizing saved
  category interests then reported wait. This is simple catalogue ordering,
  not the later personalized itinerary engine.
- Available Now requires open status and a future session with capacity.
- Nearby asks for a starting attraction and sorts by schematic distance; it
  does not claim GPS location or invent walking minutes.
- Calendar selects the date; View Times shows actual records without booking.
- Admin login/reset/sign-out, verified claim gate, responsive portal shell,
  searchable/filterable/paginated table, attraction create/edit/status.
- Revised editor: photo selection/preview/replacement, description, automatic crowd,
  standby wait, original safety/status/category/map fields and validation.
- Session creation/editing with future times and integer capacity. New count
  is zero and counts cannot be edited in the portal.
- Transactions protect concurrent edits, retain IDs for uncertain-save retries,
  prevent duplicate submissions and preserve form inputs after failed saves.
- Session edits read the latest booking count, cannot reduce capacity below it,
  cannot move booked sessions and never overwrite counts.
- The portal has a confirmed Delete action. It closes the record and sets a
  server deletedAt timestamp, removing it from active admin/customer lists and
  customer details. Linked sessions and reservations remain intact. It cannot
  be edited/restored or assigned new sessions afterward. Hard document erasure
  is denied so historical references remain valid.

## Approved record additions

The user explicitly approved the richer customer-facing attraction information.
Existing six-field records remain readable without manufactured defaults.

| Field | Meaning |
|---|---|
| description | Customer description, up to 1,200 characters |
| coverImageBase64 | Compressed JPEG, up to 240,000 Base64 characters |
| crowdLevel | Legacy report, superseded by the live confirmed-count policy |
| standbyMinutes | Optional integer 0–600; null means unreported |
| updatedAt | Server timestamp of the last attraction change |
| deletedAt | Server timestamp set only by the explicit admin Delete operation |

The encoder uses the existing image package, accepts supported images up to
8 MB, corrects orientation, scales to at most 640 pixels and compresses before
saving. It reuses the project's Firestore image approach; no Storage bucket or
new package is needed. New attractions require a photo and description. Legacy
edits may retain a missing cover.

ratingAverage/ratingCount are read-only aggregates if real reviews are later
provided. Administrators cannot submit or alter them. Until then cards show
Not rated. Missing queue/wait/photo data is explicit. Park crowd now derives from
confirmed queue places, not staff reports or measured physical occupancy.

Slots retain attractionId, startsAt, endsAt, capacity and bookedCount. Current
editor bounds are capacity 1–1,000 and 15-minute entry windows within
9:30 AM–7:30 PM. Optional confirmedCount/retired fields support the automatic
queue projection and day publication. Booked legacy times stay immutable.
No reservation callable was implemented in this Module 1 revision.

## Shared integration

Identity remains Firebase Auth UID with visitors/{uid} profiles. Project:
themeparksmartmanagement; future callable region: us-central1. References use
document IDs, times use Firestore timestamps, park display uses UTC+8
Asia/Kuala_Lumpur, money remains MYR integer minor units.

Only the server-managed boolean custom claim admin: true grants management.
Visitor profile roles cannot grant this permission. The supplied account's
claim was previously granted and verified with the user's approval.

firestore/firestore.rules preserves A's live profile/ticket/order/guest rules
outside Module 1. firestore/attractions.rules is an isolated test fragment and
must not replace the complete live source. firebase.attractions.json points to
the merged source. See attraction-access-fix.md for publication history.

Active UI queries use default single-field indexes: future sessions query
startsAt, and attraction sessions filter by ID then sort locally. The older
foundation watchSlots method retains a composite index definition in
firestore.indexes.json; that unused query/index has not been deployed.

Coordinate A's portal shell, shared Firebase deployment configuration, lockfile
and navigation integration before merging. A's auth/profile/ticket screens have
not been rewritten. The old Home demo notice is A's pending copy correction;
it does not describe this real-data Queue implementation.

## Verification

- 50 Member B model/widget/portal tests passed; three original opt-in browser
  tests are skipped in VM runs. This includes retry/failed-save retention,
  conflicts, live status, narrow screens/enlarged text, photos, availability
  protected session editing, delete confirmation/cancel/retry, stale deletion,
  duplicate-delete protection and access revocation/recovery.
- 20 merged-rule emulator tests passed, covering rich fields, authenticated
  reads, denied visitor writes, invalid data, counts/capacity/time protection,
  A's existing profile/order/ticket privacy regressions, immutable deletion,
  linked-history retention and blocked new sessions for deleted attractions.
- A normal Flutter web build in isolated headless Chrome exercised the actual
  Firebase SDK/repositories against temporary Auth/Firestore emulators:
  create/read/update, retries, concurrent edits, all new card fields, session
  creation/read/retry, visitor reads, booking-count preservation and deletion
  persistence/retries/filtering/immutability passed.
- Customer and admin web builds are checked separately; final results are
  recorded in handoffs/member-b.md. Analysis retains 25 baseline findings
  (7 warnings, 18 infos), with none in the new Module 1 code.
- Real widgets were rendered and visually inspected at customer widths 355/440,
  portal width 390 and desktop width 1440. Photos, form sections and session
  screens were inspected with isolated test records, never runtime fixtures.
- Cloud rules compile with one pre-existing unused index variable warning in
  A's source. Tested SHA-256:
  1a4a65da810f87e5bde25a7fd2771e1b69172626089fe536365fbb2aada950c7.

The pinned Flutter browser-test runner has an existing Windows CanvasKit loader
404; its three test bodies are not claimed as passed. The normal web probe above
supplies actual SDK verification without changing the SDK. The stale starter
counter test is a separate baseline issue. Android/iOS checks are not claimed.
No live attraction/session records were seeded for verification.

## Remaining module boundaries

Reserve/cancel, ticket eligibility and non-overlapping reservation enforcement belong
to Module 2 server operations. Both valid and used same-day admission tickets
must remain eligible under the shared contract. Client reservation writes are
not enabled. Walking durations require an agreed map scale/location source.
Route, heatmap and itinerary design controls are disabled until Module 3.
Real reviews need an agreed data source; no ratings or walking times are invented.
The user now allows several different attractions per visitor, each once per
visit, with no overlapping time windows. This replaces the older global
one-confirmed-reservation rule. See module1-queue-policy.md for the exact
thresholds, counts, day publication and Module 2 integration contract.
Future consumers must exclude non-null deletedAt records from active catalogues
and eligibility. The shared reader already does this without requiring a legacy
record migration. Historical displays can read the retained document explicitly;
the active-detail reader returns null for deleted records.
