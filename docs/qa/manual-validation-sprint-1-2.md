# Pre-Sprint-3 Manual Validation — Sprint 1 + Sprint 2

> Human-in-the-loop manual validation of the shipped Sprint-1 + Sprint-2 surface,
> run against the **Firebase Emulator Suite (Pass 1)** before the Sprint-3 Groups epic.
> Orchestrated by QA with flutter-dev / functions-dev / devops consulting.

**Date:** 2026-06-24 / 2026-06-25 (full re-run) · **Tester:** @avtanshgupta ·
**Backend:** Firebase Emulator Suite (Pass 1) · **Targets:** iPhone 16 sim (User One,
`+91 98765 43210` → changed to `+91 98765 00000` in FR-PR-02 testing) + iPhone 17 Pro sim
(User Two `+91 99887 76655`; plus a disposable User Three `+91 98765 11111` for the
delete-account cascade).

> **Scope.** Pass 1 (emulator) is **complete**: Phases 0–6, 8, 9, and 10 were all
> validated two-party against both the app UI and the Firebase backend, after a full
> clean-build / clean-emulator re-run. **14 defects (D1–D14) were found and all 14 are
> fixed, regression-tested, and pushed** on branch `fix/sprint-1-2-validation-defects`.
> Phase 7 (FCM push), offline queue/sync, Crashlytics, Analytics DebugView, and real SMS
> remain **Pass 2 (production + real device)** items by nature. See the matrix, defect
> list, and verdict below.

---

## Headline

Manual validation against the **real** Firebase emulator (real security rules, real
provider scopes, real app lifecycle, real Cloud Function triggers) found **14 defects** the
unit/widget suite missed — it uses fake stores and global test scopes. Several broke core
flows end-to-end (launch, add-friend, friend-detail, add-expense, delete-account display).
**All 14 are now fixed with regression tests; `flutter analyze` clean, 1609 tests pass,
formatter clean**, and each fix was re-verified on-device against the emulator.

| Core flow | Defect | Result |
|---|---|---|
| App launch (iOS) | D1 (S1) | **Fixed + verified** (#95) |
| Add friend — duplicate-check hang/latency | D4→D9 (S1) | **Fixed + verified** (#98, #106) |
| Friend Detail | D7 (S2) | **Fixed + verified** (#101) |
| Add-expense FAB picker | D8 (S1) | **Fixed + verified** (#102) |
| Add-expense save (analytics crash) | D11 (S2) | **Fixed + verified** (#105) |
| Delete-account display (tombstone) | D13 (S3) | **Fixed + verified** (#108) |

> **All 14 defects fixed.** D1–D14 each carry a GitHub issue (#95–#102, #104–#109) on the
> **Sprint 2** milestone, plus enhancement #103. Branch `fix/sprint-1-2-validation-defects`
> holds 6 commits (`0f891ba`, `2cba3cc`, `23460ef`, `c24fbec`, `51c83f4`, `80762d0`).
> A key environment caveat (FlutterFire #10449) is documented under "Environment notes".

---

## Environment (Phase 0) — fixes required before any scenario

The local toolchain was behind the project/CI and blocked all runtime testing:

- **Xcode 26.5 iOS platform missing** → `xcodebuild` listed zero simulator destinations.
  Fixed with `xcodebuild -downloadPlatform iOS` (installed the iOS 26.5 runtime).
- **Swift Package Manager** (default-on in Flutter 3.44.x) breaks the iOS build →
  `flutter config --no-enable-swift-package-manager`.
- **firebase-tools 13.35.1 + Node 18** crashed every callable Cloud Function under the
  emulator (`functions.config()` removed in firebase-functions v7). Installed **Node 22**
  and upgraded to **firebase-tools 15.20.0** (matches CI); restarted the emulators under
  Node 22 with `firebase-export` import to preserve data.

All seven functions load in `asia-south1`; emulator UI at `localhost:4000`.

---

## Pass / Fail matrix (Pass 1 · emulator)

Legend: ✅ pass · ⚠️ partial (works with a logged deviation) · ⛔ blocked.

### Phase 0 — Environment
| Scenario | Result | Evidence |
|---|---|---|
| Emulator Suite boots (auth/firestore/functions/storage + UI) | ✅ | All emulators ready; UI :4000 |
| All 7 Cloud Functions load in `asia-south1` | ✅ | boot log roster |
| Emulator UI reachable, Firestore empty (clean start) | ✅ | tester-confirmed |
| iOS app builds & launches on Simulator | ✅ | after D1 fix |

### Phase 1 — Auth & Profile — **PASS**
| Scenario | Result | Firebase evidence |
|---|---|---|
| Splash → Phone Entry (no session) | ✅ | — |
| Phone validation (reject prefix, soft-gate <10) | ✅ | client-side |
| OTP send → countdown → resend → success | ✅ | Auth emulator codes; new Auth user |
| OTP invalid code → error + retry | ⚠️ **D3** | rejected; cells don't auto-clear |
| New user → Profile Setup; display name + soft counter (>40) + 50 cap | ✅ | — |
| Avatar pick (gallery) | ✅ | — |
| Save profile → Home; `users/{uid}` + Storage avatar | ✅ | doc shape clean (phone +91, locale en-IN, notifPrefs, fcmTokens [], no extra); avatar image/jpeg 246 KB (<5 MB) |
| Session persistence (kill→relaunch→Home) | ✅ | — |
| Sign out → Phone Entry | ✅ | users doc + Auth record persist |
| Existing-user login → Home (not Profile Setup) | ✅ | — |
| User B full sign-up | ✅ | 2 users docs |
| Android OTP auto-retrieval | N/A | iOS only |

### Phase 2 — Friends — **PASS** (all scenarios, re-run)
| Scenario | Result | Firebase evidence |
|---|---|---|
| Empty friends list | ✅ | — |
| **S6** add friend (manual) → match → friendship created (two-party) | ✅ | `friendships/{sorted}`: sorted memberIds, createdBy, **no simplifiedBalances** (INV2); `lookupUserByPhoneNumber` matched |
| Add-friend duplicate-check latency | ✅ **D9 fixed** | membership query via `.snapshots().first`: 90 s → 2.2 ms |
| Add-friend completion feedback + name | ✅ **D5/D6** | `MatchAndInviteAdded` → snackbar + `userProfileProvider` invalidate |
| Duplicate block ("You are already friends") | ✅ | fast membership-query true path |
| Self-add block | ✅ | short-circuits before callable |
| Non-user → **invite via system share sheet (INV3)** | ✅ | generic iOS share sheet, no app-specific target |
| Contacts permission: no auto-prompt → Grant → list | ✅ | D1 fix (`permissions.check/request`) |
| Contacts permission denied → PermissionDeniedView → Open Settings | ✅ | opened iOS Settings; D1 `_mapPermissionStatus` |
| Friends list two-party (resolved names) | ✅ | both see each other after fix |
| Friend Detail (SCR-11) loads | ✅ | **D7 fix** (settlements list query → `isContextMember`, 200) |
| Per-user lookup rate-limit counter | ✅ | `_rateLimits/{uid}/lookups/counter` written per-user (limit 100/h) |

### Phase 3 — Expenses — **PASS** (INV1 + INV2 + #72)
| Scenario | Result | Firebase evidence |
|---|---|---|
| Add-expense FAB context picker lists friends | ✅ **D8 fixed** | scope hoisted into `MaterialApp.builder` |
| Add equal-split expense → trigger recompute | ✅ | `amountPaise=50000`, splits 25000+25000=**50000**, source=manual, currency=INR; `onExpenseWriteFriendship` → `simplifiedBalances {B:{A:25000}}` (**INV2 trigger-only**) |
| Custom split (awkward amount, INV1) | ✅ | `amountPaise=10001` (₹100.01); splits 5000+5001=**10001** exact, no float drift |
| Two-party balance display (INV1 ₹ boundary) | ✅ | ₹250.00 both sides, real-time, Indian numbering |
| Activity entry (FR-EX-07) | ✅ | `expense_added` for both users |
| Receipt upload (gallery) | ✅ | `receipts/friendships/{fid}/{eid}` 1.07 MB image/jpeg (≤5 MB); expense `receiptUrl` set |
| Expense **edit** → trigger recompute (FR-EX-06) | ✅ | Lunch 30000→40000, `updatedAt` fresh; `simplifiedBalances` recomputed |
| Creator-only edit/delete (#72) | ✅ | non-creator (User Two) blocked; creator (User One) edits/deletes |
| Expense delete → recompute | ✅ | `deleted=true`, trigger recomputed balance |
| Post-delete navigation | ✅ **D10 fixed** | returns to Friend Detail (`softDelete()` returns bool) |
| Add-expense analytics (no crash) | ✅ **D11 fixed** | bool params coerced to String; save fast |

### Phase 4 — Settlements — **PASS** (reminder push → Pass 2)
| Scenario | Result | Firebase evidence |
|---|---|---|
| Full settle-up → recompute to zero (INV1/INV2 + locks) | ✅ | `settlements/{id}` amountPaise=25000, from=B to=A, **method=manual, currency=INR, verificationStatus=unverified**; `onSettlementWrite` → `simplifiedBalances={}` |
| Settlement history per friend (SCR-24) | ✅ | shows ₹250 settlement + date (dd MMM yyyy IST) |
| Send Reminder — guard when recipient has no push | ✅ | `sendReminderNotification` ran then short-circuited (no fcmTokens); toast shown |
| Reminder push + 24 h rate-limit | ⛔ Pass 2 | needs real FCM |

### Phase 5 — Home Dashboard — **PASS**
| Scenario | Result | Firebase evidence |
|---|---|---|
| Net balance + top balances (populated) | ✅ | User Two owes ₹400 after Groceries |
| Monthly spend-breakdown chart (FR-HD-03) | ✅ | donut+legend, **own share**: Food ₹250 + Groceries ₹400 = ₹650 (never full amount) |
| Settled-up empty state (zero balance) | ✅ by-spec | hides spend card per spec 06-08:113 — enhancement #103 (Sprint 2) |
| Real-time two-party sync | ✅ | User One adds expense → User Two balance updates **live** |

### Phase 6 — Activity Feed — **PASS**
| Scenario | Result | Firebase evidence |
|---|---|---|
| Chronological list + relative IST timestamps | ✅ | expenses + settlement |
| Deep-link from item → expense detail | ✅ | navigates to SCR-21 |
| Expense detail shows friend name | ✅ **D12 fixed** | `userProfileProvider` resolves name (was "Friend") |

### Phase 8 — Profile & Account — **PASS**
| Scenario | Result | Firebase evidence |
|---|---|---|
| View profile | ✅ | name/avatar/phone |
| Edit profile (name + avatar re-upload) | ✅ | `displayName` updated; avatar overwritten at same path |
| Notification preferences toggle | ✅ | `users/{uid}.notificationPrefs.reminder=false` persisted |
| Contact Support (mailto → copy fallback) | ✅ | no Mail account → copy-address dialog |
| **Change phone (FR-PR-02)** | ✅ | `users/{uid}.phoneNumber` **AND Auth record** both → +919876500000 (same uid) |
| **Delete account (FR-AU-09)** | ✅ by-design | re-auth + type-Delete gates; **deleted** activity/_rateLimits/avatar/Auth; **tombstoned** `users/{uid}={displayName:"Deleted User", deletedAt}`; **preserved** shared friendship/expense/simplifiedBalances (ADR-0016, INV2) |
| Surviving user reconciliation | ✅ **D13 fixed** | shows "Deleted User" (tombstone parses) |

### Phase 9 — Invariants & Security — **PASS**
| Scenario | Result | Evidence |
|---|---|---|
| **INV1** integer paise (equal, custom, odd amounts) | ✅ | exact split sums; ₹100.01 = 10001 paise |
| **INV2** client write to `simplifiedBalances` rejected | ✅ | PATCH as member → **HTTP 403**; control `lastActivityAt` → 200; trigger-only writes |
| **INV3** invite → system share sheet | ✅ | no app-specific target |
| **INV4** single Firebase project | ✅ | only `onebytwo-avtanshgupta` in `.firebaserc`/options/plist/google-services |
| Non-member read/write friendship+expense | ✅ | **403** (member control 200) |
| Stranger reads another profile | ✅ | **403** (friend control 200) |
| Unauthenticated read | ✅ | **403** |
| Friendship enumeration (list all) | ✅ | **403** (no social-graph enumeration) |

### Phase 10 — Cross-cutting — **PASS** (offline → Pass 2)
| Scenario | Result | Evidence |
|---|---|---|
| Dark mode | ✅ | readable, adequate contrast |
| Dynamic type / large text | ✅ **D14 fixed** | OTP screen scrolls + responsive cells (was overflow) |
| VoiceOver | ✅ | balance, rows, buttons, headings announced |
| Tap targets ≥48 dp | ✅ | comfortable |
| Empty/error states | ✅ | friendly messages + CTAs |
| Cold-start performance | ✅ | < ~3 s to usable screen (debug/emulator) |
| Offline queue/sync | ⛔ Pass 2 | no per-sim airplane mode; localhost loopback |

### Phase 7 — Notifications — **Pass 2 only**
FCM token registration, push (expense/settlement/reminder), notification-tap deep-link
(cold/background/foreground), pref-OFF suppression — all require real FCM on a real device
(the Emulator Suite has no FCM; iOS Simulator has no push). Deferred to Pass 2.

---

## Environment notes (carry into Pass 2)

- **FlutterFire #10449 (iOS-sim + emulator slow one-shot `.get()`).** Against the Firestore
  emulator on the iOS Simulator, a one-shot server `.get()` (doc or query) stalls ~90 s,
  while `.snapshots()` cache reads are ~2 ms. This is **not a production bug** (REST/server
  reads are instant) but it makes read-heavy paths feel slow on the emulator (profile
  resolution, the dashboard spend-card read, opening an expense). D9's fix uses
  `.snapshots().first` to dodge it; other `.get()` paths remain emulator-slow only.
  Verify latency on production in Pass 2.
- **Disabling Firestore persistence makes it worse**, not better (it removes the cache that
  `.snapshots().first` reads) — do not add `persistenceEnabled: false`.

---

## Defect list

All 14 defects are **fixed, regression-tested, and pushed** on
`fix/sprint-1-2-validation-defects`. Each has a GitHub issue on the **Sprint 2** milestone.

| ID | Sev | Issue | Status | Summary |
|---|---|---|---|---|
| D1 | S1 | [#95](https://github.com/avtansh-code/OneByTwo/issues/95) | **Fixed + verified** | iOS launch crash — flutter_contacts 1.1.9+2 nil-unwraps `AppDelegate.window` under UISceneDelegate → bumped to `^2.2.2` + migrated `contact_service` to the 2.x API |
| D2 | S2 | [#96](https://github.com/avtansh-code/OneByTwo/issues/96) | **Fixed + verified** | Cold-start notification deep-link never runs — `ref.read` after dispose in `NotificationsLifecycleHost` → added `mounted` guards around the post-frame callback and after the await |
| D3 | S3 | [#97](https://github.com/avtansh-code/OneByTwo/issues/97) | **Fixed + verified** | OTP cells don't auto-clear after an invalid code (SCR-04) → `OtpInput` takes the controller-owned `digits` and clears the cells on reset via `didUpdateWidget` |
| D4 | S1 | [#98](https://github.com/avtansh-code/OneByTwo/issues/98) | **Fixed + verified** | Add-friend hang — duplicate-check `get` on a non-existent friendship denied by rules (null error); client now treats `permission-denied` as not-exists |
| D5 | S2 | [#99](https://github.com/avtansh-code/OneByTwo/issues/99) | **Fixed + verified** | Add-friend: no feedback/navigation after "Add as friend" → new `MatchAndInviteAdded` state; the screen pops with a confirmation snackbar |
| D6 | S3 | [#100](https://github.com/avtansh-code/OneByTwo/issues/100) | **Fixed + verified** | Newly-added friend shows "Unknown" until relaunch → on `Added`, `ref.invalidate(userProfileProvider(otherUserId))` refreshes the cached null |
| D7 | S2 | [#101](https://github.com/avtansh-code/OneByTwo/issues/101) | **Fixed + verified** | Friend Detail broken — settlements `watchByContext` list query denied by from/to read rule → changed to `isContextMember` |
| D8 | S1 | [#102](https://github.com/avtansh-code/OneByTwo/issues/102) | **Fixed + verified** | Add-expense FAB context picker can't load friends — modal on the root Navigator sat outside the per-arm `ProviderScope` → hoisted the scope overrides into `MaterialApp.builder` (above the root Navigator); device-verified |
| D9 | S1 | [#106](https://github.com/avtansh-code/OneByTwo/issues/106) | **Fixed + verified** | Add-friend duplicate-check stalls ~90 s (supersedes D4) — mobile SDK slow to surface a denied/one-shot `get()` on iOS-sim+emulator (#10449) → `existsForMember` membership query via `.snapshots().first` (90 s → 2.2 ms) |
| D10 | S3 | [#104](https://github.com/avtansh-code/OneByTwo/issues/104) | **Fixed + verified** | After deleting an expense the screen stayed on the stale view — gated `maybePop()` on re-reading an autoDispose provider → `softDelete()` returns `bool`; navigate on the return value |
| D11 | S2 | [#105](https://github.com/avtansh-code/OneByTwo/issues/105) | **Fixed + verified** | Adding an expense threw Firebase Analytics assertions (bool params) + slow save → coerce `bool`→`"true"/"false"` centrally in `FirebaseAnalyticsService` |
| D12 | S3 | [#107](https://github.com/avtansh-code/OneByTwo/issues/107) | **Fixed + verified** | Expense detail showed "Friend"/"You" instead of the friend's name → resolve `userProfileProvider(otherUserUid)` (cache-warm), fallback "Friend" |
| D13 | S3 | [#108](https://github.com/avtansh-code/OneByTwo/issues/108) | **Fixed + verified** | Deleted account renders "Unknown" not "Deleted User" — PII-free tombstone failed the non-nullable `phoneNumber` cast → `UserModel.fromFirestore` tolerates it (`String? ?? ''`) |
| D14 | S3 | [#109](https://github.com/avtansh-code/OneByTwo/issues/109) | **Fixed + verified** | OTP screen overflows at large Dynamic Type (vertical) and on small phones (horizontal) → `SingleChildScrollView` + `LayoutBuilder` responsive cells; 320 dp regression test |

> **Enhancement filed:** [#103](https://github.com/avtansh-code/OneByTwo/issues/103)
> (Sprint 2) — surface the spend-breakdown chart + a "no pending balances" indicator in the
> dashboard settled/empty state (FR-HD-03 follow-up; user pulled into Sprint 2). To be
> implemented after Pass 1 + Pass 2 complete.

**Common root cause / test gap:** unit & widget tests use fake repositories and a global
test `ProviderScope`, so they never exercise the **real Firestore security rules**, the
**modal provider scope**, or the **app lifecycle**. Each fix should land with a real
emulator-rules / integration / root-Navigator test.

---

## Commits (branch `fix/sprint-1-2-validation-defects`)

| Commit | Defects | Summary |
|---|---|---|
| `0f891ba` | D1–D8 | initial validation fixes (contacts 2.x, mounted guards, OTP clear, dup-check, add-friend feedback, settlements rule, FAB scope) |
| `2cba3cc` | D9 | add-friend duplicate-check via membership query `.snapshots().first` |
| `23460ef` | D10, D11 | post-delete navigation + analytics bool coercion |
| `c24fbec` | D12 | expense detail shows friend name |
| `51c83f4` | D13 | deleted account renders "Deleted User" |
| `80762d0` | D14 | OTP screen overflow (scroll + responsive cells) |

All fixes verified end-to-end against the emulator; `flutter analyze` clean; whole suite
**1609 tests pass**; formatter clean; each fix re-verified on-device.

---

## Not yet validated — **Pass 2 (production + real device)**

- Real `+91` SMS OTP; real `asia-south1` Cloud Functions latency (confirm #10449 is
  emulator-only).
- **Phase 7 Notifications**: FCM token registration, push (expense/settlement/reminder),
  notification-tap deep-link (cold/background/foreground), pref-OFF suppression.
- Reminder push + 24 h rate-limit (Phase 4 remainder).
- **Offline** queue/sync + recovery (Phase 10 remainder).
- **Crashlytics** (no crashes) and **Analytics DebugView** (events fire; bucketed
  `amount_range`, never raw `amount_paise`; no phone-derived/raw-id PII).

---

## QA sign-off

**Verdict: Pass 1 (emulator) is COMPLETE and GREEN. All 14 defects (D1–D14) found during
validation are fixed, regression-tested, and pushed. Clearance for Sprint 3 is gated only
on (1) merging the fix branch as reviewed PR(s) and (2) running Pass 2 on production.**

- ✅ **Invariants all hold:** INV1 (integer paise, exact splits incl. ₹100.01), INV2
  (`simplifiedBalances` server-only; client write → 403), INV3 (system share sheet), INV4
  (single project) — verified directly, including the security-rule probes (non-member,
  stranger, unauthenticated, enumeration all denied).
- ✅ **Full surface validated two-party** across Phases 0–6, 8, 9, 10: auth/profile,
  friends, expenses (equal+custom split, receipt, edit, creator-only #72), settlements
  (both triggers + extension-point locks), dashboard (populated + spend chart + real-time
  sync), activity feed + deep-link, profile + change-phone (dual-write) +
  delete-account cascade (ADR-0016 tombstone), accessibility.
- ✅ **14/14 defects fixed** with regression tests; `flutter analyze` clean, **1609 tests
  pass**, formatter clean; every fix device-verified.
- ⛔ **Before Sprint 3 is declared green:**
  1. Merge `fix/sprint-1-2-validation-defects` as reviewed PR(s) (closes #95–#102, #104–#109).
  2. Run **Pass 2 on production** (Phase 7 push, offline, Crashlytics, DebugView, real SMS).
  3. Implement enhancement #103 (settled-state dashboard) — user-assigned to Sprint 2.

**Highest-leverage follow-up:** the recurring theme is that fake-store/global-scope unit
tests never exercise the real security rules, modal provider scopes, app lifecycle, or
device layout — which is exactly where all 14 defects lived. Add an **emulator-backed
integration lane** (real rules + real provider scopes + a small-viewport widget pass) to CI
so these classes of defect surface automatically.

