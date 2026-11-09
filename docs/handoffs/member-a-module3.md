# Member A: Module 3 handover

Completed 7 November 2026. Module 3 covers visitor rewards, following row 3 of the
Figma: Profile 63:1252, Vouchers 82:37, Voucher Details 82:38 and Points & History
87:84. The catalogue, reward review and confirmation steps fill gaps in that flow.
Original reward icons were extracted from the user's FYP.fig; no account balances
or voucher ownership records were seeded into the shared project.

## Implementation

- `models/rewards.dart`: reward/voucher/event models, real expiry, number formatting
  and Normal/Silver/Gold/Platinum progress from lifetime earned points.
- `services/rewards_repository.dart`: same primary visitor Firebase session; owner
  queries, transaction-based purchase credits, reward exchange and single use.
- `services/rewards_store.dart`: reactive balance, catalogue, vouchers, activity,
  pending purchase credits, Malaysia monthly totals, filters and mutation guard.
- `pages/rewards_page.dart`, `widgets/rewards_widgets.dart`: complete visitor flow,
  existing bottom navigation, original artwork, detailed coupon cards/QR/terms,
  disabled/empty/loading/error states and explicit confirmation before consumption.
- `profile_page.dart`: active Points/Vouchers shortcuts, live voucher count and
  rewards membership. Admin private membership tags remain administrator metadata;
  these do not grant access or change the public rewards membership.
- `ticket_repository.dart`: after a completed V2 booking, attempt its independent
  points-credit transaction. Failure leaves the confirmed booking intact. The visitor
  can collect outstanding credit in Points & History without booking again.

Each new reward screen has a distinct keyed subtree and its own non-primary scroll
position so a previous page cannot hide its header/balance/details. Existing Profile settings,
ticketing and administrator workflows are retained. No new dependency versions.

## Shared data and integrity

`rewardCatalogue/{id}` contains name, subtitle, category (dining/shopping/photo),
benefit, pointsCost, validityDays, instructions, terms, active, sortOrder and
updatedAt/by. Three missing configuration records were created with precondition
exists=false: dining-20 (150 pts), souvenir-10 (200 pts), digital-photo (300 pts),
all 30 days. Future trusted administrators may maintain these through Firebase;
this module does not add a separate admin catalogue editor. Existing records
are never overwritten by setup. These are counter rewards; staff fulfil the
dining discount, souvenir discount or selected digital photo at the counter.

`loyaltyEvents/earn_<orderId>` is an immutable earned entry: ownerUid, kind=earned,
sourceId=orderId, positive delta and server createdAt. A completed owned V2 MYR order
earns floor(totalMinor/100), once. Existing completed V2 orders are eligible.
Cancelled, foreign, legacy V1, uncompleted, non-MYR and sub-RM1 orders cannot credit.

`rewardVouchers/{48hex}` snapshots its reward's display/terms/instructions and cost
when issued: ownerUid, rewardId, reward map, pointsCost, status=available, issuedAt,
expiresAt, usedAt=null, usedBy=''. The coupled immutable event is
`loyaltyEvents/redeem_<voucherId>` with kind=redeemed, sourceId=voucherId and negative
delta. Voucher QR is RV1:<full48hex>; the copy action supplies RV-<full48hex>.
The visible abbreviated code is for identification, while the QR/copied code
retains the complete unique reference.

Both credit and exchange update only visitors/{uid}.loyaltyPoints and
lastLoyaltyEventId atomically with a new matching immutable event. Rules verify
the persisted order/catalogue, exact amount, ownership, snapshot, expiry, and
nonnegative before/after balance. Creating a voucher alone, inventing points,
replaying an existing event or double-spending the balance is rejected.

The exchange reference persists under reward_pending_<uid>_<rewardId> in local
preferences until a successful response. A retry after an uncertain response
returns the existing voucher without another debit. No profile, password, card
or secret is saved there. Concurrent client transactions retry against current
balance. Collecting an already credited order returns without changing anything.

Expiry is midnight after validityDays including issue day in Asia/Kuala_Lumpur:
parkDay UTC encoding + validityDays - 8 hours. Server rules enforce this exact
instant; the UI moves an unconsumed voucher to Expired at that instant. Used stays
Used after expiry. Confirm Use updates only status/usedAt/usedBy, checks active
account, ownership and server expiry and is irreversible. Repeating an uncertain
use request returns the existing Used result without writing again.

Ticket checkout's previous points discount stays 100 pts = RM1. Those negative
activities are derived from immutable completed orders; voucher exchanges derive
from their ledger. They are not counted twice. Points credits count in their
actual credit month. Lifetime earned tiers are Normal <500, Silver >=500, Gold
>=1500, Platinum >=3000; spending does not downgrade the tier.

## Rules and integration

The live rules were read before publication and only the Module 3 fragment was
initially appended. Member B subsequently published newer attraction/slot rules
while retaining this fragment. The current combined deployed source was then
retained locally and the account/ticket/admin/rewards tests passed against it.
Do not redeploy a stale copy of firestore.rules over Member B's newer work.
Read the deployed source again before any future rules change.

Owner-constrained voucher/event queries are required. Ordinary visitors cannot
list all users' vouchers/events or modify catalogue entries. Missing voucher/event
point gets are allowed so transactions can safely establish nonexistence. Private
existing records remain owner/admin reads only. Suspended/archived accounts cannot
mutate rewards. No Auth role/claim, billing, functions deployment or GitHub change.

## Verification and reopening

15 previous Flutter checks plus 7 rewards checks pass (22 total). The rewards suite
checks original layout sections, filters, terms/confirmation/retry, live balance,
voucher consumption, narrow phones, true expiry instants, navigation scroll reset
and mutation overlap. Visual fixture captures remain under .local/rewards-qa only;
the normal shared app does not use fixtures.

24 isolated rule checks pass, including previous checkout/admin/admission cases and
new exact credits, immutable ledger, coupled exchange, race/overspending protection,
foreign reads, owner queries, inactive accounts, expiry and repeat-use rejection.
The scoped analyzer is clean and web build succeeds. Browser checks use the actual
existing primary visitor session and live reward catalogue, including Profile links,
uncollected points, reward review, insufficient balance and the empty voucher wallet.
The section's keyed semantic container resets the web accessibility scroll region;
the catalogue's balance card was visually verified after scrolling the prior screen.
The 440x956 Figma phone layout was checked and browser sizing restored. Old static
preview cache was bypassed through /current/ with the SAME final application build.
User points and vouchers are left for their hands-on checking.

After shutdown, run .\tool\run-app.cmd from the project folder and open
http://localhost:5173. No new version alignment is required for Member B.
User checklist: docs/MEMBER_A_MODULE_3.txt. Stop before another module is requested.

Startup correction, 7 November: the launcher now serves the compiled release app
with Flutter's web-server device bound to IPv4 127.0.0.1. This avoids IPv6-only
localhost binding and a stalled Chrome debug connection. Keep the terminal open
and open http://localhost:5173 after the served message; the visitor origin stays
the same. Verified the launcher builds successfully, both localhost and IPv4 return
HTTP 200, and the existing visitor session opens the Home screen in the browser.

The launcher also runs flutter pub get --enforce-lockfile before compilation.
This restores missing local packages (including qr_flutter 4.1.0 and
mobile_scanner 7.1.3), regenerates package paths for the current shell and cache,
and stops if locked dependency setup fails. The later --no-pub run is safe because
the launcher has already restored packages; it no longer skips that setup entirely.
