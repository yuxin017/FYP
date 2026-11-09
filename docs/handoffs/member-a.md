# Member A: ready for integration

Updated 7 November 2026. Branch feat/a-foundation. No commit/push/merge or billing
change. The latest instruction was to finish all remaining originally assigned
Member A work, then wait for Member B's source for integration.

## Current state

| Module | Ready features | Detailed handover |
|---|---|---|
| 1 | Real ticket catalog, multi-pass checkout, guest assignment, saved orders/tickets, QR, wallet/history and receipts | docs/MEMBER_A_MODULE_1.txt |
| 2 | Admin web, visitors, access controls, packages/orders/tickets, admission validation and activity | member-a-module2.md |
| 3 | Actual purchase points, ledger, redemption catalogue and single-use vouchers | member-a-module3.md |
| 4 | Guides, FAQ, visitor support cases and complete admin case handling | member-a-module4.md |
| 5 | Profile/preferences, email/password/verification/recovery, persistence, device revocation and deletion | member-a-module5.md |

The original Member A feature allocation is ready. Joint integration and final
acceptance wait for B. Native NFC, photo matching/purchase/kiosk, real Situm,
landmark recognition, KDE and trained AI are not silently claimed as complete.
See docs/CORE_TECHNOLOGIES_MODULE_MAP.txt for the proposal technology mapping.

## Run and verify

Run tool/run-app.cmd, keep its terminal open and open http://localhost:5173.
Admin: http://localhost:5173/#/admin. The launcher restores the locked Flutter
packages, starts the authenticated Node account service on loopback 8787, and
serves the release web app on IPv4 127.0.0.1:5173. The account service uses the
existing Firebase CLI sign-in and existing functions Node dependencies. No
Firebase emulator is used by the running application.

40 Flutter checks and 48 backend checks pass. Scoped analysis reports no issues;
the release web build passes. Browser checks used the existing signed-in visitor:
settings and actual preferences, a real authenticated device-list response,
disabled deletion controls and Keep My Account navigation. No credentials were
changed and no live deletion/revocation was performed. Destructive/security
workflow checks used isolated fixtures. Admin live checking requires staff sign-in.

User checklists are docs/MEMBER_A_MODULE_1.txt through MEMBER_A_MODULE_5.txt.
Latest integration summary: docs/MEMBER_A_READY_FOR_INTEGRATION.txt.

## Shared integration facts

- Firebase: themeparksmartmanagement; current registered accounts/data retained.
- Admin: same project via the named ThemeParkAdmin SDK instance; trusted Auth
  custom claim admin:true, independent of visitors.role. Client cannot grant roles.
- Tickets: completed orders; initially valid tickets; ownerUid, purchaserUid,
  guestEmail, orderId and Malaysia visitDate/validUntil; TP1:<full document ID> QR.
  Used admission can still support same-day reservations. Native NFC is pending.
- Payment confirms/saves without bank/card capture, as explicitly agreed. PAN,
  expiry and CVV are not persisted/transmitted. Monetary values use integer MYR sen.
- Keep ticketPackages distinct from the original ticket_types collection.
- B uses visitors.heightCm / foodPreferences / parkInterests; nickname is optional.
- Preserve the latest rules, including existing B attraction/slot additions.
- Privileged B functions must check the trusted accountSecurity closing flag and
  revokedBefore/auth_time cutoff because Admin SDK writes bypass Firestore rules.
- Confirm B's reservation owner/status schema before relying on account deletion's
  active-reservation guard. Add any further owned collections to cleanup deliberately.
- Profile > Visited Attractions awaits B's real visit/reservation data and navigation.

Tool versions: Flutter 3.41.0 / Dart 3.11.0; Node 22.23.4 / npm 10.9.9;
Firebase CLI 15.35.0; FlutterFire CLI 1.4.1. The dependency lock remains unchanged
from Module 4. Chrome/web is verified; native/hosted deployment is separate.

When B arrives, compare and merge the source deliberately. Do not replace the
whole workspace with his older copy or deploy old rules over current features.
