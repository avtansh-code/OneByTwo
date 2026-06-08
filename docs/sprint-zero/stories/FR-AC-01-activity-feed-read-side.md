# FR-AC-01: Activity Feed Read-Side + Settlement-Trigger Activity Emission

> Implementation-ready user story for the **first reader of the
> `activity/{userId}/items/{itemId}` collection** in the OneByTwo
> application. Ships the SCR-25 Activity Feed screen, the FR-AC-02
> in-app deep-link routing, the four `activity_*` client-side
> telemetry events, the `OBTActivityRow` widget primitive, and the
> reusable `lib/features/activity/**` feature folder. Closes the
> symmetric write-side TODO at
> `functions/src/triggers/on-settlement-write/function.ts:231` by
> extending the settlement trigger to emit `settlement` activity items
> via the reusable `activity-writer.ts` module shipped in the
> activity-feed write-side story (FR-EX-07). The settlement-trigger
> extension is bundled because the settlement leg of SCR-25 cannot
> render anything without it — every settlement recorded since the
> settlement-trigger first shipped has produced ZERO activity items;
> closing the seam now means the moment the read-side lands, the
> settlement column of the feed has data.

---

## SRS Requirement ID(s)

FR-AC-01 (SRS section 4.7 lines 236-240 — "Each user shall have an
activity feed showing all events involving them. Items shall be
ordered by recency"; P0), FR-AC-02 (SRS section 4.7 — "Tapping an
activity item shall navigate to the relevant entity (expense, group,
or friend) where the user can view full details"; P0). The story also
satisfies the symmetric write-side requirement implicit in the SCR-25
Event Type Mapping (line 308) for the `settlementRecorded` event type.

## Relevant SRS Sections

- Section 4.7 — Activity Feed (FR-AC-01, FR-AC-02)
- Section 5.6 — Accessibility (reduce-motion accommodation; semantic
  labels; live regions)
- Section 5.9 — Localisation (IST timezone for relative timestamps)
- Section 5.10 — Observability (four new client-side analytics events)
- Section 6.3 — Core Screens (Activity feed is item 10)
- Section 7.2 — Firestore schema (`activity/{userId}/items/{itemId}`)
- Section 7.3 — Key architectural decisions (Invariants 1 + 2 on the
  render path)
- Section 7.5 — Security rules (member-read / server-only-write; the
  read predicate is the load-bearing gate this story exercises)

## Priority

**P0 — Must have.** The activity feed is a Core Screen (SRS section
6.3 item 10). FR-AC-01 and FR-AC-02 are both flagged P0 in SRS
section 4.7. The write-side schema and rules block shipped in the
FR-EX-07 story; this story is the read-side that surfaces the data
to users. Without it the activity-write infrastructure has no
consumer.

## Story Points

**8.** Decomposes as:

- 5 SP — client read-side (feature folder, `OBTActivityRow` widget,
  screen with 6 states, real-time `StreamProvider` snapshot listener,
  deep-link routing, telemetry, relative-timestamp formatter).
- 1 SP — settlement-trigger activity-emission extension (reuses
  `activity-writer.ts` from FR-EX-07; new sibling
  `settlement-payload-builder.ts`; validator extension).
- 1 SP — `OBTActivityRow` widget (cross-feature OBT primitive).
- 1 SP — routing wiring + temporary `HomePlaceholderScreen` AppBar
  action + four `activity_*` telemetry events.

Patterns from the FR-EX-07 settlement-trigger and FR-FR-03 friends-
list ship-ratified architecture (`StreamProvider`, strict-parse,
boundary-contract grep, telemetry hashing) are reused; this story
does not re-derive them.

## User Story

As a **signed-in user**,
I want **a chronological feed of all events involving me — expenses
my friends and I have added, edited, or deleted, and settlements
we have recorded** with **the ability to tap any row and navigate
straight to the underlying entity**,
so that **I always know what's happened on our shared finances
without having to drill into each friendship individually, and so
that I can quickly view full details on any change I see in the feed**.

## Preconditions

1. The signed-in user has at least one friendship with activity
   items already written by the FR-EX-07 trigger extension OR by the
   settlement-trigger activity emission this story ships.
2. The `activity/{userId}/items/{itemId}` rules block exists in
   `firestore.rules` (shipped with FR-EX-07; member-read /
   server-only-write).
3. The Firebase Emulator Suite is available for pre-merge integration
   testing (Firestore on port 8181, Functions on port 5001 per
   `firebase.json`).
4. The `onSettlementWrite` trigger is deployed to `asia-south1`
   (Mumbai) per SRS section 7.1 and is the sole producer of
   `simplifiedBalances` for settlement events (FR-SE-05/06).
5. The reusable `activity-writer.ts`, `payload-builder.ts`, and
   `activity-validator.ts` modules from FR-EX-07 exist at
   `functions/src/triggers/on-expense-write/` and are ready to be
   reused by the settlement-trigger extension this story ships.

---

## Acceptance Criteria

### Client read-side — positive ACs

#### AC-1 — Activity tab renders chronological feed of friendship-expense events

> Given a signed-in user is a member of friendships with at least one
> create / edit / soft-delete activity item each in
> `activity/{currentUid}/items`
> When the user navigates to `/activity` (via the temporary
> `HomePlaceholderScreen` AppBar action that ships in this story)
> Then the screen displays an `OBTActivityRow` per item in reverse-
> chronological order (by `createdAt` desc) with the correct icon,
> colour, primary text, secondary text (relative timestamp), and
> trailing amount per the SCR-25 Event Type Mapping at lines 301-313
> And the per-row primary text resolves the OTHER party's display
> name via the existing `userProfileProvider` (e.g. "Priya added
> 'Dinner at Dosa Plaza'" — NOT "uidA added 'Dinner at Dosa Plaza'").

#### AC-2 — Settlement-recorded rows render after the settlement-trigger extension lands

> Given a settlement is recorded between two friends
> When the new `onSettlementWrite` activity emission writes one item
> per party to `activity/{fromUserId}/items` AND
> `activity/{toUserId}/items`
> Then the SCR-25 row renders with the `check_circle` icon (`success`
> colour) and primary text:
> - "You settled up with [other party]" when `currentUid ==
>   fromUserId`
> - "[other party] settled up with you" when `currentUid == toUserId`
> And the trailing amount is the settlement amount formatted via
> `formatInrFromPaise(amountPaise)`.

#### AC-3 — Real-time updates via snapshot listener

> Given the Activity screen is open in Populated state
> When a new activity item is written to `activity/{currentUid}/items`
> (e.g. by a friend adding an expense in another session, or by the
> settlement-trigger after a settlement is recorded)
> Then the row appears at the top of the feed within the
> `StreamProvider`'s next emission
> And no manual refresh is required.

#### AC-4 — FR-AC-02 deep-link routing

> Given the user taps an activity row
> When the event type is `expenseAdded` or `expenseEdited`
> Then the app navigates to the Expense Detail screen for
> `payload.expenseId` within `payload.friendshipId` (uses the existing
> `ExpenseDetailScreen` route shipped in FR-EX-06)
> And when the event type is `settlementRecorded`, navigates to the
> Friend Detail screen for the other party
> And when the event type is `expenseDeleted` (the target no longer
> exists), displays an info snackbar with the copy "This item is no
> longer available." per the SCR-25 line 341 contract and remains on
> the Activity feed.

#### AC-5 — Relative timestamp format per SCR-25 lines 314-326

> Given any `createdAt` timestamp
> When rendered
> Then the relative-timestamp string matches the SCR-25 table exactly:
> - `< 1 min` → "Just now"
> - `1-59 min` → "X min ago"
> - `1 hour` → "1 hour ago"
> - `2-23 hours` → "X hours ago"
> - `1 day` → "Yesterday"
> - `2-6 days` → "X days ago"
> - `7+ days, same year` → "dd MMM" (e.g. "14 Mar")
> - `previous year` → "dd MMM yyyy" (e.g. "28 Dec 2024")
> And all timestamps are rendered in IST (`Asia/Kolkata`) per SRS
> section 5.9.

#### AC-6 — Empty state

> Given the `activity/{currentUid}/items` collection has zero
> non-malformed documents
> When the screen loads
> Then the empty state displays with title "All quiet here" and
> subtitle "Your activity will show up as you add expenses and settle
> up."
> And the SCR-25 "Add Expense" CTA is rendered (deferred to a
> future PR when the multi-context FAB chooser ships; for v1.0 the
> CTA is a placeholder button that surfaces an info snackbar).

#### AC-7 — Loading state

> Given the screen first opens with no cached data
> When the snapshot listener is still resolving
> Then a 5-row skeleton loader displays with a shimmer animation
> (suppressed to static grey if `MediaQuery.disableAnimations` is
> `true` per SRS section 5.6 reduce-motion accommodation).

#### AC-8 — Error state

> Given the snapshot listener errors (e.g. `permission-denied` if the
> rules block is somehow violated — defence-in-depth)
> When the screen renders
> Then the error state displays with title "Something went wrong",
> subtitle "We could not load your activity. Please try again.", and
> a "Retry" button that re-establishes the listener via
> `ref.invalidate(activityFeedProvider)`.

#### AC-9 — Pull-to-refresh

> Given the Populated state
> When the user pulls to refresh
> Then the platform-native `RefreshIndicator` animates and the
> snapshot listener re-subscribes via `ref.invalidate(activityFeedProvider)`
> And on success the indicator dismisses
> And on failure an error snackbar displays with the copy "Could not
> refresh. Check your connection and try again."

### Server-side settlement-trigger extension — positive ACs

#### AC-10 — Settlement create writes a `settlement` activity item to BOTH parties

> Given a `settlements/{settlementId}` document is created with
> `fromUserId: uidA, toUserId: uidB, amountPaise: N,
> contextType: 'friendship', contextId: 'uidA_uidB'`
> When the `onSettlementWrite` trigger handles the event AFTER the
> successful `recomputeAndWrite` branch
> Then TWO activity items are written — one at
> `activity/{uidA}/items/{auto-id}` and one at
> `activity/{uidB}/items/{auto-id}`
> And each has `type: 'settlement'`
> And each has `payload: { settlementId, fromUserId, toUserId,
> amountPaise, contextType, contextId, note?, authorUid }`
> And each has `createdAt: <server timestamp>` (Firestore-side
> `FieldValue.serverTimestamp()`, symmetric with the FR-EX-07 contract).

#### AC-11 — Settlement soft-delete does NOT emit an activity item (v1.0 decision)

> Given a settlement is soft-deleted (`deleted: false -> true`)
> When the `onSettlementWrite` trigger handles the update
> Then NO activity item is written
> Rationale: the SCR-25 Event Type Mapping at line 308 does not
> include a `settlementDeleted` row type; settlement deletion is
> extremely rare per FR-SE-07; the v1.0 contract is "no activity item
> on settlement soft-delete". Documented in code as a comment in the
> settlement-trigger handler's update branch. (Architect Notes §2.2
> ratifies.)

#### AC-12 — Settlement activity emission happens AFTER the recomputeAndWrite success branch

> Given a transient `recomputeAndWrite` failure (network error,
> transaction abort, BALANCE_INVARIANT_VIOLATED, INTERNAL,
> CONTEXT_NOT_FOUND, or stale-event drop)
> When the trigger handler runs
> Then NO activity items are written for the failed branch
> And the retry on the next trigger invocation handles both the
> recompute AND the activity emission together
> Symmetric with the FR-EX-07 AC-5 contract.

#### AC-13 — Settlement payload validator rejects malformed inputs

> Given a programmatically-malformed payload (e.g. missing
> `fromUserId`, missing `toUserId`, non-integer `amountPaise`, or
> missing `contextType`)
> When `validateActivityPayload('settlement', payload)` is called
> Then it throws BEFORE any Firestore I/O
> And the trigger's outer try/catch contains the throw, logs
> `activity_emission_internal_error`, and does NOT propagate the
> failure to the trigger's success branch
> Mirrors the FR-EX-07 AC-18 contract.

### Cross-cutting and negative ACs

#### AC-14 — Telemetry events fire correctly

> Given the four new client-side events
> (`activity_feed_viewed`, `activity_item_tapped`,
> `activity_feed_refreshed`, `activity_feed_error`)
> When each is emitted
> Then the parameters match SCR-25 lines 347-354 exactly:
> - `activity_feed_viewed`: `item_count: int`
> - `activity_item_tapped`: `event_type: string`, `entity_id: string`
> - `activity_feed_refreshed`: `success: bool`
> - `activity_feed_error`: `error_code: string`
> And the `activity_item_tapped` event's `entity_id` parameter is
> hashed via `hashFriendshipId()` from
> `lib/core/telemetry/event_id_hash.dart` (ADR-0013, 16 hex chars)
> WHEN the entity is a friendship composite UID; single-UID and
> expense-ID entities are NOT subject to ADR-0013 hashing per the
> memory ratified in FR-FR-03 (the friendship composite is the
> sensitive identifier — opaque scalar IDs are not).

#### AC-15 — Invariant 1 boundary contract (client)

> Given the PR diff
> When scanned for `.toDouble()`, `parseFloat`, `/ 100`, `.toFixed`,
> or `double ` declarations on monetary fields
> Then ZERO violations exist anywhere in `lib/features/activity/**`
> or `lib/core/widgets/lists/obt_activity_row.dart`
> And the new boundary-contract grep at
> `test/features/activity/activity_boundary_contract_test.dart` is
> the affirmative test (mirrors
> `test/features/expenses/expense_creation_boundary_contract_test.dart`).

#### AC-16 — Invariant 2 negative guard

> Given the PR diff
> When scanned
> Then ZERO new writes to `simplifiedBalances` exist anywhere
> And the client surface is read-only on `activity/{currentUid}/items`
> And the settlement-trigger extension touches only `activity/**`,
> NOT `simplifiedBalances` (the existing `recomputeAndWrite` is
> unchanged).

#### AC-17 — PII hashing on telemetry

> Given the `activity_item_tapped` event fires for a row whose
> deep-link target is a friendship composite UID
> When the event parameters are inspected
> Then the `entity_id` is the SHA-256-truncated hash via
> `hashFriendshipId()` from `lib/core/telemetry/event_id_hash.dart`
> (16 hex chars)
> And the affirmative test lives in
> `test/features/activity/presentation/activity_feed_screen_test.dart`.

#### AC-18 — Integration test extension (settlement-trigger)

> Given the PR diff
> When `functions/test/integration/on-settlement-write.integration.test.ts`
> is inspected
> Then TWO new round-trip tests exist:
> 1. Settlement create-then-read for both parties asserting per-party
>    activity-item count == 1, `type == 'settlement'`, and key
>    payload fields (`fromUserId`, `toUserId`, `amountPaise`,
>    `contextType`, `contextId`).
> 2. Settlement soft-delete asserts NO new activity item appears for
>    either party after the delete (per AC-11).

---

## Telemetry Events

Client-side Firebase Analytics events via the existing
`analyticsServiceProvider` abstraction. All events are PII-free per
SRS section 5.4 and ADR-0013. Friendship IDs are hashed via
`hashFriendshipId()` from `lib/core/telemetry/event_id_hash.dart`
(SHA-256 truncated to 16 hex chars). Single-UID and expense-ID
entities are NOT hashed (opaque scalar IDs are not the ADR-0013
target).

| Event name | Parameters | Trigger | SRS Reference |
|---|---|---|---|
| `activity_feed_viewed` | `item_count: int` | Screen opens in Populated or Empty state (fired ONCE per session per SCR-25 telemetry contract) | SRS section 5.10 |
| `activity_item_tapped` | `event_type: string`, `entity_id: string` | User taps an activity row. `entity_id` is hashed via `hashFriendshipId()` when the deep-link target is a friendship composite UID; otherwise the raw opaque ID is used. | SRS section 5.10 |
| `activity_feed_refreshed` | `success: bool` | Pull-to-refresh completes (success or failure) | SRS section 5.10 |
| `activity_feed_error` | `error_code: string` | The snapshot listener emits an `AsyncError` | SRS section 5.10 |

Naming follows the verb-past pattern (Camp B) ratified in PR #38
chore #25 (`expense_save_succeeded`, `expense_save_failed` etc.).
`activity_feed_viewed` parallels `friends_list_viewed`;
`activity_item_tapped` parallels `friend_row_tapped`.

**Server-side structured-log events** (settlement-trigger extension):
the same three event constants from FR-EX-07
(`activity_item_written`, `activity_item_write_failed`,
`activity_emission_completed`) are reused with `eventType: 'settlement'`
discriminator; no new event names are introduced server-side. The
existing PII guard applies — every UID-derived parameter is hashed
via `hashId()`.

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | **Applicable on the SCR-25 render path.** The trailing amount on `OBTActivityRow` MUST use `formatInrFromPaise(int)` from `lib/core/formatters/inr_formatter.dart`. ZERO inline `/100` arithmetic anywhere in `lib/features/activity/**` or `lib/core/widgets/lists/obt_activity_row.dart`. The new boundary-contract grep at `test/features/activity/activity_boundary_contract_test.dart` is the affirmative test. The Functions-side settlement-payload builder preserves the integer invariant — `amountPaise` is passed through unchanged from the source settlement doc; the existing Functions-side boundary-contract grep at `functions/test/boundary-contracts/no-double-on-money-fields.test.ts` auto-covers the new file. |
| 2 | `simplifiedBalances` server-maintained | **N/A on the activity-read path.** The client reads `activity/{currentUid}/items`, NOT `simplifiedBalances`. The settlement-trigger extension touches only `activity/**`; the existing `recomputeAndWrite` is unchanged. AC-16 is the explicit negative-guard test. |
| 3 | System share sheet only | N/A. The activity-feed screen has no outbound sharing surface. |
| 4 | Single Firebase project | **Applicable — defence-in-depth.** The new client surface targets the single production project; the settlement-trigger deployment is an in-place handler update; `.firebaserc` is unchanged. |

PII / ADR-0013 compliance: the `activity_item_tapped` event hashes
the `entity_id` parameter via `hashFriendshipId()` when the entity is
a friendship composite UID. Other entity types (`expenseId`,
`settlementId`) are opaque auto-generated Firestore IDs and are NOT
subject to ADR-0013 per the memory ratified by FR-FR-03 architect
notes (the friendship composite is the sensitive identifier; opaque
scalar IDs are not). The server-side structured-log events
(`activity_item_written` etc.) continue to hash every UID-derived
parameter per the existing FR-EX-07 contract — no change to the
server-side PII posture.

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Cloud Functions settlement-trigger handler deployed in-place to
      `asia-south1` (Mumbai) — verified via the manual smoke matrix
      in the PR body.
- [ ] Flutter widget tests pass (the new Activity-feature widget
      tests + the OBTActivityRow widget tests).
- [ ] Cloud Functions unit tests pass — at least 10 new tests
      across `settlement-payload-builder.test.ts`,
      `activity-validator.test.ts` (extended), and
      `function.test.ts` (extended).
- [ ] Security-rules unit tests pass UNCHANGED at 188 (no rules
      diff in this PR).
- [ ] Integration tests pass — 2 new round-trip tests per AC-18 in
      `on-settlement-write.integration.test.ts`.
- [ ] Boundary-contract grep at
      `test/features/activity/activity_boundary_contract_test.dart`
      returns 0 violations.
- [ ] Functions-side boundary-contract grep at
      `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`
      returns 0 violations (auto-covers the new payload-builder).
- [ ] `dart format --set-exit-if-changed .` exits 0.
- [ ] `flutter analyze --fatal-infos` returns "No issues found".
- [ ] QA manual smoke matrix completed and signed off (Phase 5 step
      11 of `docs/copilot_prompts/sprint_2/15.md`).
- [ ] Telemetry events in place; PII hashing verified by the screen
      widget test affirmative assertion (AC-17).
- [ ] Invariant compliance confirmed (Invariants 1 + 4 applicable;
      Invariant 2 negative-guard test green; Invariant 3 N/A).
- [ ] Coverage gate green (Flutter overall ≥ 50% on changed lines;
      new Activity feature folder ≥ 70%).
- [ ] Documentation updated: `sprint-2-plan.md` (PR #52 row, 8 SP,
      cumulative 63 SP / 16 PRs); `next-three-prs.md` (PR #53 / #54 /
      #55 candidates); `07-bucket-b-burndown.md` (PR #52 entry).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Invariant 1 (paise): applicable on the SCR-25 render path. The
      `OBTActivityRow` trailing amount uses `formatInrFromPaise(int)`;
      ZERO inline `/100` arithmetic anywhere in
      `lib/features/activity/**`. The new boundary-contract grep is
      the affirmative test. The Functions-side payload builder
      preserves the integer invariant (passes `amountPaise` through
      unchanged); the existing Functions-side boundary-contract grep
      auto-covers.
- [ ] Invariant 2 (`simplifiedBalances` server-only): the existing
      single-writer enforcement is unchanged. ZERO new writes to
      `simplifiedBalances` in the PR diff (AC-16 is the explicit
      negative-guard test). The client reads `activity/{uid}/items`,
      NOT `simplifiedBalances`.
- [ ] Invariant 3 (system share sheet only): N/A in this story.
- [ ] Invariant 4 (single Firebase project): compliant — production
      only, with emulator-backed pre-merge verification.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec — Activity Feed (SCR-25) | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` lines 256-386 |
| Firestore schema (`activity/{userId}/items/{itemId}`) | `docs/design/07-technical/firestore-schema.md` lines 194-211 |
| Component catalogue (OBTActivityRow) | `docs/design/02-design-system/components.md` section 14 |
| Cloud Functions catalogue (`onSettlementWrite`) | `docs/design/07-technical/cloud-functions-catalogue.md` |
| Existing trigger handler (FR-SE-05/06, FR-EX-07) | `functions/src/triggers/on-settlement-write/function.ts`, `functions/src/triggers/on-expense-write/function.ts` |
| Existing FR-EX-07 story (settlement-trigger reuse contract) | `docs/sprint-zero/stories/FR-EX-07-activity-feed-write-side.md` |
| Existing FR-FR-03 story (StreamProvider blueprint) | `docs/sprint-zero/stories/FR-FR-03-friends-list.md` |
| ADR — Riverpod state management | `.github/shared/decision-log.md` ADR-0006 |
| ADR — Feature-first folder layout | `.github/shared/decision-log.md` ADR-0007 |
| ADR — PII / telemetry hashing | `.github/shared/decision-log.md` ADR-0013 |
| ADR — Rules-readable user collection | `.github/shared/decision-log.md` ADR-0014 |
| Feature-PR conventions | `docs/patterns/feature-pr-conventions.md` |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| PM | Story authorship, AC clarity, scope discipline (no widening to FCM push notifications, notification preferences, cold-start deep-link, OBTBottomNav shell, OBTRupeeText primitive, group-context activity emission, read/unread markers, pagination, filter/search, or settlement-deleted activity items; those are separate stories or future work). |
| Architect | Bottom-nav shell deferral, settlement soft-delete decision, activity-writer reuse-vs-rename decision, settlement payload schema, provider granularity, OBTActivityRow widget API, files-to-touch / files-not-to-touch, anticipated reconciliations. |
| Cloud Functions Dev | Settlement-payload-builder + validator extension + ActivityItemType extension + settlement-trigger handler extension + function-boundary tests + integration-test extension. |
| Flutter Dev | `lib/features/activity/**` feature folder (data / domain / application / presentation), `OBTActivityRow` primitive, `/activity` route wiring, `HomePlaceholderScreen` AppBar action, all client-side widget + provider + formatter tests. |
| DevOps | No new CI workflow changes; the new tests run in the existing CI jobs (`flutter test`, `npm test`, `npm run test:integration` inside `firebase emulators:exec`). |
| QA | Manual smoke matrix sign-off (Phase 5 step 11), DoD §3 sign-off with evidence for: (a) cross-user real-time render of expense events; (b) settlement-trigger writes both parties' activity items end-to-end; (c) deep-link routing per the SCR-25 table; (d) pull-to-refresh behaviour per AC-9; (e) settlement-deleted does NOT emit an activity item per AC-11. |

---

## Technical Notes

- **Settlement-trigger entry-point:**
  `functions/src/triggers/on-settlement-write/function.ts` is extended
  in place. The new activity-emission helper (`emitSettlementActivity`)
  lives AFTER the successful `simplified_debts_compute_completed` log
  at the bottom of the handler, mirroring the FR-EX-07
  `emitExpenseActivity` placement.
- **Region:** `asia-south1` (Mumbai). The trigger is already
  registered there; this PR is an in-place handler extension.
- **Retry:** the trigger's existing retry posture is unchanged.
  Settlement-activity-emission failures are CONTAINED inside the
  outer try/catch (mirror of the FR-EX-07 contract) — a per-member
  activity-write failure does NOT propagate to the trigger's success
  branch, so Cloud Functions does NOT retry the whole trigger on
  activity-write failures.
- **Two writes per invocation:** the activity-writer writes ONE
  document per settlement party. For the two-party friendship
  settlement context (v1.0; groups are Sprint 3), that is exactly TWO
  documents per trigger invocation.
- **Soft-delete decision:** the settlement-trigger update branch
  detects `before.deleted === false && after.deleted === true` and
  SKIPS the activity emission entirely. Documented in code as a
  comment. No `settlementDeleted` discriminator is introduced. (See
  Architect Notes §2.2 for rationale.)
- **Activity-writer reuse:** the existing `writeExpenseActivity`
  function name is retained (the rename to `writeContextActivity`
  recommended by the prompt §2.3 is DEFERRED per Architect Notes §2.3
  to minimise blast radius and avoid breaking the existing PR #51
  tests + Cloud Logging dashboards). The settlement-trigger calls
  `writeExpenseActivity({friendshipId: contextId, expenseId:
  settlementId, eventType: 'settlement', payload, memberIds})` with a
  code comment documenting the misnomer.
- **Client snapshot listener:** `activityFeedProvider` is a single
  `StreamProvider<List<ActivityFeedItem>>` (NO `family` parameter)
  over `FirebaseFirestore.collection('activity').doc(currentUid)
  .collection('items').orderBy('createdAt', descending: true)
  .snapshots()`. The current UID is read from the existing
  `currentUserIdProvider` from FR-FR-03.
- **Strict parsing:** the repository's snake_case → camelCase mapper
  drops malformed payloads silently and reports each drop via a
  structured-log callback (mirrors the `FriendshipDoc.fromFirestore`
  pattern from FR-FR-03). Unknown event types are dropped (group
  events are not yet emitted but the schema enumerates them; the
  client is forward-compatible).
- **Display name resolution:** the SCR-25 primary text needs the
  OTHER party's display name (e.g. "Priya added 'Dinner'"). The
  existing `userProfileProvider` from FR-FR-03 is the canonical
  accessor; it is rules-readable for friendship members per PR #35
  (FR-FR-03 architect notes §4).
- **Test paths:**
  - `functions/test/triggers/on-settlement-write/settlement-payload-builder.test.ts`
    — NEW unit tests for the pure mapping function.
  - `functions/test/triggers/on-expense-write/activity-validator.test.ts`
    — EXTEND with `validateSettlementPayload` tests.
  - `functions/test/triggers/on-settlement-write/function.test.ts`
    — EXTEND with assertions that the activity-writer is invoked from
    the trigger on the create success branch and NOT invoked on the
    soft-delete / CONTEXT_NOT_FOUND / BALANCE_INVARIANT_VIOLATED /
    stale-event-drop branches.
  - `functions/test/integration/on-settlement-write.integration.test.ts`
    — EXTEND with 2 new round-trip tests per AC-18.
  - `test/features/activity/domain/activity_feed_item_test.dart` —
    NEW parser + drop-malformed tests.
  - `test/features/activity/application/activity_feed_provider_test.dart`
    — NEW provider unit tests using `ProviderContainer` overrides.
  - `test/features/activity/application/relative_timestamp_formatter_test.dart`
    — NEW boundary-case tests for every SCR-25 timestamp range.
  - `test/features/activity/presentation/activity_feed_screen_test.dart`
    — NEW widget tests for Loading / Populated / Empty / Error /
    Refreshing states.
  - `test/features/activity/activity_boundary_contract_test.dart` —
    NEW grep parallel to the expenses-feature contract.
  - `test/core/widgets/lists/obt_activity_row_test.dart` — NEW widget
    tests for the OBTActivityRow primitive across all event types.

---

## Out of Scope (explicitly deferred — hand-off seams documented in code)

- **`OBTBottomNav` shell.** Separate UX PR; the temporary
  `HomePlaceholderScreen` AppBar action is the v1.0 entry point. The
  bottom-nav shell is needed when Friends + Groups + Activity +
  Profile tabs are all needed simultaneously (likely Sprint 3
  alongside the groups epic).
- **`OBTRupeeText` primitive.** Separate OBT-primitives PR; the
  `OBTActivityRow` trailing amount uses inline
  `Text(formatInrFromPaise(amountPaise))` (a 5-line wrapper that
  adds no semantic value beyond what `OBTActivityRow` itself needs).
  See Architect Notes §2.6.
- **FR-AC-03 — FCM push notifications.** Separate P0 story;
  introduces the FCM dependency + the `notificationPrefs` schema +
  per-user `fcmTokens` plumbing.
- **FR-AC-04 — notification preferences.** Paired with FR-AC-03.
- **FR-AC-05 — cold-start deep-link.** Paired with FR-AC-03 (the
  cold-start signal comes from FCM).
- **Group-context activity emission.** Sprint 3 groups epic (the
  `onExpenseWriteGroup` and `onSettlementWrite` group-context
  activity emission).
- **Read/unread markers.** SCR-25 Open Question 1; v1.1 candidate
  per the SCR.
- **Pagination / cursor-based read.** SCR-25 Open Question 2; v1.0
  loads all activity items via the single snapshot listener.
  Architect Notes §2.9 item 8 flags the cutoff at which performance
  degrades (~1000 items).
- **Filter / search within activity.** SCR-25 Open Question 3;
  deferred.
- **`settlementDeleted` activity items.** v1.0 decision per
  Architect Notes §2.2 — soft-delete does NOT emit an activity item.
- **Cosmetic rename of `writeExpenseActivity` → `writeContextActivity`.**
  Deferred per Architect Notes §2.3 — keeps PR #51 tests and Cloud
  Logging dashboards untouched. Future cleanup PR may rename the
  function, type, and log-key (`expenseIdHash` → `entityIdHash`) as
  a single focused change.
- **Issue #47 — Firestore rules-hardening for non-creator
  update/delete.** Separate small chore PR.
- **Issue #49 — Orphan-cleanup Cloud Function for receipts.** FUTURE.
- **Issue #50 — Trigger no-op-recompute optimisation.** EXPLICITLY
  REFUSED for bundling — would BREAK FR-EX-07 AC-2.
- **Concurrent-edit detection for FR-EX-06.** Still deferred.
- **Rate-limit transaction race refactor.** Still deferred.

---

## Architect Notes

> Appended for the FR-AC-01 activity-feed read-side PR. These notes
> ratify the design decisions taken before implementation begins.
> References: `docs/copilot_prompts/sprint_2/15.md`,
> `.github/shared/invariants.md`, `.github/shared/decision-log.md`
> (ADR-0002 paise integers; ADR-0006 Riverpod state management;
> ADR-0007 feature-first folder layout; ADR-0013 PII / telemetry
> hashing; ADR-0014 rules-readable user collection).

### 2.1 — Bottom-nav shell deferral

**RATIFY: PR #52 does NOT ship `OBTBottomNav`.**

The `/activity` route is reachable via a temporary "Activity" AppBar
action on `HomePlaceholderScreen` (mirror of the existing "Profile"
action at `home_placeholder_screen.dart:21-31`). The bottom-nav
shell is a separate UX PR that lands when Friends + Groups +
Activity + Profile tabs are all needed simultaneously (likely Sprint
3 alongside the groups epic).

Rationale:

- The bottom-nav infrastructure is a significant UX surface that
  warrants its own PR. Bundling it would push this PR well past 10
  SP into scope creep.
- The standalone `/activity` route is the canonical SCR-25 contract
  (line 265). The bottom-nav binding is a presentational concern
  that lands when the tab shell ships.
- Friends and Groups tabs also don't have routes yet. Shipping
  bottom-nav with only an Activity tab wired in would leave it
  visually broken.

### 2.2 — Settlement soft-delete activity decision

**RATIFY: settlement soft-delete does NOT emit an activity item.**

Rationale:

- The SCR-25 Event Type Mapping at line 308 only lists
  `settlementRecorded`. There is NO `settlementDeleted` row type in
  the spec.
- Settlement deletion is extremely rare per the FR-SE-07 contract.
- The v1.0 decision is "no activity item on settlement soft-delete".
- The settlement-trigger update branch detects
  `before.deleted === false && after.deleted === true` and SKIPS
  the activity emission entirely. Documented in code as a comment.
- Hard-delete (admin-only via admin SDK) is also a no-op for activity
  emission — symmetric with the no-op posture for soft-delete.

If observed as a UX gap in production, file an issue for v1.1
consideration (would require both schema enumeration extension AND
SCR-25 spec update — non-trivial).

### 2.3 — Activity-writer reuse vs rename

**RATIFY: keep the function name `writeExpenseActivity` (DEFER the
rename to `writeContextActivity`).**

The prompt §2.3 RECOMMENDED renaming to `writeContextActivity` on
the grounds that the function is generic over the context type and
the "Expense" prefix is now misleading. However, the prompt §2.7
ratified the rename as "OPTIONAL".

Rationale for deferral:

- Minimises blast radius — the existing PR #51 tests
  (`activity-writer.test.ts`, `function.test.ts`) stay untouched.
  Renaming would require updating ~10+ assertion call sites and
  introduces regression risk on a working ship.
- The log key `expenseIdHash` would also rename to `entityIdHash`
  in the existing `activity_item_written`,
  `activity_item_write_failed`, and `activity_emission_completed`
  events. Any Cloud Logging dashboards built post-PR-#51 that pivot
  on `expenseIdHash` would break — and we cannot verify the
  dashboard surface from here.
- The settlement-trigger call site explicitly maps the misnomer in
  a code comment:
  ```typescript
  // The activity-writer's WriteExpenseActivityRequest interface
  // pre-dates the settlement consumer; the field names friendshipId
  // and expenseId are misnomers when the source entity is a
  // settlement. The architect deferred the rename to keep PR #51's
  // tests and the Cloud Logging schema stable. FUTURE-work cleanup
  // PR renames to writeContextActivity + contextId + entityId +
  // entityIdHash.
  await writeExpenseActivity(deps, {
    friendshipId: contextId,    // misnomer: actually contextId
    expenseId: settlementId,    // misnomer: actually entityId
    eventType: "settlement",
    payload,
    memberIds,
  });
  ```
- A follow-up cosmetic-rename PR (1-2 SP, separately filed) can do
  the full rename + log-key migration as a single focused change with
  paired dashboard updates.

If a reviewer prefers the immediate rename, the architect is open to
flipping this decision — the trade-off is well-bounded.

### 2.4 — Settlement payload schema

**RATIFY:** `settlement` payload shape:

```typescript
{
  settlementId: string;
  fromUserId: string;
  toUserId: string;
  amountPaise: number;         // integer (Invariant 1 preserved)
  contextType: "friendship" | "group";
  contextId: string;
  note?: string;               // optional; nullable on the doc
  authorUid: string;           // == fromUserId per the rules
}
```

The validator's per-event-type required-field check enforces
`settlementId`, `fromUserId`, `toUserId`, `amountPaise`,
`contextType`, `contextId`, `authorUid`. The `note` field is
optional (the rules at `firestore.rules:445-455` permit
`note: null` and the schema marks it as optional per
`docs/design/07-technical/firestore-schema.md`).

Notes:

- `authorUid` is canonically the `fromUserId` for v1.0 (settlements
  are created by the payer, per the rules). Symmetric with FR-EX-07's
  `authorUid` being the expense `createdBy`.
- `contextType: 'group'` is permitted in the type union for forward-
  compatibility with the Sprint 3 groups epic, but the settlement-
  trigger handler's group-context path is NOT exercised in this PR
  (no group settlements exist yet). The friendship-context path is
  the only emission path PR #52 ships.
- `amountPaise` is passed through unchanged from the source
  settlement document — Invariant 1 is preserved by construction.

### 2.5 — Riverpod provider granularity

**RATIFY: single `StreamProvider<List<ActivityFeedItem>>` named
`activityFeedProvider`. NO `family` parameter.**

Rationale:

- The provider is per-user. The current UID is read from the
  existing `currentUserIdProvider` (shipped in FR-FR-03 at
  `lib/features/friends/application/friends_list_provider.dart:15`).
- Mirrors the `friendsListProvider` blueprint — same `StreamProvider`
  shape over a Firestore snapshot listener.
- A `family<List<ActivityFeedItem>, String>` would be over-
  engineered: the only legitimate parameter would be `userId`, but
  the entire activity feed is gated by the rules block to the
  authenticated user's own subcollection, so per-user lookup is the
  only legal access pattern.
- `ref.invalidate(activityFeedProvider)` is the canonical re-subscribe
  mechanism used by both the Retry button (AC-8) and the
  pull-to-refresh handler (AC-9).

The current UID is also passed to the `activityFeedRepository`
constructor (which builds the Firestore query path) and to the row-
tap handler (which derives the deep-link target — settlements need
`currentUid` to disambiguate "you settled up with X" vs "X settled
up with you").

### 2.6 — OBTActivityRow widget API

**RATIFY:** the widget consumes a single typed `ActivityFeedItem`
(the domain model) PLUS the resolved other-party display name. The
icon, colour, primary-text, and amount derivation lives inside the
widget per the SCR-25 Event Type Mapping table (lines 301-313).

Placement: `lib/core/widgets/lists/obt_activity_row.dart` — matches
the OBT cross-feature primitive convention established by
`lib/core/widgets/inputs/obt_amount_input.dart` (PR #38) and
`lib/core/widgets/dialogs/obt_confirmation_dialog.dart` (PR #46).

**`OBTRupeeText` is NOT shipped in PR #52.** The component catalogue
declares it (section 5) but no Dart implementation exists today.
The `OBTActivityRow` trailing amount uses
`Text(formatInrFromPaise(item.amountPaise))` inline. A 5-line
wrapper would add no semantic value beyond what `OBTActivityRow`
itself already provides; a future OBT-primitives PR ships
`OBTRupeeText` when a SECOND use site needs it (mirrors the
`OBTAmountInput` precedent — the catalogue contract is locked the
moment a second use site needs it).

API surface:

```dart
class OBTActivityRow extends StatelessWidget {
  const OBTActivityRow({
    required this.item,
    required this.currentUserUid,
    required this.otherPartyDisplayName,
    required this.onTap,
    super.key,
  });

  final ActivityFeedItem item;
  final String currentUserUid;
  final String otherPartyDisplayName;
  final VoidCallback onTap;
  // ...
}
```

The semantic label combines primary text + secondary text + amount
+ "Tap to view details" per SCR-25 line 361.

### 2.7 — Files to touch (exhaustive — anything outside this set is scope creep)

- **NEW** `docs/sprint-zero/stories/FR-AC-01-activity-feed-read-side.md`
  (this file).
- `functions/src/triggers/on-settlement-write/function.ts` — EXTEND
  with the `emitSettlementActivity` helper call after the success-
  branch log at line 315.
- **NEW** `functions/src/triggers/on-settlement-write/settlement-payload-builder.ts`
  — pure function `buildSettlementActivityPayload(changeType,
  request)`.
- `functions/src/triggers/on-expense-write/activity-validator.ts` —
  EXTEND with `validateSettlementPayload` branch.
- `functions/src/triggers/on-expense-write/payload-builder.ts` —
  EXTEND the `ActivityItemType` union with `'settlement'` and the
  `ActivityPayload` discriminated union with `SettlementPayload`.
- `functions/test/triggers/on-settlement-write/function.test.ts` —
  EXTEND with activity-writer integration assertions (mirror of PR
  #51's `function.test.ts` extension at lines 720-1032).
- **NEW** `functions/test/triggers/on-settlement-write/settlement-payload-builder.test.ts`
  — per-change-type mapping tests.
- `functions/test/triggers/on-expense-write/activity-validator.test.ts`
  — EXTEND with settlement-payload validation tests.
- `functions/test/integration/on-settlement-write.integration.test.ts`
  — EXTEND with 2 round-trip tests per AC-18.
- **NEW** `lib/features/activity/data/activity_feed_repository.dart`
- **NEW** `lib/features/activity/domain/activity_feed_item.dart`
- **NEW** `lib/features/activity/domain/activity_event_type.dart`
- **NEW** `lib/features/activity/application/activity_feed_provider.dart`
- **NEW** `lib/features/activity/application/relative_timestamp_formatter.dart`
- **NEW** `lib/features/activity/presentation/activity_feed_screen.dart`
- **NEW** `lib/features/activity/presentation/widgets/activity_feed_skeleton.dart`
- **NEW** `lib/core/widgets/lists/obt_activity_row.dart`
- `lib/features/auth/presentation/home_placeholder_screen.dart` —
  ADD "Activity" AppBar action.
- **NEW** `test/features/activity/domain/activity_feed_item_test.dart`
- **NEW** `test/features/activity/application/activity_feed_provider_test.dart`
- **NEW** `test/features/activity/application/relative_timestamp_formatter_test.dart`
- **NEW** `test/features/activity/presentation/activity_feed_screen_test.dart`
- **NEW** `test/features/activity/activity_boundary_contract_test.dart`
- **NEW** `test/core/widgets/lists/obt_activity_row_test.dart`
- `docs/sprint-zero/sprint-2-plan.md` — PR #52 row.
- `docs/sprint-zero/next-three-prs.md` — roll-forward.
- `docs/audits/sprint-1/07-bucket-b-burndown.md` — PR #52 entry.

### 2.8 — Files explicitly NOT to touch (negative scope guardrails)

- `firestore.rules` — UNCHANGED. FR-EX-07 shipped the activity rules
  block; PR #52 only reads (rules grant member-read).
- `firestore.indexes.json` — UNCHANGED. Single-field descending
  index on `createdAt` auto-creates.
- `storage.rules` — UNCHANGED. No Storage surface.
- `pubspec.yaml` / `functions/package.json` — UNCHANGED. No new
  dependencies.
- `lib/features/expenses/**`, `lib/features/friends/**`,
  `lib/features/settlements/**` — UNCHANGED. The new Activity feature
  reads its own data; no edits to existing features.
- `functions/src/triggers/on-expense-write/function.ts` — UNCHANGED.
  FR-EX-07's expense-trigger emission is correct as-is.
- `functions/src/triggers/on-expense-write/activity-writer.ts` —
  EXTENDED ONLY to include `'settlement'` in the `ActivityItemType`
  type re-export (a single character change). The function body,
  field names, and log keys are UNCHANGED per §2.3.
- `.github/workflows/*.yml` — UNCHANGED.
- `lib/main.dart` — UNCHANGED. The `/activity` route is reachable
  via the `HomePlaceholderScreen` AppBar action using
  `Navigator.of(context).push(MaterialPageRoute(...))` (the
  canonical pattern from FR-EX-06 and FR-FR-03).
- `lib/core/widgets/dialogs/obt_confirmation_dialog.dart`,
  `lib/core/widgets/inputs/obt_amount_input.dart` — UNCHANGED. The
  new `OBTActivityRow` is a sibling primitive.

### 2.9 — Anticipated reconciliations

Document EXACTLY:

1. **Snake_case vs camelCase event-type discriminators.** The
   Firestore document stores `type: 'expense_added'` (snake_case per
   schema doc line 202); the SCR-25 spec uses `expenseAdded`
   (camelCase per lines 305-307). The client mapper in
   `activity_feed_repository.dart` converts on read. Unknown types
   are dropped (mirrors the strict-parsing precedent for
   `simplifiedBalances`).

2. **OBTRupeeText deferral.** The components catalogue declares
   `OBTRupeeText` (section 5) but PR #52 does not implement it. The
   `OBTActivityRow` trailing amount uses
   `Text(formatInrFromPaise(...))` inline. Future OBT-primitives PR
   ships the wrapper. NOT a Bucket-B item.

3. **OBTBottomNav deferral.** Same as §2.1. The temporary
   `HomePlaceholderScreen` AppBar action is the v1.0 entry point
   until the bottom-nav shell lands.

4. **Activity emission on settlement soft-delete.** Per §2.2: no
   activity item. Documented in code as a comment in the settlement-
   trigger handler's update branch.

5. **Settlement activity directional copy.** The primary-text copy is:
   - "You settled up with [other party]" when `currentUid ==
     fromUserId`
   - "[other party] settled up with you" when `currentUid ==
     toUserId`
   The other-party display name is resolved via the existing
   `userProfileProvider` from FR-FR-03. If the profile resolution
   fails (deleted account, transient permission glitch), the
   fallback is "Unknown" — mirrors the FR-FR-03 friends-list
   fallback.

6. **Cold-start deep-link (FR-AC-05) deferral.** PR #52 ships the
   FR-AC-02 in-app deep-link routing. The FR-AC-05 cold-start
   deep-link (from a tapped push notification when the app is not
   running) is paired with FR-AC-03 FCM. Separate P0 story.

7. **Read/unread markers deferral.** SCR-25 Open Question 1. The
   components catalogue defines an `Unread` state for
   `OBTActivityRow` (3 dp `primary` left-edge bar) but PR #52 does
   NOT ship this — every row is rendered as "read". v1.1 candidate
   per the SCR.

8. **Pagination deferral.** SCR-25 Open Question 2. v1.0 loads all
   activity items via the single snapshot listener. Cutoff at which
   performance degrades: rough estimate ~1000 items before the
   frame budget is exceeded (each row is a lightweight
   `OBTActivityRow` with no images beyond the leading icon). FUTURE
   work.

9. **Activity-writer reuse vs rename deferral.** Per §2.3. Future
   cleanup PR may rename `writeExpenseActivity` →
   `writeContextActivity` AND `friendshipId` → `contextId` AND
   `expenseId` → `entityId` AND the log key `expenseIdHash` →
   `entityIdHash` in one focused diff with paired Cloud Logging
   dashboard updates.

10. **Boundary-contract grep co-location.** The new
    `test/features/activity/activity_boundary_contract_test.dart`
    mirrors the existing
    `test/features/expenses/expense_creation_boundary_contract_test.dart`
    template — same `_isCommentLine` helper, same regex patterns,
    same fail-loud assertion shape. Per
    `docs/patterns/feature-pr-conventions.md` boundary-contract
    discipline.

11. **Currentuid for settlement directional copy — coupling to
    OBTActivityRow.** The widget needs `currentUserUid` to render
    the correct directional copy on `settlement` rows. Passing
    `currentUserUid` as a widget prop is a small API surface
    addition; the alternative (resolving via `ref.watch` inside the
    widget) would force `OBTActivityRow` to become a
    `ConsumerWidget`, breaking the OBT-primitive convention of pure
    `StatelessWidget` reusability. Architect's call: prop-pass the
    UID.

