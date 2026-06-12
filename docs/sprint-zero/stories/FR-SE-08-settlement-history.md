# FR-SE-08: Settlement History screen (SCR-24)

> Implementation-ready user story for the dedicated full-history
> settlement screen. Tap a `View Settlement History` text link on the
> Friend Detail screen → push a reverse-chronological list of every
> settlement recorded against that friendship.

---

## SRS Requirement ID(s)

FR-SE-08 (SRS section 4.6 — View settlement history per friend and per
group). PR #42 + PR #43 partially delivered FR-SE-08 via the in-timeline
settlement rows on Friend Detail (top-5). This story closes the **P0
commitment** for the dedicated `/settle/history` surface — the friendship
axis only. The group axis is wired by the Sprint 3 Group Detail screen
PR (the screen TAKES a generic `contextType` argument; only the
friendship arm is wired here).

## Relevant SRS Sections

- Section 4.6 — Simplify & Settle (FR-SE-08).
- Section 5.6 — Accessibility (48x48 dp tap targets, WCAG 2.1 AA
  contrast, dynamic font scaling, screen-reader semantics).
- Section 5.9 — Localisation and internationalisation (`dd MMM yyyy`
  IST date format).
- Section 5.10 — Observability (telemetry contract).
- Section 6.3 items 6 and 7 — Settlement history per friend / per group.
- Section 6.4 — Loading, empty, and error states.
- Section 7.3 — Key architectural decisions (Invariants 1 and 2 —
  read-side only on this surface).
- Section 13.2 — Story format (this document).

## Priority

**P0 — Must have**

## Story Points

3

## User Story

As a **signed-in user**,
I want to **open a dedicated screen listing every settlement I have
recorded with a friend in reverse-chronological order**,
so that **I can review the full payment history beyond the most recent
few rows shown inline on the Friend Detail timeline**.

## Preconditions

1. User is authenticated and a member of the friendship `friendshipId`.
2. The top-level `settlements/{settlementId}` collection is readable by
   members of the context per the rules shipped in PR #37
   (`firestore.rules`). The screen is **read-only**; it never writes.
3. `SettlementRepository.watchByContext({contextType, contextId})`
   (PR #42 read path) returns a `Stream<List<SettlementDoc>>` filtered by
   `contextType + contextId`, ordered by `date` descending, with
   soft-deleted entries already excluded at the repository layer.
4. The Firestore composite index `(contextType ASC, contextId ASC,
   date DESC)` (PR #42) satisfies the canonical query without
   `FAILED_PRECONDITION`. No index change is required.
5. PR #57 has merged: `FriendDetailScreen`, `friendDetailProvider`, and
   the `OBTFloatingActionButton` refactor all exist in production.
6. `simplifiedBalances` is maintained exclusively by the server
   (Invariant 2). This screen reads only `settlements/{id}` documents
   and never references `simplifiedBalances`.
7. The app uses the single configured Firebase project; pre-merge
   verification runs against the Firebase Emulator Suite (Invariant 4).

---

## Acceptance Criteria

### Screen render + state contract

### AC-1 — Populated state renders settlements in date-desc order

> Given `settlementHistoryProvider` returns 3 settlements with dates
> `2025-03-25`, `2025-03-18`, `2025-02-02`
> When the screen is mounted
> Then 3 settlement rows are rendered in that exact order (no
> client-side sort — the repository stream guarantees date-desc).

### AC-2 — Empty state renders the canonical empty placeholder

> Given `settlementHistoryProvider` returns an empty list
> When the screen is mounted
> Then a `Center(Column(...))` with `Icon(Icons.history)` +
> `Text('No settlements yet')` +
> `Text('Once you settle up, it will appear here.')` renders
> And NO Retry button renders (per SCR-24 §States row 3: "No CTA
> button").

### AC-3 — Loading state renders a centred `CircularProgressIndicator`

> Given `settlementHistoryProvider` is `AsyncLoading`
> When the screen is mounted
> Then a `Center(CircularProgressIndicator())` renders.

### AC-4 — Error state renders the canonical error placeholder with Retry

> Given `settlementHistoryProvider` is `AsyncError`
> When the screen is mounted
> Then a `Center(Column(...))` with `Icon(Icons.error_outline)` +
> `Text('Something went wrong')` +
> `Text('We could not load settlement history. Please try again.')` +
> `FilledButton(child: Text('Retry'))` renders
> And tapping Retry calls `ref.invalidate(settlementHistoryProvider(args))`
> and the provider re-subscribes.

### AC-5 — 50-item cap

> Given `settlementHistoryProvider` is fed a 76-item upstream stream
> When projected
> Then the screen renders exactly 50 rows
> And the `settlement_history_viewed` event fires with `item_count: 50`
> (not 76).

### Settlement-row layout contract (per SCR-24 §Settlement Row Layout)

### AC-6 — Date format

> Given a settlement with `date: DateTime(2025, 3, 25)`
> When its row renders
> Then the date is displayed as `'25 Mar 2025'` (per SRS section 5.9
> `dd MMM yyyy`).

### AC-7 — Amount format

> Given a settlement with `amountPaise: 80000`
> When its row renders
> Then the amount is displayed as `'₹800.00'` via
> `formatInrFromPaise(80000)` (Invariant 1).

### AC-8 — Note rendering

> Given a settlement with `note: 'GPay transfer'`
> When its row renders
> Then the note text is visible below the amount
> And given `note: null`, when its row renders, then NO note text
> widget is in the tree.

### AC-9 — Avatar + arrow row

> Given a settlement with `fromUserId: currentUid` + `toUserId: otherUid`
> When its row renders
> Then the payer avatar shows the current user's initials
> And the payee avatar shows the friend's display-name initials
> And a directional arrow icon is between them.

### AC-10 — Row tap target

> Given any settlement row
> When measured
> Then its rendered height is >= 64 dp (per SCR-24 §Settlement Row
> Layout last paragraph).

### Accessibility (per SCR-24 §Accessibility)

### AC-11 — Screen title semantic header

> Given the screen is mounted
> When scanned for semantics
> Then a semantic node with label `'Settlement History'` and
> `isHeader: true` exists.

### AC-12 — Settlement-row semantic label

> Given a settlement row for `from=You, to=Priya, amount=₹800.00,
> date=25 Mar 2025, note='GPay transfer'`
> When scanned for semantics
> Then a semantic node with label
> `'You paid Priya rupees 800.00 on 25 Mar 2025. Note: GPay transfer.'`
> exists
> And given a `note: null` settlement, the label substitutes
> `'Note: no note.'`.

### Telemetry contract (both events pre-declared in telemetry-plan §1.3)

### AC-13 — `settlement_history_viewed` fires exactly once on first populated frame

> Given the screen mounts and transitions Loading → AsyncData([3 items])
> When one frame has been pumped
> Then exactly one `settlement_history_viewed` event has fired with
> `{context_type: 'friendship', item_count: 3}`
> And subsequent rebuilds (e.g. the provider stream emits a new value)
> do NOT re-fire.

### AC-14 — `settlement_history_error` fires on AsyncError

> Given the screen mounts and the provider yields AsyncError
> When one frame has been pumped
> Then exactly one `settlement_history_error` event has fired with
> `{error_code: '<mapped code>', context_type: 'friendship'}`.

### AC-15 — Telemetry PII guard

> Given the `settlement_history_viewed` and `settlement_history_error`
> events fire
> When scanned
> Then NEITHER payload includes a `userId` / `uid` / `friendship_id` /
> `friendship_id_hash` / `context_id` parameter
> And the PII-leak grep test asserts the source files contain no such
> literals.

### `FriendDetailScreen` "View Settlement History" link integration

### AC-16 — Link visible in Populated state

> Given `friendDetailProvider` returns `FriendDetailStatePopulated`
> When the screen is mounted
> Then a `TextButton` with label `'View Settlement History'` is rendered
> below the `FriendDetailTimelineWidget`.

### AC-17 — Link hidden in Empty state

> Given `friendDetailProvider` returns `FriendDetailStateEmpty`
> When the screen is mounted
> Then NO `TextButton` with label `'View Settlement History'` is in the
> tree.

### AC-18 — Link tap pushes `SettlementHistoryScreen` with correct args

> Given the Populated state is mounted
> When the user taps the "View Settlement History" link
> Then a `MaterialPageRoute` is pushed
> And its `builder` returns a `SettlementHistoryScreen` with
> `contextType: 'friendship'`, `contextId: '<friendshipId>'`,
> `currentUserUid: '<currentUid>'`, `otherUserUid: '<otherUid>'`,
> `otherDisplayName: '<state.header.displayName>'`.

### Cross-cutting and negative guards

### AC-19 — Invariant 1 boundary contract

> Given the PR diff
> When scanned for `.toDouble()`, `parseFloat`, `/ 100`, `.toFixed`, or
> `double ` declarations on the new files
> Then ZERO violations exist anywhere in
> `lib/features/settlements/presentation/settlement_history_screen.dart`,
> `lib/features/settlements/application/settlement_history_provider.dart`,
> or
> `lib/features/settlements/application/settlement_history_telemetry.dart`.

### AC-20 — Invariant 2 negative guard

> Given the PR diff
> When scanned
> Then ZERO references to `simplifiedBalances` exist anywhere in the 3
> new files.

---

## Telemetry Events

Both events are **pre-declared** in
`docs/design/07-technical/telemetry-plan.md` §1.3 lines 193-194. No
telemetry-plan append is required.

| Event | Parameters | Trigger |
|---|---|---|
| `settlement_history_viewed` | `context_type` (string), `item_count` (int) | First populated frame (fires exactly once) |
| `settlement_history_error` | `error_code` (string), `context_type` (string) | AsyncError |

**PII guard (ADR-0013).** NEITHER event carries `context_id`. For the
friendship axis `contextId` is a UID-composite `{uidA}_{uidB}` that must
not be emitted raw. The telemetry-plan deliberately omits it; the screen
spec at SCR-24 §Telemetry Events lists `context_id` and is incorrect
(see Architect Notes §2.9). `context_type` is a safe non-identifying
enum token; `item_count` is a non-PII integer; `error_code` is a safe
Firebase error-code enum.

## Invariant Applicability Assessment

| Invariant | Applicability | Rationale |
|---|---|---|
| Inv-1 (integer paise) | **N/A** (read-only) | No monetary write paths. The per-row amount renders via `formatInrFromPaise(int)`. Defence-in-depth grep returns 0 violations. |
| Inv-2 (`simplifiedBalances` server-only) | **N/A** | The screen reads `settlements/{id}` documents via `SettlementRepository.watchByContext`; it never references `simplifiedBalances`. |
| Inv-3 (system share sheet) | **N/A** | The share/export action is deferred (SCR-24 §Open Questions item 2). |
| Inv-4 (single Firebase project) | **N/A** | No new Firebase SDK usage; reads through the single production project. |

## Definition of Done

- [ ] All 20 acceptance criteria are implemented and covered by tests.
- [ ] `flutter analyze --fatal-infos` reports no issues.
- [ ] `dart format --set-exit-if-changed .` reports no changes.
- [ ] `flutter test` passes (baseline + new tests).
- [ ] Functions suite UNCHANGED (no `functions/**` touch).
- [ ] Rules suite UNCHANGED (no `firestore.rules` touch).
- [ ] QA sign-off with evidence for all 4 states, the 50-item cap, the
  date + amount format, the accessibility labels, the telemetry
  contract, and the FriendDetailScreen link visibility contract.
- [ ] Documentation updated (this story with Architect Notes,
  sprint-2-plan, next-three-prs, burndown, settlements README).

## Invariant Compliance

All four invariants are N/A on this read-only client surface. The
`settlement_history_pii_leak_test.dart` is the defence-in-depth
assertion that the three new files carry no Inv-1 / Inv-2 / PII
boundary-contract violations.

## Design Artefact References

- `docs/design/06-screen-specs/23-28-settle-activity-profile.md`
  §SCR-24 (lines 153-253) — full screen spec.
- `docs/design/04-wireframes/settle-up-flow.md` §4 (lines 326-400) —
  Settlement History wireframe.
- `docs/design/07-technical/telemetry-plan.md` §1.3 lines 193-194 —
  pre-declared event contracts.
- `docs/design/02-design-system/components.md` §5/§18/§19/§20 — the
  OBT* primitives DEFERRED in favour of inline equivalents.
- `docs/design/07-technical/error-and-empty-state-taxonomy.md` —
  AsyncError → user-facing error-state mapping.

## Responsible Agents

| Agent | Responsibility |
|---|---|
| PM | This story + acceptance criteria. |
| Architect | Architect Notes §2.1–§2.12; invariant applicability; primitive-extraction deferral; route and cap-location decisions. |
| Flutter Developer | `SettlementHistoryScreen`, `settlementHistoryProvider`, telemetry constants, FriendDetailScreen link, tests. |
| QA | Manual smoke matrix; DoD sign-off; negative-scope greps. |

## Technical Notes

- The screen is a `ConsumerStatefulWidget` (the one-shot
  `settlement_history_viewed` post-frame callback mirrors the
  `FriendDetailScreen._loggedView` precedent).
- The provider is a `StreamProvider.family<List<SettlementDoc>,
  SettlementHistoryArgs>` reusing the existing
  `settlementRepositoryProvider` (root-scope; no `dependencies:` needed).
- The 50-item cap is applied at the provider via `.take(50)`.
- Date rendering uses `DateFormat('dd MMM yyyy')` with no locale
  argument and no `initializeDateFormatting()` — matching the existing
  `relative_timestamp_formatter.dart` precedent (which renders
  `dd MMM yyyy` in production without locale init).

## Out of scope

- Group-context push wiring (Sprint 3 Groups epic).
- Settlement edit/delete flow (FR-EX-06 parallel; separate later PR).
- Cursor-based pagination beyond the 50-item cap (defer until evidence
  of >50-settlement friendships).
- `OBTSkeletonLoader` / `OBTEmptyState` / `OBTErrorState` /
  `OBTUserAvatar` / `OBTRupeeText` primitive extractions (separate
  chores; inline equivalents ship here).
- Real-time fade-in animation (SCR-24 §Edge Cases item 2).
- Context-deleted snackbar + auto-back (SCR-24 §Edge Cases item 3).
- Per-month section-header grouping (SCR-24 §Open Questions item 3).
- Settlement-row tap-to-detail navigation (SCR-24 §Open Questions
  item 1; no detail screen exists).
- Share/export action in the app bar (SCR-24 §Open Questions item 2;
  v1.1).
- `view_all_settlements_tapped` entry-point telemetry (over-instrumentation;
  Architect Notes §2.6).
- FR-PR-05 Contact Support `mailto:` flow (the error state's Retry is
  the v1.0 fallback; the "Contact Support" link in SCR-24 §States row 4
  is a separate P0 story).

---

## Architect Notes

> Appended by the Solution Architect. Ratifies the technical decisions
> the Flutter Developer must follow. Anything outside §2.10 is scope
> creep.

### 2.1 Route name

RATIFY: `/settle/history` per `SCR-24 §Screen Identity` Route row. No
`go_router` migration in this PR — the route is pushed via
`MaterialPageRoute.push` from `FriendDetailScreen`. The `next-three-prs.md`
shorthand `/settlements/history` is superseded by the screen-spec value.

### 2.2 50-item cap location

RATIFY: enforced at the **provider** layer. `settlementHistoryProvider`
pipes `.take(50)` over the upstream `watchByContext` stream. No "Load
more" footer for v1.0 per SCR-24 §Edge Cases item 1. The
`item_count` telemetry parameter therefore reports the post-cap length
(a 76-settlement context emits `item_count: 50`).

### 2.3 Inline empty/loading/error widgets (NO primitive extraction)

RATIFY: ship `_SettlementHistoryEmptyState`,
`_SettlementHistoryLoadingState`, `_SettlementHistoryErrorState` as
private widgets in the screen file (mirrors the PR #42
`friend_detail_states.dart` precedent). DEFER `OBTSkeletonLoader` /
`OBTEmptyState` / `OBTErrorState` / `OBTUserAvatar` / `OBTRupeeText` to
separate chores. The loading state is a plain centred
`CircularProgressIndicator` (not a shimmer skeleton) — `OBTSkeletonLoader`
does not exist yet.

### 2.4 Screen constructor args

RATIFY: 5-arg
`SettlementHistoryScreen({required this.contextType, required
this.contextId, required this.currentUserUid, required this.otherUserUid,
required this.otherDisplayName, super.key})`. Provider-agnostic — the
screen does NOT read `currentUserIdProvider`; the `(contextType,
contextId)` arguments fully scope the query, and `currentUserUid` is
threaded as a constructor argument so the screen can label the payer
avatar. This is the architectural seam for the Sprint 3 Group axis: the
Group Detail screen will push the same screen with `contextType: 'group'`.

### 2.5 `FriendDetailScreen` link visibility

RATIFY: the "View Settlement History" `TextButton` is unconditionally
visible in `FriendDetailStatePopulated`; HIDDEN in
`FriendDetailStateEmpty`. The link sits BELOW the
`FriendDetailTimelineWidget` inside the existing `SingleChildScrollView`.

### 2.6 Entry-point telemetry OUT OF SCOPE

RATIFY: do NOT emit a `view_all_settlements_tapped` event from the link
tap. The destination's `settlement_history_viewed` captures the funnel
arrival; an additional entry-point event would over-instrument.

### 2.7 Date format + per-row inline

RATIFY: `dd MMM yyyy` per SRS section 5.9, rendered INLINE above each
row (not as a section header — per SCR-24 §Open Questions item 3 defer).
Use `DateFormat('dd MMM yyyy')` with NO locale argument: the existing
`relative_timestamp_formatter.dart` renders `dd MMM yyyy` in production
without `initializeDateFormatting()`, so no new dependency or locale
bootstrap is required. The `SettlementDoc.date` value comes from
`Timestamp.toDate()` (device-local); the existing in-timeline
`_SettlementRow` formats `doc.date` directly with no extra offset, and
this screen matches that precedent.

### 2.8 Error-code mapping table

RATIFY:
- `FirebaseException` with `code == 'permission-denied'` →
  `'permission-denied'`
- `FirebaseException` with `code == 'unavailable'` → `'unavailable'`
- any other `FirebaseException` → its `code`
- any non-`FirebaseException` → `'unknown'`

Mirrors the existing `SettlementCreateError` mapping discipline (PR #43)
but emits the raw Firebase code (kebab) rather than the snake-case
`SettlementCreateErrorType` label, because the `settlement_history_error`
contract is independent of the write-side enum.

### 2.9 Telemetry-plan vs screen-spec discrepancy on `context_id`

RATIFY: the telemetry-plan §1.3 lines 193-194 version is **authoritative**
(NO `context_id` parameter on either event). The screen spec at SCR-24
§Telemetry Events lists `context_id` and is INCORRECT (a parallel
discrepancy exists on `settle_up_screen_viewed` at SCR-23). For the
friendship axis `context_id` is a UID-composite `{uidA}_{uidB}` that must
not be emitted raw per ADR-0013. The PII-leak test asserts the events
emit no `context_id`. The screen-spec docs cleanup is a tracked
follow-up, NOT fixed in this PR.

### 2.10 Files to touch (exhaustive — anything outside this set is scope creep)

**New:**
- `docs/sprint-zero/stories/FR-SE-08-settlement-history.md` (this file).
- `lib/features/settlements/application/settlement_history_telemetry.dart`.
- `lib/features/settlements/application/settlement_history_provider.dart`.
- `lib/features/settlements/presentation/settlement_history_screen.dart`.
- `test/features/settlements/settlement_history_screen_test.dart`.
- `test/features/settlements/settlement_history_provider_test.dart`.
- `test/features/settlements/settlement_history_telemetry_test.dart`.
- `test/features/settlements/settlement_history_pii_leak_test.dart`.

**Extend:**
- `lib/features/friends/presentation/friend_detail_screen.dart` (link).
- `lib/features/settlements/README.md` (Implemented scope; remove the
  FR-SE-08 deferral line).
- `test/features/friends/friend_detail_screen_widget_test.dart`
  (AC-16 / AC-17 / AC-18).
- `docs/sprint-zero/sprint-2-plan.md`,
  `docs/sprint-zero/next-three-prs.md`,
  `docs/audits/sprint-1/07-bucket-b-burndown.md` (Phase 7 roll-ups).

### 2.11 Files explicitly NOT to touch (negative scope guardrails)

- `firestore.rules`, `firestore.indexes.json`, `storage.rules` —
  UNCHANGED.
- `functions/package.json`, all of `functions/src/**`, all of
  `functions/test/**` — UNCHANGED.
- `lib/features/settlements/data/**` (the repository is UNCHANGED).
- `lib/features/settlements/domain/**` (the `SettlementDoc` shape is
  UNCHANGED).
- `lib/features/settlements/presentation/settle_up_bottom_sheet.dart` —
  UNCHANGED.
- `lib/features/{expenses,activity,notifications,reminders,profile,auth,shell}/**`
  — UNCHANGED.
- `lib/features/friends/**` except `friend_detail_screen.dart` —
  UNCHANGED.
- `lib/core/**` — UNCHANGED.
- `pubspec.yaml`, `pubspec.lock`, `ios/Podfile.lock` — UNCHANGED.
- `.github/workflows/*.yml` — UNCHANGED.
- `docs/design/**` — read-only references; the SCR-24 vs telemetry-plan
  `context_id` discrepancy is tracked but NOT fixed in this PR.

### 2.12 Anticipated reconciliations

1. `lib/features/profile/presentation/profile_placeholder_screen.dart`
   still exists alongside the real `profile_screen.dart`. Still NOT
   touched.
2. The `currentUserIdProvider` rehoming follow-up from PR #57 review
   recommendation 2 remains tracked; not addressed here.
3. The pre-existing storage-rules receipt-test failures remain
   pre-existing; not addressed.
4. The screen-spec vs telemetry-plan `context_id` discrepancy is
   documented (§2.9) but not fixed here.
5. The 5 OBT* primitive extractions are all tracked follow-ups; not
   addressed here.
