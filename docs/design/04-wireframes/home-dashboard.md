> [!WARNING]
> **Superseded — historical reference only.** As of **ADR-0024** the Haldi visual
> system (`design_handoff_one_by_two/`) is the canonical source of truth for colour,
> type, shape, motion and visuals. This document predates the Sprint-3 Haldi
> conversion and is retained for history; do **not** build new work against its
> tokens, type, or visuals. See `.github/shared/decision-log.md` (ADR-0024).

# Home Dashboard Wireframes

This document specifies the wireframe layouts for the Home Dashboard screen (SRS section 6.3, Core Screen 5) across all required states. Each layout references components from the One By Two Component Catalogue (`docs/design/02-design-system/components.md`) and satisfies functional requirements FR-HD-01 through FR-HD-04 (SRS section 4.8).

All monetary values displayed are converted from integer paise at the UI layer (Invariant 1). Balance data is read from the `simplifiedBalances` field, which is server-maintained and client-read-only (Invariant 2).

> **Status: planned.** The Home tab currently renders `HomeDashboardPlaceholder` ('The real dashboard is coming soon'). FR-HD-01/02 surfaces below are not yet built; the persistent FAB + context picker (FR-HD-04) **is** implemented in `AuthenticatedShell`.

---

## Design Token Quick Reference

Per SRS section 6.2:

| Token | Value | Applied To |
|---|---|---|
| `success` | `#2A9D8F` | "You are owed" balance header, positive balance pills |
| `danger` | `#E76F51` | "You owe" balance header, negative balance pills |
| `secondary` | `#F4A261` | FAB background |
| `surface` | `#FFFFFF` / `#121212` dark | Cards, screen background |
| `cornerRadiusLarge` | 24 dp | Balance header card, category chart card |
| `cornerRadiusSmall` | 16 dp | Balance pills, list tile corners |
| `elevationLow` | 1 dp shadow | Resting cards |
| `elevationMedium` | 4 dp shadow | FAB |
| `motionStandard` | 200--300 ms ease-in-out | State transitions, list tile press |
| `motionSpring` | Spring physics (damping ~0.7) | FAB press/release |

---

## 1. Empty State

Displayed when a new user has no expenses, no friends with balances, and no group memberships with balances. Satisfies SRS section 6.4 (explicit empty state with actionable copy) and section 6.5 (microcopy tone).

```
+--------------------------------------------------+
|  OBTAppBar                                        |
|  title: "Home"                     [no actions]   |
+--------------------------------------------------+
|                                                    |
|  +----------------------------------------------+ |
|  | Net Balance Card (24 dp radius, elevationLow) | |
|  |                                                | |
|  |       Net balance                              | |
|  |       ₹0.00                                    | |
|  |       (colour: onSurface, muted)               | |
|  +----------------------------------------------+ |
|                                                    |
|  +----------------------------------------------+ |
|  | OBTEmptyState                                  | |
|  |                                                | |
|  |        [illustration: empty_wallet.svg]        | |
|  |         (decorative, excludeSemantics)          | |
|  |                                                | |
|  |       "No expenses yet"                        | |
|  |       (bold title, heading semantics)           | |
|  |                                                | |
|  |  "Add your first expense and start splitting!" | |
|  |       (muted subtitle)                          | |
|  |                                                | |
|  |       [ Add Expense ]                          | |
|  |       (primary CTA, primary colour)             | |
|  +----------------------------------------------+ |
|                                                    |
|                                          [  +  ]   |
|                              OBTFloatingActionButton|
|                              (secondary, 56x56 dp)  |
+--------------------------------------------------+
| OBTBottomNav                                       |
| [Home*]  [Friends]  [Groups]  [Activity] [Profile] |
+--------------------------------------------------+
```

### Component Mapping

| Area | Component | Props |
|---|---|---|
| Top bar | `OBTAppBar` | `title: "Home"`, `showBackButton: false`; implemented host currently uses Material `AppBar` in code |
| Balance card | Custom card | `balancePaise: 0`, corner radius 24 dp, `elevationLow` |
| Empty body | `OBTEmptyState` | `illustration: empty_wallet`, `title: "No expenses yet"`, `subtitle: "Add your first expense and start splitting!"`, `ctaLabel: "Add Expense"`, `onCtaTap: -> open Add Expense flow` |
| FAB | `OBTFloatingActionButton` | `onPressed: -> open Add Expense flow` |
| Nav bar | `OBTBottomNav` | `currentIndex: 0` |

### Accessibility Notes

- The `OBTEmptyState` illustration is decorative (`excludeSemantics: true`).
- The CTA button semantic label: `"Add Expense"`.
- Net balance is announced as `"Net balance: rupees zero"`.
- FAB semantic label: `"Add new expense"` (SRS section 5.6).

---

## 2. Populated State

Displayed when the user has at least one non-zero simplified balance. Satisfies FR-HD-01 (net balance as primary visual element), FR-HD-02 (top 5 friends/groups with quick settle), FR-HD-03 (current-month category breakdown, P1), and FR-HD-04 (persistent FAB).

```
+--------------------------------------------------+
|  OBTAppBar                                        |
|  title: "Home"                     [no actions]   |
+--------------------------------------------------+
|                                                    |
|  +----------------------------------------------+ |
|  | Net Balance Header Card                        | |
|  | (24 dp radius, elevationLow)                   | |
|  |                                                | |
|  |  "Overall, you are owed"   OR  "Overall, you  | |
|  |                                 owe"           | |
|  |  ₹1,234.50                                    | |
|  |  (success colour if owed,                      | |
|  |   danger colour if owing)                      | |
|  |                                                | |
|  |  Background: success/danger at 12% opacity     | |
|  +----------------------------------------------+ |
|                                                    |
|  Section Header: "Top Balances"                    |
|                                                    |
|  +----------------------------------------------+ |
|  | OBTFriendListTile                              | |
|  | [OBTUserAvatar]  Priya Sharma                  | |
|  |                            [OBTBalancePill]    | |
|  |                            "you are owed ₹800" | |
|  |                   [Settle Up]  (text button)    | |
|  +----------------------------------------------+ |
|  +----------------------------------------------+ |
|  | OBTGroupListTile                               | |
|  | [OBTGroupAvatar] Goa Trip                      | |
|  |                  Trip . 5 members               | |
|  |                            [OBTBalancePill]    | |
|  |                            "you owe ₹1,500"    | |
|  |                   [Settle Up]  (text button)    | |
|  +----------------------------------------------+ |
|  +----------------------------------------------+ |
|  | OBTFriendListTile                              | |
|  | [OBTUserAvatar]  Rahul Mehta                   | |
|  |                            [OBTBalancePill]    | |
|  |                            "you owe ₹350"      | |
|  |                   [Settle Up]  (text button)    | |
|  +----------------------------------------------+ |
|  +----------------------------------------------+ |
|  | ... (up to 5 items, sorted by |balance| desc) | |
|  +----------------------------------------------+ |
|                                                    |
|  Section Header: "This Month"                      |
|                                                    |
|  +----------------------------------------------+ |
|  | Category Breakdown Card (P1)                   | |
|  | (24 dp radius, elevationLow)                   | |
|  |                                                | |
|  |  [  Donut/Bar chart placeholder area  ]        | |
|  |  160 dp height                                  | |
|  |                                                | |
|  |  "Spending breakdown coming soon"              | |
|  |  (muted placeholder text for v1.0)              | |
|  +----------------------------------------------+ |
|                                                    |
|                                          [  +  ]   |
|                              OBTFloatingActionButton|
+--------------------------------------------------+
| OBTBottomNav                                       |
| [Home*]  [Friends]  [Groups]  [Activity] [Profile] |
+--------------------------------------------------+
```

### Component Mapping

| Area | Component | Props / Notes |
|---|---|---|
| Balance header | Custom card | `balancePaise: <net total>`, colour-coded per `OBTBalancePill` logic (SRS section 6.2: success for positive, danger for negative). Corner radius 24 dp. |
| Top balances list | `OBTFriendListTile` or `OBTGroupListTile` | Up to 5 items sorted by absolute balance descending. Each tile includes its standard props plus a trailing `"Settle Up"` text button. |
| Balance pills | `OBTBalancePill` | `balancePaise: <per-item balance>`, `size: medium` |
| Settle Up action | Text button | Label: `"Settle Up"`, navigates to Settle Up flow pre-filled with the friend/group context (FR-SE-05). |
| Category card | Placeholder card | P1 feature (FR-HD-03). Renders a static placeholder in v1.0; area reserved for donut/bar chart. |
| FAB | `OBTFloatingActionButton` | Always visible, always active (FR-HD-04). |
| Nav bar | `OBTBottomNav` | `currentIndex: 0` |

### Colour Logic (FR-HD-01)

| Condition | Header Text | Header Colour | Background Tint |
|---|---|---|---|
| Net balance > 0 (paise) | `"Overall, you are owed"` | `success` (`#2A9D8F`) | `success` at 12% opacity |
| Net balance < 0 (paise) | `"Overall, you owe"` | `danger` (`#E76F51`) | `danger` at 12% opacity |
| Net balance = 0 (paise) | `"You're all settled up -- high five!"` | `onSurface` (muted) | `onSurface` at 8% opacity |

### Settle Up Button Placement

Each list tile in the "Top Balances" section includes a compact `"Settle Up"` text button rendered below or inline with the balance pill. This satisfies FR-HD-02 ("quick access to settle"). Tapping the button opens the Settle Up flow (SRS section 6.3, Core Screen 9) with the friend or group context pre-filled (FR-SE-05).

- Minimum tap target for the Settle Up button: 48x48 dp (SRS section 5.6).
- Button text colour: `primary` (`#1F4E79`).

### Category Breakdown (P1 -- FR-HD-03)

The current-month category breakdown is a P1 requirement. In v1.0, this area renders as a placeholder card with muted text: `"Spending breakdown coming soon"`. The card reserves 160 dp of height and uses 24 dp corner radius to match the visual system.

When implemented, this area will display:

- A donut or horizontal bar chart segmented by expense category.
- Category colour mapping as defined in `OBTCategoryChip` (Component 12).
- Data scoped to the current calendar month.

### Accessibility Notes

- Balance header semantic label: `"Overall balance: you are owed rupees [amount]"` or `"Overall balance: you owe rupees [amount]"` or `"Overall balance: all settled up"`.
- Each list tile follows the accessibility patterns defined in `OBTFriendListTile` (Component 16) and `OBTGroupListTile` (Component 17).
- The Settle Up button carries the label `"Settle up with [name], rupees [amount]"`.
- The category placeholder card carries the label `"Monthly spending breakdown, coming soon"`.
- No information is conveyed by colour alone; the textual labels `"you are owed"` and `"you owe"` provide the direction alongside the colour coding (SRS section 5.6).

---

## 3. Loading / Skeleton State

Displayed on initial data fetch. Satisfies SRS section 6.4 (skeleton screens preferred over spinners).

```
+--------------------------------------------------+
|  OBTAppBar                                        |
|  title: "Home"                                    |
+--------------------------------------------------+
|                                                    |
|  +----------------------------------------------+ |
|  | OBTSkeletonLoader (type: balancePill)          | |
|  | [==shimmer== 80x28 dp rounded rect ==]         | |
|  | (centred within 24 dp radius card area)         | |
|  +----------------------------------------------+ |
|                                                    |
|  +----------------------------------------------+ |
|  | OBTSkeletonLoader (type: listTile, count: 5)   | |
|  |                                                | |
|  | [ O ]  [====shimmer=60%====]  [==pill==]       | |
|  |         [==shimmer=40%==]                       | |
|  | ----------------------------------------       | |
|  | [ O ]  [====shimmer=60%====]  [==pill==]       | |
|  |         [==shimmer=40%==]                       | |
|  | ----------------------------------------       | |
|  | [ O ]  [====shimmer=60%====]  [==pill==]       | |
|  |         [==shimmer=40%==]                       | |
|  | ----------------------------------------       | |
|  | [ O ]  [====shimmer=60%====]  [==pill==]       | |
|  |         [==shimmer=40%==]                       | |
|  | ----------------------------------------       | |
|  | [ O ]  [====shimmer=60%====]  [==pill==]       | |
|  |         [==shimmer=40%==]                       | |
|  +----------------------------------------------+ |
|                                                    |
|  +----------------------------------------------+ |
|  | OBTSkeletonLoader (type: chart)                | |
|  |                                                | |
|  |         [  shimmer circle 160x160  ]           | |
|  |    [==bar==]  [==bar==]  [==bar==]             | |
|  +----------------------------------------------+ |
|                                                    |
|                                          [  +  ]   |
|                              OBTFloatingActionButton|
+--------------------------------------------------+
| OBTBottomNav                                       |
| [Home*]  [Friends]  [Groups]  [Activity] [Profile] |
+--------------------------------------------------+
```

### Component Mapping

| Area | Component | Props |
|---|---|---|
| Balance skeleton | `OBTSkeletonLoader` | `type: balancePill` -- single 80x28 dp rounded rectangle with shimmer. |
| List skeleton | `OBTSkeletonLoader` | `type: listTile`, `itemCount: 5` -- each row: 40 dp circle + two text rectangles (60% and 40% width) + trailing 48x20 dp pill rectangle. |
| Chart skeleton | `OBTSkeletonLoader` | `type: chart` -- 160x160 dp circle (donut placeholder) + three 12 dp-high bar lines. |
| FAB | `OBTFloatingActionButton` | Visible and active during loading (FR-HD-04). Users may begin adding an expense while data loads. |
| Nav bar | `OBTBottomNav` | `currentIndex: 0` |

### Animation

- Shimmer direction: left-to-right gradient sweep, 1.5 s loop (Component 20 spec).
- When data arrives, skeleton fades out and content fades in over 200 ms (SRS section 6.2, `motionStandard`).
- If `AccessibilityFeatures.reduceMotion` is enabled, shimmer is replaced by a static grey placeholder (Component 20 spec, SRS section 5.6).

### Accessibility Notes

- Entire skeleton group carries `Semantics(label: "Loading content", liveRegion: true)`.
- When content loads, the live region announces the new content automatically.

---

## 4. Error State

Displayed when the Firestore read for balances or friends/groups data fails. Satisfies SRS section 6.4 (error states with Retry and path to Contact Support) and FR-PR-05 / FR-SH-03 (Contact Support action).

```
+--------------------------------------------------+
|  OBTAppBar                                        |
|  title: "Home"                                    |
+--------------------------------------------------+
|                                                    |
|                                                    |
|  +----------------------------------------------+ |
|  | OBTErrorState                                  | |
|  |                                                | |
|  |      [illustration: error_cloud.svg]           | |
|  |      (decorative, excludeSemantics)             | |
|  |                                                | |
|  |      "Something went wrong"                    | |
|  |      (bold title, heading semantics)            | |
|  |                                                | |
|  |  "We could not load your balances.             | |
|  |   Please check your connection and try again." | |
|  |      (muted subtitle)                           | |
|  |                                                | |
|  |             [ Retry ]                          | |
|  |      (primary filled button)                    | |
|  |                                                | |
|  |         Contact Support                        | |
|  |      (text link, primary colour)                | |
|  |                                                | |
|  |      Error code: HD-FIRESTORE-READ             | |
|  |      (small, muted, for support triage)         | |
|  +----------------------------------------------+ |
|                                                    |
|                                                    |
|                                          [  +  ]   |
|                              OBTFloatingActionButton|
+--------------------------------------------------+
| OBTBottomNav                                       |
| [Home*]  [Friends]  [Groups]  [Activity] [Profile] |
+--------------------------------------------------+
```

### Component Mapping

| Area | Component | Props |
|---|---|---|
| Error body | `OBTErrorState` | `title: "Something went wrong"`, `subtitle: "We could not load your balances. Please check your connection and try again."`, `onRetry: -> re-fetch data`, `onContactSupport: -> open mailto: flow (FR-PR-05)`, `errorCode: "HD-FIRESTORE-READ"` |
| FAB | `OBTFloatingActionButton` | Remains visible and active. The user may still add an expense (it will be queued if offline, per FR-OF-02). |
| Nav bar | `OBTBottomNav` | `currentIndex: 0` |

### Retry Behaviour

1. On first retry press, the button shows a loading indicator and re-invokes the Firestore read.
2. If retry fails, the subtitle updates to: `"Still not working. Try again or contact support."` (Component 19 spec).
3. The Contact Support link opens the device mail client pre-filled per FR-SH-03, or falls back to a copy-address dialogue per FR-SH-04.

### Accessibility Notes

- Error illustration is decorative (`excludeSemantics: true`).
- Title announced as heading.
- Retry button label: `"Retry"`.
- Contact Support link label: `"Contact support"`.
- Error code announced as: `"Error code: HD-FIRESTORE-READ"`.

---

## 5. Offline State

Displayed when the device has no network connectivity but cached data is available. Satisfies FR-OF-01 (view previously-loaded data offline) and FR-OF-02 (add expense while offline).

```
+--------------------------------------------------+
|  OBTAppBar                                        |
|  title: "Home"                                    |
+--------------------------------------------------+
|  +----------------------------------------------+ |
|  | Offline Banner                                 | |
|  | (full-width, secondary background at 15%,      | |
|  |  corner radius 0, 40 dp height)                | |
|  |                                                | |
|  |  [info icon]  "Offline -- data may be outdated" | |
|  |  (secondary text colour)                        | |
|  +----------------------------------------------+ |
|                                                    |
|  +----------------------------------------------+ |
|  | Net Balance Header Card                        | |
|  | (same as Populated State, from cache)           | |
|  |                                                | |
|  |  "Overall, you are owed"                       | |
|  |  ₹1,234.50                                    | |
|  |  (success colour)                               | |
|  +----------------------------------------------+ |
|                                                    |
|  Section Header: "Top Balances"                    |
|                                                    |
|  +----------------------------------------------+ |
|  | OBTFriendListTile (cached data)                | |
|  | [OBTUserAvatar]  Priya Sharma                  | |
|  |                            [OBTBalancePill]    | |
|  |                   [Settle Up]  (active)         | |
|  +----------------------------------------------+ |
|  | ... (remaining cached items)                   | |
|  +----------------------------------------------+ |
|                                                    |
|  +----------------------------------------------+ |
|  | Category Breakdown Card (P1 placeholder)       | |
|  +----------------------------------------------+ |
|                                                    |
|                                          [  +  ]   |
|                              OBTFloatingActionButton|
|                              (active -- queues write)|
+--------------------------------------------------+
| OBTBottomNav                                       |
| [Home*]  [Friends]  [Groups]  [Activity] [Profile] |
+--------------------------------------------------+
```

### Component Mapping

| Area | Component | Props / Notes |
|---|---|---|
| Offline banner | `OBTSnackbar`-style persistent banner | `message: "Offline -- data may be outdated"`, `type: info`, rendered as a non-dismissible banner pinned below the app bar. Uses `secondary` (`#F4A261`) at 15% opacity background with `secondary` text. |
| Balance header | Same as Populated State | Data sourced from Firestore offline cache. |
| Top balances list | `OBTFriendListTile` / `OBTGroupListTile` | Cached data. Settle Up buttons remain active; tapping queues the settlement write (FR-OF-02). |
| FAB | `OBTFloatingActionButton` | Active. Adding an expense queues the write locally; an `OBTSnackbar` confirms: `"Expense saved offline. It will sync when you're back online."` (FR-OF-02). |
| Nav bar | `OBTBottomNav` | `currentIndex: 0` |

### Transition Behaviour

- When connectivity returns, the offline banner slides out (200 ms ease-in-out) and data refreshes from Firestore.
- Queued writes sync automatically; the `recomputeSimplifiedBalances` Cloud Function runs on sync (Invariant 2).
- If a queued write conflicts, the user is notified via `OBTSnackbar` with `type: info` (FR-OF-03).

### Accessibility Notes

- Offline banner is announced as a live region: `"Info: Offline, data may be outdated"`.
- All cached data retains the same semantic labels as the Populated State.
- The FAB continues to announce `"Add new expense"`.

---

## Bottom Navigation

The `OBTBottomNav` component (Component 2) is persistent across all five states. On the Home Dashboard, `currentIndex` is `0`.

```
+--------------------------------------------------+
| [Home]    [Friends]   [Groups]  [Activity] [Profile]|
|  (*)                                               |
|                                                    |
| Active: filled icon, primary colour label,          |
|         indicator pill behind icon                  |
| Inactive: outlined icon, muted label colour         |
+--------------------------------------------------+
```

| Index | Label | Icon | State on Home |
|---|---|---|---|
| 0 | Home | `home` | Active (filled icon, `primary` label, indicator pill) |
| 1 | Friends | `people` | Inactive (outlined icon, muted label) |
| 2 | Groups | `groups` | Inactive |
| 3 | Activity | `notifications` | Inactive |
| 4 | Profile | `person` | Inactive |

- Each tab meets the 48x48 dp minimum tap target (SRS section 5.6).
- Active tab announces `"Home, tab, selected"` to screen readers.
- Tab transitions use 200 ms ease-in-out (SRS section 6.2, `motionStandard`).
- The FAB floats above the bottom nav bar, not overlapping any tab target.

---

## Extension Points

These areas are designed for future expansion without structural redesign of the Home Dashboard.

### Monthly Spend Chart (P1 -- FR-HD-03)

The placeholder card in the "This Month" section is sized and positioned to accommodate a full category breakdown chart. In v1.1 or when the P1 milestone is reached:

- The placeholder text is replaced by a donut or horizontal bar chart.
- Category segments use the colour mapping from `OBTCategoryChip` (Component 12).
- Tapping a segment could navigate to a filtered expense list for that category.
- The chart area could expand into a dedicated Analytics tab or full-screen view.

### Multi-Currency Toggle (Out of Scope -- SRS section 12.3)

The balance header card's layout reserves no space for a currency toggle in v1.0, as multi-currency support is explicitly out of scope (SRS section 12.3). In v1.1, should multi-currency be approved:

- A small currency selector could be placed to the right of the balance amount.
- The balance header card height would increase by approximately 32 dp.
- All currency conversion logic would remain server-side, with the client displaying the result.

---

## SRS Traceability Matrix

| Wireframe Element | SRS Requirement | Priority |
|---|---|---|
| Net balance header card | FR-HD-01 (net simplified balance as primary visual element) | P0 |
| Top 5 friends/groups list with Settle Up | FR-HD-02 (top 5 by absolute balance, quick settle) | P0 |
| Category breakdown placeholder | FR-HD-03 (current-month category breakdown) | P1 |
| Persistent FAB | FR-HD-04 (FAB on any primary tab) | P0 |
| Skeleton loading state | Section 6.4 (skeleton preferred over spinners) | P0 |
| Empty state with CTA | Section 6.4 (explicit empty state with actionable copy) | P0 |
| Error state with Retry and Contact Support | Section 6.4 (Retry + Contact Support path); FR-PR-05 | P0 |
| Offline banner with cached data | FR-OF-01 (view cached data offline) | P0 |
| Offline FAB queuing writes | FR-OF-02 (add expense offline, sync on reconnect) | P1 |
| Colour-coded balance (success/danger) | Section 6.2 (success = owed, danger = owing) | P0 |
| Bottom navigation | Section 6.3 (five primary screens) | P0 |