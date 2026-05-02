# Next Three PRs

> Rolling roadmap. Updated after PR #13 (FR-PR-01 merged, Sprint 1 closed).
> Last updated: 2026-05-02.

---

## PR #14 — Sprint 1 Retro Findings (Conditional)

**Status:** Conditional — only opens if retro action items produce non-trivial
changes.

**Scope:**
- Extract a shared `FakeUserRepository` base class to reduce test boilerplate
  when `UserRepository` gains new methods.
- Remove `ProfilePlaceholderScreen` if confirmed to be dead code (superseded by
  `ProfileScreen` from PR #13).
- Pin macOS CI runner to `macos-15` in `.github/workflows/pr.yml`.
- Document `maxWorkers: 1` constraint in `functions/README.md`.

**Agents involved:** Flutter Dev (fake extraction, placeholder removal), DevOps
(CI runner pin), QA (verify no regressions).

**Decision gate:** If all items are trivial one-liners, they may be folded into
the Sprint 2 opener PR instead. PM to decide before PR #14 opens.

---

## PR #14 or #15 — Sprint 2 Opener: Friend-Add via Contact Picker (FR-FR-01)

**Status:** Next up.

**Scope:** Add-friend flow using the device contact picker. The user selects a
contact, the app resolves the +91 phone number, and either links to an existing
`users` document or creates a pending friendship document in the `friendships`
collection. Opens the social graph vertical.

**Dependencies (from DAG):** FR-AU-07 (session persistence) — already shipped in
PR #11.

**User story:** To be written. FR-FR-01 story refinement needed before PR opens.

**Design artefacts:**
- Friendship schema: to be designed by Architect.
- Screen spec: `docs/design/06-screen-specs/` (friends section).
- Wireframe: `docs/design/04-wireframes/` (friends section).

**Agents involved:** Flutter Dev, Architect (friendship schema and Firestore
rules), QA.

---

## PR #15 or #16 — Add Expense (FR-EX-01)

**Status:** Planned.

**Scope:** Add-expense bottom sheet allowing a user to create a new expense with
a description, amount (in integer paise — invariant 1), and split calculation
across selected friends. Writes the expense document to Firestore and triggers
the `recomputeSimplifiedBalances` Cloud Function (invariant 2 — server-maintained
balances). This is the first story that exercises the FUNC-01 contract shipped in
PR #12.

**Dependencies (from DAG):** FR-AU-07 (session persistence, shipped PR #11),
FUNC-01 (simplified-debts contract, shipped PR #12).

**User story:** To be written. FR-EX-01 story refinement needed before PR opens.

**Agents involved:** Flutter Dev, Functions Dev (trigger wiring), Architect
(expense schema), QA.
