# Groups Flow -- Screen Specifications (SCR-13 to SCR-18)

> **Document status:** Draft
> **SRS version:** 1.1
> **Audience:** Flutter Developer, QA Engineer, Solution Architect
> **Design system reference:** `docs/design/02-design-system/components.md`
> **Wireframe reference:** `docs/design/04-wireframes/groups-flow.md`
> **Site map reference:** `docs/design/01-information-architecture/site-map.md`

This document specifies six screens within the Groups feature of One By Two v1.0.
Each specification is self-contained and includes layout, components, states,
validation, telemetry, accessibility, edge cases, and open questions. All content
derives from the authoritative SRS (version 1.1), the Component Catalogue, and
the Groups Flow wireframes.

All monetary values are integer paise; conversion to rupees with Indian numbering
formatting occurs exclusively at the UI layer (Invariant 1). The
`simplifiedBalances` field is server-maintained and client-read-only (Invariant 2).
All outbound sharing uses the system share sheet (Invariant 3).

> **Status: planned — not implemented in the client.** No Flutter UI exists under `lib/features/groups/`; the tab is `GroupsListPlaceholder`. Spec retained as the build target.

---

## SCR-13: Groups List

| Field | Value |
|---|---|
| **Screen ID** | SCR-13 |
| **Screen Name** | Groups List |
| **Purpose** | Display all groups the authenticated user belongs to, with each group's name, type, member count, and the user's net simplified balance within that group. Serves as the entry point to the Groups tab. |
| **Route** | `/groups` (tab root) |
| **SRS Requirements** | FR-GR-04 (group members see expenses, balances, and activity); FR-GR-01 (group creation entry point); FR-HD-04 (persistent FAB); section 6.3 item 7; section 6.4; section 6.5 |

### Navigation

| Reachable From | Leads To |
|---|---|
| `OBTBottomNav` tab index 2 (Groups) | SCR-15 Group Detail (tap group tile) |
| Home Dashboard top-5 group tile | SCR-14 Create Group (tap FAB) |
| Activity feed deep-link (FR-AC-02) | Search overlay (tap search action) |
| Push notification deep-link (FR-AC-05) | |

### Components Used

| Component | Configuration |
|---|---|
| `OBTAppBar` | `title: "Groups"`, `showBackButton: false`, `actions: [{icon: search, semanticLabel: "Search groups"}]` |
| `OBTGroupListTile` | One per group. Displays `OBTGroupAvatar` (leading), group name, type badge, member count, trailing `OBTBalancePill`. `onTap` navigates to `/groups/:groupId`. |
| `OBTFloatingActionButton` | `semanticLabel: "Create new group"`. `onPressed` navigates to `/groups/create`. |
| `OBTBottomNav` | `currentIndex: 2` (Groups tab active). |
| `OBTSkeletonLoader` | `type: listTile`, `itemCount: 5`. Used in loading state. |
| `OBTEmptyState` | Used when the user has no groups. |
| `OBTErrorState` | Used on data fetch failure. |

### States

| State | Specification |
|---|---|
| **Loading** | `OBTSkeletonLoader` with `type: listTile`, `itemCount: 5`. Shimmer animation; respects `reduceMotion`. Semantic label: `"Loading content"`. (SRS section 6.4.) |
| **Loaded (populated)** | Scrollable list of `OBTGroupListTile` widgets, sorted by `lastActivityAt` descending. Pull-to-refresh enabled. |
| **Empty** | `OBTEmptyState` -- `illustration: groups_empty`, `title: "No groups yet"`, `subtitle: "Create a group for your flat, trip, or couple."`, `ctaLabel: "Create Group"`, `onCtaTap: navigateToCreateGroup`. (SRS sections 6.4, 6.5.) |
| **Error** | `OBTErrorState` -- `title: "Something went wrong"`, `subtitle: "We could not load your groups. Please try again."`, `onRetry: reloadGroups`, `onContactSupport: openSupportEmail`. (SRS section 6.4; FR-PR-05.) |
| **Offline (cached)** | Previously-loaded groups rendered from local cache. A subtle banner at the top: `"You are offline. Showing cached data."` (FR-OF-01.) |
| **Refreshing** | Pull-to-refresh indicator visible at the top whilst data reloads; existing list remains visible underneath. |

### Inputs and Validation

This screen has no user inputs beyond navigation taps. No validation rules apply.

### Telemetry Events

| Event Name | Trigger | Payload |
|---|---|---|
| `groups_list_viewed` | Screen becomes visible | `{groupCount: int}` |
| `group_tile_tapped` | User taps a group tile | `{groupId: string, groupType: string}` |
| `create_group_fab_tapped` | User taps the FAB | `{}` |
| `groups_search_tapped` | User taps the search action | `{}` |

(SRS section 5.10: Firebase Analytics events for key funnels.)

### Accessibility

- Each `OBTGroupListTile` semantic label: `"[Group name], [group type], [member count] members, [balance pill text]"`. (Component Catalogue, section 17.)
- Group avatars excluded from semantics when adjacent to the text label (`excludeSemantics: true`).
- Minimum tile height: 64 dp. All tap targets at least 48x48 dp. (SRS section 5.6.)
- Search action labelled `"Search groups"`.
- FAB labelled `"Create new group, button"`.
- WCAG 2.1 AA contrast ratios (at least 4.5:1) verified for all text on both light and dark surfaces. (SRS section 5.6.)
- Dynamic font scaling supported; layout must not clip at 200% text scale. (SRS section 5.6.)
- Offline banner is a live region announced by screen readers.

### Edge Cases

1. **User belongs to more than 50 groups.** The list must paginate or lazy-load to avoid excessive Firestore reads. Skeleton loaders appear at the bottom during incremental loading.
2. **Group deleted by another admin whilst user is viewing the list.** The real-time Firestore listener removes the tile with a 200 ms fade-out animation. If the user was mid-scroll, scroll position is preserved.
3. **Network loss during initial load (no cache).** The error state is shown with the subtitle `"Check your connection and try again."` and a Retry button. No empty state is shown when the failure is a network error.
4. **Balance updates in real time.** When a `simplifiedBalances` recomputation fires server-side (Invariant 2), the `OBTBalancePill` on the affected tile updates without requiring manual refresh.

### Open Questions

1. Should the Groups List support a sort toggle (e.g., by balance amount versus by last activity)? The SRS does not specify this. Pending PM decision.
2. Is there a maximum group count per user enforced server-side? If so, should the FAB be disabled or should an informational snackbar be shown when the limit is reached?
3. Should the search action on this screen filter groups only, or should it navigate to the global `/search` overlay (FR-SR-01)?

---

## SCR-14: Create Group

| Field | Value |
|---|---|
| **Screen ID** | SCR-14 |
| **Screen Name** | Create Group |
| **Purpose** | Allow the user to create a new group by specifying a name, selecting a type (Trip, Home, Couple, Other), and optionally uploading a cover photo. |
| **Route** | `/groups/create` |
| **SRS Requirements** | FR-GR-01 (create group with name, type, optional cover photo); section 6.3 item 7; section 6.2 (corner radius, tokens) |

### Navigation

| Reachable From | Leads To |
|---|---|
| SCR-13 Groups List (FAB tap) | SCR-15 Group Detail (on successful creation) |
| Home Dashboard quick action (if exposed) | SCR-13 Groups List (back navigation / cancel) |

### Components Used

| Component | Configuration |
|---|---|
| `OBTAppBar` | `title: "Create Group"`, `showBackButton: true`. |
| Cover photo area | Tappable; opens image picker (camera or gallery). Circular or rounded rectangle preview, corner radius 24 dp. |
| Group name text field | Placeholder: `"e.g. Goa Trip 2024"`. Max length: 50 characters. Semantic label: `"Group name"`. |
| Group type selector | Row of four selectable chips (`Trip`, `Home`, `Couple`, `Other`). Default: `Trip`. |
| Create button | Full-width filled button in `primary`. Label: `"Create Group"`. Corner radius 16 dp. Minimum height: 48 dp. |
| `OBTSnackbar` | Used for success and error feedback. |

### States

| State | Specification |
|---|---|
| **Default** | Form empty; type selector defaults to `Trip`. Create button disabled (name is required). Cover photo area shows placeholder with camera icon and `"Add cover photo"` label. |
| **Valid** | Name field has at least one non-whitespace character; type selected. Create button enabled in `primary`. |
| **Validation error** | Inline error below name field: `"Group name is required"` in `danger`. Shown on submit attempt with an empty or whitespace-only name. |
| **Photo uploading** | Progress overlay on the cover photo area; Create button disabled. Cancel option available on the overlay. |
| **Submitting** | Create button shows loading indicator; all inputs disabled. 200--300 ms transition. |
| **Success** | Navigates to `/groups/:groupId` for the newly created group. `OBTSnackbar` with `type: success`, `message: "Group created"`. Fires `group_created` analytics event. |
| **Error** | `OBTSnackbar` with `type: error`, `message: "Could not create group. Try again."`, `actionLabel: "Retry"`. Form remains populated so the user does not lose their input. |

### Inputs and Validation

| Field | Type | Required | Constraints | Error Message |
|---|---|---|---|---|
| Group name | `String` | Yes | 1--50 characters; at least one non-whitespace character. Leading/trailing whitespace trimmed on submit. | `"Group name is required"` (empty); `"Group name must be 50 characters or fewer"` (exceeds limit) |
| Group type | `enum` | Yes | One of `Trip`, `Home`, `Couple`, `Other`. Default: `Trip`. | N/A (always has a default selection) |
| Cover photo | Image file | No | JPEG or PNG; maximum 5 MB. | `"Image must be smaller than 5 MB"` (file too large); `"Unsupported file format. Please use JPEG or PNG."` (wrong format) |

### Telemetry Events

| Event Name | Trigger | Payload |
|---|---|---|
| `create_group_started` | Screen becomes visible | `{}` |
| `group_created` | Group successfully created (SRS section 5.10) | `{groupId: string, groupType: string, hasCoverPhoto: bool}` |
| `create_group_failed` | Creation request fails | `{errorCode: string}` |
| `group_photo_uploaded` | Cover photo successfully uploaded | `{fileSizeBytes: int}` |

### Accessibility

- All form fields have explicit semantic labels. (SRS section 5.6.)
- Type selector chips announce `"[Type] group type, [selected / not selected]"`.
- Cover photo area: `"Add cover photo, optional, button"`. When a photo is selected: `"Cover photo selected. Tap to change."`.
- Create button: `"Create group, button"` when enabled; `"Create group, button, disabled"` when disabled.
- Minimum tap targets: 48x48 dp for all interactive elements. (SRS section 5.6.)
- Error messages are announced as live regions.
- Dynamic font scaling supported; the form scrolls if content overflows at large text sizes.

### Edge Cases

1. **User navigates back with unsaved input.** A discard confirmation dialog is shown: `title: "Discard group?"`, `body: "Your changes will not be saved."`, `confirmLabel: "Discard"`, `isDestructive: true`. If the name field is empty and no photo is selected, no dialog is shown.
2. **Image picker permission denied.** Show a prompt: `"Camera/photo access is needed to add a cover photo. You can grant permission in Settings."` with a CTA to open device settings.
3. **Network loss during submission.** If offline support (FR-OF-02) is enabled, queue the write and show `OBTSnackbar type: info`, `message: "You are offline. Group will be created when you reconnect."`. Otherwise show the error snackbar.
4. **Duplicate group name.** The SRS does not prohibit duplicate names. No client-side uniqueness check is performed. The user may create multiple groups with the same name.

### Open Questions

1. Should the Create Group screen include an option to invite members immediately after creation, or should the user be directed to the Invite Members screen from Group Detail? The wireframes currently show navigation to Group Detail on success.
2. Should there be a character counter visible on the name field as the user types, or only on validation failure?
3. Is there a file compression step for cover photos before upload, or does Firebase Storage handle this?

---

## SCR-15: Group Detail

| Field | Value |
|---|---|
| **Screen ID** | SCR-15 |
| **Screen Name** | Group Detail |
| **Purpose** | Display comprehensive group information across three tabs: Expenses (all group expenses), Balances (simplified debts and settle-up CTAs), and Settings (group management actions). |
| **Route** | `/groups/:groupId` |
| **SRS Requirements** | FR-GR-04 (members see expenses, balances, activity); FR-SE-01 (simplified debts as canonical view); FR-SE-07 (Settle Up CTA on non-zero balance); FR-EX-02 (expense in group context); FR-HD-04 (persistent FAB); section 6.3 item 7; section 6.4 |

### Navigation

| Reachable From | Leads To |
|---|---|
| SCR-13 Groups List (tap group tile) | Add Expense bottom sheet (FAB tap; group context, FR-EX-02) |
| SCR-14 Create Group (on success) | Settle Up flow (tap settle-up CTA or member balance row) |
| Home Dashboard top-5 tile | SCR-16 Invite Members (Settings tab > Invite Members) |
| Activity feed deep-link (FR-AC-02) | SCR-17 Group Members (Settings tab > View Members) |
| Push notification deep-link (FR-AC-05) | Delete Group dialog -- SCR-18 (Settings tab > Delete Group) |
| | Expense Detail (tap expense tile) |
| | Group History (`/groups/:groupId/history`) |

### Components Used

| Component | Configuration |
|---|---|
| `OBTAppBar` | `title: groupName`, `showBackButton: true`, `actions: [{icon: settings, semanticLabel: "Group settings"}]`. |
| Group header card | Custom layout. Corner radius 24 dp, `elevationLow`. Cover photo or gradient fallback. Group name, type badge, member count, `OBTBalancePill` showing the current user's net balance in the group. |
| Tab bar | Three tabs: `Expenses`, `Balances`, `Settings`. Active tab underlined in `primary`. |
| `OBTExpenseListTile` | Per expense. Leading `OBTCategoryChip` icon, description, payer name, date, user share amount. |
| `OBTSettleUpCard` | Per non-zero simplified balance involving the current user. Payer/payee avatars, amount, Settle Up CTA. (FR-SE-07.) |
| `OBTBalancePill` | Used in header and per-member balance rows. |
| `OBTUserAvatar` | Used in balance rows and settle-up cards. |
| `OBTFloatingActionButton` | `semanticLabel: "Add expense to group"`. Opens Add Expense flow in group context (FR-EX-02). Visible on Expenses and Balances tabs; hidden on Settings tab. |
| `OBTEmptyState` | Per-tab empty states. |
| `OBTErrorState` | Standard error with Retry and Contact Support. |
| `OBTSkeletonLoader` | `type: profileHeader` for the header; `type: listTile, itemCount: 5` for tab content. |

### States

| State | Specification |
|---|---|
| **Loading** | Group header: `OBTSkeletonLoader type: profileHeader`. Tab content: `OBTSkeletonLoader type: listTile, itemCount: 5`. (SRS section 6.4.) |
| **Loaded** | Full content rendered per the tab specifications below. |
| **Error** | `OBTErrorState` -- `title: "Could not load group"`, `subtitle: "Please check your connection and try again."`, `onRetry: reloadGroup`, `onContactSupport: openSupportEmail`. (SRS section 6.4.) |
| **Offline (cached)** | Cached data shown with a subtle banner: `"You are offline. Showing cached data."` (FR-OF-01.) |
| **Group deleted** | If the group is deleted whilst the user is viewing it, navigate to SCR-13 with `OBTSnackbar type: info`, `message: "This group has been deleted."`. |
| **Refreshing** | Pull-to-refresh indicator on the active tab; existing content remains visible. |

#### Expenses Tab States

| State | Specification |
|---|---|
| Populated | Scrollable list of `OBTExpenseListTile` widgets, sorted by date descending. |
| Empty | `OBTEmptyState` -- `title: "No expenses yet"`, `subtitle: "Tap the + button to add your first group expense."`, `ctaLabel: "Add Expense"`, `onCtaTap: openAddExpense`. |

#### Balances Tab States

| State | Specification |
|---|---|
| Non-zero balances | `OBTSettleUpCard` for each non-zero simplified balance involving the current user. Remaining members shown as balance rows with `OBTUserAvatar` and `OBTBalancePill`. Data read from `simplifiedBalances` (Invariant 2). |
| All settled | Celebratory message: `"Everyone is settled up -- well done!"` (SRS section 6.5.) No settle-up cards displayed. |

#### Settings Tab

- List of settings rows, each with a chevron trailing icon.
- `"Invite Members"` -- navigates to `/groups/:groupId/invite` (SCR-16).
- `"View Members"` -- navigates to `/groups/:groupId/members` (SCR-17).
- `"Delete Group"` -- visible only to the group admin. Label in `danger` colour. Triggers SCR-18 delete dialog (FR-GR-07).

### Inputs and Validation

This screen has no direct user inputs beyond navigation taps and tab switching. No validation rules apply.

### Telemetry Events

| Event Name | Trigger | Payload |
|---|---|---|
| `group_detail_viewed` | Screen becomes visible | `{groupId: string, groupType: string, memberCount: int}` |
| `group_tab_switched` | User switches tab | `{groupId: string, tabName: string}` |
| `group_expense_tapped` | User taps an expense tile | `{groupId: string, expenseId: string}` |
| `group_settle_up_tapped` | User taps a Settle Up CTA | `{groupId: string, targetUserId: string, amountPaise: int}` |
| `group_add_expense_fab_tapped` | User taps the FAB | `{groupId: string}` |

### Accessibility

- Tab bar: each tab announces `"[Tab name], tab, [selected / not selected]"`. (SRS section 5.6.)
- Group header: `"[Group name], [type] group, [member count] members, [balance pill text]"`.
- Settle-up cards: `"[Payer] owes [Payee] rupees [amount]. Settle up button available."` (Component Catalogue, section 13.)
- Settings rows: `"[Label], button"`. Delete Group additionally announces `"destructive action"`.
- All tap targets: minimum 48x48 dp. (SRS section 5.6.)
- Cover photo in header is decorative: `excludeSemantics: true`.
- Dynamic font scaling: tab labels and content must not clip at 200% text scale.
- WCAG 2.1 AA contrast verified for all text on the header card gradient/photo overlay.

### Edge Cases

1. **User is removed from the group by the admin whilst viewing the detail screen.** The real-time listener detects the removal. Navigate to SCR-13 with `OBTSnackbar type: info`, `message: "You have been removed from this group."`.
2. **Group has a very large number of expenses (hundreds).** The expenses tab must paginate. Load the first 20 expenses, then lazy-load subsequent batches on scroll. Skeleton loaders appear at the bottom during incremental loading.
3. **Simplified balances recompute whilst the Balances tab is active.** The `simplifiedBalances` listener triggers a smooth re-render of the settle-up cards and balance rows without a full-screen reload. Amounts animate using a 200 ms ease-in-out transition.
4. **User is the sole member of a newly created group.** The Balances tab shows the all-settled message. The Expenses tab shows the empty state. Settings tab shows Invite Members prominently.
5. **The group cover photo fails to load.** Fall back to a gradient background derived from the group type colour (see type chip colours in the Create Group specification).

### Open Questions

1. Should the Settings tab gear icon in the app bar navigate directly to the Settings tab, or should it remain a tab that the user switches to manually? The wireframes show both patterns.
2. Should there be a group activity history link on the Settings tab or as a fourth tab? The site map includes `/groups/:groupId/history` but the wireframes show only three tabs.
3. When the Balances tab shows other members' inter-member balances (not involving the current user), should those be visible or hidden? FR-GR-04 says members see "member balances (Simplified)" which implies all pairwise simplified debts are visible.

---

## SCR-16: Invite Members

| Field | Value |
|---|---|
| **Screen ID** | SCR-16 |
| **Screen Name** | Invite Members |
| **Purpose** | Provide three invitation paths for adding new members to a group: contact picker, manual +91 phone entry, and shareable invite link via the system share sheet. |
| **Route** | `/groups/:groupId/invite` |
| **SRS Requirements** | FR-GR-02 (invite via contact picker, phone number, or invite link through system share sheet); FR-GR-03 (invite link expires in 7 days, revocable by admin); FR-SH-01 (system share sheet only -- Invariant 3); FR-SH-02 (deep link + fallback store URL) |

### Navigation

| Reachable From | Leads To |
|---|---|
| SCR-15 Group Detail Settings tab > Invite Members | System share sheet (invite link -- Invariant 3) |
| SCR-17 Group Members app bar action | `OBTContactPicker` full-screen overlay |
| | SCR-15 Group Detail (back navigation) |

### Components Used

| Component | Configuration |
|---|---|
| `OBTAppBar` | `title: "Invite Members"`, `showBackButton: true`. |
| `OBTContactPicker` | `title: "Select contact"`, `excludeNumbers: currentMemberPhones`, `existingUserIds: obtUserPhones`. |
| `OBTPhoneInput` | `autoFocus: false`. Locked `+91` prefix. |
| Contact picker button | Filled button in `primary`. Label: `"Select from contacts"`. |
| Invite button | Outlined button in `primary`. Label: `"Invite"`. |
| Share button | Filled button in `secondary` colour. Label: `"Share Invite Link"`. |
| Revoke link button | Text button in `danger`. Label: `"Revoke Link"`. Visible to admin only when a link is active. |
| `OBTSnackbar` | Used for invite success, invite error, revoke success, and revoke error feedback. |
| `OBTConfirmationDialog` | Used for revoke link confirmation. |

### States

| State | Specification |
|---|---|
| **Default** | All three invitation paths available. No active invite link. Phone input empty. |
| **Link active** | Expiry date shown below the share section: `"Link active. Expires: [dd MMM yyyy]"`. Revoke button visible for admin. (FR-GR-03.) |
| **Inviting (contact/phone)** | Invite button shows loading indicator. Phone input disabled. 200--300 ms transition. |
| **Invite success** | `OBTSnackbar type: success`, `message: "[Name or number] invited to [Group name]"`. Phone input clears. Screen remains for further invitations. |
| **Invite error** | `OBTSnackbar type: error`, `message: "Could not send invite. Try again."`, `actionLabel: "Retry"`. |
| **Link generating** | Share button shows loading indicator. Other paths remain usable. |
| **Revoke confirmation** | `OBTConfirmationDialog` -- `title: "Revoke invite link?"`, `body: "Anyone with the current link will no longer be able to join."`, `confirmLabel: "Revoke"`, `isDestructive: true`. |
| **Revoke success** | `OBTSnackbar type: success`, `message: "Invite link revoked"`. Link active section disappears. |
| **Revoke error** | `OBTSnackbar type: error`, `message: "Could not revoke link. Try again."`, `actionLabel: "Retry"`. |

### Inputs and Validation

| Field | Type | Required | Constraints | Error Message |
|---|---|---|---|---|
| Phone number | `String` (10 digits) | Yes (for Path 2 only) | Exactly 10 digits; must start with 6, 7, 8, or 9 (FR-AU-02 pattern reused). | `"Please enter a valid 10-digit mobile number"` |

### Telemetry Events

| Event Name | Trigger | Payload |
|---|---|---|
| `invite_members_viewed` | Screen becomes visible | `{groupId: string}` |
| `invite_contact_picker_opened` | User taps Select from contacts | `{groupId: string}` |
| `invite_sent_contact` | Invite sent via contact picker | `{groupId: string, isExistingUser: bool}` |
| `invite_sent_phone` | Invite sent via manual phone entry | `{groupId: string, isExistingUser: bool}` |
| `invite_link_shared` | System share sheet opened with invite link | `{groupId: string}` |
| `invite_link_revoked` | Admin revokes an active link | `{groupId: string}` |

### Accessibility

- Section headings (`"From Contacts"`, `"Enter Number"`, `"Share Invite Link"`) announced as headings. (SRS section 5.6.)
- `"Select from contacts"` button: `"Select from contacts, button"`.
- Phone input: `"Phone number, India country code plus 91"`. (Component Catalogue, section 8.)
- Share button: `"Share invite link, button"`.
- Revoke button: `"Revoke invite link, destructive action, button"`.
- Link expiry text: `"Invite link active, expires [date]"`.
- Validation error announced as a live region.
- Minimum tap targets: 48x48 dp for all interactive elements. (SRS section 5.6.)
- Contact picker permission denied state announces the guidance message.

### Edge Cases

1. **User attempts to invite a phone number that is already a group member.** Show `OBTSnackbar type: info`, `message: "This person is already a member of [Group name]."`. Do not send a duplicate invitation.
2. **Contact picker permission denied.** Show `OBTErrorState` with message `"Contact access is needed to add members. You can grant permission in Settings."` and a CTA to open device settings. The manual phone entry and share link paths remain fully usable.
3. **Invite link generation fails due to network error.** Show `OBTSnackbar type: error`, `message: "Could not generate invite link. Check your connection and try again."`. The share button returns to its default state.
4. **Non-admin user attempts to revoke a link.** The Revoke button is not rendered for non-admin users. If a race condition causes it to appear, the Cloud Function rejects the request with a permission error; show `OBTSnackbar type: error`, `message: "Only the group admin can revoke the invite link."`.
5. **User invites themselves.** The current user's phone number is included in `excludeNumbers` for the contact picker and validated against for manual entry. Error message: `"You are already a member of this group."`.

### Open Questions

1. Should the invite screen show a list of pending (not yet accepted) invitations below the three paths, so the admin can see who has been invited but has not yet joined?
2. When a non-admin member visits this screen, should the revoke section be hidden entirely or shown in a read-only state displaying the expiry date?
3. If the group has reached a maximum member count (if one exists), should all three invitation paths be disabled with an explanatory message?

---

## SCR-17: Group Members

| Field | Value |
|---|---|
| **Screen ID** | SCR-17 |
| **Screen Name** | Group Members |
| **Purpose** | Display all members of the group with their roles and simplified balances. Provide the admin with the ability to remove members (with a zero-balance guard) and all members with the ability to leave the group (with a zero-balance guard). |
| **Route** | `/groups/:groupId/members` |
| **SRS Requirements** | FR-GR-05 (admin removes member only if balance is zero); FR-GR-06 (member leaves only if balance is zero); FR-GR-04 (member balances visible); section 6.3 item 7 |

### Navigation

| Reachable From | Leads To |
|---|---|
| SCR-15 Group Detail Settings tab > View Members | SCR-16 Invite Members (app bar Invite action) |
| | SCR-18 Remove Member / Leave Group dialogs |
| | SCR-15 Group Detail (back navigation) |
| | SCR-13 Groups List (on successful leave) |

### Components Used

| Component | Configuration |
|---|---|
| `OBTAppBar` | `title: "Members"`, `showBackButton: true`, `actions: [{icon: person_add, semanticLabel: "Invite members"}]`. |
| `OBTUserAvatar` | Leading element in each member row. |
| `OBTBalancePill` | Trailing element showing each member's net simplified balance within the group. |
| Admin badge | Muted text `"(Admin)"` next to the admin member's display name. |
| Remove action | Trailing icon button or swipe-to-reveal on non-admin member rows. Admin-only. |
| Leave Group button | Full-width outlined button in `danger` at the bottom of the member list. |
| `OBTConfirmationDialog` | Used for remove member and leave group confirmations. |
| `OBTSnackbar` | Used for success and error feedback. |
| `OBTSkeletonLoader` | `type: listTile, itemCount: 4`. Used in loading state. |

### States

| State | Specification |
|---|---|
| **Loading** | `OBTSkeletonLoader type: listTile, itemCount: 4`. (SRS section 6.4.) |
| **Loaded** | Member list rendered. Admin badge shown on admin row. Remove actions conditionally enabled. Leave Group button conditionally enabled. |
| **Remove success** | `OBTSnackbar type: success`, `message: "[Name] removed from group"`. Member row disappears with a 200 ms fade-out animation. |
| **Remove error (non-zero balance)** | `OBTSnackbar type: error`, `message: "[Name] has an outstanding balance. They must settle up first."`. (FR-GR-05.) |
| **Leave success** | Navigates to SCR-13 Groups List. `OBTSnackbar type: success`, `message: "You left [Group name]"`. |
| **Error** | `OBTErrorState` -- standard configuration with Retry and Contact Support. (SRS section 6.4.) |

### Inputs and Validation

This screen has no text inputs. The following business rules function as validation guards:

| Action | Guard Condition | Disabled State Message |
|---|---|---|
| Remove member (admin) | Target member's simplified balance must be zero (FR-GR-05). | `"[Name] must settle up before they can be removed."` (tooltip / disabled hint) |
| Leave group (any member) | Current user's simplified balance must be zero (FR-GR-06). | `"You must settle up before you can leave."` (helper text below disabled button) |

### Telemetry Events

| Event Name | Trigger | Payload |
|---|---|---|
| `group_members_viewed` | Screen becomes visible | `{groupId: string, memberCount: int, isAdmin: bool}` |
| `group_member_removed` | Admin successfully removes a member | `{groupId: string, removedUserId: string}` |
| `group_member_remove_blocked` | Admin attempts to remove a member with a non-zero balance | `{groupId: string, targetUserId: string}` |
| `group_left` | User successfully leaves the group | `{groupId: string}` |
| `group_leave_blocked` | User attempts to leave with a non-zero balance | `{groupId: string}` |

### Accessibility

- Each member row: `"[Name], [admin if applicable], [balance pill text]"`. (SRS section 5.6.)
- Remove action: `"Remove [Name] from group, [enabled / disabled], button"`.
- Leave button: `"Leave group, [enabled / disabled], destructive action, button"`.
- Disabled states announce the reason via `Semantics(hint:)` (e.g., `"Disabled: [Name] must settle up first"`).
- Minimum tap targets: 48x48 dp for all interactive elements. (SRS section 5.6.)
- Swipe-to-reveal remove action is also accessible via the trailing icon button for screen-reader users who cannot perform swipe gestures.
- Dynamic font scaling supported; member names truncate with ellipsis if they exceed the available width at large text sizes.

### Edge Cases

1. **Admin is the only member.** The Leave Group button is visible. On tap, because the balance is zero (sole member), the confirmation dialog is shown. On confirmation, the group is effectively deleted (or the admin is informed they must delete the group instead via SCR-18).
2. **Member is removed by the admin whilst the member is viewing the group.** The real-time listener detects the removal. The removed user is navigated to SCR-13 with `OBTSnackbar type: info`, `message: "You have been removed from [Group name]."`.
3. **Balance changes from zero to non-zero between the time the admin taps Remove and the Cloud Function executes.** The Cloud Function performs a server-side zero-balance check and rejects the removal. Show `OBTSnackbar type: error`, `message: "Could not remove [Name]. Their balance has changed. Please refresh and try again."`.
4. **Admin attempts to remove themselves.** The remove action is not shown on the admin's own row. The admin uses the Leave Group button instead.

### Open Questions

1. Should admin transfer be supported in v1.0? If the admin leaves, who becomes the new admin? The SRS does not specify admin transfer. This needs a PM decision.
2. Should there be a visual distinction (e.g., reordering or a section divider) between the admin and non-admin members?
3. If the group has only two members and one leaves, should the remaining member be notified that they are now the sole member?

---

## SCR-18: Delete/Leave Group Dialogs

| Field | Value |
|---|---|
| **Screen ID** | SCR-18 |
| **Screen Name** | Delete/Leave Group Dialogs |
| **Purpose** | Present confirmation dialogs for two destructive group actions: deleting a group (admin only, all balances must be zero) and leaving a group (any member, own balance must be zero). These are modal overlays, not standalone screens. |
| **Route** | N/A (modal overlays triggered from SCR-15 Settings tab and SCR-17 respectively) |
| **SRS Requirements** | FR-GR-06 (leave group with zero-balance guard); FR-GR-07 (admin deletes group only if all balances zero); section 6.4; section 6.5 |

### Navigation

| Reachable From | Leads To |
|---|---|
| SCR-15 Group Detail Settings tab > Delete Group (admin) | SCR-13 Groups List (on successful delete) |
| SCR-17 Group Members > Leave Group button | SCR-13 Groups List (on successful leave) |
| | Returns to the triggering screen on Cancel or dismiss |

### Components Used

| Component | Configuration |
|---|---|
| `OBTConfirmationDialog` (delete -- permitted) | `title: "Delete [Group name]?"`, `body: "This will permanently delete the group and all its data for every member. This cannot be undone."`, `confirmLabel: "Delete"`, `isDestructive: true`. Corner radius 24 dp. |
| `OBTConfirmationDialog` (delete -- blocked) | `title: "Cannot delete group"`, `body: "Some members still have outstanding balances. Everyone must settle up before the group can be deleted."`, `cancelLabel: "OK"`. Single dismiss button only. |
| `OBTConfirmationDialog` (leave -- permitted) | `title: "Leave [Group name]?"`, `body: "You will no longer see this group's expenses or balances."`, `confirmLabel: "Leave Group"`, `isDestructive: true`. |
| `OBTConfirmationDialog` (leave -- blocked) | `title: "Cannot leave group"`, `body: "You have an outstanding balance. Please settle up before leaving."`, `cancelLabel: "OK"`. Single dismiss button only. |
| `OBTSnackbar` | Used for success and error feedback after dialog actions. |

### States

| State | Specification |
|---|---|
| **Pre-check: delete permitted (all balances zero)** | Destructive confirmation dialog shown. Admin may proceed. Client reads `simplifiedBalances` from the group document (Invariant 2) to perform the check. |
| **Pre-check: delete blocked (non-zero balances exist)** | Blocking information dialog shown. No delete action available. (FR-GR-07.) |
| **Deleting** | Confirm button shows loading indicator; both buttons disabled. (Component Catalogue, section 24.) |
| **Delete success** | Dialog dismisses. Navigates to SCR-13 Groups List. `OBTSnackbar type: success`, `message: "[Group name] deleted"`. |
| **Delete error** | `OBTSnackbar type: error`, `message: "Could not delete group. Try again."`, `actionLabel: "Retry"`. Dialog returns to its default state. |
| **Pre-check: leave permitted (own balance zero)** | Destructive confirmation dialog shown. Member may proceed. |
| **Pre-check: leave blocked (own balance non-zero)** | Blocking information dialog shown. No leave action available. (FR-GR-06.) |
| **Leaving** | Confirm button shows loading indicator; both buttons disabled. |
| **Leave success** | Dialog dismisses. Navigates to SCR-13 Groups List. `OBTSnackbar type: success`, `message: "You left [Group name]"`. |
| **Leave error** | `OBTSnackbar type: error`, `message: "Could not leave group. Try again."`, `actionLabel: "Retry"`. Dialog returns to its default state. |

### Inputs and Validation

These dialogs have no text inputs. Validation is performed as a pre-condition check before the dialog is shown:

| Action | Pre-condition | Source of Truth | Blocking Message |
|---|---|---|---|
| Delete group | All member balances are zero | `simplifiedBalances` field on the group document (Invariant 2) | `"Some members still have outstanding balances. Everyone must settle up before the group can be deleted."` |
| Leave group | Current user's own balance is zero | `simplifiedBalances` field on the group document (Invariant 2) | `"You have an outstanding balance. Please settle up before leaving."` |

### Telemetry Events

| Event Name | Trigger | Payload |
|---|---|---|
| `group_delete_dialog_shown` | Delete dialog becomes visible | `{groupId: string, isPermitted: bool}` |
| `group_deleted` | Group successfully deleted | `{groupId: string, memberCount: int}` |
| `group_delete_blocked` | Delete blocked due to non-zero balances | `{groupId: string}` |
| `group_delete_failed` | Delete request fails | `{groupId: string, errorCode: string}` |
| `group_leave_dialog_shown` | Leave dialog becomes visible | `{groupId: string, isPermitted: bool}` |
| `group_left` | User successfully leaves | `{groupId: string}` |
| `group_leave_blocked` | Leave blocked due to non-zero balance | `{groupId: string}` |
| `group_leave_failed` | Leave request fails | `{groupId: string, errorCode: string}` |

### Accessibility

- Dialog announced as modal: `"Alert: Delete [Group name]?"` or `"Alert: Cannot delete group"` or `"Alert: Leave [Group name]?"` or `"Alert: Cannot leave group"`. (Component Catalogue, section 24.)
- Body text read after title by screen readers.
- Focus trapped within the dialog whilst open. (SRS section 5.6.)
- Cancel/OK button: `"Cancel, button"` or `"OK, button"`.
- Delete button: `"Delete, destructive action, button"`.
- Leave Group button: `"Leave group, destructive action, button"`.
- Escape gesture or hardware back button is equivalent to Cancel/OK. (SRS section 5.6.)
- Loading state announces `"Processing, please wait"` via a live region.
- Scrim overlay prevents interaction with content behind the dialog; screen readers do not traverse elements behind the scrim.

### Edge Cases

1. **Balances change between the pre-condition check and the Cloud Function execution.** The Cloud Function performs its own server-side validation. If balances are no longer zero, the operation is rejected. Show `OBTSnackbar type: error`, `message: "Balances have changed. Please refresh and try again."`. Dialog dismisses and the user is returned to the triggering screen.
2. **Admin attempts to delete a group with pending offline expense writes (FR-OF-02).** The offline queue must be synced before deletion can proceed. If unsynced writes exist, show `OBTSnackbar type: info`, `message: "You have unsynced changes. Please connect to the internet and try again."`. Block the delete action.
3. **Admin is the last member and deletes the group.** This is permitted (all balances are trivially zero). The flow proceeds normally. The admin is navigated to SCR-13.
4. **Multiple users attempt to delete or leave simultaneously.** The Cloud Function handles concurrency via Firestore transactions. Only one operation succeeds; subsequent attempts receive an error. The client retries or shows the error snackbar.
5. **User's connection drops after tapping Confirm but before the response.** The dialog remains in the loading state. After a 15-second timeout, show `OBTSnackbar type: error`, `message: "Request timed out. Please check your connection and try again."`. Dialog returns to its default state.

### Open Questions

1. Should the delete operation perform a soft delete (marking the group as deleted) or a hard delete (removing all documents)? The SRS does not specify. This affects whether group data can be recovered and has implications for the Architect and Cloud Functions Developer.
2. When the admin leaves a group (rather than deleting it), should admin privileges transfer to the next member by creation date, or should the admin be forced to delete the group instead? The SRS is silent on admin transfer for v1.0.
3. Should the blocked dialogs include a CTA to navigate directly to the Balances tab (SCR-15) so the user can initiate settlements, rather than simply dismissing with OK?

---

## Cross-Cutting Specifications

### Design Token Application

| Token | Application Across SCR-13 to SCR-18 |
|---|---|
| `primary` (`#1F4E79` / `#2E86AB`) | Tab bar active state, Create/Invite buttons, app bar actions, Retry buttons. |
| `secondary` (`#F4A261`) | FAB background, Share Invite Link button. |
| `success` (`#2A9D8F`) | Positive balance pills (`"you are owed"`), success snackbars. |
| `danger` (`#E76F51`) | Negative balance pills (`"you owe"`), destructive buttons (Remove, Delete, Leave), error snackbars, validation error text. |
| `surface` (`#FFFFFF` / `#121212`) | Card backgrounds, dialog backgrounds, sheet backgrounds. |
| `cornerRadiusSmall` (16 dp) | Buttons, pills, input fields, snackbars. |
| `cornerRadiusLarge` (24 dp) | Group header card, confirmation dialogs, cover photo area. |
| `elevationLow` (1 dp) | Resting cards, group header. |
| `elevationMedium` (4 dp) | FAB, raised cards. |
| `motionStandard` (200--300 ms ease-in-out) | Tab switches, tile press states, snackbar enter/exit, list item animations, dialog fade. |
| `motionSpring` (damping ~0.7) | FAB press/release. |

### Microcopy Reference (SRS section 6.5)

| Context | Copy |
|---|---|
| Groups list empty | `"No groups yet"` / `"Create a group for your flat, trip, or couple."` |
| Group expenses empty | `"No expenses yet"` / `"Tap the + button to add your first group expense."` |
| All settled in group | `"Everyone is settled up -- well done!"` |
| Invite link description | `"Share a link that lets anyone join this group. Link expires in 7 days."` |
| Cannot remove (balance) | `"[Name] must settle up before they can be removed."` |
| Cannot leave (balance) | `"You must settle up before you can leave."` |
| Cannot delete (balances) | `"Some members still have outstanding balances. Everyone must settle up before the group can be deleted."` |
| Group created | `"Group created"` |
| Group deleted | `"[Group name] deleted"` |
| Left group | `"You left [Group name]"` |
| Member removed | `"[Name] removed from group"` |
| Invite sent | `"[Name or number] invited to [Group name]"` |
| Invite link revoked | `"Invite link revoked"` |
| Offline banner | `"You are offline. Showing cached data."` |
| Group name required | `"Group name is required"` |
| Invalid phone | `"Please enter a valid 10-digit mobile number"` |

### SRS Requirement Traceability

| Requirement | Screen(s) |
|---|---|
| FR-GR-01 | SCR-14 Create Group |
| FR-GR-02 | SCR-16 Invite Members (all three paths) |
| FR-GR-03 | SCR-16 Invite Members (link expiry, revoke) |
| FR-GR-04 | SCR-13 Groups List, SCR-15 Group Detail (expenses, balances), SCR-17 Group Members |
| FR-GR-05 | SCR-17 Group Members (admin remove with zero-balance guard) |
| FR-GR-06 | SCR-17 Group Members, SCR-18 Leave Group dialog (zero-balance guard) |
| FR-GR-07 | SCR-18 Delete Group dialog (admin-only, all-zero-balance guard) |
| FR-SE-01 | SCR-15 Group Detail Balances tab (simplified debts only) |
| FR-SE-07 | SCR-15 Group Detail Balances tab (Settle Up CTA on non-zero balance) |
| FR-SH-01 | SCR-16 Invite Members (system share sheet -- Invariant 3) |
| FR-SH-02 | SCR-16 Invite Members (deep link + fallback store URL) |
| FR-EX-02 | SCR-15 Group Detail FAB (expense in group context) |
| FR-HD-04 | SCR-13 Groups List FAB, SCR-15 Group Detail FAB |
| FR-OF-01 | SCR-13, SCR-15 offline cached state |
| Section 5.6 | All screens (tap targets, contrast, dynamic font scaling, screen readers) |
| Section 6.3 | Core Screen 7: Groups list and Group detail |
| Section 6.4 | Empty, error, and loading states on all screens |
| Section 6.5 | All microcopy |
| Section 5.10 | All telemetry events |
| Invariant 1 | All balance values stored and transmitted as integer paise; conversion at UI layer |
| Invariant 2 | `simplifiedBalances` read-only on client; server-maintained |
| Invariant 3 | System share sheet only for invite link sharing |