# AC-11 — "Open Settings" deep-link CTA (permission-denied surfaces)

> Implementation-ready chore story for the **AC-11 "Open Settings" CTA**: when a
> user has denied (or permanently denied) an OS permission, the app must offer a
> button that deep-links straight to the app's OS settings page so they can
> re-enable it. Two surfaces currently fall short because, until now, no Flutter
> plugin capable of opening the OS settings screen was in the lockfile:
>
> 1. **SCR-27 Notification Preferences** (FR-PR-03 / FR-AC-04) — the
>    `_OsPermissionBanner` shipped (PR #55) **without** the "Open Settings"
>    button, because `firebase_messaging` does not expose
>    `openAppNotificationSettings()` on the Dart API (re-verified at this kickoff
>    in `firebase_messaging-16.3.0`).
> 2. **SCR-10 Add Friend contact-permission** (FR-FR-01) — `ContactService.openSettings()`
>    called `FlutterContacts.openExternalPick()` (a contact-picker fallback), not
>    the app's OS settings page; the source carried an explicit TODO naming
>    `app_settings`.
>
> This chore adds **one** native settings-deep-link plugin (`app_settings`) behind
> a thin `lib/core/services/AppSettingsService` seam (mirroring `UrlLauncherService`),
> and wires the CTA on both surfaces. Pure client + dependency chore: no Cloud
> Function, no Firestore rules / index / schema change.

---

## SRS Requirement ID(s)

- **FR-AC-04** (SRS section 4.7, **P0**) — notification-permission handling; **AC-11**
  (the OS-permission banner + "Open Settings" CTA) is the acceptance criterion this
  chore completes.
- **FR-PR-03** (SRS section 4.8) — Notification Preferences (SCR-27); the banner
  lives on this screen.
- **FR-FR-01** (SRS section 4.5, **P0**) — Add a friend (SCR-10); the
  contact-permission "Open Settings" CTA is the parallel gap.

> No tracked GitHub issue exists for this chore; it was recorded only as a
> candidate-list bullet (PR #55 architect §2.4 / `next-three-prs.md`). The PR
> opens without a `Closes #NN` line.

## Relevant SRS Sections

- **Section 4.7 / FR-AC-04** — OS-level notification permission UX (AC-11).
- **Section 5.4 / line 308** — PII rule: no `uid`, friendship composite, or raw
  entity ID in any Analytics/Crashlytics parameter. The new
  `permission_settings_opened` event carries only a non-identifying `surface` enum.
- **Section 13.1** — Flutter feature-first folder layout; shared platform shims live
  under `lib/core/services/`.

## Relevant Design References

- `docs/design/06-screen-specs/23-28-settle-activity-profile.md` §SCR-27
  (Notification Preferences banner).
- The SCR-10 contact-permission spec (Add Friend); `permission_denied_view.dart`
  copy ("Open Settings" / "Grant Permission") is unchanged.
- `docs/design/07-technical/error-and-empty-state-taxonomy.md` (permission-denied
  copy).

## Priority

**P1 chore.** The highest-ranked unshipped carry-forward candidate (it leads the
post-#69 "Next candidates" list), surfaced by PR #55 QA. Closes the PR #55 §2.4
AC-11 graceful-degradation deferral in full and the parallel friends
contact-permission gap.

## Story

**As** a One By Two user who has turned off notifications (or contact access) for
the app,
**I want** an "Open Settings" button on the permission-denied surface that takes me
straight to the app's OS settings page,
**so that** I can re-enable the permission without hunting through system settings
myself.

## Preconditions

- The user is authenticated.
- For notifications: the user is on SCR-27 and
  `NotificationPermissionController` reports `denied` or `permanentlyDenied`.
- For contacts: the user is on SCR-10 (Add Friend → From Contacts) and contact
  permission is `deniedPermanently`.

## Acceptance Criteria

1. **AC-11 notifications — banner button present and actionable.**
   Given I am on SCR-27 and notification permission is `denied` or
   `permanentlyDenied`, when the banner renders, then it shows the unchanged copy
   ("Notifications are turned off for this app. Enable them in your device settings
   to receive alerts.") **and** an "Open Settings" button; when I tap "Open
   Settings", then the app deep-links to the OS **notification** settings via
   `AppSettingsService.openNotificationSettings()`.

2. **AC-11 contacts — CTA opens OS app settings, not the contact picker.**
   Given I am on SCR-10 and contact permission is `deniedPermanently`, when I tap
   the existing "Open Settings" button, then the app deep-links to the OS **app**
   settings page via `AppSettingsService.openAppSettings()` (no longer
   `FlutterContacts.openExternalPick()`).

3. **Telemetry (PII-free).**
   Given either "Open Settings" CTA is tapped, when the deep-link fires, then a
   single `permission_settings_opened` event is logged with exactly one parameter,
   `surface` = `notifications` (SCR-27) or `contacts` (SCR-10), and no `uid`,
   friendship composite, or raw entity ID.

4. **Negative — no CTA when permission is granted.**
   Given notification permission is `granted`, when SCR-27 renders, then neither
   the banner nor the "Open Settings" button appears; given contact permission is
   `granted`, the SCR-10 contact list renders with no permission-denied view.

5. **Graceful degradation.**
   Given the platform settings deep-link fails (the plugin throws or is a no-op on
   the device), when the user taps "Open Settings", then the app does not crash and
   the banner/view remains visible so the user can retry or follow the on-screen
   instruction.

## Definition of Done

- [ ] Code merged to main via an approved PR.
- [ ] Unit and widget tests written and passing (fake `AppSettingsService`
      overrides; banner-button-only-when-blocked; granted negative case;
      contacts CTA calls the service not `openExternalPick`; telemetry PII-leak
      assertion).
- [ ] `ios/Podfile.lock` regenerated (`pod install --repo-update`) and committed.
- [ ] QA reviewed and verified across both surfaces; Build iOS + Build Android
      green; per-feature coverage ≥ 70%.
- [ ] `permission_settings_opened` declared in `telemetry-plan.md` and wired.
- [ ] Documentation updated (this story; ADR-0019; planning docs reconciled).

## Invariant Compliance

- **Invariant 1 (integer paise):** N/A — no money path; none introduced.
- **Invariant 2 (`simplifiedBalances` server-only):** N/A — no balance read/write.
- **Invariant 3 (system share sheet only):** N/A and **not** conflated —
  deep-linking to OS settings via `app_settings` is not sharing; it is **not**
  routed through `Share.share`; no messaging-app targeting is introduced.
- **Invariant 4 (single Firebase project):** reinforced — no new project/config;
  all testing against the Emulator Suite / a faked plugin seam.

## Implementation Notes

- New seam: `lib/core/services/app_settings_service.dart` (`AppSettingsService`
  abstract + `DefaultAppSettingsService` + `appSettingsServiceProvider`), mirroring
  `lib/core/services/url_launcher_service.dart`.
- New telemetry constants: `lib/core/telemetry/permission_settings_telemetry.dart`.
- Notifications: `_OsPermissionBanner` becomes a `ConsumerWidget` with the button.
- Contacts: `FlutterContactService` takes an injected `AppSettingsService`;
  `openSettings()` → `openAppSettings()`; the line-77 TODO is removed.
- iOS `Podfile.lock` MUST be committed (native plugin).

---

## Architect Notes

### §1. Plugin choice — `app_settings`, not `permission_handler`

**RATIFIED: `app_settings: ^7.0.0`.** It is single-purpose (open an OS settings
screen), so it carries the smallest dependency-graph and `ios/Podfile.lock` delta;
the friends TODO already named it. `AppSettings.openAppSettings(type: ...)` covers
both needs: `AppSettingsType.notification` (Android
`ACTION_APP_NOTIFICATION_SETTINGS`; iOS the app settings page) and the default
`AppSettingsType.settings` (Android `ACTION_APPLICATION_DETAILS_SETTINGS`; iOS
`UIApplication.openSettingsURLString`).

**REJECTED: `permission_handler`.** Its `openAppSettings()` would also subsume the
permission-request lifecycle, but that is a larger refactor than this chore needs;
the contact/notification request flows already work via `flutter_contacts` /
`firebase_messaging`. **Exactly one** plugin is added — never both.

Kickoff verification (done): `app_settings 7.0.0` resolves; its iOS podspec targets
platform **11.0**, below the project's iOS **15.0** Podfile target, so there is **no**
connectivity_plus-style iOS-version break; `AppSettingsType.notification` and
`.settings` both exist in the installed package.

This **reverses** the FR-PR-03 story **§2.4** "REJECTED: pulling `app_settings` or
`permission_handler`" note, which was an interim 5-SP-scoping decision; ADR-0019
records the reversal.

### §2. The seam

One shared `AppSettingsService` behind `appSettingsServiceProvider`, a thin
binding shim with zero business logic (exactly the `UrlLauncherService` /
`ImagePickerService` pattern). Two methods — `openNotificationSettings()` and
`openAppSettings()` — so both call sites bind to a fakeable seam, never to the
plugin directly (the plugin's platform channel is unavailable in `flutter test`).

### §3. Unify both surfaces

**RATIFIED: unify.** The dependency is paid once; the SCR-27 banner and the SCR-10
`PermissionDeniedView` both bind to the one `AppSettingsService`. This is the first
shared consumer of a single permission-settings seam across two features
(`notifications`/`profile` and `friends`).

### §4. Telemetry

**RATIFIED (PM-confirmed): one PII-free event.** `permission_settings_opened` with a
single non-identifying `surface` enum (`notifications` / `contacts`), declared in
`telemetry-plan.md §1.8` and logged at the presentation layer (never inside the
data-layer shim). No `uid`, friendship composite, or raw entity ID (SRS line 308 /
ADR-0013).

### §5. Platform manifests

No Android `<queries>` entry is required: the plugin uses system settings intents
(`ACTION_APP_NOTIFICATION_SETTINGS` / `ACTION_APPLICATION_DETAILS_SETTINGS`), which
target the Settings app via well-known system actions, not arbitrary-package
visibility (unlike the FR-PR-05 `mailto` `<queries>`). iOS `Podfile.lock` **does**
change and is committed in the same PR.

### §6. No schema / rules / index / function change

Confirmed: pure client + dependency chore. Invariants 1, 2, 3 are N/A as above.

---

## Designer Notes

- **Banner button (SCR-27).** Placement: below the banner text, right-aligned,
  inside the existing `surfaceContainerHighest` info banner. A text-only Material
  `TextButton` ("Open Settings") keeps visual weight appropriate for an inline
  banner action (the friends full-screen empty state keeps its `FilledButton`).
  Material's default `TextButton` tap target satisfies the ≥ 48dp minimum.
  Accessibility: the button label "Open Settings" is the semantic label; the banner
  remains a non-blocking info strip.
- **Banner copy unchanged.** "Notifications are turned off for this app. Enable them
  in your device settings to receive alerts."
- **SCR-10 CTA copy unchanged.** The existing "Open Settings" / "Grant Permission"
  labels and the "Type a number instead" fallback stay exactly as shipped; only the
  action behind "Open Settings" changes (now a real OS-settings deep-link).
