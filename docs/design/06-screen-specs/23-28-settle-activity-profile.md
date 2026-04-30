# Screen Specifications: Settle Up, Activity Feed, Profile and Support (SCR-23 to SCR-28)

> **Document owner:** UX/UI Designer
> **Version:** 1.0
> **Status:** Draft
> **SRS baseline:** v1.1
> **Last updated:** 2025-07-15

---

## Table of Contents

1. [SCR-23: Settle Up](#scr-23-settle-up)
2. [SCR-24: Settlement History](#scr-24-settlement-history)
3. [SCR-25: Activity Feed](#scr-25-activity-feed)
4. [SCR-26: Profile View/Edit](#scr-26-profile-viewedit)
5. [SCR-27: Notification Preferences](#scr-27-notification-preferences)
6. [SCR-28: Contact Support and Account Deletion](#scr-28-contact-support-and-account-deletion)

---

## Design Token Quick Reference

All screens in this document consume tokens from `docs/design/02-design-system/tokens.md` and the component catalogue at `docs/design/02-design-system/components.md`.

| Token | Light | Dark | Applied to |
|---|---|---|---|
| `primary` | `#1F4E79` | `#2E86AB` | Primary actions, app bar, focused inputs |
| `secondary` | `#F4A261` | `#F4A261` | FAB, accent highlights |
| `success` | `#2A9D8F` | `#2A9D8F` | "You are owed", positive states, settlement confirmation |
| `danger` | `#E76F51` | `#E76F51` | "You owe", destructive actions, validation errors |
| `surface` | `#FFFFFF` | `#121212` | Cards, sheets, dialogs |
| `background` | `#F8F9FB` | `#121212` | Scaffold background |
| `textPrimary` | `#1A1A1A` | `#FFFFFF` | Headings, primary labels |
| `textSecondary` | `#4B5563` | `#9CA3AF` | Descriptions, timestamps |
| `divider` | `#E4E7EC` | `#2C2C2C` | Section separators |
| `cornerRadiusSmall` | 16 dp | -- | Buttons, pills, inputs |
| `cornerRadiusLarge` | 24 dp | -- | Cards, bottom sheets, dialogs |
| `tapTargetMin` | 48x48 dp (Android) / 44x44 pt (iOS) | -- | All interactive elements |
| `motionStandard` | 200--300 ms ease-in-out | -- | Page transitions, state changes |
| `motionSpring` | Spring physics (damping ~0.7) | -- | Confirmation checkmark, FAB press |

---

## SCR-23: Settle Up

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-23 |
| **Screen Name** | Settle Up |
| **Purpose** | Record a settlement (payment) between the current user and another user, with pre-filled amount from the simplified-debts suggestion. Supports partial settlement. |
| **Route** | `/settle` |
| **SRS Requirements** | FR-SE-05 (P0), FR-SE-06 (P0), FR-SE-07 (P0) |
| **Core Screen** | 9 -- Settle Up flow (SRS section 6.3, item 9) |

### Navigation

| Direction | Screens |
|---|---|
| **Reachable from** | Home Dashboard (via `OBTSettleUpCard` CTA, FR-HD-02); Friend Detail (via "Settle Up" button, FR-FR-03); Group Detail (via per-member `OBTSettleUpCard`, FR-GR-04) |
| **Leads to** | Settlement Confirmation (success); returns to originating screen (on back/cancel); error snackbar remains on current screen |

### Components Used

| Component | Catalogue Section | Role |
|---|---|---|
| `OBTAppBar` | 1 | Screen header; `title: "Settle Up"`, `showBackButton: true` |
| `OBTUserAvatar` (x2) | -- | Payer and payee identity, connected by a directional arrow icon |
| `OBTAmountInput` | 6 | Editable amount field; `initialAmountPaise` pre-filled from simplified-debts suggestion |
| Date picker | -- | Platform-native or Material date picker; defaults to today |
| Text field | -- | Optional note; max 200 characters |
| Primary button | -- | Label: "Record Settlement"; full-width; `primary` colour; 48 dp height |
| `OBTBalancePill` | 4 | Displayed on the confirmation sub-screen post-recording |
| `OBTSnackbar` | -- | Error feedback with "Retry" action |

### States

| State | Description | Visual Treatment |
|---|---|---|
| **Default** | Form loaded with pre-filled values from navigation arguments (`payerUserId`, `payeeUserId`, `suggestedAmountPaise`, `contextType`, `contextId`). All fields idle. | Amount field shows pre-filled value; date defaults to today; note empty; "Record Settlement" button in `primary`. |
| **Editing** | User modifies amount, date, or note. | Focused field border in `primary`; keyboard visible; button remains enabled unless validation fails. |
| **Validation error** | Amount is zero, exceeds simplified balance, or date is in the future. | `OBTAmountInput` displays `errorText` in `danger`; "Record Settlement" button disabled (`disabled` colour). |
| **Loading** | Settlement write to Firestore in progress; Cloud Function `recomputeSimplifiedBalances` firing. | Button text replaced by circular progress indicator; all fields disabled; 200--300 ms transition (SRS section 6.2). |
| **Success** | Cloud Function completed; balances updated. | Transitions to Settlement Confirmation sub-screen with animated checkmark (see below). |
| **Error** | Network failure or server rejection. | `OBTSnackbar(type: error)` with message and "Retry" action; form returns to editable state. |

### Settlement Confirmation Sub-screen

Displayed inline after a successful recording. Not a separate route.

- **Animated checkmark:** `success` colour (`#2A9D8F`); scale-in from 0 to 1 with spring physics; 300 ms duration. Respects `AccessibilityFeatures.reduceMotion` -- if active, the checkmark appears immediately.
- **Title:** "Settlement recorded" (`titleMedium`, `primary`).
- **Subtitle (full settlement):** "You paid [Name] Rs[amount]. You're all settled up -- high five!" (SRS section 6.5).
- **Subtitle (partial settlement):** "You paid [Name] Rs[amount]."
- **`OBTBalancePill`:** Shows the updated balance from the freshly recomputed `simplifiedBalances` (Invariant 2 -- client reads only).
- **"Done" button:** Full-width, `primary`, returns to the originating screen.

### Inputs and Validation

| Field | Type | Required | Validation Rule | Error Message |
|---|---|---|---|---|
| Amount | `OBTAmountInput` (integer paise output) | Yes | Must be > 0 paise | "Amount must be greater than zero." |
| Amount | `OBTAmountInput` | Yes | Must not exceed `suggestedAmountPaise` | "Amount cannot exceed the outstanding balance of Rs[suggestedAmount]." |
| Date | Date picker | Yes | Must not be in the future | "Date cannot be in the future." |
| Note | Text field | No | Max 200 characters | "Note must be 200 characters or fewer." |

All monetary values are integer paise (Invariant 1). Conversion to rupees with Indian numbering formatting occurs at the UI layer via `OBTRupeeText` / `OBTAmountInput`.

### Telemetry Events

| Event Name | Parameters | Trigger | SRS Reference |
|---|---|---|---|
| `settlement_recorded` | `amount_paise`, `context_type`, `context_id`, `is_partial` | Settlement successfully written | SRS section 5.10 |
| `settle_up_screen_viewed` | `context_type`, `context_id`, `suggested_amount_paise` | Screen opened | SRS section 5.10 |
| `settle_up_error` | `error_code`, `context_type` | Settlement write fails | SRS section 5.10 |

### Accessibility

| Element | Semantic Label | Role |
|---|---|---|
| Payer avatar + name | "[Your name] pays" | `text` |
| Arrow icon | Excluded from semantics (decorative; names read in sequence) | -- |
| Payee avatar + name | "[Payee name]" | `text` |
| Amount input | "Enter amount in rupees" | `textField` |
| Date picker | "Settlement date, [selected date]" | `button` |
| Note field | "Add a note, optional" | `textField` |
| Record Settlement button | "Record settlement of rupees [amount] to [payee name]" | `button` |
| Confirmation checkmark | "Settlement successful" (live region) | `image` |
| Done button | "Done, return to previous screen" | `button` |

- All interactive elements meet the 48x48 dp minimum tap target (SRS section 5.6).
- All text meets WCAG 2.1 AA contrast ratios (minimum 4.5:1 for body text; SRS section 5.6).
- Screen fully supports OS-level dynamic font scaling and dark mode (SRS section 5.6).
- Screen-reader compatible with semantic labels on every interactive widget (SRS section 5.6).

### Edge Cases

1. **Simplified balance becomes zero between navigation and submission.** If another user records a settlement concurrently, the `suggestedAmountPaise` may become stale. The Cloud Function must reject an over-settlement. The screen displays an `OBTSnackbar(type: error)` with the message: "The balance has changed. Please go back and try again." The form becomes read-only. The user taps "Back" to return to the originating screen, which shows the updated balance via real-time Firestore listener (FR-SE-06).
2. **Offline submission.** If the device is offline (FR-OF-02), the settlement is queued locally. An `OBTSnackbar(type: info)` appears: "You are offline. This settlement will be recorded when you reconnect." The confirmation sub-screen is not shown until the Cloud Function confirms recomputation. The user is returned to the originating screen.
3. **User navigates back during loading state.** The system back gesture is intercepted and ignored while the submission is in progress (analogous to Delete Account Step D). A brief toast is not shown; the loading indicator communicates that work is in progress.
4. **Amount field receives non-numeric input.** The `OBTAmountInput` keyboard type is set to numeric-with-decimal. Paste of non-numeric strings is silently stripped to digits and decimal point only.

### Open Questions

1. **Partial settlement microcopy:** Should partial settlements display a follow-up prompt such as "Settle the remaining Rs[X]?" or is the updated `OBTBalancePill` sufficient?
2. **Maximum settlement amount ceiling:** The current validation caps at `suggestedAmountPaise`. Should the system additionally enforce a per-transaction ceiling (e.g., Rs 10,00,000) for fraud prevention, or is this deferred to a future moderation layer?
3. **Settlement date backdating limit:** The current spec allows any past date. Should a maximum backdating window (e.g., 90 days) be enforced to prevent abuse?

---

## SCR-24: Settlement History

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-24 |
| **Screen Name** | Settlement History |
| **Purpose** | Display a reverse-chronological list of all settlements for a given friend or group context, enabling the user to review past payments. |
| **Route** | `/settle/history` (accepts `contextType` and `contextId` as query parameters) |
| **SRS Requirements** | FR-SE-08 (P0) |
| **Core Screen** | Sub-screen of Core Screens 6 and 7 (SRS section 6.3, items 6, 7) |

### Navigation

| Direction | Screens |
|---|---|
| **Reachable from** | Friend Detail (via "View Settlement History" text link); Group Detail (via "View Settlement History" text link) |
| **Leads to** | No forward navigation from this screen. Back returns to the originating detail screen. |

### Components Used

| Component | Catalogue Section | Role |
|---|---|---|
| `OBTAppBar` | 1 | `title: "Settlement History"`, `showBackButton: true` |
| `OBTUserAvatar` (x2 per row) | -- | Payer and payee identity per settlement |
| `OBTRupeeText` | 5 | Amount formatting per row |
| `OBTSkeletonLoader` | 20 | Loading state; `type: listTile`, `itemCount: 5` |
| `OBTEmptyState` | 18 | Empty list display |
| `OBTErrorState` | 19 | Error display with retry and Contact Support link |

### States

| State | Description | Visual Treatment |
|---|---|---|
| **Loading** | Data fetch in progress; no cached data available. | `OBTSkeletonLoader` with 5 `listTile` skeletons; shimmer animation (suppressed if `reduceMotion` is active). |
| **Populated** | Settlements successfully fetched; list is non-empty. | Reverse-chronological list of settlement rows. |
| **Empty** | Settlements fetched; list is empty (no settlements recorded). | `OBTEmptyState` centred vertically. Title: "No settlements yet". Subtitle: "Once you settle up, it will appear here." No CTA button. |
| **Error** | Data fetch failed; no cached data. | `OBTErrorState`. Title: "Something went wrong". Subtitle: "We could not load settlement history. Please try again." "Retry" button. "Contact Support" link (FR-PR-05). |
| **Retry loading** | User tapped "Retry" on error state. | "Retry" button shows inline circular progress indicator. |
| **Retry failed** | Second fetch attempt also failed. | Returns to error state. Subtitle updates to: "Still not working. Try again or contact support." |

### Settlement Row Layout

Each row displays:

| Element | Rendering |
|---|---|
| Date | `dd MMM yyyy` in IST (`Asia/Kolkata`), displayed as a section header or inline above the row (SRS section 5.9). |
| From avatar | `OBTUserAvatar` for the payer. |
| Arrow | Directional `-->` icon in muted colour. |
| To avatar | `OBTUserAvatar` for the payee. |
| Amount | `OBTRupeeText` with `amountPaise`; displayed in `primary` colour. |
| Note | Muted body text (`bodySmall`, `textSecondary`) below the amount; hidden if `null`. |

Minimum row height: 64 dp (ensures 48x48 dp tap targets with padding; SRS section 5.6).

### Context Variants

| Context | Access Point | Data Scope |
|---|---|---|
| Friend | Friend Detail -- "View Settlement History" link | Settlements where `contextType == 'friendship'` and `contextId` matches the friendship document. |
| Group | Group Detail -- "View Settlement History" link | Settlements where `contextType == 'group'` and `contextId` matches the group document. |

### Inputs and Validation

This screen has no user inputs. It is a read-only list view. Navigation arguments (`contextType`, `contextId`) are required and validated on entry; if missing or invalid, the screen displays the error state immediately.

### Telemetry Events

| Event Name | Parameters | Trigger | SRS Reference |
|---|---|---|---|
| `settlement_history_viewed` | `context_type`, `context_id`, `item_count` | Screen loaded with data | SRS section 5.10 |
| `settlement_history_error` | `error_code`, `context_type` | Data fetch fails | SRS section 5.10 |

### Accessibility

| Element | Semantic Label | Role |
|---|---|---|
| Screen title | "Settlement history" (heading) | `header` |
| Settlement row | "[Payer name] paid [Payee name] rupees [amount] on [date]. Note: [note or 'no note']." | `listItem` within a `list` semantic group |
| Empty state | Per `OBTEmptyState` specification | -- |
| Error state | Per `OBTErrorState` specification | -- |
| Skeleton loader | "Loading settlement history" (live region) | -- |

- All text meets WCAG 2.1 AA contrast ratios (SRS section 5.6).
- Fully supports dynamic font scaling; row height grows to accommodate larger text without clipping.
- Dark mode: card and row surfaces use `#1E1E1E` on `#121212` background.

### Edge Cases

1. **Very long settlement history (100+ items).** The list should support cursor-based pagination or lazy loading to avoid excessive memory consumption. If pagination is not implemented in v1.0, the list fetches the most recent 50 settlements with a "Load more" button at the bottom. This is an implementation decision for the Flutter Developer.
2. **Settlement recorded while viewing history.** If a new settlement is recorded by the other party while this screen is open, the real-time Firestore listener should prepend the new row at the top with a 200 ms fade-in animation. No manual refresh should be required (FR-SE-06).
3. **Context document deleted.** If the friendship or group is deleted while viewing its settlement history, the screen should display an `OBTSnackbar(type: info)` with the message: "This friend or group is no longer available." and navigate back to the originating screen after a 2-second delay.

### Open Questions

1. **Settlement row tap behaviour.** Should tapping a settlement row open a detail view or remain non-interactive? The current spec does not define a settlement detail screen.
2. **Export/share settlement history.** Should a "Share" action be available in the app bar to export settlement history as text via the system share sheet (Invariant 3)? This may be a v1.1 feature.
3. **Grouping by month.** Should settlements be grouped by month with section headers, or displayed as a flat chronological list?

---

## SCR-25: Activity Feed

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-25 |
| **Screen Name** | Activity Feed |
| **Purpose** | Display a chronological feed of all events (expenses added/edited/deleted, settlements, group changes, friend additions) involving the current user, with deep-link navigation to relevant entities. |
| **Route** | `/activity` |
| **SRS Requirements** | FR-AC-01 (P0), FR-AC-02 (P0) |
| **Core Screen** | 10 -- Activity feed (SRS section 6.3, item 10) |

### Navigation

| Direction | Screens |
|---|---|
| **Reachable from** | `OBTBottomNav` tab index 3 ("Activity"); push notification deep-link (FR-AC-05) |
| **Leads to** | Expense Detail (via `expenseAdded` or `expenseEdited` row tap); Friend Detail (via `friendAdded` or `settlementRecorded` row tap); Group Detail (via `groupCreated`, `groupMemberAdded`, `groupMemberRemoved` row tap); for `expenseDeleted`, remains on Activity feed with snackbar "This item is no longer available." |

### Components Used

| Component | Catalogue Section | Role |
|---|---|---|
| `OBTAppBar` | 1 | `title: "Activity"`, `showBackButton: false` (tab root); no trailing actions; elevation 0.5 |
| `OBTBottomNav` | 2 | `currentIndex: 3` (Activity tab selected) |
| `OBTFloatingActionButton` | 3 | Persistent FAB for adding expenses (FR-HD-04) |
| `OBTActivityRow` | 14 | Primary list item for each activity event |
| `OBTRupeeText` | 5 | Trailing amount formatting on activity rows |
| `OBTEmptyState` | 18 | Empty feed display |
| `OBTErrorState` | 19 | Error display with retry |
| `OBTSkeletonLoader` | 20 | Loading placeholders; `type: activityRow`, `itemCount: 5` |
| `OBTSnackbar` | -- | Refresh failure, deleted entity feedback |

### States

| State | Description | Visual Treatment |
|---|---|---|
| **Loading** | Screen first opened; no cached data. | `OBTSkeletonLoader` with 5 `activityRow` skeletons. Shimmer animation (1.5 s loop, left-to-right); suppressed to static grey if `reduceMotion` is active (SRS section 5.6). Semantics: "Loading activity feed" (live region). |
| **Populated** | Data successfully fetched; list is non-empty. | Scrollable `OBTActivityRow` list in reverse-chronological order. Pull-to-refresh enabled. Each row is tappable (FR-AC-02). |
| **Empty** | Data successfully fetched; list is empty (new user). | `OBTEmptyState` centred vertically. Title: "All quiet here". Subtitle: "Your activity will show up as you add expenses and settle up." CTA: "Add Expense" (opens Add Expense flow, same as FAB). |
| **Error** | Data fetch failed; no cached data to show. | `OBTErrorState` centred. Title: "Something went wrong". Subtitle: "We could not load your activity. Please try again." "Retry" button. "Contact Support" link (FR-PR-05, SRS section 6.4). |
| **Refreshing** | User pulls to refresh on a populated list. | Populated list with platform-native `RefreshIndicator` active; indicator colour: `primary`. On failure: `OBTSnackbar(message: "Could not refresh. Check your connection and try again.", type: error)`. |
| **Retry failed** | Second fetch attempt after error also failed. | Returns to error state. Subtitle updates to: "Still not working. Try again or contact support." |

### Event Type Mapping

| Event Type | Icon | Colour | Example `primaryText` | Trailing Amount |
|---|---|---|---|---|
| `expenseAdded` | `receipt_long` | `primary` | "Priya added 'Dinner at Dosa Plaza'" | User's share in paise |
| `expenseEdited` | `edit` | `secondary` | "Amit edited 'Groceries'" | Updated amount |
| `expenseDeleted` | `delete` | `danger` | "You deleted 'Auto fare'" | Deleted amount |
| `settlementRecorded` | `check_circle` | `success` | "You settled up with Rahul" | Settlement amount |
| `groupCreated` | `group_add` | `primary` | "You created 'Goa Trip'" | None |
| `groupMemberAdded` | `person_add` | `primary` | "Neha was added to 'Goa Trip'" | None |
| `groupMemberRemoved` | `person_remove` | `danger` | "Ravi was removed from 'Flat Expenses'" | None |
| `friendAdded` | `person_add` | `success` | "Priya added you as a friend" | None |

### Relative Timestamp Format

| Elapsed Time | Display |
|---|---|
| < 1 minute | "Just now" |
| 1--59 minutes | "X min ago" |
| 1--23 hours | "X hours ago" (or "1 hour ago") |
| 1 day | "Yesterday" |
| 2--6 days | "X days ago" |
| 7+ days | "dd MMM" (e.g., "14 Mar") |
| Previous year | "dd MMM yyyy" (e.g., "28 Dec 2024") |

All timestamps rendered in IST (`Asia/Kolkata`) per SRS section 5.9.

### Deep-Link Behaviour (FR-AC-02)

| Event Type | Deep-Link Target |
|---|---|
| `expenseAdded` | Expense detail screen |
| `expenseEdited` | Expense detail screen |
| `expenseDeleted` | Group detail or Friend detail (expense no longer exists) |
| `settlementRecorded` | Friend detail screen |
| `groupCreated` | Group detail screen |
| `groupMemberAdded` | Group detail screen |
| `groupMemberRemoved` | Group detail screen |
| `friendAdded` | Friend detail screen |

If the target entity has been deleted, the app displays an `OBTSnackbar(message: "This item is no longer available.", type: info)` and remains on the Activity feed.

### Inputs and Validation

This screen has no user inputs. It is a read-only feed. Pull-to-refresh is the only interaction beyond row taps.

### Telemetry Events

| Event Name | Parameters | Trigger | SRS Reference |
|---|---|---|---|
| `activity_feed_viewed` | `item_count` | Screen opened with populated data | SRS section 5.10 |
| `activity_item_tapped` | `event_type`, `entity_id` | User taps an activity row | SRS section 5.10 |
| `activity_feed_refreshed` | `success` (boolean) | Pull-to-refresh completed | SRS section 5.10 |
| `activity_feed_error` | `error_code` | Data fetch fails | SRS section 5.10 |

### Accessibility

| Element | Semantic Label | Role |
|---|---|---|
| App bar title | "Activity" (heading; `Semantics(header: true)`) | `header` |
| Activity row | "[Primary text]. [Secondary text]. [Amount if present]. Tap to view details." | `listItem` within `list` |
| Empty state illustration | Excluded from semantics (decorative) | -- |
| Empty state title | Announced as heading | `header` |
| Empty state CTA | "Add Expense" | `button` |
| Error state illustration | Excluded from semantics (decorative) | -- |
| Error state Retry | "Retry" | `button` |
| Error state Support link | "Contact support" | `link` |
| Skeleton loader group | "Loading activity feed" (live region) | -- |
| Bottom navigation, Activity tab | "Activity, tab, selected" | `tab` |
| FAB | "Add new expense" | `button` |

Contrast ratios verified per wireframe document: `textPrimary` on `surface` (light) = 17.1:1; `textSecondary` on `surface` = 5.9:1; `primary` icon on `surface` = 8.3:1. All pass WCAG 2.1 AA. Icons below 4.5:1 are decorative and always paired with passing text labels.

### Edge Cases

1. **Notification deep-link from cold start (FR-AC-05).** The app must complete authentication (auth guard) before navigating to the target screen. The Activity tab should reflect the new event at the top of the feed upon the next visit.
2. **Rapid successive events.** If multiple events arrive in quick succession (e.g., a group member adds several expenses), the list should batch-animate new rows in with staggered 50 ms delays rather than jarring instant insertion.
3. **Activity for a deleted group or friend.** Historical activity rows for entities that no longer exist should remain visible in the feed but display a muted style. Tapping such a row shows the "This item is no longer available." snackbar.
4. **Extremely long primary text.** If an expense description is very long (e.g., 100 characters), the `primaryText` in `OBTActivityRow` should truncate with an ellipsis after two lines. The full text is available via the semantic label and by navigating to the expense detail.

### Open Questions

1. **Read/unread markers.** The component catalogue defines an `Unread` state for `OBTActivityRow` with a 3 dp `primary` left-edge bar. Is this shipped in v1.0 or deferred to v1.1?
2. **Infinite scroll vs. full load.** For users with extensive history, should the feed support cursor-based pagination or load all activity? What is the maximum item count before performance degrades?
3. **Filter or search within activity.** Should users be able to filter the activity feed by event type (e.g., settlements only) in v1.0, or is this deferred?

---

## SCR-26: Profile View/Edit

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-26 |
| **Screen Name** | Profile View/Edit |
| **Purpose** | Display the current user's profile information (name, photo, phone number), provide access to friends/groups counts, and offer entry points to Edit Profile, Notification Preferences, Contact Support, Sign Out, and Delete Account. The Edit Profile sub-flow allows updating the display name and profile photo. |
| **Route** | `/profile` (view), `/profile/edit` (edit sub-screen) |
| **SRS Requirements** | FR-PR-01 (P0), FR-PR-04 (P0), FR-PR-05 (P0), FR-AU-08 (P0) |
| **Core Screen** | 11 -- Profile and Settings (SRS section 6.3, item 11) |

### Navigation

| Direction | Screens |
|---|---|
| **Reachable from** | `OBTBottomNav` tab index 4 ("Profile") |
| **Leads to** | Friends List (via "My Friends" row, tab index 1); Groups List (via "My Groups" row, tab index 2); Edit Profile (`/profile/edit`); Notification Preferences (`/profile/notifications`, SCR-27); Contact Support flow (SCR-28); Sign Out (returns to Phone Entry screen); Delete Account flow (SCR-28) |

### Components Used

| Component | Catalogue Section | Role |
|---|---|---|
| `OBTAppBar` | 1 | `title: "Profile"`, `showBackButton: false` (tab root) |
| `OBTBottomNav` | 2 | `currentIndex: 4` (Profile tab selected) |
| `OBTUserAvatar` | -- | Profile photo; `size: 96 dp`; centred horizontally |
| `OBTSkeletonLoader` | 20 | Loading state skeleton |
| `OBTErrorState` | 19 | Error state with Retry and Contact Support |
| `OBTConfirmationDialog` | -- | Sign Out confirmation dialog |
| `OBTSnackbar` | -- | Edit success/error, photo upload feedback |

### Profile View Layout

The Profile View is structured in four sections separated by full-bleed 1 dp dividers (`divider` colour):

1. **Profile header:** `OBTUserAvatar` (96 dp), display name (`titleLarge`, `textPrimary`), phone number (`bodyMedium`, `textSecondary`, read-only).
2. **Stats section:** "My Friends" row (leading `people` icon, trailing count + chevron); "My Groups" row (leading `groups` icon, trailing count + chevron). Each row is 56 dp height.
3. **Actions section:** "Edit Profile" row; "Notification Preferences" row; "Contact Support" row. Each 56 dp height, leading icon in `primary`, trailing chevron.
4. **Destructive section:** "Sign Out" row (`textPrimary`); "Delete Account" row (`danger` colour). Each 56 dp height.

### Edit Profile Sub-screen

Pushed from the "Edit Profile" row. `OBTAppBar` with back button; bottom nav hidden.

- **Avatar with camera badge:** Tapping opens a bottom sheet (`cornerRadiusLarge` top corners) with options: "Take Photo", "Choose from Gallery", "Remove Photo" (only if photo exists; `danger` colour).
- **Display name text input:** Pre-populated; clear button when non-empty; `cornerRadiusSmall` outline border.
- **Phone number field:** Read-only, disabled style, `textTertiary`. Hint: "Phone number cannot be changed from here."
- **Save button:** Full-width, `primary` filled, `cornerRadiusSmall`. Disabled when name is unchanged or empty.

### States

#### Profile View

| State | Description | Visual Treatment |
|---|---|---|
| **Loading** | Profile data fetch in progress. | `OBTSkeletonLoader`: 96 dp circle shimmer (avatar), 160 dp and 120 dp text bar shimmers, three 56 dp row shimmers. |
| **Populated** | Profile data loaded successfully. | Full layout as described above. |
| **Empty** | Not applicable -- a profile always exists for an authenticated user. | -- |
| **Error** | Profile data fetch failed. | `OBTErrorState`. Title: "Something went wrong". Subtitle: "We could not load your profile. Check your connection and try again." "Retry" button. "Contact Support" link. |
| **Retry loading** | User tapped "Retry". | Retry button shows inline progress indicator. |
| **Retry failed** | Second fetch failed. | Subtitle updates to: "Still not working. Try again or contact support." |

#### Edit Profile

| State | Description | Visual Treatment |
|---|---|---|
| **Default** | Fields pre-populated; no changes made. | Save button in `disabled` colour. |
| **Editing** | User modifies display name. | Save button in `primary` fill. |
| **Empty name** | User clears the name field. | Inline error below field: "Display name cannot be empty" (`danger`). Save button disabled. |
| **Saving** | Save API call in progress. | Save button shows circular progress indicator (`onPrimary`). Back button disabled. Fields disabled. |
| **Save success** | Profile updated. | `OBTSnackbar(message: "Profile updated", type: success)`. Navigate back to Profile View. |
| **Save error** | Network or server error. | `OBTSnackbar(message: "Could not update profile. Try again.", type: error, actionLabel: "Retry", onAction: retrySave)`. Fields remain editable. |

### Inputs and Validation (Edit Profile)

| Field | Type | Required | Validation Rule | Error Message |
|---|---|---|---|---|
| Display name | Text input | Yes | Must not be empty after trimming whitespace | "Display name cannot be empty." |
| Display name | Text input | Yes | Must not exceed 50 characters | "Display name must be 50 characters or fewer." |
| Profile photo | Image picker (camera/gallery) | No | Max file size 5 MB; accepted formats: JPEG, PNG | "Photo must be under 5 MB." / "Unsupported image format." |

### Sign Out Flow

Triggered from the "Sign Out" row. Presents a modal `OBTConfirmationDialog`:

- **Title:** "Sign out?"
- **Body:** "Are you sure you want to sign out? You will need to verify your phone number again to sign back in."
- **Cancel:** Outlined button, `textSecondary`. Dismisses dialog.
- **Sign Out:** `danger` filled button. Clears local session, navigates to Phone Entry screen (FR-AU-08). Loading state: button text replaced by spinner; label becomes "Signing out...".

### Telemetry Events

| Event Name | Parameters | Trigger | SRS Reference |
|---|---|---|---|
| `profile_viewed` | -- | Profile View screen opened | SRS section 5.10 |
| `profile_edited` | `fields_changed` (array) | Profile saved successfully | SRS section 5.10 |
| `profile_photo_changed` | `action` ("take", "choose", "remove") | Photo change completed | SRS section 5.10 |
| `sign_out_completed` | -- | User signs out successfully | SRS section 5.10 |
| `sign_out_cancelled` | -- | User cancels sign-out dialog | SRS section 5.10 |

### Accessibility

| Element | Semantic Label | Role |
|---|---|---|
| Avatar (Profile View) | "[Display name] profile photo" | `image` |
| Display name | Readable as-is; announced as heading level | `text` |
| Phone number | "Phone number: plus 91 [formatted number]" | `text` (read-only, no button role) |
| My Friends row | "My Friends, [count], button" | `button` |
| My Groups row | "My Groups, [count], button" | `button` |
| Each action row | "[label], button" | `button` |
| Sign Out row | "Sign Out, button" | `button` |
| Delete Account row | "Delete Account, button" | `button` |
| Avatar + camera badge (Edit) | "Change profile photo, button" | `button` (merged tap target) |
| Display name field (Edit) | "Display name, text field, required" | `textField` |
| Phone number field (Edit) | "Phone number, plus 91 [number], read-only" | `text` |
| Save button (Edit) | "Save, button" or "Save, button, disabled" | `button` |
| Sign Out dialog | `OBTConfirmationDialog` spec; modal focus trap | `alertDialog` |

All rows meet 48x48 dp minimum tap target (SRS section 5.6). Contrast: `textPrimary` on `surface` = 17.4:1; `danger` on `surface` = 4.6:1; both exceed WCAG 2.1 AA 4.5:1 threshold.

### Edge Cases

1. **Display name with only whitespace.** The trimming validation must catch names consisting solely of spaces or special whitespace characters. The error message "Display name cannot be empty." applies.
2. **Photo upload timeout on slow connection.** If the Firebase Storage upload exceeds 30 seconds, the upload is cancelled and an `OBTSnackbar(type: error)` is shown: "Photo upload timed out. Please try again on a better connection." The avatar reverts to the previous state.
3. **Concurrent profile edit on another device.** If the user edits their profile on a second device while the Edit Profile screen is open, the real-time Firestore listener on the Profile View will reflect the latest data when the user navigates back. No conflict resolution UI is shown on the Edit screen itself -- last-write-wins applies (FR-OF-03).
4. **Sign out with pending offline writes.** If there are queued offline settlements or expenses, the sign-out confirmation body should append: "You have unsaved changes that will be lost." This requires the Flutter Developer to check the offline queue before presenting the dialog.

### Open Questions

1. **Phone number change (FR-PR-02).** The SRS lists phone number update as P1. Should the Edit Profile screen include a disabled "Change Phone Number" row with a "Coming soon" label, or should it be entirely absent in v1.0?
2. **Profile photo crop.** Should the app offer a square crop tool after photo selection, or accept the image as-is? Cropping improves avatar appearance but adds complexity.
3. **Friends/groups count source.** Should "My Friends" and "My Groups" counts come from a dedicated counter field on the user document (for performance) or be derived from a collection count query?

---

## SCR-27: Notification Preferences

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-27 |
| **Screen Name** | Notification Preferences |
| **Purpose** | Allow users to control which categories of push notifications they receive, with per-category toggles that auto-save on change. |
| **Route** | `/profile/notifications` |
| **SRS Requirements** | FR-PR-03 (P1) |
| **Core Screen** | Sub-screen of Core Screen 11 (SRS section 6.3, item 11) |

### Navigation

| Direction | Screens |
|---|---|
| **Reachable from** | Profile View (SCR-26) via "Notification Preferences" row |
| **Leads to** | No forward navigation. Back returns to Profile View. |

### Components Used

| Component | Catalogue Section | Role |
|---|---|---|
| `OBTAppBar` | 1 | `title: "Notification Preferences"`, `showBackButton: true` |
| `OBTSkeletonLoader` | 20 | Loading state; three 72 dp rows with shimmer |
| `OBTErrorState` | 19 | Load failure with Retry |
| `OBTSnackbar` | -- | Save error feedback, offline indicator |

### Layout

- **Descriptive header:** "Choose which notifications you would like to receive." (`bodyMedium`, `textSecondary`; 16 dp horizontal padding, 16 dp top padding).
- **Toggle rows:** Three rows separated by dividers, each containing a label, description, and platform-adaptive `Switch` widget.

### Toggle Mapping

| Toggle Label | Description | `notificationPrefs` Field | Default |
|---|---|---|---|
| New Expenses | "Get notified when someone adds an expense involving you." | `newExpense` | `true` |
| Settlements | "Get notified when someone records a payment involving you." | `settlement` | `true` |
| Reminders | "Receive reminders about outstanding balances." | `reminder` | `true` |

**Data model:** Maps to `users/{userId}.notificationPrefs` (SRS section 7.2): `{ newExpense: bool, settlement: bool, reminder: bool }`.

### States

| State | Description | Visual Treatment |
|---|---|---|
| **Loading** | Preferences data fetch in progress. | `OBTSkeletonLoader`: three 72 dp rows with shimmer. |
| **Populated** | Preferences loaded; toggles reflect current values. | Three toggle rows with descriptions. |
| **Empty** | Not applicable -- preferences always exist with defaults. | -- |
| **Error (load)** | Preferences fetch failed. | `OBTErrorState`. Title: "Something went wrong". Subtitle: "Could not load your preferences." "Retry" button. |
| **Toggle saving** | User changed a toggle; optimistic update in progress. | Toggle visually reflects new state instantly. No visible loading indicator. |
| **Toggle save error** | Firestore write failed. | Toggle reverts to previous state. `OBTSnackbar(message: "Could not update preference. Try again.", type: error)`. |

### Inputs and Validation

| Field | Type | Required | Validation Rule | Error Message |
|---|---|---|---|---|
| New Expenses toggle | `Switch` | -- | Boolean; no validation needed | N/A |
| Settlements toggle | `Switch` | -- | Boolean; no validation needed | N/A |
| Reminders toggle | `Switch` | -- | Boolean; no validation needed | N/A |

No explicit "Save" button. Each toggle auto-saves immediately via a Firestore `update()` to `users/{userId}.notificationPrefs.[field]`.

### Telemetry Events

| Event Name | Parameters | Trigger | SRS Reference |
|---|---|---|---|
| `notification_prefs_viewed` | -- | Screen opened | SRS section 5.10 |
| `notification_pref_changed` | `category` ("newExpense" / "settlement" / "reminder"), `enabled` (boolean) | Toggle changed and persisted | SRS section 5.10 |
| `notification_pref_error` | `category`, `error_code` | Toggle save fails | SRS section 5.10 |

### Accessibility

| Element | Semantic Label | Role |
|---|---|---|
| Page description | Readable as-is; announced after app bar title | `text` |
| New Expenses toggle | "New Expenses notifications, switch, [on/off]" | `switch` |
| Settlements toggle | "Settlements notifications, switch, [on/off]" | `switch` |
| Reminders toggle | "Reminders notifications, switch, [on/off]" | `switch` |

Description text beneath each toggle label serves as the accessibility hint. Toggle tap target meets minimum 48x48 dp (SRS section 5.6). Active track colour: `primary`. Inactive track colour: `disabled`. Thumb: white.

### Edge Cases

1. **Offline toggle change.** If the device is offline, the toggle updates queue locally. An `OBTSnackbar(message: "You are offline. Changes will sync when you reconnect.", type: info)` is shown on the first toggle change while offline. Subsequent offline toggles do not repeat the snackbar.
2. **Rapid toggle toggling.** If the user toggles the same switch multiple times in quick succession, the system should debounce writes (e.g., 500 ms delay) to avoid unnecessary Firestore operations. Only the final state is persisted.
3. **OS-level notification permissions denied.** If the user has disabled notifications at the OS level, the screen should display an info banner at the top: "Notifications are turned off for this app. Enable them in your device settings to receive alerts." with a "Open Settings" button that launches the OS notification settings for the app.

### Open Questions

1. **Per-group notification override.** Should users be able to mute notifications for a specific group (e.g., a very active group) without disabling the category globally? This may be a v1.1 feature.
2. **Toggle for reminders frequency.** The current spec offers a simple on/off for reminders. Should a future iteration allow configuring reminder frequency (daily, weekly)?
3. **Notification channel mapping (Android).** Should each toggle map to a separate Android notification channel, allowing the OS-level per-channel control to override the in-app setting?

---

## SCR-28: Contact Support and Account Deletion

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-28 |
| **Screen Name** | Contact Support and Account Deletion |
| **Purpose** | (A) Enable users to contact the support team via the device's default mail client, with diagnostic information pre-filled; provide a fallback dialog when no mail client is available. (B) Enable users to permanently delete their account via a multi-step confirmation flow with re-authentication. |
| **Route** | `/profile/support` (Contact Support -- no distinct route for happy path; dialog-based), `/profile/delete-account` (Account Deletion multi-step flow) |
| **SRS Requirements** | FR-SH-03 (P0), FR-SH-04 (P1), FR-AU-09 (P1) |
| **Core Screen** | Sub-flows of Core Screen 11 (SRS section 6.3, item 11) |

### Navigation

| Direction | Screens |
|---|---|
| **Reachable from** | Profile View (SCR-26) via "Contact Support" row and "Delete Account" row; Error states on any screen via "Contact Support" link (SRS section 6.4) |
| **Leads to** | Contact Support: external mail client (happy path) or dismissible fallback dialog (no mail client). Account Deletion: Phone Entry screen after successful deletion (navigation stack cleared). |

---

### Part A: Contact Support

#### Flow

Contact Support is not a screen but a flow triggered from the Profile View's "Contact Support" row or from any error state's "Contact Support" link. No separate route is pushed for the happy path.

1. User taps "Contact Support".
2. The app assembles a `mailto:` URL:
   - **To:** Support address from Firebase Remote Config (key: `support_email_address`).
   - **Body (pre-filled):**
     ```
     --- Diagnostic Info (do not delete) ---
     User ID: {userId}
     App Version: {appVersion}
     OS: {osName} {osVersion}
     Device: {deviceModel}
     ---
     ```
3. The app checks `canLaunchUrl(mailto:)`.
4. **If mail client available (happy path):** The device's default mail client opens. The user may edit the subject, body, or recipients before sending (FR-PR-05). No in-app UI renders.
5. **If no mail client (fallback, FR-SH-04):** The fallback dialog is displayed.

#### Fallback Dialog (FR-SH-04)

Displayed when `canLaunchUrl(mailto:)` returns `false`.

- **Dialog style:** `cornerRadiusLarge` (24 dp), surface background, dimmed scrim.
- **Title:** "No Mail App Found" (`titleMedium`, `textPrimary`).
- **Body:** "We could not open a mail app on your device. You can reach us at:" (`bodyMedium`, `textSecondary`).
- **Email address:** "[support@onebytwo.app]" (`bodyLarge`, `primary`, selectable text).
- **"Copy Address" button:** `primary` filled, `onPrimary` text. Writes the email address to system clipboard. On success: dialog dismisses, `OBTSnackbar(message: "Email address copied", type: info)` shown for 4000 ms.
- **"Close" button:** Outlined, `textSecondary`. Dismisses dialog.
- Scrim tap or back gesture: equivalent to "Close".

#### Remote Config Fallback

If the `support_email_address` key is missing or Remote Config fetch has failed, the app uses the compiled-in default address. The flow proceeds identically; no error UI is displayed.

#### Components Used (Contact Support)

| Component | Role |
|---|---|
| `OBTConfirmationDialog` (adapted) | Fallback dialog with copy button |
| `OBTSnackbar` | Copy confirmation |

#### States (Contact Support)

| State | Description | Visual Treatment |
|---|---|---|
| **Tapped (mail available)** | Mail client opens externally. | No in-app state change. |
| **Tapped (no mail client)** | Fallback dialog appears. | 200 ms fade-in per `OBTConfirmationDialog` motion. |
| **Copy pressed** | Clipboard write succeeded. | Dialog dismisses. `OBTSnackbar(type: info)`: "Email address copied". |
| **Close pressed** | User dismisses dialog. | 200 ms fade-out. |
| **Remote Config missing** | Silent fallback to default address. | No user-facing error. |
| **Clipboard write fails** | Rare platform failure. | `OBTSnackbar(type: error)`: "Could not copy. Please note the address above." Dialog remains open. |

#### Inputs and Validation (Contact Support)

No user inputs. The mailto URL is assembled programmatically from device metadata and Remote Config.

#### Telemetry Events (Contact Support)

| Event Name | Parameters | Trigger | SRS Reference |
|---|---|---|---|
| `support_email_opened` | `method` ("mailto" or "fallback_dialog") | Contact Support tapped | SRS section 5.10 |
| `support_email_copied` | -- | User copies address from fallback dialog | SRS section 5.10 |

#### Accessibility (Contact Support)

| Element | Semantic Label | Role |
|---|---|---|
| "Contact Support" row (Profile View) | "Contact Support, button" | `button` |
| Fallback dialog | "Alert: No Mail App Found" | `alertDialog` (modal focus trap) |
| Support email text | "Support email address: [address]" | `text` (selectable; screen reader can read character by character) |
| Copy Address button | "Copy Address, button" | `button` (announces "Email address copied" on success via snackbar live region) |
| Close button | "Close, button" | `button` |

#### Edge Cases (Contact Support)

1. **Remote Config fetch latency.** If Remote Config has not yet completed its initial fetch (e.g., app just installed, poor connectivity), the compiled-in default support address is used. The user experience is identical. A background fetch should be attempted for subsequent taps.
2. **Mail client crashes after launch.** The app has no control over external mail clients. If the mail client crashes or the user discards the email, no telemetry is captured. The user can retry by tapping "Contact Support" again.
3. **Multiple rapid taps.** The "Contact Support" row should be debounced (300 ms) to prevent launching the mail client multiple times or showing the fallback dialog twice.

---

### Part B: Account Deletion

#### Flow Overview

Account Deletion is a multi-step flow within a single full-screen route (`/profile/delete-account`), using an internal step controller. The bottom nav is hidden throughout.

```
Profile View
    |
    v
[Step A: Warning]
    |
    v  (user taps "Continue")
[Step B: Re-authentication]
    |
    v  (OTP verified)
[Step C: Final Confirmation]
    |
    v  (user types DELETE, taps "Delete My Account")
[Step D: Processing]
    |
    v  (Cloud Function completes)
[Step E: Success]
    |
    v
Phone Entry Screen (navigation stack cleared)
```

#### Components Used (Account Deletion)

| Component | Catalogue Section | Role |
|---|---|---|
| `OBTAppBar` | 1 | Step-specific titles and back navigation |
| `OBTPhoneInput` | 8 | Re-authentication phone display (read-only, pre-filled) |
| `OBTOTPInput` | 7 | OTP entry for re-authentication |
| `OBTSnackbar` | -- | Error feedback with Contact Support action |

#### Step A: Warning Screen

- **App bar:** `title: "Delete Account"`, `showBackButton: true`.
- **Warning icon:** 56 dp, `danger` colour.
- **Title:** "This will permanently delete your account" (`titleLarge`, `textPrimary`, centre-aligned).
- **Body paragraph 1:** "Your personal data, profile, and expense history will be permanently removed." (`bodyMedium`, `textSecondary`, centre-aligned).
- **Body paragraph 2:** "In shared groups, your name will be replaced with 'Deleted User' and your balances will be preserved for other members." (`bodyMedium`, `textSecondary`, centre-aligned).
- **Info banner:** `danger` at 12% opacity background, `danger` text, `cornerRadiusSmall`, 16 dp padding. Content: "This cannot be undone. Data is removed within 30 days of your request." (SRS section 5.5).
- **"Continue" button:** Full-width, `danger` filled, `textOnDanger`, `cornerRadiusSmall`.
- **"Cancel" button:** Full-width, outlined, `textSecondary`, `cornerRadiusSmall`. Navigates back to Profile View.

#### Step B: Re-authentication

- **App bar:** `title: "Verify Your Identity"`, `showBackButton: true` (returns to Step A).
- **Body:** "To protect your account, please verify your phone number before continuing." (`bodyMedium`, `textSecondary`, centre-aligned).
- **`OBTPhoneInput`:** Pre-filled with the authenticated user's phone number. Read-only.
- **"Send OTP" button:** Full-width, `primary` filled, `cornerRadiusSmall`.
- **After OTP sent:** `OBTOTPInput` appears. 30-second cooldown on resend (FR-AU-05). Auto-read on Android (FR-AU-04). Manual entry on iOS.
- **On successful verification:** Auto-advance to Step C.
- **On OTP error:** `OBTOTPInput` error state with message: "Incorrect code, try again."
- **Max retries exceeded (3 per 10-minute window, FR-AU-05):** `OBTSnackbar(type: error)` with message: "Too many attempts. Please try again later." Back button remains active.

#### Step C: Final Confirmation

- **App bar:** `title: "Confirm Deletion"`, `showBackButton: true` (returns to Step B).
- **Body:** "This is your last chance to change your mind." (`bodyMedium`, `textSecondary`, centre-aligned).
- **Label:** "Type DELETE to confirm" (`labelMedium`, `textSecondary`).
- **Text input:** `cornerRadiusSmall` outline border, uppercase, monospace font style. Placeholder: "DELETE".
- **"Delete My Account" button:** Full-width, `danger` filled, `textOnDanger`, `cornerRadiusSmall`. Disabled (`disabled` colour) until input matches exactly "DELETE" (case-sensitive, trimmed of leading/trailing whitespace).

#### Step D: Processing (Loading State)

- **App bar:** `title: "Deleting Account"`. No back button. System back gesture intercepted and ignored.
- **Circular progress indicator:** 56 dp, `primary` colour.
- **Body:** "Deleting your account..." (`bodyMedium`, `textSecondary`, centre-aligned).
- **Sub-body:** "This may take a moment." (`bodySmall`, `textTertiary`, centre-aligned).
- **Timeout:** If the Cloud Function `deleteUserAccount` does not respond within 30 seconds, the flow navigates back to Profile View with `OBTSnackbar(message: "Account deletion failed. Please try again or contact support.", type: error, actionLabel: "Contact Support", onAction: triggerContactSupportFlow)`.

#### Step E: Success

- **No app bar.** Full-screen success state.
- **Check circle icon:** 64 dp, `success` colour. Fades in with `motionStandard` (200 ms ease-in-out).
- **Title:** "Account deleted" (`titleLarge`, `textPrimary`, centre-aligned).
- **Body:** "Your data will be fully removed within 30 days." (`bodyMedium`, `textSecondary`, centre-aligned).
- Displayed for 3000 ms. After 3 seconds, the navigation stack is cleared and the user is taken to the Phone Entry screen (SRS section 6.3, item 2). No back navigation is possible.

#### States (Account Deletion)

| Step | State | Behaviour | Back Navigation |
|---|---|---|---|
| A (Warning) | Default | Warning copy displayed. Continue and Cancel active. | Back to Profile View. |
| A | Cancel pressed | Navigate back to Profile View. | -- |
| A | Continue pressed | Advance to Step B. | -- |
| B (Re-auth) | Default | Phone pre-filled. "Send OTP" button active. | Back to Step A. |
| B | OTP sent | `OBTOTPInput` appears. 30-second cooldown on resend. | Back to Step A. |
| B | OTP error | `OBTOTPInput` error state. User can retry. | Back to Step A. |
| B | OTP verified | Auto-advance to Step C. | -- |
| B | Max retries exceeded | `OBTSnackbar(type: error)`. Back button remains active. | Back to Step A. |
| C (Confirm) | Default | Text input empty. Delete button disabled. | Back to Step B. |
| C | Input matches "DELETE" | Delete button enabled (`danger` fill). | Back to Step B. |
| C | Delete pressed | Advance to Step D. | -- |
| D (Processing) | Loading | Progress indicator. No back button. | Blocked. |
| D | Error / timeout | Navigate to Profile View. Error snackbar with Contact Support action. | -- |
| E (Success) | Shown | 3-second display, then navigate to Phone Entry. | Blocked. |

#### Inputs and Validation (Account Deletion)

| Field | Type | Required | Validation Rule | Error Message |
|---|---|---|---|---|
| Phone number (Step B) | `OBTPhoneInput` | N/A (read-only) | Pre-filled from authenticated session | N/A |
| OTP (Step B) | `OBTOTPInput` | Yes | Exactly 6 digits | "Incorrect code, try again." |
| OTP (Step B) | `OBTOTPInput` | Yes | Max 3 retries per 10-minute window (FR-AU-05) | "Too many attempts. Please try again later." |
| Confirmation text (Step C) | Text input | Yes | Exact match: "DELETE" (case-sensitive, trimmed) | Button remains disabled; no explicit error message until submission attempt. |

#### Telemetry Events (Account Deletion)

| Event Name | Parameters | Trigger | SRS Reference |
|---|---|---|---|
| `delete_account_started` | -- | User taps "Delete Account" row on Profile View | SRS section 5.10 |
| `delete_account_warning_continued` | -- | User taps "Continue" on Step A | SRS section 5.10 |
| `delete_account_warning_cancelled` | -- | User taps "Cancel" on Step A | SRS section 5.10 |
| `delete_account_reauth_completed` | -- | OTP verified in Step B | SRS section 5.10 |
| `delete_account_confirmed` | -- | User taps "Delete My Account" in Step C | SRS section 5.10 |
| `delete_account_completed` | -- | Cloud Function returns success | SRS section 5.10 |
| `delete_account_failed` | `error_code` | Cloud Function returns error or times out | SRS section 5.10 |

#### Accessibility (Account Deletion)

| Element | Semantic Label | Role |
|---|---|---|
| Warning icon (Step A) | "Warning" | `image` |
| Info banner (Step A) | "Important: This cannot be undone. Data is removed within 30 days of your request." | `text` (announced as group) |
| Continue button (Step A) | "Continue with account deletion, button" | `button` |
| Cancel button (Step A) | "Cancel, button" | `button` |
| Phone input (Step B) | Per `OBTPhoneInput` spec; pre-filled; announced as read-only | `textField` |
| OTP input (Step B) | Per `OBTOTPInput` spec | `textField` |
| Confirmation input (Step C) | "Type DELETE to confirm, text field" | `textField` |
| Delete button (Step C) | "Delete My Account, button" or "Delete My Account, button, disabled" | `button` |
| Progress indicator (Step D) | "Deleting your account, please wait" (live region) | -- |
| Success icon (Step E) | "Account deleted successfully" (announced once) | `image` |

#### Edge Cases (Account Deletion)

1. **Outstanding balances at time of deletion.** The SRS (FR-AU-09) specifies that the Cloud Function anonymises data in shared groups and removes personal records within 30 days. However, if the user has non-zero simplified balances, the deletion should still proceed -- the `simplifiedBalances` for other group members are preserved with the deleted user shown as "Deleted User". The warning copy in Step A covers this scenario.
2. **OTP delivery failure.** If the SMS is not delivered (carrier issue), the user can retry up to 3 times within the 10-minute window (FR-AU-05). After exhausting retries, the user must wait and try again later. No alternative verification method is available in v1.0.
3. **Network loss during Step D (Processing).** If connectivity is lost while the Cloud Function is executing, the app waits until the 30-second timeout, then navigates to Profile View with the error snackbar. The Cloud Function may still complete server-side; on next login attempt, the user will discover their account has been deleted. This is an acceptable eventual-consistency trade-off.
4. **User force-quits app during Step D.** The Cloud Function continues executing server-side. On next app launch, if the account has been deleted, Firebase Auth returns an authentication error and the user sees the Phone Entry screen.

#### Open Questions (Account Deletion)

1. **Grace period for undoing deletion.** The SRS specifies data removal within 30 days. Should there be a mechanism for the user to contact support and reverse the deletion within a shorter window (e.g., 7 days)?
2. **Deletion confirmation email/SMS.** Should the app send a confirmation SMS to the user's phone number after successful deletion, confirming the request and the 30-day timeline?
3. **Deletion audit log.** Should the deletion event be logged in a separate admin-facing audit collection (beyond Crashlytics/Analytics) for compliance purposes?

---

## Cross-Reference Matrix

| Screen | SRS Requirement | Priority | Components Used |
|---|---|---|---|
| SCR-23: Settle Up | FR-SE-05, FR-SE-06, FR-SE-07 | P0, P0, P0 | `OBTAppBar`, `OBTUserAvatar`, `OBTAmountInput`, `OBTBalancePill`, `OBTSnackbar` |
| SCR-24: Settlement History | FR-SE-08 | P0 | `OBTAppBar`, `OBTUserAvatar`, `OBTRupeeText`, `OBTSkeletonLoader`, `OBTEmptyState`, `OBTErrorState` |
| SCR-25: Activity Feed | FR-AC-01, FR-AC-02 | P0, P0 | `OBTAppBar`, `OBTBottomNav`, `OBTFloatingActionButton`, `OBTActivityRow`, `OBTRupeeText`, `OBTEmptyState`, `OBTErrorState`, `OBTSkeletonLoader`, `OBTSnackbar` |
| SCR-26: Profile View/Edit | FR-PR-01, FR-PR-04, FR-PR-05, FR-AU-08 | P0, P0, P0, P0 | `OBTAppBar`, `OBTBottomNav`, `OBTUserAvatar`, `OBTConfirmationDialog`, `OBTSkeletonLoader`, `OBTErrorState`, `OBTSnackbar` |
| SCR-27: Notification Preferences | FR-PR-03 | P1 | `OBTAppBar`, `OBTSkeletonLoader`, `OBTErrorState`, `OBTSnackbar` |
| SCR-28: Contact Support | FR-SH-03, FR-SH-04 | P0, P1 | `OBTConfirmationDialog` (adapted), `OBTSnackbar` |
| SCR-28: Account Deletion | FR-AU-09 | P1 | `OBTAppBar`, `OBTPhoneInput`, `OBTOTPInput`, `OBTSnackbar` |

---

## Invariant Compliance

| Invariant | Compliance Notes |
|---|---|
| **1. Money is integer paise.** | SCR-23 (Settle Up) accepts and transmits all amounts as integer paise. `OBTAmountInput` outputs paise; `OBTRupeeText` converts at the UI layer. SCR-24 (Settlement History) displays amounts via `OBTRupeeText` from paise. SCR-25 (Activity Feed) trailing amounts are paise-sourced. |
| **2. `simplifiedBalances` is server-maintained and client-read-only.** | SCR-23 reads `simplifiedBalances` for pre-fill and confirmation display; never writes to it. The `recomputeSimplifiedBalances` Cloud Function writes on settlement recording. |
| **3. System share sheet only.** | No sharing flows in these six screens. Contact Support uses `mailto:` URL, not a share sheet. No specific messaging app is targeted. |
| **4. Single Firebase project.** | All Firestore reads/writes, Remote Config reads, and Cloud Function invocations target the single production Firebase project. |

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2025-07-15 | UX/UI Designer | Initial draft -- six screens (SCR-23 to SCR-28) covering Settle Up, Settlement History, Activity Feed, Profile View/Edit, Notification Preferences, Contact Support and Account Deletion. |