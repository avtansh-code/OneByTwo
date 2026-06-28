> [!WARNING]
> **Superseded — historical reference only.** As of **ADR-0024** the Haldi visual
> system (`design_handoff_one_by_two/`) is the canonical source of truth for colour,
> type, shape, motion and visuals. This document predates the Sprint-3 Haldi
> conversion and is retained for history; do **not** build new work against its
> tokens, type, or visuals. See `.github/shared/decision-log.md` (ADR-0024).

# Screen Specifications: Home Dashboard, Search Overlay, and Add Expense Entry Point

> **Document status:** Draft
> **SRS version:** 1.1
> **Audience:** Flutter Developer, QA Engineer, Solution Architect
> **Screens covered:** SCR-06, SCR-07, SCR-08

This document specifies three interconnected screens for One By Two v1.0: the Home Dashboard, the Search Overlay, and the Add Expense entry point (FAB action). Each specification includes layout, states, inputs, accessibility, telemetry, edge cases, and open questions.

All monetary values are integer paise (Invariant 1, SRS section 7.3). Balance data is read from the `simplifiedBalances` field, which is server-maintained and client-read-only (Invariant 2, SRS sections 4.6, 7.3, 7.5). All outbound sharing uses the platform system share sheet only (Invariant 3, SRS sections 3.4, 4.11, 12.2).

> **Implementation status (verified against `lib/`, this pass).** **SCR-06 Home Dashboard implemented** (`HomeDashboardScreen` -- FR-HD-01 net balance, FR-HD-02 top balances, FR-HD-03 spend breakdown; no longer a placeholder); **SCR-07 Search not implemented**; **SCR-08 Add-Expense entry implemented** (`AddExpenseContextPickerSheet` → `AddExpenseBottomSheet`).

---

## Table of Contents

1. [SCR-06: Home Dashboard](#scr-06-home-dashboard)
2. [SCR-07: Search Overlay](#scr-07-search-overlay)
3. [SCR-08: Add Expense Entry Point](#scr-08-add-expense-entry-point)

---

## SCR-06: Home Dashboard

### Overview

| Field | Value |
|---|---|
| **Screen ID** | SCR-06 |
| **Screen Name** | Home Dashboard |
| **Purpose** | Present the user's overall financial position at a glance: net simplified balance, top friends/groups by balance, current-month spend summary, and a persistent entry point for adding expenses. This is the primary landing screen after authentication. |
| **Route** | `/home` |
| **SRS Requirements** | FR-HD-01 (net simplified balance as primary visual element), FR-HD-02 (top 5 friends/groups by absolute simplified balance with quick settle), FR-HD-03 (current-month category breakdown, P1), FR-HD-04 (persistent FAB on any primary tab) |

### Navigation Context

| Direction | Screens |
|---|---|
| **Reachable from** | Splash (`/splash`, via auth-guard redirect for authenticated users), OTP Verification (`/auth/otp`, returning user redirect), Profile Setup (`/auth/profile-setup`, after first-time setup), any tab via `OBTBottomNav` (tab index 0), deep-link to `/home` |
| **Leads to** | Friend Detail (`/friends/:friendshipId`, via top-balances list tile tap), Group Detail (`/groups/:groupId`, via top-balances list tile tap), Settle Up flow (modal bottom sheet, via "Settle Up" button on any list tile), Add Expense flow (modal bottom sheet, via FAB -- see SCR-08), Search Overlay (`/search`, via app bar action if enabled), Friends tab (`/friends`), Groups tab (`/groups`), Activity tab (`/activity`), Profile tab (`/profile`) |

### Components Used

| Component | Catalogue Reference | Usage on This Screen |
|---|---|---|
| `OBTAppBar` | Component 1 | Top bar with title "Home", no back button, no trailing actions in v1.0. |
| `OBTBottomNav` | Component 2 | Five-tab navigation bar; `currentIndex: 0` (Home active). |
| `OBTFloatingActionButton` | Component 3 | Persistent FAB for adding an expense; `secondary` background, white `+` icon. |
| `OBTBalancePill` | Component 4 | Per-item balance display in the top-balances list. |
| `OBTRupeeText` | Component 5 | Net balance amount in the header card. |
| `OBTFriendListTile` | Component 16 | Friend rows in the top-balances section. |
| `OBTGroupListTile` | Component 17 | Group rows in the top-balances section. |
| `OBTEmptyState` | Component 18 | Empty-state body when no balances exist. |
| `OBTErrorState` | Component 19 | Error-state body when data fetch fails. |
| `OBTSkeletonLoader` | Component 20 | Shimmer placeholders during initial load. |
| `OBTSnackbar` | Component 25 | Feedback for offline queued writes (FR-OF-02). |

### States

#### 1. Default / Loading State

Displayed on initial data fetch or when the screen is revisited after cache invalidation.

- The `OBTAppBar` renders with title "Home".
- The body renders `OBTSkeletonLoader` instances:
  - One `balancePill`-type skeleton (80x28 dp rounded rectangle, centred within a 24 dp corner-radius card area).
  - Five `listTile`-type skeletons (40 dp circle + two text rectangles at 60% and 40% width + trailing 48x20 dp pill rectangle).
  - One `chart`-type skeleton (160x160 dp circle + three 12 dp-high bar lines).
- The FAB is visible and active during loading. Users may begin adding an expense whilst data loads (FR-HD-04).
- Shimmer direction: left-to-right gradient sweep, 1.5 s loop. If `AccessibilityFeatures.reduceMotion` is enabled, shimmer is replaced by a static grey placeholder (SRS section 5.6).
- When data arrives, skeleton fades out and content fades in over 200 ms (`motionStandard`, SRS section 6.2).

#### 2. Empty State

Displayed when a new user has no expenses, no friends with balances, and no group memberships with balances.

- **Net Balance Card:** Displays `0.00` in muted `onSurface` colour, within a 24 dp corner-radius card with `elevationLow`.
- **Empty body:** `OBTEmptyState` with:
  - Illustration: `empty_wallet.svg` (decorative, `excludeSemantics: true`).
  - Title: "No expenses yet" (bold, heading semantics).
  - Subtitle: "Add your first expense and start splitting!" (muted, SRS section 6.5 tone).
  - CTA button: "Add Expense" (primary colour), which opens the Add Expense flow.
- The FAB remains visible and active.

#### 3. Populated State

Displayed when the user has at least one non-zero simplified balance.

- **Net Balance Header Card** (24 dp corner radius, `elevationLow`):

  | Condition | Header text | Text colour | Background tint |
  |---|---|---|---|
  | Net balance > 0 paise | "Overall, you are owed" | `success` (`#2A9D8F`) | `success` at 12% opacity |
  | Net balance < 0 paise | "Overall, you owe" | `danger` (`#E76F51`) | `danger` at 12% opacity |
  | Net balance = 0 paise | "You're all settled up -- high five!" | `onSurface` (muted) | `onSurface` at 8% opacity |

  Amount is rendered via `OBTRupeeText` with Indian numbering format (SRS section 5.9, FR-EX-09).

  > **Implementation note (accepted, Bucket-C).** The shipped `NetBalanceHeaderCard` renders these tints via semantic `ColorScheme` roles -- `tertiaryContainer` (owed), `errorContainer` (owe), `surfaceContainerHighest` (settled) -- instead of the literal hex above, a deliberate dark-mode-correct choice; the header copy is unchanged (`net_balance_header_card.dart:47,53,59`).

- **Top Balances Section:**
  - Section header: "Top Balances".
  - Up to 5 items (`OBTFriendListTile` or `OBTGroupListTile`), sorted by absolute balance descending (FR-HD-02).
  - Each tile includes a trailing `OBTBalancePill` and a compact "Settle Up" text button.
  - "Settle Up" button colour: `primary` (`#1F4E79`). Minimum tap target: 48x48 dp (SRS section 5.6).
  - Tapping "Settle Up" opens the Settle Up flow pre-filled with the friend/group context (FR-SE-05).
  - Tapping the tile itself navigates to the Friend Detail or Group Detail screen.

- **Category Breakdown Section (P1 -- FR-HD-03):**
  - Section header: "This Month" (`titleMedium`, `textPrimary`, `header` semantics).
  - **Breakdown card** (`surface`, `radiusXL` / 24 dp corner, `elevationLow`, 16 dp internal padding) presenting the signed-in user's **own** current-month spend (their `sharePaise`, summed per `ExpenseCategory`, current calendar month in IST per SRS section 5.9 -- never the full `amountPaise`) as a **donut chart + legend + month total**. The card is **non-interactive** in v1.0 (no per-segment drill-down -- see Edge Case 5).
  - **Placement.** The card occupies the "This Month" slot in the Populated State, implemented as `SpendingBreakdownCard` (donut + legend + empty/error sub-states, FR-HD-03; `home_dashboard_screen.dart:388`). Surfacing the breakdown inside the dashboard's settled/empty state is a tracked follow-up (FR-HD-03 story, Follow-up Issues) and is out of scope here.
  - **Donut chart** (the recommended chart type over a horizontal bar -- a donut reads the part-to-whole month total at a glance and frees its centre for the total figure):
    - One segment per `ExpenseCategory` with non-zero current-month spend, **ordered by descending paise** (AC-10). A single-category month renders one full-circle segment at 100% (AC-11). `ExpenseCategory.other`, when it carries spend, is an ordinary segment ranked by its own paise -- never a synthetic tail bucket and never a "+N more" truncation (AC-12).
    - Geometry: outer diameter **160 dp** (matches the loading chart-skeleton, State 1, line 69); ring thickness **28 dp**; centre hole diameter **~104 dp** (in fl_chart terms: `centerSpaceRadius` ~= 52 dp, section `radius` ~= 28 dp). Segments are separated by a **2 dp gap rendered in the card `surface` colour** so each arc is visually bounded.
    - Segment fill = the category's colour token from the **Expense Category Palette** (`docs/design/02-design-system/tokens.md` section 1.3), brightness-keyed (light map on `#FFFFFF`, dark map on `#1E1E1E`). Every token meets WCAG 2.1 AA >=3:1 against the card surface in both themes (tokens.md section 1.3.3).
    - Segment sweep angle = the **exact integer-paise ratio** `categoryPaise / monthTotalPaise` (Invariant 1: a derived ratio, never a `double` money value). No percentage labels are painted on the arcs (percentages live in the legend and the semantics).
    - **Centre label:** the **month total** rendered once via `formatInrFromPaise` (`headlineSmall` / `titleLarge`, `textPrimary`), with a `labelSmall` `textSecondary` caption "spent" beneath. The total equals the sum of all segment subtotals.
  - **Legend** (beneath the donut; a single vertical column, one row per non-zero category, same descending-paise order):
    - Row layout (leading -> trailing): a **14 dp rounded colour swatch** (radius 4 dp) filled with the category colour token (the colour key); the category icon (`expenseCategoryIcon`, `iconSmall` 20 dp, tinted `onSurface` for guaranteed legibility -- a redundant non-colour signal); the category label (`expenseCategoryLabel`, `bodyMedium`, `textPrimary`); a spacer; the category subtotal via `formatInrFromPaise` (`bodyMedium`, `textPrimary`); and the percentage (`labelSmall`, `textSecondary`).
    - Percentage = integer-rounded `categoryPaise * 100 / monthTotalPaise`, displayed as "N%". Rounding is for readability only; the donut sweep uses the exact ratio, so rounded legend percentages may not sum to exactly 100% (acceptable). All values derive from integer paise (Invariant 1).
    - Responsive 1..8 rows: the legend is a single vertical column at any count; the card grows vertically within the scrollable dashboard (no truncation, no "+N more", no horizontal scroll). Under dynamic font scaling to 200%, rows wrap/grow and the card height expands; the donut holds 160 dp (min 120 dp if space-constrained) with no clipping (SRS section 5.6).
  - **Empty / zero-spend sub-state** (no qualifying current-month spend -- `monthTotalPaise == 0`): the card shows **no chart and no legend** (AC-7). Instead, centred: a decorative leading icon (`pie_chart` / `insights`, `iconLarge`, `secondary` tint, `excludeSemantics: true`); primary copy **"No spending yet this month"** (`titleSmall`, `textPrimary`); subline **"Add an expense to see your monthly breakdown"** (`bodyMedium`, `textSecondary`). Same card frame (`surface`, 24 dp corner, `elevationLow`). Microcopy per SRS section 6.5 (encouraging, not a dead end).
  - **Loading sub-state:** reuses the dashboard skeleton discipline -- the `chart`-type `OBTSkeletonLoader` already specified for the Default / Loading State (State 1, line 69: 160x160 dp circle + three 12 dp bar lines). `reduceMotion` swaps shimmer for a static grey placeholder. `home_spending_breakdown_viewed` is **not** emitted whilst loading (AC-8 / AC-15).
  - **Error sub-state:** if the cross-friendship expense read fails, the card shows the FR-HD-01/02 / FR-PR-05 treatment: a short message "We couldn't load your spending breakdown.", a **Retry** affordance (re-invokes the read), a **Contact Support** link wired to the FR-PR-05 `ContactSupportController` (`mailto:` flow with the copy-address fallback dialogue), and the muted support-triage code **`HD-FIRESTORE-READ`** -- identical to the dashboard Error State (State 4). `home_spending_breakdown_viewed` does **not** fire on the error sub-state (AC-17).

#### 4. Error State

Displayed when the Firestore read for balances or friends/groups data fails.

- `OBTErrorState` with:
  - Illustration: `error_cloud.svg` (decorative, `excludeSemantics: true`).
  - Title: "Something went wrong" (bold, heading semantics).
  - Subtitle: "We could not load your balances. Please check your connection and try again."
  - Retry button: primary filled button. On press, shows a loading indicator and re-invokes the Firestore read.
  - Contact Support link: text link in `primary` colour. Opens the device mail client pre-filled per FR-SH-03, or falls back to a copy-address dialogue per FR-SH-04.
  - Error code: `"HD-FIRESTORE-READ"` (small, muted, for support triage).
- On second retry failure, subtitle updates to: "Still not working. Try again or contact support." (Component 19 spec).
- The FAB remains visible and active. The user may still add an expense (it will be queued if offline, per FR-OF-02).

#### 5. Offline State

Displayed when the device has no network connectivity but cached data is available (FR-OF-01).

- **Offline banner:** Non-dismissible banner pinned below the app bar, full width, `secondary` (`#F4A261`) at 15% opacity background, 40 dp height. Text: "Offline -- data may be outdated" in `secondary` text colour.
- Balance header and top-balances list render from Firestore offline cache, with the same layout as the Populated State.
- "Settle Up" buttons remain active; tapping queues the settlement write (FR-OF-02).
- FAB remains active. Adding an expense queues the write locally; an `OBTSnackbar` (type: `success`) confirms: "Expense saved offline. It will sync when you're back online."
- When connectivity returns, the offline banner slides out (200 ms ease-in-out) and data refreshes from Firestore. Queued writes sync automatically; the `recomputeSimplifiedBalances` Cloud Function runs on sync (Invariant 2). If a queued write conflicts, the user is notified via `OBTSnackbar` (type: `info`) per FR-OF-03.

### Inputs and Validation

The Home Dashboard has no direct user inputs (no text fields, pickers, or forms). All interactions are navigational (taps on tiles, buttons, tabs, FAB). No input validation or error messages apply to this screen.

### Telemetry Events

All events conform to SRS section 5.10 (Firebase Analytics).

| Event Name | Trigger | Parameters |
|---|---|---|
| `home_viewed` | Screen becomes visible (including tab switches back to Home) | `net_balance_state`: `"positive"` / `"negative"` / `"zero"` / `"loading"` / `"error"` |
| `home_settle_up_tapped` | User taps "Settle Up" on a top-balances tile | `context_type`: `"friend"` / `"group"`, `context_id`: friendship or group ID, `amount_paise`: balance amount |
| `home_tile_tapped` | User taps a friend or group tile (not the Settle Up button) | `context_type`: `"friend"` / `"group"`, `context_id`: friendship or group ID |
| `home_empty_cta_tapped` | User taps "Add Expense" CTA in the empty state | -- |
| `home_error_retry_tapped` | User taps "Retry" in the error state | `attempt_number`: integer |
| `home_error_support_tapped` | User taps "Contact Support" in the error state | `error_code`: `"HD-FIRESTORE-READ"` |
| `home_spending_breakdown_viewed` | First terminal (non-loading) render of the breakdown card per dashboard mount -- fires in the populated and empty sub-states, never on loading or error | `category_count`: integer (number of non-zero categories rendered; `0` in the empty sub-state; range 0--8). Carries no `uid`, no `friendshipId`, and no rupee/paise value (SRS section 5.4 / line 308) |
| `expense_save_succeeded` | (Logged by the Add Expense flow, not the dashboard itself) | Per SRS section 5.10 |

### Accessibility

#### Semantic Labels for Interactive Elements

| Element | Semantic Label | Role |
|---|---|---|
| App bar title | "Home" | `header` (`Semantics(header: true)`) |
| Net balance header (positive) | "Overall balance: you are owed rupees [amount]" | -- (informational) |
| Net balance header (negative) | "Overall balance: you owe rupees [amount]" | -- (informational) |
| Net balance header (zero) | "Overall balance: all settled up" | -- (informational) |
| Friend list tile | "[Display name], [balance pill text]" | `button` |
| Group list tile | "[Group name], [group type], [member count] members, [balance pill text]" | `button` |
| "Settle Up" text button | "Settle up with [name], rupees [amount]" | `button` |
| Category breakdown -- section header | "This Month" | `header` |
| Category breakdown -- donut summary (the chart's accessible alternative) | "This month you have spent [amount via `formatInrFromPaise`] across [N] categories" (e.g. "This month you have spent ₹1,000.00 across 2 categories"; use the singular "category" when N = 1) | -- (informational) |
| Category breakdown -- donut arcs | (excluded from semantics; the painted chart is decorative -- all information is carried by the donut summary + legend) | -- |
| Category breakdown -- legend row (per non-zero category) | "[Category label], [amount via `formatInrFromPaise`], [N] per cent" (e.g. "Food, ₹700.00, 70 per cent") -- never conveyed by colour alone | -- (informational) |
| Category breakdown -- empty sub-state | "No spending yet this month. Add an expense to see your monthly breakdown." | -- (informational) |
| Category breakdown -- error sub-state | Reuses the Error-state rows below (title / Retry / Contact support / "Error code: HD-FIRESTORE-READ") | -- |
| FAB | "Add new expense" | `button` |
| Bottom nav tab (Home) | "Home, tab, selected" | `tab` |
| Bottom nav tab (others) | "[Label], tab" | `tab` |
| Empty-state illustration | (excluded from semantics) | -- |
| Empty-state title | "No expenses yet" | `header` |
| Empty-state CTA | "Add Expense" | `button` |
| Error-state title | "Something went wrong" | `header` |
| Error-state Retry button | "Retry" | `button` |
| Error-state Contact Support link | "Contact support" | `button` |
| Error-state error code | "Error code: HD-FIRESTORE-READ" | -- (informational) |
| Offline banner | "Info: Offline, data may be outdated" | live region |
| Skeleton group | "Loading content" | live region |

#### Focus Order

1. App bar title (announced as heading).
2. Net balance header card (or skeleton / empty-state title / error-state title, depending on state).
3. Empty-state CTA / Error-state Retry / top-balances section header, as applicable.
4. Top-balances list tiles, in order (each tile, then its "Settle Up" button).
5. Category breakdown: section header -> donut summary -> legend rows (top to bottom) -> empty-state body or error Retry / Contact Support, when applicable. No element is a focus stop for tapping (the card is non-interactive).
6. FAB.
7. Bottom navigation tabs (left to right: Home, Friends, Groups, Activity, Profile).

#### Screen-Reader Announcements

- On state transition from loading to populated: the live region announces the net balance text.
- On state transition from loading to error: the live region announces "Something went wrong".
- On offline banner appearing: live region announces "Info: Offline, data may be outdated".
- On offline banner disappearing: live region announces "Back online".
- No information is conveyed by colour alone; textual labels "you are owed" and "you owe" provide direction alongside colour coding (SRS section 5.6).
- All text meets WCAG 2.1 AA contrast ratios (at least 4.5:1 for body text) in both light and dark mode.
- All layouts support dynamic font scaling up to 200% without clipping (SRS section 5.6).
- The category breakdown conveys no information by colour alone: every segment's category, rupee amount, and percentage are exposed in the legend and the per-segment semantic label, and the donut summary announces the month total across N categories; the painted donut arcs are excluded from semantics (SRS section 5.6).
- The 8 category-segment colours meet WCAG 2.1 AA (>=3:1 against the card surface) in both light and dark mode (tokens.md section 1.3.3). The breakdown card is non-interactive in v1.0; its legend and summary are informational, not focusable controls.

### Edge Cases

1. **User has exactly zero net balance but non-zero individual balances.** The net balance header displays "You're all settled up -- high five!" in muted `onSurface`, whilst the top-balances list still shows individual friend/group tiles with non-zero balances and "Settle Up" buttons. This is correct behaviour: the user's debts and credits cancel out overall, but individual settlements remain pending.

2. **User has more than 5 friends/groups with non-zero balances.** Only the top 5 by absolute balance are shown. There is no "View all" link on the Home Dashboard in v1.0; users navigate to the Friends or Groups tab to see the full list. The sort is deterministic: ties in absolute balance are broken by `lastActivityAt` descending, then by document ID alphabetically.

3. **Firestore cache is empty on first launch with no connectivity.** The offline state cannot render cached data because none exists. In this case, the screen displays the error state with subtitle "You appear to be offline. Connect to the internet to load your data." and a Retry button. The FAB remains active; any expense added will be queued (FR-OF-02), though the user will not see existing balances until connectivity is restored.

4. **Balance data updates in real time whilst the user is viewing the dashboard.** The Firestore snapshot listener updates the UI reactively. If a balance changes (e.g., another user adds an expense), the balance header and top-balances list animate to reflect the new values using `motionStandard` (200--300 ms ease-in-out). The top-5 sort order may change; items slide into new positions.

5. **Category breakdown card is tapped.** The breakdown card is **non-interactive** in v1.0: it has no tap handler and no pressed state, and no per-segment drill-down. Tapping anywhere on it (donut, legend, or empty / error body) performs no navigation or action. A tap-to-drill-down per-category expense list is explicitly out of scope (see the FR-HD-03 story, *Out of Scope*).

### Open Questions

1. **OQ-HD-01:** Should the Home Dashboard include a search icon in the app bar trailing actions to access SCR-07 (Search Overlay)? The site map lists search as `/search` with no defined trigger from the Home screen. The wireframes show no trailing actions on the Home app bar. Awaiting PM decision.

2. **OQ-HD-02:** When the user has zero balances but does have friends/groups (just all settled up), should the empty state or the populated state (with "You're all settled up -- high five!") be shown? Current spec shows the populated state with the settled-up message, but the empty-state illustration may be more encouraging for engagement. Awaiting PM/UX alignment.

3. **OQ-HD-03:** Should the top-balances list tiles support swipe-to-settle as a gesture shortcut, in addition to the explicit "Settle Up" button? This would improve efficiency for frequent users but adds interaction complexity. Awaiting PM prioritisation.

---

## SCR-07: Search Overlay

> **Status: deferred.** Search (SCR-07; FR-SR-01 search, FR-SR-02 filter) is **not implemented in v1.0 through Sprint 2** -- see the global status note (line 12). This section is retained as a forward-looking specification for a future release; nothing here ships in v1.0.

### Overview

| Field | Value |
|---|---|
| **Screen ID** | SCR-07 |
| **Screen Name** | Search Overlay |
| **Purpose** | Allow users to search expenses by description, amount, category, or member, and to filter results by date range, group, and category. Provides fast access to any expense without navigating through friend or group detail screens. |
| **Route** | `/search` |
| **SRS Requirements** | FR-SR-01 (search by description, amount, category, member), FR-SR-02 (filter by date range, group, category) |

### Navigation Context

| Direction | Screens |
|---|---|
| **Reachable from** | Any primary tab (trigger mechanism to be confirmed -- see OQ-HD-01; likely an app bar action icon or a dedicated search entry point), Activity Feed (contextual search) |
| **Leads to** | Expense detail (via result tap -- navigates to the expense within its friend or group context), Friend Detail (`/friends/:friendshipId`, if a search result is a friend match), Group Detail (`/groups/:groupId`, if a search result is a group match), back to the originating screen (via close/back gesture) |

### Components Used

| Component | Catalogue Reference | Usage on This Screen |
|---|---|---|
| `OBTAppBar` | Component 1 | Top bar with title "Search", back/close button enabled. |
| `OBTSearchBar` | Component 23 | Primary search input field at the top of the content area. |
| `OBTCategoryChip` | Component 12 | Horizontally scrollable category filter chips. |
| `OBTExpenseListTile` | Component 15 | Expense result rows. |
| `OBTFriendListTile` | Component 16 | Friend result rows (when searching by member). |
| `OBTGroupListTile` | Component 17 | Group result rows (when searching by group). |
| `OBTEmptyState` | Component 18 | No-results state. |
| `OBTErrorState` | Component 19 | Error state when search query fails. |
| `OBTSkeletonLoader` | Component 20 | Shimmer placeholders during search execution. |

### States

#### 1. Default State (Idle)

Displayed when the search overlay first opens, before any query is entered.

- `OBTAppBar` with title "Search" and a leading close icon (X or back arrow).
- `OBTSearchBar` with `autoFocus: true`, `hintText: "Search expenses, friends, or groups"`. Keyboard opens immediately.
- Below the search bar: a horizontal row of `OBTCategoryChip` components (all eight categories from FR-EX-08), all unselected, acting as quick-filter shortcuts.
- Below the chips: optional "Recent searches" section showing up to 5 recent query strings, each as a tappable row with a trailing clear (X) icon. If no recent searches exist, this section is omitted.
- No results area is shown until a query is entered or a filter is applied.

#### 2. Loading State

Displayed after the user enters a query (debounced by 300 ms) or selects a filter.

- The search bar retains the query text.
- The results area shows `OBTSkeletonLoader` with `type: listTile`, `itemCount: 5`.
- Shimmer animation follows the standard spec (1.5 s loop, left-to-right).

#### 3. Populated State (Results Found)

Displayed when the query or filter returns one or more matches.

- Results are grouped by type with section headers:
  - "Expenses" -- rendered as `OBTExpenseListTile` rows.
  - "Friends" -- rendered as `OBTFriendListTile` rows (shown only if query matches a member name).
  - "Groups" -- rendered as `OBTGroupListTile` rows (shown only if query matches a group name).
- Each section shows up to 10 results initially, with a "Show more" text button if additional results exist.
- Active filters are shown as selected `OBTCategoryChip` instances and/or a date-range pill below the search bar.
- Result count is displayed as muted text below the filter chips: e.g., "12 results".

#### 4. Empty State (No Results)

Displayed when a query or filter combination yields zero matches.

- `OBTEmptyState` with:
  - Illustration: `search_empty.svg` (decorative, `excludeSemantics: true`).
  - Title: "No results found".
  - Subtitle: "Try a different search term or adjust your filters."
  - No CTA button.

#### 5. Error State

Displayed when the search query fails (e.g., Firestore read error).

- `OBTErrorState` with:
  - Title: "Search failed".
  - Subtitle: "We could not complete your search. Please try again."
  - Retry button: re-executes the last query.
  - Contact Support link: opens mailto flow (FR-PR-05).
  - Error code: `"SR-QUERY-FAIL"`.

#### 6. Offline State

Displayed when the device is offline.

- Search operates against the local Firestore cache (FR-OF-01).
- An `OBTSnackbar`-style persistent banner appears below the search bar: "Offline -- searching cached data only" (`secondary` at 15% opacity).
- Results may be incomplete. The empty state subtitle adjusts to: "No results found in cached data. Connect to the internet for complete results."

### Inputs and Validation

| Input | Component | Type | Validation | Error Message |
|---|---|---|---|---|
| Search query | `OBTSearchBar` | Free text | Minimum 1 character to trigger search. Maximum 100 characters (client-side truncation, no error shown). Debounced by 300 ms after last keystroke. | No explicit error message; an empty query shows the default idle state. |
| Category filter | `OBTCategoryChip` (multiple) | Toggle selection | At least 0, at most 8 selected. No validation error possible. | -- |
| Date range filter | Date range picker (inline) | Start date and end date | Start date must not be after end date. Both dates must not be in the future. | "Start date must be before end date." / "Date cannot be in the future." |
| Group filter | Group selector (dropdown or bottom sheet) | Single or multi-select from user's groups | No validation error possible (list is populated from user's groups). | -- |

### Telemetry Events

| Event Name | Trigger | Parameters |
|---|---|---|
| `search_opened` | Search overlay becomes visible | `source`: `"home"` / `"activity"` / `"other"` |
| `search_query_submitted` | Debounce fires after user types (300 ms pause) | `query_length`: integer, `has_filters`: boolean |
| `search_filter_applied` | User selects or deselects a category chip, date range, or group filter | `filter_type`: `"category"` / `"date_range"` / `"group"`, `filter_value`: string |
| `search_result_tapped` | User taps a result row | `result_type`: `"expense"` / `"friend"` / `"group"`, `result_id`: document ID, `result_position`: integer (1-indexed) |
| `search_no_results` | Query returns zero results | `query_length`: integer, `filters_active`: integer count |
| `search_closed` | User dismisses the search overlay | `had_query`: boolean, `result_count`: integer |

### Accessibility

#### Semantic Labels for Interactive Elements

| Element | Semantic Label | Role |
|---|---|---|
| App bar close/back button | "Close search" | `button` |
| App bar title | "Search" | `header` |
| Search bar | "Search expenses, friends, or groups" | `textField` |
| Clear search button | "Clear search" | `button` |
| Category chip (unselected) | "[Category name] category, not selected" | `button` |
| Category chip (selected) | "[Category name] category, selected" | `button` |
| Date range filter | "Filter by date range, [start] to [end]" (or "Filter by date range" if unset) | `button` |
| Group filter | "Filter by group, [group name]" (or "Filter by group" if unset) | `button` |
| Result count text | "[N] results" | -- (informational) |
| Expense result row | "[Description], [category], paid by [payer], [date], your share: [you lent / you borrowed] rupees [amount]" | `button` |
| Friend result row | "[Display name], [balance pill text]" | `button` |
| Group result row | "[Group name], [group type], [member count] members, [balance pill text]" | `button` |
| "Show more" button | "Show more [type] results" | `button` |
| Recent search row | "Recent search: [query]. Tap to search again" | `button` |
| Recent search clear | "Remove [query] from recent searches" | `button` |
| Empty-state illustration | (excluded from semantics) | -- |
| Empty-state title | "No results found" | `header` |
| Offline banner | "Info: Offline, searching cached data only" | live region |

#### Focus Order

1. Close/back button in the app bar.
2. Search bar (receives focus automatically with `autoFocus: true`).
3. Category filter chips (left to right).
4. Date range filter (if visible).
5. Group filter (if visible).
6. Result count text.
7. Result rows (top to bottom, within each section).
8. "Show more" button (if visible).

#### Screen-Reader Announcements

- On opening: "Search. Edit text field focused."
- On results loading: live region announces "Loading results".
- On results loaded: live region announces "[N] results found" or "No results found".
- On filter change: announces the updated filter state (e.g., "Food category selected. Searching.").
- Query text changes are debounced for announcements to avoid excessive verbosity.

### Edge Cases

1. **User enters only whitespace.** The query is trimmed. An all-whitespace query is treated as empty and the screen returns to the default idle state. No search is executed.

2. **User types a query that matches an amount (e.g., "500").** The search matches against both description text and amount values. Amount matching converts the query to paise (50000) and searches for expenses where `totalAmountPaise` equals that value. Partial amount matches (e.g., "5" matching "500") are not supported; the match must be exact for amounts.

3. **User selects a category filter and then types a query that contradicts it (e.g., filter: Food, query: "flight tickets").** Both constraints are applied as an AND filter. The search returns only Food-category expenses whose description contains "flight tickets". This may yield zero results, which is correct. The empty-state subtitle guides the user to adjust filters.

4. **Search results update in real time whilst viewing.** If a matching expense is edited or deleted by another user, the Firestore snapshot listener updates the results list reactively. Items may appear, disappear, or change position. Removed items animate out with a 200 ms fade.

5. **Rapid successive queries (user types quickly, pauses, types again).** The 300 ms debounce ensures only the final resting query triggers a search. Any in-flight Firestore query from a previous debounce cycle is cancelled before a new one is issued, preventing stale results from overwriting current results.

### Open Questions

1. **OQ-SR-01:** What is the primary entry point for the Search Overlay? Options include: (a) a search icon in the Home app bar, (b) a search icon in all tab app bars, (c) a pull-down gesture on any list screen. The site map lists `/search` as "overlay or full-screen" but no trigger is specified in the wireframes. Awaiting PM decision.

2. **OQ-SR-02:** Should recent searches be persisted locally (surviving app restarts) or held only in memory for the current session? Local persistence improves convenience but requires local storage management. Awaiting Architect input on storage approach.

3. **OQ-SR-03:** Should amount search support range queries (e.g., "500-1000") or only exact matches? FR-SR-01 says "search by amount" without specifying match type. Awaiting PM clarification.

4. **OQ-SR-04:** How should the date range filter be presented? Options include: (a) a pre-set list (Today, This Week, This Month, Custom), (b) a calendar-based range picker. The SRS does not specify a preferred pattern. Awaiting design decision.

---

## SCR-08: Add Expense Entry Point

### Overview

| Field | Value |
|---|---|
| **Screen ID** | SCR-08 |
| **Screen Name** | Add Expense Entry Point (FAB Action) |
| **Purpose** | Provide the universal entry point for creating a new expense from any primary tab. The FAB tap opens a multi-step bottom sheet that captures expense details (amount, description, date, category, payer, split method, optional notes). This specification covers the FAB interaction, the context-selection step (friend or group), and the transition into the Add Expense flow. |
| **Route** | No dedicated route. The FAB is rendered by the authenticated shell. The Add Expense flow is a modal bottom sheet overlay (SRS section 6.3, Core Screen 8; site map section 2.4). |
| **SRS Requirements** | FR-HD-04 (persistent FAB on any primary tab), FR-EX-01 (expense fields: amount, description, date, category, payer, split method, optional notes) |

### Navigation Context

| Direction | Screens |
|---|---|
| **Reachable from** | Any primary tab (Home, Friends, Groups, Activity, Profile) via the persistent `OBTFloatingActionButton`. Also reachable from the empty-state CTA on the Home Dashboard (SCR-06). |
| **Leads to** | Add Expense bottom sheet (multi-step flow: Step 1 context selection, Step 2 amount and description, Step 3 split method, Step 4 review and save). On completion, returns to the originating screen with an `OBTSnackbar` confirmation. On cancellation, returns to the originating screen with no changes. |

### Components Used

| Component | Catalogue Reference | Usage on This Screen |
|---|---|---|
| `OBTFloatingActionButton` | Component 3 | The trigger element; persistent across all tabs. |
| `OBTAppBar` | Component 1 | Bottom sheet header with title "Add Expense" and a close (X) icon. |
| `OBTSearchBar` | Component 23 | Friend/group search within the context-selection step. |
| `OBTFriendListTile` | Component 16 | Friend rows in the context-selection list. |
| `OBTGroupListTile` | Component 17 | Group rows in the context-selection list. |
| `OBTAmountInput` | Component 6 | Amount entry field (Step 2). |
| `OBTCategoryChip` | Component 12 | Category selection (Step 2 or Step 3, depending on flow). |
| `OBTSplitMethodSelector` | Component 21 | Split method selection (Step 3). |
| `OBTSnackbar` | Component 25 | Confirmation feedback on save. |
| `OBTConfirmationDialog` | Component 24 | Discard confirmation if user has unsaved input. |
| `OBTEmptyState` | Component 18 | Empty state if user has no friends or groups. |
| `OBTSkeletonLoader` | Component 20 | Loading state for friend/group list. |

### States

#### 1. Default State (FAB Resting)

- The FAB is visible on every primary tab, floating above the bottom navigation bar without overlapping any tab target.
- FAB appearance: `secondary` (`#F4A261`) background, white `+` icon, 56x56 dp, `elevationMedium` (4 dp shadow).
- The FAB does not change appearance based on tab or screen state (it is always active).

#### 2. FAB Pressed State

- Spring-physics scale-down to 0.92x on press, elevation increases.
- 200 ms spring release on lift (SRS section 6.2, `motionSpring`).
- On release, the Add Expense bottom sheet slides up from the bottom (200--300 ms ease-in-out, SRS section 6.2, `motionStandard`).

#### 3. Context Selection Step (Bottom Sheet Step 1)

- Bottom sheet with 24 dp top corner radius, drag handle at top, surface background.
- Header: "Add Expense" title with a close (X) icon.
- Two-tab segmented control: "Friend" | "Group".
- Below the tabs: `OBTSearchBar` with `hintText: "Search friends or groups"`.
- Below the search bar: scrollable list of friends (`OBTFriendListTile`) or groups (`OBTGroupListTile`), depending on the active tab.
- Tapping a friend or group selects it and advances to Step 2.

##### Context Selection Sub-States

| Sub-State | Behaviour |
|---|---|
| Loading | `OBTSkeletonLoader` with `type: listTile`, `itemCount: 5` whilst friends/groups load. |
| Populated | Scrollable list of friends or groups. |
| Empty (no friends) | `OBTEmptyState` with title: "No friends yet", subtitle: "Add a friend first to split an expense.", CTA: "Add Friend" (navigates to `/friends/add`). |
| Empty (no groups) | `OBTEmptyState` with title: "No groups yet", subtitle: "Create a group to split expenses with multiple people.", CTA: "Create Group" (navigates to `/groups/create`). |
| Search active | Filtered list updates in real time. No matches shows inline "No matches found". |

#### 4. Loading State (Saving Expense)

- After the user taps "Save" on the final review step, the save button shows a loading indicator.
- The bottom sheet is non-dismissible during save.
- All form fields are disabled.

#### 5. Error State (Save Failed)

- If the Firestore write fails, an `OBTSnackbar` (type: `error`) appears: "Could not save expense. Please try again."
- The bottom sheet remains open with all data preserved.
- The save button returns to its default state, allowing retry.

#### 6. Offline State

- The FAB remains active when offline (FR-OF-02).
- When the user saves an expense offline, the write is queued locally.
- An `OBTSnackbar` (type: `success`) confirms: "Expense saved offline. It will sync when you're back online."
- The bottom sheet dismisses normally.
- The `recomputeSimplifiedBalances` Cloud Function will run when the write syncs (Invariant 2).

### Inputs and Validation

All inputs below refer to the full Add Expense multi-step flow triggered by the FAB.

| Input | Component | Type | Validation Rule | Error Message |
|---|---|---|---|---|
| Context (friend/group) | `OBTFriendListTile` / `OBTGroupListTile` | Selection | Required. User must select exactly one friend or group. | "Please select a friend or group to split with." (shown if user attempts to proceed without selection) |
| Amount | `OBTAmountInput` | Numeric (paise) | Required. Must be greater than 0 paise. Maximum: 99,99,999.99 rupees (9,99,99,99,999 paise). | "Please enter an amount." (if empty) / "Amount must be greater than zero." (if 0) / "Amount cannot exceed 99,99,999.99 rupees." (if over maximum) |
| Description | Text field | Free text | Required. Minimum 1 character. Maximum 100 characters. | "Please add a description." (if empty) / "Description cannot exceed 100 characters." (if over maximum; shown with a character counter) |
| Date | Date picker | Date | Required. Defaults to today. Must not be in the future. Must not be more than 1 year in the past. | "Date cannot be in the future." / "Date cannot be more than a year ago." |
| Category | `OBTCategoryChip` | Single selection | Required. Defaults to "Other" if not selected. | No error message; "Other" is auto-selected as fallback. |
| Payer | Payer selector | Single selection | Required. Defaults to the current user ("You paid"). | No error message; defaults to current user. |
| Split method | `OBTSplitMethodSelector` | Single selection | Required. Defaults to "Equal". | No error message; defaults to "Equal". |
| Split amounts | `OBTSplitEntryRow` (per participant) | Numeric (paise) | Splits must sum exactly to the expense total (FR-EX-04). | "Splits do not add up. [Remaining amount] left to assign." / "Splits exceed the total by [excess amount]." |
| Notes | Text field | Free text | Optional. Maximum 500 characters. | "Notes cannot exceed 500 characters." (shown with character counter) |

### Telemetry Events

| Event Name | Trigger | Parameters |
|---|---|---|
| `fab_tapped` | User taps the FAB | `source_tab`: `"home"` / `"friends"` / `"groups"` / `"activity"` / `"profile"` |
| `expense_context_selected` | User selects a friend or group in Step 1 | `context_type`: `"friend"` / `"group"`, `context_id`: document ID |
| `expense_split_method_selected` | User selects a split method in Step 3 | `method`: `"equal"` / `"unequal"` / `"percentage"` / `"shares"` / `"exact"` |
| `expense_save_succeeded` | Expense is successfully saved (SRS section 5.10) | `amount_paise`: integer, `category`: string, `split_method`: string, `participant_count`: integer, `has_notes`: boolean, `has_receipt`: boolean, `is_offline`: boolean |
| `expense_add_cancelled` | User dismisses the bottom sheet without saving | `step_reached`: `"context"` / `"amount"` / `"split"` / `"review"`, `had_data_entered`: boolean |
| `expense_save_failed` | Save attempt fails | `error_type`: string, `is_offline`: boolean |

### Accessibility

#### Semantic Labels for Interactive Elements

| Element | Semantic Label | Role |
|---|---|---|
| FAB | "Add new expense" | `button` |
| Bottom sheet drag handle | "Drag to resize" | -- (decorative, included for assistive tech) |
| Close (X) icon | "Close, discard expense" | `button` |
| "Friend" tab | "Split with a friend, tab" | `tab` |
| "Group" tab | "Split with a group, tab" | `tab` |
| Search bar (context step) | "Search friends or groups" | `textField` |
| Friend list tile | "[Display name]" | `button` |
| Group list tile | "[Group name], [member count] members" | `button` |
| Amount input | "Enter amount in rupees" | `textField` |
| Description input | "Expense description" | `textField` |
| Date picker | "Expense date, [selected date]" | `button` |
| Category chip | "[Category name] category, [selected/not selected]" | `button` |
| Payer selector | "Paid by [name]" | `button` |
| Split method chip | "[Method name], [selected/not selected]" | `button` |
| Split entry row | "[Participant name], share: rupees [amount]" | `textField` |
| Notes input | "Optional notes" | `textField` |
| "Save" button | "Save expense, rupees [amount]" | `button` |
| "Back" button (between steps) | "Go back to previous step" | `button` |
| Empty-state CTA (no friends) | "Add Friend" | `button` |
| Empty-state CTA (no groups) | "Create Group" | `button` |

#### Focus Order

1. Bottom sheet drag handle (non-focusable for most users, but announced).
2. Close (X) icon.
3. Step title / header.
4. Tab control ("Friend" / "Group") in Step 1.
5. Search bar in Step 1.
6. List items (friend/group tiles) in Step 1.
7. Amount input in Step 2.
8. Description input in Step 2.
9. Date picker in Step 2.
10. Category chips in Step 2.
11. Payer selector in Step 2/3.
12. Split method selector in Step 3.
13. Split entry rows in Step 3.
14. Notes input in Step 3/4.
15. "Save" button in Step 4.

#### Screen-Reader Announcements

- On FAB press: "Add new expense. Bottom sheet opened."
- On step transition: "Step [N] of 4: [step title]."
- On validation error: the error message is announced immediately after the field label.
- On split validation failure: "Splits do not add up. [Remaining/excess] rupees [amount]."
- On successful save: "Success: Expense added."
- On save failure: "Error: Could not save expense. Please try again."
- On offline save: "Success: Expense saved offline. It will sync when you're back online."
- On discard confirmation: "Alert: Discard expense? You have unsaved changes."
- Focus is trapped within the bottom sheet whilst it is open (SRS section 5.6, modal behaviour).

### Edge Cases

1. **User taps FAB, enters data in Step 2, then swipes down to dismiss the bottom sheet.** If any field has been modified (amount entered, description typed, etc.), an `OBTConfirmationDialog` appears: title "Discard expense?", body "You have unsaved changes. Are you sure you want to discard this expense?", cancel label "Keep editing", confirm label "Discard" (destructive). If no data has been entered, the sheet dismisses without confirmation.

2. **User taps FAB whilst offline and has no cached friends/groups data.** The context-selection step shows the empty state with an explanation: "You appear to be offline. Add a friend or group when you're back online." The CTA buttons ("Add Friend" / "Create Group") are disabled with muted styling, as those flows require connectivity.

3. **User selects "Unequal" split, enters amounts for some participants but not all, then taps "Save".** Validation fires: the split sum does not equal the expense total. The error message "Splits do not add up. [Remaining amount] left to assign." appears inline below the split entry area. The "Save" button remains disabled until the split sums correctly (FR-EX-04). Participants with no amount entered are treated as 0 paise.

4. **User is in the middle of adding an expense and receives a phone call or the app is backgrounded.** The bottom sheet state (all entered data, current step) must be preserved in memory. When the user returns to the app, the bottom sheet is still visible with all data intact. If the app is killed by the OS, the data is lost and the user must start again (no draft persistence in v1.0).

5. **User selects a group context, and whilst filling in expense details, another user removes them from that group.** On save, the Firestore security rules reject the write. The error state shows: "Could not save expense. You may no longer be a member of this group." The bottom sheet remains open so the user can change the context.

### Open Questions

1. **OQ-EX-01:** Should the Add Expense flow support draft persistence (saving partial data locally if the app is killed)? This is not in the SRS for v1.0 but would improve UX for interrupted flows. Awaiting PM prioritisation.

2. **OQ-EX-02:** Should the context-selection step be skipped if the user triggers the FAB from a Friend Detail or Group Detail screen, with the context pre-filled? The site map shows the FAB as a global element, but contextual pre-filling would save a tap. Awaiting PM/Architect alignment.

3. **OQ-EX-03:** Should the bottom sheet support a "full-screen" expanded mode for complex split entry (e.g., unequal splits across many group members)? The 24 dp corner-radius bottom sheet may become cramped with more than 6 participants. Awaiting design validation with real data.

---

## Cross-Screen Traceability

| SRS Requirement | SCR-06 | SCR-07 | SCR-08 |
|---|---|---|---|
| FR-HD-01 (net balance as primary visual) | Primary | -- | -- |
| FR-HD-02 (top 5 with quick settle) | Primary | -- | -- |
| FR-HD-03 (category breakdown, P1) | Primary | -- | -- |
| FR-HD-04 (persistent FAB) | Primary | -- | Primary |
| FR-SR-01 (search by description, amount, category, member) | -- | Primary | -- |
| FR-SR-02 (filter by date range, group, category) | -- | Primary | -- |
| FR-EX-01 (expense fields) | -- | -- | Primary |
| FR-SE-05 (pre-filled settle up) | Secondary (triggers) | -- | -- |
| FR-SE-07 (settle CTA on non-zero balance screens) | Secondary | -- | -- |
| FR-OF-01 (view cached data offline) | Secondary | Secondary | -- |
| FR-OF-02 (add expense offline) | Secondary | -- | Secondary |
| Section 5.6 (accessibility) | Cross-cutting | Cross-cutting | Cross-cutting |
| Section 5.10 (observability) | Cross-cutting | Cross-cutting | Cross-cutting |
| Section 6.2 (visual system) | Cross-cutting | Cross-cutting | Cross-cutting |
| Section 6.4 (empty/error/loading states) | Cross-cutting | Cross-cutting | Cross-cutting |
| Section 6.5 (microcopy tone) | Cross-cutting | Cross-cutting | Cross-cutting |

---

## Invariant Compliance Checklist

| Invariant | Compliance |
|---|---|
| **1. Money is integer paise.** | All balance values displayed on SCR-06 and all amount inputs on SCR-08 use integer paise internally. Conversion to rupees with Indian numbering formatting occurs exclusively at the UI layer via `OBTRupeeText` and `OBTAmountInput`. Amount search on SCR-07 converts the user's rupee input to paise before querying. |
| **2. `simplifiedBalances` is server-maintained and client-read-only.** | SCR-06 reads `simplifiedBalances` for display only. No client write to this field occurs from any of these three screens. The settle-up and expense flows trigger Cloud Functions that recompute balances server-side. |
| **3. System share sheet only.** | None of these three screens invoke sharing. Any future sharing from these screens (e.g., sharing a balance summary) must use the platform system share sheet. |
| **4. Single Firebase project.** | All Firestore reads (SCR-06, SCR-07) and writes (SCR-08) target the single production Firebase project. Testing uses the Firebase Emulator Suite. |