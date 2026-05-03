# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #31.

---

## PR #32 — User Lookup and Friendship Creation (FR-FR-01 Matching)

**Status:** Next up. Unblocked once PR #31 merges.

**Scope:** Consumes the hand-off contract established by PR #31's contact picker
UI. Performs a Firestore query against the `users` collection to determine whether
the selected contact's phone number matches an existing One By Two user. If yes,
creates a `friendships` document linking the two users. If no, opens an invite
flow via the system share sheet (Invariant 3). Handles negative cases: self-add
rejection and duplicate friendship rejection.

**Dependencies (from DAG):** PR #31 (contact picker UI) — in flight.

**User story:** `docs/sprint-zero/stories/FR-FR-01-matching-and-friendship.md`.
DoR-compliant. 2 SP.

**Design artefacts:**
- Friendship schema: `docs/design/07-technical/firestore-schema.md`
  (`friendships/{friendshipId}`).
- Screen spec: `docs/design/06-screen-specs/09-12-friends.md` (SCR-10, SCR-11).
- Architecture: ADR-0013 (Contact Matching Strategy — Local Intersection).
- PII handling: `docs/design/07-technical/pii-handling.md`.

**Agents involved:** Flutter Dev, Architect (friendship Firestore security rules),
QA.

**Bucket-B items likely addressed:** R1-R3 (friendship rules create/update/delete
tests).

---

## PR #33 — TBD per Sprint 2 Plan

**Status:** Planned. Depends on PR #31 (and possibly PR #32).

**Scope:** Likely FR-FR-02 (link existing user or invite via system share sheet)
or FR-FR-03 (friends list with simplified net balance). Final determination at
PR #33 kickoff based on Sprint 2 progress and any blockers surfaced by PR #32.

**Candidate stories:**
- `docs/sprint-zero/stories/FR-FR-02-link-or-invite-friend.md` (3 SP, DoR-compliant).
- `docs/sprint-zero/stories/FR-FR-03-friends-list.md` (3 SP, DoR-compliant).

**Agents involved:** Flutter Dev, QA.

---

## PR #34 — TBD per Sprint 2 Plan

**Status:** Planned.

**Scope:** To be determined at PR #34 kickoff. Will cover whichever of FR-FR-02,
FR-FR-03, or FR-FR-04 remains after PR #33's scope is finalised.

**Agents involved:** TBD.
