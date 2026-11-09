# Member A: account completion and integration handover

7 November 2026. The user expanded the instruction from one module to finishing
all remaining work from the original Member A allocation, then waiting for B.
Module 5 completes accounts/profile/security. It does not silently add Smart Photos
to the original allocation or claim the entire proposal has been implemented.

## UI and behaviour

Figma references are recorded in docs/design/accounts/frames.json and its PNGs:
90:150, 90:157, 90:158, 90:160, 92:186, 21:166 and 24:189. Native Flutter controls
retain separate settings, personal details, preferences, security, password,
email-change, devices and deletion pages. Existing artwork/background/nav is reused.
Email links implement actual Firebase recovery; no fake OTP validation was added.

AccountRepository isolates UI from Firebase and supports test fixtures. Profile
saves update only changed fields and compare their original values in a transaction,
so a concurrent edit cannot be silently overwritten. Unicode names are accepted;
phone, nickname, date, height and avatar size are bounded. The 200px JPEG avatar
is separate from face-recognition data. Clearing an avatar is supported.

Preferences preserve the existing heightCm, foodPreferences and parkInterests
fields for B. Labels follow Figma while existing canonical strings remain:
Family rides, Thrill rides, Adventure rides, Shows, Food & dining,
Shopping & souvenirs, Photo spots and Water rides. Nickname is an optional
additional field; Home uses it and otherwise falls back to the full name.

Email changes reauthenticate and use verifyBeforeUpdateEmail. The server copies
only Firebase Auth's verified email into visitors/{uid}. It never accepts an
arbitrary email update from the request body. Password changes use Firebase's
reauthentication/updatePassword APIs. Passwords are never sent to the account
server or stored in Firestore/preferences/logs. Reset links are verified by
Firebase before the reset form appears. Verification emails have a resend cooldown.

Remember me now sets LOCAL or SESSION persistence on web before sign-in. An
interrupted initial profile write can be retried against the existing unverified
Auth account, and missing profiles have a genuine completion page. Existing
profiles are never overwritten by recovery. Logout preserves ticket/cart/pending
request recovery data; permanent account closure clears account-local data.

## Account service

`server/start-accounts.cjs` starts a Node HTTP service on 127.0.0.1:8787. It uses
the same cloud Firebase project, not Firebase emulators. It reuses firebase-admin
from the existing functions dependencies and the installed Firebase CLI sign-in
for server-side IAM access. It does not expose those credentials to Flutter.
The Windows launcher starts it hidden; no Cloud Functions/Blaze change is needed.

`firebase_account_adapter.cjs` supplies Admin Auth and Firestore REST access.
`account_service.cjs` verifies Firebase ID tokens with checkRevoked=true, enforces
email verification, derives uid from the token, bounds requests, restricts browser
origins and requires recent authentication for revocation/deletion. No endpoint
lets callers nominate another owner or change roles/prices/balances.

API: POST /v1/sessions/open, /list, /end, /revoke-all; /v1/profile/sync;
/v1/account/state and /close. The only public read is /health. The app does not
send current passwords to these endpoints: Firebase client reauthentication
produces a fresh verified ID token. Errors avoid logging tokens/request bodies.

`accountSessions/{uid}_{48hex}` stores the owner, random device id, label, auth
time, start and last-active timestamps. This is the application's device registry,
not an enumeration API for Firebase refresh tokens. The real all-device action
calls Admin revokeRefreshTokens, removes registry entries, and writes a trusted
accountSecurity.revokedBefore cutoff. It signs out this device too.

Rules check that cutoff and closing flag in signedIn(), so old ID tokens cannot
continue to read/write private data even before their normal expiry. A raw-auth
owner may read only their own security signal to react. AccountReadyGate watches
it, restores missing profiles and refreshes session state. Session statistics and
transient account-service outages do not erase the logged-in account.

The service binds to loopback for this checked Chrome/web setup. The Flutter API
base is configurable with --dart-define=ACCOUNT_SERVICE_URL=.... A future hosted
or native deployment needs the corresponding protected service address/origin
configuration; native Android/iOS and public hosting were not verified here.
Deployment credentials should be supplied by that host; do not copy a user's CLI
token cache or a service-account key into the repository or client application.

## Deletion semantics

Recent authentication, checkbox and exact DELETE confirmation are required.
An active confirmed reservation blocks cleanup before data changes. A trusted
closing marker blocks normal client access; a private closure marker records
progress. Cleanup removes owned orders/tickets/references/admissions/sessions,
loyalty events/vouchers, support cases/attachments/conversations/private staff
notes/events, and profile/admin/access records. Cancelled/completed owned
reservation history is removed without modifying active slot capacity.

Guest identity in another purchaser's booking is anonymised while retaining
that purchaser's order and other guests. Immutable non-personal security/audit
records and the deletion marker may remain. No automatic refund is promised.
Auth is deleted last so a failed data cleanup can resume. Duplicate requests
share one job. A closing account returns to the recovery deletion page, not a
new visitor profile. Further B collections must be added deliberately during
integration; do not claim cleanup of unknown future schemas.

## Integration with B

Preserve the shared signedIn/accountSessionAllowed rules and server-only security
collections. Privileged reservation functions bypass Firestore rules, so they
must also reject accountSecurity.closing and revoked auth_time before writes.
Send B's latest source, functions/rules/index additions and actual collection
fields here for the integration pass. In particular, confirm confirmed reservation
ownership/status fields before relying on the active-reservation deletion guard.

Member A tickets are real: completed orders, initially valid tickets, ownerUid /
purchaserUid, visitDate/validUntil, orderId and TP1:<ticket document ID> QR.
Do not replace them with older local ticket placeholders. The original callable
createDemoOrder interface in the first plan is obsolete. The user rejected that
reduced app and later approved normal shared-Firebase booking transactions.

## Verification

40 Flutter checks (10 account checks) and 48 backend checks (38 rules + 10 account
service) pass. They cover profile bounds/ownership, old-token rejection, deletion
privacy/retry/duplicates, active reservation blocking, CORS, email identity,
separate Figma screens, validation, real reset-code handling, and device actions.
Scoped analysis has no issues; release web and existing-account browser checks
are recorded in the handover. Existing package lock SHA256 remains
E3A06F94E49DB0EA127490181E0A436778089CB11426095FA0AA4C6F8F7960B2.

Shared rule publication checked the remote source precondition and retained B's
attraction/slot additions. No live credentials were changed, no account deleted,
no fixture user/support case inserted. No GitHub commit/push/merge or billing
change. The remaining joint work is B integration and final combined acceptance.
