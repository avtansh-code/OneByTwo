# Phase 4 — Dependency and Security Audit

**Date:** 2026-05-02
**Lead:** DevOps

---

## 4.1 Flutter Dependencies

### Major Version Bumps Available

| Package | Current | Latest | Type | Assessment |
|---|---|---|---|---|
| `flutter_riverpod` | 2.6.1 | 3.3.1 | **Major (2→3)** | Riverpod 3.x is a significant migration affecting all providers. Do NOT upgrade in an audit PR. Plan as Sprint 2 or Sprint 3 chore. |
| `riverpod_annotation` | 2.6.1 | 4.0.2 | **Major (2→4)** | Paired with riverpod upgrade. Same timeline. |
| `riverpod_generator` | 2.6.5 | 4.0.3 | **Major (2→4)** | Paired with riverpod upgrade. Same timeline. |
| `riverpod_lint` | 2.6.5 | 3.1.3 | **Major (2→3)** | Paired with riverpod upgrade. Same timeline. |
| `google_fonts` | 6.3.3 | 8.1.0 | **Major (6→8)** | Non-critical. Upgrade when convenient. |
| `share_plus` | 10.1.4 | 13.1.0 | **Major (10→13)** | Sprint 2 introduces sharing (friend invites). Evaluate upgrade before the first share-using PR. |
| `very_good_analysis` | 6.0.0 | 10.2.0 | **Major (6→10)** | Linter rules. May introduce new lint warnings. Upgrade as a standalone chore. |
| `build_runner` | 2.5.4 | 2.15.0 | Minor | Safe to upgrade. |

### Firebase SDK Packages

**All Firebase SDK packages are at their latest compatible versions.** No outdated
Firebase dependencies detected. No security patches pending.

### Discontinued Packages

| Package | Status | Impact |
|---|---|---|
| `build_resolvers` | Discontinued | Transitive dependency of `build_runner`. Will be resolved when `build_runner` is upgraded to 2.15.0. |
| `build_runner_core` | Discontinued | Same — transitive of `build_runner`. |

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| D1 | Riverpod ecosystem major version available (2.x → 3.x). Significant migration effort. | Medium | Backlog — plan Riverpod 3.x migration as a dedicated chore PR in Sprint 2 or 3. Do not bundle with feature work. | Flutter Dev |
| D2 | `share_plus` 10.x → 13.x available. Sprint 2 introduces sharing. | Low | Backlog — evaluate before the first friend-invite PR. | Flutter Dev |
| D3 | Firebase SDK packages are current. No security concerns. | — | None | — |
| D4 | `build_runner` 2.5.4 → 2.15.0 (minor) with discontinued transitive deps. | Low | Backlog — upgrade `build_runner` to resolve discontinued transitives. | Flutter Dev |

---

## 4.2 Cloud Functions Dependencies

### Outdated Packages

| Package | Current | Latest | Type | Assessment |
|---|---|---|---|---|
| `firebase-functions` | 6.6.0 | 7.2.5 | **Major (6→7)** | Potential breaking changes in the v2 API surface. Evaluate changelog before upgrading. Sprint 2 adds new CFs — upgrading beforehand reduces future friction. |
| `typescript` | 5.9.3 | 6.0.3 | **Major (5→6)** | Language version bump. Evaluate breaking changes. |
| `jest` | 29.7.0 | 30.3.0 | **Major (29→30)** | Testing framework. Check for breaking changes in assertions or config. |
| `@types/jest` | 29.5.14 | 30.0.0 | **Major (29→30)** | Paired with Jest upgrade. |
| `eslint` | 8.57.1 | 9.39.4 | **Major (8→9)** | Flat config migration. Significant effort. |

### Security Audit (`npm audit`)

| Severity | Count | Details |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| **Moderate** | **9** | `uuid` (buffer bounds check, <14.0.0) — affects transitive deps via `@google-cloud/storage`. `@tootallnate/once` (control flow scoping) — via `http-proxy-agent` chain. |
| Low | 2 | Part of same dependency chains. |
| **Total** | **11** | All in transitive dependencies. None in direct project code. |

**No HIGH or CRITICAL advisories.** Per Phase 0 triage rules, MODERATE advisories are
backlog.

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| D5 | `firebase-functions` 6→7 available. Sprint 2 adds new Cloud Functions — upgrading beforehand may reduce friction. | Medium | Backlog — evaluate `firebase-functions` 7.x changelog. If no breaking changes to the `onCall` API, upgrade in the first Sprint 2 CF PR. | Functions Dev |
| D6 | 11 npm vulnerabilities (0 critical, 0 high, 9 moderate, 2 low). All in transitive dependencies (`uuid`, `@tootallnate/once`). | Low | Backlog — resolve via `npm audit fix` when `firebase-admin` / `firebase-functions` are upgraded. Do not force-fix as it would install breaking changes. | DevOps |
| D7 | Jest 29→30 and TypeScript 5→6 available. | Low | Backlog — upgrade as a standalone chore when convenient. Not security-critical. | Functions Dev |

---

## 4.3 Firestore Rules Drift

### Consistency Assessment

| Aspect | Status |
|---|---|
| Cohesion | **Good.** File reads as a unified whole. Consistent naming (`isValidXXXCreate()`, `isValidXXXUpdate()`), uniform comment density, ADR references throughout. |
| Dead rules | **None.** All rule blocks correspond to SRS-defined collections (`users`, `friendships`, `groups`). Default deny at top. |
| File length | **174 lines.** Well under the 500-line threshold. No split needed. |

### Test Coverage Gaps

The `simplifiedBalances` invariant is thoroughly tested (13 test cases). However,
the create/update validation logic for friendships and groups is **untested beyond
the invariant**.

| # | Rule Path | Gap | Severity | Action | Owner |
|---|---|---|---|---|---|
| R1 | `friendships/{id}` create | `isValidFriendshipCreate()` validation untested: memberIds size (must == 2), memberIds type checks, lastActivityAt == request.time. Only the simplifiedBalances write-block is tested. | Medium | Backlog — friendships are Sprint 2 scope. Add comprehensive create validation tests when the friendship feature is built. These tests should be written before the friendship creation code is merged. | QA |
| R2 | `friendships/{id}` update | `isValidFriendshipUpdate()` validation untested: memberIds immutability enforcement. Only the simplifiedBalances write-block is tested. | Medium | Backlog — same timeline as R1. | QA |
| R3 | `friendships/{id}` delete | `allow delete: if false` — no explicit deny test. | Low | Backlog — add when friendship tests are written. | QA |
| R4 | `groups/{id}` create | `isValidGroupCreate()` validation untested: name length (1-100), type enum, adminId == auth.uid, timestamps. | Medium | Backlog — groups are Sprint 3 scope. Add when group feature is built. | QA |
| R5 | `groups/{id}` update | `isValidGroupUpdate()` validation untested: adminId change authorisation, createdAt immutability. | Medium | Backlog — same timeline as R4. | QA |
| R6 | `groups/{id}` delete | `allow delete: if false` — no explicit deny test. | Low | Backlog — add when group tests are written. | QA |

**Note:** These gaps are NOT "fix now" because the friendships and groups features
have not shipped yet. The rules were written ahead of time (PR #12) to establish the
pattern, and the simplifiedBalances invariant enforcement IS tested. The validation
logic tests should be written as part of the feature PRs that exercise these
collections (Sprint 2 for friendships, Sprint 3 for groups).

---

## 4.4 Storage Rules Drift

### Consistency Assessment

| Aspect | Status |
|---|---|
| Cohesion | **Excellent.** 21 lines, single collection (`avatars/{userId}`), clear constraints documented in comments. |
| Dead rules | **None.** |

### Test Coverage Gaps

| # | Rule | Gap | Severity | Action | Owner |
|---|---|---|---|---|---|
| R7 | `avatars/{userId}` write | **File size constraint (5 MB) untested.** Rule enforces `request.resource.size < 5 * 1024 * 1024` but no test uploads a file exceeding the limit. | Medium | Backlog — add a test case that uploads a >5 MB file and expects rejection. Non-blocking for Sprint 2 but should be added for completeness. | QA |
| R8 | `avatars/{userId}` write | **Content-type constraint untested.** Rule enforces `request.resource.contentType.matches('image/(jpeg|png)')` but no test uploads an invalid content type (e.g., BMP, GIF). | Medium | Backlog — add negative test cases for invalid content types. | QA |

---

## 4.5 Secrets and Environment

### Secrets Inventory

| Secret | Status | Needed for Sprint 2? |
|---|---|---|
| `GOOGLE_SERVICES_JSON_BASE64` | Configured | Yes (existing) |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | Configured | Yes (existing) |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Configured | Yes (existing) |
| `ANDROID_KEYSTORE_BASE64` | Configured | No (release only) |
| `ANDROID_KEYSTORE_PASSWORD` | Configured | No (release only) |
| `KEY_ALIAS` | Configured | No (release only) |
| `KEY_PASSWORD` | Configured | No (release only) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Not configured (TODO) | No (release only) |
| `MATCH_GIT_URL` | Not configured (TODO) | No (release only) |
| `MATCH_PASSWORD` | Not configured (TODO) | No (release only) |
| `APP_STORE_CONNECT_*` | Not configured (TODO) | No (release only) |

**Sprint 2 requires no new secrets.** The Friends epic uses Firestore, Cloud Functions,
and Firebase Auth — all already configured. Google Play and TestFlight secrets are
needed for release (Sprint 6) and can be configured then.

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| S1 | No new secrets needed for Sprint 2. All required Firebase credentials are configured. | — | None | — |
| S2 | Release pipeline secrets (Google Play, Fastlane, TestFlight) are TODOs. Not blocking for Sprint 2 but should be configured before Sprint 6 (release). | Low | Backlog — configure before release pipeline is exercised. | DevOps |

---

## Summary

| Category | High | Medium | Low | Total |
|---|---|---|---|---|
| Flutter deps (4.1) | 0 | 1 | 2 | 3 |
| Functions deps (4.2) | 0 | 1 | 2 | 3 |
| Firestore rules (4.3) | 0 | 4 | 2 | 6 |
| Storage rules (4.4) | 0 | 2 | 0 | 2 |
| Secrets (4.5) | 0 | 0 | 1 | 1 |
| **Total** | **0** | **8** | **7** | **15** |

### Preliminary Triage

**Fix now candidates (0):** No blocking dependency or security issues. No HIGH/CRITICAL
npm advisories. Firebase SDKs are current. Rules test gaps are for unshipped features.

**Backlog candidates (13):** D1, D2, D4, D5, D6, D7, R1-R6, R7, R8, S2.

**Accept candidates (2):** D3, S1.

### Overall Assessment

The dependency and security posture is healthy. No urgent upgrades or vulnerabilities
require immediate action. The Riverpod 3.x migration (D1) is the largest upcoming
chore and should be planned carefully. Rules test gaps (R1-R8) are real but aligned
with unshipped feature scope — they should be addressed as part of the feature PRs
that exercise those collections, not in an audit cleanup PR.
