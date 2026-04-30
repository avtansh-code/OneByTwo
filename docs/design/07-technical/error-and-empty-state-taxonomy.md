# Error and Empty State Taxonomy

> **Document owner:** UX/UI Designer
> **Version:** 1.0
> **SRS version:** 1.1
> **Last updated:** 2025-01-27

This document provides a comprehensive catalogue of every error, empty, and loading state across the One By Two application. It is the single reference for microcopy, telemetry event names, retry strategies, and component usage. All copy follows the friendly, concise, and lightly playful tone mandated by SRS section 6.5. All error states render using `OBTErrorState` and all empty states render using `OBTEmptyState`, as defined in `docs/design/02-design-system/components.md` (sections 18 and 19).

**Cross-references:**
- SRS section 6.4 -- Empty, Error and Loading States
- SRS section 6.5 -- Microcopy Tone
- SRS section 5.6 -- Usability and Accessibility
- SRS section 5.10 -- Observability (telemetry events)
- Component spec: `OBTEmptyState` (component 18), `OBTErrorState` (component 19), `OBTSkeletonLoader` (component 20)

---

## 1. Error States

Every error state renders via `OBTErrorState`, which provides a non-alarming illustration, a title, a descriptive subtitle, a primary "Retry" button, and an optional "Contact Support" text link (per FR-PR-05, FR-SH-03, FR-SH-04). An optional `errorCode` is shown in small muted text for support triage.

### 1.1 Network Errors

| Screen | Error Condition | User-Visible Copy (Title / Subtitle) | Telemetry Event | Retry Strategy | Escalation |
|---|---|---|---|---|---|
| Any list or detail screen | Device is offline | "You're offline" / "Check your connection and try again. We'll keep your data safe." | `error_network_offline` | Tap "Retry"; also auto-retry on connectivity restored | Contact Support link hidden (not a server issue) |
| Any list or detail screen | Request timeout (>10 s) | "Taking too long" / "The request timed out. Give it another go." | `error_network_timeout` | Tap "Retry" with exponential back-off (max 3 attempts) | Show Contact Support after 3 consecutive failures |
| Add/Edit Expense | Save fails due to network | "Could not save" / "Your expense was not saved. Please check your connection and try again." | `error_expense_save_network` | Tap "Retry"; if offline-capable (FR-OF-02), queue locally | Contact Support after 3 failures |
| Settle Up | Settlement recording fails | "Settlement not recorded" / "We could not record this payment. Please try again." | `error_settlement_save_network` | Tap "Retry" | Contact Support after 3 failures |

### 1.2 Authentication Errors

| Screen | Error Condition | User-Visible Copy (Title / Subtitle) | Telemetry Event | Retry Strategy | Escalation |
|---|---|---|---|---|---|
| Phone Number Entry | Invalid phone number format (FR-AU-02) | Inline validation: "Enter a valid 10-digit Indian mobile number." | `error_auth_invalid_phone` | Inline; user corrects input | N/A |
| OTP Verification | Incorrect OTP entered | Inline validation: "That code does not match. Please check and try again." | `error_auth_invalid_otp` | User re-enters; field clears | After 3 failed attempts, prompt "Request a new code" |
| OTP Verification | OTP expired | "Code expired" / "That code has expired. Request a fresh one." | `error_auth_otp_expired` | Tap "Request new code" (respects 30 s cooldown per FR-AU-05) | Contact Support if repeated failures |
| OTP Verification | Rate limit exceeded (3 retries per 10 min, FR-AU-05) | "Too many attempts" / "You have requested too many codes. Please wait a few minutes and try again." | `error_auth_rate_limited` | Disabled state with countdown timer | Contact Support link shown |
| Any screen (background) | Auth token expired / session invalid | "Session expired" / "Please sign in again to continue." | `error_auth_token_expired` | Navigate to Phone Number Entry screen | N/A |
| Any screen (background) | Account disabled server-side | "Account unavailable" / "Your account is currently unavailable. Please contact support for help." | `error_auth_account_disabled` | No retry; sign out | Contact Support shown prominently |

### 1.3 Validation Errors

All validation errors display as inline messages beneath the relevant field, not as `OBTErrorState`. They use `Danger` colour (`#E76F51`) for the message text.

| Screen | Error Condition | User-Visible Copy | Telemetry Event | Retry Strategy | Escalation |
|---|---|---|---|---|---|
| Phone Number Entry | Number fewer than 10 digits | "Enter a valid 10-digit mobile number." | `error_validation_phone_short` | Inline correction | N/A |
| Profile Setup | Display name empty (FR-AU-06) | "A name is needed so friends can find you." | `error_validation_name_empty` | Inline correction | N/A |
| Profile Setup | Display name exceeds character limit | "Keep it under 50 characters." | `error_validation_name_long` | Inline correction | N/A |
| Add/Edit Expense | Amount is zero or empty (FR-EX-01) | "Enter an amount greater than zero." | `error_validation_amount_zero` | Inline correction | N/A |
| Add/Edit Expense | Description empty (FR-EX-01) | "Add a short description for this expense." | `error_validation_desc_empty` | Inline correction | N/A |
| Add/Edit Expense | Splits do not sum to total (FR-EX-04) | "The splits do not add up to the total. Adjust to continue." | `error_validation_split_mismatch` | Inline; difference amount shown | N/A |
| Add/Edit Expense | Percentage splits do not sum to 100% | "Percentages must add up to 100%." | `error_validation_pct_mismatch` | Inline correction | N/A |
| Settle Up | Settlement amount is zero or empty | "Enter the amount being settled." | `error_validation_settle_zero` | Inline correction | N/A |
| Group Creation | Group name empty (FR-GR-01) | "Give your group a name." | `error_validation_group_name_empty` | Inline correction | N/A |

### 1.4 Permission Errors

| Screen | Error Condition | User-Visible Copy (Title / Subtitle) | Telemetry Event | Retry Strategy | Escalation |
|---|---|---|---|---|---|
| Group Detail | User is not a member of the group | "You are not in this group" / "You may have been removed, or the link has expired." | `error_permission_not_member` | Navigate back; no retry | Contact Support link shown |
| Group Detail | Non-admin attempts admin action (remove member, delete group) | Snackbar: "Only the group admin can do this." | `error_permission_not_admin` | N/A (action blocked) | N/A |
| Friend Detail | Attempting to delete friend with non-zero balance (FR-FR-05) | Snackbar: "Settle up first before removing this friend." | `error_permission_unsettled_delete` | N/A (action blocked) | N/A |
| Group Detail | Member attempts to leave with non-zero balance (FR-GR-06) | Snackbar: "You need to settle up before leaving this group." | `error_permission_unsettled_leave` | N/A (action blocked) | N/A |
| Group Detail | Admin attempts to delete group with non-zero balances (FR-GR-07) | Snackbar: "All balances must be settled before deleting this group." | `error_permission_unsettled_group_delete` | N/A (action blocked) | N/A |
| Contact Picker | Device contact permission denied | "Contact access is needed to add friends. You can grant permission in Settings." (per component spec) | `error_permission_contacts_denied` | CTA: "Open Settings" to device settings | Manual phone entry fallback always available |

### 1.5 Server Errors (Cloud Function Failures)

| Screen | Error Condition | User-Visible Copy (Title / Subtitle) | Telemetry Event | Retry Strategy | Escalation |
|---|---|---|---|---|---|
| Any screen depending on simplified balances | `recomputeSimplifiedBalances` function fails | "Something went wrong" / "We could not update your balances. Please try again." | `error_server_balance_recompute` | Tap "Retry" (re-triggers the originating write) | Contact Support after 2 consecutive failures |
| Group Detail | Group invite link generation fails | "Could not create invite link" / "Something went wrong. Please try again." | `error_server_invite_link` | Tap "Retry" | Contact Support shown |
| Profile and Settings | Account deletion Cloud Function fails (FR-AU-09) | "Could not delete account" / "We hit a snag deleting your account. Please try again or contact support." | `error_server_account_delete` | Tap "Retry" | Contact Support shown immediately |
| Settle Up | Settlement Cloud Function fails | "Settlement not recorded" / "Something went wrong on our end. Please try again." | `error_server_settlement` | Tap "Retry" | Contact Support after 2 failures |
| Add/Edit Expense | Expense write triggers Cloud Function error | "Could not save expense" / "Something went wrong. Your data is safe -- please try again." | `error_server_expense_save` | Tap "Retry" | Contact Support after 2 failures |

### 1.6 Not Found Errors

| Screen | Error Condition | User-Visible Copy (Title / Subtitle) | Telemetry Event | Retry Strategy | Escalation |
|---|---|---|---|---|---|
| Expense Detail (deep link) | Expense has been deleted | "Expense not found" / "This expense may have been deleted by the person who added it." | `error_notfound_expense` | Navigate back (no retry) | N/A |
| Group Detail (deep link) | Group has been deleted or user was removed | "Group not found" / "This group may have been deleted, or you are no longer a member." | `error_notfound_group` | Navigate back (no retry) | Contact Support link shown |
| Friend Detail (deep link) | Friendship no longer exists | "Friend not found" / "This connection may have been removed." | `error_notfound_friend` | Navigate back (no retry) | N/A |
| Activity Feed | Tapped activity item points to deleted resource (FR-AC-02) | Snackbar: "This item is no longer available." | `error_notfound_activity_target` | Dismiss snackbar | N/A |
| Group Join (invite link) | Invite link expired or revoked (FR-GR-03) | "Invite expired" / "This invite link is no longer valid. Ask the group admin to send a new one." | `error_notfound_invite_expired` | No retry | N/A |

---

## 2. Empty States

Every empty state renders via `OBTEmptyState`, which provides a centred SVG illustration, a bold title, a descriptive subtitle, and an optional primary CTA button. All copy follows the friendly and lightly playful tone per SRS section 6.5.

| Screen | Empty Condition | Headline | Subtitle | CTA Text | CTA Action |
|---|---|---|---|---|---|
| Home Dashboard (new user) | No friends, groups, or expenses | "Welcome to One By Two" | "Add a friend or create a group to start splitting expenses." | "Add a friend" | Navigate to Contact Picker / Add Friend flow |
| Home Dashboard (returning, all settled) | Net simplified balance is zero across all friends and groups | "You're all settled up" | "Nothing owed, nothing owing. Time for a chai break." | -- | -- |
| Friends List | User has no friends added (FR-FR-03) | "No friends yet" | "Add a friend and start sharing expenses." | "Add friend" | Navigate to Contact Picker (FR-FR-01) |
| Groups List | User has no groups (FR-GR-01) | "No groups yet" | "Create a group for your flat, trip, or couple." | "Create group" | Navigate to Create Group flow |
| Activity Feed | No activity events exist for the user (FR-AC-01) | "All quiet here" | "Your activity will show up as you add expenses and settle up." | -- | -- |
| Expense List (Friend Detail) | No expenses between user and this friend (FR-FR-04) | "No expenses yet" | "Tap the button below to add your first expense with this friend." | "Add expense" | Open Add Expense sheet with friend pre-selected |
| Expense List (Group Detail) | No expenses in this group (FR-GR-04) | "No expenses yet" | "Add the first expense and get splitting." | "Add expense" | Open Add Expense sheet with group pre-selected |
| Settlement History (Friend) | No settlements recorded with this friend (FR-SE-08) | "No settlements yet" | "Once you settle up, it will appear here." | -- | -- |
| Settlement History (Group) | No settlements recorded in this group (FR-SE-08) | "No settlements yet" | "Settlements for this group will show up here." | -- | -- |
| Search Results | Query returns no matching expenses (FR-SR-01) | "No results found" | "Try a different search term or adjust your filters." | "Clear filters" | Reset all active filters |
| Contact Picker | No contacts match search / no contacts on device | "No contacts found" | "You can enter a number manually." | "Enter number" | Switch to manual phone number entry field |
| Group Members List | Group has only the creator (edge case after creation) | "Just you so far" | "Invite friends to join this group." | "Invite members" | Open invite flow (system share sheet per FR-SH-01) |

---

## 3. Loading States

Per SRS section 6.4, skeleton screens are the preferred loading pattern. Spinners are used only as a fallback after 1.5 seconds if content has not yet rendered, or for discrete in-progress actions (e.g., saving).

All skeleton loaders render via `OBTSkeletonLoader` (component 20), which provides a shimmer animation (1.5 s loop, left-to-right). The shimmer respects `AccessibilityFeatures.reduceMotion`; when reduced motion is enabled, a static grey placeholder is shown without animation (per SRS section 5.6).

### 3.1 Skeleton-First Screens

These screens display skeleton placeholders immediately on load, transitioning to content with a 200 ms fade-in once data arrives.

| Screen | Skeleton Type (`OBTSkeletonLoader.type`) | Item Count | Notes |
|---|---|---|---|
| Home Dashboard | `chart` + `listTile` | 1 chart + 5 list tiles | Chart skeleton for spend summary (FR-HD-03); list tiles for top friends/groups (FR-HD-02) |
| Friends List | `listTile` | 8 | Matches `OBTFriendListTile` layout with avatar circle + name lines + balance pill |
| Friend Detail | `profileHeader` + `listTile` | 1 header + 5 list tiles | Header for friend info; list tiles for expense history |
| Groups List | `listTile` | 6 | Matches `OBTGroupListTile` layout |
| Group Detail | `profileHeader` + `listTile` | 1 header + 5 list tiles | Header for group info; list tiles for expenses and members |
| Activity Feed | `activityRow` | 10 | Matches `OBTActivityRow` layout with small avatar + two-line text |
| Expense Detail | `expenseDetail` | 1 | Full-width header + line items + amount block |
| Settlement History | `listTile` | 5 | Matches settlement row layout |
| Search Results | `listTile` | 5 | Shown after query submitted, before results arrive |
| Profile and Settings | `profileHeader` | 1 | Centred avatar circle + name line; settings items render statically |

### 3.2 Spinner Usage

Spinners (circular progress indicators) are used for discrete, user-initiated actions where skeleton placeholders are not meaningful.

| Context | Trigger | Spinner Placement | Timeout |
|---|---|---|---|
| Add/Edit Expense -- saving | User taps "Save" | Inline within the save button (button label replaced with spinner) | 10 s; on timeout, show `OBTErrorState` with network timeout copy |
| Settle Up -- recording | User taps "Record settlement" | Inline within the confirm button | 10 s; on timeout, show `OBTErrorState` |
| OTP Verification -- verifying | User submits OTP (FR-AU-03) | Inline within the verify button | 15 s; on timeout, show "Verification timed out. Please try again." |
| OTP Verification -- requesting new code | User taps "Request new code" (FR-AU-05) | Small spinner next to the resend text link | 10 s; on timeout, re-enable the resend link |
| Profile photo upload | User selects a photo (FR-PR-01) | Overlay spinner on the avatar | 30 s; on timeout, show snackbar "Upload timed out. Please try again." |
| Receipt image upload | User attaches a receipt (FR-EX-05) | Overlay spinner on the thumbnail | 30 s; on timeout, show snackbar "Upload timed out. Please try again." |
| Group invite link generation | User taps "Share invite" (FR-GR-02) | Inline spinner replacing the share icon | 10 s; on timeout, show snackbar with server error copy |
| Account deletion | User confirms deletion (FR-AU-09) | Full-screen modal spinner with "Deleting your account..." | 30 s; on timeout, show `OBTErrorState` with account deletion failure copy |
| Pull-to-refresh (any list) | User pulls down on a list | Standard `RefreshIndicator` spinner at top of list | 10 s; on timeout, show snackbar "Could not refresh. Please try again." |

### 3.3 Skeleton-to-Spinner Fallback Rule

If a skeleton-first screen has not received data within **1.5 seconds**, the skeleton remains visible (it is not replaced by a spinner). The spinner fallback applies only when the skeleton itself cannot render (e.g., a configuration error). In practice, the skeleton persists until either content loads or an `OBTErrorState` is shown after the request fails or times out.

### 3.4 Transition Specifications

| Transition | Duration | Curve | Reference |
|---|---|---|---|
| Skeleton to content | 200 ms | ease-in-out | SRS section 6.2 (motion: 200-300 ms ease-in-out) |
| Content to error state | 200 ms | ease-in-out | SRS section 6.2 |
| Error state to skeleton (on retry) | 150 ms | ease-out | Immediate visual feedback on tap |
| Empty state appearance | 300 ms | ease-in-out | Slightly longer for illustration fade-in |

---

## 4. State Decision Matrix

A quick-reference for which component to use in each scenario.

| Scenario | Component | Retry? | Contact Support? |
|---|---|---|---|
| Data loading in progress | `OBTSkeletonLoader` | N/A | N/A |
| Discrete action in progress | Inline spinner (within button) | N/A | N/A |
| Data loaded but list is empty | `OBTEmptyState` | No | No |
| Network failure on load | `OBTErrorState` | Yes | After 3 failures |
| Network failure on save | `OBTErrorState` or snackbar | Yes | After 3 failures |
| Server / Cloud Function error | `OBTErrorState` | Yes | After 2 failures |
| Validation failure | Inline field error | No (user corrects) | No |
| Permission denied | Snackbar or `OBTErrorState` | No | Contextual |
| Resource not found | `OBTErrorState` | No (navigate back) | Contextual |
| Auth failure (token expired) | `OBTErrorState` with redirect | No (re-authenticate) | No |
| Account disabled | `OBTErrorState` | No | Yes (prominent) |

---

## 5. Telemetry Event Naming Convention

All error telemetry events follow the pattern `error_{category}_{condition}` to ensure consistency in Firebase Analytics dashboards (per SRS section 5.10).

| Category Prefix | Scope |
|---|---|
| `error_network_` | Connectivity and timeout issues |
| `error_auth_` | Authentication and session issues |
| `error_validation_` | Client-side input validation failures |
| `error_permission_` | Authorisation and access control |
| `error_server_` | Cloud Function and backend failures |
| `error_notfound_` | Missing or deleted resources |

Each event should include the following parameters:

| Parameter | Type | Description |
|---|---|---|
| `screen` | `string` | Screen name where the error occurred |
| `error_code` | `string?` | Technical error code from the backend, if available |
| `retry_count` | `int` | Number of retries attempted before logging |
| `is_offline` | `bool` | Whether the device was offline at the time |

---

## 6. Accessibility Requirements for States

Per SRS section 5.6 and the component specifications in `docs/design/02-design-system/components.md`:

| Requirement | Specification |
|---|---|
| Illustrations in empty and error states | Decorative; `excludeSemantics: true` |
| Titles in empty and error states | Announced as headings by screen readers |
| Retry button in `OBTErrorState` | Semantic label: "Retry" |
| Contact Support link in `OBTErrorState` | Semantic label: "Contact support" |
| Error code in `OBTErrorState` | Included in semantics as "Error code: [code]" |
| CTA button in `OBTEmptyState` | Semantic label matches `ctaLabel` text |
| Skeleton loaders | `Semantics(label: "Loading content", liveRegion: true)` |
| Skeleton to content transition | Live region announces new content on load |
| Reduced motion | Skeleton shimmer replaced with static grey placeholder |
| Inline validation errors | Associated with their input field via semantics; announced on appearance |
| Snackbar errors | Announced via `liveRegion: true`; auto-dismiss after 4 seconds with manual dismiss available |
| Contrast ratios | All error and empty state text meets WCAG 2.1 AA (4.5:1 minimum for body text) |
| Tap targets | Retry button and CTA button meet 48x48 dp (Android) / 44x44 pt (iOS) minimum |