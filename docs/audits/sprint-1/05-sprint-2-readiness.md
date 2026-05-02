# Phase 5 — Sprint 2 Pre-Flight Readiness

**Date:** 2026-05-02
**Lead:** PM
**Consulting:** Architect, Designer

---

## 5.1 Sprint 2 Scope Clarity

Sprint 2 is "Friends and Core Expenses" (50 SP, 14 stories) per
`docs/design/08-plan/sprint-sequence.md`.

### First Three Stories

| ID | Title | SP | DoR Status |
|---|---|---|---|
| FR-FR-01 | Add friend by contact picker or +91 number | 3 | **Not ready** |
| FR-FR-02 | Link existing user or invite via system share sheet | 3 | **Not ready** |
| FR-FR-03 | Friends list with simplified net balance | 3 | **Not ready** |

### Definition-of-Ready Compliance

| DoR Item | Status |
|---|---|
| 1. User story written (SRS 13.2 format) | **MISSING** — no story files for FR-FR-01/02/03 in `docs/sprint-zero/stories/` |
| 2a. Screen specs | Present (draft) — `docs/design/06-screen-specs/09-12-friends.md` |
| 2b. Wireframes | Present — `docs/design/04-wireframes/friends-flow.md` |
| 2c. Component catalogue entries | Present — `OBTContactPicker`, `OBTFriendListTile`, `OBTBalancePill` |
| 3a. Firestore schema | Present — `friendships/{friendshipId}` fully specified |
| 3b. Cloud Functions catalogued | Present |
| 3c. Riverpod provider shape | Present — section 2.3 of state-management.md |
| 4. Dependencies cleared | Cleared — FR-AU-07 shipped in PR #11 |
| 5. Telemetry events | Partial — some events missing (see 5.4) |
| 6. Accessibility requirements | Present |
| 7. Edge cases documented | Present |
| 8. Story points estimated | Present — all stories have SP |
| 9. Invariant applicability | Partial — no per-story checklist |

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| SR1 | **Missing user story documents.** FR-FR-01, FR-FR-02, FR-FR-03 have no written story files in SRS 13.2 format. `next-three-prs.md` explicitly states: "FR-FR-01 story refinement needed before PR opens." This is a **Sprint 2 blocker** — DoR item 1 is not satisfied. | **High** | **Fix now** — PM writes user stories for the first three Sprint 2 stories before any Sprint 2 PR opens. | PM |
| SR2 | Screen spec `09-12-friends.md` is in draft status ("pending PM, Flutter Dev, and QA review"). | Medium | **Fix now** — PM schedules review and finalises the screen spec before Sprint 2 development begins. | PM |

---

## 5.2 Design Artefacts

### Friends Epic

| Artefact | Path | Status |
|---|---|---|
| Wireframes — friends flow | `docs/design/04-wireframes/friends-flow.md` | Present |
| Screen specs — friends | `docs/design/06-screen-specs/09-12-friends.md` | Present (draft) |
| Component: OBTContactPicker | `docs/design/02-design-system/components.md` | Catalogued |
| Component: OBTFriendListTile | `docs/design/02-design-system/components.md` | Catalogued |
| Component: OBTBalancePill | `docs/design/02-design-system/components.md` | Catalogued |
| Mockups — friends | `docs/design/05-mockups/` | **Missing** |

### Expenses Epic

| Artefact | Path | Status |
|---|---|---|
| Wireframes — expense flow | `docs/design/04-wireframes/expense-flow.md` | Present |
| Screen specs — expenses | `docs/design/06-screen-specs/19-22-expenses.md` | Present |
| Mockups — add expense | `docs/design/05-mockups/04-add-expense-bottom-sheet.html` | Present |
| Components: OBTSplitMethodSelector, OBTSplitEntryRow | `docs/design/02-design-system/components.md` | Catalogued |

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| SR3 | **Friends mockup missing.** No HTML mockup for friends screens in `docs/design/05-mockups/`. Screen spec compensates — the spec is comprehensive with detailed visual descriptions. | Low | Backlog — designer can create if needed during Sprint 2 development. Non-blocking. | Designer |

---

## 5.3 Technical Readiness

### Friendship Schema

**Complete.** `friendships/{friendshipId}` is fully specified in
`firestore-schema.md` with fields: `memberIds` (array, size 2, sorted ascending),
`simplifiedBalances` (server-maintained map), `lastActivityAt` (timestamp, composite
index).

### Platform Permissions for Contact Picker

| Platform | Permission | File | Status |
|---|---|---|---|
| iOS | `NSContactsUsageDescription` | `ios/Runner/Info.plist` | **MISSING** |
| Android | `READ_CONTACTS` | `android/app/src/main/AndroidManifest.xml` | **MISSING** |

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| SR4 | **Contact picker permissions not declared.** iOS `Info.plist` has camera and photo library permissions but not contacts. Android `AndroidManifest.xml` has no `READ_CONTACTS`. The contact picker will fail at runtime without these. **Sprint 2 blocker.** | **High** | **Fix now** — add `NSContactsUsageDescription` to Info.plist and `READ_CONTACTS` to AndroidManifest.xml. Can be folded into the Sprint 2 opener PR or done in the audit PR. | DevOps |

### Simplified-Debts in Sprint 2

**Correction:** The audit prompt suggested Sprint 2 does NOT exercise simplified-debts.
This is **incorrect**. Sprint 2 includes FR-SE-02 (full algorithm, 8 SP), FR-SE-03
(Cloud Function writes simplifiedBalances, 5 SP), and FR-SE-04 (atomic recomputation,
5 SP). The Sprint 2 demo explicitly states: "The Cloud Function correctly computes and
writes simplified balances; the client reads them without writing."

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| SR5 | Sprint 2 fully exercises simplified-debts. The `paidBy` vs `payerId` bug (Phase 1, finding F1) is therefore a **Sprint 2 blocker** — it must be fixed before expense documents are created. | **High** | **Fix now** — reinforces F1 from Phase 1. The field name fix is critical path. | Functions Dev |

### State Management

**Complete.** Provider trees for Friends (section 2.3), Expenses (section 2.5), and
Settlements (section 2.6) are fully defined in `state-management.md`.

---

## 5.4 Telemetry Plan

### Friends Events

| Event | Status | Notes |
|---|---|---|
| `friend_added` | Defined | Parameters: `method` (`contacts`/`manual`/`invite`) |
| `friend_invite_sent` | Defined | Parameters: `method` |
| `friend_search_started` | **Missing** | No event for search initiation on add-friend screen |
| `contact_permission_granted` | **Missing** | Only denial is tracked; asymmetric observability |
| `contact_permission_denied` | Defined | SCR-10 reference |

### Expense Events

| Event | Status | Notes |
|---|---|---|
| `expense_added` (save success) | Defined | Named `expense_added` not `expense_save_succeeded` |
| `expense_save_failed` | Defined | Asymmetric naming with success event |
| `expense_split_method_selected` | Defined | Parameters: `method` |

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| SR6 | **Missing `friend_search_started` event.** Cannot measure friend discovery funnel without it. | Medium | **Fix now** — add to telemetry plan section 1.4 before Sprint 2 development. | PM |
| SR7 | **Missing `contact_permission_granted` event.** Only denial tracked. Cannot measure permission grant rate or contact picker adoption. | Medium | **Fix now** — add to telemetry plan section 1.4. | PM |
| SR8 | **Expense event naming asymmetry.** Success logs `expense_added`; failure logs `expense_save_failed`. Inconsistent naming harms funnel analysis. | Low | Backlog — decide on naming convention (`_added`/`_add_failed` or `_save_succeeded`/`_save_failed`) before expense stories begin. | PM |

---

## 5.5 Risk Register

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| SR9 | **Contact permission handling not in risk register.** Risk register (R-01 through R-16) does not address: iOS 14+ permission request behaviour, Android permission group requirements, permission revocation during app lifecycle, graceful degradation when denied. This is a notorious source of friction. | **High** | **Fix now** — add R-17 (Contact Permission Platform Fragility) to `risks-revisited.md`. Include mitigation design for denial UX, "try again" flow, and manual fallback. | Architect |
| SR10 | **Contact permission denial UX not specified.** Screen spec does not define what happens when user denies contact access on the add-friend screen. No fallback UI documented. | **High** | **Fix now** — add to screen spec `09-12-friends.md`: denial state with manual-entry fallback and permission re-request flow. | Designer |
| SR11 | **Privacy posture for contacts is sound but implicit.** SRS FR-FR-01 specifies contacts are matched locally; telemetry plan forbids phone numbers in events. However, there is no explicit architectural note confirming contacts are never uploaded to Firestore. | Medium | **Fix now** — add a brief note to the friendship schema doc or an ADR confirming: "Contact data is processed client-side only. Phone numbers from the device contact book are matched against existing `users` documents via query but are never stored in a contacts collection or transmitted to analytics." | Architect |
| SR12 | **DPDP compliance: legal sign-off not scheduled.** The right-to-delete requirement is documented and the `onUserDelete` Cloud Function is planned, but legal review has not been scheduled. | Low | Backlog — schedule legal review before Sprint 6 (release). Not blocking for Sprint 2. | PM |

---

## Summary

| Category | High | Medium | Low | Total |
|---|---|---|---|---|
| Scope clarity (5.1) | 1 | 1 | 0 | 2 |
| Design artefacts (5.2) | 0 | 0 | 1 | 1 |
| Technical readiness (5.3) | 2 | 0 | 0 | 2 |
| Telemetry (5.4) | 0 | 2 | 1 | 3 |
| Risk register (5.5) | 2 | 1 | 1 | 4 |
| **Total** | **5** | **4** | **3** | **12** |

### Sprint 2 Blockers

1. **SR1:** Missing user story documents for FR-FR-01/02/03 (PM must write)
2. **SR4:** Contact picker permissions missing from iOS and Android (DevOps must add)
3. **SR5:** `paidBy` vs `payerId` bug in Cloud Function (Functions Dev must fix — reinforces Phase 1 F1)

### Preliminary Triage

**Fix now candidates (8):** SR1, SR2, SR4, SR5, SR6, SR7, SR9, SR10, SR11.

**Backlog candidates (3):** SR3, SR8, SR12.

**Accept candidates (0).**

### Overall Assessment

Sprint 2 is **not yet ready for entry**. Three blockers must be resolved: user stories
must be written, contact picker permissions must be added, and the `paidBy` field name
bug must be fixed. Design artefacts are 95% complete and the technical foundation is
strong. The risk register has a critical gap around contact permission handling that
must be addressed before the first friend-add PR.
