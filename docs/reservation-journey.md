# Customer reservation journey — Member B

Updated 7 November 2026. This is the booking journey requested as Module 3 in
the latest instruction, originally called Module 2 in the task split. Map,
heatmap, planner and further admin reservation management are separate work.

## Behavior and design

Queue → Reserve → attraction details/time → Select Visitor → Review → Confirm.
The layout follows Figma frames 122:134, 122:135 and 122:136, adapted to the
agreed one visitor per reservation. Photos, descriptions, safety/status,
queue counts come from Firebase. Missing ratings show **Not rated**.

Open attractions offer automatic return times from 9:30 AM to 7:30 PM Kuala
Lumpur time. Staff set capacity once per attraction. Existing attractions use
10 places by default, and existing saved windows retain their times and capacity.
The server saves a new window when it accepts the first booking for that time.

Eligibility uses the customer's Firebase profile and real admission tickets.
Both valid and used admission tickets can cover the visit date, including
validUntil for multi-day tickets. Missing admission/profile/required height
blocks review. Visitors can book ahead for a date their ticket covers.
My reservations shows saved bookings and supports cancellation.

The optional 15-minute reminder works inside the open application and stores
its preference per account/reservation on this device. Cancellation removes
its scheduled reminder. This is not closed-app push notification delivery.

## Contract and safeguards

Node 22 callables, exported through functions/index.js from src/reservations.js:

- reserveSlot(slotId, ticketId, requestId) → reservationId, status.
- cancelReservation(reservationId, requestId) → reservationId, status.
- Region: us-central1. Identity: verified caller Auth UID, visitors/{uid}.
- One visitor per reservation; no client-supplied owner, group or quantity.
- Different attractions can be reserved. A confirmed/checked_in booking
  prevents a second booking for the same attraction/visit date.
- Cancelled bookings allow same-day rebooking, as explicitly confirmed by user.
- Active return windows cannot overlap. Adjacent windows are allowed.
- The server rechecks ticket ownership/guest/date/status, profile height,
  attraction status/deletion, session retirement/time/cadence and capacity.
- Booking and both slot counts change atomically. Cancellation releases both
  counts once. Caller/operation/request IDs prevent duplicate retry effects.
- Queue cadence stays 15 / 30 / 45 minutes for 0–49 / 50–100 / 101+ confirmed
  visitors. Existing return windows remain fixed; hours are 09:30–19:30 KL.

Reservations store ownerUid, ticketId, attractionId, slotId, status, visitDate,
startsAt, endsAt, attractionName, createdAt, requestId; cancellation adds
cancelledAt. Times are Firestore timestamps; names are history snapshots and
references use document IDs. Money and Member A's interfaces are unchanged.

Server-only reservationRequests retain retry results. reservationGuards and
attractionQueueGuards serialize visitor and queue races. Clients cannot read
or write these private records. Reservation reads require owner/admin; all
direct client reservation writes, including portal admin writes, are denied.

## Live setup and Member A integration

The prepared attraction rules accept the per-attraction capacity and reserve
window creation for the booking service. They were merged against the active
Firestore rules. Check for newer shared-rule changes before publishing.

**Live confirmation is blocked:** billingEnabled=false and the Functions API
returns SERVICE_DISABLED. No reservation function was deployed, and payment
settings were not changed. The owner must enable/authorize Blaze and the
Functions API before deployment. See the official
[Functions setup guide](https://firebase.google.com/docs/functions/get-started?platform=flutter).

My Tickets displays issued Firestore tickets for the signed-in visitor. The
Add Ticket button is disabled pending integration of Member A's real ticket
issuance and checkout. Supported ticket fields include ownerUid, visitDate,
optional validUntil, status and optional guestEmail. Profile height uses heightCm.

After owner setup and coordination, deploy the booking exports and reviewed rules.

```powershell
firebase.cmd deploy --config firebase.reservations.json --project themeparksmartmanagement --only 'functions:reserveSlot,functions:cancelReservation,firestore:rules'
```

This command has not been run. The dedicated configuration excludes test-only
code and does not select moderation or unrelated exports. Inspect concurrent
source/config changes before deployment. No GitHub push is authorized yet.

## Review and tests

Restart FYP - Chrome, sign in and open Queue → All → Reserve for an open
attraction. Pick a date covered by an eligible admission ticket and select a
return time. Until Functions are deployed, confirmation reports that the service
is unavailable and retains the selected details.

37 backend/rules tests passed. An authenticated callable check also confirmed a
future booking without a pre-existing window, rejected an unmatched ticket date
and released capacity on cancellation. The test services were isolated from the
cloud project used by both applications.

See the run guide and Member B handoff for final screen/build results, existing
baseline issues and setup differences. Android/iOS are not verified by web tests.

With the reviewed dependencies already present, repeat the portable checks:

```powershell
flutter --no-version-check test --no-pub test/member_b
firebase.cmd emulators:exec --config firebase.reservations-test.json --project demo-fyp-module1 --only auth,firestore,functions "node --test --test-concurrency=1 test/emulator/attractions_rules.test.cjs test/emulator/shared_rules_regression.test.cjs test/emulator/slots_rules.test.cjs test/emulator/reservations_rules.test.cjs test/emulator/reservations_backend.test.cjs"
```

Separate suites are serialized because the emulator can lock query ranges
across unrelated fixtures. The last-place and overlapping-booking race cases
still issue competing transactions concurrently within their own test.
