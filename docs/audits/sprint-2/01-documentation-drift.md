# Phase 1 — Documentation Drift Audit

**Date:** 2026-06-24
**Lead:** Architect
**Consulting:** PM, Flutter Dev (screen specs, state, telemetry)

Method: design docs were compared against shipped Sprint-2 code (PRs #15–#77) across
seven sub-parts. Every row is grounded in a file:line opened on both the doc and code
sides. The four HIGH findings (**S6, C1, T1, T2**) were independently re-verified by the
orchestrator before filing. Drift is recorded in both directions (implementation
diverged from doc, OR doc describes something cut/deferred). `lib/features/groups` is a
README/stub — Groups screens/providers/telemetry are Sprint-3 scope and are NOT counted
as drift here (they are Phase 5 readiness items).

---

## 1.1 Screen Specs vs Implementation

| ID | Location (spec ; code) | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| S6 | `09-12-friends.md:14` ; `match_and_invite_screen.dart:8`, `add_friend_screen.dart:162,169`, `friends_list_screen.dart:97,108`, `add_expense_context_picker_sheet.dart:205`, `match_and_invite_controller.dart:201,235-239` | **Add-friend flow is unreachable end-to-end (functional defect, VERIFIED).** `AddFriendScreen` pops a `SelectedContact` (contacts path l.162, manual path l.169) but all three callers `push<void>` and discard it. `MatchAndInviteScreen` — the only widget that runs the phone lookup and calls `createFriendship`/`openInviteShareSheet` — is never navigated to, and `matchAndInviteControllerProvider` throws `UnimplementedError` unless overridden (no override site exists). `createFriendship()` has exactly one caller (`controller.addFriend`), itself reachable only from the orphaned screen. **No reachable code path creates a friendship or sends an invite**, so FR-FR-01 (manual add) and FR-FR-02 (invite non-user) cannot complete in the running app. The spec status note claims SCR-10 (incl. Match-and-Invite) is "implemented". Not caught by tests because the wiring gap is exactly what the deferred #23 Flutter integration harness would exercise. | **High** | **Fix now.** QA to reproduce and `triage-bug` (likely S1/S2). Wire the popped `SelectedContact` into `MatchAndInviteScreen` with the controller override (currentUserId + phone), at both `friends_list_screen` add sites and the context-picker. This is the top Bucket-A candidate. | Flutter Dev |
| S1 | `06-08-home-and-search.md:12` ; `home_dashboard_screen.dart:22,53` | Status note says SCR-06 Home = placeholder (`HomeDashboardPlaceholder`); full `HomeDashboardScreen` shipped (grep: placeholder gone). Stale status note. | Medium | Fix now (update status note) | Architect/Designer |
| S2 | `06-08-home-and-search.md:111` ; `home_dashboard_screen.dart:388` | Spec references `SpendingBreakdownPlaceholderCard` as future; code ships `const SpendingBreakdownCard()` (donut + legend + empty/error). | Medium | Fix now (update spec prose) | Architect/Designer |
| S5 | `06-08-home-and-search.md:477-494` ; `add_expense_context_picker_sheet.dart:189,193,261` | SCR-08 picker: spec = two-tab Friend\|Group segmented + `OBTSearchBar`; code = stacked Friends + Groups "Coming in Sprint 3" stub, no search/close-X. Empty-copy mismatch ("No friends yet"/CTA "Add Friend" vs code "You have no friends yet"/"Add your first friend"). | Medium | Fix now (reconcile copy + mark Groups-tab deferral) | Flutter Dev + Designer |
| S7 | `09-12-friends.md:50,68` ; `friends_list_screen.dart:55-61` | SCR-09 app-bar Search action + search sub-state (State 5) + `friends_search_used` telemetry absent; app bar exposes only Add. | Medium | Decide scope (build if v1.0, else mark deferred) | Flutter Dev + Designer |
| S9 | `09-12-friends.md:221,241` ; `friend_detail_screen.dart:115-123,140` | SCR-11 ships a reminder receiving-direction card the spec does not describe; nav "View full history" → `SettlementHistoryScreen` (SCR-24) not the spec'd `/friends/:id/history`; timeline intermixes settlements vs spec "Recent Expenses". | Medium | Fix now (reconcile SCR-11 spec) | Designer + Flutter Dev |
| S16 | `23-28-settle-activity-profile.md:9` ; `delete_account_screen.dart`, `profile_screen.dart:372,396,416,435`, `home_dashboard_screen.dart:148` | Status note claims Support/Deletion are "Coming soon" stubs; both fully shipped (Delete = 5-step flow; Contact Support = mailto + fallback). Only the line-9 note is stale (SCR-28 body matches). | Medium | Fix now (rewrite status note) | Architect/Designer |
| S17 | `23-28-...:56,71,88,91-100` ; `settle_up_bottom_sheet.dart:166,224-228,277` | SCR-23 spec = routed full screen + a Settlement-Confirmation sub-screen (animated check, SRS §6.5 "high five!" microcopy, `OBTBalancePill`, "Done"); code = bottom sheet, success is a one-line snackbar + auto-pop. Confirmation sub-screen absent; spec body unreconciled. | Medium | Fix now (PM/Designer decide: cut → update spec, or build) | Designer + PM |
| S19 | `23-28-...:450,533` ; `edit_profile_screen.dart:150-174`, `change_phone_screen.dart` | Change-Phone (FR-PR-02) shipped (full two-OTP `ChangePhoneScreen`), but SCR-26 l.450 still says phone is read-only ("cannot be changed from here") and OQ-1 poses change-phone as an open question; no dedicated Change-Phone screen spec exists. | Medium | Fix now (close OQ-1, correct l.450, add spec section) | Designer + Architect |
| S3 | `06-08-home-and-search.md:12,245-423` ; (absent) | SCR-07 Search Overlay not implemented; global note says so, but the SCR-07 section carries no per-section deferral marker. | Low | Fix now (add deferral marker) | Designer |
| S4 | `06-08-home-and-search.md:94-96` ; `net_balance_header_card.dart:47,53,59` | Net-balance tints use semantic `ColorScheme` roles vs spec literal hex (deliberate dark-mode deviation; documented in code, not spec). Copy matches. | Low | Accept (note rationale in spec) | Designer/Flutter Dev |
| S8 | `09-12-friends.md:67` ; `friends_list_screen.dart:278`, `friend_detail_states.dart:147` | Error states missing spec-required "Contact Support" link; Retry only. (Recurring — see S20/S21.) | Low | Backlog | Flutter Dev |
| S10 | `09-12-friends.md:227,242` ; `friend_detail_screen.dart:80` | SCR-11 lists an overflow menu + Delete-Friend entry; code app bar has no overflow. SCR-12 Delete honestly marked deferred, but the SCR-11 overflow entry point is not. | Low | Fix now (add deferral marker) | Designer |
| S11 | `09-12-friends.md:140,243` ; `friend_detail_states.dart:92,98`, `match_and_invite_screen.dart:47` | Friend-detail empty state omits spec "Add Expense" CTA; "couldn't" vs spec "could not"; self/duplicate copy lacks `[Display name]` interpolation. | Low | Backlog | Flutter Dev |
| S12 | `06-08-home-and-search.md:524` vs `19-22-expenses.md:73` ; `step_1_amount_details.dart:81` | Cross-spec conflict: SCR-08 says description max 200 chars, SCR-19 says 1–100; code enforces `maxLength:100` (SCR-08 is the outlier). | Low | Fix now (correct SCR-08) | Designer |
| S13 | `19-22-expenses.md:49,52,525` ; `step_1_amount_details.dart:56,133-135,151` | SCR-19 nits: `autoFocus:false` vs spec true; date field `dd/MM/yyyy` vs spec `dd MMM yyyy`; backdate limit 5 yr vs SCR-08 "1 year". | Low | Backlog | Flutter Dev |
| S14 | `19-22-expenses.md:329-331` ; `step_3_receipt_and_confirm.dart:431-487` | SCR-21 confirm summary is text-only (no `OBTUserAvatar`, no per-split breakdown); "Paid by" shows generic "You"/"Friend". | Low | Backlog | Flutter Dev |
| S18 | `23-28-...:78,89` ; `settle_up_bottom_sheet.dart:229-231` | SCR-23 error: spec = `OBTSnackbar` + "Retry" action; code = plain `SnackBar`, no Retry. | Low | Backlog | Flutter Dev |
| S20 | `23-28-...:180,190,193,195` ; `settlement_history_screen.dart:345,419` | SCR-24 nits: spinner vs spec `OBTSkeletonLoader`×5; error missing "Contact Support" + retry escalation; initials `CircleAvatar` vs `OBTUserAvatar`. Copy/money/labels match. | Low | Backlog | Flutter Dev |
| S21 | `23-28-...:298,378,381` ; `activity_feed_screen.dart:161-168,376,415` | SCR-25 nits: empty "Add Expense" CTA shows a hint snackbar (FAB-chooser deferred, not reflected in spec); error missing "Contact support" link. | Low | Backlog (+ deferral note) | Flutter Dev + Designer |
| S22 | `23-28-...:564,587` ; `notification_preferences_screen.dart:179` | SCR-27 loading = spinner vs spec `OBTSkeletonLoader` (3 shimmer rows). Inconsistent: Profile uses real shimmer; History/Settle/NotifPrefs use spinners. | Low | Backlog | Flutter Dev |
| S15 | `19-22-expenses.md` SCR-20/21/22 ; `add_expense_bottom_sheet.dart`, `expense_detail_screen.dart:160-168,271,318` | **No drift.** Split + receipt attach + edit/delete faithful; delete dialog copy exact; money via `formatInrFromPaise` throughout. (Stale *code* comment `add_expense_bottom_sheet.dart:10-21` → 1.4 hygiene.) | — | Accept | — |
| S23 | `23-28-...:435-462,570-602,659-820` ; `profile_screen.dart`, `notification_preferences_screen.dart`, `delete_account_screen.dart` | **No drift.** SCR-26 Profile, SCR-27 toggles (optimistic-revert/offline/OS-banner), SCR-28 body all match exactly. | — | Accept | — |

Cross-cutting PASS: Invariant 1 (money) compliant — `formatInrFromPaise` is the sole
paise→INR path; no `toDouble`/`/100`/`*100`/`toStringAsFixed` on money. Invariant 2
honoured — settlement/history code reads but never writes `simplifiedBalances`.

---

## 1.2 Firestore Schema vs Implementation

| ID | Location (file:line) | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| F1 | `activity_event_type.dart:6-8`; `activity_feed_item.dart:9`; `triggers/on-expense-write/payload-builder.ts:24-25`; `expenses/data/receipt_storage_service.dart:25` | **Stale schema cross-references in code comments.** Four comments cite removed/relocated schema content: cite "line 202" and a removed `'group_change'` activity type (schema `:245` now has `'reminder'`); cite "lines 194-211"/"298-313" for activity/receipt sections now at `:237-258`/`:332-340`. Emitted `type` set matches schema; only comments lag. | Low | Backlog (refresh comment line ranges; drop `group_change`) | Flutter/Functions Dev |
| F2 | `firestore-schema.md:218`; `extension-points-register.md:46`; `firestore.rules:446`; `settlement_doc.dart:181` | `verificationStatus` "client-read-only" nuance: client writes the locked `'unverified'` once at create, read-only only on update. Phrasing consistent across schema/register/rules. | Low | Accept (internally consistent; matches rules) | — |
| F3 | `settlement_doc.dart:171-185`; `expense_doc.dart:114-137`; `friendship_repository.dart:169-173`; `firestore.indexes.json` | **No field-level drift.** Every written field appears in schema and vice versa; `simplifiedBalances` never client-written (Invariant 2 preserved); all 3 composite indexes' fields exist; extension-points register consistent. | — | None | — |

---

## 1.3 Cloud Functions Catalogue / Error Codes vs Implementation

`index.ts` exports seven functions: `healthcheck`, `recomputeSimplifiedBalances`,
`lookupUserByPhoneNumber`, `sendReminderNotification`, `deleteUserAccount`,
`onExpenseWriteFriendship`, `onSettlementWrite`. Error-codes doc verified accurate for
all six business functions; trigger types and `asia-south1` regions match.

| ID | Location (file:line) | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| C1 | `cloud-functions-catalogue.md:9,24,680-685,718-728,797` vs `index.ts:54` + `cloud-functions-error-codes.md:108-120` | **Shipped `deleteUserAccount` absent from the catalogue (VERIFIED), and contradicts the error-codes doc.** Catalogue says it covers "the six" (seven exported), has no TOC/body/Appendix-A/B row for `deleteUserAccount`, and actively lists FR-AU-09 / `onUserDelete` as "deferred — not implemented" (`:683`, Appendix C `:797`) — yet `deleteUserAccount` shipped (HTTPS callable, `asia-south1`, UNAUTHENTICATED/REAUTH_REQUIRED/INTERNAL) and IS documented in error-codes §2.6. The two CF docs contradict each other. | **High** | **Fix now** — add a `deleteUserAccount` section + Appendix A/B rows; remove FR-AU-09 from the Deferred/Appendix-C "not implemented" lines; correct "six"→"seven". | Architect |
| C2 | `cloud-functions-catalogue.md:469` vs `send-reminder-notification/index.ts:11,33` | §5 prose calls the reminder trigger `functions.https.onCall` (v1); code is v2 `onCall` from `firebase-functions/v2/https`. Every other section + Appendix A say "HTTPS Callable (`onCall`)". | Low | Fix now (cheap consistency fix) | Architect |

Correctly handled (not drift): `onExpenseWriteGroup`/`acceptGroupInvite`/
`revokeGroupInvite` carry proper "deferred" markers (Sprint-3 scope).

---

## 1.4 State-Management Doc vs Real Riverpod Provider Tree

| ID | Location (file:line) | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| M1 | `state-management.md:29-30,477` vs `home/application/home_balances_providers.dart:36,68`, `monthly_spend_breakdown_provider.dart:15,47` | Doc intro + traceability declare Home Dashboard unbuilt ("no client code", FR-HD-01..03 "not implemented"); there is no §2.x Home section. Shipped: `overallNetBalanceProvider`, `topBalancesProvider`, `monthlySpendBreakdownProvider`, `homeClockProvider`, `home_telemetry.dart`. | Medium | Fix now (add §2.x Home table; correct intro + traceability) | Architect |
| M2 | `state-management.md:87-88,104,291-303` vs `core/providers/firebase_providers.dart:15,22`, `phone_auth_provider.dart:13` | Firebase DI providers relocated to `lib/core/providers/` (Sprint-1 M4 done in code) but doc still cites `features/auth/...` and §4 explicitly states core providers are "not collected in a single `core/providers/` file" — self-contradictory. | Medium | Fix now (update §2.1/§2.2/§4 to `core/providers/`; delete "not collected" claim) | Architect |
| M3 | `state-management.md:189-197` vs `profile/application/` | Profile §2.8 omits 4 shipped providers: `changePhoneControllerProvider`, `contactSupportControllerProvider`, `deleteAccountControllerProvider`, `friendCountProvider`. | Medium | Fix now (add the 4 providers w/ FR refs) | Architect |
| M4 | `state-management.md:195,469` vs `change_phone_controller.dart:14-31,399` | Doc explicitly claims FR-PR-02 change-phone "is not implemented" (twice); the full re-verification state machine + `changePhoneControllerProvider` ship. | Medium | Fix now (remove "not implemented"; map FR-PR-02) | Architect |
| M5 | `state-management.md` (no section); `main.dart:177`, `friends_list_provider.dart:61`, `home_balances_providers.dart:41,92` | The scoped-provider `dependencies:` rule (the FR-HD/FR-FR trap) is undocumented though shipped code relies on it pervasively (`currentUserIdProvider` overridden in `ProviderScope`; 7 providers declare `dependencies:`). | Medium | Fix now (add "Scoped overrides & dependencies" subsection codifying the rule) | Architect |
| M6 | `state-management.md:94` vs `core/remote_config/remote_config_service.dart:61`, `main.dart:125` | Doc's "There is no `remoteConfigProvider`" is stale: `remoteConfigServiceProvider` exists, is overridden in `main.dart`, consumed by Contact Support. | Low | Backlog (correct the sentence) | Architect |
| M7 | `lib/features/{home,friends,activity,profile}/application/*` | **No drift — scoped `dependencies:` all correct.** Providers watching a scoped provider declare the right DIRECT dependency (`friendsListProvider`/`activityFeedProvider`/`contactSupportControllerProvider`→`[currentUserIdProvider]`; balances + `friendCountProvider`→`[friendsListProvider]`, NOT the transitive root). | — | None (record compliance) | — |

---

## 1.5 Telemetry Plan vs Implementation

| ID | Location (file:line) | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| T1 | `home_dashboard_screen.dart:211`, `add_expense_controller.dart:1317` vs `telemetry-plan.md:284,294-296` | **Raw `amount_paise` emitted where the plan mandates bucketed `amount_range` (VERIFIED).** `home_settle_up_tapped` sends `amount_paise: item.netBalancePaise.abs()`; `expense_delete_confirmed` sends `amount_paise: draft.amountPaise`. Plan §2.1: "Raw `amount_paise`…must never appear" and lists both events; §3 calls it a "blocking defect". | **High** | **Fix now** — replace with `amountRangeFor(...)` (helper exists), OR PM/Architect ratify a documented carve-out. | Flutter Dev |
| T2 | `otp_entry_controller.dart:132-135` vs `telemetry-plan.md:67,323` | **`otp_screen_viewed` leaks a phone-derived reversible hash (VERIFIED).** Fires `phone_hash = sha256(phoneNumber)` (full 64-hex of a 10-digit number → brute-forceable = effectively the phone number). Plan §1.2 defines the event parameter-free; §3 "no phone numbers" is non-negotiable. Bypasses the 16-hex truncating `hashId` helper. | **High** | **Fix now** — remove `phone_hash` (event needs no params), or route through privacy review; never emit a phone-derived value. | Flutter Dev |
| T3 | `activity_feed_screen.dart:181,255-264` vs `telemetry-plan.md:229,307` | `activity_item_tapped.entity_id` undocumented + breaks hash-naming: settlement branch carries `hashFriendshipId(...)` but with no `_hash` suffix (violates ADR-0013/§2.2); expense branch carries the RAW `expenseId` (opaque, not UID-composite, but inconsistent with `expense_id_hash` used elsewhere). | Medium | Fix now (rename `entity_id_hash`, hash both branches, document param) | Flutter Dev |
| T4 | `match_and_invite_controller.dart:205` vs `telemetry-plan.md:42` | Core-funnel `friend_added` missing its `method` param (`contacts`/`manual`/`invite`); SRS-5.10 acquisition funnel cannot be segmented. (Note: this call site is currently unreachable per S6.) | Medium | Fix now (pass `method`) — coordinate with S6 wiring | Flutter Dev |
| T5 | `friend_detail_screen.dart:181-183` vs `telemetry-plan.md:142` | `friend_detail_viewed` param mismatch: plan = `balance_state` (`owed`/`owes`/`settled`); code emits `friendship_id_hash`. Documented dimension never produced; emitted (PII-safe) one undocumented. | Medium | Fix now (reconcile: emit `balance_state`, or update plan) | Flutter Dev / Architect |
| T6 | `telemetry-plan.md:131-149` vs `friends/{application,presentation}/*` | Friends catalogue §1.4 diverged both directions: ~15 shipped events absent from plan (`friend_lookup_matched/unmatched/failed/rate_limited`, `friend_add_blocked_self/duplicate`, `friend_invite_share_sheet_opened`, `add_friend_screen_viewed`, `friend_contact_picker_opened/search_used/selected`, `add_friend_tab_switched`, `friend_manual_entry_opened/validation_failed/submitted`); plan-side names never fired (`friends_search_used`, `friend_invite_sent`, `friend_search_started`, `contact_permission_granted/denied`). `friend_delete_*` = FR-FR-05 (not built → Sprint-3). | Medium | Fix now (rewrite §1.4 to shipped taxonomy; mark `friend_delete_*` deferred) | Architect |
| T7 | `telemetry-plan.md` (none) vs `reminders/application/reminder_telemetry.dart:21-48` | Reminder family (7 events) absent from plan catalogue: `reminder_send_tapped/succeeded/rate_limited/recipient_prefs_disabled/recipient_no_tokens/recipient_doesnt_owe/failed`. (Code hashes `friendship_id_hash` correctly — PII-safe.) | Medium | Fix now (add §1.x Send Reminder table mirroring code) | Architect |
| T8 | `notifications/*` vs `telemetry-plan.md:266,268-269` | Notifications/permissions/deep-link diverged: code fires `fcm_token_registered`, `fcm_permission_prompt_shown`, `fcm_notification_tapped` (none catalogued); planned `notification_permission_granted/denied` + `deep_link_opened` never fire. All `fcm_*` PII-safe. | Medium | Fix now (catalogue `fcm_*`; reconcile planned names) | Architect |
| T9 | `telemetry-plan.md:24-26` vs `delete_account_controller.dart:139,158,169,276,331,341,346` | Plan status note wrongly says account deletion "unimplemented / no producer (SCR-28)"; full SCR-28 family fires and §1.7 already catalogues it. Parallels M4/S16. | Medium | Fix now (correct status note) | Architect |
| T10 | `telemetry-plan.md:39-40,109,224-225` vs settlement/home/expense call sites | Plan omits several PII-safe params present in code (`context_id_hash`, `friendship_id_hash`, `settlement_id_hash`, `receipt_size_bytes`) and the undocumented event `settle_up_validation_failed`. All PII-safe. | Low | Backlog (add hashed params + event to plan) | Architect |
| T11 | `telemetry-plan.md:125,206` vs `expense_telemetry.dart:65-67` | `expense_save_failed` internally inconsistent in plan: §1.3 = `error_type`+`is_offline`; §1.6 = `error_code`+`retry_count`. Code matches §1.3 only. | Low | Backlog (de-dupe to shipped contract) | Architect |
| T12 | `telemetry-plan.md:53-56,134,246` | Minor planned events with no producer (built flows): `support_email_copied`, `friends_search_used`, `splash_auth_check_started/completed/failed`, `splash_retry_tapped`. (Distinct from genuine future scope: `onboarding_*`, Groups, Search, `dark_mode_toggled`.) | Low | Backlog (instrument on next touch, or mark deferred) | Flutter Dev |
| T13 | `lib/**` (PII hashing verification) | **No drift — mandatory ID hashing compliant.** Every `friendshipId`/UID-composite reaching telemetry is hashed via `hashFriendshipId()`; opaque ids via `hashId()`. No raw friendship-composite leaks. Only exceptions are T2 + T3 (tracked separately). | — | None (record compliance) | — |

---

## 1.6 Architecture Decision Records

ADR-0017–0020 decision text verified accurate against shipped code: ADR-0017 →
`fl_chart ^1.2.0` + home spend-breakdown widgets; ADR-0018 → `notification_deep_links`
`homeTabIndex` + `deep_link_handler`; ADR-0019 → `app_settings ^7.0.0` +
`AppSettingsService`; ADR-0020 → `shared_preferences ^2.5.5` + `KeyValueStore` +
`PreferenceKeys`. Sprint-1 ADR-0009/0010/0011 back-ports exist.

| ID | Location (file:line) | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| A1 | `triggers/on-expense-write/index.ts`, `on-settlement-write/index.ts`, `simplified-debts/function.ts` (`recomputeAndWrite`); no ADR | **Missing ADR: simplified-debts trigger architecture.** Sprint 2 shipped a shared `recomputeAndWrite` core invoked by three entry points (callable + two `onDocumentWritten`, `retry:true`), with a 7-day stale-event guard, monotonic `lastActivityAt`, and contained (logged, never rethrown) activity/FCM side-effects. Sprint-1 C1 flagged this as "planned for Sprint 2"; shipped without an ADR. | Medium | Fix now (write ADR-0021 ratifying trigger-vs-callable shared-core, retry/stale-guard, side-effect containment) | Architect |
| A2 | `extension-points-register.md:30,189` vs `decision-log.md:1093` | Register cites **ADR-0017** for "localisation infrastructure / `.arb`", but ADR-0017 is the charting decision; no localisation ADR exists. A reader is misrouted. | Medium | Fix now (remove/correct the ADR-0017 localisation reference) | Architect |
| A3 | `decision-log.md:1321,1472,1566` | ADR-0018/0019/0020 headers + bodies are indented 2 spaces (others at column 0). Renders today but is fragile and broke a `^## ADR-` scan. | Low | Backlog (de-indent to column 0) | Architect |
| A4 | `firestore.rules:282-300`; no ADR | Implicit security decision lacks an ADR: friendship-expense update/soft-delete is creator-only (#72), deliberately asymmetric to settlements' either-party soft-delete (rule comment "do not harmonise"). Captured in a CHORE story, not an ADR. | Low | Backlog (fold asymmetry into a rules ADR or extend ADR-0010) | Architect |
| A5 | `storage.rules:30-39`; no ADR | Implicit decision lacks an ADR: receipt-path authz reaches cross-collection into Firestore (`firestore.get(...).memberIds`) — first Storage rule doing so; Sprint-3 group receipts will reuse it. | Low | Backlog (optional ADR for Storage→Firestore membership pattern) | Architect |

---

## 1.7 Feature-PR-Conventions Accuracy

#75 additions verified present/correct (before/after coverage fields §6 + thresholds
table; CF PR checklist §6; Jest-config separation table §3). #77 milestone convention
reflected. Coverage thresholds consistent across conventions, PR template, coverage
tables. `sprint-2-chore` correctly deprecated in `milestone-tracking.md` and not advised
by any live convention doc.

| ID | Location (file:line) | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| P1 | `.github/PULL_REQUEST_TEMPLATE.md:27-28` vs `.github/shared/invariants.md:13-17` | **PR template Invariant-2 wording stale (single-writer).** Template: "Only the `recomputeSimplifiedBalances` Cloud Function may write it." After Sprint-2 trigger wiring, `simplifiedBalances` is written by `recomputeAndWrite` via THREE entry points (callable + `onExpenseWriteFriendship` + `onSettlementWrite`), as invariants.md/catalogue/schema state. A reviewer could wrongly flag a trigger write. | Medium | Fix now — align template Invariant-2 line to the three-writer wording. Architect supplies text; DevOps edits the template. | DevOps (text from Architect) |
| P2 | `feature-pr-conventions.md:328-344` vs `.github/PULL_REQUEST_TEMPLATE.md` | PR section taxonomy diverges: conventions §6 prescribes 12 sections (incl. References, Files Added/Modified, Manual Smoke Test, Next PR) absent from the template; template has "Screenshots/Recordings" not in conventions. Likely intentional (template = lighter scaffold) but undocumented. | Low | Backlog (note the template is a minimal subset, or align) | Architect/DevOps |
| P3 | `milestone-tracking.md:21` vs `sprint-sequence.md:29,149` | Sprint-3 theme "Groups and Settlements" partially stale: settlement recording (FR-SE-05/06) + reminders (FR-SE-09) shipped in Sprint 2. Inherited from `sprint-sequence.md` (PM-owned, authoritative); likely "Settlements" = group-context settlements. | Low | Backlog (PM to confirm theme wording) | PM |
| P4 | `feature-pr-conventions.md:112-126,346-388`; `milestone-tracking.md`; `PULL_REQUEST_TEMPLATE.md:43-63` | **Compliant.** #75 additions present/correct; #77 convention reflected; thresholds consistent; `sprint-2-chore` deprecated and not advised. | — | None | — |

---

## Summary

| Category | High | Medium | Low | Total scored | Accept/None rows |
|---|---|---|---|---|---|
| Screen specs (1.1) | 1 | 8 | 12 | 21 | 2 (S15, S23) |
| Firestore schema (1.2) | 0 | 0 | 1 | 1 | 2 (F2, F3) |
| Cloud Functions (1.3) | 1 | 0 | 1 | 2 | 0 |
| State management (1.4) | 0 | 5 | 1 | 6 | 1 (M7) |
| Telemetry (1.5) | 2 | 7 | 3 | 12 | 1 (T13) |
| Missing/stale ADRs (1.6) | 0 | 2 | 3 | 5 | 0 |
| PR conventions (1.7) | 0 | 1 | 2 | 3 | 1 (P4) |
| **Total** | **4** | **23** | **23** | **50** | **7** |

### Preliminary Triage (Phase 6 finalises)

**Fix-now candidates (HIGH + load-bearing, ~24):** S6 (unreachable add-friend — top
Bucket-A, QA triage-bug), T1 + T2 (telemetry PII — fix or ratify carve-out), C1
(`deleteUserAccount` catalogue), A1 (ADR-0021 trigger architecture), A2 (wrong ADR
cross-ref), P1 (template Invariant-2 three-writer), C2; the stale-status-note /
spec-lag cluster (S1, S2, S5, S16, S17, S19, M1, M2, M3, M4, M5, T9), and the telemetry
catalogue rewrites (T3, T4, T5, T6, T7, T8).

**Backlog candidates (~22):** S3, S4, S7, S8, S10, S11, S12, S13, S14, S18, S20, S21,
S22, F1, M6, T10, T11, T12, A3, A4, A5, P2, P3.

**Accept / no-action (7):** S15, S23, F2, F3, M7, T13, P4.

> Headline: the audit surfaced one functional defect (**S6** — the add-friend funnel is
> unreachable in the running app) and two telemetry-PII regressions (**T1, T2**). These
> three are the Bucket-A core. The Medium tier is dominated by documentation that lags
> shipped Sprint-2 code (stale "not implemented" status notes and an out-of-date
> telemetry catalogue) — low-risk to fix, high-value for Sprint-3 agents building on a
> trustworthy spec/telemetry baseline.
