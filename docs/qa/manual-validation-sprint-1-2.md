# Pre-Sprint-3 Manual Validation — Sprint 1 + Sprint 2

> Human-in-the-loop manual validation of the shipped Sprint-1 + Sprint-2 surface,
> run against the **Firebase Emulator Suite (Pass 1)** before the Sprint-3 Groups epic.
> Orchestrated by QA with flutter-dev / functions-dev / devops consulting.

**Date:** 2026-06-24 · **Tester:** @avtanshgupta · **Backend:** emulator (Pass 1) ·
**Targets:** iPhone 16 sim (iOS 18.6, User One `+91 98765 43210`) + iPhone 17 Pro sim
(iOS 26.0, User Two `+91 99887 76655`).

> **Scope note.** This pass covered Phase 0 (environment), Phase 1 (Auth & Profile),
> Phase 2 (Friends), and the core of Phase 3 (Expenses: INV1/INV2). **Pass 2 (production)
> and Phases 4–10 were not reached** — the session uncovered and fixed several blocking
> defects first. See "Not yet validated" and "Verdict" below.

---

## Headline

Manual validation found that **four core flows were each broken end-to-end** by defects
that the unit/widget tests miss (they use **fake stores / global test scopes** and never
exercise the real security rules, provider scopes, or app lifecycle). All four — and every
other defect found this session — are now fixed and verified (D8 also device-verified).

| Core flow | Defect | Result |
|---|---|---|
| App launch (iOS) | D1 (S1) | **Fixed + verified** (#95) |
| Add friend | D4 (S1) | **Fixed + verified** (#98) |
| Friend Detail | D7 (S2) | **Fixed + verified** (#101) |
| Add expense (FAB picker) | D8 (S1) | **Fixed + verified** (#102) |

> **Update — all 8 defects fixed.** Following the validation, every open defect (D2, D3,
> D5, D6, D8) was fixed with regression tests. Whole repo: `flutter analyze` clean,
> **1601 tests pass**, formatter clean; D8 also re-verified on device (the picker lists all
> friends, including ones with no expense). Changes are in the working tree pending PR(s).

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

### Phase 2 — Friends — **PASS** (core), with open UX defects
| Scenario | Result | Firebase evidence |
|---|---|---|
| Empty friends list | ✅ | — |
| **S6** add friend (manual) → match → friendship created (two-party) | ⚠️ **D4 fixed; D5/D6 open** | `friendships/{sorted}`: sorted memberIds, createdBy, **no simplifiedBalances** (INV2); `lookupUserByPhoneNumber` matched (246 ms) |
| Duplicate block ("You are already friends") | ✅ | existing-friendship read allowed → true |
| Self-add block | ✅ | short-circuits before callable |
| Non-user → **invite via system share sheet (INV3)** | ✅ | generic iOS share sheet, no app-specific target |
| Contacts permission: no auto-prompt → Grant → list | ✅ | D1 fix (`permissions.check/request`) |
| Contacts permission denied → Open Settings | ✅ | D1 `deniedPermanently` mapping |
| Friend Detail (SCR-11) loads | ✅ | after **D7 fix** (settlements list query 200) |

### Phase 3 — Expenses — **core PASS** (INV1 + INV2)
| Scenario | Result | Firebase evidence |
|---|---|---|
| Add equal-split expense → trigger recompute | ✅ | `amountPaise=50000`, splits 25000+25000=**exactly 50000**, source=manual, currency=INR; `onExpenseWriteFriendship` fired (259 ms) → `simplifiedBalances {B:{A:25000}}` (**INV2 trigger-only**) |
| Two-party balance display (INV1 ₹ boundary) | ✅ | ₹250.00 — A owed / B owes, real-time both sides, Indian numbering |
| Activity entry (FR-EX-07) | ✅ | `expense_added` for both users |
| Custom split / receipt attach / creator-only edit-delete | **not validated** | — |

---

## Defect list

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

**Common root cause / test gap:** unit & widget tests use fake repositories and a global
test `ProviderScope`, so they never exercise the **real Firestore security rules**, the
**modal provider scope**, or the **app lifecycle**. Each fix should land with a real
emulator-rules / integration / root-Navigator test.

---

## In-session code changes (working tree — need PR + review)

| File | Defect |
|---|---|
| `pubspec.yaml`, `pubspec.lock`, `ios/Podfile.lock` | D1 (flutter_contacts `^2.2.2`) |
| `lib/features/friends/data/contact_service.dart` | D1 (2.x API migration) |
| `lib/features/friends/data/friendship_repository.dart` | D4 (permission-denied → not-exists) |
| `firestore.rules` | D7 (settlements read → `isContextMember`) |
| `lib/features/notifications/presentation/notifications_lifecycle_host.dart` | D2 (`mounted` guards) |
| `lib/features/auth/presentation/widgets/otp_input.dart`, `otp_entry_screen.dart` | D3 (controller-owned digits + clear on reset) |
| `lib/features/friends/application/match_and_invite_controller.dart`, `presentation/match_and_invite_screen.dart` | D5 + D6 (`Added` state → pop + snackbar + profile invalidate) |
| `lib/main.dart` | D8 (scope overrides hoisted into `MaterialApp.builder`) |
| `test/features/auth/otp_input_test.dart`, `test/features/friends/match_and_invite_controller_test.dart`, `test/features/shell/root_navigator_scope_test.dart` | D3 / D5 / D8 regression tests |

All eight fixes verified end-to-end against the emulator; `flutter analyze` clean; whole
suite **1601 tests pass**; formatter clean; D8 additionally re-verified on device.

---

## Not yet validated (out of this session)

- **Pass 2 — production**: real `+91` SMS OTP, real `asia-south1` functions, real FCM push,
  Crashlytics, Analytics DebugView (incl. telemetry PII / bucketed `amount_range`).
- **Phase 3 remainder**: custom split (INV1 exact sum), receipt attach (Storage), creator-only
  edit/delete (#72).
- **Phase 4** Settlements, **Phase 5** Home dashboard chart + cross-device sync, **Phase 6**
  Activity feed deep-links, **Phase 7** Notifications (prod), **Phase 8** Profile + delete-account
  cascade, **Phase 9** explicit invariant + security-rule probes, **Phase 10** offline / a11y /
  perf / Crashlytics.

---

## QA sign-off

**Verdict: all eight validation defects (D1–D8) are fixed and verified. Cleared for Sprint 3
once the fixes land as reviewed PRs — full Pass-2 / Phase-4–10 validation remains outstanding.**

- ✅ Validated: the integer-paise money model and the server-only `simplifiedBalances`
  recompute (**INV1 + INV2**), the system-share-sheet invariant (**INV3**), and the single
  Firebase project (**INV4**) all hold; Auth/Profile is solid; the Friends and add-expense
  surfaces work end-to-end after fixes.
- ✅ All eight defects (D1–D8, incl. the four S1 blockers — launch, add-friend, Friend Detail,
  add-expense) are fixed with regression tests; `flutter analyze` clean, **1601 tests pass**,
  formatter clean, D8 device-verified.
- ⛔ Before Sprint 3 can be declared green:
  1. Land the eight fixes as **reviewed PR(s)** (they are currently in the working tree) —
     ideally with the missing **real-rules / integration / lifecycle** coverage so these
     fake-store/test-scope regressions can't recur.
  2. Resume the validation from **Phase 3 remainder** (custom split, receipt, creator-only
     edit/delete) through **Phase 10**, and run **Pass 2 on production**.

**Recommendation:** the recurring fake-store/test-scope gap is itself the highest-leverage
fix — add an emulator-backed integration lane (real rules + real provider scopes) to CI so
these classes of defect surface automatically.
