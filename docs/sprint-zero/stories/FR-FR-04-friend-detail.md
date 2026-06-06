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

---

## Architect Notes

> Appended for PR #42. These notes ratify the design decisions taken
> before implementation begins. References:
> `docs/copilot_prompts/sprint_2/8.md`, `.github/shared/invariants.md`,
> `.github/shared/decision-log.md` (ADR-0001, ADR-0002, ADR-0006,
> ADR-0007, ADR-0013).

### 1. File layout

This PR adds the following Flutter source files:

- `lib/features/settlements/domain/settlement_doc.dart` — strict-parsing
  immutable value type for `settlements/{settlementId}` documents (the
  read-side counterpart that FR-SE-08 will pair with on the write side).
- `lib/features/settlements/data/settlement_repository.dart` — abstract
  `SettlementStore` + `FirestoreSettlementStore` (production) +
  `SettlementRepository` wrapper + `settlementRepositoryProvider`.
  Defines `SettlementParseFailureSink` and `logSettlementParseFailure`
  parallel to the friendship variants.
- `lib/features/friends/application/friend_detail_provider.dart` — combined
  provider returning `FriendDetailState` (`loading` / `populated` /
  `empty` / `error`) per `(friendshipId, currentUserUid, otherUserUid)`
  family.
- `lib/features/friends/presentation/friend_detail_screen.dart` — root
  screen widget replacing the placeholder.
- `lib/features/friends/presentation/widgets/friend_detail_header.dart`
- `lib/features/friends/presentation/widgets/friend_detail_timeline.dart`
- `lib/features/friends/presentation/widgets/friend_detail_states.dart`
  (loading skeleton, empty state, error state, all in one file because
  they are small and share styling tokens — splitting earned no
  modularity benefit per the FR-FR-03 precedent).
- `lib/features/settlements/README.md` — describe the read-path-only
  scope of PR #42 and the hand-off to FR-SE-08 for the write path.

And extends:

- `lib/features/expenses/data/expense_repository.dart` — add a
  `watchExpensesByFriendship({friendshipId, limit})` method on the
  abstract `ExpenseStore` and the Firestore implementation. The
  `ExpenseRepository` exposes the same signature.

And replaces:

- `lib/features/friends/presentation/friend_detail_placeholder_screen.dart`
  — deleted; replaced by `friend_detail_screen.dart`.

### 2. `SettlementStore` IS extracted (parallels `ExpenseStore` / `FriendshipStore`)

The store / repository / fake pattern mirrors `FriendshipStore` (PR #35)
and `ExpenseStore` (PR #38) exactly. The abstract `SettlementStore`
exposes `Stream<List<SettlementDoc>> watchByContext({contextType,
contextId})`. The Firestore implementation wraps the snapshot stream and
maps each doc through `SettlementDoc.fromFirestore`. Tests inject a
`FakeSettlementStore` (no `fake_cloud_firestore` dependency in
`pubspec.yaml`, consistent with prior PRs).

Rationale: the FR-SE-08 settle-up write path will add a `createSettlement`
method to the same store; introducing the abstraction now keeps the FR-SE-08
diff focused on its write logic. The FR-SE-08 architect notes may amend
this if they discover a stronger reason to inline.

### 3. Timeline composition + settlements index extension

- The timeline is **intermixed**: expense and settlement events are
  folded into a single `List<FriendDetailTimelineEvent>` ordered by their
  primary timestamp (`ExpenseDoc.date` for expenses,
  `SettlementDoc.date` for settlements) descending. The top-5 cap from
  AC-4 applies to the COMBINED list — settlements count toward the cap
  so that the timeline never grows beyond the "recent activity" budget
  the SCR-11 spec defines.
- The expense query uses the existing composite index
  `(deleted ASC, date DESC)` on `friendships/{fid}/expenses` (already
  in `firestore.indexes.json` since PR #35-era schema doc).
- The settlement query is
  `where('contextType', ==, 'friendship').where('contextId', ==, fid).orderBy('date', desc).limit(5)`.
  The existing composite index in `firestore.indexes.json` had only
  `(contextType ASC, contextId ASC)`; without `date DESC` the orderBy
  would fail at runtime with `FAILED_PRECONDITION`. This PR extends the
  composite to `(contextType ASC, contextId ASC, date DESC)`, matching
  the canonical schema in
  `docs/design/07-technical/firestore-schema.md` §Composite Indexes
  "Settlements by Context and Date".

  **Deviation from prompt scope:** the source prompt explicitly listed
  `firestore.indexes.json` as out of scope. The deviation is necessary
  for the canonical settlement query to work in production; without it
  the AC-5 path would crash on any non-empty result set. DevOps deploys
  the updated index before merge (the deploy is independent of the app
  bundle so it lands first without breaking the running app).

### 4. Per-row tap behaviour — no-op

Tapping an expense row in the timeline is a deliberate no-op for PR #42.
SCR-11 references an Expense Detail screen but it is FR-EX-06's
responsibility (separate later PR). Until FR-EX-06 ships, the row
remains tappable for visual affordance consistency but the gesture is
swallowed. A widget test asserts the tap is captured without
navigating, so a future "tap → edit sheet" wiring is the only diff
FR-EX-06 needs to make.

### 5. Settle-up affordance — omitted entirely

The SCR-11 spec reserves a position for the `OBTSettleUpCard` between
the header and the timeline. PR #42 omits the card entirely (no
deferred-affordance placeholder) because:

- FR-SE-07 requires the CTA to be functional ("on every screen with
  non-zero balance"). A non-functional placeholder would be a fake
  affordance — worse UX than its absence.
- The header + timeline layout looks correct without the card; FR-SE-08
  inserts the card via a clean diff between the header and the
  timeline, with no need to first remove a placeholder.

### 6. No design-system widget extractions

SCR-11 lists 8 reusable components from the design-system catalogue
(`OBTAppBar`, `OBTUserAvatar`, `OBTBalancePill`, `OBTSettleUpCard`,
`OBTExpenseListTile`, `OBTEmptyState`, `OBTErrorState`,
`OBTSkeletonLoader`). None exist in the codebase yet. Per the PR #38
precedent (only `OBTAmountInput` was extracted because the bottom-sheet
amount input had a clear second use site planned for FR-SE-08), this PR
INLINES every component:

- `_FriendDetailHeader` (avatar + name + balance pill) inline in
  `friend_detail_header.dart`.
- The header's balance pill is a NEW inline widget — distinct from
  `lib/features/friends/presentation/widgets/balance_pill.dart` (the
  friends-list trailing pill) because the SCR-11 large variant has
  different copy (`You are owed ₹X.XX` vs `owes you ₹X.XX`) and a
  different layout (centred, large). Both will be folded into
  `OBTBalancePill` when a third use site appears.
- `_TimelineExpenseRow`, `_TimelineSettlementRow` inline in
  `friend_detail_timeline.dart`.
- `_LoadingState`, `_EmptyState`, `_ErrorState` inline in
  `friend_detail_states.dart`.

If FR-SE-08 introduces a third use site for any pattern (most likely
the balance pill), that PR extracts the component then.

### 7. Telemetry single-fire

`friend_detail_viewed` fires exactly **once per screen instance** on
first paint of the populated or empty state. A `ConsumerStatefulWidget`
with a `_loggedView` boolean guards re-emission. The event carries:

- `friendship_id_hash: String` — `hashFriendshipId(friendshipId)`
  (SHA-256 truncated to 16 hex). The raw `friendshipId` (composite UID
  pair) MUST NOT appear in any analytics parameter.
- `balance_state: String` — one of `owed` (net > 0), `owes` (net < 0),
  `settled` (net == 0). Derived from `netBalancePaise()` evaluated on
  the friendship document's `simplifiedBalances`. Computing on emit (not
  on mount) ensures the state reflects the loaded data.

The PII-leak test enforces both rules by asserting the raw UID-pair
string never appears in any logged parameter and that the
`friendship_id_hash` value equals
`hashFriendshipId('uid-priyalakshmi_uid-rahulagarwal')` exactly.

### 8. `netBalancePaise()` is the sole projection helper

The header pill derives its balance via the SAME helper the friends
list uses (`lib/core/balances/net_balance.dart`). PR #42 must NOT
re-implement the projection. A provider test asserts the helper is
invoked (via a fake friendship doc with known balances and expected
signed paise output).

This also locks in the read-side parity invariant: the friends-list
chip and the friend-detail header always agree, because they derive
from the same input via the same helper.

### 9. State machine — `FriendDetailState`

The provider returns `AsyncValue<FriendDetailState>` where
`FriendDetailState` is a sealed class with four variants:

- `FriendDetailStateLoading` — at least one of the three reads
  (friendship doc, expenses stream, settlements stream) has not yet
  emitted.
- `FriendDetailStateEmpty({header})` — all three reads have emitted; the
  combined timeline is empty (zero expenses AND zero settlements).
- `FriendDetailStatePopulated({header, timeline})` — all three reads
  have emitted; the timeline has at least one event.
- `FriendDetailStateError({error})` — any of the three streams produced
  an error.

The `header` carries the resolved display name, photo URL, net balance
in paise, and balance state. The `timeline` is a
`List<FriendDetailTimelineEvent>` of up to 5 events. Empty + populated
differ only by which body widget renders; the header always renders
when the friendship document has resolved.

### 10. Error state — retry re-invalidates the providers

The error state's Retry button calls `ref.invalidate(...)` on the
friendship document provider, the expense stream provider, and the
settlement stream provider, which forces them to re-resolve and
re-subscribe. The composite `friendDetailProvider` family then re-emits
loading and (on success) populated. A widget test asserts the
re-invalidation by injecting a fake repository that succeeds on the
second attempt.

### 11. No new ADR required

All decisions above are within the precedent of:

- ADR-0001 — simplified debts as the canonical view; the screen reads
  `simplifiedBalances` (Invariant 2) and renders it via the existing
  `netBalancePaise()` helper.
- ADR-0002 — paise integer arithmetic; the screen never crosses paise
  → double; `formatInrFromPaise()` is the sole conversion at the UI
  boundary.
- ADR-0006 — Riverpod state management; the new provider is a
  standard combined `StreamProvider.family` returning a sealed-class
  state.
- ADR-0007 — feature-first folder layout; new files live under
  `lib/features/settlements/` and `lib/features/friends/`.
- ADR-0013 — PII / telemetry hashing; `friendship_id_hash` uses
  `hashFriendshipId()` at the emit boundary.

If a future PR denormalises any user-doc field onto the settlement or
expense doc (a real trade-off with PII implications), that escalates to
a new ADR before implementation.
