# Firestore attraction access

Project: themeparksmartmanagement, default Firestore database.

## Original permission repair — completed

The previous live rules had no attraction match; default deny blocked reads and
saves. CLI login/project ownership were not the cause: the supplied active,
email-verified Auth account had admin: true, and CLI rule permissions were valid.

The user first selected Keep the rules local, then explicitly changed that
decision to allow Firebase publication while forbidding a GitHub push.
On 6 November 2026 at 20:25:43 MYT the tested attraction block was published,
preserving Member A's then-current shared rules. The user then confirmed that
live reads and writes worked.

- Previous ruleset: b80963c2-4e73-478d-8f06-edb35f004ecc.
- Published ruleset: 0571e1b0-1476-4cd8-9505-296087501cc8.
- Verified source SHA-256:
  7a3591e42c715e8f11721054d31124b919d8392a13fe6c6b528941399c560e55.

Older notes saying publication was still prohibited or attraction access was
still missing are superseded by this record.

The portal's transaction conflicts were corrected too: business errors return
from the callback and are thrown afterward, avoiding the pinned web SDK's opaque
converted-Future wrapper for custom Dart exceptions.

## Module 1 design revision

The new photo/description/crowd/wait fields and session administration require an
updated Module 1 block. firestore/firestore.rules is the complete merged source,
configured separately by firebase.attractions.json. All shared source outside
Module 1 is preserved byte for byte from the published 0571e1b0 ruleset.

- Signed-in users can read attractions and sessions.
- Only boolean custom-claim administrators can create/edit them.
- Rich fields and server timestamps are validated; reviews stay read-only.
- Future sessions start at count zero. Updates cannot overwrite counts, reduce
  capacity below bookings or move a booked session.
- Visitor writes, privilege escalation, hard deletes, reservation writes and
  unknown collections remain denied.

17 merged-rule tests and actual Flutter web SDK checks passed against temporary
emulators. Cloud compilation passed with one pre-existing unused index variable
warning. Tested source SHA-256:
98b3abfe6b768970fa2f2c0e628bf6c93f35665350626e7584165f0f6bc90497.

The updated block was published on 6 November 2026 at 21:22:59 MYT as
ruleset 6473ef70-be65-413c-8389-8cee28e4d357. The released source was read back
and its SHA-256 exactly matches the tested value above. The guarded publication
checked the previous live source before and immediately after upload, and
preserved all shared rules outside Module 1. No live records were created for
verification; authenticated live write acceptance of the revised form remains
a manual user check, separate from the successful SDK emulator verification.

Future publication must inspect the active source again, preserve concurrent
work by A, test the merged checksum and read back the released source. Never
publish the isolated firestore/attractions.rules fragment as the full policy.
No app, Functions, Hosting, indexes, registrations or live fixture data are
published by this repair. No source has been pushed to GitHub.

## Admin Delete action — publication history

At 23:09:39 MYT on 6 November 2026, the tested deletion update was published as
ruleset 75ec4806-6539-4511-9abc-acd3fe83b99a. It was based on the newer live
ruleset 862717df-1a7e-41aa-b53c-e5bebcf88a00, preserving all shared source outside
Module 1 byte for byte. Released source was read back and verified against:
d8b02629772cc64d0bb8361db1e41dcee397317d552f349b8455166906d65b1d.

Admin deletion is a closed record with a server deletedAt timestamp, removed
from active list/detail readers. Linked sessions/reservations remain intact;
later edits/restoration and new sessions are denied. Direct hard erase remains
denied. Only an authenticated boolean-claim admin may perform this operation.
45 widget/model tests, 19 merged-rule tests and actual browser SDK persistence,
filtering, retry and retained-history checks passed. Both app builds passed.
No live attraction was deleted or seeded during verification. Test emulators
were stopped; both application entry points still use the real cloud project.

## Module 1 queue policy — current publication

At 23:50:23 MYT on 6 November 2026, the tested park-hours, confirmed-counter and
day-publication rules were published as ruleset
73536f67-0e50-4284-8bae-6dd9350cc27d, based on the previous 75ec4806 ruleset.
All shared source outside Module 1 remains byte-for-byte unchanged. The active
source was read back and verified with SHA-256:
1a4a65da810f87e5bde25a7fd2771e1b69172626089fe536365fbb2aada950c7.

50 focused Flutter tests, 20 merged-rule tests and the actual browser SDK checks
passed. Both web builds and phone/desktop layout inspection passed. No live
schedule, fixture reservation or nonzero count was seeded. An administrator
explicitly chooses Publish day with their real date/capacity. Module 2 booking
and cancellation functions were deferred at that stage.

## Reservation journey — 7 November 2026

The booking journey now has local callable implementations and actual Firebase
SDK tests. Reservation owner/admin reads and private server guard protection
were added to the complete active source without changing any previous rule.
The tested policy was published/read back at 01:43:11 MYT as ruleset
206b290a-47b1-4a60-8a4a-3ec00a759a2e.
SHA-256: 1d1145f4335baa36d36f18b150ffcbe2ce49dd4cb882de902ce736569638c07e.
35 backend/rules tests and the actual callable SDK probe passed. Clients,
including portal admins, cannot write reservation documents or booking counts
directly. No live fixture documents were created.

Live Functions remain undeployed: billing is disabled and the Functions API
returns SERVICE_DISABLED. Payment settings were not changed. See
[reservation-journey.md](reservation-journey.md) for the owner setup and Member A
ticket-issuance integration needed before live confirmation can succeed.
