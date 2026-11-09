# Run and check Member B's work

Open this folder in VS Code:
`C:\Users\chunm\Documents\Codex\2026-11-06\now-i-would-like-to-start-2\FYP`

Use Flutter 3.41.0 and bundled Dart 3.11.0. This computer's ignored workspace
settings select the installed toolchain. Open a new terminal if PATH is stale.
Keep the sibling work/toolchains directory. Use this checkout, not Downloads.

## Customer application

Select **FYP - Chrome** and press **F5**. Sign in, then open **Queue**.

The Virtual Queue follows copied Figma frame 122:131: crowd banner, search,
Recommended / Available Now / Nearby / All, photo cards and session times.
Tap **Reserve** or a card for attraction details and automatic return times.
Choose a visit date covered by your ticket, select a time and review the booking.
**My reservations** opens saved history and cancellation. The calendar chooses
the park visit date. Nearby asks for
a starting attraction and sorts by schematic coordinates.

Cards use real Firestore records. Add missing photos/descriptions/reports through
the portal. Ratings stay **Not rated** until real reviews exist. An empty
collection stays empty; no example records are injected into the application.
The booking journey is implemented locally and tested. **Live confirmation
still needs Firebase Blaze/Functions setup and deployment.** My Tickets shows
issued admission tickets. Add Ticket requires Member A's checkout integration.
See [reservation-journey.md](reservation-journey.md) for exact status and checks.
Open **Map** and use **Attractions**, **Dining**, **Facilities** or **Shops**
to filter the map pins and Nearby list. Tap the active filter again to show
all four types. Use search to narrow the current view. Choose a starting landmark with
**Find My Location**. Select a marker for details and schematic directions.
From **Queue**, use **View Heatmap** for live crowd levels or **Need a plan?**
for **Your Smart Itinerary**. It uses saved interests, height, existing
reservations and automatic return times. **Reserve Suggested Slots** opens
individual return times for review. Walking times and live directions require
a surveyed route map and calibrated location data.

## Separate administrator website

Select **FYP Admin Portal - Chrome** and press **F5**, or run:

```powershell
flutter run -d chrome -t lib/admin_main.dart --web-port 5411
```

Sign in with the real administrator email/password. Only a trusted boolean
Firebase Auth claim admin: true grants access. Customer accounts cannot manage
attractions, including direct attempts to write the database.

1. Open **Park Facilities → Add Facility → Attraction**.
2. Choose a cover photo; enter name, description, category, status, minimum
   height and map coordinates. A new record defaults to Closed.
3. Crowd is read-only and calculated from confirmed queue counts: 0–49 Low
   (15-minute starts), 50–100 Moderate (30-minute starts), 101+ Busy (45-minute
   starts). Optionally enter a separate standby estimate; leave unknown waits blank.
4. Save, then choose **Queue → All** in the customer app to check the same
   photo/details. Recommended excludes closed/maintenance or height-ineligible
   attractions; choose Open when ready to make a ride available.
5. Set **Capacity per entry window** once per attraction. Open attractions
   offer automatic windows from 9:30 AM to 7:30 PM Kuala Lumpur time. Changes
   to capacity apply to new windows. Existing windows keep their capacity.
6. Check **View Times** for an open attraction, then change its status to
   Closed and confirm that it stops accepting bookings.
7. Use the attraction row's red trash action to **Delete**. Confirm the named
   attraction; Cancel makes no change. A confirmed delete removes it from both
   active lists and details. Its closed Firebase record and linked windows and
   reservations remain for history.

For **Dining**, **Facilities** and **Shops**, select that type under **Add
Facility**. Enter a name, description, status and map position, and optionally
choose a cover photo. After saving, check the corresponding filter in **Map**.
The same portal list lets you edit or remove those places.

Photos are compressed into the real Firestore attraction document. Both clients
use themeparksmartmanagement; there is no application database emulator or local
fallback. If an old session is running, stop with **Shift+F5** before relaunching.
Changing the selected configuration does not replace an already-running app.

### Module 5 — Reservations

In **FYP Admin Portal - Chrome**, sign in as an administrator and select
**Reservations** in the sidebar. The list starts on today's Kuala Lumpur date.
Change **Visit date** to the date on the visitor's ticket. Search by visitor,
attraction or booking reference and use **All Statuses** to filter the table.
Select a reservation ID or the eye icon to see the ticket and return window.
The totals cover the selected date, including records outside the search filter.
Only saved reservations appear in the portal. Buying a ticket alone leaves the
list empty until a ride booking is confirmed.

## External PowerShell terminal on this computer

```powershell
Set-Location 'C:\Users\chunm\Documents\Codex\2026-11-06\now-i-would-like-to-start-2\FYP'
. '..\work\fyp-env.ps1'
flutter run -d chrome
```

No GitHub push is required for local review. Android/iOS readiness is a separate
milestone. See module1-attractions.md for checks and limitations, and
attraction-access-fix.md for exact live rule publication status.

The reservation backend updates protected confirmedCount/bookedCount atomically.
Until deployment, zero confirmed bookings correctly shows Low; test scenarios
are not seeded live.
See module1-queue-policy.md for the agreed crowd and reservation rules.

## Current verification — 7 November 2026

64 Member B Flutter tests and 37 backend/access tests passed. An authenticated
callable check verified advance booking, rejection of an unmatched ticket date
and cancellation against isolated test services. Three opt-in browser tests
were skipped. Both JavaScript debug web builds passed with the existing
flutter_tts WebAssembly dry-run warnings. The changed app areas passed analysis.

Live confirmation still needs the owner setup described in the reservation guide.
Customers also need an issued ticket covering their visit date.
