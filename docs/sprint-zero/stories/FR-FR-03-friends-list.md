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
| `friends_list_viewed` | `friend_count: int` | Friends list screen first renders the populated or empty state (fires once per screen mount) |
| `friend_row_tapped` | `friendship_id: String` (SHA-256 truncated to 16 hex chars) | User opens a friend from the list |
| `friends_empty_add_tapped` | — | User taps Add Friend from the empty state |

The pre-existing `friend_add_button_tapped` continues to fire when the app-bar `+` is
tapped from the populated state (regression target from the PR #14 placeholder screen).

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

---

## Architect Notes

> Appended for PR #35. These notes ratify the design decisions taken before
> implementation begins. References: `docs/copilot_prompts/sprint_2/4.md`,
> `.github/shared/invariants.md`, `.github/shared/decision-log.md`.

### 1. Net-balance computation and INR formatting live in `lib/core/`

- `lib/core/balances/net_balance.dart` exposes a pure function
  `int netBalancePaise({Map<String, dynamic>? simplifiedBalances, String currentUserId, String otherUserId})`.
  Returns the SIGNED paise amount from the current user's perspective. Positive ⇒
  "owes you"; negative ⇒ "you owe"; zero ⇒ "settled up". Missing/null map returns 0.
  Malformed nested entries (non-integer values, wrong shape) return 0 for that pair
  — the parsing layer (see §3 below) is responsible for logging the parse failure.
- `lib/core/formatters/inr_formatter.dart` exposes
  `String formatInrFromPaise(int paise)`. Uses integer division (`~/`, `%`) so no
  `double` arithmetic ever touches money. Indian numbering system via
  `NumberFormat.decimalPattern('en_IN')` for the rupee component. Always two
  decimal places. Zero state ⇒ `"₹0.00"`. Negative uses U+2212 minus
  (`"−₹50.00"`). Symbol is always `₹` and is never overridable by callers.
- These two functions belong in `lib/core/` (not feature-scoped) because every
  monetary display path across the app will use them. The PR #34 precedent for
  `lib/core/widgets/india_phone_input_formatter.dart` establishes the
  "formatters/utilities are core" convention.

### 2. Repository layer extends `FriendshipRepository`; the write path stays locked

- Add `Stream<List<FriendshipDoc>> watchFriendships(String currentUserId)` to
  `FriendshipRepository`. Delegates to a new
  `Stream<List<FriendshipDoc>> watchByMember(String userId)` on the abstract
  `FriendshipStore`. The Firestore implementation runs
  `where('memberIds', 'array-contains', uid).orderBy('lastActivityAt', desc).snapshots()`.
- Do NOT modify `createFriendship` or `friendshipExists`. PR #32's boundary
  contract for the write path is locked in.

### 3. Domain models with defensive parsing

- `FriendshipDoc` (`lib/features/friends/domain/friendship_doc.dart`) is an
  immutable value type carrying `friendshipId`, `memberIds`,
  `simplifiedBalances` (typed `Map<String, Map<String, int>>`), and
  `lastActivityAt`. The `fromFirestore(id, data)` factory performs strict type
  validation:
  - Missing or `null` `simplifiedBalances` ⇒ empty map (the freshly-created
    friendship case before the Cloud Function runs; AC-3 still renders
    "settled up" naturally).
  - Malformed nested entries (non-`int` values, non-`Map` sub-entries) are
    dropped and a breadcrumb is routed through the `onParseFailure` callback.
    In production, `FirestoreFriendshipStore` wires the callback to
    `logFriendshipParseFailure` (`lib/features/friends/data/friendship_repository.dart`),
    which calls `developer.log(..., name: 'friendship_parse_failure', level: 900)`.
    `developer.log` surfaces in Dart DevTools, the Android `adb logcat` stream,
    the iOS device log, and Crashlytics breadcrumbs (when the Crashlytics
    integration is wired). The remaining valid entries are preserved.
  - This way, corrupt data never silently shows "settled up" for a real debt —
    if every entry for a pair is invalid, the row's net is genuinely zero or
    the parse failure is observable downstream.
  - Tests inject a custom `FriendshipParseFailureSink` via the
    `FirestoreFriendshipStore` constructor to inspect the callback contract
    without spinning up Firestore.
- `FriendListItem` (`lib/features/friends/domain/friend_list_item.dart`) is the
  UI-facing projection: `friendshipId`, `otherUserId`, `displayName`,
  `photoUrl`, and `netBalancePaise: int`. The provider returns the structured
  integer; the widget invokes the shared formatter for display.

### 4. Friend display-name resolution: cached family provider (Option B)

The `friendships` doc carries `memberIds` (UIDs only); the friend's display
name and photo URL live on `users/{otherUserId}`. Choice: **Option B from
the prompt's Phase 2.4** — a `userProfileProvider.family(uid)` of type
`FutureProvider.family<UserModel?, String>` caches each lookup. The
`friendsListProvider` stream resolves each friend's profile via
`await ref.read(userProfileProvider(otherUid).future)` and projects in parallel
via `Future.wait`.

- Profile reads are **one-shot/cached** by intent for v1.0. If a friend updates
  their display name mid-session, the list does not live-update the name until
  the user reopens the friends tab or the family is invalidated. This is
  documented as an intentional trade-off; we revisit if it surfaces as a UX
  issue.
- If a profile lookup fails (deleted user doc, rules-denied edge case), the
  row falls back to `displayName: "Unknown"` with the avatar omitted. The
  balance still renders correctly because it derives from the friendship doc,
  not the user doc. A provider test asserts this fallback.
- **Defensive drop on degenerate `memberIds`.** A friendship doc whose
  `memberIds` does not contain a distinct other user (empty list, single
  member, or a list where every entry equals `currentUserId`) is **dropped**
  from the projected list and surfaced via
  `developer.log(name: 'friendship_parse_failure', level: 900)`. No "self
  row" — i.e. a row that resolves the current user's own profile — is ever
  rendered. Firestore Security Rules already require exactly two members on
  write (`firestore.rules` and `functions/test/firestore-rules/friendships.test.ts`),
  so this branch only fires for data that bypasses the production rules; the
  drop keeps the UI honest if such corruption ever appears.

### 5. Real-time updates via Firestore snapshot listener

The `friendsListProvider` directly subscribes to the snapshot stream. Updates
to `simplifiedBalances` or `lastActivityAt` flow through automatically;
Firestore's `orderBy('lastActivityAt', desc)` owns the ordering — no
client-side sort is performed. AC-6 is verified by repository tests (re-order
on `lastActivityAt` change) and the integration stub (end-to-end seeding +
mutation).

### 6. Friend-detail navigation stub: minimal placeholder screen (Option A)

A new `FriendDetailPlaceholderScreen` is pushed when a row is tapped. The
screen displays a generic "Friend details coming soon" message and a back
button. **It does not display the raw `friendshipId`** — even though it's a
deterministic composite, the ID is composed of two UIDs and is PII-adjacent.

- Why Option A over a SnackBar (Option B): the placeholder participates in
  the Navigator stack, which lets the AC-6 integration test walk
  open → tap → back → real-time update.
- Removal moment: the FR-FR-04 PR replaces
  `FriendDetailPlaceholderScreen` with the real Friend Detail screen
  (`SCR-11`). The route call site in the list tile stays the same; only the
  destination widget changes.

### 7. Telemetry — single-fire + hashed identifiers

- `friends_list_viewed` fires exactly **once per screen instance**, on first
  paint of the populated or empty state. A `ConsumerStatefulWidget` with a
  `_loggedView` boolean guards re-emission; widget tests assert that snapshot
  updates and rebuilds do not duplicate the event.
- `friend_row_tapped` includes a `friendship_id` parameter that is the
  SHA-256 hash of the raw friendshipId, truncated to the first 16 hex chars.
  The hash utility lives at `lib/core/telemetry/event_id_hash.dart` and is
  the canonical helper for any other event that needs an opaque correlation
  ID. Raw friendshipIds and UIDs must never appear in analytics parameters,
  Crashlytics breadcrumbs, or log output (the PII-leak test enforces this).
- `friends_empty_add_tapped` carries no parameters.

A companion update to `docs/design/07-technical/telemetry-plan.md` is shipped
in the same PR so the plan, story, and SCR-09 spec converge on the hashed
`friendship_id` parameter and the single-fire `friends_list_viewed`
behaviour.

### 8. Composite index declaration

The `memberIds (array-contains) + lastActivityAt (desc)` composite is the only
index Firestore demands for this query. Devops adds it to
`firestore.indexes.json` in the same PR and deploys it before the merge
ceremony — without the live index, the populated state fails with
`FAILED_PRECONDITION`.

### 9. No new ADR required

All moves above are within the precedent of ADR-0001 (simplified debts as the
sole debt mechanism), ADR-0002 (paise integer arithmetic), and ADR-0013/0014
(PII handling and Cloud Function gateway for lookups). If a future PR
introduces denormalisation of `displayName` onto the friendship doc — a real
tradeoff with PII implications — that escalates to a new ADR before
implementation.
