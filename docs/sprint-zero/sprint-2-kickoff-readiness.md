# Sprint 2 Kickoff Readiness Confirmation

**Date:** 2026-05-02
**Author:** PM
**Sign-off:** QA

---

## Audit Resolution Status

All five audit phases have been resolved:

| Phase | Title | Findings | Fixed (A) | Deferred (B) | Accepted (C) |
|---|---|---|---|---|---|
| 1 | Documentation drift | 23 | 12 | 8 | 3 |
| 2 | Test-suite health | 8 | 0 | 8 | 0 |
| 3 | Agentic infrastructure debt | 16 | 9 | 5 | 2 |
| 4 | Dependency and security | 15 | 0 | 13 | 2 |
| 5 | Sprint 2 pre-flight readiness | 12 | 8 | 3 | 1 |
| **Total** | | **74** | **27** | **37** | **9** |

- **Bucket A (27 findings):** All fixed in PR #14 (18 commits).
- **Bucket B (37 findings):** Logged in `docs/audits/sprint-1/06-deferred-to-sprint-2.md`.
- **Bucket C (9 findings):** Documented in `docs/audits/sprint-1/00-triage-summary.md`.

No finding remains untriaged. Every item has an explicit disposition.

---

## Sprint 2 First Three PRs

Queued in `docs/sprint-zero/next-three-prs.md`:

| PR | Story | Title | SP | DoR | Story File |
|---|---|---|---|---|---|
| #15 | FR-FR-01 | Add friend by contact picker or +91 number | 3 | Compliant | `docs/sprint-zero/stories/FR-FR-01-add-friend.md` |
| #16 | FR-FR-02 | Link existing user or invite via system share sheet | 3 | Compliant | `docs/sprint-zero/stories/FR-FR-02-link-or-invite-friend.md` |
| #17 | FR-FR-03 | Friends list with simplified net balance | 3 | Compliant | `docs/sprint-zero/stories/FR-FR-03-friends-list.md` |

### DoR Compliance for PR #15 (Sprint 2 First PR)

| DoR Item | Status | Evidence |
|---|---|---|
| User story (SRS 13.2) | Done | `FR-FR-01-add-friend.md` written in PR #14 |
| Screen spec | Done | `06-screen-specs/09-12-friends.md` with permission denial UX |
| Wireframes | Done | `04-wireframes/friends-flow.md` |
| Components catalogued | Done | `OBTContactPicker`, `OBTFriendListTile`, `OBTBalancePill` |
| Firestore schema | Done | `friendships/{friendshipId}` fully specified |
| Security rules documented | Done | `firestore-security-rules.md` |
| Provider shape | Done | State-management doc section 2.3 |
| Dependencies cleared | Done | FR-AU-07 shipped (PR #11) |
| Telemetry events | Done | `friend_added`, `friend_invite_sent`, `friend_search_started`, `contact_permission_granted`, `contact_permission_denied` |
| Platform permissions | Done | `NSContactsUsageDescription` + `READ_CONTACTS` added in PR #14 |
| Risk documented | Done | R-17 (contact permission fragility) added in PR #14 |
| Story points | Done | 3 SP |

---

## Sprint 2 First PR Is Unblocked

**PR #15 (FR-FR-01: Add friend by contact picker)** is unblocked:

- All dependencies are shipped (FR-AU-07 in PR #11).
- Platform permissions are in place (PR #14).
- User story, screen spec, wireframes, and components are ready.
- Friendship schema and security rules are documented.
- Telemetry events are defined.
- Risk R-17 (contact permissions) is documented with mitigation plan.
- `paidBy` → `payerId` bug is fixed (PR #14) — critical for Sprint 2 expenses.
- ADRs 0009-0011 document the architectural patterns Sprint 2 will follow.
- Conventions doc updated with CF testing layers and field-level rules pattern.

---

## Key Artefacts Produced by PR #14

| Artefact | Purpose |
|---|---|
| ADR-0009 | Sealed-union auth state pattern (template for Sprint 2 state machines) |
| ADR-0010 | Field-level Firestore rules using `affectedKeys()` (template for friendship rules) |
| ADR-0011 | Cloud Function module layout (template for Sprint 2 functions) |
| R-17 | Contact permission platform fragility risk and mitigation |
| CI invariant check | Single Firebase project verified on every PR |
| 3 user stories | FR-FR-01, FR-FR-02, FR-FR-03 (Sprint 2 DoR satisfied) |
| Conventions update | CF testing layers and field-level rules pattern documented |

---

## QA Sign-Off

**Confirmed:**

- [x] All five audit phases have been resolved (74 findings: 27 fixed, 37 deferred,
  9 accepted).
- [x] Bucket A fixes are committed in PR #14 with passing tests (213 Flutter + 32
  Functions).
- [x] Bucket B items are logged in `06-deferred-to-sprint-2.md` with owners and
  timelines.
- [x] Bucket C items are documented with acceptance rationale.
- [x] The first three Sprint 2 PRs are queued with DoR-compliant story files.
- [x] PR #15 (FR-FR-01) is identified and unblocked.
- [x] No open blockers for Sprint 2 entry.

---

**This file is the green light to start Sprint 2.**
