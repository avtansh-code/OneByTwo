# Friends Flow -- Screen Specifications

> Detailed screen-level specifications for the Friends feature flow in One By Two v1.0.
> Derived from SRS sections 4.3, 4.11, 5.6, 5.10, 6.3, 6.4, and 6.5.

| Field | Value |
|---|---|
| Document version | 1.0 |
| Status | Draft -- pending PM, Flutter Dev, and QA review |
| Author | UX/UI Designer Agent |
| SRS baseline | v1.1 |
| Last updated | 2025-07-12 |

> **Implementation status (verified against `lib/`, this pass).** SCR-09 List, SCR-10 Add Friend (incl. Match-and-Invite via `share_plus`), SCR-11 Detail implemented. **SCR-12 Delete Friend not implemented.**

---

## Table of Contents

1. [SCR-09: Friends List](#scr-09-friends-list)
2. [SCR-10: Add Friend](#scr-10-add-friend)
3. [SCR-11: Friend Detail](#scr-11-friend-detail)
4. [SCR-12: Delete Friend Dialog](#scr-12-delete-friend-dialog)

---

## SCR-09: Friends List

### Overview

| Field | Value |
|---|---|
| Screen ID | SCR-09 |
| Screen Name | Friends List |
| Purpose | Display all of the current user's friends with their net simplified balance, enabling navigation to individual friend details and friend-addition. |
| Route | `/friends` (tab root, bottom navigation index 1) |
| SRS Requirements | FR-FR-03 (friends list with net balance); FR-FR-04 (entry point to per-friend history); FR-SE-01 (simplified debts as canonical view); section 6.3 screen 6; section 6.4 (empty, loading, error states); section 5.6 (tap targets, contrast, screen reader). |

### Navigation

| Direction | Target |
|---|---|
| **Reachable from** | `OBTBottomNav` tab index 1 (any authenticated screen); Home Dashboard top-5 friends row (deep link). |
| **Leads to** | SCR-10 Add Friend (tap `+` action or empty-state CTA); SCR-11 Friend Detail (tap a friend row); Search overlay (tap search icon). |

### Components Used

| Component | Catalogue Ref | Usage |
|---|---|---|
| `OBTAppBar` | 1 | Title "Friends"; trailing actions: Search, Add (`+`). |
| `OBTBottomNav` | 2 | Tab bar with index 1 active. |
| `OBTFloatingActionButton` | 3 | Persistent FAB for Add Expense (FR-HD-04). |
| `OBTSearchBar` | 23 | Inline search below app bar, filters friend list by display name. |
| `OBTFriendListTile` | 16 | One tile per friend; avatar, name, `OBTBalancePill`. |
| `OBTBalancePill` | 4 | Trailing pill on each tile; colour-coded credit/debit/settled. |
| `OBTEmptyState` | 18 | Shown when the user has zero friends. |
| `OBTErrorState` | 19 | Shown on Firestore or network failure. |
| `OBTSkeletonLoader` | 20 | Shimmer rows while data loads. |

### States

| # | State | Trigger | Visual | Behaviour |
|---|---|---|---|---|
| 1 | **Loading** | Firestore snapshot listener has not yet delivered the first result. | `OBTSkeletonLoader(type: listTile, itemCount: 5)` shimmer rows in the list area. App bar and bottom nav remain visible and interactive. | Transition to Populated or Empty on data arrival with a 200 ms fade-in (SRS section 6.2 motion). |
| 2 | **Populated** | Firestore returns one or more friendship documents. | Scrollable list of `OBTFriendListTile` rows, sorted by `lastActivityAt` descending. Each tile shows avatar, display name, and `OBTBalancePill`. | Tapping a row navigates to SCR-11 Friend Detail. Balance values are read from `simplifiedBalances` (Invariant 2) and converted from integer paise to rupees at the UI layer (Invariant 1). |
| 3 | **Empty** | Firestore query returns zero documents. | `OBTEmptyState` centred in the list area. Title: "No friends yet". Subtitle: "Add a friend and start sharing expenses." CTA button: "Add Friend" (navigates to SCR-10). Illustration is decorative (`excludeSemantics: true`). | CTA navigates to `/friends/add`. |
| 4 | **Error** | Firestore read failure or network error. | `OBTErrorState` centred in the list area. Title: "Something went wrong". Subtitle: "We could not load your friends list. Please try again." Retry button and "Contact Support" link. | Retry re-triggers the Firestore snapshot listener. "Contact Support" opens the support flow (FR-SH-03). |
| 5 | **Search active** | User taps the search icon in the app bar. | `OBTSearchBar` appears inline below the app bar. List filters in real time by case-insensitive substring match against `displayName`. | If no matches: centred inline text "No friends match your search" (not a full `OBTEmptyState`). Clear button dismisses search and restores the full list. |
| 6 | **Refreshing** | Pull-to-refresh gesture on the populated list. | A platform-standard refresh indicator appears at the top of the list; existing rows remain visible. | The Firestore listener is re-established. Indicator dismisses on data arrival. |

### Inputs and Validation

| Input | Validation Rule | Error Message | SRS Ref |
|---|---|---|---|
| Search query (text) | No formal validation; empty query shows the full list. Minimum 1 character to begin filtering. | N/A (no error state; simply shows "No friends match your search" when results are empty). | Section 6.4 |

### Telemetry Events

| Event Name | Trigger | Parameters | SRS Ref |
|---|---|---|---|
| `friends_list_viewed` | Screen becomes visible. | `friend_count: int` | Section 5.10 |
| `friends_search_used` | User types at least 1 character into the search bar. | `query_length: int` | Section 5.10 |
| `friend_row_tapped` | User taps a friend list tile. | `friendship_id: String` | Section 5.10 |
| `friends_empty_add_tapped` | User taps the "Add Friend" CTA in the empty state. | None | Section 5.10 |

### Accessibility

| Aspect | Specification | SRS Ref |
|---|---|---|
| Screen title | Announced as heading: "Friends". `Semantics(header: true)` on the app bar title. | Section 5.6 |
| Friend list tile | Semantic label: "[Display name], [balance pill text]" (e.g., "Priya Sharma, you are owed rupees 1,250.00"). Avatar excluded from semantics. | Section 5.6; component 16 spec |
| Search bar | Label: "Search friends". | Section 5.6; component 23 spec |
| Empty state illustration | `excludeSemantics: true` (decorative). | Section 5.6 |
| Tap targets | All interactive elements meet 48x48 dp (Android) / 44x44 pt (iOS) minimum. Each `OBTFriendListTile` has a minimum height of 56 dp. | Section 5.6 |
| Contrast | Body text and balance pill text meet WCAG 2.1 AA ratio (4.5:1 minimum). | Section 5.6 |
| Focus order | App bar title, search icon, add icon, friend list (top to bottom), bottom nav (left to right), FAB. | Section 5.6 |
| Announcements | On data load: "[N] friends loaded" (screen reader only). On search filter: "[N] results" (live region). | Section 5.6 |

### Edge Cases

1. **User has exactly one friend with a zero balance.** The list renders a single `OBTFriendListTile` with the "settled up" pill in muted colour. The empty state must not be shown; the threshold is zero documents, not zero active balances.
2. **Rapid tab switching.** If the user taps away from the Friends tab and returns quickly, the Firestore listener should not be re-created unnecessarily. The previously loaded data should remain visible to avoid a flash of skeleton loaders.
3. **Very long display name.** Names exceeding the available horizontal space must be truncated with an ellipsis. The `OBTBalancePill` must never be pushed off-screen; the name text is the flexible element.
4. **Offline with cached data.** If the device is offline but Firestore persistence has cached friendship documents, the list should render from cache. No error state should appear unless the cache is also empty.

### Open Questions

1. Should the list support grouping or sectioning (e.g., "You are owed" / "You owe" / "Settled up") in a future iteration, or remain a flat reverse-chronological list?
2. Should pull-to-refresh be supported given that Firestore snapshot listeners provide real-time updates, or is it redundant?
3. Is there a maximum number of friends to support before pagination or virtual scrolling becomes necessary?

---

## SCR-10: Add Friend

### Overview

| Field | Value |
|---|---|
| Screen ID | SCR-10 |
| Screen Name | Add Friend |
| Purpose | Allow the user to add a friend by selecting a device contact or entering a +91 mobile number manually, linking existing One By Two users immediately or inviting non-users via the system share sheet. |
| Route | `/friends/add` |
| SRS Requirements | FR-FR-01 (add friend via contact picker or manual +91 entry); FR-FR-02 (link existing user or invite via system share sheet); FR-SH-01 (system share sheet only -- Invariant 3); FR-SH-02 (deep link with install fallback URL); section 5.6; section 6.4; section 6.5. |

### Navigation

| Direction | Target |
|---|---|
| **Reachable from** | SCR-09 Friends List (`+` action or empty-state CTA); Home Dashboard (if a shortcut is provided). |
| **Leads to** | SCR-11 Friend Detail (on successful add of an existing user); System Share Sheet (on invite of a non-user; Invariant 3); SCR-09 Friends List (on back/cancel or after share sheet dismissal). |

### Components Used

| Component | Catalogue Ref | Usage |
|---|---|---|
| `OBTAppBar` | 1 | Title "Add Friend"; leading back button. |
| `OBTContactPicker` | 9 | Path A: device contact list with search and "on One By Two" badges. |
| `OBTPhoneInput` | 8 | Path B: manual +91 number entry. |
| `OBTSearchBar` | 23 | Within `OBTContactPicker` for filtering contacts. |
| `OBTSnackbar` | 25 | Success confirmation on friend addition. |
| `OBTConfirmationDialog` | 24 | Invite prompt for non-One By Two contacts. |
| `OBTEmptyState` | 18 | No contacts found (Path A). |
| `OBTSkeletonLoader` | 20 | While device contacts are loading. |

### States

| # | State | Trigger | Visual | Behaviour |
|---|---|---|---|---|
| 1 | **Loading (contacts)** | Device contacts are being read. | `OBTSkeletonLoader(type: listTile, itemCount: 8)` in the contact list area. Segmented control and app bar remain visible. | Transitions to Populated or Empty on data arrival. |
| 2 | **Populated (contacts)** | Device returns one or more contacts. | Full contact list with alphabetical section headers and `OBTSearchBar`. Contacts matching existing One By Two users show an "on One By Two" chip. | Tapping an existing user creates the friendship immediately and navigates to SCR-11. Tapping a non-user shows the invite confirmation dialog. |
| 3 | **Empty (no contacts)** | Device returns zero contacts. | `OBTEmptyState` in the contact list area. Title: "No contacts found". Subtitle: "You can enter a number manually." No CTA button (the "Enter Number" tab is the alternative). | User must switch to the "Enter Number" path. |
| 4 | **Contact Permission Denied** | User denies contact access. | The contact picker is hidden. The screen shows a fallback UI with a text field for manual phone number entry (`+91` prefix, same validation as the phone-entry screen), a "Try Again" button that re-requests contact permission, and a brief explanation: "Contact access helps you find friends already on One By Two." | The manual-entry fallback remains usable whilst the user decides whether to retry permission. Telemetry: `contact_permission_denied` fires on denial. |
| 5 | **Validation error (manual)** | User submits an invalid phone number in Path B. | `OBTPhoneInput` in error state with `errorText` below the field. "Add Friend" button remains enabled for retry. | See Inputs and Validation table below. |
| 6 | **Looking up number** | User taps "Add Friend" in Path B with a valid number. | "Add Friend" button shows a loading indicator. Input field is disabled. | Brief state while the app queries Firestore for the phone number. Transitions to friend creation or invite prompt. |

### Inputs and Validation

| Input | Validation Rule | Error Message | SRS Ref |
|---|---|---|---|
| Phone number (manual entry) | Must be exactly 10 digits. | "Please enter a valid 10-digit mobile number." | FR-FR-01; FR-AU-02 (reused validation rules) |
| Phone number (manual entry) | Must start with 6, 7, 8, or 9. | "Please enter a valid Indian mobile number." | FR-AU-02 |
| Phone number (manual entry) | Must not be the user's own number. | "You cannot add yourself as a friend." | Logical constraint |
| Phone number (manual entry) | Must not already be an existing friend. | "You are already friends with [Display name]." | Logical constraint |

### Telemetry Events

| Event Name | Trigger | Parameters | SRS Ref |
|---|---|---|---|
| `add_friend_screen_viewed` | Screen becomes visible. | `entry_path: "contacts" or "manual"` (initial tab) | Section 5.10 |
| `friend_added` | Friendship document is successfully created. | `method: "contacts" or "manual"`, `target_is_existing_user: bool` | Section 5.10 |
| `friend_invite_sent` | System share sheet is opened for a non-user invite. | `method: "contacts" or "manual"` | Section 5.10 |
| `contact_permission_denied` | User denies contact permission. | None | Section 5.10 |

### Accessibility

| Aspect | Specification | SRS Ref |
|---|---|---|
| Screen title | Announced as heading: "Add Friend". | Section 5.6 |
| Segmented control | Announces "From Contacts, selected" or "Enter Number, selected" on focus/change. | Section 5.6 |
| Contact list items | Each row announces: "[Name], [phone number], [on One By Two / not on One By Two]". | Section 5.6; component 9 spec |
| Phone input | Label: "Phone number, India country code plus 91". Error state announces the error text. | Section 5.6; component 8 spec |
| "Add Friend" button | Label: "Add friend". | Section 5.6 |
| Invite dialog | Modal announced: "Alert: Invite [Name]?". Body text read after title. Focus trapped within dialog. | Section 5.6; component 24 spec |
| Tap targets | All interactive elements meet 48x48 dp minimum. | Section 5.6 |
| Focus order | App bar back button, app bar title, segmented control ("From Contacts" then "Enter Number"), search bar or phone input (depending on active tab), contact list / Add Friend button, back. | Section 5.6 |
| Announcements | On friend added: screen reader announces "[Name] added as a friend" (via snackbar). On invite sent: "Invite sent" (live region). On validation error: error message announced. | Section 5.6 |

### Edge Cases

1. **User selects a contact with multiple phone numbers.** The app should display all +91 numbers for that contact and allow the user to choose which one to use. Non-Indian numbers should be filtered out silently.
2. **Contact permission revoked mid-session.** If the user navigates to device settings and revokes permission while the Add Friend screen is still mounted, the app should detect the change on resume and transition to the Contact Permission Denied state.
3. **Duplicate friendship attempt.** If the user tries to add someone who is already a friend (via either path), the app must show the inline error "You are already friends with [Display name]" and must not create a duplicate friendship document.
4. **Share sheet dismissed without sharing.** If the user opens the system share sheet for an invite but dismisses it without selecting a channel, the app should return to the Add Friend screen with no snackbar or confirmation. The non-user is not marked as invited.

### Open Questions

1. Should the invite prompt display a preview of the share message text before opening the system share sheet?
2. When a non-user contact is invited, should the contact be shown in a "Pending Invites" section on the Friends List, or simply disappear until they register?
3. Should the "From Contacts" path request permission lazily (on first switch to that tab) or eagerly (on screen mount)?

---

## SCR-11: Friend Detail

### Overview

| Field | Value |
|---|---|
| Screen ID | SCR-11 |
| Screen Name | Friend Detail |
| Purpose | Display the full profile header, net simplified balance, Settle Up CTA (when balance is non-zero), and recent expense history for a single friend. |
| Route | `/friends/:friendshipId` |
| SRS Requirements | FR-FR-03 (net balance per friend); FR-FR-04 (per-friend transaction history, reverse chronological); FR-SE-01 (simplified debts only); FR-SE-07 (Settle Up CTA on every screen with non-zero balance); FR-FR-05 (delete friend entry point via overflow menu); section 6.3 screen 6; section 6.4; section 5.6. |

### Navigation

| Direction | Target |
|---|---|
| **Reachable from** | SCR-09 Friends List (tap a friend row); SCR-10 Add Friend (on successful add); Home Dashboard (tap a friend in the top-5 list). |
| **Leads to** | Settle Up flow (tap Settle Up CTA in `OBTSettleUpCard`); Expense Detail (tap an expense row); Friend History `/friends/:friendshipId/history` (tap "View full history"); SCR-12 Delete Friend Dialog (tap "Delete Friend" in overflow menu -- **deferred with SCR-12 / FR-FR-05; not present in the shipped app bar**); SCR-09 Friends List (back navigation). |

### Components Used

| Component | Catalogue Ref | Usage |
|---|---|---|
| `OBTAppBar` | 1 | Title: friend's display name; leading back button; trailing overflow menu (three-dot icon) -- **deferred (FR-FR-05): the shipped app bar has no overflow menu; ships with SCR-12 Delete Friend**. |
| `OBTUserAvatar` | 11 | Large variant (80 dp) centred in the profile header. |
| `OBTBalancePill` | 4 | Large variant below the avatar; colour-coded balance. |
| `OBTSettleUpCard` | 13 | Pre-filled settlement card; rendered only when `balancePaise != 0`. |
| `OBTExpenseListTile` | 15 | Up to 5 recent expenses in the "Recent Expenses" section. |
| `OBTEmptyState` | 18 | Shown in the expense area when there are no shared expenses. |
| `OBTErrorState` | 19 | Full-screen error below the app bar on data load failure. |
| `OBTSkeletonLoader` | 20 | Profile header skeleton and expense list skeleton. |

### States

| # | State | Trigger | Visual | Behaviour |
|---|---|---|---|---|
| 1 | **Loading** | Friendship and expense data are being fetched. | Profile header: `OBTSkeletonLoader(type: profileHeader)`. Expense list: `OBTSkeletonLoader(type: listTile, itemCount: 3)`. App bar shows the friend's name if available from the navigation argument. | Transitions to Populated or Error on data arrival. |
| 2 | **Populated (non-zero balance)** | Friendship data loaded; `simplifiedBalances` indicates a non-zero value. | Full layout: avatar, name, `OBTBalancePill`, `OBTSettleUpCard`, and up to 5 recent `OBTExpenseListTile` rows. "View full history" text link right-aligned above expense rows. | `OBTSettleUpCard` pre-fills the settlement amount from the simplified balance (FR-SE-05). Tapping the CTA opens the Settle Up flow. |
| 3 | **Populated (settled up)** | Friendship data loaded; `simplifiedBalances` is zero. | Full layout without `OBTSettleUpCard`. `OBTBalancePill` shows "settled up" in muted `onSurface` colour. | Settle Up CTA hidden per FR-SE-07 (only shown for non-zero). Overflow menu still offers "Delete Friend" (FR-FR-05 -- deletion is permitted at zero balance) -- **deferred with SCR-12: the overflow menu and Delete Friend entry point are not in the shipped app bar**. |
| 4 | **No expenses** | Friendship data loaded; expense query returns zero documents. | Profile header and balance pill render normally. Expense area shows `OBTEmptyState`. Title: "No expenses yet". Subtitle: "Add an expense with [Friend name] to start tracking." CTA: "Add Expense" (opens the Add Expense flow with this friend pre-selected). | Balance pill may show a non-zero value if a settlement was recorded without expenses (edge case). |
| 5 | **Error** | Firestore read failure or network error. | `OBTErrorState` replaces the entire content area below the app bar. Title: "Something went wrong". Subtitle: "We could not load this friend's details. Please try again." Retry button and "Contact Support" link. | Retry re-fetches friendship and expense data. |
| 6 | **Settling (transient)** | User taps Settle Up CTA and the Settle Up flow is in progress. | `OBTSettleUpCard` CTA button shows a loading indicator; card becomes non-interactive. | On settlement completion, balance updates in real time via the Firestore listener and the `OBTSettleUpCard` either updates its amount or disappears (if fully settled). |

### Inputs and Validation

| Input | Validation Rule | Error Message | SRS Ref |
|---|---|---|---|
| `friendshipId` (route parameter) | Must be a valid, non-empty Firestore document ID that the current user has access to. | If invalid or inaccessible: navigate to SCR-09 Friends List and show `OBTSnackbar(type: error, message: "Friend not found.")`. | Section 6.4 |

### Telemetry Events

| Event Name | Trigger | Parameters | SRS Ref |
|---|---|---|---|
| `friend_detail_viewed` | Screen becomes visible. | `friendship_id: String`, `balance_state: "owed" or "owes" or "settled"` | Section 5.10 |
| `settle_up_tapped` | User taps the Settle Up CTA. | `friendship_id: String`, `amount_paise: int` | Section 5.10 |
| `friend_history_tapped` | User taps "View full history". | `friendship_id: String` | Section 5.10 |
| `friend_delete_menu_tapped` | User taps "Delete Friend" in the overflow menu. | `friendship_id: String` | Section 5.10 |

### Accessibility

| Aspect | Specification | SRS Ref |
|---|---|---|
| Screen title | Friend's display name announced as heading. | Section 5.6 |
| Profile avatar | 80 dp avatar is decorative when adjacent to the name text (`excludeSemantics: true`). | Section 5.6; component 11 spec |
| Balance pill | Semantic label per component 4 spec: "Balance: you are owed rupees [amount]" / "Balance: you owe rupees [amount]" / "Balance: settled up". | Section 5.6 |
| Settle Up card | Semantic label: "[Payer name] owes [Payee name] rupees [amount]. Settle up button available." CTA button label: "Settle up, rupees [amount]". | Section 5.6; component 13 spec |
| Overflow menu icon | Label: "More options". | Section 5.6 |
| "View full history" link | Label: "View full history with [Friend name]". | Section 5.6 |
| Expense list tiles | Per component 15 spec: "[Description], [category], paid by [payer], [date], your share: [you lent / you borrowed] rupees [amount]". | Section 5.6 |
| Tap targets | All interactive elements meet 48x48 dp minimum. Expense tiles have a minimum height of 64 dp. | Section 5.6 |
| Focus order | App bar back button, app bar title (heading), overflow menu, avatar (skipped -- decorative), display name, balance pill, settle up card (if present), settle up button, "View full history" link, expense list tiles (top to bottom). | Section 5.6 |
| Announcements | On balance update (real-time): "Balance updated" (live region). On settle up completion: "Settlement recorded" (via snackbar). | Section 5.6 |

### Edge Cases

1. **Friendship document deleted by the other user while this screen is open.** The Firestore listener should detect the deletion and navigate the user back to SCR-09 Friends List with `OBTSnackbar(type: info, message: "This friendship is no longer available.")`.
2. **Balance updates in real time while viewing.** If another expense or settlement is recorded by the friend, the `simplifiedBalances` field updates via the listener. The `OBTBalancePill` and `OBTSettleUpCard` must animate to their new values (200 ms ease-in-out) rather than snapping abruptly.
3. **Deep link with an invalid `friendshipId`.** If the user arrives via a deep link or stale navigation state with a `friendshipId` that does not exist or is inaccessible, the screen should show `OBTSnackbar(type: error, message: "Friend not found.")` and navigate back to SCR-09.
4. **Friend has expenses in both friend and group contexts.** The "Recent Expenses" section on this screen should show only expenses in the 1-to-1 friend context, not group expenses that happen to involve the same person. Group expenses appear on the respective Group Detail screen.

### Open Questions

1. Should the "Recent Expenses" section be limited to 5 items, or should it be configurable (e.g., via Remote Config)?
2. Should the overflow menu contain additional options beyond "Delete Friend" in future iterations (e.g., "Send Reminder" per FR-SE-09, "Mute Notifications")?
3. Should the screen support a "Send Reminder" action inline (FR-SE-09 is P1) or is that deferred entirely to a later sprint?

---

## SCR-12: Delete Friend Dialog

### Overview

| Field | Value |
|---|---|
| Screen ID | SCR-12 |
| Screen Name | Delete Friend Dialog |
| Purpose | Confirm friend deletion when the simplified balance is zero, or inform the user that deletion is blocked due to an outstanding balance. |
| Route | N/A -- modal dialog overlay; no dedicated route. Triggered from the overflow menu on SCR-11 Friend Detail. |
| SRS Requirements | FR-FR-05 (delete friend only if balance is zero); FR-SE-01 (simplified debts as canonical balance); section 6.4 (error states with actionable copy); section 6.5 (microcopy tone); Invariant 1 (balance displayed in rupees, stored as paise); Invariant 2 (`simplifiedBalances` is client-read-only). |

### Navigation

| Direction | Target |
|---|---|
| **Reachable from** | SCR-11 Friend Detail (overflow menu "Delete Friend" action). |
| **Leads to** | SCR-09 Friends List (on successful deletion, with success snackbar); SCR-11 Friend Detail (on cancel or dismiss of the blocked-deletion variant). |

### Components Used

| Component | Catalogue Ref | Usage |
|---|---|---|
| `OBTConfirmationDialog` | 24 | Dialog container with title, body, and action buttons. `isDestructive: true` for the zero-balance variant. |
| `OBTSnackbar` | 25 | Success snackbar on deletion; error snackbar on failure. |

### States

| # | State | Trigger | Visual | Behaviour |
|---|---|---|---|---|
| 1 | **Zero balance -- confirmation** | User taps "Delete Friend" and `simplifiedBalances` for this friendship is zero. | `OBTConfirmationDialog` with `isDestructive: true`. Title: "Delete Friend?". Body: "Are you sure you want to remove [Friend name] from your friends? This will not delete any shared expenses." Cancel button (left). Delete button in `danger` colour (right). Corner radius 24 dp. | Cancel dismisses the dialog and returns to SCR-11. Delete triggers the Firestore deletion. |
| 2 | **Non-zero balance -- blocked** | User taps "Delete Friend" and `simplifiedBalances` is non-zero. | Modified dialog (single button). Title: "Cannot Delete Friend". Body: "You have an outstanding balance of [formatted amount] with [Friend name]. Please settle up before removing this friend." Single "OK" button in `primary` colour. | "OK" dismisses the dialog. No delete action is available. The balance amount is formatted using Indian numbering (Invariant 1). |
| 3 | **Deleting (loading)** | User taps "Delete" in the zero-balance confirmation. | Delete button shows a small progress indicator. Both Cancel and Delete buttons are disabled. Dialog remains on screen. | Brief transient state while the Firestore delete completes. |
| 4 | **Delete success** | Firestore deletion completes successfully. | Dialog dismisses. Navigation returns to SCR-09 Friends List. `OBTSnackbar(type: success, message: "[Friend name] removed from friends")` appears. | Snackbar auto-dismisses after 4 seconds. |
| 5 | **Delete failed** | Firestore deletion fails (network error, permission error). | Dialog dismisses. `OBTSnackbar(type: error, message: "Could not remove friend. Please try again.")` appears on SCR-11 Friend Detail. | Snackbar auto-dismisses after 4 seconds. User can retry from the overflow menu. |
| 6 | **Dismissed** | User taps outside the dialog, presses Back, or presses Escape. | Dialog dismisses with a 200 ms fade-out. | Equivalent to tapping "Cancel" (zero-balance variant) or "OK" (non-zero variant). No action taken. |

### Inputs and Validation

| Input | Validation Rule | Error Message | SRS Ref |
|---|---|---|---|
| Balance check | `simplifiedBalances` for the friendship must be exactly zero for deletion to proceed. Client reads this value (Invariant 2); server enforces via security rules. | "You have an outstanding balance of [amount] with [Friend name]. Please settle up before removing this friend." | FR-FR-05 |
| Server-side enforcement | Even if the client somehow bypasses the zero-balance check, the Cloud Function or Firestore security rules must reject the deletion. | Client receives a permission error; displayed as: "Could not remove friend. Please try again." | FR-FR-05; Invariant 2 |

### Telemetry Events

| Event Name | Trigger | Parameters | SRS Ref |
|---|---|---|---|
| `friend_delete_dialog_shown` | Dialog becomes visible. | `friendship_id: String`, `balance_state: "zero" or "non_zero"` | Section 5.10 |
| `friend_deleted` | Friendship document is successfully deleted. | `friendship_id: String` | Section 5.10 |
| `friend_delete_blocked` | Non-zero balance dialog is shown. | `friendship_id: String`, `balance_paise: int` | Section 5.10 |
| `friend_delete_failed` | Deletion attempt fails. | `friendship_id: String`, `error_code: String` | Section 5.10 |

### Accessibility

| Aspect | Specification | SRS Ref |
|---|---|---|
| Dialog announcement | Modal announced as: "Alert: Delete Friend?" (zero-balance) or "Alert: Cannot Delete Friend" (non-zero). | Section 5.6 |
| Body text | Read after the title automatically by screen readers. | Section 5.6 |
| Cancel button | Label: "Cancel". | Section 5.6 |
| Delete button | Label: "Delete". Announced with the destructive role where supported by the platform. | Section 5.6 |
| OK button | Label: "OK" (non-zero variant only). | Section 5.6 |
| Focus trapping | Focus is trapped within the dialog while open. Tab order: body text, Cancel (or OK), Delete (if present). | Section 5.6; component 24 spec |
| Dismiss gesture | Back gesture or Escape key dismisses the dialog (equivalent to Cancel / OK). | Section 5.6 |
| Loading state | During deletion, the screen reader announces "Deleting friend" (live region on the button area). | Section 5.6 |
| Contrast | All dialog text meets WCAG 2.1 AA contrast ratio (4.5:1) against the dialog surface. The `danger` colour Delete button text on the dialog surface must also meet this threshold. | Section 5.6 |

### Edge Cases

1. **Balance changes to non-zero between dialog open and delete tap.** If another expense is recorded by the friend after the dialog opens but before the user taps "Delete", the server-side security rules must reject the deletion. The client should show `OBTSnackbar(type: error, message: "Could not remove friend. Please try again.")` and, on re-opening the dialog, display the updated non-zero balance variant.
2. **Network loss during deletion.** If the device goes offline after the user taps "Delete", the Firestore offline persistence may queue the write. The dialog should show a timeout error after 10 seconds: "Could not remove friend. Please check your connection and try again."
3. **Dialog opened for a friendship that has already been deleted.** If the friendship document is deleted by the other user (or by a concurrent session) while the dialog is open, the Firestore listener on SCR-11 should detect the deletion, dismiss the dialog, and navigate to SCR-09 with an informational snackbar.
4. **Very long friend name in dialog body.** The friend's display name in the body text must wrap gracefully within the dialog width. The dialog should not overflow or clip text.

### Open Questions

1. Should the "Cannot Delete Friend" variant include a direct "Settle Up" CTA button alongside "OK" to reduce friction, or is the single dismiss button sufficient?
2. Should the deletion be a soft delete (marking the friendship as inactive) or a hard delete (removing the document), and does this affect the dialog's copy or behaviour?
3. Should the dialog include a brief explanation of what "delete" means (e.g., "You will still appear in each other's shared groups") or is the current copy sufficient?