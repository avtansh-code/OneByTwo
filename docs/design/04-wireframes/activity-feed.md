# Activity Feed Wireframes

> Screen-level wireframes, states, component mapping, and accessibility
> specifications for the Activity Feed tab (Core Screen 10).

| Field            | Value                                       |
|------------------|---------------------------------------------|
| Document version | 1.0                                         |
| Status           | Draft -- pending PM and Flutter Dev review   |
| Author           | UX/UI Designer Agent                        |
| SRS baseline     | v1.1                                        |
| Last updated     | 2025-07-15                                  |

> **Status: implemented** (`activity_feed_screen.dart` + `OBTActivityRow`). States match code: 5-row `ActivityFeedSkeleton` loading, 'All quiet here' empty, 'Something went wrong' + Retry error, pull-to-refresh.

---

## SRS Traceability

This document satisfies or directly references the following SRS requirements:

| SRS Reference | Description |
|---|---|
| FR-AC-01 | Activity tab showing a chronological feed of all events involving the user. |
| FR-AC-02 | Tapping an activity item deep-links to the relevant expense, friend, or group screen. |
| FR-AC-03 | Push notifications via FCM for new expense, edit/delete, settlement, and reminders. |
| FR-AC-04 | Notifications respect per-category user preferences. |
| FR-AC-05 | Tapping a notification deep-links to the relevant screen, including from cold start. |
| Section 5.6 | Usability and accessibility (tap targets, contrast, dynamic font scaling, dark mode, screen-reader compatibility). |
| Section 6.2 | Visual system tokens (colour, typography, corner radius, elevation, motion). |
| Section 6.3, Screen 10 | Activity feed as a core screen. |
| Section 6.4 | Explicit empty, loading, and error states with actionable copy and Retry affordance. |
| Section 6.5 | Microcopy tone: friendly, concise, lightly playful. |

---

## 1. Activity Feed -- Default (Populated) State

### 1.1 ASCII Layout

```
+---------------------------------------------------+
| OBTAppBar                                         |
|  "Activity"                          (no actions) |
+---------------------------------------------------+
|                                                   |
|  Pull-to-refresh indicator (hidden until pulled)  |
|                                                   |
|  +-----------------------------------------------+
|  | [icon]  Priya added "Dinner at Dosa Plaza"     |
|  |         in Flat Expenses                       |
|  |         Just now                      +Rs 250  |
|  +-----------------------------------------------+
|  | [icon]  You settled up with Rahul              |
|  |         2 min ago                     Rs 1,200 |
|  +-----------------------------------------------+
|  | [icon]  Amit edited "Groceries"                |
|  |         in Weekend Trip                        |
|  |         15 min ago                    Rs 430   |
|  +-----------------------------------------------+
|  | [icon]  You deleted "Auto fare"                |
|  |         1 hour ago                    Rs 85    |
|  +-----------------------------------------------+
|  | [icon]  Neha was added to "Goa Trip"           |
|  |         Yesterday                              |
|  +-----------------------------------------------+
|  | [icon]  Priya added you as a friend            |
|  |         2 days ago                             |
|  +-----------------------------------------------+
|  |            ... scrollable list ...             |
|  +-----------------------------------------------+
|                                                   |
+---------------------------------------------------+
| OBTBottomNav  [Home] [Friends] [Groups]           |
|               [Activity*] [Profile]               |
+---------------------------------------------------+
|         OBTFloatingActionButton (+)               |
+---------------------------------------------------+
```

### 1.2 Layout Specification

| Region | Component | Notes |
|---|---|---|
| Top bar | `OBTAppBar` | Title: `"Activity"`. `showBackButton: false` (tab root). No trailing actions. Elevation 0.5. |
| Feed list | `ListView` of `OBTActivityRow` widgets | Reverse-chronological order. Each row is tappable (FR-AC-02). |
| Pull-to-refresh | Platform-native `RefreshIndicator` | Triggers a re-fetch of activity data. Indicator colour: `primary`. |
| Bottom navigation | `OBTBottomNav` | `currentIndex: 3` (Activity tab selected). |
| FAB | `OBTFloatingActionButton` | Persistent across all primary tabs (FR-HD-04). |

### 1.3 OBTActivityRow -- Event Type Mapping

Each row uses the `OBTActivityRow` component as defined in the component catalogue (section 14). The icon and colour are determined by event type:

| Event Type | Icon | Colour | Example `primaryText` | Trailing Amount |
|---|---|---|---|---|
| `expenseAdded` | `receipt_long` | `primary` (`#1F4E79`) | `"Priya added 'Dinner at Dosa Plaza'"` | User's share in paise |
| `expenseEdited` | `edit` | `secondary` (`#F4A261`) | `"Amit edited 'Groceries'"` | Updated amount |
| `expenseDeleted` | `delete` | `danger` (`#E76F51`) | `"You deleted 'Auto fare'"` | Deleted amount |
| `settlementRecorded` | `check_circle` | `success` (`#2A9D8F`) | `"You settled up with Rahul"` | Settlement amount |
| `groupCreated` | `group_add` | `primary` | `"You created 'Goa Trip'"` | None |
| `groupMemberAdded` | `person_add` | `primary` | `"Neha was added to 'Goa Trip'"` | None |
| `groupMemberRemoved` | `person_remove` | `danger` | `"Ravi was removed from 'Flat Expenses'"` | None |
| `friendAdded` | `person_add` | `success` | `"Priya added you as a friend"` | None |

### 1.4 Relative Timestamp Format

Timestamps are displayed as relative strings in the `secondaryText` property. The following tiers apply:

| Elapsed Time | Display |
|---|---|
| < 1 minute | `"Just now"` |
| 1--59 minutes | `"X min ago"` |
| 1--23 hours | `"X hours ago"` (or `"1 hour ago"`) |
| 1 day | `"Yesterday"` |
| 2--6 days | `"X days ago"` |
| 7+ days | `"dd MMM"` (e.g., `"14 Mar"`) |
| Previous year | `"dd MMM yyyy"` (e.g., `"28 Dec 2024"`) |

All timestamps are rendered in IST (`Asia/Kolkata`) as required by SRS section 5.9.

### 1.5 Context Line

When an event occurs within a group context, the group name is appended to the primary text or shown as a secondary context label beneath it (e.g., `"in Flat Expenses"`). For friend-only events, the friend's name serves as context. This gives the user immediate orientation without needing to tap through (supports FR-AC-02 discoverability).

### 1.6 Deep-Link Behaviour (FR-AC-02)

| Event Type | Deep-Link Target |
|---|---|
| `expenseAdded` | Expense detail screen |
| `expenseEdited` | Expense detail screen |
| `expenseDeleted` | Group detail or Friend detail (expense no longer exists) |
| `settlementRecorded` | Friend detail screen (settlement tab/section) |
| `groupCreated` | Group detail screen |
| `groupMemberAdded` | Group detail screen |
| `groupMemberRemoved` | Group detail screen |
| `friendAdded` | Friend detail screen |

If the target entity has been deleted (e.g., a deleted expense), the app should display an `OBTSnackbar` with the message `"This item is no longer available."` and remain on the Activity feed.

### 1.7 Pull-to-Refresh Behaviour

- Pulling down beyond 64 dp reveals the `RefreshIndicator`.
- On release, the activity feed data is re-fetched from Firestore.
- The indicator dismisses with a 200 ms fade-out once the data arrives.
- If the refresh fails, an `OBTSnackbar` appears: `"Could not refresh. Check your connection and try again."`.

---

## 2. Empty State -- New User with No Activity

### 2.1 ASCII Layout

```
+---------------------------------------------------+
| OBTAppBar                                         |
|  "Activity"                          (no actions) |
+---------------------------------------------------+
|                                                   |
|                                                   |
|                                                   |
|              [Illustration SVG]                   |
|             (decorative graphic)                  |
|                                                   |
|              "All quiet here"                     |
|                                                   |
|       "Your activity will show up as you          |
|        add expenses and settle up."               |
|                                                   |
|           [ + Add Expense ]                       |
|                                                   |
|                                                   |
|                                                   |
+---------------------------------------------------+
| OBTBottomNav  [Home] [Friends] [Groups]           |
|               [Activity*] [Profile]               |
+---------------------------------------------------+
|         OBTFloatingActionButton (+)               |
+---------------------------------------------------+
```

### 2.2 Component Specification

| Element | Component | Value |
|---|---|---|
| Illustration | `OBTEmptyState.illustration` | SVG asset: `activity_empty` (decorative; excluded from semantics). |
| Title | `OBTEmptyState.title` | `"All quiet here"` |
| Subtitle | `OBTEmptyState.subtitle` | `"Your activity will show up as you add expenses and settle up."` |
| CTA button | `OBTEmptyState.ctaLabel` | `"Add Expense"` |
| CTA action | `OBTEmptyState.onCtaTap` | Opens the Add Expense flow (same as FAB). |

**Microcopy rationale (SRS section 6.5):** The title `"All quiet here"` is friendly and lightly playful without being patronising. The subtitle provides clear guidance on what action will populate the feed. The CTA duplicates the FAB affordance for users who may not notice the floating button.

### 2.3 Layout Notes

- The `OBTEmptyState` is vertically centred within the scrollable area.
- The illustration is sized at 160x160 dp.
- 16 dp spacing between illustration and title; 8 dp between title and subtitle; 24 dp between subtitle and CTA button.
- The CTA button uses `primary` colour, `cornerRadiusSmall` (16 dp), and meets the minimum 48x48 dp tap target (SRS section 5.6).

---

## 3. Loading State -- Skeleton Placeholders

### 3.1 ASCII Layout

```
+---------------------------------------------------+
| OBTAppBar                                         |
|  "Activity"                          (no actions) |
+---------------------------------------------------+
|                                                   |
|  +-----------------------------------------------+
|  | [O]  ============================   ========  |
|  |      ==================                       |
|  +-----------------------------------------------+
|  | [O]  ============================   ========  |
|  |      ==================                       |
|  +-----------------------------------------------+
|  | [O]  ============================   ========  |
|  |      ==================                       |
|  +-----------------------------------------------+
|  | [O]  ============================   ========  |
|  |      ==================                       |
|  +-----------------------------------------------+
|  | [O]  ============================   ========  |
|  |      ==================                       |
|  +-----------------------------------------------+
|                                                   |
+---------------------------------------------------+
| OBTBottomNav  [Home] [Friends] [Groups]           |
|               [Activity*] [Profile]               |
+---------------------------------------------------+
|         OBTFloatingActionButton (+)               |
+---------------------------------------------------+
```

Key: `[O]` = 32 dp circle placeholder. `====` = rounded rectangle text placeholder. Trailing `========` = amount placeholder.

### 3.2 Component Specification

| Element | Component | Configuration |
|---|---|---|
| Skeleton list | `OBTSkeletonLoader` | `type: activityRow`, `itemCount: 5`. |

**Skeleton shape (from component catalogue):** Each `activityRow` skeleton consists of:

- A 32 dp circle on the leading edge (icon placeholder).
- Two text-block rounded rectangles: 70% width (primary text) and 50% width (secondary text / timestamp), both 12 dp high.
- An optional trailing rectangle (48x20 dp) for the amount placeholder.

### 3.3 Animation

- Continuous shimmer animation sweeping left-to-right on a 1.5 s loop (SRS section 6.4: skeleton screens preferred over spinners).
- If the user has enabled `reduceMotion` at the OS level, the shimmer is suppressed and a static grey placeholder is shown instead (SRS section 5.6).
- Transition to loaded content uses a 200 ms fade-in (`motionStandard`).

### 3.4 Accessibility

- The entire skeleton group is wrapped in `Semantics(label: "Loading activity feed", liveRegion: true)`.
- When content loads, the live region announces the new content to screen readers.

---

## 4. Error State -- Data Fetch Failure

### 4.1 ASCII Layout

```
+---------------------------------------------------+
| OBTAppBar                                         |
|  "Activity"                          (no actions) |
+---------------------------------------------------+
|                                                   |
|                                                   |
|                                                   |
|              [Error Illustration]                 |
|            (muted, non-alarming SVG)              |
|                                                   |
|           "Something went wrong"                  |
|                                                   |
|      "We could not load your activity.            |
|       Please try again."                          |
|                                                   |
|              [ Retry ]                            |
|                                                   |
|           Contact Support                         |
|                                                   |
|                                                   |
+---------------------------------------------------+
| OBTBottomNav  [Home] [Friends] [Groups]           |
|               [Activity*] [Profile]               |
+---------------------------------------------------+
|         OBTFloatingActionButton (+)               |
+---------------------------------------------------+
```

### 4.2 Component Specification

| Element | Component | Value |
|---|---|---|
| Layout | `OBTErrorState` | Vertically centred within the scrollable area. |
| Title | `OBTErrorState.title` | `"Something went wrong"` (default). |
| Subtitle | `OBTErrorState.subtitle` | `"We could not load your activity. Please try again."` |
| Retry button | `OBTErrorState.onRetry` | Re-invokes the activity feed data fetch. |
| Support link | `OBTErrorState.onContactSupport` | Opens the Contact Support flow (FR-PR-05). |
| Error code | `OBTErrorState.errorCode` | Optional; displayed in small muted text (e.g., `"ERR_FEED_TIMEOUT"`). |

### 4.3 States and Transitions

| Scenario | Behaviour |
|---|---|
| Initial error | Default layout with Retry button in `primary` colour. |
| Retry pressed | Button shows a loading indicator (replaces label). Triggers re-fetch. |
| Retry succeeds | Transitions to the populated feed with a 200 ms fade-in. |
| Retry fails again | Returns to error state. Subtitle updates to `"Still not working. Try again or contact support."` |

### 4.4 Microcopy Rationale (SRS section 6.5)

The error copy is non-alarming and avoids technical jargon. The subtitle provides a clear action (`"Please try again"`) and the secondary `"Contact Support"` link offers an escalation path as required by SRS section 6.4.

---

## 5. Accessibility Specifications

All specifications below satisfy SRS section 5.6.

### 5.1 Tap Targets

| Element | Minimum Size | Actual Size |
|---|---|---|
| `OBTActivityRow` | 48x48 dp | Full-width row, minimum 56 dp height. |
| `OBTEmptyState` CTA button | 48x48 dp | Full-width button, 48 dp height. |
| `OBTErrorState` Retry button | 48x48 dp | Full-width button, 48 dp height. |
| `OBTErrorState` Support link | 48x48 dp | Text link with 48 dp hit area (padding applied). |
| `OBTBottomNav` tabs | 48x48 dp | Each tab meets minimum target. |
| `OBTFloatingActionButton` | 48x48 dp | 56x56 dp (exceeds minimum). |

### 5.2 Semantic Labels

| Element | Semantic Label Pattern |
|---|---|
| App bar title | `"Activity"` -- announced as a heading (`Semantics(header: true)`). |
| Activity row | `"[Primary text]. [Secondary text]. [Amount if present]. Tap to view details."` |
| Empty state illustration | Excluded from semantics (decorative). |
| Empty state title | Announced as a heading. |
| Empty state CTA | `"Add Expense"` -- announced as a button. |
| Error state illustration | Excluded from semantics (decorative). |
| Error state Retry | `"Retry"` -- announced as a button. |
| Error state Support link | `"Contact support"` -- announced as a link. |
| Error code (if present) | `"Error code: [code]"`. |
| Skeleton loader group | `"Loading activity feed"` -- live region. |
| Bottom navigation, Activity tab | `"Activity, tab, selected"`. |

### 5.3 Contrast Ratios

All text elements meet WCAG 2.1 AA minimum contrast ratios:

| Element | Foreground | Background | Ratio (approx.) | Pass |
|---|---|---|---|---|
| Primary text on surface (light) | `#1A1A1A` | `#FFFFFF` | 17.1:1 | Yes |
| Secondary text / timestamps | `#6B6B6B` | `#FFFFFF` | 5.9:1 | Yes |
| `primary` icon on surface | `#1F4E79` | `#FFFFFF` | 8.3:1 | Yes |
| `danger` icon on surface | `#E76F51` | `#FFFFFF` | 3.4:1 | Decorative icon; paired with text that passes |
| `success` icon on surface | `#2A9D8F` | `#FFFFFF` | 3.8:1 | Decorative icon; paired with text that passes |
| Error title on surface | `#1A1A1A` | `#FFFFFF` | 17.1:1 | Yes |
| Retry button label on `primary` | `#FFFFFF` | `#1F4E79` | 8.3:1 | Yes |

Note: Icons that fall below the 4.5:1 text ratio are always accompanied by text labels that independently meet the contrast threshold. Icons serve as supplementary visual cues, not sole information carriers.

### 5.4 Dark Mode

In dark mode (`surface: #121212`):

- Text colours invert to light-on-dark equivalents.
- `primary` accent shifts to `#2E86AB` (SRS section 6.2).
- All skeleton placeholders use `#1E1E1E` base with `#2A2A2A` shimmer highlight.
- Contrast ratios are recalculated to maintain WCAG 2.1 AA compliance.
- Card and row surfaces use `#1E1E1E` on the `#121212` background.

### 5.5 Dynamic Font Scaling

- All text within `OBTActivityRow` uses relative sizing and wraps gracefully.
- Row height grows to accommodate larger text without clipping.
- Timestamps may truncate with an ellipsis only at the most extreme scaling levels (200%+), but the full text remains available via the semantic label.

---

## 6. Motion and Interaction

All motion values reference the design token table in SRS section 6.2 and the component catalogue.

| Interaction | Duration | Curve | Notes |
|---|---|---|---|
| Row press (background tint) | 200 ms | ease-in-out | `primary` at 6% opacity. |
| Pull-to-refresh indicator appear | 200 ms | ease-in-out | Follows platform convention. |
| Skeleton shimmer loop | 1500 ms | linear | Left-to-right sweep; respects `reduceMotion`. |
| Skeleton-to-content transition | 200 ms | ease-in-out | Fade-in of actual rows. |
| Error-to-content transition | 200 ms | ease-in-out | Fade-in on successful retry. |
| FAB press | 200 ms | spring (damping ~0.7) | Scale to 0.92x on press, spring release. |
| List scroll | Native | Platform physics | Bouncing on iOS; clamping on Android. |

---

## 7. Component Dependency Summary

The following components from the component catalogue are consumed by the Activity Feed screen:

| Component | Catalogue Section | Usage on This Screen |
|---|---|---|
| `OBTAppBar` | Section 1 | Screen title bar. |
| `OBTBottomNav` | Section 2 | Tab navigation; index 3 selected. |
| `OBTFloatingActionButton` | Section 3 | Persistent FAB for adding expenses. |
| `OBTRupeeText` | Section 5 | Trailing amount formatting on activity rows. |
| `OBTActivityRow` | Section 14 | Primary list item for each activity event. |
| `OBTEmptyState` | Section 18 | Empty feed display. |
| `OBTErrorState` | Section 19 | Error display with retry. |
| `OBTSkeletonLoader` | Section 20 | Loading placeholders (`type: activityRow`). |

---

## 8. State Machine

The Activity Feed screen transitions through the following states:

```
                    +----------+
                    |  Initial |
                    +----+-----+
                         |
                         v
                   +-----------+
                   |  Loading  |  (OBTSkeletonLoader, type: activityRow)
                   +-----+-----+
                    /           \
                   v             v
          +-----------+    +-----------+
          | Populated |    |   Error   |  (OBTErrorState)
          +-----+-----+   +-----+-----+
                |                |
        pull-to-refresh     Retry tap
                |                |
                v                v
          +-----------+    +-----------+
          | Refreshing|    |  Loading  |
          +-----+-----+   +-----------+
           /         \
          v           v
   +-----------+ +-----------+
   | Populated | | Populated |  (with OBTSnackbar on refresh failure)
   +-----------+ +-----------+

   If data is empty --> Empty State (OBTEmptyState)
```

| State | Display | Entry Condition |
|---|---|---|
| Loading | `OBTSkeletonLoader` (5 `activityRow` skeletons) | Screen first opened; no cached data. |
| Populated | Scrollable `OBTActivityRow` list | Data successfully fetched; list is non-empty. |
| Empty | `OBTEmptyState` | Data successfully fetched; list is empty. |
| Error | `OBTErrorState` | Data fetch failed; no cached data to show. |
| Refreshing | Populated list with `RefreshIndicator` active | User pulls to refresh on the populated list. |

---

## 9. Notification Deep-Link Handling (FR-AC-03, FR-AC-05)

When a push notification is tapped (warm or cold start), the app resolves the deep-link target as follows:

1. Parse the notification payload for `eventType` and `entityId`.
2. If the app is in a cold-start state, complete authentication first (auth guard), then navigate.
3. Navigate to the target screen as defined in section 1.6 above.
4. The Activity tab should also reflect the new event at the top of the feed upon next visit.

This aligns with FR-AC-05 (deep-link from notification, including cold start) and the navigation flow document (`docs/design/01-information-architecture/navigation-flow.md`).

---

## 10. Extension Points

These items are explicitly out of scope for v1.0 but the design accommodates them:

- **Read/unread markers (v1.1):** The `OBTActivityRow` component already defines an `Unread` state with a 3 dp `primary` left-edge bar indicator. The feed layout supports this without structural changes. An unread count badge could be added to the Activity tab in `OBTBottomNav`.
- **System announcements or tips:** The feed list could intersperse non-event cards (e.g., onboarding tips, product announcements) as a distinct row type, differentiated by a `secondary` background tint. This would require a new component (e.g., `OBTAnnouncementCard`) but no changes to the feed's scroll or state architecture.
- **Pagination / infinite scroll:** For users with extensive history, the feed should support cursor-based pagination. The skeleton loader can be repurposed as a bottom-of-list loading indicator.