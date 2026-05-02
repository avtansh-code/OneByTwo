# Next Three PRs

> Rolling roadmap. Updated after PR #14 (Sprint 1 boundary cleanup merged).
> Last updated: 2026-05-02.

---

## PR #15 — Sprint 2 Opener: Friend-Add via Contact Picker (FR-FR-01)

**Status:** Next up. Unblocked by PR #14.

**Scope:** Add-friend flow using the device contact picker. The user selects a
contact, the app resolves the +91 phone number, and either links to an existing
`users` document or creates a pending friendship document in the `friendships`
collection. Opens the social graph vertical.

**Dependencies (from DAG):** FR-AU-07 (session persistence) — shipped in PR #11.
Contact picker permissions — added in PR #14.

**User story:** `docs/sprint-zero/stories/FR-FR-01-add-friend.md` (written in
PR #14). DoR-compliant.

**Design artefacts:**
- Friendship schema: complete in `docs/design/07-technical/firestore-schema.md`.
- Screen spec: `docs/design/06-screen-specs/09-12-friends.md` (includes
  contact permission denial UX, added in PR #14).
- Wireframe: `docs/design/04-wireframes/friends-flow.md`.
- Components: `OBTContactPicker`, `OBTFriendListTile`, `OBTBalancePill` catalogued.
- Risk: R-17 (contact permission fragility) documented in PR #14.

**Agents involved:** Flutter Dev, Architect (friendship Firestore rules), QA.

---

## PR #16 — Link Existing User or Invite (FR-FR-02)

**Status:** Planned. Depends on FR-FR-01.

**Scope:** After selecting a contact, determine whether the phone number matches
an existing OneByTwo user. If yes, create a confirmed friendship. If no, send an
invite via the system share sheet (invariant 3). Contacts are matched client-side
only — never uploaded to Firestore (privacy note in PR #14).

**User story:** `docs/sprint-zero/stories/FR-FR-02-link-or-invite-friend.md`
(written in PR #14). DoR-compliant.

**Agents involved:** Flutter Dev, QA.

---

## PR #17 — Friends List with Net Balance (FR-FR-03)

**Status:** Planned. Depends on FR-FR-01.

**Scope:** Friends list screen showing all friendships with the authenticated
user. Each row displays the friend's display name, avatar, and simplified net
balance (read from `simplifiedBalances` — invariant 2, client-read-only). Sorted
by `lastActivityAt` descending. Empty state for zero friends.

**User story:** `docs/sprint-zero/stories/FR-FR-03-friends-list.md` (written in
PR #14). DoR-compliant.

**Agents involved:** Flutter Dev, QA.
