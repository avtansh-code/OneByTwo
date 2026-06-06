# FR-FR-04: Per-friend Transaction History (Friend Detail screen)

> Implementation-ready user story for the per-friend ledger screen that
> closes the simplified-debts read-side round-trip beyond the friends-list
> net-balance chip.

---

## SRS Requirement ID(s)

FR-FR-04 (SRS section 4.3), FR-FR-03 (SRS section 4.3 — net balance display
parity), FR-SE-01 (SRS section 4.6 — simplified debts canonical view).

## Relevant SRS Sections

- Section 4.3 — Friends (1-to-1)
- Section 4.6 — Simplify & Settle
- Section 5.9 — Localisation and internationalisation
- Section 5.10 — Observability
- Section 6.4 — Loading, empty, and error states
- Section 7.3 — Key architectural decisions
- Section 7.5 — Security rules

## Priority

**P0 — Must have**

## Story Points

5

## User Story

As a **signed-in user**,
I want to **see the full ledger of expenses (and settlements) shared with a
specific friend**,
so that **I can understand how the simplified net balance came to be and add
new expenses without losing context**.

## Preconditions

1. User is authenticated and a member of the friendship `friendshipId`.
2. The friendship document exists at `friendships/{friendshipId}` and the
   expense subcollection `friendships/{friendshipId}/expenses/{expenseId}`
   may legitimately be empty.
3. The top-level `settlements/{settlementId}` collection may contain zero
   or more documents whose `contextType == 'friendship'` and
   `contextId == friendshipId`.
4. `simplifiedBalances` on the friendship document is maintained by the
   `recomputeSimplifiedBalances` Cloud Function (PR #36) and exposed as a
   read-only projection to the client.
5. The app uses the single configured Firebase project; pre-merge
   verification runs against the Firebase Emulator Suite.

---

## Acceptance Criteria

### AC-1 — Open from Friends List

> Given I am viewing the Friends list and the friendship `A↔B` is rendered
> When I tap the row
> Then the Friend Detail screen opens at `/friends/{friendshipId}` with the
> friend's identity pre-bound
> And `friend_detail_viewed` fires exactly once with `friendship_id_hash`
> (SHA-256 truncated to 16 hex chars) and `balance_state` of `owed`, `owes`,
> or `settled`

### AC-2 — Header rendering

> Given the screen opens
> When the friendship document is loaded
> Then the header renders the friend's avatar, display name, and balance
> pill colour-coded per the balance state
> And the friend's display name and photo URL are resolved via the shared
> `userProfileProvider.family(uid)` (no re-fetch logic)

### AC-3 — Balance pill semantics

> When `simplifiedBalances[currentUid][friendUid] > 0`
> Then the pill reads `You are owed ₹X.XX` in the success colour
>
> When `simplifiedBalances[friendUid][currentUid] > 0`
> Then the pill reads `You owe ₹X.XX` in the danger colour
>
> When both are zero
> Then the pill reads `Settled up` in the muted `onSurface` colour
>
> And every paise → INR conversion goes through `formatInrFromPaise()`
> exclusively (Invariant 1)

### AC-4 — Expense list (top 5)

> Given the friendship has at least one non-deleted expense in
> `friendships/{friendshipId}/expenses/`
> When the expense snapshot stream emits
> Then the screen renders up to 5 most recent rows ordered by `date`
> descending
> And each row shows description, category icon, payer (`You` /
> friend's first name), date (locale-formatted), and the current user's
> share (`you lent ₹X.XX` if the user is the payer, `you borrowed ₹X.XX`
> otherwise — derived from the `splits[]` entry for the current user's UID)

### AC-5 — Settlement read path (defensive empty)

> Given the friendship has zero settlements in the top-level `settlements/`
> collection (production state pre-FR-SE-08)
> When the settlement snapshot stream emits
> Then the screen does not render any settlement rows
>
> And when one or more settlements ARE present (seeded by an integration
> test or by a future FR-SE-08 client write), they render intermixed in
> the timeline ordered chronologically alongside the expense rows

### AC-6 — Empty state (no expenses, no settlements)

> Given the friendship has zero non-deleted expenses AND zero settlements
> When both snapshot streams emit
> Then the body shows an empty-state placeholder with title `No expenses yet`
> and subtitle `Add an expense with [Friend name] to start tracking.`
> And the FAB remains visible and opens the `AddExpenseBottomSheet`
> (the PR #38 call site)

### AC-7 — Loading state

> Given the screen opens
> When the friendship document and the two snapshot streams are loading
> Then the header renders a skeleton placeholder
> And the body renders three list-tile skeleton rows
> And the app-bar title shows the friend's display name if available;
> otherwise it renders an empty placeholder

### AC-8 — Error state

> Given the friendship document load throws OR either snapshot stream
> errors
> When the error reaches the provider
> Then the body shows an error placeholder with title `Something went wrong`,
> subtitle `We couldn't load this friend's details. Please try again.`, and
> a Retry button
> And tapping Retry re-initialises both snapshot streams

### AC-9 — Real-time update via the round-trip

> Given I am viewing the Friend Detail screen with an empty expense list
> and `simplifiedBalances == {}`
> When I tap the FAB and create a ₹100 equal-split expense via the
> `AddExpenseBottomSheet`
> Then within the integration-test polling window (≤ 2.5 s per NFR-PE-04)
> the screen re-renders so that the balance pill reads
> `You are owed ₹50.00` in the success colour, the new expense row appears
> at the top of the timeline, and the empty state is replaced by the
> populated state

### AC-10 (Negative) — Invariant 1 (paise, read-side) at the boundary

> Given the Friend Detail screen's source files
> When the boundary-contract grep runs
> Then the files contain no `.toDouble()`, no `/ 100` arithmetic, and no
> `double` declarations
> And every monetary display uses `formatInrFromPaise()` exclusively

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `friend_detail_viewed` | `friendship_id_hash: String` (SHA-256 truncated to 16 hex chars), `balance_state: 'owed' \| 'owes' \| 'settled'` | Friend Detail screen first paints the populated or empty state (fires once per screen mount) |

Deferred — gated on out-of-scope features:

| Event name | Deferred to |
|---|---|
| `settle_up_tapped` | FR-SE-08 (PR #43) |
| `friend_history_tapped` | full-history screen (separate later PR) |
| `friend_delete_menu_tapped` | FR-FR-05 (separate later PR) |

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | Applicable. All amounts originate as integer paise. Conversion to INR happens exclusively via `formatInrFromPaise()` at the UI boundary. |
| 2 | `simplifiedBalances` server-maintained | Applicable. This screen reads `simplifiedBalances` via `netBalancePaise()` for the header pill; it never writes the field. |
| 3 | System share sheet only | N/A. This screen does not initiate outbound sharing. |
| 4 | Single Firebase project | Applicable. Reads come from the single production Firebase project, with emulator-backed pre-merge verification. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing.
- [ ] Integration tests passing against Firebase Emulator Suite.
- [ ] QA reviewed and verified acceptance criteria (including negative cases).
- [ ] Telemetry events in place and firing correctly.
- [ ] Accessibility verified (semantic labels, screen-reader, focus order).
- [ ] Dark mode checked (WCAG AA contrast ratios).
- [ ] Invariant compliance confirmed (all four).
- [ ] Documentation updated (story file, sprint plan, next-three-prs,
      feature READMEs).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (Invariant 1) — required for the
      header pill and every expense-row share label.
- [ ] No client writes to `simplifiedBalances` (Invariant 2) — required;
      read-only via `netBalancePaise()`.
- [ ] Uses system share sheet only (Invariant 3) — N/A.
- [ ] Single Firebase project (Invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/09-12-friends.md` (SCR-11) |
| Wireframe | `docs/design/04-wireframes/friends-flow.md` (Friend Detail section) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`friendships/{friendshipId}/expenses/{expenseId}`, `settlements/{settlementId}`) |
| State management | `docs/design/07-technical/state-management.md` (friends feature) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (`friend_detail_viewed`) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Friend Detail screen, header, timeline, states, provider, settlement repository, expense-repository read-path extension, widget + provider + boundary + PII tests, integration stub |
| Architect | Review of read-side data flow, invariants 1 and 2 compliance, query and index expectations |
| QA | Manual smoke matrix, real-time update verification, error state, emulator-backed sign-off |
| DevOps | Deploy the updated `firestore.indexes.json` (settlements composite extended with `date DESC`) before merge |
| Designer | SCR-11 sign-off on header presentation, balance pill clarity, accessibility focus order |

---

## Technical Notes

- **New `lib/features/settlements/` layer.** First Flutter feature for
  the settlements collection. The store / repository / fake pattern
  mirrors `FriendshipStore` (PR #35) and `ExpenseStore` (PR #38).
  `SettlementDoc.fromFirestore` applies strict parsing — malformed
  entries are dropped and surfaced via `onParseFailure` so silent
  corruption stays observable.
- **Extended `ExpenseStore` / `ExpenseRepository`.** A new
  `watchExpensesByFriendship({friendshipId, limit: 5})` is added to the
  abstract store and the Firestore implementation. The
  composite index `(deleted ASC, date DESC)` already exists on the
  `friendships/{fid}/expenses` collection.
- **Settlements composite index extension.** The existing
  `settlements (contextType ASC, contextId ASC)` composite is extended
  to `(contextType ASC, contextId ASC, date DESC)` so the canonical
  query `where contextType + where contextId + orderBy('date', desc)`
  runs without `FAILED_PRECONDITION`. The extension matches the schema
  doc (`docs/design/07-technical/firestore-schema.md` §Composite
  Indexes). DevOps deploys the updated `firestore.indexes.json` before
  merge.
- **`friendDetailProvider`.** New combined provider that fans out three
  reads — the friendship document via `friendshipRepositoryProvider`, the
  per-friendship expense stream, the per-friendship settlement stream —
  and folds them into a `FriendDetailState` discriminated union
  (`loading`, `populated`, `empty`, `error`). The balance projection
  reuses `netBalancePaise()` — the helper from `lib/core/balances/`
  shared with the friends list.
- **Telemetry single-fire.** `friend_detail_viewed` fires exactly once
  per screen mount on first paint of the populated or empty state,
  gated by a `_loggedView` boolean in `ConsumerStatefulWidget`.
- **PII hashing per ADR-0013.** `friendship_id_hash` is produced via
  `hashFriendshipId()` (already canonical from PR #35). The raw
  `friendshipId` is a deterministic composite of two UIDs and must
  never appear in telemetry — the PII-leak test enforces.
- **Placeholder replacement.** `FriendDetailPlaceholderScreen` from
  PR #35 (and its FAB wiring from PR #38) is replaced by
  `FriendDetailScreen` with the same constructor signature, so the
  navigation call site in `FriendsListScreen._onRowTapped` needs no
  change. The placeholder file is deleted.

---

## Out of scope

- Settle Up CTA card (FR-SE-07 affordance is reserved on the screen but
  the button is omitted; FR-SE-08 / PR #43 introduces the write path).
- Edit / delete expense (FR-EX-06 — separate later PR; rows are read-only).
- Receipt attachment (FR-EX-05 — separate later PR; receipt thumbnails
  are not rendered because every expense doc currently has
  `receiptUrl == null`).
- Delete Friend overflow menu (FR-FR-05 P1 — separate later PR with
  SCR-12).
- Full-history screen at `/friends/:friendshipId/history` — only top-5
  recent expenses per SCR-11; "View full history" link omitted.
- Send Reminder (FR-SE-09 P1 — separate later PR).
- Groups context (FR-GR-04 — Sprint 3 groups epic).
- Any change to `firestore.rules` or to `functions/src/**`.
- The D5 deadline upgrade (issues #39 + #40) — PR #44 owns this.
