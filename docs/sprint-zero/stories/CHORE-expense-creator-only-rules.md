# CHORE — friendship-expense edit / soft-delete restricted to the creator

> Defence-in-depth Firestore-rules tightening: restrict editing and soft-deleting a
> friendship-context expense (`friendships/{friendshipId}/expenses/{expenseId}`) to the
> **expense creator only** — the member whose `uid == expense.createdBy`. Today
> `isValidExpenseUpdate()` preserves `createdBy` / `createdAt` immutability
> (`data.createdBy == prev.createdBy`) but does NOT require
> `request.auth.uid == prev.createdBy`, so the rule
> `allow update: if isCallerFriendshipMember() && isValidExpenseUpdate()` accepts an
> edit or soft-delete from EITHER friendship member. The FR-EX-06 client already gates
> the Edit / Delete affordances on `expense.createdBy == currentUser.uid`; this chore
> re-checks that gate server-side so that a buggy or custom client cannot issue the
> write directly and have the rules accept it. Pure security-rules + rules-test chore:
> no client, Cloud Function, trigger, schema, or `firestore.indexes.json` change.
>
> Tracked as GitHub issue **#47** (`Firestore rules: tighten friendship-expense
> update/delete to creator-only`, label `sprint-2-chore`); the PR opens with
> `Closes #47`. Originates from the FR-EX-06 Architect Notes §2.9 item 5 and the PR #46
> reviewer note R-2.

---

## SRS Requirement ID(s)

- **FR-EX-06** (SRS section **4.5** Expense Management, line 211, **P0**) — "Users shall
  be able to edit or delete **any expense they created**." The phrase "they created" is
  the creator-only intent that this chore enforces at the rules layer, completing the
  client-side gate already shipped in FR-EX-06.
- **Reference: SRS section 7.5** (Security Rules — Principles) — documents are
  writable only by listed participants, and expense writes are validated server-side in
  addition to client-side. This chore strengthens the friendship-expense update rule
  within that posture (a server-side authorisation re-check, not a new model).

> Tracked GitHub issue: **#47** (`sprint-2-chore`). The implementing PR opens with
> `Closes #47`.
>
> Note on the section number: FR-EX-06 lives in SRS **§4.5** (Expense Management); SRS
> §4.6 is "Settlements & Simplified Debts" and is referenced below only for the
> deliberate settlement-versus-expense asymmetry.

## Relevant SRS Sections

- **Section 4.5 / FR-EX-06** (P0, line 211) — edit / delete an expense the user created;
  the "they created" wording is the creator-only scope this chore makes authoritative
  server-side.
- **Section 7.5** — Security Rules (Principles): participant-scoped access; "Expense
  writes shall validate that splits sum to the expense amount in paise (server-side rule
  check, in addition to client-side)." This chore adds the creator-equality check inside
  the same server-side rule, next to the existing sum / shape checks.
- **Section 7.3** — Key Architectural Decisions: `simplifiedBalances` is the
  server-maintained, client-read-only source of truth (Invariant 2). **Reinforced** —
  this chore hardens the client-writable expense subcollection that *feeds* the server
  recompute (`onExpenseWriteFriendship` → `recomputeSimplifiedBalances`) but never reads
  or writes `simplifiedBalances`.
- **(Context) Section 4.6** — Settlements & Simplified Debts: settlements are bilateral,
  which is why the settlement update rule deliberately lets either party soft-delete.
  Friendship-expenses are creator-owned, so the two rules are **intentionally
  asymmetric** — see Implementation Notes.

## Relevant Design References

- **None / no UI change.** The FR-EX-06 client already gates the Edit and Delete
  affordances on `expense.createdBy == currentUser.uid`; a non-creator sees a read-only
  Expense Detail screen with no action buttons (FR-EX-06 AC-13 / Q8). This chore changes
  only the server-side rule and its rules-tests, so the user-visible behaviour is
  unchanged for both members.
- **No Designer and no Flutter Dev are required** for this chore.

## Priority

- **P1 / `sprint-2-chore`.** The highest-ranked unshipped single-focus, issue-backed
  carry-forward candidate. Issue #47 is open with the `sprint-2-chore` label; the change
  is small, self-contained, and closes a known defence-in-depth gap surfaced in PR #46
  review (note R-2) and recorded in FR-EX-06 §2.9 item 5. It is not P0 because the
  client UI already prevents the write in the shipped app — this is hardening against a
  buggy or custom client, not a user-facing defect.

## Product Ruling — creator-only for BOTH edit and soft-delete (resolves the open question)

**RULING (PM): adopt creator-only for both the edit path and the soft-delete path.** This
is the minimal, client-matching fix and the defence-in-depth posture this work exists to
enforce.

- There is a coherent argument that *either* member could soft-delete a shared expense,
  because the expense affects both members' balances. That argument is **rejected for this
  chore**: the FR-EX-06 client UI, the FR-EX-06 §2.9 item 5 note, and issue #47 all specify
  creator-only, and the whole purpose of #47 is to make the rules match the shipped client
  gate.
- Allowing either member to soft-delete would be a **deliberate product divergence**, not a
  rules bug-fix. It would require a **paired client-UI follow-up** (the Delete affordance
  would have to be un-gated for non-creators) and is therefore **OUT OF SCOPE here**. If the
  product ever wants symmetric deletion, raise it as a separate story with its own client
  change and acceptance criteria.
- The asymmetry with settlements is **intentional and must not be harmonised** in this
  chore: settlements are bilateral (`isValidSettlementUpdate()` lets either party
  soft-delete), whereas a friendship-expense is owned by its creator. Do not "tidy up" the
  two rules to look the same.

## Story

**As** a One By Two user,
**I want** only the person who created a shared expense to be able to edit or delete it,
even at the database layer,
**so that** a buggy or custom client cannot let the other member silently alter or remove an
expense I recorded.

## Preconditions

1. The user is authenticated (Phone Auth complete per FR-AU-03/04/05; session restored per
   FR-AU-07).
2. A friendship document exists at `friendships/{friendshipId}` with
   `memberIds == [self, friend]` (the deterministic composite ID).
3. At least one **non-deleted** expense exists at
   `friendships/{friendshipId}/expenses/{expenseId}` with a known `createdBy` — i.e. one
   member is the creator and the other is a non-creator friendship member.
4. The Firebase Emulator Suite is available for the rules-test run, on the single project
   `onebytwo-avtanshgupta` (Invariant 4). No server-side or client work is required.

## Acceptance Criteria

**Scenario 1 (happy path) — the creator CAN edit.**
Given an authenticated user who is the expense creator (`request.auth.uid == expense.createdBy`)
and a member of the friendship,
When they submit a valid partial-update map (for example `amountPaise` plus matching `splits`
plus `updatedAt: serverTimestamp()`) that satisfies the existing shape, splits-sum and
extension-point-lock checks,
Then the update is accepted.

**Scenario 2 (happy path) — the creator CAN soft-delete.**
Given an authenticated user who is the expense creator,
When they submit a soft-delete update setting `deleted: true` together with
`updatedAt: serverTimestamp()`, leaving the immutable fields unchanged,
Then the soft-delete is accepted.

**Scenario 3 (negative) — a non-creator member CANNOT edit.**
Given an authenticated friendship member who is NOT the expense creator (in `memberIds` but
`request.auth.uid != expense.createdBy`),
When they submit an otherwise-valid partial-update map,
Then the update is rejected with permission-denied because the new
`request.auth.uid == prev.createdBy` clause in `isValidExpenseUpdate()` fails — even though
that member may still *read* the expense.

**Scenario 4 (negative) — a non-creator member CANNOT soft-delete.**
Given an authenticated non-creator friendship member,
When they submit a soft-delete update (`deleted: true` + `updatedAt: serverTimestamp()`),
Then the update is rejected with permission-denied (the soft-delete path flows through the
same update rule, so it is creator-only too).

**Scenario 5 (negative / regression guard) — immutability and shape checks still hold.**
Given the expense creator,
When they submit an update that mutates `createdBy` or `createdAt`, or that breaks the
splits-sum / shape / extension-point-lock checks (or omits the `updatedAt == request.time`
bump),
Then the update is still rejected — the existing `data.createdBy == prev.createdBy`,
`data.createdAt == prev.createdAt`, `data.updatedAt == request.time` and
`isValidExpenseShared()` checks remain in force and are not weakened by this change, and hard
delete remains `allow delete: if false`.

**Scenario 6 (negative) — a non-member outsider cannot read or write.**
Given an authenticated user who is NOT in the friendship's `memberIds`,
When they attempt to read, edit, or soft-delete the expense,
Then every operation is rejected with permission-denied — the pre-existing
`isCallerFriendshipMember()` gate on read / create / update is unchanged by this chore.

## Definition of Done

- [ ] **Code merged to main via an approved PR**, and the PR opens with `Closes #47`.
- [ ] Rules change applied in `firestore.rules` `isValidExpenseUpdate()`: the
      `&& request.auth.uid == prev.createdBy` clause (where `prev = resource.data`) added so
      that BOTH the edit path and the soft-delete path are creator-only.
- [ ] **Unit / widget tests written and passing** — for this rules-only chore the relevant
      suite is the Firestore-rules emulator tests (no Dart unit/widget tests apply, as there
      is no client change):
  - [ ] The two placeholder `assertSucceeds` tests for a non-creator member's update and
        soft-delete (`functions/test/firestore-rules/expenses-friendship.test.ts`, the
        update-rules `describe` block) inverted to `assertFails`, with their comments updated
        to describe the enforced creator-only behaviour.
  - [ ] Positive creator-success counterparts present: a test asserting the creator (memberA)
        CAN edit (the canonical FR-EX-06 partial-update-map acceptance) and a test asserting
        the creator CAN soft-delete (`deleted: true` + `updatedAt`).
  - [ ] Existing immutability / sum / shape / non-member tests remain green; no regression to
        the rest of the friendship-expense rules suite; `allow delete: if false` unchanged.
  - [ ] Full Firestore-rules suite green under the Firebase Emulator Suite on the single
        project `onebytwo-avtanshgupta`.
- [ ] **QA reviewed and verified** — QA sign-off that the creator-only gate is enforced for
      both edit and soft-delete and that no legitimate creator path or non-member boundary
      regressed.
- [ ] **Telemetry / analytics events in place** — N/A: no new events (no client or
      user-facing behaviour change); existing FR-EX-06 telemetry is untouched. Recorded
      explicitly so the gate is consciously satisfied, not skipped.
- [ ] **Documentation updated (if applicable)** — this story; FR-EX-06 §2.9 item 5 reconciled
      from "KNOWN FINDING — do NOT fix in PR #46" to "resolved by the creator-only rules
      hardening"; decision log touched only if the Architect rules a new ADR is warranted
      (not expected — see Implementation Notes).
- [ ] **Zero** client / Cloud Function / trigger / Firestore-schema / `firestore.indexes.json`
      change in the PR.

## Invariant Compliance

- **Invariant 1 (money is integer paise).** N/A to the change itself — no monetary value is
  read, computed, or written. The existing `amountPaise is int` typing and the bounded
  splits-sum check (`sumOfSharesEquals`) inside `isValidExpenseShared()` stay exactly as-is;
  this chore introduces no float and no new arithmetic.
- **Invariant 2 (`simplifiedBalances` is server-maintained, client-read-only).**
  **Reinforced.** This hardens the client-writable expense subcollection that feeds the
  server-side recompute (`onExpenseWriteFriendship` → `recomputeSimplifiedBalances`); the
  rule never reads or writes `simplifiedBalances`, and the field's read-only-to-clients
  guarantee is unchanged.
- **Invariant 3 (system share sheet only).** N/A — no sharing path is touched.
- **Invariant 4 (single Firebase project).** **Reinforced** — the change is validated only
  against the Firebase Emulator Suite on the single project `onebytwo-avtanshgupta`; no new
  project, config, or `.firebaserc`/`firebase.json` entry is introduced.

## Implementation Notes

- **Where the change lives.** `firestore.rules` `isValidExpenseUpdate()` — add
  `&& request.auth.uid == prev.createdBy`, where `prev = resource.data`, alongside the
  existing immutability clauses (`data.createdBy == prev.createdBy`,
  `data.createdAt == prev.createdAt`, `data.updatedAt == request.time`) and the
  `isValidExpenseShared()` call (sum / shape / extension-point locks). The `allow update`
  rule keeps `isCallerFriendshipMember() && isValidExpenseUpdate()` unchanged; the new clause
  is purely additive. `isValidExpenseCreate()` already gates create on
  `data.createdBy == request.auth.uid`, so create is consistent.
- **Soft-delete flows through the same rule.** Clients soft-delete by an update that sets
  `deleted: true` (hard delete is `allow delete: if false`), so the single new clause restricts
  both edit and soft-delete to the creator — no separate delete rule is needed.
- **Tests to change.** `functions/test/firestore-rules/expenses-friendship.test.ts` — the two
  non-creator cases in the "update rules (FR-EX-06 additions)" `describe` block flip from
  `assertSucceeds` to `assertFails`; add/confirm the positive creator counterparts (creator
  edit; creator soft-delete). The seed sets `createdBy: memberA`, so memberA is the creator and
  memberB is the non-creator member used by the negative cases.
- **Source of the requirement.** FR-EX-06 Architect Notes §2.9 item 5 ("Possible rules-gap on
  non-creator update / delete — KNOWN FINDING") and PR #46 reviewer note R-2.
- **Deliberate asymmetry — do NOT harmonise.** `isValidSettlementUpdate()` with its
  `allow update` intentionally permits **either** party to soft-delete a settlement, because
  settlements are bilateral. Friendship-expenses are creator-owned. Leave the settlement rule
  untouched; the difference is by design.
- **Not a new decision.** This is a tightening WITHIN the established rules-authorisation
  model — the field-level / immutability rule pattern of **ADR-0010**
  (`affectedKeys()` / field-equality clauses) under the client-writes-with-rule-enforcement
  posture of **ADR-0008**, all in service of **Invariant 2**. A new ADR is therefore **not
  expected**; the Architect should confirm.
- **Handoff.** Handed off to the **Architect** for Architect Notes — to confirm (a) no new
  ADR is required, (b) the exact placement/wording of the `request.auth.uid == prev.createdBy`
  clause within `isValidExpenseUpdate()`, and (c) that the settlement asymmetry remains as-is.
  After the Architect signs off, this proceeds to the Functions/rules implementer and QA.

---

## Architect Notes

> Authored at the PM's handoff to ratify Issue #47. References: `firestore.rules`
> lines 282-300 (`isValidExpenseUpdate`), 316-320 (`allow update` / `allow delete`),
> 272-280 (`isValidExpenseCreate`), and 480-504 (the deliberately asymmetric settlement
> update rule); `functions/test/firestore-rules/expenses-friendship.test.ts` lines
> 606-685 (the "update rules (FR-EX-06 additions)" `describe` block) and line 512 (the
> pre-existing non-member rejection); ADR-0008 (client-writes-with-rule-enforcement),
> ADR-0010 (field-level / immutability rules); Invariants 1, 2, 4 from
> `.github/shared/invariants.md`. The three confirmation points the PM requested are
> ratified below: clause placement / wording in §2, the settlement asymmetry in §3, and
> the no-new-ADR ruling in §7.

### §1. Pick confirmation

**CONFIRMED.** Issue #47 (friendship-expense creator-only rules hardening) is the
correct next-slot pick: the highest-ranked unshipped single-focus, issue-backed
carry-forward candidate. It closes a concrete, recorded gap — FR-EX-06 Architect Notes
§2.9 item 5 ("possible rules-gap on non-creator update / delete — KNOWN FINDING, do NOT
fix in PR #46") and PR #46 reviewer note R-2 — and discharges the two self-documenting
placeholder tests that were deliberately left as `assertSucceeds` precisely so they
could be flipped to `assertFails` once this work landed. The diff is small, additive,
and confined to one rules function plus its test, so the blast radius is minimal.

The alternative I could have picked was the Bucket-B "close-with-evidence" bundle (a
batch of already-satisfied items closed together with links). I prefer this single-focus
pick: #47 is a genuine code change with a security-gap justification, not a bookkeeping
close-out. Bundling it into a multi-item batch would dilute the review, blur the
`Closes #47` provenance, and mix a rules tightening that rejects previously-accepted
writes with no-op administrative closes. One issue, one PR, one reviewable diff.

### §2. The ratified rules change

**RATIFIED.** The chosen form is the inline clause `&& request.auth.uid ==
prev.createdBy` inside `isValidExpenseUpdate()` (`firestore.rules` line 295, where
`let prev = resource.data;` is bound at line 284), NOT a separate
`isCallerExpenseCreator()` helper. Both forms were acceptable; the inline form is
chosen because it sits directly beside the existing `data.createdBy == prev.createdBy`
immutability clause (line 297) — author identity and author immutability are read
together — and because it matches the wording the placeholder-test comments already
specified (`request.auth.uid == prev.createdBy`). A one-line helper would add an
indirection for a single call site with no reuse.

The clause is **purely additive**: every pre-existing check in `isValidExpenseUpdate()`
is preserved — the `isValidExpenseShared(data, members)` call (line 286: known-keys,
required-keys, shape, extension-point locks, payer / split membership, and the paise
sum check) and the three immutability / freshness locks `data.createdBy ==
prev.createdBy`, `data.createdAt == prev.createdAt`, and `data.updatedAt ==
request.time` (lines 297-299). `resource.data` is the pre-image and is always present
on an update (the document must already exist), so `prev.createdBy` is safe to
dereference here. The clause is correctly absent from the create path:
`isValidExpenseCreate()` (lines 272-280) already binds authorship via `data.createdBy
== request.auth.uid` (line 277), where there is no `resource.data` to read. `allow
update: if isCallerFriendshipMember() && isValidExpenseUpdate()` (lines 316-317) and
`allow delete: if false` (line 320) are unchanged.

### §3. Creator-only ruling and the deliberate settlement asymmetry — do NOT harmonise

**RATIFIED: creator-only for BOTH edit and soft-delete.** Both paths flow through the
single `allow update` rule — a soft-delete is an update that sets `deleted: true` (hard
delete stays `allow delete: if false`) — so the one new clause restricts both to the
member whose `uid == prev.createdBy`. This is the PM ruling and it mirrors the shipped
FR-EX-06 client gate (`expense.createdBy == currentUser.uid`).

The settlement update rule is **intentionally asymmetric and must not be "fixed" by a
future reader.** `isValidSettlementUpdate()` (lines 480-488) with its `allow update`
(lines 501-504) deliberately permits **EITHER** party — `fromUserId` or `toUserId` — to
soft-delete, because a settlement is a bilateral record of a payment between two people.
A friendship-expense, by contrast, is owned by its creator. The two rules therefore look
different on purpose; do not tidy them into a common shape. If either-member soft-delete
of an expense were ever wanted, that would be a deliberate product divergence (not a
rules bug-fix) requiring a paired client-UI follow-up to un-gate the Delete affordance
for non-creators — explicitly OUT OF SCOPE here. The settlement block is left untouched
by this chore.

### §4. Tests

**CONFIRMED green.** In `functions/test/firestore-rules/expenses-friendship.test.ts`
(the "update rules (FR-EX-06 additions)" `describe` block, lines 606-685):

- The two non-creator placeholder tests are inverted from `assertSucceeds` to
  `assertFails` — non-creator edit (line 620) and non-creator soft-delete (line 639) —
  with their comments updated to describe the enforced creator-only gate. The seed sets
  `createdBy: memberA`, so memberB is the non-creator member used by both negatives.
- Two creator-success counterparts are added: memberA (the creator) CAN edit (line 657,
  the canonical partial-update map) and memberA CAN soft-delete (line 675, `deleted:
  true` + `updatedAt`), proving the tightening does not regress the legitimate path.
- The pre-existing "rejects update by a non-member" case (line 512) still holds and is
  now belt-and-braces — a non-member is rejected both by `isCallerFriendshipMember()`
  and by the new creator gate.
- The immutability / sum / shape / extension-point cases and `allow delete: if false`
  are unchanged. Full Firestore-rules suite green under the Emulator Suite: **10 suites
  / 200 tests**, with no regression to the rest of the friendship-expense suite.

### §5. Invariants

- **Invariant 1 (money is integer paise).** N/A to the change itself — no monetary
  value is read, computed, or written. The `amountPaise is int` typing and the bounded
  `sumOfSharesEquals` splits check inside `isValidExpenseShared()` are untouched; no
  float and no new arithmetic is introduced.
- **Invariant 2 (`simplifiedBalances` server-maintained, client-read-only).**
  **Reinforced.** The change hardens the client-writable expense subcollection that
  *feeds* the server recompute (`onExpenseWriteFriendship` →
  `recomputeSimplifiedBalances`); the rule never reads or writes `simplifiedBalances`,
  and the field's read-only-to-clients guarantee is unchanged.
- **Invariant 3 (system share sheet only).** N/A — no sharing path is touched.
- **Invariant 4 (single Firebase project).** **Reinforced** — validated only against
  the Firebase Emulator Suite on the single project `onebytwo-avtanshgupta`; no new
  project, config, or `.firebaserc` / `firebase.json` entry is introduced.

### §6. Scope and handoff

**CONFIRMED: rules + rules-tests only.** NO client / UI change (the FR-EX-06 client
already gates Edit and Delete on `createdBy`, so a non-creator sees a read-only Expense
Detail screen with no action buttons — user-visible behaviour is identical for both
members), NO Cloud Function, NO trigger, NO Firestore schema, and NO
`firestore.indexes.json` change. **No Designer and no Flutter Dev are required for this
chore** — stated explicitly so the gate is consciously satisfied, not skipped. The work
is handed to the Functions / rules implementer (the `firestore.rules` clause and the
test inversions, already in the working tree) and then to QA, to verify the creator-only
gate for both edit and soft-delete and that no legitimate creator path or non-member
boundary regressed.

### §7. No new ADR; commit-type ruling

**RULED: no new ADR.** This is a tightening WITHIN the established rules-authorisation
model — the field-level / immutability clause pattern of **ADR-0010** (`affectedKeys()`
/ field-equality checks), under the client-writes-with-rule-enforcement posture of
**ADR-0008**, in service of **Invariant 2**. It introduces no new architectural
decision, collection, or pattern; it re-applies an existing one to one more clause. A
short Architect Notes block on this story is the correct record; the decision log is not
touched.

**Commit type: recommend `fix(rules):`.** The change rejects writes the rules previously
accepted (a non-creator member's edit / soft-delete) — it closes a security gap and
alters observable authorisation behaviour, which is a fix rather than pure housekeeping.
`chore(rules):` is also defensible (the shipped app's user-facing behaviour is unchanged
because the client already gated the affordance) and is noted as acceptable. Either way
the scope is a single token (`rules`).
