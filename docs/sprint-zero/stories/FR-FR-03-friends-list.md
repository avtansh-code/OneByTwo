# FR-FR-03: Friends List with Simplified Net Balance

> Implementation-ready user story for listing all friendships with a simplified
> net balance per friend, sourced from the server-maintained balance projection.

---

## SRS Requirement ID(s)

FR-FR-03 (SRS section 4.3), FR-SE-01 (SRS section 4.6), FR-SE-03 (SRS section 4.6), FR-SE-06 (SRS section 4.6)

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

3

## User Story

As a **signed-in user**,
I want to **see my friends list with the simplified net balance for each friend**,
so that **I can immediately tell who owes me, whom I owe, and which friendships are settled up**.

## Preconditions

1. User is authenticated and can access the Friends tab.
2. Friendship documents exist in `friendships/{friendshipId}` or the list query may
   legitimately return zero documents.
3. `simplifiedBalances` is maintained by the
   `recomputeSimplifiedBalances` Cloud Function and exposed to the client as a
   read-only projection.
4. The app uses the single configured Firebase project; pre-merge verification
   runs against the Firebase Emulator Suite.

---

## Acceptance Criteria

### AC-1 — Populated list shows net balance direction and INR formatting

> Given I have one or more friendship documents with simplified balance data
> When I open the Friends list
> Then each row shows the friend's display name and a single simplified balance
> state of `owes you`, `you owe`, or `settled up`
> And any monetary display is derived from integer paise stored in
> `simplifiedBalances`
> And conversion to INR formatting happens at the UI layer only
> And `friends_list_viewed` fires with `friend_count`

### AC-2 — Friend rows are ordered by recent activity

> Given I have multiple friendship documents with different `lastActivityAt`
> timestamps
> When the Friends list loads
> Then the rows are ordered by `lastActivityAt` descending
> so the most recently active friendship appears first

### AC-3 — Zero balance shows “settled up”

> Given a friendship has no net amount owed in the server-maintained simplified
> balance projection
> When that row is rendered in the Friends list
> Then the balance pill shows `settled up`
> And no raw payer-to-payee debt graph is displayed

### AC-4 (Negative) — Empty state is shown when no friendships exist

> Given the friendship query returns zero documents
> When I open the Friends list
> Then I see the empty state with an Add Friend CTA
> And no placeholder balance rows are shown

### AC-5 (Negative / Invariant 2) — Client cannot mutate `simplifiedBalances`

> Given the Friends list is visible and an authenticated client attempts to write
> to the `simplifiedBalances` field on a friendship document
> When the request reaches Firestore Security Rules
> Then the write is rejected
> And the Friends list remains a read-only view of the server projection

### AC-6 — Balance updates appear in real time

> Given I am viewing the Friends list and a shared expense or settlement changes
> a friendship balance
> When the `recomputeSimplifiedBalances` Cloud Function writes updated
> `simplifiedBalances` and `lastActivityAt` values
> Then the affected friend row updates automatically without a manual refresh
> And the row reorders if the new `lastActivityAt` value makes it the most recent

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `friends_list_viewed` | `friend_count` | Friends list screen becomes visible |
| `friend_row_tapped` | `friendship_id` | User opens a friend from the list |
| `friends_empty_add_tapped` | — | User taps Add Friend from the empty state |

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | Applicable. Balance values originate as integer paise and are converted to INR only in the UI layer. |
| 2 | `simplifiedBalances` server-maintained | Applicable. The list must read `simplifiedBalances` without recomputing or writing it on the client. |
| 3 | System share sheet only | N/A. This story displays balances and does not initiate outbound sharing. |
| 4 | Single Firebase project | Applicable. The Friends list reads from the single production Firebase project, with emulator-backed pre-merge verification. |

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
- [ ] Documentation updated (if applicable).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) — required for all balance display.
- [ ] No client writes to `simplifiedBalances` (invariant 2) — required; client reads only.
- [ ] Uses system share sheet only (invariant 3) — N/A in this story.
- [ ] Single Firebase project (invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/09-12-friends.md` (SCR-09) |
| Wireframe | `docs/design/04-wireframes/friends-flow.md` (section 1, Friends List) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`friendships/{friendshipId}`) |
| State management | `docs/design/07-technical/state-management.md` (section 2.3, friends feature) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (section 1.4, friends events) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Friends list UI, loading/empty/error states, balance rendering, navigation wiring |
| Architect | Review of balance-display rules, invariant 1 and 2 compliance, query/index expectations |
| QA | Real-time update verification, empty/error states, emulator-backed security checks |
| Designer | List tile presentation, balance-pill clarity, accessibility sign-off |

---

## Technical Notes

- **Firestore collection:** query `friendships/{friendshipId}` with `where('memberIds', 'array-contains', uid).orderBy('lastActivityAt', 'desc')`; each document includes `memberIds`, `simplifiedBalances`, and `lastActivityAt`.
- **Providers:** `friendsListProvider` supplies the real-time ordered list; `friendDetailProvider` is the navigation handoff target when a row is tapped.
- **Telemetry events:** `friends_list_viewed`, `friend_row_tapped`, and `friends_empty_add_tapped` are the core analytics events for this story.
- **Balance source of truth:** the client must not recompute simplified debts; it renders the server-maintained `simplifiedBalances` projection and formats paise as INR for display only.
