# Module 1 queue and booking-start policy

This revision implements Module 1 only. It adds no reserve/cancel callable,
customer reservation submission, reservation admin page or fabricated booking.
The user explicitly kept those workflows in Module 2.

## Confirmed rules

| Active confirmed places in an attraction queue | Crowd | Offered start interval |
|---|---|---|
| 0–49 | Low | 15 minutes |
| 50–100 inclusive | Moderate | 30 minutes |
| 101+ | Busy | 45 minutes |

The user confirmed both boundary values. Park hours are 9:30 AM–7:30 PM in
Asia/Kuala_Lumpur. Cadence is anchored to opening time, not to the device clock.
The same policy is used by cards, View Times, details and admin queue summaries.

The user revised the earlier global one-confirmed-reservation rule: customers
may reserve different attractions, each attraction once per visit, with no
overlapping time windows. This supersedes the old handoff. Actual enforcement
belongs in Module 2's server transactions. Before that implementation, confirm
whether cancelling permits another booking for the same attraction/visit.

## Real data and the Module 2 boundary

The live projection reads attractionSlots, not visitor-private reservation lists.
Each slot exposes server-maintained confirmedCount. The queue sums active
confirmed places on the selected park date, excluding retired or expired windows.
Changing counts in Firebase immediately changes crowd and offered start times;
the clock also removes expired windows. It never moves an existing booking.

bookedCount and confirmedCount have different purposes:

- bookedCount counts capacity consumed by confirmed and checked-in places.
- confirmedCount counts people still in the confirmed queue.
- Module 2 reserve must increment both in its atomic booking transaction.
- Cancellation of a confirmed booking must decrement both exactly once.
- Check-in must decrement confirmedCount once while retaining consumed capacity.
- Both counters must satisfy 0 <= confirmedCount <= bookedCount <= capacity.
- Visitors and portal administrators cannot edit either counter directly.

Legacy documents without confirmedCount read their bookedCount as the initial
confirmed count. Before enabling Module 2 on any legacy nonzero data, reconcile
that value against actual confirmed reservations. All newly published windows
explicitly start with both counts zero. No live nonzero bookings were invented
to demonstrate thresholds; test changes are confined to isolated emulators.

There is no current booking workflow to produce these changes automatically from
customer actions. Module 2 must maintain the counters as above. Module 1's
projection and reactions were tested with real SDK/emulator count changes;
this is not a claim that reservation creation/cancellation is already delivered.

The old attraction crowdLevel field is legacy data and is ignored by the live
queue policy. Its manual editor control was removed. A staff standby-minute
estimate remains separate; the booking interval is not an estimated ride wait.
The park banner totals confirmed places across queues, not unique park visitors.

## Publishing and preserving a park day

In the admin portal, open an attraction's calendar action, then Publish day.
Choose the date and capacity. Publication persists real 15-minute entry windows
from 9:30 AM–7:30 PM, forty windows for a complete future day. This common grid
supports automatic expansion/contraction of offered starts without moving
confirmed sessions or requiring a background process on the user's computer.

The entry window stays 15 minutes wide; its offered start spacing changes:
Low offers all starts, Moderate every second start, Busy every third start.
For a complete unbooked day this gives 40, 20 or 14 offered starts respectively.
The last possible entry is 7:15–7:30 PM. No window crosses closing time.

Publication runs transactionally and uses deterministic window IDs. Retrying
does not create duplicates. It reads current slot documents, keeps all booked
and started sessions, and creates no overlapping base windows over those locked
times. Unbooked future legacy sessions are marked retired, preserving history,
and replaced by the base schedule. A booked legacy window can reduce the number
of generated windows. Publishing capacity affects unbooked generated windows;
booked capacity/counts/timestamps are preserved.

Single-session creation remains available, restricted to the same 15-minute
entry grid and park hours. Booked legacy sessions can still have capacity edited
above existing bookings, while their times remain immutable. Replaced sessions
are labelled Replaced and are not offered to customers.

## Security and integration

The full policy remains firestore/firestore.rules, preserving A's source outside
Module 1. New optional slot fields are confirmedCount and retired. The existing
document-ID, timestamp, capacity and bookedCount contract remains intact.
No backend exports, shared app routing, package manifests or runtimes were edited.

Rules validate park hours independently of client code and protect both counts.
UTC timestamp/time methods are documented in the
[Firebase Rules Timestamp reference](https://firebase.google.com/docs/reference/rules/rules.Timestamp).
The isolated rule fragment must not replace the full shared source.

Module 2 must revalidate offered cadence and availability on the server, not
trust a displayed start time. It must preserve ticket ownership/date/height/open
status/capacity checks, caller-scoped retries and atomic updates. Per-visitor
locking must support several different attractions while rejecting overlaps
and duplicate attraction bookings. A global one-reservation lock is no longer
the agreed behavior. Keep the requested slotId/ticketId/requestId callable input.

## Verification

50 focused Flutter tests and 20 merged-rule tests passed. The normal Flutter web
SDK probe passed real day publication, repeated publication without duplicates,
legacy unbooked replacement, retained booked times/counts and a live queue
decrease from 50 to 49 without releasing checked-in capacity. Unit/widget tests
cover 49/50/100/101 boundaries, all three start cadences, expiry, hours, cancelled
or checked-in count semantics, live screen updates and failed publication retry.
The three original opt-in browser-runner tests remain skipped in VM runs.

Both web builds and phone/desktop visual inspection passed. The exact tested
rules were published and read back at 23:50:23 MYT on 6 November 2026 as ruleset
73536f67-0e50-4284-8bae-6dd9350cc27d; shared rules outside Module 1 were preserved.
Analysis retains the 25 existing baseline findings with no new findings.
No live records were seeded or
converted as part of verification. An administrator chooses Publish day for
their real attraction/date/capacity through the portal.
