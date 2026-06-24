# Phase 4 — Dependency and Security Audit

**Date:** 2026-06-24
**Lead:** DevOps

Method: `fvm flutter pub outdated` (pinned SDK); `npm outdated` + `npm audit`
(+ `npm audit --json` for advisory detail and a `--dry-run --package-lock-only`
fix simulation) in `functions/`; read `firestore.rules` (548 ln) and `storage.rules`
end-to-end and mapped every collection/path to its negative tests under
`functions/test/{firestore-rules,storage-rules}/`; verified `pubspec.lock` integrity,
`.firebaserc`, the workflow secret references, and the git-tracking status of the
local `secrets/` directory. Triage rule: HIGH/CRITICAL advisories fix-now, MODERATE
backlog, LOW accept.

---

## 4.1 Flutter Dependencies

`pubspec.lock` is **intact** — clean working tree, committed, `sdks:` floor
`dart >=3.12.0 <4.0.0` / `flutter >=3.44.0` matches the fvm-pinned SDK (3.44.2). No
bare-`pub get` downgrade occurred; the "use fvm" guidance held. No security advisories
surfaced for Dart/Flutter deps.

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| D4 | `pubspec.lock` (sdks floor); `git status` clean | **Lock integrity verified.** Committed lock matches the fvm SDK; no transitive/sdks-floor downgrade. | — | None (PASS) | — |
| D1 | `pubspec.yaml` direct deps vs `flutter pub outdated` "Resolvable" | **Held-back majors are exactly the deferred #22 epic.** flutter_riverpod 2.6→3.x, riverpod_annotation 2→4, share_plus 10→13, connectivity_plus 6→7, device_info_plus 12→13, flutter_contacts 1→2, google_fonts 6→8, package_info_plus 9→10, very_good_analysis 6→10, win32 5→6, xml 6→7. No security driver; staying pinned is correct. | Low | Backlog — confirm #22 (Sprint 4) owns these; do not upgrade piecemeal. | DevOps |
| D2 | Firebase Flutter plugins (cloud_firestore 6.5→6.6, firebase_* minor) | In-range minor/patch updates exist but the lock intentionally pins older; CI tests the committed lock. | Low | Accept — batch-bump at a natural Sprint-3 moment if desired. | DevOps |
| D3 | `build_resolvers`, `build_runner_core` (discontinued) | Discontinued `build_runner` transitives (Sprint-1 D4 carried forward). No replacement needed until the build_runner ecosystem migrates. | Low | Backlog — track; non-urgent. | DevOps |

---

## 4.2 Cloud Functions Dependencies

`npm audit`: **38 vulnerabilities — 4 high, 32 moderate, 2 low**, all in the single
runtime dependency `firebase-admin@^13.0.2` transitive chain
(`firebase-admin → @google-cloud/firestore → google-gax → gaxios/teeny-request → uuid`,
plus `@grpc/grpc-js`, `form-data`, `protobufjs`, `fast-xml-parser`). A non-breaking
`npm audit fix` (verified by `--dry-run --package-lock-only`) resolves **none** of them
— even the latest `firebase-admin` 13.10.0 sits inside every vulnerable range, so only
`npm audit fix --force` (breaking) or targeted `overrides` can move the transitives.

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| D5 | `functions/package-lock.json` (transitive) — `@grpc/grpc-js` (GHSA-5375-pq7m-f5r2, CVSS 7.5, DoS), `form-data` (GHSA-hmw2-7cc7-3qxx, CVSS 7.5, CRLF), `protobufjs` (GHSA-jggg-4jg4-v7c6, CVSS 5.3, DoS), `fast-xml-parser` (GHSA-5wm8-gmm8-39j9, CVSS 6.1) | **4 HIGH advisories, all transitive to `firebase-admin`; no non-breaking fix.** In a Cloud Functions backend, real exploitability is **low**: firebase-admin uses grpc-js/form-data/protobuf as a *trusted client* to Google APIs over TLS — the app runs no gRPC server, parses no attacker-controlled XML/protobuf descriptors, and the multipart field names are library-controlled. Escalation of Sprint-1 D6 (was moderate-only; new CVEs raised it to HIGH). | **High** | **Fix now (attempt)** — add targeted `overrides` for the four HIGH transitives in the cleanup PR and verify `npm ci && npm run build && npm test` stay green. If overrides destabilise the firebase-admin tree, **fall back** to a HIGH-priority tracked issue (Sprint 3) to bump `firebase-admin` when upstream ships patched transitives, accepting the in-context-low residual. | DevOps |
| D6 | `npm outdated` (firebase-admin 13.8→13.10; typescript-eslint 8.59→8.62; ts-jest, fast-check, firebase-functions-test minor) | In-range minor/patch updates available; none security-critical on their own. | Low | Backlog — bump at a natural moment (may partially help the moderate chain). | DevOps |
| D7 | `npm outdated` majors held (eslint 9, jest 30, typescript 6, @types/jest 30) | Dev-tooling majors; non-urgent, #22-adjacent. | Low | Backlog. | DevOps |

---

## 4.3 Firestore Rules Drift

`firestore.rules` is **548 lines** and reads consistently: default-deny parent;
well-factored helpers per collection; `users`, `friendships`,
`friendships/{fid}/expenses` (with the #72 creator-only update + extension-point/split
validation), `groups` (forward, Sprint 3), `_rateLimits` (client-denied), `settlements`
(context-aware friendship/group, extension-point locks), and `activity/{uid}/items`
(read-own, no client write). Negative-test coverage is strong: users (32 cases across
two files), friendships (24), expenses-friendship (44), settlements (43),
simplified-balances (13), activity (12), delete-account-denied (3).

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| R3 | `firestore.rules` (whole) + `functions/test/firestore-rules/*` | **Rules are consistent and well-tested for every *shipped* collection.** Creator-only #72, extension-point locks (`method`/`currency`/`verificationStatus`), and `simplifiedBalances` read-only are each enforced in rules and covered by negative tests. No dead/superseded rule (forward `groups` + group-receipt rules are deliberate and documented). | — | None (PASS) | — |
| R1 | `firestore.rules:1-548` | **Length now exceeds the ~500-line split threshold (548).** Still readable, but Sprint-3 groups rules (membership, roles, invite tokens, zero-balance guards) will add substantially. | Medium | Backlog (early Sprint 3) — plan a split (per-collection organisation / comment banners) before groups inflate it further. | Architect |
| R2 | `firestore.rules:325-372` (`groups/{groupId}`, `isValidGroupCreate`/`isValidGroupUpdate`) vs `functions/test/firestore-rules/` (no `groups.test.ts`) | **Forward `groups/{groupId}` rules have no negative test — an asymmetry with Storage.** The parallel forward Storage group-receipt rule *does* have tests (`receipts.test.ts`), but the Firestore groups create/update/delete rules are shipped untested (Sprint-1 R4/R5b/R6 were re-scoped to the Sprint-3 Groups epic). Until then the rules are unexercised. | Medium | Backlog (Sprint 3, first groups PR) — add `groups.test.ts` negative tests with the Create-group story; or remove the forward rules until then. Confirm the deferral is intentional. | Architect + Functions Dev |

---

## 4.4 Storage Rules Drift

`storage.rules` (61 ln): default-deny; `avatars/{userId}` (owner + <5 MB + jpeg/png);
`receipts/friendships/{fid}/{eid}` and a forward `receipts/groups/{gid}/{eid}` (member
via cross-collection `firestore.get(...).memberIds` + <10 MB + jpeg/png).

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| R5 | `functions/test/storage-rules/receipts.test.ts` (AC-14/15/16/17/18) | **Receipt R7/R8 well-covered** — oversize (>10 MB) and unsupported-MIME (text/plain, image/gif) rejections for both friendship and group paths, plus cross-collection membership read/write. | — | None (PASS) | — |
| R4 | `storage.rules:13-19` (avatar size + content-type) vs `functions/test/storage-rules/avatars.test.ts` | **Avatar size (5 MB) and content-type (jpeg/png) constraints have no negative tests.** `avatars.test.ts` only exercises auth/owner/read with a valid PNG; there is no oversize and no non-image rejection. The Sprint-1 R7/R8 closure (#48) covered *receipts* but left the *avatar* constraints untested, so the avatar size/MIME rule could regress undetected. | Medium | Fix now (cheap) — add avatar oversize (>5 MB) and non-image (e.g. text/plain) rejection tests mirroring the receipt suite. | Functions Dev |

---

## 4.5 Secrets and Environment

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| SEC1 | `.firebaserc`; `.gitignore:123` (`secrets/`), `:60` (`*.jks`); `git ls-files secrets/` (0); workflow secret refs | **No committed secrets; Invariant 4 upheld.** Single project `onebytwo-avtanshgupta`. The local `secrets/` directory (service-account JSON, Apple `.p8`, Android `.jks`, base64 key files) is **gitignored and never committed** (0 tracked, no historical add). All CI/release credentials are injected via GitHub Actions secrets (`GOOGLE_SERVICES_JSON_BASE64`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `ANDROID_KEYSTORE_*`, `GOOGLE_SERVICE_INFO_PLIST_BASE64`). | — | None (PASS) | — |
| SEC2 | `storage.rules` (forward group-receipt); `firebase.json` | **Sprint 3 (Groups) needs no new secrets.** Group cover photos reuse the existing Storage bucket/config and the same `GOOGLE_SERVICES_*` material; no new project, key, or service account is required. | — | Accept (confirmed) | DevOps |
| SEC3 | issue #26 (Sprint 6 milestone) | Release-pipeline secrets + DPDP legal sign-off remain deferred to Sprint 6, as planned. | Low | Accept (on track) | DevOps / PM |
| SEC4 | `secrets/` (Wallper.dmg, Wallper Receipt.pdf, etc.) | The local `secrets/` staging dir also holds unrelated personal files. Gitignored — zero repo impact; pure local hygiene. | Low | Backlog (optional) — note in dev-setup docs that `secrets/` is a local-only, gitignored staging dir; keep it tidy. | DevOps |

---

## Summary

| Sub-part | High | Medium | Low | PASS/None |
|---|---|---|---|---|
| 4.1 Flutter deps | 0 | 0 | 3 (D1, D2, D3) | D4 |
| 4.2 Functions deps | 1 (D5) | 0 | 2 (D6, D7) | — |
| 4.3 Firestore rules | 0 | 2 (R1, R2) | 0 | R3 |
| 4.4 Storage rules | 0 | 1 (R4) | 0 | R5 |
| 4.5 Secrets/env | 0 | 0 | 2 (SEC3, SEC4) | SEC1, SEC2 |
| **Total** | **1** | **3** | **7** | 4 PASS |

### Preliminary Triage (Phase 6 finalises)

- **Fix now:** D5 (attempt targeted `overrides` for the 4 HIGH advisories; fall back to
  a tracked Sprint-3 issue if it destabilises), R4 (avatar size/MIME negative tests —
  cheap, closes a regression gap).
- **Backlog:** R1 (rules-file split before Sprint-3 groups inflate it), R2 (groups-rules
  negative tests with the first groups PR), D1/D3/D6/D7 (dependency bumps — #22 owns the
  Flutter majors), SEC4 (dev-setup note).
- **Accept:** D2 (pinned lock is intentional), SEC1/SEC2/SEC3 (secrets posture sound;
  no new secrets for Groups; #26 on track for Sprint 6).

> Headline: the security posture is **sound** — no committed secrets, Invariant 4 intact,
> and the rules are consistent and (for shipped collections) well-tested. Two real
> action items stand out: the **4 HIGH npm advisories** (firebase-admin transitive, low
> in-context exploitability, no clean fix — resolve via `overrides` or track), and two
> **test-coverage gaps in the rules layer** (untested forward groups Firestore rules and
> untested avatar size/MIME constraints) that should be closed before Sprint 3 builds on
> them.
