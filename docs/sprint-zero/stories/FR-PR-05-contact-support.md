# FR-PR-05: Contact Support (mailto flow)

> Implementation-ready user story for the Profile "Contact Support" action.
> Tapping the row opens the device's default mail client via a `mailto:` URL
> pre-filled with the Remote Config support address and a diagnostic body
> (FR-PR-05, FR-SH-03). When no mail client is configured, a fallback dialog
> shows the address with a "Copy" button (FR-SH-04). No backend changes.

---

## SRS Requirement ID(s)

FR-PR-05 (SRS section 4.2), FR-SH-03 (SRS section 4.11), FR-SH-04 (SRS
section 4.11). Bundled because FR-PR-05 and FR-SH-03 describe the same
`mailto:` action and FR-SH-04 is its no-mail-client fallback.

## Relevant SRS Sections

- Section 4.2 — Profile Management (FR-PR-05).
- Section 4.11 — Sharing & Support (FR-SH-03, FR-SH-04).
- Section 5.10 — Observability (`support_email_opened` funnel event).
- Section 6.4 — Empty, Error & Loading States (every error state provides a
  path to Contact Support; this flow is that shared destination).
- Section 10.2 — Critical User Journeys, item 12 (Contact Support must-pass).
- Section 10.3 — Device & OS Coverage Matrix (Tier 1 sign-off devices).
- Section 13.2 — Acceptance Criteria template (this document).

## Priority

**P0 — Must have** (FR-PR-05 and FR-SH-03). The FR-SH-04 fallback dialog is
**P1 — Should have**, bundled into this story so the action degrades
gracefully on devices with no configured mail client.

## Story Points

3

## User Story

As a **signed-in user**,
I want to **tap "Contact Support" on my Profile and have my device's default
mail client open a message pre-addressed to support with my diagnostic
details filled in**,
so that **I can report a problem quickly without looking up the address or
typing my device information by hand**.

## Preconditions

1. The user is authenticated and on the Profile screen (tab 4). The "Contact
   Support" row already exists in `profile_screen.dart` with the semantics
   label `"Contact Support, button"` and currently shows a "Coming soon"
   snackbar stub that this story replaces.
2. Firebase Remote Config exposes the string key `support_email_address`. The
   app ships a compiled-in default of `support@onebytwo.app` (via
   `setDefaults`) so the flow works offline and before the first successful
   fetch.
3. The app can read the user's `userId` (`FirebaseAuth` current user), the app
   version (`package_info_plus`), and the OS version plus device model
   (`device_info_plus`).
4. This is a read-only, client-only flow: no Firestore reads/writes, no
   Security Rule changes, and no Cloud Function changes. Remote Config is read
   from the single production project; pre-merge testing uses the Firebase
   Emulator Suite (invariant 4).

---

## Acceptance Criteria

### AC-1 (happy path) — Mailto opens with the RC address and diagnostic body

> Given the user is signed in, a default mail client is configured, and Remote
> Config has been fetched with `support_email_address` = `support@onebytwo.app`
> When the user taps the "Contact Support" row
> Then `canLaunchUrl` returns true and the app calls `launchUrl` with a
> `mailto:` URI whose recipient equals the Remote Config address
> And the URI body contains four clearly labelled diagnostic lines — the
> user's User ID, App Version, OS (name and version), and Device model — in the
> block defined by the wireframe (section 4.1)
> And exactly one `support_email_opened` event fires with `method: "mailto"`.

### AC-2 — Support address is read from Remote Config at runtime

> Given the published value of `support_email_address` is changed to a
> non-default address (e.g. `help@onebytwo.app`) and the new value has been
> fetched and activated
> When the user taps "Contact Support" with a mail client present
> Then the `mailto:` recipient is the newly configured address, with no app
> update and no hard-coded address in the client.

### AC-3 — The pre-filled message is editable before sending

> Given the default mail client has opened with the pre-filled recipient,
> subject, and diagnostic body
> When the user edits the recipient, subject, or body and sends
> Then the app neither overrides nor restricts the edit and the mail client
> sends the user's modified version
> And the app's only outbound action is launching the pre-filled `mailto:`
> URI — it presents no in-app compose form and does not intercept the send.

### AC-4 (negative) — No mail client falls back to a dialog (FR-SH-04)

> Given the user is signed in, Remote Config has a valid address, and no mail
> client is configured (`canLaunchUrl` returns false)
> When the user taps "Contact Support"
> Then `launchUrl` is not called and a fallback dialog renders per wireframe
> section 4b — title "No Mail App Found", the support address shown as
> selectable text, and "Copy Address" plus "Close" actions — with no crash or
> unhandled error
> And exactly one `support_email_opened` event fires with
> `method: "fallback_dialog"`.

### AC-5 (negative) — Fallback "Copy Address" copies and confirms

> Given the fallback dialog is showing the support address
> When the user taps "Copy Address"
> Then the address string is written to the system clipboard via
> `Clipboard.setData`, the dialog dismisses, and a confirmation snackbar
> reading "Email address copied" is shown
> And tapping "Close" (or the scrim / back gesture) instead dismisses the
> dialog with no clipboard write.

### AC-6 (negative) — Remote Config failure degrades gracefully

> Given Remote Config cannot be reached or the `support_email_address` key is
> absent (first launch offline, fetch timeout, or service error)
> When the user taps "Contact Support"
> Then the app silently uses the compiled-in default address
> `support@onebytwo.app`, shows no error UI, and proceeds exactly as in AC-1
> (mailto) or AC-4 (fallback dialog) depending on mail-client availability
> And the diagnostic body fields are still present and correct.

### AC-7 — `support_email_opened` carries no PII

> Given a `support_email_opened` event fires on either path
> When its payload is inspected
> Then its only parameter is `method`, valued `"mailto"` or `"fallback_dialog"`
> And no `userId` / `uid`, email address, OS version, or device-model parameter
> is present — the userId and device diagnostics appear only in the
> user-visible `mailto:` body, never as analytics parameters
> And a defence-in-depth grep test confirms the new files emit no such
> identifiers as analytics parameters.

---

## Telemetry Events

| Event | Parameters | Trigger |
|---|---|---|
| `support_email_opened` | `method` (string: `mailto` / `fallback_dialog`) | Fires exactly once per "Contact Support" tap, after the `canLaunchUrl` branch decision |

Pre-declared in `docs/design/07-technical/telemetry-plan.md` (the
event/parameter table, `support_email_opened`) and listed as a key funnel in
SRS section 5.10. No telemetry-plan append is required. The event is fired
through the existing `analyticsServiceProvider` (`AnalyticsService.logEvent`),
the same mechanism that fires `profile_viewed` in `profile_screen.dart`.

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No monetary values in this flow. |
| 2 | `simplifiedBalances` server-maintained | N/A. No Firestore access; the field is never read or written. |
| 3 | System share sheet only | Clarified, not violated. Contact Support uses a `mailto:` URL that opens the device's **default mail client** (mandated by FR-SH-03). This is **not** outbound sharing: it must **not** route through the system share sheet, must **not** use `share_plus` / `Share.share`, and must **not** target any specific mail app. |
| 4 | Single Firebase project | Applicable. The Remote Config read uses the single production project; pre-merge testing runs against the Firebase Emulator Suite. No second project is introduced. |

---

## Definition of Done

- [ ] Code merged to `main` via approved PR.
- [ ] Unit tests cover: `mailto:` URI construction with all four diagnostic
      fields and the RC recipient; Remote Config read with compiled-in default
      fallback; the `canLaunchUrl` true/false branch selection; clipboard copy;
      and the no-PII `support_email_opened` payload.
- [ ] Widget tests cover: the "Contact Support" row tap launching the `mailto:`
      URI on the happy path; the fallback dialog render, "Copy Address", and
      confirmation snackbar; the >= 48 dp tap target; and the
      `"Contact Support, button"` screen-reader semantics.
- [ ] QA reviewed and verified on at least one iOS and one Android Tier-1
      device per SRS section 10.3, including the no-mail-client fallback path
      (satisfies SRS section 10.2 critical-journey item 12).
- [ ] Telemetry `support_email_opened` in place, firing once per tap with the
      correct `method` and carrying no PII.
- [ ] No third-party helpdesk SDK introduced (ADR-0006) — Freshdesk, Zoho
      Desk, Intercom, and similar remain excluded.
- [ ] Documentation updated: `lib/features/profile/README.md` and the
      `docs/sprint-zero/stories/FR-PR-05-architect-notes.md` design note.
- [ ] Invariant compliance confirmed (all four; invariant 3 is the
      mailto / default-mail-client clarification, not share-sheet work).
- [ ] `flutter analyze` and `dart format` clean; `flutter test` passes.
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) — N/A, no monetary values.
- [ ] No client writes to `simplifiedBalances` (invariant 2) — N/A, no
      Firestore access.
- [ ] Uses system share sheet only (invariant 3) — clarified: this is a
      `mailto:` to the default mail client per FR-SH-03, not share-sheet
      sharing; it targets no specific app and does not use `share_plus`.
- [ ] Single Firebase project (invariant 4) — compliant; Remote Config is read
      from the single production project and tested via the Emulator Suite.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Contact Support wireframe (flow, fallback dialog, states, a11y) | `docs/design/04-wireframes/profile-and-support.md` section 4 |
| Profile View wireframe (the "Contact Support" row) | `docs/design/04-wireframes/profile-and-support.md` section 1 |
| Telemetry contract | `docs/design/07-technical/telemetry-plan.md` (`support_email_opened`) |
| Decision record | ADR-0006 (`.github/shared/decision-log.md`) |
| Handoff dry-run (prior draft US-SUPPORT-01) | `docs/sprint-zero/contact-support-dry-run.md` |

---

## Dependencies

| Dependency | Status |
|---|---|
| `firebase_remote_config` | Declared in `pubspec.yaml` (ADR-0006); no client wiring exists yet — this is the first consumer. |
| `url_launcher` | Required for `canLaunchUrl` / `launchUrl`; **not yet declared** in `pubspec.yaml` (Architect / Flutter Dev to add). |
| `package_info_plus` | Required for the app version; **not yet declared**. |
| `device_info_plus` | Required for OS version and device model; **not yet declared**. |
| `firebase_analytics` (via `analyticsServiceProvider`) | Declared and in use. |

The PM does not modify `pubspec.yaml`; the missing packages are flagged for the
Architect to confirm and the Flutter Dev to add.

---

## Out of Scope

- Wiring the "Contact Support" links that appear in other screens' error
  states (SRS section 6.4) beyond the Profile screen. The shared controller
  built here is reused, but additional call sites elsewhere are tracked
  separately. The Architect decides whether the Profile error-state link
  ("Still stuck? Contact Support", currently the "Coming soon" stub) is wired
  in this PR.
- The IA-EXT-05 v1.1 channel selector (Email vs Chat). v1.0 triggers the email
  flow directly with no channel-selection UI.
- Any in-app contact form or third-party helpdesk integration (ADR-0006; SRS
  section 12.3, post-v1.0).
- A pre-filled subject line is recommended but its exact copy is a Designer /
  Architect call; only the recipient and the diagnostic body are mandated by
  FR-PR-05 / FR-SH-03.

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| PM | This story and acceptance criteria. |
| Architect | `FR-PR-05-architect-notes.md`: Remote Config provider shape, compiled-in default mechanism, fallback-dialog component choice, and dependency additions. |
| Flutter Dev | Contact Support controller/service, `mailto:` assembly, fallback dialog, telemetry, and tests; replaces the "Coming soon" stub in `profile_screen.dart`. |
| DevOps | Publish `support_email_address` in Remote Config and reconcile the parameter name and default (see Implementation Notes). |
| QA | Device-matrix verification including the no-mail-client path. |
| Designer | Fallback dialog visuals, snackbar copy, and accessibility sign-off. |

---

## Implementation Notes

- **Feature folder.** All work lives in `lib/features/profile/`. The "Contact
  Support" row already exists in `presentation/profile_screen.dart` (the
  `_ProfileRow` with `Icons.mail` and the `"Contact Support, button"`
  semantics label) and currently shows a "Coming soon" snackbar; this story
  replaces that `onTap` with the real flow. Add the orchestration under
  `application/` (e.g. a `ContactSupportController` / service plus a small
  telemetry-constants file mirroring `notification_preferences_telemetry.dart`).
- **Remote Config.** There is currently no client Remote Config wiring in
  `lib/` (a repo search returns none), so this story introduces the first
  client read. Abstract the read behind a provider so other features can reuse
  Remote Config values. Register the compiled-in default `support@onebytwo.app`
  via `setDefaults` so the address resolves offline and before the first fetch
  (covers AC-6).
- **Canonical key and default.** Use `support_email_address` (the key in the
  telemetry plan and the wireframe) with the compiled-in default
  `support@onebytwo.app`. Two stale references should be reconciled before GA:
  `docs/setup/00-decisions.md` lists the key as `support_email`, and the
  dry-run DevOps section uses the default `avtanshgupta@onebytwo.app`. The
  locked facts for this story supersede both; DevOps should align the Remote
  Config parameter (SRS section 3.5 requires the customer to supply the final
  address before GA).
- **Mailto body.** Assemble the URI-encoded body from the wireframe's labelled
  block (section 4.1): User ID `{userId}`, App Version `{appVersion}`,
  OS `{osName} {osVersion}`, Device `{deviceModel}`. `userId` comes from
  `FirebaseAuth.instance.currentUser`, the version from `package_info_plus`,
  and the OS/device fields from `device_info_plus`.
- **Path selection.** Call `canLaunchUrl` against the composed `mailto:` URI;
  true -> `launchUrl(..., mode: LaunchMode.externalApplication)`; false -> the
  FR-SH-04 fallback dialog per wireframe 4b; copy via `Clipboard.setData`;
  confirm with the "Email address copied" snackbar (info, ~4000 ms) per
  wireframe section 4.3.
- **Telemetry.** Fire `support_email_opened` via
  `ref.read(analyticsServiceProvider).logEvent(...)` with a single `method`
  parameter, once per tap, after the branch decision. Keep the payload free of
  `userId`, the email address, and device identifiers (AC-7).
- **No backend changes.** No Firestore schema, Security Rules, or Cloud
  Function work — the flow only reads Remote Config and hands off to the
  external mail client.
- **Architect handoff.** Technical design is ratified in
  `docs/sprint-zero/stories/FR-PR-05-architect-notes.md`, per the PM ->
  Architect handoff edge in `.github/shared/handoffs.md`.
