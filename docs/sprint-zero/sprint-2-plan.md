# Sprint 2 Plan

> Last updated: the **Issue #47 friendship-expense creator-only rules hardening** (#72, `33f870d`) is now **Merged** — `isValidExpenseUpdate()` now gates friendship-context expense edit and soft-delete on `request.auth.uid == prev.createdBy`. The velocity Total is reconciled to **132 SP / 32 PRs** through #72. With #72 merged, **every P0 functional requirement except the deferred Sprint-3 Groups epic (FR-GR-01..07) is shipped, and every P1 is shipped**, and the single-focus issue-backed carry-forward candidate (#47) is consumed. The **Bucket-B close-with-evidence bundle** has since **Merged** as #73 (`f9a4c54`) — it verified the Sprint-1 boundary-audit findings that Sprint 2 PRs already resolved, posted per-issue evidence comments, **fully closed #21**, **re-scoped #20 / #23** (kept open), and reconciled the burndown + roadmap; it was **velocity-excluded** (docs/hygiene, like #59), so the Total is unchanged at **132 SP / 32 PRs**. The **`chore(auth)` client-housekeeping bundle** (#74, `ce6d594`) has since **Merged** — the first of the three consolidated Sprint-2 close-out PRs: it renamed `authStateNotifierProvider` → `authStateProvider` (M1), relocated the three shared providers (`firebaseFirestoreProvider`, `firebaseStorageProvider`, `phoneAuthRepositoryProvider`) to `lib/core/providers/` (M4), emitted the four secondary auth-funnel telemetry events and corrected the `is_new_user` typing note (T3/T4/T5), and aligned the splash / phone-entry / OTP screen specs (S1/S3/S4/S5); it **closed #15 / #16 / #17 / #18** and, as feature-adjacent client work, **carried 5 SP**, so the velocity Total advances to **137 SP / 33 PRs**. The **`docs` close-out bundle** (#75, `dbc209d`) has since **Merged** — the second of the three consolidated close-out PRs: it added the #19 (CV2) before/after coverage fields, completed the #24 (CN3 / CN4) Jest-config-separation table and Cloud-Functions PR checklist, and created the #28 (SR3) Friends HTML mockup; it **closed #19 / #24 / #28** and was **velocity-excluded** (pure docs/design, like #59 / #61 / #73), so the Total is unchanged at **137 / 33**. The next PR — the **third and final** of the three consolidated close-out PRs — is the **`test` close-out bundle** (#76): the SC1–SC4 coverage tests, RT2 CI step-duration logging, and the INV2 share-sheet verification; it **fully closes #20** and **re-scopes #23** again (RT2 + INV2 closed with evidence; the PY3 Flutter emulator-harness remainder kept open under a narrowed scope), and **carries 5 SP** (NOT velocity-excluded — counted in the Total on merge, advancing **137 / 33 → 142 / 34**). It lands as the next available GitHub number (≥ #76 now that the highest PR is #75 and the highest issue is #68); reconcile the slot label at PR open. **CLOSED:** #76 merged (`3f3cd16`, advancing the Total to **142 SP / 34 PRs**) and #77 merged (`b9b1e63`, the path-filter pipeline + milestone-tracking convention + deepened review skill; velocity-excluded), so **Sprint 2 is fully closed at 100%** — its 13 issues closed and the `Sprint 2` GitHub milestone closed. The **Sprint 2 → Sprint 3 boundary audit** (`docs/audits/sprint-2/`) then ran, producing cleanup **PR #91** (33 Bucket-A fixes; 44 Bucket-B issues #78–#90 on their milestones; ADR-0021/0022/0023); audit + cleanup work, **velocity-excluded**, so the Total stays **142 / 34**.

---

## Sprint Goal

Deliver the **Friends epic** (FR-FR-01 through FR-FR-04), establishing the social
graph that all downstream features (expenses, settlements, groups) depend upon.

---

## ⚠ Critical Cross-PR Constraints

These constraints span multiple PRs and MUST be honoured. They are surfaced
here so the next orchestrator / PM / architect cannot accidentally violate
them by sequencing PRs in isolation.

### C-1: Bundle chore #25 with PR #38 (FR-EX-01)

**Chore #25** ([Expense event naming convention decision](https://github.com/avtansh-code/OneByTwo/issues/25))
MUST be resolved in the same PR as FR-EX-01 (expense creation UI). The
choice is between `expense_added` / `expense_add_failed` and
`expense_save_succeeded` / `expense_save_failed`.

**Why bundle:** PR #38 is the FIRST PR that logs any expense analytics
event. Once the first event ships, every downstream funnel chart, alert,
and Sprint 3+ instrumentation inherits the naming convention. Splitting
the decision into a separate later chore PR would force a backfill on the
event taxonomy AND on every test that asserts event names — a meaningful
rework cost for zero benefit.

**Operational rule:** PR #38 cannot ship without:
1. The naming-convention decision recorded in
   `docs/design/07-technical/telemetry-plan.md` (and any related
   telemetry index).
2. All expense events in `lib/features/expenses/**` using the chosen
   names.
3. Issue #25 closed in the same PR (`Closes #25` in the PR body) with a
   comment summarising the decision and citing the affected files.

**Architect's call:** the decision itself is the architect's at PR #38
kickoff. The orchestrator MUST refuse to start FR-EX-01 implementation
work until the decision is recorded in the story file's Architect Notes.

**Status: RESOLVED (PR #38, merged 2026-06-06).**

- **Decision:** Camp B — `expense_save_succeeded` / `expense_save_failed`.
  PM had recommended Camp B on consistency grounds with the SCR-21
  edit / delete cluster already in `telemetry-plan.md` §1.6; the
  architect ratified the recommendation at PR #38 kickoff.
- **Rationale citation:** `docs/sprint-zero/stories/FR-EX-01-expense-creation.md`
  §2.0 (Architect Notes — one-paragraph rationale and rollout plan).
- **Files updated in PR #38:**
  - `docs/design/07-technical/telemetry-plan.md` — 5 occurrences
    renamed (the SCR-19 success row, the SCR-08 failure row, the
    SCR-21 row, the amount-bucketing note, and the funnel diagram).
  - `lib/features/expenses/application/expense_telemetry.dart` —
    `expenseSaveSucceeded` / `expenseSaveFailed` constants.
  - All expense test files under `test/features/expenses/` that
    assert event names.
- **Issue closure:** [#25](https://github.com/avtansh-code/OneByTwo/issues/25)
  closed by `Closes #25` in the PR #38 body.
- **Downstream effect:** SR8 is now CLOSED in
  `docs/audits/sprint-1/07-bucket-b-burndown.md`; the Documentation
  chores bucket drops from 8 remaining to 7.

---

## ✅ Sprint 2 End-of-Sprint Manual Testing — Pre-Flight Verification

> **Owner:** DevOps lead.
> **When:** Run this checklist immediately before the Sprint 2 manual
> device-testing phase begins (i.e. after PR #53 merges + Functions
> are deployed + a release-candidate mobile build is cut).
> **Why now:** PR #53 (FR-AC-03 + FR-AC-05) is the **first PR that
> integrates Firebase Cloud Messaging end-to-end.** FCM has platform-
> shell requirements (APNS on iOS, FCM service entries on Android)
> that the existing Auth-only build configuration may not satisfy.
> Verifying these BEFORE manual QA starts saves a round-trip if a
> build-side gap is found.

### Verification gates

1. **iOS APNS entitlements + certificate (BLOCKING for iOS push).**
   - `ios/Runner/Info.plist` declares `UIBackgroundModes` including
     `remote-notification` and `fetch` if not already present.
   - `ios/Runner/Runner.entitlements` declares the
     `aps-environment` key (`development` for TestFlight, `production`
     for App Store).
   - The Apple Developer account has a current APNS Authentication
     Key (`.p8` file) uploaded to the Firebase console under
     **Project Settings → Cloud Messaging → Apple app configuration**.
     The key ID and team ID match the Bundle Identifier.
   - The Push Notifications capability is enabled on the Xcode
     project (`Runner → Signing & Capabilities → +Capability → Push
     Notifications`).

2. **Android FCM manifest entries (BLOCKING for Android push).**
   - `android/app/src/main/AndroidManifest.xml` declares the FCM
     intent filter or relies on the `firebase_messaging` plugin
     auto-registration (version `^16.2.0` does this automatically;
     verify there is no manual `<service>` entry colliding with the
     plugin's).
   - A default notification channel ID is declared via
     `<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" .../>`
     if custom channel routing is desired (optional for v1.0 — the
     default channel works).
   - The default notification icon meta-data
     (`com.google.firebase.messaging.default_notification_icon`)
     points to a monochrome white icon asset (Android system tray
     requirement). If missing, the OS uses the launcher icon and
     tints it grey — acceptable for v1.0 but flagged as a polish item.
   - The app's `google-services.json` is present at
     `android/app/google-services.json` and matches the production
     Firebase project (Invariant 4).

3. **Functions deploy verification (post-merge).**
   - `firebase deploy --only functions:onExpenseWriteFriendship,functions:onSettlementWrite`
     completes without errors on the release tag.
   - `firebase functions:log --only onExpenseWriteFriendship --limit 5`
     shows the first post-deploy invocations include the
     `fcm_send_attempted` structured log key (smoke test by triggering
     a single expense add from the canary device).

4. **Production Firebase Cloud Messaging readiness.**
   - The production Firebase project has Cloud Messaging enabled
     (Firebase console → Project Settings → Cloud Messaging tab is
     populated, not greyed out).
   - The Cloud Messaging API V1 is enabled in the Google Cloud
     Console for the production project ID
     (`firebase apps:list` confirms the project ID matches `.firebaserc`).

### Sign-off

Once all four gates above are green, DevOps records sign-off in the
PR #53 (or successor release-cut PR) review comment and the manual
QA smoke matrix (Section A.6 of the FR-AC-03 story DoD) can begin.

If ANY gate is red, file a dedicated DevOps chore PR (estimated
1-3 SP) before resuming manual testing.

---

## PR Tracking

| PR | Story | Title | SP | Status |
|---|---|---|---|---|
| #31 | FR-FR-01 (UI) | Contact picker UI for add-friend flow | 3 | Merged |
| #32 | FR-FR-01 (Matching) | User lookup and friendship creation | 3 | Merged |
| #34 | FR-FR-01 (Manual Entry) | Manual phone-number friend-add | 2 | Merged |
| #35 | FR-FR-03 | Friends list with simplified net balance | 3 | Merged |
| #36 | FR-SE-03/04 | `onExpenseWriteFriendship` Firestore trigger | 3 | Merged |
| #37 | FR-SE-05/06 | `onSettlementWrite` Firestore trigger + settlements rules + algorithm extension | 5 | Merged |
| #38 | FR-EX-01 + chore #25 | Expense creation UI (friendship) + adopt `expense_save_*` event names | 5 | Merged |
| #41 | chore | D5 deadline backlog cross-refs | 0 | Merged |
| #42 | FR-FR-04 | Friend Detail full screen (per-friend transaction history) | 5 | Merged |
| #43 | FR-SE-05/06/07 | Settle Up flow (record settlement + real-time round-trip + Friend Detail CTA card) | 5 | Merged |
| #44 | CHORE-D5 | D5 runtime upgrade — Node 22 + firebase-functions 7.x (closes #39 #40) | 3 | Merged |
| #45 | CHORE-PR45 | Lookup rate-limit doc-path fix + post-PR-#38 cleanup (3 S4 items) | 3 | Merged |
| #46 | FR-EX-06 | Edit / delete expense (friendship) — bottom-sheet edit-mode + Expense Detail screen + soft-delete with confirmation | 5 | Merged |
| #48 | FR-EX-05 | Receipt attachment (friendship) — Step 3 (SCR-21) + ReceiptStorageService + storage.rules friendship + group receipts predicates + Expense Detail thumbnail | 5 | Merged |
| #51 | FR-EX-07 | Activity feed write-side (friendship) — activity-writer + payload-builder + activity-validator + activity/{userId}/items rules + trigger emission + 12 new rules tests + 41 new unit tests + 3 integration round-trips | 5 | Merged |
| #52 | FR-AC-01 / FR-AC-02 | Activity feed read-side — SCR-25 ActivityFeedScreen + OBTActivityRow widget + activity feature folder + 4 telemetry events + settlement-trigger activity-emission extension (closes the on-settlement-write TODO) | 8 | Merged |
| #53 | FR-AC-03 / FR-AC-05 | FCM push notifications + cold-start deep-link — Functions notifications module (fcm-send + payload-renderer + prefs-filter + Functions-side INR formatter) + expense + settlement trigger FCM emission + client FCM token lifecycle + pre-permission dialog + in-app banner + cold-start handler + shared notification_deep_links routing helper consumed by both the activity feed and notifications | 10 | Merged |
| #54 | FR-SE-09 | Send Reminder — sendReminderNotification callable (auth + simplifiedBalances precondition + 5-segment `_rateLimits/{senderUid}/sends/{recipientUid}` 24-hour rate-limit + prefs filter + FCM dispatch + recipient-only activity emission) + notifications/send-reminder-notification.ts FCM helper + activity-validator 'reminder' event-type extension + lib/features/reminders/ feature folder (repository + sealed result hierarchy + send controller + cooldown provider + telemetry) + OBTSettleUpCard receiving-direction variant + FriendDetailScreen owed-branch wiring | 6 | Merged |
| #55 | FR-PR-03 + FR-AC-04 | Notification preferences UI (SCR-27) — `/profile/notifications` route with three per-event toggles (`newExpense` / `settlement` / `reminder`) + per-toggle 500 ms debounced auto-save controller + `UserRepository.updateNotificationPrefs` Firestore dot-path partial-map writer (avoids the read-modify-write race the full-map form would inherit) + production `cloud_functions` adapter wiring for `reminderRepositoryProvider` + `matchingRepositoryProvider` (closes the throw-until-overridden gap surfaced by PR #54; FR-SE-09 Send Reminder callable now reaches its production handler from the app shell) + OS-permission banner with graceful "Open Settings" degradation per architect §2.4 (`firebase_messaging: ^16.2.0` Dart API does not expose `openAppNotificationSettings()` on either platform; CTA deferred to a future `app_settings` / `permission_handler` follow-up chore) + 3 new partial-map `users-update.test.ts` rules tests | 5 | Merged |
| #56 | CHORE-PR56 | OBTBottomNav design-system primitive (`components.md §2`) + `AuthenticatedShell` IndexedStack host for the five primary tabs (Home / Friends / Groups / Activity / Profile) + 2 new placeholder screens (Home dashboard + Groups list) + `bottom_nav_tab_selected` telemetry event + PopScope snap-to-tab-0 on Android back + `lib/main.dart` wire-change swapping `HomePlaceholderScreen` for `AuthenticatedShell` + deletion of the temporary `HomePlaceholderScreen` (closes the long-deferred PR #52 §2.1 OBTBottomNav shell deferral) | 3 | Merged |
| #57 | FR-HD-04 | Persistent FAB + Add Expense context picker — `OBTFloatingActionButton` design-system primitive (`components.md`) at `lib/core/widgets/nav/obt_floating_action_button.dart` (50 LOC) + `AuthenticatedShell` `Scaffold.floatingActionButton` slot + `_onFabTapped` handler (FAB hidden on Activity tab per architect §2.3) + `AddExpenseContextPickerSheet` bottom sheet (282 LOC; Friend path routes to existing Add Expense bottom sheet from PR #38; Group path stubbed with "Coming soon" snackbar pending Sprint 3 Groups epic) + 6 new `shell_telemetry.dart` constants for the FAB-tap → picker-open → friend-select / group-select-stub funnel + `friend_detail_screen.dart` FAB refactor (`heroTag: 'friendDetailFab'` to avoid Hero animation collision with the shell-owned FAB) + **bundled `currentUserIdProvider` production wiring** in the `AuthenticatedWithProfile` arm of `lib/main.dart` per-arm `ProviderScope` override (closes the FR #56 deferral that left `friendsListProvider` + `activityFeedProvider` throwing `UnimplementedError` on first read in production) + Riverpod 2.x `dependencies: [currentUserIdProvider]` 2-character addition each on those two providers (architect §2.9 reconciliation discovery — natural completion of PR #56 architect §2.1) | 3 | Merged |
| #58 | FR-SE-08 | Dedicated settlement-history screen (SCR-24) — `SettlementHistoryScreen` at `/settle/history` (friendship axis; generic over `(contextType, contextId)` so the Sprint 3 Group Detail screen inherits the seam) with four inline states (loading / populated / empty / error; no OBT* primitive extraction per architect §2.3) + per-row layout (`dd MMM yyyy` date, payer→arrow→payee avatars, `formatInrFromPaise()` amount, optional note, 64 dp min row) + `settlementHistoryProvider` (`StreamProvider.family` keyed by `SettlementHistoryArgs`, reusing the PR #42 `watchByContext` read path with a 50-item cap) + `settlement_history_telemetry.dart` (2 pre-declared events `settlement_history_viewed` / `settlement_history_error`; NEITHER carries `context_id` per ADR-0013) + "View Settlement History" link on `FriendDetailScreen` (populated state only; no entry-point telemetry per architect §2.6). Zero changes to repository / rules / indexes / functions | 3 | Merged |
| #60 | FR-PR-05 | Contact Support `mailto:` flow (FR-SH-03) + bundled FR-SH-04 no-mail-client fallback dialog — first Firebase Remote Config consumer (`support_email_address`, in-app default `support@onebytwo.app`, ADR-0006) via `RemoteConfigService` (`lib/core/remote_config/`) + `UrlLauncherService` (`lib/core/services/`) + `package_info_plus` / `device_info_plus` diagnostics (`SupportDiagnostics` + `DeviceDiagnosticsService`) + `ContactSupportController` (sealed `ContactSupportResult`; canonical `mailto:` subject/body built with `Uri.encodeComponent`) + `support_email_opened` telemetry (PII-free single `method` param) + both Profile entry points wired (action row + error-state "Still stuck?" link) + Android `mailto` `<queries>` intent + committed `ios/Podfile.lock` + FR-PR-05 story & architect notes. Zero schema / rules / index / function changes | 3 | Merged (`8f72514`) |
| #61 | CI | PR-pipeline speed-up + clean-up — parallelise `build-ios`/`build-android` with `flutter-checks` (drop the `needs:` edge), cache CocoaPods, guard the `flutterfire_cli` activation, de-duplicate the coverage-gate via artifacts, drop the apt `lcov` install, pin `firebase-tools`; all free runners. No app-code change | 0 | Merged (`d474507`) |
| #62 | FR-HD-01/02 | Home dashboard (SCR-06) — replaces `HomeDashboardPlaceholder` on shell tab 0 with the real `lib/features/home/` feature: FR-HD-01 overall net-balance header card + FR-HD-02 top-5 friendships by absolute balance with per-row Settle Up (`source: 'home_dashboard'`) + tile-tap → Friend Detail, via two pure derived providers (`overallNetBalanceProvider` sum, `topBalancesProvider` abs-sort/zero-exclude/cap-5/stable-tie-break) composed over `friendsListProvider` + four inline states (loading/empty/populated/error, error reuses the FR-PR-05 `ContactSupportController` + `HD-FIRESTORE-READ`) + FR-HD-03 (P1) "Spending breakdown coming soon" placeholder card (no chart, no plugin) + `home_telemetry.dart` (6 SCR-06 events; `context_id_hash` via `hashFriendshipId`) + 1-line optional `source` param on `SettleUpBottomSheet` (default `friend_detail`) + shell tab-0 swap + `home_dashboard_placeholder.dart` deletion + shell README update. Group axis stubbed (Sprint 3). Offline banner (FR-OF-01) deferred. Zero schema / rules / index / function changes; no new Flutter plugin (no `ios/Podfile.lock` change) | 5 | Merged (`57c272e`) |
| #63 | FR-PR-04 | "My Friends" / "My Groups" from Profile (SCR-26, **P0** — the last open P0 functional requirement; omitted from the candidate list, corrected here) — replaces the two hardcoded `'0'` + "Coming soon" snackbar Stats stubs with a live "My Friends" count + Friends-tab navigation and a "My Groups" stub (0) + Groups-tab navigation. `friendCountProvider` (`Provider<AsyncValue<int>>` `.length` projection over `friendsListProvider`, `dependencies: [friendsListProvider]`; em-dash on loading/error, never a crash) + the architectural-first `shellNavigationControllerProvider` (`NotifierProvider.autoDispose<ShellNavigationController, int>` with `selectTab(int)`) replacing the in-shell `setState(_currentIndex)` and closing the PR #56 §2.2 deferral; `AuthenticatedShell` refactored to read/write it (bottom_nav telemetry, PopScope snap-to-0, FAB rules preserved) + Profile rows rewired (`selectTab(1)` / `selectTab(2)`, group stub) + `profile_stats_telemetry.dart` (2 PII-free events `profile_friends_tapped` / `profile_groups_tapped`, pre-declared in `telemetry-plan.md §1.7`) + new `friend_count_provider_test.dart` + `profile_stats_boundary_contract_test.dart` + shell boundary-contract list extension. Group axis stubbed (Sprint 3). FR-AC-05 deep-link tab-switch migration deferred (controller seam only). Zero schema / rules / index / function changes; no new Flutter plugin (no `ios/Podfile.lock` change) | 3 | Merged (`209afea`) |
| #64 | FR-PR-02 | Update phone number via OTP re-verification (SRS 4.2 line 175, **P1** — top-ranked remaining P1 now that every P0 is shipped; resolves SCR-26 Open Question #1) — replaces the read-only "Phone number cannot be changed from here." dead-end on Edit Profile with a "Change Phone Number" flow that **reuses** the auth phone-entry (+91, 10-digit) + OTP-entry widgets (first reuse outside sign-in). New `PhoneAuthRepository.updatePhoneNumber({verificationId, code})` calling `currentUser.updatePhoneNumber(credential)` (NOT `signInWithCredential`) + `reauthenticateWithCredential` two-OTP path for the `requires-recent-login` common case (FR-AU-07 session persistence) + new `AuthError.requiresRecentLogin` variant/copy mapped in `_mapException` (`credential-already-in-use` → existing `credentialInUse`) + gated `UserRepository` `phoneNumber` write with a forced `getIdToken(true)` BEFORE the Firestore write + `firestore.rules` `isValidUserUpdate()` line 80 relaxation (`data.phoneNumber == prev.phoneNumber \|\| data.phoneNumber == request.auth.token.phone_number`, all other immutability/shape checks preserved) + extended `users-update.test.ts` (allow token-phone change; reject arbitrary; other immutables still rejected) + profile-scoped change-phone controller/flow + Edit Profile entry-point + success/error states + `phone_change_*` PII-free telemetry (`telemetry-plan.md §1.7`; number never a parameter) + boundary-contract + widget/controller tests. +91 only (SRS 133); no friendship/contact migration (UID-keyed); zero new function / collection / index / plugin (no `ios/Podfile.lock` change) | 5 | Merged (`2e68713`) |
| #65 | FR-AU-09 | Permanently delete your account (SCR-28 Part B, SRS section 4.1 line 168, **P1** — the next top-ranked remaining P1 now that FR-PR-02 has merged and every P0 is shipped; first reuse of the FR-PR-02 re-authentication surface outside change-phone) — replaces the `'Coming soon'` Delete Account dead-end on Profile (SCR-26) with a multi-step full-screen flow at `/profile/delete-account` (Step A warning → Step B re-auth, reusing the FR-PR-02 `PhoneAccountRepository` → Step C type-`DELETE` confirmation → Step D processing with 30s timeout → Step E success → Phone Entry, stack cleared). New callable Cloud Function `deleteUserAccount` (region `asia-south1`, exported from `index.ts`, Admin-SDK cascade fan-out, idempotent, PII-hashed logs via `hashId`): DELETE personal records (`activity/{uid}`, `_rateLimits/{uid}`, Storage `avatars/{uid}`, Firebase Auth record LAST) + TOMBSTONE `users/{uid}` into a PII-free `{ displayName: 'Deleted User', deletedAt }` shell + PRESERVE shared data untouched (friendships/expenses/settlements/receipts — surviving member's `simplifiedBalances` NEVER recomputed/zeroed, Invariant 2). Client name-fallback sites need no change (`displayName ?? 'Unknown'` renders "Deleted User"). Type-`DELETE` gate (case-sensitive, trimmed); failure/timeout → Profile + Contact Support snackbar (reuses FR-PR-05 `ContactSupportController`); 7 pre-declared `delete_account_*` PII-free telemetry events. ADR-0016. `firestore.rules` unchanged (client delete already denied; rules test confirms). Groups axis stubbed (Sprint 3); 30-day scheduled-cleanup reaper / confirmation SMS / audit log deferred to FUTURE issue #66. No new plugin (no `ios/Podfile.lock` change) | 8 | Merged (`d542793`) |
| #67 | FR-HD-03 | Current-month spend summary with a category breakdown chart (SCR-06, SRS section 4.8 line 248, **P1** — the top-ranked remaining P1 on the carry-forward candidate list and the **last open Home-dashboard requirement** now that FR-HD-01/02 shipped in #62 and FR-HD-04 in #57) — replaces the `SpendingBreakdownPlaceholderCard` ("Spending breakdown coming soon") under the "This Month" header with a real card: the current calendar-month (IST, SRS section 5.9) **total spend** + a per-category breakdown chart. First **cross-friendship** expense read path — a fan-out over `friendsListProvider` reading each friendship's current-month non-deleted `expenses` and folding the signed-in user's OWN `sharePaise` from `splits` per `ExpenseCategory` (NOT the full `amountPaise`, which would over-report); `collectionGroup` rejected because expenses carry no member field for the rules membership scope. Integer paise throughout (Invariant 1; `formatInrFromPaise` only at the UI; chart segment ratios from integer paise). First charting approach + the 8-category colour-token map (dark-mode + WCAG AA; charting library ratified in ADR-0017) rendering a donut with a per-segment a11y summary (category, amount, percentage; never colour-only) + legend + month total; empty/zero state ("No spending yet this month", no chart); loading reuses the dashboard skeleton; error reuses the FR-PR-05 `ContactSupportController` / `HD-FIRESTORE-READ`. New `home_spending_breakdown_viewed` telemetry event (PII-free; DECLARED in `telemetry-plan.md §1.3` + wired). ADR-0017. Group axis stubbed (Sprint 3). No new Cloud Function / rules change; Invariant 2 N/A (reads `expenses`, never `simplifiedBalances`) | 5 | Merged (`1f26548`) |
| #69 | FR-AC-05 | Deep-link tab-switch on notification tap (SRS section 4.7 line 240, **P0** — the first carry-forward candidate, unblocked by the `shellNavigationControllerProvider` seam (#63) and closing that PR's "controller seam only" deferral; completes the last deferred piece of a P0 so every FR-AC requirement is fully shipped) — a notification deep-link now **selects the relevant primary tab** before the root-navigator push so the user lands in (and on pop returns to) a coherent tab context, instead of the detail screen pushing over whatever tab happened to be active. Adds an `int? homeTabIndex` getter to the sealed `DeepLinkTarget` (Expense/Friend detail → Friends tab 1; Unavailable → Activity tab 3 + the "no longer available" snackbar; GroupsComingSoon → no switch + the "Groups are coming soon" snackbar) and calls `shellNavigationControllerProvider.notifier.selectTab(...)` in `DeepLinkHandler.handleDeepLink` BEFORE `NotificationDeepLinks.navigate` (kept Riverpod-free). All four dispatch sources (foreground banner / background `onMessageOpenedApp` / cold-start `getInitialMessage` / pending-replay) preserved; the cold-start switch rides the existing post-`AuthenticatedWithProfile` `addPostFrameCallback` so it never runs before the shell mounts. The **Activity-feed row-tap is explicitly excluded** (in-tab navigation; uses the resolver + `navigate` directly, never the handler — guarded by a boundary-contract grep). `fcm_notification_tapped` extended with a non-identifying `target_tab` enum (`friends`/`activity`/`none`); no `uid`/friendship composite/raw entity ID ever a parameter (SRS line 308 / ADR-0013). ADR-0018. First notification consumer of the shell tab controller; first cross-feature reach from `notifications` into `shell`. Invariants 1 & 2 N/A (no money, no `simplifiedBalances`); no Cloud Function / rules / index / schema change; no new Flutter plugin (no `ios/Podfile.lock` change) | 3 | Merged (`8dd67f9`) |
| #70 | AC-11 | "Open Settings" deep-link CTA (FR-AC-04 / AC-11 + parallel FR-FR-01 contact-permission gap; **P1 chore** — the highest-ranked unshipped carry-forward candidate, surfaced by PR #55 QA; closes the PR #55 §2.4 AC-11 graceful-degradation deferral and the SCR-10 `openExternalPick` placeholder) — adds **one** native settings-deep-link plugin (`app_settings: ^7.0.0`, iOS podspec platform 11.0 < the project's iOS 15 target) behind a thin `lib/core/services/AppSettingsService` seam + `appSettingsServiceProvider` (mirroring `UrlLauncherService`/`ImagePickerService`), exposing `openNotificationSettings()` / `openAppSettings()`. Wires the SCR-27 `_OsPermissionBanner` (now a `ConsumerWidget`) "Open Settings" button → OS notification settings, and rewires `FlutterContactService.openSettings()` from `FlutterContacts.openExternalPick()` → `AppSettingsService.openAppSettings()` (removes the line-77 TODO). New PII-free `permission_settings_opened` telemetry (`surface` enum `notifications`/`contacts`; DECLARED in `telemetry-plan.md §1.8` + wired at the presentation layer). `ios/Podfile.lock` regenerated (`pod install --repo-update`, +`app_settings` pod, no collateral version bumps) and committed; no Android `<queries>` entry (system settings intents). ADR-0019 (reverses the FR-PR-03 §2.4 "REJECTED `app_settings`/`permission_handler`" interim note). First Flutter plugin that opens an OS settings screen; first shared consumer of one permission-settings seam across `notifications`/`profile` and `friends`. Invariants 1/2/3 N/A (no money, no `simplifiedBalances`, OS-settings deep-link is not sharing — not via `Share.share`); no Cloud Function / rules / index / schema change; no `shared_preferences` (separate chore) | 2 | Merged (`dda2f97`) |
| #71 | CHORE | `shared_preferences` cross-launch persistence (**P1 chore** — the highest-ranked unshipped carry-forward candidate now that #70 merged; the natural pair with the #70 `app_settings` chore, deliberately NOT bundled; closes the `notification_permission_controller.dart` TODO and the `reminder_cooldown_provider.dart` deferral) — adopts **one** native plugin (`shared_preferences: ^2.5.5`, iOS pod `shared_preferences_foundation` platform 13.0 < the project's iOS 15 target, no version break) behind a thin `lib/core/services/KeyValueStore` seam (`KeyValueStore` abstract + `SharedPreferencesKeyValueStore` + `InMemoryKeyValueStore` default + `keyValueStoreProvider`, mirroring `AppSettingsService`/`UrlLauncherService`) exposing a **synchronous** typed surface (`getBool`/`setBool`/`getString`/`setString`/`remove`) over an already-loaded `SharedPreferences`, loaded once in `main()` and injected via a `ProviderScope` override. Persists FR-AC-04 `wasPermanentlyDenied` (hydrated in `build()`, awaited `setBool` on the deny/error transition; line-89-90 TODO removed; controller + README dartdocs corrected from "this session" to "next launch") and the FR-SE-09 reminder cooldown (promotes `reminderCooldownProvider` to a `NotifierProvider.family` so read-hydrate / write-persist / **expiry guard** live in one class — a past `nextAllowedAt` hydrates as `null` with lazy key removal so a stale value never disables the button; writer → `notifier.set(...)`). Key registry `lib/core/persistence/preference_keys.dart`. **NO telemetry** (persistence is not a user action). `ios/Podfile.lock` regenerated (`pod install --repo-update`, +`shared_preferences_foundation` pod, no collateral version bumps) and committed; no Android `<queries>` entry. ADR-0020 (reverses the FR-AC-03 §2.6 / FR-SE-09 §2.6 in-memory-for-v1.0 calls). First on-device cross-launch persistence; second consecutive consumer of the `lib/core/services/` thin-shim pattern after #70. Invariants 1/2/3 N/A (no money, no `simplifiedBalances`, local storage is not sharing); Invariant 4 reinforced; no Cloud Function / rules / index / schema change | 3 | Merged (`a0de106`) |
| #72 | CHORE (closes #47) | Firestore rules — restrict friendship-expense edit / soft-delete to the **expense creator** (defence-in-depth re-check of the FR-EX-06 client UI gate; adds `request.auth.uid == prev.createdBy` to `isValidExpenseUpdate()`, so a non-creator friendship member can no longer edit or soft-delete via the rules). Inverts the two self-documenting `assertSucceeds` "flip to assertFails" placeholder tests in `expenses-friendship.test.ts` and adds the creator-success counterparts; full rules suite green (10 suites / 200 tests). The settlement either-party soft-delete (the settlements `allow update`) is deliberately left asymmetric (settlements are bilateral). Pure `firestore.rules` + rules-tests; no client / Cloud Function / trigger / schema / `firestore.indexes.json` change. First rules PR that TIGHTENS an existing `allow`; first issue-backed PR in several slots (opens with `Closes #47`) | 2 | Merged (`33f870d`) |
| #73 | CHORE (refs #20 #21 #23; closes #21) | **Bucket-B close-with-evidence bundle** — first dedicated Bucket-B tracker-hygiene PR. Verifies the Sprint-1 boundary-audit findings that Sprint 2 PRs already resolved (CV3 → #36; R1–R3 → #32; R5a → #51; R7–R8 → #48; PY3 Functions/emulator layer → the `functions/test/integration/*` suite enabled in CI by #36, extended by #37 / #45 / #65), posts per-issue evidence comments, **fully closes #21** (all non-groups rules findings resolved; the R4/R5b/R6 groups halves re-scoped to the Sprint 3 Groups epic), and **re-scopes #20** (CV3 closed; SC1–SC4 kept open) and **#23** (PY3 Functions-layer closed; the Flutter-harness PY3 half + RT2 + INV2 kept open). Reconciles `docs/audits/sprint-1/07-bucket-b-burndown.md` (PR #58 → current) + this plan + `next-three-prs.md`. Carries a `Closes #21` line only. No app code / rules / new tests / schema / index / Cloud Function change; no new ADR. ~3 SP effort but **velocity-excluded** (documentation + issue-tracker hygiene, like #59 / #61) | 0 | Merged (`f9a4c54`) |
| #74 | CHORE (closes #15 #16 #17 #18) | **`chore(auth)` client-housekeeping bundle** — first of the three consolidated Sprint-2 close-out PRs. Renames `authStateNotifierProvider` → `authStateProvider` (M1; ~24 `.dart` sites + auth/notifications READMEs + `state-management.md`); relocates `firebaseFirestoreProvider` / `firebaseStorageProvider` / `phoneAuthRepositoryProvider` to `lib/core/providers/` (M4; `currentUserIdProvider` deferred as a separate follow-up to keep #17 to its literal scope); emits the four secondary auth-funnel events `phone_entry_viewed` / `phone_validation_failed` / `otp_send_requested` / `otp_verification_started` (T4 — the last supersedes the non-standard `signup_otp_submitted`, T3) and corrects the `is_new_user` typing note to `int (0/1)` (T5; Firebase Analytics rejects a `bool` param); screen-spec polish (S1 splash 3 s → 1500 ms; S3 OTP-send error → snackbar; S4 live `XXXXX XXXXX` formatting via a new `IndianPhoneDisplayFormatter` wired in phone-entry only; S5 resend-exhausted copy). No rules / trigger / schema / index / Cloud Function change; no new ADR (documented architecture alignment). | 5 | Merged (`ce6d594`) |
| #75 | DOCS (closes #19 #24 #28) | **`docs` close-out bundle** — second of the three consolidated Sprint-2 close-out PRs. Adds the #19 (CV2) before/after coverage fields to `feature-pr-conventions.md` §6 + `.github/PULL_REQUEST_TEMPLATE.md`; completes the #24 CN3 Jest-config-separation table (`jest.config.js` / `jest.rules.config.js` / `jest.integration.config.js` — roots, npm scripts, workers, emulator ports) in §3 and adds the CN4 Cloud-Functions PR checklist (region pinning to `asia-south1`, error-code mapping, transaction usage, idempotency) to §6 + the PR template; creates the #28 (SR3) Friends HTML mockup `docs/design/05-mockups/09-friends.html` (the 9th mockup; SCR-09..12 aligned) and updates the mockups `README.md` index. Reconciles `07-bucket-b-burndown.md` (CV2 / CN3 / CN4 / SR3 → closed; Total 10 / 27 → 14 / 23). Pure docs/design — no `lib/` / `functions/` / rules / trigger / schema / index change; no new ADR. **Velocity-excluded.** | 0 | Merged (`dbc209d`) |
| #76 | TEST (closes #20; refs #23) | **`test` close-out bundle** — third and final of the three consolidated Sprint-2 close-out PRs. **Fully closes #20**: SC1 concurrent-submit guard test for phone entry (plus a separate `fix(auth)` adding the `isLoading` guard the test surfaced); SC2 OTP auto-retrieval-timeout tests at the genuine `requestOtp` consumers (the `FirebasePhoneAuthRepository` wiring + the phone-entry controller's `otp_auto_read_failed` path); SC3 `MAX_SAFE_INTEGER` overflow-boundary + SC4 100+/1000-member algorithm scalability tests under `functions/test/simplified-debts/`. Closes the **#23** RT2 (per-step duration logging on the emulator-dependent `pr.yml` steps) and INV2 (first automated Invariant-3 enforcement: a `ShareServiceBase.share()` boundary unit test + a `share_boundary_contract_test.dart` grep over `lib/`) halves **with evidence**, and **re-scopes #23** again — the PY3 Flutter emulator integration-harness remainder is kept **open** under a narrowed scope (a real `integration_test/` harness needs an Android emulator in CI; deferred rather than blocking the bundle). `Closes #20` + `Refs #23`. No `lib/**` change beyond the single `fix(auth)` guard commit; no `functions/src/**` / rules / trigger / schema / index change; no new ADR. **Carries 5 SP.** | 5 | Open (≥ #76) |

---

## Velocity

| PR | SP | Status |
|---|---|---|
| #31 | 3 | Merged |
| #32 | 3 | Merged |
| #34 | 2 | Merged |
| #35 | 3 | Merged |
| #36 | 3 | Merged |
| #37 | 5 | Merged |
| #38 | 5 | Merged |
| #41 | 0 | Merged (docs-only) |
| #42 | 5 | Merged |
| #43 | 5 | Merged |
| #44 | 3 | Merged |
| #45 | 3 | Merged (chore — Stream A + Stream B) |
| #46 | 5 | Merged |
| #48 | 5 | Merged |
| #51 | 5 | Merged |
| #52 | 8 | Merged |
| #53 | 10 | Merged |
| #54 | 6 | Merged |
| #55 | 5 | Merged |
| #56 | 3 | Merged (chore — UX foundation) |
| #57 | 3 | Merged (FR-HD-04 + bundled regression closure) |
| #58 | 3 | Merged (FR-SE-08 settlement-history screen) |
| #60 | 3 | Merged (FR-PR-05 contact-support mailto flow) |
| #62 | 5 | Merged (FR-HD-01/02 home dashboard) |
| #63 | 3 | Merged (FR-PR-04 my friends/groups + tab nav) |
| #64 | 5 | Merged (FR-PR-02 change phone via OTP re-verification) |
| #65 | 8 | Merged (`d542793`, FR-AU-09 delete account + cascade cloud function) |
| #67 | 5 | Merged (`1f26548`, FR-HD-03 monthly spend category breakdown chart) |
| #69 | 3 | Merged (`8dd67f9`, FR-AC-05 deep-link tab-switch on notification tap) |
| #70 | 2 | Merged (`dda2f97`, AC-11 "Open Settings" deep-link CTA) |
| #71 | 3 | Merged (`a0de106`, `shared_preferences` cross-launch persistence — `KeyValueStore` seam + `wasPermanentlyDenied` + FR-SE-09 cooldown + expiry guard) |
| #72 | 2 | Merged (`33f870d`, Issue #47 friendship-expense creator-only rules hardening — `Closes #47`) |
| #73 | 0 | Merged (`f9a4c54`) — Bucket-B close-with-evidence bundle (documentation + issue-tracker hygiene); **velocity-excluded** per the #59 / #61 convention, so its ~3 SP of verification/reconciliation effort counts 0 and it is not in the "PRs so far" tally |
| #74 | 5 | Merged (`ce6d594`) — `chore(auth)` client-housekeeping bundle (closes #15 / #16 / #17 / #18); feature-adjacent client work, **5 SP** now counted in the Total per the rolling-reconciliation convention |
| #75 | 0 | Merged (`dbc209d`) — `docs` close-out bundle (closes #19 / #24 / #28); pure docs/design, **velocity-excluded** (like #59 / #61 / #73), so it contributed 0 and is not in the "PRs so far" tally |
| #76 | 5 | Merged (`3f3cd16`) — `test` close-out bundle (closes #20; re-scopes #23, with RT2 + INV2 closed with evidence and the PY3 Flutter-harness remainder kept open); substantive test engineering, **5 SP** counted — advanced the Total 137 / 33 → **142 / 34** |
| #77 | 0 | Merged (`b9b1e63`) — `chore` path-filter PR pipeline + milestone-tracking convention + deepened review skill; CI + governance, **velocity-excluded** (like #59 / #61 / #73 / #75), Total unchanged **142 / 34** |
| #91 | 0 | Open — `chore` Sprint 2 boundary cleanup and audit findings (the Sprint 2 → Sprint 3 boundary audit; 33 Bucket-A fixes, 44 Bucket-B issues #78–#90, ADR-0021/0022/0023); audit + cleanup, **velocity-excluded** (like #73 / #75), Total unchanged **142 / 34** on merge |
| **Total** | **142** | **34 PRs so far** |

> Velocity counts feature/chore PRs only. Pure documentation and CI
> infrastructure PRs are excluded (consistent with #59
> documentation-reconciliation): #59 (`093fce7`) and #61 (`d474507`,
> CI pipeline speed-up) are merged but carry no feature SP. The Issue #47
> friendship-expense creator-only rules hardening (2 SP) merged as #72
> (`33f870d`) and is now counted in the Total. The **Bucket-B close-with-evidence
> bundle** merged as #73 (`f9a4c54`); as documentation + issue-tracker hygiene it is
> **velocity-excluded** (same rule as #59 / #61), so it contributed **0**. The
> **`chore(auth)` client-housekeeping bundle** has since merged as #74 (`ce6d594`):
> feature-adjacent client work that **carries 5 SP**, so per the rolling-reconciliation
> convention that 5 SP is now counted and the Total advances **132 SP / 32 PRs → 137 SP
> / 33 PRs**. The **`docs` close-out bundle** merged as #75 (`dbc209d`, closes #19 /
> #24 / #28); pure docs/design and **velocity-excluded** (same rule as #59 / #61 /
> #73), so it contributed **0** and the Total stayed at **137 / 33**. The next PR —
> the **`test` close-out bundle** (#76, closes #20; re-scopes #23) — is substantive
> test engineering that **carries 5 SP**; per the rolling-reconciliation convention it
> is added as Open now and its 5 SP is counted when the next reconciliation flips it to
> Merged, advancing **137 / 33 → 142 / 34** and closing out the Sprint-2 chore backlog.
> The Total is never silently inflated.

Sprint 1 reference:

| Metric | Sprint 1 |
|---|---|
| PRs merged | 10 (#1 through #10) |
| Story points delivered | 43 |
| Chore/cleanup PRs | 4 (#11 through #14, plus hotfix #29 and chore #30) |

---

## Scope Notes

- FR-FR-01 is now **complete** across three PRs: the contact picker UI (PR #31,
  merged), the matching and friendship creation logic (PR #32, merged), and the
  manual phone entry path (PR #34, merged). This three-PR split validated
  clean pattern reuse of the phone validator, IndianPhoneInputFormatter, and
  MatchAndInviteController.
- ADR-0013/0014 reconciliation (PR #33, merged before PR #34) confirmed both
  ADRs cross-reference each other. No new ADR was needed for PR #34.
- FR-FR-02 (link existing user or invite via system share sheet) was implemented
  as part of PR #32's MatchAndInviteController. The story file exists at
  `docs/sprint-zero/stories/FR-FR-02-link-or-invite-friend.md`.
- FR-FR-03 (friends list with simplified net balance) shipped in PR #35 — the
  first client surface to read `simplifiedBalances` (Invariant 2 read path) and
  the first to display monetary values in INR (Invariant 1). It introduced the
  shared `formatInrFromPaise` formatter and `netBalancePaise` pure function in
  `lib/core/`, the `userProfileProvider.family(uid)` caching pattern, and a
  composite Firestore index `memberIds + lastActivityAt`.
- FR-SE-03/04 (`onExpenseWriteFriendship` trigger) shipped in PR #36 — the
  first Firestore trigger in the application and the first non-callable
  producer of `simplifiedBalances` (Invariant 2 server-side writer). It
  added a shared `recomputeAndWrite` core to the simplified-debts module,
  the `lastActivityAt` monotonicity guard, the bounded-enumeration sum
  check in Firestore Security Rules for the
  `friendships/{id}/expenses/{id}` subcollection, and enabled
  `npm run test:integration` inside `firebase emulators:exec` so future
  triggers exercise their registration end-to-end in CI.
- FR-FR-04 (per-friend transaction history) shipped in PR #42 — the
  first client surface to read the `friendships/{fid}/expenses/{eid}`
  subcollection PR #38 wrote to, and the first surface to read the
  top-level `settlements/{settlementId}` collection PR #37 shipped
  rules + a trigger for. It introduced
  `lib/features/settlements/` (the read-side scaffolding for the
  settlements feature folder), extended `ExpenseRepository` with
  `watchExpensesByFriendship`, added a combined `friendDetailProvider`
  that joins three real-time streams (friendship doc + expenses +
  settlements) into a `FriendDetailState` sealed union, and replaced
  the PR #35 placeholder screen with `FriendDetailScreen`. The
  settlements composite index was extended from
  `(contextType, contextId)` to `(contextType, contextId, date)` to
  unblock the canonical query — DevOps deploys the updated
  `firestore.indexes.json` before merge.

## Pattern Reuse Validation (PR #34)

PR #34 was intentionally the smallest feature PR in Sprint 2 to validate that
the patterns from PRs #31/#32 generalise cleanly. Key findings:

- **Phone validator reuse:** `validateIndianMobile()` from `lib/core/validators.dart`
  lifted cleanly. No fork or wrapper needed. Already in shared location.
- **Input formatter reuse:** `IndianPhoneInputFormatter` from auth imported
  across feature boundary without friction. Future chore may relocate to
  `lib/core/widgets/`.
- **Controller reuse:** `MatchAndInviteController.performLookup()` consumed a
  `SelectedContact` from manual entry identically to the contact picker path.
  No subclassing or new methods required.
- **No friction surfaced.** The three-PR pattern split for FR-FR-01 validated
  cleanly.

## Pattern Establishment (PR #35)

PR #35 introduced patterns that downstream balance-rendering screens will
inherit:

- **`lib/core/formatters/inr_formatter.dart`** — single source of truth for
  paise → INR string formatting (Indian numbering, Unicode minus, always two
  decimal places). Every future screen that shows money must call this
  formatter; inline arithmetic is forbidden by the boundary contract grep.
- **`lib/core/balances/net_balance.dart`** — pure read-side reducer for the
  nested `simplifiedBalances` map. Reusable for the Home dashboard
  (`netBalanceProvider`, FR-HD-01) and groups (`group_list_provider`).
- **`lib/core/telemetry/event_id_hash.dart`** — SHA-256-truncated hash for
  opaque correlation IDs in telemetry. Used by `friend_row_tapped`; reuse for
  any future event that would otherwise carry a deterministic UID-composed ID.
- **`userProfileProvider.family(uid)`** caching pattern — one-shot cached user
  doc lookups, keyed per uid via Riverpod family. Reusable for any screen that
  resolves "the other user's display profile" by uid (group member list,
  expense splits, etc.).
- **`FriendDetailPlaceholderScreen`** — intentional minimal placeholder; the
  FR-FR-04 PR replaces it with the real Friend Detail screen and keeps the
  same call site in `FriendsListScreen.onRowTap`.

## Pattern Establishment (PR #36)

PR #36 introduced patterns that downstream Cloud Functions triggers will
inherit:

- **Shared core extraction (`recomputeAndWrite`)** — the simplified-debts
  callable and the new `onExpenseWriteFriendship` trigger now both consume
  a typed-result core that takes an `alsoSet` payload for atomic
  additional writes. Future triggers (`onExpenseWriteGroup` in Sprint 3,
  `onSettlementWrite` next) reuse this seam without re-implementing the
  algorithm.
- **`lastActivityAt` monotonicity guard** — `max(existing, eventTimestamp)`
  applied inside the same Firestore transaction as the
  `simplifiedBalances` write. Prevents out-of-order Cloud Functions
  delivery from regressing the friends-list ordering (FR-FR-03 AC-6).
- **Bounded enumeration sum check in Firestore Security Rules** — the
  `friendships/{id}/expenses/{id}` block enumerates split positions up to
  the schema-natural cap (N=2 for a two-member friendship) with each
  index access guarded by `splits.size() > i`. The groups subcollection
  (Sprint 3) will declare its own bounded enumeration matching the
  group-member cap.
- **First Firestore trigger registration end-to-end in CI** — the PR
  pipeline now runs `npm run build && npm run test:integration` inside
  `firebase emulators:exec --only auth,firestore,functions,storage`, so
  every future trigger PR exercises its registration, not just its
  handler in isolation.
- **First non-callable producer of `simplifiedBalances`** — Invariant 2
  transitioned from a read-side abstraction to a live server-side
  production-data writer. The DoD invariant grep confirms exactly one
  write site remains in `functions/src/` (variant 2.3(b) collapses the
  callable and trigger to a shared writer).

The architect notes appended to
`docs/sprint-zero/stories/FR-SE-03-04-expense-trigger-friendship.md`
ratify all design decisions taken in this PR.

## Pattern Extension (PR #37)

PR #37 extends the patterns ratified by PR #36 to ship the
`onSettlementWrite` trigger:

- **Shared core takes an additional read source** —
  `recomputeAndWrite` now reads both the per-context expenses
  subcollection AND the top-level `settlements` collection inside the
  same Firestore transaction. `computeNetBalances` accepts both and
  folds them together (expenses credit payer / debit splits;
  settlements credit `fromUserId` / debit `toUserId`). The public
  signature of `recomputeAndWrite` is unchanged — settlements are an
  internal implementation detail.
- **First trigger on a top-level collection** — the
  `onSettlementWrite` trigger registers at `settlements/{settlementId}`
  and reads the context discriminator (`contextType`, `contextId`)
  from the document data rather than the trigger path. Naturally
  handles both friendship and group contexts without modification when
  groups ship in Sprint 3.
- **Invariant-2 parallel for `verificationStatus` on settlements** —
  enforced by the new `match /settlements/{settlementId}` security
  rules block (field-level diff rejects client mutation). v1.0 has no
  server-side writer; the rules are the enforcement mechanism per
  ARCH-EXT-06.
- **Settlements schema additions** — `deleted: bool` (default `false`)
  for soft-delete and `createdAt: timestamp` (immutable) for audit
  history. The settlements rules permit ONLY soft-delete on update;
  every other field is immutable. Hard-delete is admin-only.
- **In-code soft-delete filter for settlements** — the algorithm
  filters `deleted === true` settlements in JavaScript inside
  `computeNetBalances` rather than chaining a third Firestore
  `where('deleted', '!=', true)` on the cross-field query. This avoids
  an over-specified three-field composite index for negligible
  computational cost (settlements per context are small).
- **Composite index for settlements queries** — declared in
  `firestore.indexes.json`:
  `{collectionGroup: 'settlements', fields: [contextType ASC, contextId ASC]}`.

The architect notes appended to
`docs/sprint-zero/stories/FR-SE-05-06-settlement-trigger.md`
ratify the PR #37 design decisions.

---

## Post-Merge Cleanup Backlog

Small follow-up items surfaced during a feature PR's QA sign-off that
were judged too minor to block merge. Listed here so they are not lost
between sprints. Severity per the project bug grading scale: **S4 =
nice-to-have, no functional impact**.

### From PR #38 (FR-EX-01 expense creation UI) — **CLOSED BY PR #45**

QA sign-off was APPROVED WITH CAVEATS — see the "QA Sign-Off" section in
`docs/sprint-zero/stories/FR-EX-01-expense-creation.md`. Three S4 items
were deferred to a follow-up cleanup PR and shipped as Stream B of
**PR #45** (chore — bundled with the Stream A lookup-user rate-limit
doc-path fix; squash commit landed 2026-06-06).

1. **Stale `expense_added` / `expense_add_failed` references in 3 design docs**
   — **RESOLVED in PR #45.** Renamed to `expense_save_succeeded` /
   `expense_save_failed` in the six legacy positions:
   - `docs/design/03-architecture/non-functional-design.md:399`
   - `docs/design/06-screen-specs/06-08-home-and-search.md:152, 517, 519`
   - `docs/design/06-screen-specs/19-22-expenses.md:360, 386`

   The `type: 'expense_added'` notification-type schema discriminator
   (per SRS §7.2; `firestore-schema.md:202`) was deliberately left
   untouched — see PR #45 AC-B1 + AC-X4 negative guard.

2. **Splitter test descriptions still label `99999999` as "the maximum
   permitted total"** — **RESOLVED in PR #45.** Updated the cap labels
   and the dependent share assertions in both files to use the real
   cap `999999999` (= ₹99,99,999.99 per SCR-19). See PR #45 chore-story
   Architect Notes §2.7 for the coordinated share-assertion
   reconciliation rationale.

3. **Missing `// TODO(SCR-08)` comment in `friends_list_screen.dart`**
   — **RESOLVED in PR #45.** Added the comment block at the top of
   the file (immediately after the import block), citing
   `FriendDetailScreen` (the real screen since PR #42) rather than the
   pre-PR-#42 `FriendDetailPlaceholderScreen` wording.

### From PR #38 deploy (Firebase CLI warnings, 2026-06-06) — **CLOSED BY PR #44**

Two **deadline-bound** items surfaced by the post-PR #38 functions deploy.
Filed as standalone GitHub issues (not S4 — these are S2 because of the
hard 2026-10-31 deploy-blocker) and tracked separately from the S4 set
above. **Both shipped together in PR #44 (D5 runtime upgrade).**

4. **Cloud Functions runtime Node 20 decommissioned 2026-10-31** —
   tracked as [#39](https://github.com/avtansh-code/OneByTwo/issues/39).
   After this date, `firebase deploy --only functions` would have been
   rejected for the Node 20 runtime. **Closed by PR #44** — Node 22 LTS
   shipped: `functions/package.json` `engines.node = "22"`,
   `firebase.json` `functions[0].runtime = "nodejs22"`, and all five
   `actions/setup-node@v4` invocations across `.github/workflows/pr.yml`
   (three) and `.github/workflows/release.yml` (two) pinned to `'22'`.

5. **`firebase-functions` package outdated (6.x → 7.x)** — tracked as
   [#40](https://github.com/avtansh-code/OneByTwo/issues/40). CLI warned
   on every deploy. **Closed by PR #44** — `firebase-functions` upgraded
   from `^6.1.2` to `^7.0.0` (resolved `7.2.5`); the CLI deprecation
   warning on every deploy clears.

**Outcome:** zero source-code reconciliations required (the v6 → v7
breaking changes do not apply to our v2-only callsites — see
`docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` Architect Notes
§2.4 and §2.7 for the applicability matrix). The five-layer test
pyramid stays green on the new matrix:

| Layer | Suite count | Test count |
|---|---|---|
| 1 + 2 + 3 (algorithm unit + property + boundary) | 9 / 9 | 100 / 100 pass |
| 4 (Firestore + Storage rules) | 7 / 7 | 149 / 149 pass |
| 5 (full-emulator integration) | 3 / 4 + 1 skipped suite | 28 pass / 5 skipped |

Coverage on `functions/src/simplified-debts/function.ts` stays at
89.13% branch (PR #36 baseline 88.57%; unchanged within margin).

Both items close umbrella item D5 in
`docs/audits/sprint-1/07-bucket-b-burndown.md`. Issue #22 (umbrella
dependency-upgrade backlog) retains D1, D2, D4, D6, D7.

---

## Pattern Establishment (PR #44)

PR #44 establishes the **dependency-upgrade chore pattern** that
future deadline-bound deploy-toolchain bumps (Node 24, future
`firebase-functions@8.x`, etc.) will inherit:

- **Atomic runtime + SDK bundling** — Node 22 + `firebase-functions@7.x`
  ship in the same PR so the rollback story is a single `git revert`.
  Splitting would double the breaking-change reconciliation surface
  AND require two reverts to recover. The "split into PR #44a + PR
  #44b" escape hatch in Architect Notes §2.1 was not exercised; the
  default single-PR approach worked.
- **Pre-implementation breaking-change applicability matrix** — the
  architect populates §2.4 of the chore story with a row-per-breaking-
  change table mapping each v6 → v7 (or analogous) change to our
  codebase. Validated post-implementation in §2.7. For PR #44 the
  prediction was "zero reconciliations required"; the test pyramid
  confirmed it.
- **Five-layer test pyramid as the upgrade gate** — every layer
  (algorithm unit, property, boundary, rules, integration) must stay
  green on the new matrix BEFORE merge. The CI pipeline already
  enforces this; the chore-story Architect Notes §2.6 codifies the
  execution order.
- **CI runner pin scheme** — the five `actions/setup-node@v4`
  invocations across `pr.yml` (three) and `release.yml` (two) move
  in lockstep with the `functions/package.json` `engines.node` and
  `firebase.json` `functions[0].runtime` pins. Future runtime bumps
  follow the same pattern.
- **Forward-compatibility note in §2.9** — the chore story documents
  the next foreseeable runtime forcing event (Node 22 deprecation
  2027-04-30 / decommission 2027-10-31), so the next D-row update
  can be slotted ~6 months ahead of the cutoff.

The architect notes appended to
`docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` ratify the
PR #44 design decisions.

---

## Sprint 2 Chore Backlog (open GitHub issues)

The Sprint 1 boundary audit (PR #14) deferred 37 findings into Bucket B.
Fourteen of those were filed as labelled GitHub issues
(`sprint-2-chore`) with numbers **#15-#28**; a fifteenth `sprint-2-chore`,
**#47** (friendship-expense creator-only rules hardening), was filed
mid-sprint during PR #46 (reviewer note R-2) and is tracked in the final
row below. Of **#15-#28**, only **#25** is closed on GitHub (by PR #38);
several others have been partially or fully addressed by Sprint 2 feature
PRs (#31-#36). The **#15-#28** rows reflect the audited status as of PR #36;
the **#47** row reflects its closure by PR #72 (`33f870d`).

> **Audit — every open `sprint-2-chore` issue is tracked in the table
> below** (#15-#28 and #47). The other open GitHub issues are deliberately
> **NOT Sprint-2-committed** and are listed here so nothing is silently
> dropped:
> - **#8** (`backlog`) — `chore(ci): upgrade GitHub Actions to Node.js 24`.
>   CI maintenance, not Sprint-2-scoped; stays on the `backlog`.
> - **#49 / #50 / #66 / #68** (no label, **FUTURE / out-of-v1.0**) —
>   orphan-receipt reaper, trigger no-op-recompute optimisation, account-
>   deletion reaper, and the monthly-spend rollup respectively. Tracked in
>   `docs/sprint-zero/next-three-prs.md`; explicitly out of the Sprint 2
>   commitment.

Status legend:
- **Closed-in-code** — work is complete in the repository; the GitHub
  issue can be closed by ticking the relevant checklist and merging
  evidence of the fix. Sprint-1 burndown
  (`docs/audits/sprint-1/07-bucket-b-burndown.md`) is the authority on
  which Bucket-B IDs are formally resolved.
- **Partially addressed** — at least one named Bucket-B sub-item is
  resolved; remainder is still open under the same issue.
- **Open** — no work done yet.

| # | Title | Audit IDs | Status | Verification |
|---|---|---|---|---|
| [#15](https://github.com/avtansh-code/OneByTwo/issues/15) | Rename `authStateNotifierProvider` to `authStateProvider` | M1 | Open | 10+ references still use the old name across `lib/main.dart`, `lib/features/profile/**`, `lib/features/auth/presentation/**`. |
| [#16](https://github.com/avtansh-code/OneByTwo/issues/16) | Missing secondary telemetry events + `is_new_user` typing | T3, T4, T5 | Open | `phone_entry_viewed` / `phone_validation_failed` / `otp_verification_started` / `otp_send_requested` not yet emitted; `is_new_user` still logged as `int` (`otp_entry_controller.dart:215` — `value.isNewUser ? 1 : 0`); `signup_otp_submitted` decision not recorded. |
| [#17](https://github.com/avtansh-code/OneByTwo/issues/17) | Relocate core providers to `lib/core/providers/` | M4 | Open | `lib/core/providers/` does not exist; `firebaseFirestoreProvider`, `firebaseStorageProvider`, `phoneAuthRepositoryProvider` still in feature trees. |
| [#18](https://github.com/avtansh-code/OneByTwo/issues/18) | Screen-spec alignment (splash, phone entry, OTP) | S1, S3, S4, S5 | Open | Splash uses `Duration(seconds: 3)` (`splash_screen.dart:19`); spec says 1500 ms. Other items (inline-vs-snackbar OTP error, live phone formatting, exhausted-resend copy) still unresolved. |
| [#19](https://github.com/avtansh-code/OneByTwo/issues/19) | Add PR coverage tracking to conventions | CV2 | Partially addressed | `feature-pr-conventions.md` has an enforced-thresholds section and `.github/PULL_REQUEST_TEMPLATE.md` has a "Coverage thresholds maintained" checkbox. **Still missing:** explicit before/after coverage fields requested by the issue. |
| [#20](https://github.com/avtansh-code/OneByTwo/issues/20) | Improve test coverage gaps | SC1, SC2, SC3, SC4, **CV3** | **Re-scoped & kept open** (PR #73 close-with-evidence) | **CV3 closed by PR #36** — `functions/src/simplified-debts/function.ts` branch coverage **76% → 88.57% (31/35)** at the #36 gate (the `recomputeAndWrite` variant 2.3(b) refactor + trigger-boundary tests); measured **89.13%** at PR #73. Evidence comment posted on #73. Remaining open under the narrowed scope: SC1 (concurrent-submit guard), SC2 (OTP auto-retrieval timeout), SC3 (`MAX_SAFE_INTEGER` overflow), SC4 (large-group 100+ scalability — Sprint 3 groups). No `Closes` line. |
| [#21](https://github.com/avtansh-code/OneByTwo/issues/21) | Firestore + Storage rules test gaps | R1–R3 (friendships); R4–R6 (groups); R7–R8 (Storage) | **Closed by PR #73** (close-with-evidence; `Closes #21`) | **R1–R3 closed by PR #32** (`friendships.test.ts` create/update/delete validation). **R5a closed by PR #51** (`activity.test.ts`, 12 tests — the Sprint-2 activity-rules sub-ID split from audit R5). **R7–R8 closed by PR #48** (`storage-rules/receipts.test.ts`, 23 tests; size + content-type negatives; the file header declares "Closes R7 + R8"). Only the **groups** halves remain — **R4** (`groups/{id}` create), **R5b** (`groups/{id}` update), **R6** (`groups/{id}` delete) — re-scoped to the Sprint 3 Groups epic, NOT under #21. (Correction per `04-dependency-and-security.md`: R4/R5/R6 are all `groups/{id}` rules — earlier rows mislabelled R4 as an expense-rules test closed by #36 and R6 as a settlement-rules test closed by #37.) |
| [#22](https://github.com/avtansh-code/OneByTwo/issues/22) | Dependency upgrades — Riverpod 3.x, share_plus, firebase-functions 7.x | D1, D2, D4, D5, D6, D7 | **Open — D5 now URGENT** (split into [#39](https://github.com/avtansh-code/OneByTwo/issues/39) Node 20 decommissioned **2026-10-31** and [#40](https://github.com/avtansh-code/OneByTwo/issues/40) firebase-functions 6→7) | Sprint 1 audit deferral. D5 was reinforced by the post-PR #38 deploy warnings (2026-06-06) and split into two deadline-aware sub-issues; #39 has ~5 months runway before the next `firebase deploy --only functions` is rejected. D1, D2, D4, D6, D7 remain tracked on the umbrella. |
| [#23](https://github.com/avtansh-code/OneByTwo/issues/23) | Expand integration tests for Sprint 2 flows | PY3, RT2, INV2 | **Re-scoped & kept open** (PR #73 close-with-evidence) | **PY3 substantially resolved at the Functions/emulator layer** — `npm run test:integration` runs in CI under `firebase emulators:exec` and exercises the friend-lookup, expense-create + simplified-debts, settlement-write, and account-deletion flows (`functions/test/integration/*`); 5 suites / 43 tests green at PR #73. Evidence comment posted on #73. Remaining open: the **Flutter `test/integration/**/*_flow_test.dart` harness half of PY3** (`skip:`ped stubs await the emulator harness), **RT2** (CI step-duration logging), and **INV2** (system-share-sheet verification — partially addressed by PR #32's invite flow). No `Closes` line. |
| [#24](https://github.com/avtansh-code/OneByTwo/issues/24) | Conventions doc — CF PR checklist and Jest config separation | CN3, CN4 | Open | `feature-pr-conventions.md` does not yet enumerate the Jest config split (`jest.config.js` vs `jest.rules.config.js` vs `jest.integration.config.js`) nor CF-specific PR checklist items (region pinning, error-code mapping, transaction usage, idempotency). |
| [#25](https://github.com/avtansh-code/OneByTwo/issues/25) | Expense event naming convention decision | SR8 | **Closed by PR #38** (Camp B adopted — see Critical Constraint C-1 above, marked RESOLVED) | Decision: `expense_save_succeeded` / `expense_save_failed` per Architect Notes §2.0 of FR-EX-01. Five telemetry-plan occurrences renamed; `lib/features/expenses/application/expense_telemetry.dart` ships the matching constants. `Closes #25` recorded in PR #38 body. |
| [#26](https://github.com/avtansh-code/OneByTwo/issues/26) | Release pipeline secrets + DPDP legal sign-off | S2_sec, SR12 | Open | Sprint 6 work — explicit tracking required before release execution. |
| [#27](https://github.com/avtansh-code/OneByTwo/issues/27) | Float/double rejection hook for Invariant 1 | INV3 | Open — low priority | The type system already enforces Invariant 1; a hook would be belt-and-braces. DoD grep across `lib/**` and `functions/src/**` for `double.*amountPaise` returns 0 in PR #36, so the gap is theoretical. |
| [#28](https://github.com/avtansh-code/OneByTwo/issues/28) | Friends HTML mockup | SR3 | Open | `docs/design/05-mockups/` has 8 HTML mockups but no friends-flow mockup. Wireframes and screen specs exist; only the HTML is missing. |
| [#47](https://github.com/avtansh-code/OneByTwo/issues/47) | Firestore rules: tighten friendship-expense update/delete to creator-only | — (filed mid-sprint during PR #46; FR-EX-06 §2.9 item 5 / reviewer note R-2) | **Closed by PR #72** (`33f870d`, `Closes #47`) | `isValidExpenseUpdate()` now gates friendship-context expense edit + soft-delete on `request.auth.uid == prev.createdBy`; the two `assertSucceeds` "flip to assertFails" placeholder tests in `expenses-friendship.test.ts` were inverted and creator-success counterparts added (full rules suite green, 10 suites / 200 tests). The bilateral settlement either-party soft-delete was left deliberately asymmetric. |

### Issue closure candidates (close-with-evidence PR) — EXECUTED by PR #73

The **Bucket-B close-with-evidence bundle** (PR #73) acted on these issues. Each
received a per-issue evidence comment citing the resolving commit; the canonical
evidence map is in `docs/audits/sprint-1/07-bucket-b-burndown.md` (PR #73 section):

- **#20 — re-scoped, kept OPEN.** CV3 closed with an evidence comment citing PR #36
  (`functions/src/simplified-debts/function.ts` branch coverage 76% → 88.57% (31/35);
  89.13% at PR #73). The remaining sub-items (SC1 concurrent-submit guard, SC2 OTP
  auto-retrieval timeout, SC3 `MAX_SAFE_INTEGER`, SC4 large-group scalability) stay
  open under the narrowed scope. No `Closes` line.
- **#21 — fully CLOSED (`Closes #21`).** Evidence comments cite PR #32 (R1–R3
  friendship rules), PR #51 (R5a activity rules), and PR #48 (R7–R8 Storage size +
  content-type). The only remainders are the groups halves R4 / R5b / R6
  (`groups/{id}` create / update / delete), re-scoped to the Sprint 3 Groups epic.
- **#23 — re-scoped, kept OPEN.** PY3 closed at the Functions/emulator data-flow layer
  (the `npm run test:integration` suite in CI) with an evidence comment. The Flutter
  integration-harness half of PY3, RT2 (CI step-duration logging), and INV2
  (share-sheet verification) stay open. No `Closes` line.

### Recommended sequencing (chores vs. feature pairing)

Some chores pair naturally with upcoming feature work; others are best
batched into a standalone chore PR. The orchestrator's recommendation:

| Pair with | Issues | Rationale |
|---|---|---|
| **PR #37 (`onSettlementWrite`)** | none required | Settlements work has its own scope; do not bundle chores. |
| **PR #38 (FR-EX-01 expense creation UI)** | **#25** | **MANDATORY bundle — see Critical Constraint C-1 at the top of this document.** Naming convention MUST be decided before the first expense event is logged; bundling avoids retrofitting every downstream funnel chart, alert, and test. |
| **Post-PR #38 cleanup PR (1 SP, candidate for PR #45)** | none required | The three S4 items from the PR #38 QA sign-off (stale event names in 3 design docs; splitter test cap labels; missing `// TODO(SCR-08)` comment). Pure docs + test-description fixes; ~10 lines diff total. See "Post-Merge Cleanup Backlog" section above and `docs/sprint-zero/next-three-prs.md` PR #45 slot for full detail. |
| **Standalone chore PR (Sprint 2 polish — 3 SP)** | **#15, #17, #19** | Pure mechanical refactor + template edit. Low risk. Fast feedback. |
| **Standalone chore PR (telemetry sweep — 2 SP)** | **#16, #18 (S5 only)** | Both touch auth/OTP screens; one PR keeps the analytics changes coherent. |
| **Pre-FR-EX-01 design polish PR (2 SP)** | **#18 (S1, S3, S4), #28** | Spec alignment + friends mockup before the expense screens land so the design system stabilises. |
| **Standalone CF chore PR (Sprint 3 ramp — 3 SP)** | **#24** | CF PR checklist + Jest config docs make Sprint 3's groups trigger work less ambiguous. |
| **Merged — rules-hardening chore** | **#47** | Restricted friendship-expense edit / soft-delete to the creator. Merged as **#72** (`33f870d`, `Closes #47`); pure `firestore.rules` + rules-tests. |
| **#21 fully closed; groups halves defer to Sprint 3** | **#21 (R4 / R5b / R6)** | #21 closed by PR #73 (R1–R3 / R5a / R7–R8 all resolved). The remaining group rules tests — R4 `groups/{id}` create, R5b `groups/{id}` update, R6 `groups/{id}` delete — pair with the Sprint 3 Groups epic. |
| **Defer to Sprint 4+** | **#22 (D1/D2/D4/D6/D7 remaining), #27** | Dependency upgrades and the Invariant-1 hook are non-urgent; type system + boundary contracts suffice for now. **D5 has been split out into #39 (Node 20 decommissioned 2026-10-31) and #40 (firebase-functions 6→7) and is URGENT** — slot the pair into PR #44 (default plan per `docs/sprint-zero/next-three-prs.md`) so the Cloud Functions deploy path stays open past the cutoff. |
| **Defer to Sprint 6** | **#26** | Release-only secrets and DPDP review explicitly tied to release execution. |
| **#23 re-scoped (PR #73), kept open** | **#23 (Flutter-harness PY3 + RT2 + INV2)** | PY3 closed at the Functions/emulator layer (`test:integration` in CI). Remaining: the Flutter integration harness (`skip:`ped `test/integration/**` stubs), RT2 (CI step-duration logging), INV2 (share-sheet verification). |

### Sprint 2 close-out — consolidated chore PRs (#74+)

> Added 2026-06-22. **Supersedes the single-issue groupings in the table above for the
> Sprint-2 close-out.** With every P0/P1 functional requirement shipped and #25 / #47 /
> #21 closed, the **9 remaining actionable chores are consolidated into three combined
> PRs** (down from ~9 single-issue PRs) to close the sprint quickly. Each PR keeps a
> single-token conventional-commit scope and bundles only issues that touch the same
> surface. The committed close-out scope is exactly **#15, #16, #17, #18, #19, #20, #23,
> #24, #28**.

| PR (slot) | Scope | Closes | Contents | SP |
|---|---|---|---|---|
| **#74** | `chore(auth)` | **#15, #16, #17, #18** | All client `lib/` housekeeping in one branch (no internal conflict): rename `authStateNotifierProvider` → `authStateProvider` (M1; ~24 `.dart` sites + READMEs + `state-management.md`) + relocate the three shared providers (`firebaseFirestoreProvider`, `firebaseStorageProvider`, `phoneAuthRepositoryProvider`) to `lib/core/providers/` (M4; `currentUserIdProvider` deferred as a separate follow-up to keep #17 to its literal three-provider scope) + emit the four secondary auth-funnel events (`phone_entry_viewed`, `phone_validation_failed`, `otp_send_requested`, `otp_verification_started` — the last supersedes the non-standard `signup_otp_submitted`) & correct the `is_new_user` typing note to `int (0/1)` (Firebase Analytics rejects a `bool` param) (T3/T4/T5) + screen-spec polish: splash 3 s → 1500 ms (S1), snackbar phone-entry OTP-send error (S3), live `XXXXX XXXXX` phone formatting via a new `IndianPhoneDisplayFormatter` wired in phone-entry only (S4), resend-exhausted copy (S5). | 5 |
| **#75** | `docs` | **#19, #24, #28** | Conventions doc + PR-template coverage fields (CV2) + CF PR checklist & Jest-config-separation docs (CN3/CN4) + the Friends HTML mockup (SR3). Pure docs/design; **velocity-excluded**. | 0 |
| **#76** | `test` | **#20** closes; **#23** re-scoped | SC1 concurrent-submit guard (phone entry) + the `fix(auth)` `isLoading` guard the test surfaced, SC2 OTP-auto-retrieval-timeout (repository + phone-entry-controller consumers), SC3 `MAX_SAFE_INTEGER` overflow, **SC4 large-group (100+/1000) algorithm scalability** tests — **fully closes #20** + RT2 CI step-duration logging + INV2 share-sheet boundary verification (first automated Invariant-3 guard). The PY3 Flutter emulator-harness remainder is **kept open** (re-scopes #23; a real `integration_test/` harness needs an Android emulator in CI), so the body carries `Closes #20` + `Refs #23`. | 5 |

PR slots are indicative (next available GitHub numbers ≥ #74); reconcile at each open.
Combining #15–#18 into one client PR removes the rename-vs-screen-edit serial dependency;
#76 lands after #74 so its new tests use the relocated/renamed providers.

> **#23 re-scoped a second time at #76 open.** The RT2 (CI step-duration logging) and
> INV2 (share-sheet verification) halves close **with evidence**; the PY3 Flutter
> emulator-harness remainder stays **open** under a narrowed scope. A genuine
> executable `integration_test/` harness requires an Android emulator in CI (the
> existing `test/integration/**/*_flow_test.dart` files remain render-only stubs), so it
> is deferred rather than blocking the close-out bundle — `#76` opens with `Refs #23`,
> not `Closes #23`. With #76 merged, the committed close-out scope is fully discharged
> except this single tracked remainder.

**Deferred — NOT in the committed close-out scope (recorded so nothing is dropped):**

- **#22 — dependency upgrades (Riverpod 3.x, `share_plus`, `firebase-admin`/`functions`
  majors, `build_runner`, Jest 30 / TS 6 / ESLint 9): Sprint 4+.** Breaking major-version
  migrations; rushing them right before release risks destabilising the app for no
  deadline reason (the urgent D5 axis already shipped in #44).
- **#26 — release-pipeline secrets + DPDP legal sign-off: Sprint 6.** Requires real
  Google Play / TestFlight credentials and an external legal review; cannot be completed
  pre-release.
- **#27 — float/double rejection hook (INV3): Sprint 4+, low priority.** The type system +
  boundary-contract greps already enforce Invariant 1; a hook is belt-and-braces.
