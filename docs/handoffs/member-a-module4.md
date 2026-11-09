# Member A: Module 4 handover

Completed 7 November 2026. Help, tutorials, FAQs and visitor support with the
administrator Feedback & Complaints inbox. Remain on this module until the user
finishes hands-on checking; do not start another module automatically.

## UI and navigation

Profile/settings and the login/register help buttons open `SupportPage`.
Public visitors can read help; sending a request requires the normal sign-in.
The visitor help hub preserves the existing bottom navigation. Guide index,
guide detail, FAQ and submission are distinct screens. Added request confirmation,
My Requests and conversation/detail screens follow the same established style.

Figma row 3 frames: 89:121 Help, 93:202 guide index, 93:206 guide detail,
94:214 FAQ, 89:115 Feedback. Administrator frame: 136:572. Extracted originals
and provenance are in docs/design/support and docs/design/admin. Native widgets
provide controls; screenshots are references rather than the application itself.
The login diagram teaches supported email sign-in rather than unsupported phone
or Face ID authentication. Names, bookings, dates and case counts come from Firebase.

The admin sidebar now scrolls when the available height cannot fit all entries.
Cases open beside the inbox on wide layouts and in a full panel at smaller widths.
The full table scrolls horizontally. Other administrator modules are preserved.

## Implementation

- `lib/support/support_content.dart`: guide and FAQ content, categories and search.
- `support_models.dart`: cases, drafts, files, messages, events, reference and dates.
- `support_repository.dart`: Firebase transactions, private queries and pending store.
- `support_attachment.dart`: real file-header/type checks, image decode/resize and limits.
- `support_widgets.dart`: original icons, segmented controls, conversation and timeline.
- `support_form.dart`: validation, owned-booking choice, attachment, consent and safe retry.
- `support_page.dart`: help, guides, FAQ, confirmation, requests and visitor case handling.
- `lib/admin/support_management.dart`: full inbox, staff controls, notes and conversations.

AdminRepository exposes an optional SupportRepository. Its real implementation uses
the existing named ThemeParkAdmin Firebase instance and authenticated admin UID.
The visitor uses the primary instance. Both connect to themeparksmartmanagement.
There is no new dependency version; pubspec adds the support artwork directory only.

## Shared collections and permissions

`supportCases/{48hex}` stores immutable owner/name, original type/subject/message,
optional owned orderId, contactConsent/contactEmail, fingerprint and attachment
metadata. Mutable fields are status (new/in_progress/resolved), priority,
category, assignment, resolution, response/resolution times, updatedAt,
messageCount, lastMessageId and lastEventId. Creation starts New/Medium/unassigned.
Rules require a verified active owner, actual profile name, account email only
when contact is permitted, valid bounds and server timestamps.

`supportAttachments/{caseId}` contains the same metadata, base64 bytes, ownerUid,
caseId and server createdAt. Maximum raw size is 512000 bytes. PNG/JPEG images
are decoded; larger photos are resized/recompressed. PDF files above the limit
are rejected. A file and its case are created atomically. Rules require matching
metadata, size, MIME/header and ownership. Files are immutable, point-readable
only by owner/admin and cannot be listed. No Firebase Storage/billing setup is needed.

`supportMessages/{caseId}_{48hex}` contains ownerUid, caseId, authorUid/name,
role (visitor/admin), body and createdAt. The append and the case message counter/
last-message update are atomic. The first administrator reply records firstResponseAt
once and moves New to In Progress. Resolved cases require reopening before replies.
Message retries use stable IDs and return an existing matching send instead of duplicating.

`supportNotes/{caseId}_{48hex}` has the same shape but is administrator-only on
both read and write. These notes never enter the public conversation stream.
`supportEvents/{caseId}_{48hex}` records actor, action, from/to statuses and time.
Metadata updates require a coupled immutable event. Resolution requires a 5-500
character summary. Only an owner can reopen their own resolved case; admins can
also change case status. No original submission can be rewritten or deleted.

Owner queries include ownerUid; conversations/events additionally constrain caseId.
Admins can query all cases using the trusted Auth admin:true claim. Visitor role
fields do not grant admin access. The contact checkbox shares an email for staff
follow-up; it does not claim to send automated email. Related bookings are read-only.
Response templates fill a composer and still require an explicit Send Reply.

The five-business-day target and overdue count use Malaysia dates and weekdays;
no public-holiday calendar is configured. Average response uses actual first staff
replies. Empty data produces empty states or a dash, not fabricated statistics.

## Concurrency, retry and preservation

Before submitting, the account-scoped SharedPreferences pending store saves the
reference and draft, including attachment. Retries restore the same request ID
and fingerprint. Editing a pending submission first checks the server: an existing
case opens its confirmation; absence unlocks editing with a fresh reference.
Successful confirmation clears the pending record. Ordinary unsent forms confirm
before navigation discards them. The app never silently submits on page opening.

Replies use transactions and immutable messages. Metadata saves compare the base
updatedAt and refuse to overwrite concurrent edits; reopening the panel reloads
the current data. Case IDs are random 48-hex values, not guessable sequence numbers.

The latest shared rules were fetched before release, the support block was appended,
and the full resulting rules passed the existing and new suites. A final precondition
check refused publication if the shared rules changed again. The active ruleset
was verified after publishing. Ticket/rewards and Member B attraction/slot rules
remain preserved. No shared visitor data, case or reply was created for automated QA.

## Validation and handover

30 Flutter checks pass, including eight support model/UI/workflow checks.
33 isolated backend checks pass, including nine support privacy, attachment,
atomicity, retry, concurrency, notes, audit, resolution and suspension checks.
Scoped analysis has no issues. The release web build and actual browser help
navigation were checked. The normal application remains on shared Firebase.
Browser checks used the existing signed-in visitor, including guides/FAQ search,
empty-form validation and the live My Requests query. The admin portal opens its
normal sign-in page; its privileged UI workflow was exercised with isolated
fixtures. The user should sign in as admin for the shared-project end-to-end check.

Run tool/run-app.cmd and keep its terminal open. It restores locked dependencies
and serves release web on 127.0.0.1:5173. Visitor: Profile > Help & Support.
Admin: /#/admin > Feedback & Complaints. See docs/MEMBER_A_MODULE_4.txt for the
hands-on sequence. No GitHub commit/push/merge, Functions deployment or billing change.
