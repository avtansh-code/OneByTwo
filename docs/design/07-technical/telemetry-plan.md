# Telemetry Plan — Firebase Analytics Events

> **Version:** 1.0
> **Last updated:** 2025-01-28
> **SRS authority:** `docs/OneByTwo_Requirements_Spec.md` section 5.10
> **Screen spec authority:** `docs/design/06-screen-specs/`

---

## 1. Event Catalogue

All events are logged via Firebase Analytics. No event payload may contain
personally identifiable information (PII). See [Privacy Rules](#3-privacy-rules)
below.

> **Implementation status.** This catalogue is a forward-looking plan. As of v1.0 the
> events actually emitted by the client are the expense family
> (`lib/features/expenses/application/expense_telemetry.dart`), the settle-up /
> settlement / settlement-history family (`lib/features/settlements/application/`), the
> reminder family (`lib/features/reminders/application/reminder_telemetry.dart`), the
> app-shell navigation events (`lib/features/shell/application/shell_telemetry.dart`),
> the notification-preferences events
> (`lib/features/profile/application/notification_preferences_telemetry.dart`), and the
> friends events (e.g. `friend_row_tapped`). Groups events (SCR-13–18) and
> account-lifecycle events (SCR-28) have **no producer yet** — those features are not
> built (groups is data-layer-only; account deletion is unimplemented). The
> repositories also emit structured **parse-failure** diagnostics not listed in the
> tables below: `friendship_parse_failure`, `settlement_parse_failure`, and
> `activity_parse_failure`.

### 1.1 SRS Section 5.10 — Core Funnel Events

These eight events are explicitly named in SRS section 5.10 as key funnel events.

| Event Name | Parameters | Parameter Types | Trigger | SRS / Screen Ref |
|---|---|---|---|---|
| `signup_started` | -- | -- | User taps Continue with a valid 10-digit number on the phone-entry screen (ADR-0007) | FR-AU-01; SCR-03 |
| `signup_completed` | `method` | `string` (`phone`) | OTP verified and session created for a first-time user | FR-AU-03; SCR-04 |
| `expense_save_succeeded` | `context_type`, `amount_range`, `category`, `split_method`, `participant_count`, `has_receipt`, `has_notes`, `is_offline` | `string`, `string`, `string`, `string`, `int`, `bool`, `bool`, `bool` | Expense successfully saved | FR-EX-01; SCR-21 |
| `settlement_recorded` | `context_type`, `amount_range`, `is_partial` | `string`, `string`, `bool` | Settlement successfully written | FR-SE-05; SCR-23 |
| `group_created` | `type`, `has_cover_photo` | `string`, `bool` | Group document created | FR-GR-01; SCR-14 |
| `friend_added` | `method` | `string` (`contacts` / `manual` / `invite`) | Friendship document created | FR-FR-01; SCR-10 |
| `simplified_balance_computed` | `member_count`, `duration_ms` | `int`, `int` | `recomputeSimplifiedBalances` Cloud Function completes | FR-SE-04 |
| `support_email_opened` | `method` | `string` (`mailto` / `fallback_dialog`) | Contact Support tapped | FR-PR-05; SCR-27 |

### 1.2 Auth and Onboarding Events

Source: `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md`

| Event Name | Parameters | Parameter Types | Trigger | Screen Ref |
|---|---|---|---|---|
| `app_launched` | `platform`, `app_version` | `string`, `string` | Cold-start splash screen mounts | SCR-01 |
| `splash_auth_check_started` | — | — | Auth state check begins | SCR-01 |
| `splash_auth_check_completed` | `result`, `duration_ms` | `string`, `int` | Auth state check resolves (`onboarding` / `phone` / `profile_setup` / `home`) | SCR-01 |
| `splash_auth_check_failed` | `error_type` | `string` | Auth state check fails (network error) | SCR-01 |
| `splash_retry_tapped` | `attempt_number` | `int` | User taps Retry in error state | SCR-01 |
| `onboarding_started` | — | — | Onboarding screen mounts (slide 1 displayed) | SCR-02 |
| `onboarding_slide_viewed` | `slide_index` | `int` (1, 2, or 3) | Each slide becomes visible | SCR-02 |
| `onboarding_skipped` | `skipped_from_slide` | `int` (1 or 2) | User taps Skip | SCR-02 |
| `onboarding_completed` | `slides_viewed` | `int` | User taps Get Started on slide 3 or completes onboarding flow and reaches home for the first time | SCR-02 |
| `phone_entry_viewed` | `source` | `string` (`splash` / `onboarding` / `otp_back`) | Phone-entry screen mounts | SCR-03 |
| `phone_number_submitted` | — | — | User taps Continue with 10 digits (phone number is NOT logged) | SCR-03 |
| `phone_validation_failed` | `reason` | `string` (`invalid_prefix` / `too_short`) | Client-side validation rejects the number | SCR-03 |
| `otp_send_requested` | — | — | `verifyPhoneNumber` called | SCR-03 |
| `otp_send_succeeded` | `duration_ms` | `int` | Firebase confirms OTP dispatched | SCR-03 |
| `otp_send_failed` | `error_code` | `string` | Firebase returns an error | SCR-03 |
| `otp_screen_viewed` | — | — | OTP screen mounts | SCR-04 |
| `otp_auto_read_started` | — | — | SMS Retriever begins listening (Android only) | SCR-04 |
| `otp_auto_read_succeeded` | `duration_ms` | `int` | SMS Retriever reads OTP | SCR-04 |
| `otp_auto_read_failed` | `error_type` | `string` | SMS Retriever times out or fails | SCR-04 |
| `otp_manual_entry_completed` | — | — | User manually enters all 6 digits | SCR-04 |
| `otp_verification_started` | `method` | `string` (`auto_read` / `manual` / `paste`) | `signInWithCredential` called | SCR-04 |
| `otp_verification_succeeded` | `is_new_user`, `duration_ms` | `bool`, `int` | Firebase confirms OTP valid | SCR-04 |
| `otp_verification_failed` | `error_code` | `string` | Firebase returns error | SCR-04 |
| `otp_resend_tapped` | `attempt_number` | `int` (1, 2, or 3) | User taps Resend OTP | SCR-04 |
| `otp_resend_exhausted` | — | — | Third resend attempt used | SCR-04 |
| `profile_setup_viewed` | `source` | `string` (`otp` / `splash`) | Profile setup screen mounts | SCR-05 |
| `profile_photo_picker_opened` | — | — | User taps the avatar or camera badge | SCR-05 |
| `profile_photo_selected` | `source` | `string` (`camera` / `gallery`) | User selects a photo | SCR-05 |
| `profile_photo_skipped` | — | — | User taps Continue without a photo | SCR-05 |
| `profile_save_requested` | `has_photo`, `name_length` | `bool`, `int` | User taps Continue with valid input | SCR-05 |
| `profile_save_succeeded` | `duration_ms` | `int` | Firestore write completes | SCR-05 |
| `profile_save_failed` | `error_code`, `error_source` | `string`, `string` (`firestore` / `storage`) | Firestore or Storage write fails | SCR-05 |

### 1.3 Home and Search Events

Source: `docs/design/06-screen-specs/06-08-home-and-search.md`

| Event Name | Parameters | Parameter Types | Trigger | Screen Ref |
|---|---|---|---|---|
| `home_viewed` | `net_balance_state` | `string` (`positive` / `negative` / `zero` / `loading` / `error`) | Home screen becomes visible | SCR-06 |
| `home_settle_up_tapped` | `context_type`, `amount_range` | `string`, `string` | User taps Settle Up on a top-balances tile | SCR-06 |
| `home_tile_tapped` | `context_type` | `string` (`friend` / `group`) | User taps a friend or group tile | SCR-06 |
| `home_empty_cta_tapped` | — | — | User taps Add Expense CTA in empty state | SCR-06 |
| `home_error_retry_tapped` | `attempt_number` | `int` | User taps Retry in error state | SCR-06 |
| `home_error_support_tapped` | `error_code` | `string` | User taps Contact Support in error state | SCR-06 |
| `home_spending_breakdown_viewed` | `category_count` | `int` (`0`–`8`) | First terminal render of the breakdown card (populated or empty), once per dashboard mount | SCR-06 |
| `search_opened` | `source` | `string` (`home` / `activity` / `other`) | Search overlay becomes visible | SCR-07 |
| `search_query_submitted` | `query_length`, `has_filters` | `int`, `bool` | Debounce fires after 300 ms pause | SCR-07 |
| `search_filter_applied` | `filter_type`, `filter_value` | `string`, `string` | User selects or deselects a filter chip | SCR-07 |
| `search_result_tapped` | `result_type`, `result_position` | `string`, `int` | User taps a result row | SCR-07 |
| `search_no_results` | `query_length`, `filters_active` | `int`, `int` | Query returns zero results | SCR-07 |
| `search_closed` | `had_query`, `result_count` | `bool`, `int` | User dismisses the search overlay | SCR-07 |
| `fab_tapped` | `source_tab` | `string` (`home` / `friends` / `groups` / `activity` / `profile`) | User taps the FAB | SCR-08 |
| `expense_context_selected` | `context_type` | `string` (`friend` / `group`) | User selects a friend or group in Step 1 of the add-expense flow | SCR-08 |
| `expense_split_method_selected` | `method` | `string` (`equal` / `unequal` / `percentage` / `shares` / `exact`) | User selects a split method in Step 3 | SCR-08 |
| `expense_add_cancelled` | `step_reached`, `had_data_entered` | `string`, `bool` | User dismisses the bottom sheet without saving | SCR-08 |
| `expense_save_failed` | `error_type`, `is_offline` | `string`, `bool` | Save attempt fails | SCR-08 |

### 1.4 Friends Events

Source: `docs/design/06-screen-specs/09-12-friends.md`

| Event Name | Parameters | Parameter Types | Trigger | Screen Ref |
|---|---|---|---|---|
| `friends_list_viewed` | `friend_count` | `int` | Friends list screen renders the populated or empty state for the first time (fires once per screen mount; rebuilds and snapshot updates do not duplicate the event) | SCR-09 |
| `friends_search_used` | `query_length` | `int` | User types at least 1 character into the search bar | SCR-09 |
| `friend_row_tapped` | `friendship_id_hash` | `string` (SHA-256 of the raw friendshipId, truncated to the first 16 hex chars; never the raw composite UID pair) | User taps a friend list tile | SCR-09 |
| `friends_empty_add_tapped` | — | — | User taps Add Friend CTA in empty state | SCR-09 |
| `add_friend_screen_viewed` | `entry_path` | `string` (`contacts` / `manual`) | Add-friend screen becomes visible | SCR-10 |
| `friend_invite_sent` | `method` | `string` (`contacts` / `manual`) | System share sheet opened for a non-user invite | SCR-10 |
| `contact_permission_denied` | — | — | Contact permission denied or revoked | SCR-10 |
| `friend_search_started` | — | — | User taps search field on add-friend screen | SCR-10 |
| `contact_permission_granted` | — | — | User grants contact access on add-friend screen | SCR-10 |
| `friend_detail_viewed` | `balance_state` | `string` (`owed` / `owes` / `settled`) | Friend detail screen becomes visible | SCR-11 |
| `settle_up_tapped` | `source` | `string` (`friend_detail`) | User taps the Settle Up CTA | SCR-11 |
| `friend_history_tapped` | — | — | User taps View full history | SCR-11 |
| `friend_delete_menu_tapped` | — | — | User taps Delete Friend in the overflow menu | SCR-11 |
| `friend_delete_dialog_shown` | `balance_state` | `string` (`zero` / `non_zero`) | Delete-friend dialog becomes visible | SCR-12 |
| `friend_deleted` | — | — | Friendship document successfully deleted | SCR-12 |
| `friend_delete_blocked` | — | — | Non-zero balance dialog shown | SCR-12 |
| `friend_delete_failed` | `error_code` | `string` | Deletion attempt fails | SCR-12 |

### 1.5 Groups Events

Source: `docs/design/06-screen-specs/13-18-groups.md`

| Event Name | Parameters | Parameter Types | Trigger | Screen Ref |
|---|---|---|---|---|
| `groups_list_viewed` | `group_count` | `int` | Groups list screen becomes visible | SCR-13 |
| `group_tile_tapped` | `group_type` | `string` | User taps a group tile | SCR-13 |
| `create_group_fab_tapped` | — | — | User taps the FAB on Groups list | SCR-13 |
| `groups_search_tapped` | — | — | User taps the search action | SCR-13 |
| `create_group_started` | — | — | Create Group screen becomes visible | SCR-14 |
| `create_group_failed` | `error_code` | `string` | Group creation request fails | SCR-14 |
| `group_photo_uploaded` | `file_size_bytes` | `int` | Cover photo uploaded | SCR-14 |
| `group_detail_viewed` | `group_type`, `member_count` | `string`, `int` | Group detail screen becomes visible | SCR-15 |
| `group_tab_switched` | `tab_name` | `string` | User switches tab on group detail | SCR-15 |
| `group_expense_tapped` | — | — | User taps an expense tile in the group | SCR-15 |
| `group_settle_up_tapped` | `source` | `string` (`group_detail`) | User taps a Settle Up CTA | SCR-15 |
| `group_add_expense_fab_tapped` | — | — | User taps the FAB on group detail | SCR-15 |
| `invite_members_viewed` | — | — | Invite Members screen becomes visible | SCR-16 |
| `invite_contact_picker_opened` | — | — | User taps Select from contacts | SCR-16 |
| `invite_sent_contact` | `is_existing_user` | `bool` | Invite sent via contact picker | SCR-16 |
| `invite_sent_phone` | `is_existing_user` | `bool` | Invite sent via manual phone entry | SCR-16 |
| `invite_link_shared` | — | — | System share sheet opened with invite link | SCR-16 |
| `invite_link_revoked` | — | — | Admin revokes an active link | SCR-16 |
| `group_members_viewed` | `member_count`, `is_admin` | `int`, `bool` | Manage Members screen becomes visible | SCR-17 |
| `group_member_removed` | — | — | Admin successfully removes a member | SCR-17 |
| `group_member_remove_blocked` | — | — | Admin attempts to remove a member with a non-zero balance | SCR-17 |
| `group_left` | — | — | User successfully leaves the group | SCR-17, SCR-18 |
| `group_leave_blocked` | — | — | User attempts to leave with a non-zero balance | SCR-17, SCR-18 |
| `group_delete_dialog_shown` | `is_permitted` | `bool` | Delete dialog becomes visible | SCR-18 |
| `group_deleted` | `member_count` | `int` | Group successfully deleted | SCR-18 |
| `group_delete_blocked` | — | — | Delete blocked due to non-zero balances | SCR-18 |
| `group_delete_failed` | `error_code` | `string` | Delete request fails | SCR-18 |
| `group_leave_dialog_shown` | `is_permitted` | `bool` | Leave dialog becomes visible | SCR-18 |
| `group_leave_failed` | `error_code` | `string` | Leave request fails | SCR-18 |

### 1.6 Expense Flow Events

Source: `docs/design/06-screen-specs/19-22-expenses.md`

| Event Name | Parameters | Parameter Types | Trigger | Screen Ref |
|---|---|---|---|---|
| `expense_step1_opened` | `context_type`, `entry_point` | `string`, `string` (`fab` / `friend_detail` / `group_detail` / `empty_state`) | Step 1 sheet becomes visible | SCR-19 |
| `expense_step1_completed` | `amount_range`, `category`, `has_notes` | `string`, `string`, `bool` | User taps Next and validation passes | SCR-19 |
| `expense_step1_abandoned` | `fields_filled_count`, `time_spent_ms` | `int`, `int` | User dismisses the sheet from step 1 | SCR-19 |
| `expense_category_selected` | `category` | `string` | User taps a category chip | SCR-19 |
| `expense_step2_opened` | `split_method`, `participant_count` | `string`, `int` | Step 2 sheet becomes visible | SCR-20 |
| `expense_split_method_changed` | `from_method`, `to_method` | `string`, `string` | User selects a different split method | SCR-20 |
| `expense_payer_changed` | `payer_is_self` | `bool` | User changes the payer | SCR-20 |
| `expense_step2_completed` | `split_method`, `participant_count`, `payer_is_self` | `string`, `int`, `bool` | User taps Next and validation passes | SCR-20 |
| `expense_split_validation_failed` | `split_method`, `direction` | `string`, `string` (`under` / `over`) | User taps Next but splits do not sum to total | SCR-20 |
| `expense_step2_abandoned` | `split_method`, `time_spent_ms` | `string`, `int` | User dismisses the sheet from step 2 | SCR-20 |
| `expense_step3_opened` | `has_receipt_from_edit` | `bool` | Step 3 sheet becomes visible | SCR-21 |
| `expense_receipt_attached` | `source`, `file_size_bytes` | `string` (`camera` / `gallery`), `int` | User attaches a receipt image | SCR-21 |
| `expense_receipt_removed` | — | — | User removes an attached receipt | SCR-21 |
| `expense_save_failed` | `error_code`, `retry_count` | `string`, `int` | Save operation fails | SCR-21 |
| `expense_step3_abandoned` | `had_receipt`, `time_spent_ms` | `bool`, `int` | User dismisses the sheet from step 3 | SCR-21 |
| `expense_edit_opened` | `context_type` | `string` | Edit sheet becomes visible | SCR-22 |
| `expense_edit_field_changed` | `field_name` | `string` (`amount` / `description` / `category` / `split_method`) | User modifies a field from its original value | SCR-22 |
| `expense_edit_saved` | `fields_changed`, `split_method` | `string` (comma-delimited list), `string` | Edit successfully saved | SCR-22 |
| `expense_edit_failed` | `error_code` | `string` | Edit save fails | SCR-22 |
| `expense_edit_abandoned` | `had_changes`, `time_spent_ms` | `bool`, `int` | User dismisses the edit sheet without saving | SCR-22 |
| `expense_delete_initiated` | `context_type` | `string` | User taps Delete on Expense Detail (dialog opens) | SCR-22 |
| `expense_delete_confirmed` | `amount_range`, `participant_count` | `string`, `int` | User confirms deletion in the dialog | SCR-22 |
| `expense_delete_cancelled` | — | — | User cancels the deletion dialog | SCR-22 |
| `expense_delete_failed` | `error_code` | `string` | Deletion fails | SCR-22 |

### 1.7 Settle Up, Activity, and Profile Events

Source: `docs/design/06-screen-specs/23-28-settle-activity-profile.md`

| Event Name | Parameters | Parameter Types | Trigger | Screen Ref |
|---|---|---|---|---|
| `settle_up_screen_viewed` | `context_type`, `source` | `string`, `string` (`home` / `friend_detail` / `group_detail`) | Settle Up screen opened | SCR-23 |
| `settle_up_error` | `error_code`, `context_type` | `string`, `string` | Settlement write fails | SCR-23 |
| `settlement_history_viewed` | `context_type`, `item_count` | `string`, `int` | Settlement history screen loaded with data | SCR-24 |
| `settlement_history_error` | `error_code`, `context_type` | `string`, `string` | Data fetch fails | SCR-24 |
| `activity_feed_viewed` | `item_count` | `int` | Activity feed screen opened with populated data | SCR-25 |
| `activity_item_tapped` | `event_type` | `string` | User taps an activity row | SCR-25 |
| `activity_feed_refreshed` | `success` | `bool` | Pull-to-refresh completed | SCR-25 |
| `activity_feed_error` | `error_code` | `string` | Data fetch fails | SCR-25 |
| `profile_viewed` | — | — | Profile View screen opened | SCR-26 |
| `profile_edited` | `fields_changed` | `string` (comma-delimited list) | Profile saved successfully | SCR-26 |
| `profile_photo_changed` | `action` | `string` (`take` / `choose` / `remove`) | Photo change completed | SCR-26 |
| `profile_friends_tapped` | — | — | User taps the "My Friends" stats row (FR-PR-04); switches to the Friends tab (index 1). Parameter-free — a friend count is non-identifying. | SCR-26 |
| `profile_groups_tapped` | — | — | User taps the "My Groups" stats row (FR-PR-04); switches to the Groups tab (index 2). Parameter-free. | SCR-26 |
| `phone_change_started` | — | — | User opens the Change Phone Number flow from Edit Profile (FR-PR-02). Parameter-free; the number is never logged. | SCR-26 |
| `phone_change_otp_requested` | `leg` | `string` (`reauth` / `new_number`) | An OTP is requested for the re-authentication leg (current number) or the new-number leg. No phone number is logged. | SCR-26 |
| `phone_change_completed` | — | — | `updatePhoneNumber` succeeds and the `users/{uid}.phoneNumber` write completes. Parameter-free. | SCR-26 |
| `phone_change_failed` | `error_code` | `string` (the `AuthError` name, e.g. `invalidOtp` / `credentialInUse` / `requiresRecentLogin` / `networkFailure`, or `sync_failed`) | A Firebase or Firestore step fails after an OTP was requested. Mirrors the `otp_send_failed` / `otp_verification_failed` `error_code` convention (the `AuthError.name`); never carries PII. | SCR-26 |
| `sign_out_completed` | — | — | User signs out successfully | SCR-26 |
| `sign_out_cancelled` | — | — | User cancels sign-out dialog | SCR-26 |
| `notification_prefs_viewed` | — | — | Notification Preferences screen opened | SCR-27 |
| `notification_pref_changed` | `category`, `enabled` | `string` (`newExpense` / `settlement` / `reminder`), `bool` | Toggle changed and persisted | SCR-27 |
| `notification_pref_error` | `category`, `error_code` | `string`, `string` | Toggle save fails | SCR-27 |
| `support_email_copied` | — | — | User copies address from fallback dialog | SCR-27 |
| `delete_account_started` | — | — | User taps Delete Account row on Profile View | SCR-28 |
| `delete_account_warning_continued` | — | — | User taps Continue on Step A | SCR-28 |
| `delete_account_warning_cancelled` | — | — | User taps Cancel on Step A | SCR-28 |
| `delete_account_reauth_completed` | — | — | OTP verified in Step B | SCR-28 |
| `delete_account_confirmed` | — | — | User taps Delete My Account in Step C | SCR-28 |
| `delete_account_completed` | — | — | Cloud Function returns success | SCR-28 |
| `delete_account_failed` | `error_code` | `string` | Cloud Function returns error or times out | SCR-28 |

### 1.8 Cross-Cutting Events

These events are not tied to a single screen. They are derived from the SRS
section 5.10 observability requirements and from patterns observed across
multiple screen specs (error states per SRS section 6.4, deep links, sharing
via system share sheet per SRS section 3.4 / Invariant 3).

| Event Name | Parameters | Parameter Types | Trigger | SRS / Screen Ref |
|---|---|---|---|---|
| `error_shown` | `screen`, `error_type` | `string`, `string` | Error state rendered on any screen | SRS section 6.4 |
| `retry_tapped` | `screen`, `attempt_number` | `string`, `int` | Retry button tapped on any error state | SRS section 6.4 |
| `deep_link_opened` | `source`, `destination` | `string`, `string` | Deep link resolved and navigation completed | SRS section 4.11 |
| `share_invite_sent` | `context_type` | `string` (`friend` / `group`) | System share sheet invoked for an invite | SRS section 3.4; SCR-10, SCR-16 |
| `notification_permission_granted` | — | — | User grants push notification permission | SRS section 4.10 |
| `notification_permission_denied` | — | — | User denies push notification permission | SRS section 4.10 |
| `dark_mode_toggled` | `mode` | `string` (`light` / `dark`) | Theme changes (manual toggle, if implemented) | SRS section 6.2 |
| `bottom_nav_tab_selected` | `tab_index`, `tab_label` | `int` (0..4), `string` (`home` / `friends` / `groups` / `activity` / `profile`) | User taps a tab in `OBTBottomNav`. Fires on every tap (including taps on the already-active tab). Does NOT fire on programmatic switches (Android back-button snap-to-zero, FCM deep-link tab switches). | `components.md §2`; `navigation-flow.md §1` MainTabs subgraph |

---

## 2. Parameter Sanitisation Rules

To comply with [Privacy Rules](#3-privacy-rules), certain raw values must be
transformed before logging.

### 2.1 Amount Ranges

All monetary amounts are stored as integer paise (Invariant 1; SRS section 7.3).
Raw `amount_paise` values must **never** appear in analytics events. Instead, map
to a bucketed `amount_range` string:

| Bucket | Range (paise) | Range (INR equivalent) |
|---|---|---|
| `under_500` | 0–49999 | Under 500 |
| `500_5000` | 50000–499999 | 500–4,999 |
| `5000_25000` | 500000–2499999 | 5,000–24,999 |
| `over_25000` | 2500000+ | 25,000+ |

This bucketing applies to all events that reference amounts: `expense_save_succeeded`,
`expense_step1_completed`, `settlement_recorded`, `expense_delete_confirmed`,
`home_settle_up_tapped`.

### 2.2 Document Identifiers

Identifiers that derive from user UIDs — notably `friendshipId`, the sorted
`{uidA}_{uidB}` composite — are PII-adjacent and must never be emitted raw. The
implemented approach is to **hash and emit** them, **not** to exclude them. The client
helper `lib/core/telemetry/event_id_hash.dart` (`hashId` / `hashFriendshipId`) and the
server helper `functions/src/utils/id-hash.ts` (`hashId`) both apply SHA-256 truncated
to the first **16 hex characters (64 bits)**.

Per ADR-0013 the emitted parameter name appends a `_hash` suffix so consumers know the
value is hashed — e.g. `friendship_id_hash`, `expense_id_hash`, `settlement_id_hash`.
These hashed parameters appear in events in **all** builds (debug and production); the
raw identifier is never emitted in any build. There is no debug-only or
production-stripped behaviour.

The catalogue tables above already reflect this convention — see `friend_row_tapped`
(`friendship_id_hash`) in section 1.4 and the expense and settlement event families,
which carry `friendship_id_hash`, `expense_id_hash`, and `settlement_id_hash`.

---

## 3. Privacy Rules

These rules are non-negotiable. Violation is a blocking defect.

1. **No PII in any event.** Phone numbers, display names, user IDs, email
   addresses, and any other personally identifiable information must never appear
   in event parameters. — SRS section 5.10; General Data Protection principles.

2. **Amount ranges, not exact amounts.** All monetary values are bucketed into
   ranges (see section 2.1). Exact paise values must not be logged. This prevents
   inference of personal financial behaviour from analytics data.

3. **No free-text user input.** Notes, descriptions, group names, and similar
   user-authored content must never be included in event parameters.

4. **Timestamps are implicit.** Firebase Analytics automatically records event
   timestamps. Do not add a redundant `timestamp` parameter to events. The
   screen specs list `timestamp` for completeness, but implementation should rely
   on the Firebase-managed timestamp.

5. **Boolean and enum parameters only where possible.** Prefer constrained
   parameter values (`string` enums, `bool`, `int` counts) over free-form
   strings to keep the analytics namespace clean and queryable.

---

## 4. Dashboards

The following Firebase Analytics dashboards (or BigQuery views, if exported)
should be configured for v1.0 monitoring.

### 4.1 Signup Funnel

Measures conversion from first app launch to active user.

```
app_launched
  → onboarding_started
    → signup_started
      → otp_verification_succeeded
        → signup_completed
          → profile_save_succeeded
            → onboarding_completed (reaches home for the first time)
```

**Key metrics:**
- Drop-off rate at each step.
- Median `duration_ms` for OTP send and verification.
- OTP resend rate (`otp_resend_tapped` count / `otp_send_requested` count).

### 4.2 Expense Funnel

Measures the add-expense flow completion rate.

```
fab_tapped
  → expense_step1_opened
    → expense_step1_completed
      → expense_step2_completed
        → expense_step3_opened
          → expense_save_succeeded
```

**Key metrics:**
- Abandonment rate per step (`expense_step[N]_abandoned` / `expense_step[N]_opened`).
- Most common split methods selected (`split_method` parameter distribution).
- Receipt attachment rate (`has_receipt` = `true` / total `expense_save_succeeded`).
- Category distribution.

### 4.3 Settlement Funnel

Measures settle-up flow completion.

```
settle_up_screen_viewed (with source parameter)
  → settlement_recorded
```

**Key metrics:**
- Conversion rate from view to recorded.
- Partial versus full settlement ratio (`is_partial` distribution).
- Source distribution (`home` / `friend_detail` / `group_detail`).

### 4.4 Retention Cohorts

Cohorts defined by `signup_completed` date. Track:

- Day-1, Day-7, Day-30 retention (measured by any `home_viewed` event).
- Weekly active users (any event within a 7-day window).
- Expense creation frequency per cohort.

### 4.5 Error Monitoring

```
error_shown → retry_tapped (optional) → [resolution or support_email_opened]
```

**Key metrics:**
- Error rate by screen (`error_shown.screen` parameter distribution).
- Retry success rate (`retry_tapped` followed by a successful load event).
- Support escalation rate (`support_email_opened` / `error_shown`).

### 4.6 Account Lifecycle

```
delete_account_started
  → delete_account_warning_continued
    → delete_account_reauth_completed
      → delete_account_confirmed
        → delete_account_completed
```

**Key metrics:**
- Drop-off at each deletion step (measures friction effectiveness).
- Cancellation rate at the warning step.

---

## 5. Implementation Notes

1. **Firebase Analytics SDK.** All events are logged via the `firebase_analytics`
   Flutter package on the client and via the Firebase Admin SDK in Cloud Functions
   (for `simplified_balance_computed` only). — SRS section 5.10.

2. **Event naming convention.** All event names use `snake_case`. Parameter names
   use `snake_case`. This aligns with Firebase Analytics conventions and avoids
   issues with BigQuery export column naming.

3. **Custom dimensions.** Parameters such as `context_type`, `split_method`,
   `category`, and `source` should be registered as custom dimensions in the
   Firebase Console to enable filtering and breakdown in reports.

4. **Debug mode.** During development against the Firebase Emulator Suite
   (Invariant 4; SRS section 3.4), analytics events should be logged to the
   debug console only. The emulator does not support Analytics; use
   `FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false)` when
   running against emulators, and log events to `stdout` instead.

5. **Event volume.** Firebase Analytics has a limit of 500 distinct event names
   per project. The catalogue above contains approximately 120 distinct events,
   well within this limit. New events should be added conservatively.

6. **Crashlytics integration.** Errors logged via `error_shown` should also be
   recorded as non-fatal exceptions in Firebase Crashlytics with the same
   `screen` and `error_type` parameters, providing a correlated view across
   Analytics and Crashlytics dashboards. — SRS section 5.10.

---

## 6. References

| Reference | Location |
|---|---|
| SRS section 5.10 (Observability) | `docs/OneByTwo_Requirements_Spec.md`, line 349 |
| SRS section 3.4 (Constraints) | `docs/OneByTwo_Requirements_Spec.md` |
| SRS section 6.4 (Error states) | `docs/OneByTwo_Requirements_Spec.md` |
| SRS section 7.3 (Data model — integer paise) | `docs/OneByTwo_Requirements_Spec.md` |
| Invariant 1 (Money is integer paise) | `.github/shared/invariants.md` |
| Invariant 3 (System share sheet only) | `.github/shared/invariants.md` |
| Invariant 4 (Single Firebase project) | `.github/shared/invariants.md` |
| Screen specs SCR-01 to SCR-05 | `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` |
| Screen specs SCR-06 to SCR-08 | `docs/design/06-screen-specs/06-08-home-and-search.md` |
| Screen specs SCR-09 to SCR-12 | `docs/design/06-screen-specs/09-12-friends.md` |
| Screen specs SCR-13 to SCR-18 | `docs/design/06-screen-specs/13-18-groups.md` |
| Screen specs SCR-19 to SCR-22 | `docs/design/06-screen-specs/19-22-expenses.md` |
| Screen specs SCR-23 to SCR-28 | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` |
