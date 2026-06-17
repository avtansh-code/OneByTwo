# FR-HD-03 — Current-Month Spend Summary + Category Breakdown Chart

> Implementation-ready user story for the **real current-month spend
> summary and category-breakdown chart** that replaces the
> `SpendingBreakdownPlaceholderCard` ("Spending breakdown coming soon",
> 160 dp) under the "This Month" header of the Home dashboard
> (`lib/features/home/presentation/home_dashboard_screen.dart:388`,
> SCR-06 Populated State). Ships the **first cross-friendship expense
> read path** — a fan-out over `friendsListProvider` that sums the
> **signed-in user's own `sharePaise`** (taken from each expense's
> `splits`) per `ExpenseCategory` for the **current calendar month
> computed in IST** — the **first charting library** (`fl_chart`
> recommended, ratified by the Architect in ADR-0017) plus any
> consequent **`ios/Podfile.lock` change** (only if the chosen library
> introduces a CocoaPod; `fl_chart` is pure-Dart, so none is expected),
> the 8-category colour-token map, the breakdown card (donut/bar chart +
> legend + month total via `formatInrFromPaise`), the loading / empty /
> error sub-states (the error sub-state reuses the FR-PR-05
> `ContactSupportController` path exactly like FR-HD-01/02 —
> `HD-FIRESTORE-READ`), and one newly-declared PII-free telemetry event
> (`home_spending_breakdown_viewed`). 100% read-only over `expenses`;
> it never reads or writes `simplifiedBalances` (Invariant 2 N/A);
> every category subtotal and the month total is integer paise and the
> only rupee rendering is via `formatInrFromPaise(int)` (Invariant 1).

---

## SRS Requirement ID(s)

- **FR-HD-03** (SRS section 4.8, **line 248**, **P1**) — "The Home
  dashboard shall show a current-month spend summary with a category
  breakdown (donut/bar chart)." This story closes the SRS FR-HD-03 row
  in full for v1.0 (the placeholder shipped in PR #62 is now superseded
  by the real chart).

## Relevant SRS Sections

- **Section 4.8** — Home Dashboard. FR-HD-03 row (P1); the last open
  Home-dashboard requirement after FR-HD-01/02 (#62) and FR-HD-04 (#57).
- **Section 5.4 / line 308** — Security / PII. "Personally identifiable
  information (phone number, name, photo URL) shall never be logged in
  Crashlytics or Analytics." Binds the new telemetry event: no `uid`,
  `friendshipId`, or raw rupee/paise value may ever be a parameter.
- **Section 5.9** — Localisation & Internationalisation. "Date/time
  displayed in IST (`Asia/Kolkata`) regardless of device locale." The
  current-month window MUST be computed in IST so the boundary matches
  the rest of the app's date rendering (`DateFormat('dd MMM yyyy')`).
- **Section 5.10** — Observability. One NEW client analytics event
  (`home_spending_breakdown_viewed`), **not yet pre-declared** in
  `docs/design/07-technical/telemetry-plan.md` — this PR must DECLARE it
  in §1.3 and wire it. PII guard per ADR-0013.
- **Section 7.3** — Key Architectural Decisions. "Money is stored as
  integer **paise** … conversion to ₹ happens at the UI layer." Every
  category subtotal and the month total is an integer `*Paise` sum.
- **Section 13.1** — Flutter feature-first folder layout. The new
  aggregation provider, domain model, and card widget land under the
  existing `lib/features/home/` feature.
- **Section 13.2** — Acceptance Criteria Template (this document).

## Relevant Design References

- `docs/design/06-screen-specs/06-08-home-and-search.md` — SCR-06
  "Home Dashboard":
  - **Category Breakdown Section (P1 — FR-HD-03)** (lines 108–113):
    "This Month" header; "a donut or horizontal bar chart segmented by
    expense category using `OBTCategoryChip` colour mapping".
  - **Loading State** (lines 61–72): a `chart`-type `OBTSkeletonLoader`
    (160×160 dp circle + three 12 dp bar lines) — the loading sub-state
    reuses the dashboard skeleton discipline.
  - **Error State** (lines 114–127): `HD-FIRESTORE-READ`, Retry +
    Contact Support (FR-PR-05 / FR-SH-03/04 reuse).
  - **Telemetry Events** table (lines 142–154) and **Accessibility**
    table (lines 156–202): "No information is conveyed by colour alone";
    WCAG 2.1 AA contrast in light and dark mode; dynamic font scaling to
    200%.
  - **Edge Case 5** (line 213): the v1.0 placeholder card is
    non-interactive — superseded here; the real card remains
    non-interactive in v1.0 (no per-segment drill-down).
- `docs/design/02-design-system/` — the colour tokens the designer maps
  to the 8 `ExpenseCategory` values (dark-mode-safe, WCAG AA).
- `lib/features/expenses/domain/expense_category.dart` — the 8-value
  enum (`food`, `travel`, `rent`, `utilities`, `groceries`,
  `entertainment`, `shopping`, `other`) with existing display labels +
  Material icons (no colour map yet).

## Priority

**P1.** FR-HD-03 is the top-ranked remaining P1 on the
`docs/sprint-zero/next-three-prs.md` carry-forward candidate list and
the **last open Home-dashboard requirement**. It was explicitly deferred
from PR #62 (FR-HD-01/02) as "a separate P1 PR (the real donut/bar chart
+ the category-aggregation read path)". Every P0 functional requirement
is already shipped; FR-PR-02 (#64) and FR-AU-09 (#65) closed the two
top-ranked P1s before this one.

## Story Points

**5.** The architect may adjust to **5–8** at kickoff (the cross-
friendship read path and the first charting plugin are the two
risk-bearing axes). Decomposition (per the canonical prompt §1):

- **2 SP** — the cross-friendship current-month per-category aggregation
  read path + provider: a fan-out over `friendsListProvider`, summing
  the **user's own `sharePaise`** per `ExpenseCategory`, integer paise,
  `dependencies: [friendsListProvider]`, group axis stubbed.
- **1 SP** — the charting plugin (`fl_chart`, architect-ratified) +
  `cd ios && pod install` (+ commit `ios/Podfile.lock` only if the
  library adds a CocoaPod — none expected for pure-Dart `fl_chart`) +
  the 8-category colour-token map (designer-owned).
- **1 SP** — the breakdown card UI (chart + legend + month total via
  `formatInrFromPaise`) + the loading / empty / error sub-states.
- **1 SP** — the new telemetry event (declared in `telemetry-plan.md`
  §1.3 + wired) + the placeholder-card swap at
  `home_dashboard_screen.dart:388` + README / home-feature docs +
  provider unit tests (aggregation correctness, current-month filter,
  user-share-not-total, multi-friendship fold, deleted-exclusion) +
  widget tests (chart renders, empty/zero state, a11y summary) + a
  boundary contract over the new files + any new `firestore.indexes.json`
  index + ADR-0017 + the SCR-06 / telemetry-plan doc updates.

## Branch / PR Metadata

| Field | Value |
|---|---|
| **Branch** | `feat/fr-hd-03-spend-breakdown-chart` |
| **Base** | `main` after PR #65 merged (FR-AU-09 delete account, squash commit `d542793`) |
| **Target PR** | next available GitHub number (**≥ #67** — highest issue is FUTURE #66, highest PR is #65; reconcile the slot label at PR open) |
| **PR title (≤72 chars)** | `feat(home): FR-HD-03 monthly spend category breakdown chart` (59 chars) |
| **Commit-title scope** | `home` (single-token per CI title-lint `^(feat\|fix\|…)(\([a-z0-9_-]+\))?!?: .{1,72}$`) |
| **Story SP** | 5 (architect may adjust to 5–8) |

> **PR-number caveat.** Issues and PRs share one sequential GitHub
> namespace; the `next-three-prs.md` slot label is an internal roadmap
> slot, not a GitHub number. If the designer tracks the 8-category
> colour-token map as a companion design issue, that issue consumes an
> intermediate number — reconcile at PR open.

## Dependencies

This story builds on:

- **PR #62 (FR-HD-01/02 home dashboard)** — provides the
  `HomeDashboardScreen` four-state scaffold, the `_PopulatedState` with
  the "This Month" header + the `SpendingBreakdownPlaceholderCard` swap
  point at `home_dashboard_screen.dart:388`, the error-state
  `ContactSupportController` reuse (`HD-FIRESTORE-READ`,
  `home_dashboard_screen.dart:136-158`), the `HomeTelemetry` constants
  file, and the canonical `dependencies: [friendsListProvider]` derived-
  provider pattern (`home_balances_providers.dart`). UNCHANGED except
  the line-388 swap and the new telemetry constants.
- **PR #57 (FR-HD-04 persistent FAB)** — the persistent FAB stays
  visible and active during the breakdown card's loading / empty / error
  sub-states (the user may add an expense whilst the chart loads).
  UNCHANGED.
- **PR #36 (FR-FR-03 friends list)** —
  `lib/features/friends/application/friends_list_provider.dart` is the
  source of the user's `friendshipId`s for the fan-out. UNCHANGED; the
  aggregation provider is a fresh consumer.
- **PR #38 (FR-EX-01 expense creation) / PR #35 (FR-FR-04 friend
  detail)** — `lib/features/expenses/domain/expense_doc.dart` (fields
  `amountPaise`, `category`, `date`, `splits` where each split is
  `{userId, sharePaise}`), `expense_category.dart` (the 8-value enum +
  labels + icons), and `expense_repository.dart`'s
  `watchExpensesByFriendship({friendshipId, limit})` read pattern over
  `friendships/{fid}/expenses` (`where('deleted', isEqualTo: false)
  .orderBy('date', descending: true)`). UNCHANGED — the new read adds a
  `date >= monthStart` window.
- **`lib/core/formatters/inr_formatter.dart`** — `formatInrFromPaise(int)`
  is the SOLE paise→rupee boundary. UNCHANGED.
- **The charting plugin (NEW)** — `fl_chart` recommended; the architect
  ratifies the plugin + version pin + the required `ios/Podfile.lock`
  update in ADR-0017.
- **ADR-0001 (simplified debts)** and the FR-HD-01/02 Architect Notes —
  mirror the derived-provider composition + error-state reuse.

## GitHub Issue This Story Closes

**None.** FR-HD-03 is a **P1 SRS row** (section 4.8, line 248). There is
**no dedicated GitHub tracking issue**; this story is the source of
truth and closes the SRS FR-HD-03 row in full for v1.0 (mirroring how
FR-HD-04 closed its SRS row with no pre-existing issue). The
**denormalised monthly-spend rollup** and the **per-category drill-down**
are deferred to FUTURE follow-up issues filed after merge (see the
*Follow-up Issues* section) — they are NOT part of this row's closure.

## User Story

As a **One By Two user viewing the Home dashboard**,
I want **a current-month spend summary with a per-category breakdown
chart**,
so that **I can see at a glance how much I have spent this month and
which categories it went on**.

## Preconditions

1. The user is authenticated AND has completed profile setup (the
   authenticated shell is mounted; `currentUserIdProvider` is bound to
   the signed-in UID by the per-arm `ProviderScope` in `lib/main.dart`,
   per FR-HD-04 / PR #57).
2. The Home dashboard renders its **populated** state (FR-HD-01/02, PR
   #62) — the breakdown card occupies the "This Month" slot the
   `SpendingBreakdownPlaceholderCard` holds today
   (`home_dashboard_screen.dart:388`).
3. `friendsListProvider` (PR #36) is functional and emits the user's
   `friendshipId`s — the keys the aggregation fan-out reads expenses
   for.
4. Each `friendships/{fid}/expenses` document the caller can read is an
   `ExpenseDoc` carrying `amountPaise` (int paise), `category` (a
   serialised `ExpenseCategory.name`), `date` (a Firestore `Timestamp`),
   `splits` (a list of `{userId, sharePaise}`), and `deleted` (a bool).
   The Firestore read gate (`firestore.rules`) already permits the
   caller to read expenses in friendships they are a member of.
5. Groups are **not** implemented (Sprint 3). The aggregation folds the
   **friendship axis only**; the group axis is a forward-compat stub
   (exactly as `topBalancesProvider` stubbed groups).

---

## Acceptance Criteria

> 20 ACs grouped into 7 contractual buckets (Aggregation correctness —
> the highest-risk surface; Current-month / IST filtering; Card states;
> Chart rendering; Accessibility; Telemetry; Invariant negative guards).
> Each AC is independently testable. At least one negative case appears
> in every bucket; the mandated negatives (zero-spend, prior-month,
> deleted, user-share-not-total, single-category degenerate, Firestore
> error) are AC-7, AC-5, AC-6, AC-2, AC-11, and AC-9 respectively.

### Resolved product decisions (binding for Phase 2 onward)

These four open product questions from the canonical prompt §1/§8 are
**resolved here and are not re-openable** without a PM sign-off:

1. **Spend semantics (highest-risk correctness surface).** "Spend" =
   the **signed-in user's OWN `sharePaise`**, taken from the single
   `splits` entry whose `userId == currentUserId`, summed per
   `ExpenseCategory`, for the **current calendar month computed in IST**
   (SRS 5.9). It is **NOT** the full `amountPaise` (which includes the
   other member's share and would over-report). An expense the user is
   not a `splits` member of contributes nothing. This rule is repeated
   in AC-1, AC-2, AC-3, the Telemetry Contract, and the Invariant
   Compliance section — it is the single most important sentence in this
   story.
2. **All categories, no synthetic top-N, no tail "Other" bucket.**
   Render **every** `ExpenseCategory` that has non-zero current-month
   spend (the enum is only 8 values), sorted by **descending paise**.
   Do NOT introduce a synthetic top-N truncation or an artificial tail
   "Other" bucket. `ExpenseCategory.other` is itself a **real category
   (the 8th)** — when it carries spend it renders as an ordinary segment,
   never as a collapsed tail. (A top-N collapse is a possible future
   refinement; out of scope — see *Out of Scope*.)
3. **Empty / zero-spend state.** When there is no current-month spend,
   show a friendly card with primary copy **"No spending yet this
   month"** and a helper subline **"Add an expense to see your monthly
   breakdown"**, and **NO chart**. The loading sub-state reuses the
   dashboard skeleton; the error sub-state reuses the FR-PR-05
   `ContactSupportController` path exactly like the FR-HD-01/02 error
   state (`HD-FIRESTORE-READ`).
4. **One new PII-free telemetry event.** `home_spending_breakdown_viewed`,
   single non-identifying parameter `category_count` (`int` = the number
   of categories with non-zero current-month spend rendered; `0` in the
   empty sub-state). Fires **once per dashboard mount**, on the **first
   terminal (non-loading) render** of the breakdown card — in BOTH the
   empty and populated sub-states, but **NOT** on the error sub-state.
   `uid`, any `friendshipId`, and any raw rupee/paise value MUST NEVER
   be a parameter (SRS line 308).

### Aggregation correctness (highest-risk surface)

**AC-1 — Happy path: multi-friendship fold into one per-category
breakdown + correct month total.** **Given** the user has current-month,
non-deleted expenses across **multiple friendships** — e.g. Friendship A
(with Bob): a Food bill of ₹1,000.00 (`100000` paise) split equally so
the user's `sharePaise` is `50000`, and a Travel bill of ₹600.00
(`60000` paise) split equally so the user's `sharePaise` is `30000`; and
Friendship B (with Carol): a Food bill of ₹400.00 (`40000` paise) split
equally so the user's `sharePaise` is `20000` — **when** the breakdown
card resolves, **then** it renders two segments — **Food = `70000` paise
(₹700.00)** (`50000 + 20000`, folded across both friendships) and
**Travel = `30000` paise (₹300.00)** — and a **month total of `100000`
paise (₹1,000.00)**, every rupee string produced by `formatInrFromPaise`.

**AC-2 — The user's share is counted, never the bill total (negative —
the canonical over-report trap).** **Given** a single current-month Food
expense whose bill is ₹1,000.00 (`amountPaise == 100000`) split equally
between the user and one friend, so the user's `splits` entry is
`sharePaise == 50000`, **when** the breakdown resolves, **then** the
Food subtotal is **`50000` paise (₹500.00)** — the user's own share —
and is **NOT** `100000` paise. A naive `sum(amountPaise)` aggregation
(which would yield `100000`, double-counting the friend's share) is a
blocking defect.

**AC-3 — Same category folds across friendships into one segment.**
**Given** two different friendships each contribute a Groceries expense
in the current month (user shares `15000` paise and `25000` paise),
**when** the breakdown resolves, **then** there is exactly **one**
Groceries segment of **`40000` paise (₹400.00)** — categories are folded
by `ExpenseCategory`, not by friendship.

### Current-month / IST filtering

**AC-4 — Prior-month expenses are excluded (negative).** **Given** the
user has expenses dated in a **previous** calendar month (e.g. an expense
dated 20 May 2026 when the current month is June 2026), **when** the
breakdown resolves, **then** those expenses contribute **nothing** to any
category subtotal and nothing to the month total.

**AC-5 — The month window is computed in IST (boundary, negative).**
**Given** the current month is June 2026, so the window start is the
first instant of the month in IST — `2026-06-01T00:00:00+05:30`
(equivalently `2026-05-31T18:30:00Z`) — **when** the breakdown
aggregates, **then** an expense whose `date` is `2026-05-31T23:00 IST`
(before the window) is **excluded**, whilst an expense whose `date` is
`2026-06-01T00:30 IST` (on/after the window) is **included**. The
boundary matches the app's IST date rendering (SRS 5.9); it is **not**
computed in device-local time or UTC.

**AC-6 — Soft-deleted expenses are excluded (negative).** **Given** a
current-month expense with `deleted == true`, **when** the breakdown
resolves, **then** it contributes **nothing** to any subtotal or the
month total (mirroring the existing `where('deleted', isEqualTo: false)`
read filter).

### Card states

**AC-7 — Zero current-month spend → the empty card, no chart
(negative).** **Given** the user has no current-month spend (no
qualifying expenses this month, or every qualifying expense nets to
`0` of the user's share), **when** the breakdown resolves, **then** the
card shows **"No spending yet this month"** with the subline **"Add an
expense to see your monthly breakdown"** and renders **no chart and no
legend**.

**AC-8 — Loading sub-state reuses the dashboard skeleton.** **Given**
the first cross-friendship expense read has not yet resolved, **when**
the breakdown card is shown, **then** it renders a `chart`-type skeleton
placeholder (per SCR-06 Loading State) and `home_spending_breakdown_viewed`
is **not** yet emitted (AC-15).

**AC-9 — Firestore read error → error state with Retry + Contact Support
(negative, FR-PR-05 reuse).** **Given** the cross-friendship expense
read fails, **when** the breakdown resolves, **then** the card shows the
error sub-state with a **Retry** affordance and a **Contact Support**
link wired to the FR-PR-05 `ContactSupportController` (`mailto:` flow
with the copy-address fallback dialog), carrying the support-triage code
**`HD-FIRESTORE-READ`** — identical to the FR-HD-01/02 error path.
Tapping **Retry** re-invokes the read.

### Chart rendering

**AC-10 — Populated chart: every non-zero category, sorted descending,
with legend + month total.** **Given** the populated breakdown of AC-1,
**when** the card renders, **then** it shows a donut (or horizontal bar)
chart with one segment per non-zero category **sorted by descending
paise** (Food `70000` before Travel `30000`), a legend mapping each
segment's colour to its `ExpenseCategory` label and rupee subtotal, and
the **month total** rendered once via `formatInrFromPaise`. Segment
geometry (sweep angle / bar width) and any displayed percentage are
**derived ratios from integer paise** (e.g. `70000 / 100000`); they are
not money and never flow through a `double` money path.

**AC-11 — Single-category month: the degenerate one-segment chart still
renders and is announced (edge).** **Given** the user's only
current-month spend is in **one** category (e.g. Rent `120000` paise,
₹1,200.00), **when** the card renders, **then** the chart shows a single
full-circle (or single full-width bar) segment at 100%, the legend shows
the one row, the month total equals the single subtotal, and the segment
is announced per AC-13.

**AC-12 — No synthetic "Other" bucket and no top-N truncation; `other`
is a real category.** **Given** the user has spend in all 8 categories
including `ExpenseCategory.other`, **when** the card renders, **then**
all 8 segments render (one per category), `other` appears as an ordinary
segment ranked by its own paise, and there is **no** collapsed tail
bucket and **no** "+N more" truncation.

### Accessibility

**AC-13 — Each segment is announced "category, ₹amount, percentage"
(never colour-only).** **Given** the populated chart, **when** a screen
reader traverses it, **then** each segment exposes a semantic label of
the form **"[category label], [rupee amount via `formatInrFromPaise`],
[percentage]"** (e.g. "Food, ₹700.00, 70 percent") — information is
**never** conveyed by colour alone (SCR-06 Accessibility; SRS 5.6). The
colour-token map (designer-owned) is dark-mode-safe and meets WCAG 2.1
AA contrast.

**AC-14 — The month total is announced.** **Given** the populated card,
**then** the month-total element exposes an informational semantic label
(e.g. "This month you have spent ₹1,000.00") rendered via
`formatInrFromPaise`.

### Telemetry

**AC-15 — `home_spending_breakdown_viewed` fires once on the first
terminal populated render.** **Given** the breakdown reaches its
populated sub-state for the first time on a dashboard mount, **then**
`home_spending_breakdown_viewed` is emitted **exactly once** with
`category_count` equal to the number of non-zero categories rendered
(e.g. `2` for AC-1). It does not re-fire on rebuilds within the same
mount.

**AC-16 — The event fires in the empty sub-state with
`category_count: 0`.** **Given** the breakdown reaches its empty
sub-state ("No spending yet this month") for the first time on a mount,
**then** `home_spending_breakdown_viewed` is emitted once with
**`category_count: 0`**.

**AC-17 — The event does NOT fire on the error sub-state (negative).**
**Given** the breakdown resolves to its error sub-state
(`HD-FIRESTORE-READ`), **then** `home_spending_breakdown_viewed` is
**not** emitted (the loading and error sub-states are non-terminal for
telemetry purposes; only the empty and populated sub-states are
terminal).

**AC-18 — Telemetry PII guard (negative, SRS line 308).** **Given** any
emission of `home_spending_breakdown_viewed`, **then** its payload
contains **only** the `category_count` integer — it carries **no**
`uid`, no `friendshipId` (raw or hashed), no display name, no photo URL,
no phone number, and **no raw rupee/paise value**. Enforced by the
home PII-leak grep extended over the new files.

### Invariant negative guards

**AC-19 — Invariant 1 (integer paise).** Every category subtotal and the
month total is an integer `*Paise` sum; the **only** paise→rupee
conversion is `formatInrFromPaise(int)` at the widget layer; chart
segment ratios and percentage labels are derived from integer paise.
The boundary-contract test asserts **zero** `.toDouble()` / `parseFloat`
/ `/ 100` / `.toFixed` / `double `-declaration matches in the new
aggregation provider, domain model, and card files.

**AC-20 — Invariant 2 (`simplifiedBalances` read-only) negative guard.**
The new files read `expenses` only; they contain **zero** references to
`simplifiedBalances` (spend is the user's expense share, not a balance).
Enforced by the negative-guard grep over the new files.

---

## Telemetry Contract (FR-HD-03 v1.0)

One NEW client event. It is **NOT yet declared** in
`docs/design/07-technical/telemetry-plan.md` (the Home section §1.3
lists only the six `home_*` events). This PR must **declare** it in
§1.3 **and** wire it.

| Event | Trigger | Parameters | Types |
|---|---|---|---|
| `home_spending_breakdown_viewed` | Fires **once per dashboard mount**, on the **first terminal (non-loading) render** of the breakdown card — in BOTH the populated and empty sub-states; **NEVER** on the loading or error sub-states | `category_count` | `int` — the number of categories with non-zero current-month spend rendered; `0` in the empty sub-state (range `0..8`) |

**PII guard (SRS line 308 / ADR-0013).** `category_count` is a
non-identifying small integer (`0..8`); it is not user-specific. **No**
`uid`, **no** `friendshipId` (raw or hashed), **no** raw rupee/paise
value, and **no** name / photo URL / phone number may ever be a
parameter. If a per-category identifier is ever logged in future, it is
the **non-PII enum name only** (`'food'`, `'travel'`, …) and never an
amount. No hashing is required because no hashable identifier is emitted.
AC-18 asserts this via the PII-leak grep.

**Single-fire discipline.** The event is gated by a screen-local
`bool` (mirroring the existing `_loggedView` gate for `home_viewed` in
`home_dashboard_screen.dart:106-119`), but keyed to the **breakdown
card's** own terminal sub-state (which has a separate data lifecycle
from the balances axis that drives `home_viewed`). The architect
confirms whether the gate lives on `_HomeDashboardScreenState` or inside
a dedicated breakdown-card `ConsumerStatefulWidget` (sub-question (b)).

**Constants placement (PM recommendation).** Extend the existing
`lib/features/home/application/home_telemetry.dart` `HomeTelemetry`
abstract final class with a `spendingBreakdownViewed` event-name
constant and a `paramCategoryCount` key constant, mirroring the existing
six `home_*` constants. The architect ratifies.

---

## Invariant Compliance

| Invariant | Applicability | How enforced |
|---|---|---|
| **1 — money is integer paise** | **CRITICAL** (this is a monetary surface) | Every category subtotal and the month total is an integer `*Paise` sum over the user's `sharePaise`; the **only** paise→rupee conversion is `formatInrFromPaise(int)` at the widget layer; chart segment geometry and percentage labels are **derived ratios from integer paise** (e.g. `categoryPaise / monthTotalPaise`), never `double` money. No `double`, no inline `/ 100`, no `.toFixed`. AC-2 (user-share-not-total) and AC-19 (boundary-contract grep over the new aggregation provider, domain model, and card files) are the affirmative gates. |
| **2 — `simplifiedBalances` server-only** | **N/A** | FR-HD-03 reads the `expenses` subcollections and **never** reads or derives from `simplifiedBalances` (spend is the user's expense share, not a balance), and it **writes nothing**. AC-20 asserts zero `simplifiedBalances` references in the new files. |
| **3 — system share sheet only** | **N/A** | No sharing or export on this surface. A "share my spending" action is explicitly out of scope. |
| **4 — single Firebase project** | **Reinforced** | The fan-out read, any new `firestore.indexes.json` index, and all pre-merge testing target the single production project (`onebytwo-avtanshgupta`) via the Firebase Emulator Suite. No new project config; no second project ID. |

---

## Out of Scope

These are explicitly EXCLUDED to keep the PR surgical. If an agent
suggests bundling any of the below, refuse and cite this section.

- **The Sprint 3 Groups epic / group-expense aggregation beyond the
  forward-compat stub.** The aggregation folds the friendship axis
  fully and stubs the group axis (a comment + an ADR-0017 note), exactly
  as `topBalancesProvider` did. No Groups Dart code is written.
- **A denormalised monthly-spend rollup Cloud Function (FUTURE).** v1.0
  uses the client-side fan-out. A server-maintained per-user monthly
  rollup is a much larger change + a new server writer — filed as a
  FUTURE optimisation issue only if the architect deems read cost
  material (sub-question (a)).
- **Per-category tap-to-drill-down.** The card stays non-interactive in
  v1.0 (SCR-06 Edge Case 5); no segment opens a filtered expense list.
  Future enhancement.
- **Any spending share / export action.** Out of scope (Invariant 3).
- **`OBTCategoryChip` design-system extraction beyond the colour map
  this card needs.** Only the 8-category colour-token map is added; the
  full chip-primitive extraction is deferred.
- **A top-N collapse / synthetic tail "Other" bucket.** Resolved against
  for v1.0 (all 8 categories render; `ExpenseCategory.other` is a real
  category). A top-N collapse is a possible future refinement.
- **The SCR-06 Offline State.** Deferred with the FR-OF-01/02/03 slice
  (per the FR-HD-01/02 Architect Notes §5); the error sub-state covers
  the empty-cache + no-connectivity case via `HD-FIRESTORE-READ`.

Standing carry-forwards (per the canonical prompt §6 / `next-three-prs.md`)
— **not** bundled here: the FR-AC-05 deep-link tab-switch migration (the
`shellNavigationControllerProvider` seam from #63); the `app_settings` /
`permission_handler` "Open Settings" CTA chore + `shared_preferences`
adoption; the `go_router` migration (Sprint 3); `currentUserIdProvider`
rehoming; the Bucket-B chore close-out bundle; Issue #47 rules-hardening;
and FUTURE issue #66 (the deletion reaper).

---

## Architect-Call Sub-Questions (for Phase 2)

Enumerated for the architect to ratify in ADR-0017 / the Architect Notes
appendix. Each is a genuine escalation, not a settled product decision
(the four product decisions are resolved above).

- **(a) Read path — friendship fan-out vs a denormalised monthly
  rollup.** **PM recommendation: fan-out for v1.0.** Reuse
  `friendsListProvider` for the user's `friendshipId`s, then read each
  friendship's current-month, non-deleted expenses
  (`where('deleted', isEqualTo: false).where('date', isGreaterThanOrEqualTo:
  monthStart)`) and aggregate the user's own `sharePaise` per category.
  A `collectionGroup('expenses')` query is rejected: expenses carry no
  member field, so the Security Rules (which gate reads on friendship
  membership) cannot scope a collection-group query to the caller's
  friendships without a schema change. The fan-out issues **N reads**
  (one per friendship) on every dashboard view; if the architect deems
  the cost material, file the denormalised-rollup as a FUTURE issue —
  do **not** build it here.
- **(b) Charting library — `fl_chart` vs a hand-rolled `CustomPainter`,
  and the `ios/Podfile.lock` consequence.** **PM recommendation:**
  `fl_chart` (the de-facto Flutter choice), version-pinned. Adding ANY
  Flutter plugin requires `cd ios && pod install --repo-update` and a
  committed `ios/Podfile.lock` **in the same PR**, or the CI "Build iOS
  (no signing)" job fails (it runs vanilla `pod install` without
  `--repo-update`). The architect ratifies the plugin + version + the
  Podfile.lock update, and decides whether the new event's single-fire
  gate lives on `_HomeDashboardScreenState` or a dedicated breakdown-card
  `ConsumerStatefulWidget`. A hand-rolled `CustomPainter` donut avoids
  the plugin (no Podfile.lock churn) at the cost of more code +
  bespoke accessibility work.
- **(c) New composite index or existing index?** The existing
  `firestore.indexes.json` `expenses` index is `queryScope: COLLECTION`
  with fields `deleted ASC + date DESC`. The architect confirms whether
  that index serves the per-friendship current-month query
  (`deleted == false` equality + a `date >= monthStart` range/orderBy)
  or whether a new single-collection index is required. If a new index
  is needed, **deploy rules/indexes before the client** (Schema Change
  handoff order).
- **(d) IST month-boundary computation.** Confirm the current-month
  window start is the first instant of the month in IST (`+05:30`, no
  DST), computed consistently from `DateTime.now()` and compared against
  each expense's `date` (`Timestamp.toDate()`), so the boundary matches
  the app's IST date rendering (SRS 5.9). Worked boundary in AC-5.
- **(e) Breakdown-card placement vs the dashboard's empty/settled state
  (uncovered from the code).** The placeholder lives only inside
  `_PopulatedState` (`home_dashboard_screen.dart:388`); the dashboard's
  empty state (no non-zero balances) shows the "No expenses yet" CTA
  instead. A narrow edge exists — a user with current-month spend but a
  **zero overall balance** (they settled up after spending) sees the
  dashboard empty state, which would hide the breakdown. **PM
  recommendation:** keep the card in `_PopulatedState` for v1.0 (matching
  the placeholder) and track surfacing the breakdown in the settled/empty
  state as a follow-up; the architect confirms.

> PM-recommended domain shape (architect ratifies the names): a
> `CategorySpend { ExpenseCategory category; int totalPaise }` value
> object and a `MonthlySpendBreakdown { List<CategorySpend> categories;
> int monthTotalPaise }` aggregate, exposed by a
> `monthlySpendBreakdownProvider` (`AsyncValue<MonthlySpendBreakdown>`,
> `dependencies: [friendsListProvider]`) under
> `lib/features/home/application/`.

---

## Definition of Done

Core checklist (per `.github/ISSUE_TEMPLATE/user_story.md`):

- [ ] **Code merged to main via approved PR** — squash-merged after
      green CI + QA sign-off; PR title `feat(home): FR-HD-03 monthly
      spend category breakdown chart` (single-token scope `home`,
      ≤ 72 chars).
- [ ] **Unit and widget tests written and passing** — provider unit
      tests (aggregation correctness, **user-share-not-total**,
      current-month/IST filter, prior-month exclusion, deleted
      exclusion, multi-friendship fold, single-category degenerate,
      empty/zero) + widget tests (chart renders, legend + month total,
      empty card, loading skeleton, error state, a11y per-segment
      summary) + the boundary-contract grep over the new files. Per-
      feature coverage ≥ 70%; overall Flutter ≥ 50%.
- [ ] **QA reviewed and verified** — against all 20 ACs and SCR-06 (the
      "This Month" card, chart, legend, total, empty/zero state, a11y),
      the invariants (especially Inv-1 integer-paise aggregation, the
      user-share-not-total correctness, and the IST month boundary),
      the telemetry PII guard, the `ios/Podfile.lock` change (iOS build
      green), the coverage thresholds, and dark-mode WCAG AA contrast.
- [ ] **Telemetry / analytics events in place** —
      `home_spending_breakdown_viewed` **declared** in
      `telemetry-plan.md §1.3` AND wired; single-fire on first terminal
      render; `category_count` only; PII-leak grep clean (AC-18).
- [ ] **Documentation updated (if applicable)** — ADR-0017 (read path +
      charting plugin + index decision + telemetry + Invariant-2 N/A
      confirmation); SCR-06 "Category Breakdown Section" updated from
      placeholder to the shipped chart; `telemetry-plan.md §1.3`
      appended; `lib/features/home/README.md` updated; the
      `next-three-prs.md` / `sprint-2-plan.md` roll-forward at PR open
      and on merge.

Technical gates:

- [ ] The charting plugin is added, version-pinned, and
      `ios/Podfile.lock` is committed in the **same PR**
      (`pod install --repo-update`); the CI "Build iOS (no signing)" job
      is green.
- [ ] `SpendingBreakdownPlaceholderCard` is removed and the line-388 swap
      lands the real card; no other dashboard behaviour changes.
- [ ] Inv-1 boundary-contract grep clean (zero `.toDouble()` /
      `parseFloat` / `/ 100` / `.toFixed` / `double `-declaration in the
      new files); Inv-2 negative-guard grep clean (zero
      `simplifiedBalances` references in the new files).
- [ ] `dart format --set-exit-if-changed .` exits 0;
      `flutter analyze --fatal-infos` exits 0; `flutter test` exits 0.
- [ ] If a new `firestore.indexes.json` index is required, it is added
      and deployed **before** the client (Schema Change handoff order).
- [ ] Zero Cloud Function change; zero `firestore.rules` /
      `storage.rules` change; zero `simplifiedBalances` read/write.

---

## Follow-up Issues to File After Merge

Candidate issues the Phase 7 PM files (or notes in `next-three-prs.md`)
once this PR squash-merges:

1. **Denormalised monthly-spend rollup (FUTURE optimisation)** — a
   Cloud Function trigger maintaining a per-user monthly per-category
   spend rollup, replacing the N-read fan-out. File **only if** the
   architect deems the fan-out read cost material (sub-question (a)).
2. **Per-category tap-to-drill-down (future enhancement)** — tapping a
   segment opens a current-month, category-filtered expense list. Needs
   the search/filter read path (FR-SR-01/02).
3. *(Optional, designer-flagged)* surfacing the breakdown in the
   dashboard's settled/empty state for the "spend-but-zero-balance" edge
   (sub-question (e)); and a top-N segment collapse if the 8-segment
   donut proves visually noisy in production.

These are tracked as candidates; the orchestrator decides which (if any)
are filed at merge time.

---

## Architect Notes

> **Phase 2 ratification (ADR-0017, Accepted).** The technical design is
> ratified. The four resolved product decisions stand unchanged. Story
> points stay at **5** — `fl_chart` is pure-Dart and adds no
> `ios/Podfile.lock` churn (see §1(b)), and no new index is needed (§1(c)),
> so neither risk axis inflates the estimate. Full rationale and
> alternatives are in `.github/shared/decision-log.md` **ADR-0017**;
> this section is the implementation-facing contract for the Designer
> (Phase 3) and Flutter Dev (Phase 4).

### 1. Architect-Call sub-question answers

**(a) Read path — friendship fan-out (RATIFIED), not a rollup.** Reuse
`friendsListProvider` for the caller's `friendshipId`s; for each, issue a
one-shot read of that friendship's current-month, non-deleted expenses
via the new repository method (§5), then aggregate the user's own
`sharePaise` per category (§3). `collectionGroup('expenses')` is
**rejected**: expense docs carry no member field, and `firestore.rules`
line 294 gates reads on **parent-friendship** membership via a `get()` of
`memberIds`, so a collection-group query cannot be scoped to the caller's
friendships without a schema change (out of scope). A denormalised
monthly-rollup Cloud Function is **rejected for v1.0** (larger change, new
server writer). The fan-out's N month-bounded reads per dashboard view are
**acceptable for v1.0**; file the rollup as a FUTURE optimisation issue
**only if** production telemetry shows the cost is material (Follow-up #1).
The **group axis is stubbed** — a plain explanatory comment in the
provider, exactly as `topBalancesProvider` did. No Groups Dart is written.

**(b) Charting library — `fl_chart` (RATIFIED); single-fire gate in a
dedicated card widget.** Use `fl_chart`, pinned `^1.2.0`. **The prompt's
"`ios/Podfile.lock` change is REQUIRED" assertion is incorrect for
`fl_chart`:** it is pure Dart (deps `equatable`, `flutter`,
`vector_math`), declares no `flutter: plugin:` block, and ships no native
iOS/Android code, so it adds **no CocoaPod and does not change
`ios/Podfile.lock`**. Still run `flutter pub get` and
`cd ios && pod install`, confirm `ios/Podfile.lock` is **unchanged**, and
commit it **only if** it changes (it will not). A hand-rolled
`CustomPainter` donut is rejected (more code + bespoke a11y). The
single-fire telemetry gate lives **inside a dedicated breakdown-card
`ConsumerStatefulWidget`** (`SpendingBreakdownCard`), not on
`_HomeDashboardScreenState` — the card's terminal sub-state has a separate
data lifecycle from the balances axis that drives `home_viewed` (§6).

**(c) Index — NO new index (RATIFIED).** The existing
`firestore.indexes.json` composite
`{ expenses, COLLECTION, [deleted ASC, date DESC] }` already covers the
per-friendship query (equality on `deleted` + range/`orderBy` on `date`)
**provided the query orders by `date` DESCENDING**. Order by `date`
descending (matching `watchExpensesByFriendship`). No
`firestore.indexes.json` change, no `firestore.rules` change; the
Schema-Change deploy-before-client order is **moot** (no schema change).

**(d) IST month boundary — fixed +05:30, absolute instants (RATIFIED).**
See §4 for the exact computation and worked example (AC-5). No
`timezone`/`intl` initialisation; the offset is a constant
`Duration(hours: 5, minutes: 30)`.

**(e) Card placement — keep in `_PopulatedState` for v1.0 (CONFIRMED).**
The card replaces the placeholder at `home_dashboard_screen.dart:388`,
inside `_PopulatedState`. Consequently `friendsListProvider` is already
resolved-success when the card mounts, so the breakdown provider's
loading/error states reflect **only** the fan-out fetch (this simplifies
Retry — see §5). The "spend-but-zero-overall-balance" user (settled up
after spending) sees the dashboard's empty state and therefore no
breakdown: an **accepted v1.0 limitation** tracked as Follow-up #3. Do
**not** surface the card in the empty/settled state in this PR.

### 2. Binding correctness rule (the highest-risk surface)

"Spend" = the signed-in user's **own `sharePaise`**, summed per
`ExpenseCategory`, for the current IST month — **never** `amountPaise`.
Extract the user's share **without re-reading `currentUserIdProvider`**:
for a friendship whose counterparty is `FriendListItem.otherUserId`, the
user's share for an expense is the **sum of `split.sharePaise` over splits
whose `userId != otherUserId`**. Because the Security Rules guarantee an
expense's split members are a subset of the two friendship members
(`areSplitMembers`), the non-counterparty split **is** the signed-in
user's split — this is identically the "`userId == currentUserId`" rule in
the ACs, computed from data already on `friendsListProvider`. An expense
the user is not a split member of contributes `0`. Integer paise
throughout; no `double`, no `/ 100`, no `.toFixed`. Percentages are
derived ratios (`categoryPaise / monthTotalPaise`) at render time and are
not money.

### 3. Exact IST month-boundary computation

Implement as a **pure** function (no Riverpod, no Firestore), unit-tested
directly with pinned `now` values:

```text
istShift            = Duration(hours: 5, minutes: 30)   // fixed; no DST
istNow              = DateTime.now().toUtc().add(istShift)
(Y, M)              = (istNow.year, istNow.month)
monthStartUtc       = DateTime.utc(Y, M,     1).subtract(istShift)
nextMonthStartUtc   = DateTime.utc(Y, M + 1, 1).subtract(istShift)   // Dart rolls month 13 -> next Jan
```

- **Query lower bound:**
  `where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStartUtc))`.
- **Reducer window predicate (both bounds, defence against future-dated
  docs):** include an expense iff
  `!e.date.isBefore(monthStartUtc) && e.date.isBefore(nextMonthStartUtc)`
  (`DateTime.isBefore` compares absolute instants regardless of the
  `isUtc` flag, so no manual normalisation is needed).
- **Worked example (AC-5), June 2026:**
  `monthStartUtc = 2026-05-31T18:30:00Z` (= `2026-06-01T00:00:00+05:30`);
  `nextMonthStartUtc = 2026-06-30T18:30:00Z`. An expense at
  `2026-05-31T23:00 IST` (= `2026-05-31T17:30Z`) is **excluded**; one at
  `2026-06-01T00:30 IST` (= `2026-05-31T19:00Z`) is **included**.

### 4. Domain signatures (pure; no Flutter/Firestore deps beyond `ExpenseDoc`)

```dart
// lib/features/home/domain/monthly_spend_breakdown.dart
@immutable
class CategorySpend {
  const CategorySpend({required this.category, required this.totalPaise});
  final ExpenseCategory category;
  final int totalPaise; // > 0 (zero categories are omitted)
}

@immutable
class MonthlySpendBreakdown {
  const MonthlySpendBreakdown({required this.categories, required this.monthTotalPaise});
  final List<CategorySpend> categories; // non-zero only, descending paise, unmodifiable
  final int monthTotalPaise;            // == sum of categories' totalPaise
  bool get isEmpty => categories.isEmpty; // drives the empty card
}
```

```dart
// lib/features/home/domain/monthly_spend_aggregator.dart
typedef FriendshipExpenses = ({String otherUserId, List<ExpenseDoc> expenses});

({DateTime startUtc, DateTime endUtc}) currentMonthWindowIst(DateTime now);

MonthlySpendBreakdown aggregateMonthlySpend({
  required Iterable<FriendshipExpenses> input,
  required DateTime monthStartUtc,
  required DateTime nextMonthStartUtc,
});
```

`aggregateMonthlySpend` folds each in-window expense's user share (§2)
into a `Map<ExpenseCategory,int>`, drops zero-valued categories, sorts
descending by paise (stable; tie-break on `ExpenseCategory.index` for
determinism), and sums `monthTotalPaise`.

### 5. Provider + repository signatures

```dart
// lib/features/home/application/monthly_spend_breakdown_provider.dart

// Feature-local injectable clock (global/unscoped -> NOT in `dependencies`).
// Mirrors the codebase's `DateTime Function()? clock` convention. Override
// in provider-level month tests for determinism; default is DateTime.now.
final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final monthlySpendBreakdownProvider =
    FutureProvider<MonthlySpendBreakdown>((ref) async {
  final items = await ref.watch(friendsListProvider.future); // already resolved (card is in _PopulatedState)
  final window = currentMonthWindowIst(ref.watch(homeClockProvider)());
  final repo = ref.watch(expenseRepositoryProvider);
  final perFriendship = await Future.wait(items.map((item) async {
    final expenses = await repo.fetchExpensesInMonth(
      friendshipId: item.friendshipId,
      monthStartUtc: window.startUtc,
    );
    return (otherUserId: item.otherUserId, expenses: expenses);
  }));
  return aggregateMonthlySpend(
    input: perFriendship,
    monthStartUtc: window.startUtc,
    nextMonthStartUtc: window.endUtc,
  );
}, dependencies: [friendsListProvider]); // <-- exactly this; NOT currentUserIdProvider
```

```dart
// lib/features/expenses/data/expense_repository.dart — add to ExpenseStore,
// FirestoreExpenseStore, and ExpenseRepository:
Future<List<ExpenseDoc>> fetchExpensesInMonth({
  required String friendshipId,
  required DateTime monthStartUtc,
});
// FirestoreExpenseStore impl (mirror watchExpensesByFriendship, one-shot .get()):
//   _expensesCollection(friendshipId)
//     .where('deleted', isEqualTo: false)
//     .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStartUtc))
//     .orderBy('date', descending: true)   // reuses the existing composite index
//     .get()  -> map docs via ExpenseDoc.fromMap (reuse _parseExpense)
```

- **Deleted-exclusion (AC-6)** is enforced by the
  `where('deleted', isEqualTo: false)` query predicate (identical to
  `watchExpensesByFriendship`); `ExpenseDoc` does not carry `deleted`, so
  the reducer never sees deleted docs. Verify the predicate in a
  store-contract test and in QA's emulator pass.
- **Retry (AC-9):** `ref.invalidate(monthlySpendBreakdownProvider)` —
  re-runs the fan-out. Because the card is in `_PopulatedState`, the only
  failure source is the fan-out fetch, so invalidating the breakdown
  provider alone is sufficient (no need to disturb the balances axis).

### 6. Telemetry contract

- Extend `HomeTelemetry` (`home_telemetry.dart`) with
  `static const String spendingBreakdownViewed = 'home_spending_breakdown_viewed';`
  and `static const String paramCategoryCount = 'category_count';`.
- Fire **once per mount**, on the **first terminal render** of
  `SpendingBreakdownCard` (populated **and** empty sub-states), gated by a
  private `bool _loggedBreakdownView` on the card's state (mirror the
  `_loggedView` pattern). **Never** fire on loading (AC-8) or error
  (AC-17).
- Payload is **only** `{ category_count: <0..8> }` (`0` in the empty
  state). No `uid`, no `friendshipId` (raw or hashed), no name/photo/phone,
  no rupee/paise value (AC-18; SRS line 308; ADR-0013). No hashing —
  nothing hashable is emitted.
- **Declare** the event in `docs/design/07-technical/telemetry-plan.md`
  **section 1.3** (Home and Search Events), alongside the six `home_*`
  rows.

### 7. Charting + palette + accessibility contract

- Chart isolated in `SpendingDonutChart` (donut vs horizontal-bar is the
  Designer's Phase-3 call; the widget renders whatever shape from
  `MonthlySpendBreakdown`). Segment geometry is the **integer-paise ratio**
  `categoryPaise / monthTotalPaise`.
- **Category palette is feature-local**, NOT a `ThemeExtension` (codebase
  convention, `tokens.md`):
  `spending_category_palette.dart` exposes brightness-aware
  `Map<ExpenseCategory, Color>` light/dark `static const` maps selected by
  `Theme.of(context).brightness`. **The Designer owns the colour values**
  (8 categories, dark-mode-safe, WCAG 2.1 AA) — Phase 3 fills them; Phase 4
  wires them.
- **A11y (AC-13/AC-14):** the chart is decorative; each segment exposes a
  `Semantics` label "`[label], [formatInrFromPaise(paise)], [pct] percent`"
  (e.g. "Food, ₹700.00, 70 percent"); the month total is announced
  separately. **Never colour-only**; a legend maps colour → label →
  rupee subtotal.

### 8. File-by-file build map

**New production files (6):**

1. `lib/features/home/domain/monthly_spend_breakdown.dart` —
   `CategorySpend`, `MonthlySpendBreakdown` (§4).
2. `lib/features/home/domain/monthly_spend_aggregator.dart` — pure
   `currentMonthWindowIst` + `aggregateMonthlySpend` (§3, §4).
3. `lib/features/home/application/monthly_spend_breakdown_provider.dart` —
   `monthlySpendBreakdownProvider` + `homeClockProvider` (§5).
4. `lib/features/home/presentation/widgets/spending_breakdown_card.dart` —
   `SpendingBreakdownCard` (`ConsumerStatefulWidget`; loading/empty/
   populated/error sub-states; owns the single-fire gate; reuses
   `ContactSupportController` + `HD-FIRESTORE-READ`).
5. `lib/features/home/presentation/widgets/spending_donut_chart.dart` —
   the `fl_chart` wrapper + per-segment `Semantics` (§7).
6. `lib/features/home/presentation/widgets/spending_category_palette.dart`
   — brightness-aware category→colour maps (Designer-owned values, §7).

**Modified (5) + deleted (1):**

- `lib/features/home/presentation/home_dashboard_screen.dart` — swap
  line 388 `const SpendingBreakdownPlaceholderCard()` →
  `const SpendingBreakdownCard()`. No other dashboard change.
- `lib/features/home/application/home_telemetry.dart` — add the two
  constants (§6).
- `lib/features/expenses/data/expense_repository.dart` — add
  `fetchExpensesInMonth` to `ExpenseStore`, `FirestoreExpenseStore`,
  `ExpenseRepository` (§5).
- `pubspec.yaml` — add `fl_chart: ^1.2.0` (alphabetical, with an inline
  comment: pure-Dart, no CocoaPod / no `ios/Podfile.lock` change; requires
  Flutter >= 3.27.4 / Dart >= 3.6.2).
- `lib/features/home/README.md`,
  `docs/design/07-technical/telemetry-plan.md` (§1.3), and the SCR-06 doc
  — update from placeholder to the shipped chart (per DoD).
- **Delete**
  `lib/features/home/presentation/widgets/spending_breakdown_placeholder_card.dart`.

**New test files (3) + extensions (2):**

- `test/features/home/monthly_spend_aggregator_test.dart` — pure reducer +
  window (AC-1, AC-2, AC-4, AC-5, AC-7, AC-11, AC-12, descending sort,
  integer-paise).
- `test/features/home/monthly_spend_breakdown_provider_test.dart` —
  fan-out over recording fakes (`FriendshipRepository` + the `ExpenseStore`
  `fetchExpensesInMonth` fake), overriding `currentUserIdProvider`,
  `friendsListProvider`, and `homeClockProvider`; multi-friendship fold,
  loading/error propagation, Retry invalidation.
- `test/features/home/spending_breakdown_card_test.dart` — widget +
  a11y + single-fire telemetry (incl. `category_count: 0` empty, no-fire on
  error).
- **Extend** `test/features/home/home_boundary_contract_test.dart` —
  Inv-1 grep (no `double`/`/ 100`/`.toFixed`/`.toDouble`/`parseFloat`) and
  Inv-2 grep (no `simplifiedBalances`) over the new files (AC-19, AC-20).
- **Extend** `test/features/home/home_dashboard_pii_leak_test.dart` — PII
  grep over the new card/provider files (AC-18).

### 9. Invariants and refusals (reaffirmed)

- **Inv-1 (CRITICAL):** integer paise everywhere; only `formatInrFromPaise`
  converts. **Inv-2 (N/A):** never read/derive `simplifiedBalances`.
  **Inv-3 (N/A):** no share/export. **Inv-4 (reinforced):** single project,
  emulator testing.
- **Refuse** any attempt to: sum `amountPaise` instead of the user's share;
  use `double`/`/ 100` for any subtotal/total; read `simplifiedBalances`;
  compute the month boundary in device-local/UTC time; log `uid`/
  `friendshipId`/rupee value as a telemetry param; or build Groups /
  rollup / drill-down / share beyond the stubs and follow-ups named above.
