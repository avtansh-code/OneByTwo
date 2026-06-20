# CHORE — `shared_preferences` cross-launch persistence

> Implementation-ready chore story to adopt **`shared_preferences`** behind a thin
> `lib/core/services/KeyValueStore` seam and make the two documented in-memory
> deferrals survive an app restart. Both shipped as best-effort-but-session-only
> because `shared_preferences` was not in the lockfile; this chore adds it (behind a
> fakeable seam) and restores the true cross-launch semantics:
>
> 1. **Notifications `wasPermanentlyDenied` (FR-AC-04).** The
>    `notification_permission_controller.dart` flag was in-memory only, so "do not
>    re-show the pre-permission dialog on **next launch**" was approximated as "do
>    not re-show **this session**" — a documented deviation tracked by a TODO. This
>    chore closes that TODO.
> 2. **FR-SE-09 reminder cooldown.** The `reminder_cooldown_provider.dart` family
>    held the server-returned `nextAllowedAt` in memory only and RESET on launch.
>    This chore persists it so a 24-hour cooldown is still honoured after a restart.
>
> The natural pair with the merged #70 `app_settings` chore (deliberately NOT
> bundled into it). Pure client + dependency chore: no Cloud Function, no Firestore
> rules / index / schema change.

---

## SRS Requirement ID(s)

- **FR-AC-04** (SRS section 4.7, **P0**) — notification-permission handling; the
  "do not re-show on next launch" semantic is the cross-launch behaviour this chore
  restores (closing the controller TODO).
- **FR-SE-09** (SRS section 4.7) — send-reminder rate limit; the client cooldown
  that mirrors the server `nextAllowedAt` is now persisted.

> No tracked GitHub issue exists for this chore; it was recorded only as a
> candidate-list bullet (`next-three-prs.md`) plus two in-code deferral notes (the
> `notification_permission_controller.dart` TODO and the
> `reminder_cooldown_provider.dart` note). The PR opens without a `Closes #NN` line.

## Relevant SRS Sections

- **Section 4.7 / FR-AC-04** — OS-level notification permission UX (the
  next-launch suppression semantic).
- **Section 4.7 / FR-SE-09** — send-reminder rate limit; the server remains the
  authoritative gate, the client cooldown is a best-effort UX optimisation.
- **Section 5.4 / line 308** — PII rule: no `uid`, friendship composite, or raw
  entity ID in any Analytics/Crashlytics parameter. The rule governs analytics, NOT
  on-device storage; a `friendshipId`-keyed local key is acceptable but must never
  be logged to analytics. No telemetry is added by this chore.
- **Section 13.1** — Flutter feature-first folder layout; shared platform shims live
  under `lib/core/services/`.

## Relevant Design References

- **None.** There is no new UI. The cooldown's disabled-with-countdown surface
  already exists (SCR-24 receiving-direction `OBTSettleUpCard`); persistence only
  restores it after a restart. The pre-permission dialog surface (SCR-27 area) is
  unchanged. **No Designer is required** for this chore.

## Priority

**P1 chore.** The highest-ranked unshipped carry-forward candidate now that #70 has
merged; the natural pair with the #70 `app_settings` chore. Closes two documented
in-memory deviations in one shot.

## Story

**As** a One By Two user,
**I want** the app to remember that I permanently denied notifications, and remember
an active send-reminder cooldown, even after I fully close and reopen the app,
**so that** I am not re-nagged with the notification prompt I already declined, and
the "you already reminded them" countdown is not silently forgotten on restart.

## Preconditions

- The user is authenticated.
- For notifications: the user previously denied the OS prompt (the controller
  reached `permanentlyDenied`).
- For the cooldown: a reminder was recently sent (or rate-limited), so the server
  returned a future `nextAllowedAt`.

## Acceptance Criteria

1. **Notifications — cross-launch suppression (closes the FR-AC-04 TODO).**
   Given I permanently denied the OS notification prompt in a previous session,
   when I fully restart the app and reach an authenticated state, then the
   pre-permission dialog auto-trigger stays suppressed (the controller hydrates
   `wasPermanentlyDenied = true` from on-device storage at construction).

2. **Notifications — persisted on the deny transition.**
   Given I am prompted and I deny (or the request throws), when the controller
   transitions to `permanentlyDenied`, then the `wasPermanentlyDenied` flag is
   written to on-device storage so it survives a process kill.

3. **Reminder cooldown — survives a restart.**
   Given a send produced a future `nextAllowedAt` cooldown for a friendship, when I
   fully restart the app and open that Friend Detail, then the receiving-direction
   card still renders the disabled-with-countdown state (the cooldown hydrates from
   on-device storage).

4. **NEGATIVE / expiry — an elapsed cooldown does not disable the button.**
   Given a stored `nextAllowedAt` is already in the past, when the cooldown provider
   hydrates on the next launch, then it yields `null` (treated as no cooldown) and
   the stale key is removed, so the button is enabled — never a phantom countdown.

5. **NEGATIVE / fresh install — behaves exactly as today.**
   Given a fresh install with no stored keys, when the app launches, then
   `wasPermanentlyDenied` hydrates `false` and every cooldown hydrates `null` —
   identical to the pre-`shared_preferences` behaviour.

6. **No new telemetry; no PII in storage logs.**
   Given persistence happens, when keys are read/written, then no Analytics event is
   added for the persistence itself, and the `friendshipId`-keyed local key is never
   passed to Analytics/Crashlytics (SRS line 308 / ADR-0013).

## Definition of Done

- [ ] Code merged to main via an approved PR.
- [ ] `shared_preferences: ^2.5.5` added; `KeyValueStore` seam + provider created;
      loaded once in `main()` and injected via a `ProviderScope` override.
- [ ] `wasPermanentlyDenied` hydrated + persisted; the line-89-90 TODO removed and
      the controller / README dartdocs corrected from "this session" to "next
      launch".
- [ ] FR-SE-09 cooldown persisted with the past-`nextAllowedAt` expiry guard; the
      cooldown provider dartdoc updated.
- [ ] Unit tests: seam smoke + fake override; hydrate-at-startup + persist-on-deny;
      restart-simulation (second container, same fake store) suppresses the dialog
      flag; cooldown persist + expiry + fresh-install negatives; boundary-contract
      grep for the new core files. Existing permission-controller and cooldown tests
      kept green.
- [ ] `ios/Podfile.lock` regenerated (`pod install --repo-update`) and committed.
- [ ] `dart format` + `flutter analyze --fatal-infos` clean; per-feature coverage
      ≥ 70%; Build iOS + Build Android green.
- [ ] Documentation updated (this story; ADR-0020; FR-AC-04 / FR-SE-09 §2.6 deferral
      notes reconciled; planning docs reconciled).

## Invariant Compliance

- **Invariant 1 (integer paise):** N/A — no money path. The persisted cooldown is a
  `DateTime`/ISO string, never a monetary value; none is introduced.
- **Invariant 2 (`simplifiedBalances` server-only):** N/A — no balance read/write.
- **Invariant 3 (system share sheet only):** N/A and **not** conflated — writing to
  on-device `shared_preferences` is local persistence, not sharing; nothing is routed
  through `Share.share`.
- **Invariant 4 (single Firebase project):** reinforced — `shared_preferences` is
  on-device storage; no new Firebase project/config; all testing against the faked
  seam / Emulator Suite.

## Implementation Notes

- New seam: `lib/core/services/key_value_store.dart` (`KeyValueStore` abstract +
  `SharedPreferencesKeyValueStore` + `InMemoryKeyValueStore` + `keyValueStoreProvider`),
  mirroring `lib/core/services/app_settings_service.dart` /
  `url_launcher_service.dart`.
- New key registry: `lib/core/persistence/preference_keys.dart` (no stringly-typed
  keys at call sites).
- `main.dart`: `await SharedPreferences.getInstance()` after the existing awaits,
  before `runApp`; override `keyValueStoreProvider` with a
  `SharedPreferencesKeyValueStore`.
- iOS `Podfile.lock` MUST be committed (native `shared_preferences_foundation` pod).

---

## Architect Notes

See **ADR-0020** (`.github/shared/decision-log.md`) for the full design. Summary of
the ratified decisions:

### §1. Dependency — `shared_preferences: ^2.5.5`

**RATIFIED.** Kickoff verification: `2.5.5` resolves; its iOS pod
(`shared_preferences_foundation`) targets deployment **13.0**, below the project's
iOS **15.0** Podfile target, so there is no `connectivity_plus`-style iOS-version
break. `ios/Podfile.lock` **does** change (native plugin) and is committed in the
same PR (`pod install --repo-update`), mirroring the #70 / `cloud_functions`
precedents — the CI "Build iOS (no signing)" job runs vanilla `pod install` and
fails on a stale lock. No Android `<queries>`/manifest entry is required (local
storage, no intent visibility).

### §2. The seam + load-once-in-`main()` async-hydration

**RATIFIED.** One shared `KeyValueStore` (abstract) behind `keyValueStoreProvider`,
a thin binding shim with zero business logic, exactly the `AppSettingsService` /
`UrlLauncherService` pattern. It exposes a **synchronously-readable** typed surface
(`getBool` / `setBool` / `getString` / `setString` / `remove`) over an
**already-loaded** `SharedPreferences` instance, so the sync
`NotificationPermissionController.build()` can hydrate with no async/sync mismatch
and the first frame is never blocked. The instance is loaded **once** in `main()`
(after the existing `Firebase` / Remote Config awaits, before `runApp`) and injected
via a `ProviderScope` override — the established bootstrap pattern. The store is
ready before any provider reads it, so a deep-link / auth transition cannot arrive
pre-hydration.

`keyValueStoreProvider` defaults to an `InMemoryKeyValueStore`, so tests and any
un-wired context never touch the platform channel (unavailable in `flutter test`);
production overrides it with `SharedPreferencesKeyValueStore`. Tests inject an
`InMemoryKeyValueStore` (sharing one instance across two containers simulates a
relaunch). **No consumer calls `shared_preferences` directly**, and no test calls
`SharedPreferences.setMockInitialValues`.

### §3. Scope — both surfaces

**RATIFIED: both.** The dependency is paid once; persisting only one surface would
leave the other deferral open and re-litigate the same wiring. Notifications-only
was considered (the simpler half, closes the explicit TODO) but rejected — the
cooldown's family-persistence + expiry is low blast radius behind the seam.

### §4. Cooldown shape + expiry guard

**RATIFIED: promote to a `NotifierProvider.family`.** `reminderCooldownProvider`
becomes a `NotifierProvider.family<ReminderCooldownNotifier, DateTime?, String>` so
read-hydrate, write-persist, and the expiry guard all live in **one** class — never
scattered `getString`/`setString` across widgets. `build(friendshipId)` hydrates the
stored ISO-8601 value and applies the **expiry guard**: a `nextAllowedAt` already in
the past (or unparseable) hydrates as `null` and the stale key is lazily removed, so
a long-closed app never shows a phantom countdown. `set(value)` persists (or clears)
and updates state; it applies **no** expiry filter — the value is fresh from the
server and the live countdown UI already handles an elapsed timestamp (this also
keeps the existing `send_reminder_controller_test` past-date fixtures green). The
read site (`friend_detail_screen.dart`) and the writer (`send_reminder_controller.dart`,
now `…notifier.set(value)`) are otherwise unchanged. The server
(`notifications.md §6.1`) stays the authoritative 24-hour gate; the persisted client
value is a best-effort UX optimisation, so its writes are fire-and-forget. The
`wasPermanentlyDenied` write, by contrast, is **awaited** on the deny transition
because cross-launch suppression is its entire purpose.

### §5. Key namespace

**RATIFIED.** All keys live in `lib/core/persistence/preference_keys.dart`
(`notifications_permanently_denied`, `reminder_cooldown_<friendshipId>`), so call
sites are never stringly-typed. On-device keys are exempt from the PII rule (which
governs analytics) but must never be logged to analytics.

### §6. Telemetry

**RATIFIED (PM-confirmed): NONE.** Persisting a flag is not a user action worth an
event; the existing `fcm_*` / `reminder_send_*` events already cover the user-facing
moments. No event is added.

### §7. No schema / rules / index / function change

Confirmed: pure client + dependency chore. Invariants 1, 2, 3 are N/A as above;
Invariant 4 is reinforced.

---

## Designer Notes

**None — no Designer is required.** This chore adds no new UI. The cooldown's
disabled-with-countdown surface and the pre-permission dialog flow already exist;
persistence only restores prior state after an app restart.
