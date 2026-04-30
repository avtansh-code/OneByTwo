# Test Design — Coverage Plan

**Document owner:** QA Engineer
**Status:** Draft
**SRS version:** 1.1
**Last updated:** 2025

---

## 1. Test Pyramid Mapping

This section maps every screen (SCR-01 to SCR-28) and every Cloud Function to the
test pyramid levels defined in SRS section 10.1 and `.github/shared/test-strategy.md`.

### 1.1 Screens

| Target | Widget Tests | Unit Tests | Integration Tests | Manual Smoke |
|--------|-------------|------------|-------------------|--------------|
| SCR-01 Splash | Required | N/A | Required (CUJ-1) | Required (Tier 1) |
| SCR-02 Onboarding | Required | N/A | Required (CUJ-1) | Required (Tier 1) |
| SCR-03 Phone Entry | Required | Required (validation logic) | Required (CUJ-1) | Required (Tier 1) |
| SCR-04 OTP Verification | Required | Required (cooldown, retry logic) | Required (CUJ-1) | Required (Tier 1) |
| SCR-05 Profile Setup | Required | Required (name validation) | Required (CUJ-1) | Required (Tier 1) |
| SCR-06 Home Dashboard | Required | Required (balance aggregation, formatting) | Required (CUJ-1, CUJ-2, CUJ-3) | Required (Tier 1) |
| SCR-07 Search Overlay | Required | Required (search/filter logic) | Optional | Required (Tier 1) |
| SCR-08 Add Expense Entry | Required | N/A | Required (CUJ-2, CUJ-3) | Required (Tier 1) |
| SCR-09 Friends List | Required | Required (balance display logic) | Required (CUJ-2) | Required (Tier 1) |
| SCR-10 Add Friend | Required | Required (phone validation, contact matching) | Required (CUJ-2) | Required (Tier 1) |
| SCR-11 Friend Detail | Required | Required (balance formatting) | Required (CUJ-2) | Required (Tier 1) |
| SCR-12 Delete Friend | Required | Required (zero-balance guard) | Optional | Required (Tier 2) |
| SCR-13 Groups List | Required | Required (balance display logic) | Required (CUJ-3) | Required (Tier 1) |
| SCR-14 Create Group | Required | Required (group validation) | Required (CUJ-3) | Required (Tier 1) |
| SCR-15 Group Detail | Required | Required (balance formatting, member listing) | Required (CUJ-3, CUJ-4, CUJ-5) | Required (Tier 1) |
| SCR-16 Invite Members | Required | Required (invite link generation) | Required (CUJ-11) | Required (Tier 1) |
| SCR-17 Group Members | Required | N/A | Optional | Required (Tier 2) |
| SCR-18 Delete/Leave Group | Required | Required (zero-balance guard) | Optional | Required (Tier 2) |
| SCR-19 Add Expense (Amount) | Required | Required (paise conversion, validation) | Required (CUJ-2, CUJ-3) | Required (Tier 1) |
| SCR-20 Add Expense (Split) | Required | Required (split calculation, sum validation) | Required (CUJ-2, CUJ-3) | Required (Tier 1) |
| SCR-21 Add Expense (Receipt/Confirm) | Required | Required (receipt upload logic) | Required (CUJ-2, CUJ-3) | Required (Tier 1) |
| SCR-22 Edit/Delete Expense | Required | Required (edit diff, soft delete) | Required (CUJ-4, CUJ-5) | Required (Tier 1) |
| SCR-23 Settle Up | Required | Required (pre-fill logic from simplifiedBalances) | Required (CUJ-3) | Required (Tier 1) |
| SCR-24 Settlement History | Required | Required (history sorting, formatting) | Optional | Required (Tier 2) |
| SCR-25 Activity Feed | Required | Required (event mapping, deep-link routing) | Required (CUJ-4) | Required (Tier 1) |
| SCR-26 Profile | Required | Required (data binding) | Required (CUJ-10, CUJ-12) | Required (Tier 1) |
| SCR-27 Notification Prefs | Required | Required (preference toggling) | Optional | Required (Tier 2) |
| SCR-28 Support/Deletion | Required | Required (mailto URI construction, fallback) | Required (CUJ-10, CUJ-12) | Required (Tier 1) |

### 1.2 Cloud Functions

| Target | Unit Tests | Integration Tests | Manual Smoke |
|--------|-----------|-------------------|--------------|
| `recomputeSimplifiedBalances` | Required (100% branch coverage) | Required (CUJ-2 to CUJ-5, CUJ-7, CUJ-9) | Required (Tier 1) |
| `accountDeletion` | Required | Required (CUJ-10) | Required (Tier 1) |
| `groupInviteAcceptance` | Required | Required (CUJ-3) | Required (Tier 1) |
| FCM notification triggers | Required | Required (CUJ-6) | Required (Tier 1) |
| Reminder rate-limiter (FR-SE-09) | Required | Optional | Required (Tier 2) |

### 1.3 Non-UI Modules (Dart)

| Target | Unit Tests | Widget Tests | Integration Tests |
|--------|-----------|-------------|-------------------|
| Money utilities (paise/rupee conversion) | Required | N/A | N/A |
| Indian number formatter | Required | N/A | N/A |
| Split calculation engine | Required | N/A | Required (CUJ-2, CUJ-3) |
| Firestore repositories | Required | N/A | Required |
| Auth service | Required | N/A | Required (CUJ-1) |
| Offline queue manager | Required | N/A | Required (CUJ-7) |
| Deep-link resolver | Required | N/A | Required (CUJ-6) |
| Contact picker adapter | Required | N/A | Optional |
| Share sheet service | Required | N/A | Required (CUJ-11) |

---

## 2. Coverage Targets

Derived from SRS section 5.7 and `.github/shared/test-strategy.md`. All thresholds
are CI-enforced via the PR pipeline (SRS section 9.2.1).

### 2.1 Non-UI Code

**Target: >= 70% line coverage.**

Scope: repositories, services, models, algorithms, utilities, formatters, state
management providers, and all Cloud Functions TypeScript code.

Measured by: `flutter test --coverage` (Dart), `nyc` or `c8` (TypeScript).

Failure to meet this threshold shall block merge to `main`.

### 2.2 Overall Project

**Target: >= 50% line coverage.**

Scope: entire Flutter project including widget code and screen code.

Measured by: `flutter test --coverage` aggregated with `lcov`.

### 2.3 Simplified-Debts Module

**Target: 100% branch coverage of the canonical test matrix.**

Scope: `functions/src/simplifiedDebts.ts` and its pure-function core (SRS section 7.4).

This module has the highest blast radius in the system (SRS section 12.1) as it is
the sole debt mechanism. Every branch, including tie-breaking paths, must be exercised
by the canonical test matrix defined in section 3 below.

### 2.4 Firestore Security Rules

**Target: 100% rule coverage.**

Scope: `firestore.rules` — every `allow` and `deny` path must have at least one
positive and one negative test case (SRS section 10.4).

### 2.5 Coverage Regression Policy

No pull request may reduce coverage below these thresholds. The CI pipeline shall
compare coverage against the thresholds and fail the check if any threshold is
breached (SRS section 9.2.1, step 4).

---

## 3. Simplified-Debts Canonical Test Matrix

Source: SRS section 7.4, `.github/shared/test-strategy.md`.

The `recomputeSimplifiedBalances` Cloud Function and its pure-function core
(`simplifyDebts`) must pass all of the following test cases. These are mandatory
checks in the PR pipeline and must achieve 100% branch coverage of the algorithm.

### 3.1 Required Test Cases

| ID | Case | Input Description | Expected Outcome | Invariants Verified |
|----|------|-------------------|-------------------|---------------------|
| SD-01 | Empty input | No expenses, no settlements in the context. | `simplifiedBalances` is empty (no entries) or all values are zero. | Sum of all balances is zero. |
| SD-02 | Single member | One member, one self-paid expense (payer and sole split recipient are the same person). | No debts; `simplifiedBalances` is empty. | No self-transfers emitted. |
| SD-03 | Perfectly balanced | Three members, each paid one expense of equal value, split equally among all three. | No debts; `simplifiedBalances` is empty or all zeroes. | Net balance per member is zero. |
| SD-04 | Cyclic to zero | A owes B 100, B owes C 100, C owes A 100. Net balances are zero for all. | `simplifiedBalances` is empty. | Algorithm correctly cancels cyclic debts. |
| SD-05 | 3-person canonical | A pays 60000 paise (600 rupees) for A, B, C split equally (20000 paise each). | B owes A 20000 paise, C owes A 20000 paise. Two transfers only. | Splits sum to expense total in paise (invariant 1). All amounts are integers. |
| SD-06 | 5-person canonical | Mixed payers and splits across 5 members with varying amounts. | Minimised number of pairwise transfers. Deterministic tie-breaking by ascending `userId`. | Transfer count <= n-1. Tie-breaking is by ascending `userId`. All amounts are integer paise. |

### 3.2 Additional Required Edge Cases

| ID | Case | Input Description | Expected Outcome | Invariants Verified |
|----|------|-------------------|-------------------|---------------------|
| SD-07 | Tie-breaking determinism | Two or more creditors (or debtors) have identical net balances. | Tie is broken by ascending `userId` lexicographic order. Result is identical across multiple invocations. | Determinism guarantee (SRS section 7.4, step 5). |
| SD-08 | Float rejection | Input contains a monetary value that is not an integer (e.g., 100.5 paise). | Function rejects input or rounds to nearest integer before processing. Must never produce fractional paise in output. | Money is integer paise (invariant 1). |
| SD-09 | Single expense with settlement | A pays 30000 paise for A and B equally, then B settles 15000 paise to A. | `simplifiedBalances` is empty (fully settled). | Settlements correctly reduce balances. |
| SD-10 | Large group (50 members) | 50 members with varied expenses and settlements. | Computation completes within 500 ms (P95) (SRS section 5.2). Result is correct and deterministic. | Performance SLA. Minimised transfers. |

### 3.3 Verification Rules for All Cases

For every test case, the following assertions must hold:

1. The sum of all net balances across members equals zero.
2. Every amount in `simplifiedBalances` is a positive integer (no negative values,
   no fractional paise).
3. No self-transfers appear (a member does not owe themselves).
4. The number of transfers is at most n-1 (where n is the number of members with
   non-zero balances).
5. Re-running the function with identical input produces an identical result
   (idempotency).

---

## 4. Integration Test Suite

Each of the 12 Critical User Journeys defined in SRS section 10.2 is mapped to an
integration test specification below. All integration tests run against the Firebase
Emulator Suite (SRS section 9.1) — never against the production project
(invariant 4).

### 4.1 CUJ-1: First-Time User Onboarding

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_01_onboarding_test.dart` |
| **Emulator services** | Auth, Firestore |
| **Setup steps** | 1. Start Firebase Emulator Suite. 2. Clear Auth and Firestore emulator state. 3. Launch app in emulator mode. |
| **Test steps** | 1. Verify splash screen renders. 2. Swipe through onboarding carousel. 3. Enter valid +91 phone number on Phone Entry (SCR-03). 4. Submit and verify OTP screen appears (SCR-04). 5. Enter the emulator-provided OTP code. 6. Verify Profile Setup screen appears (SCR-05). 7. Enter display name "Test User". 8. Tap "Continue". 9. Verify Home Dashboard (SCR-06) renders with zero balances. |
| **Assertions** | Auth emulator confirms user is signed in. Firestore `users/{userId}` document exists with `displayName: "Test User"`. Home dashboard shows net balance of zero. |
| **Negative cases** | Enter invalid phone (e.g., 5 digits) — verify inline error, submit button disabled. Enter wrong OTP — verify error message, retry available. |
| **Tear-down** | Delete test user from Auth emulator. Clear Firestore emulator state. |

### 4.2 CUJ-2: Add Friend and Equally-Split Expense

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_02_friend_expense_test.dart` |
| **Emulator services** | Auth, Firestore, Functions |
| **Setup steps** | 1. Start emulators. 2. Create two test users (User A, User B) via Auth emulator. 3. Seed User B's profile in Firestore. 4. Sign in as User A. |
| **Test steps** | 1. Navigate to Friends List (SCR-09). 2. Add User B as a friend (SCR-10) using phone number. 3. Verify friendship document created in Firestore. 4. Navigate to Friend Detail (SCR-11). 5. Tap "Add Expense". 6. Enter amount 500 rupees (50000 paise). 7. Select "Split Equally". 8. Confirm and save. 9. Verify simplified balance updates on SCR-11. |
| **Assertions** | Friendship `simplifiedBalances` shows User B owes User A 25000 paise. Expense document in Firestore has `amountPaise: 50000`. Splits array sums to 50000 paise (invariant 1). `simplifiedBalances` was written by the Cloud Function, not the client (invariant 2). Home dashboard reflects updated balance. |
| **Negative cases** | Attempt to save expense with splits not summing to total — verify error is shown and save is blocked (FR-EX-04). |
| **Tear-down** | Delete friendship, expense, and test users. Clear emulator state. |

### 4.3 CUJ-3: Group with Unequal Split and Settlement

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_03_group_settle_test.dart` |
| **Emulator services** | Auth, Firestore, Functions |
| **Setup steps** | 1. Start emulators. 2. Create four test users (A, B, C, D). 3. Sign in as User A. |
| **Test steps** | 1. Create a group "Trip" with type "trip" (SCR-14). 2. Add users B, C, D to the group. 3. Add an expense of 10000 rupees (1000000 paise) paid by User A, split unequally: A=400000, B=300000, C=200000, D=100000 paise. 4. Verify simplified balances update. 5. Navigate to Settle Up (SCR-23) as User B. 6. Verify pre-filled amount matches simplified-debts suggestion. 7. Record settlement. 8. Verify simplified balances recompute and User B's debt is cleared. |
| **Assertions** | Group `simplifiedBalances` reflects correct debts after expense. After settlement by User B, User B's balance is reduced by the settlement amount. All amounts are integer paise. `simplifiedBalances` written only by Cloud Function. |
| **Negative cases** | Attempt unequal split where shares do not sum to total — verify save is blocked. |
| **Tear-down** | Delete group, expenses, settlements, test users. Clear emulator state. |

### 4.4 CUJ-4: Edit Expense

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_04_edit_expense_test.dart` |
| **Emulator services** | Auth, Firestore, Functions |
| **Setup steps** | 1. Start emulators. 2. Create two users and a friendship. 3. Create an equally-split expense of 40000 paise. 4. Sign in as the expense creator. |
| **Test steps** | 1. Navigate to the expense on SCR-22. 2. Edit amount from 40000 to 60000 paise. 3. Save changes. 4. Verify simplified balances recompute. 5. Navigate to Activity Feed (SCR-25). 6. Verify an "expense_edited" activity item appears. |
| **Assertions** | Updated expense document has `amountPaise: 60000`. Simplified balances reflect the new amount. Activity feed contains edit event with correct author and timestamp. Splits sum to new total (invariant 1). |
| **Negative cases** | Edit splits so they do not sum to total — verify save is blocked. |
| **Tear-down** | Delete expense, friendship, test users. Clear emulator state. |

### 4.5 CUJ-5: Delete Expense

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_05_delete_expense_test.dart` |
| **Emulator services** | Auth, Firestore, Functions |
| **Setup steps** | 1. Start emulators. 2. Create two users, friendship, and an equally-split expense of 50000 paise. 3. Sign in as expense creator. |
| **Test steps** | 1. Navigate to the expense. 2. Delete the expense (SCR-22). 3. Confirm deletion dialog. 4. Verify simplified balances recompute to zero. |
| **Assertions** | Expense document has `deleted: true` (soft delete). Simplified balances are empty or zero. Activity feed contains "expense_deleted" event. |
| **Negative cases** | N/A (deletion is a destructive action; the dialog confirmation is the guard). |
| **Tear-down** | Clear emulator state. |

### 4.6 CUJ-6: Push Notification and Deep-Link

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_06_notification_deeplink_test.dart` |
| **Emulator services** | Auth, Firestore, Functions |
| **Setup steps** | 1. Start emulators. 2. Create two users. 3. Sign in as User A. 4. Register FCM token in emulator. |
| **Test steps** | 1. As User B (via emulator seeding), create an expense involving User A. 2. Verify the FCM trigger fires (check Functions emulator logs). 3. Simulate a notification tap with the deep-link payload. 4. Verify the app navigates to the correct expense screen. 5. Repeat from a cold-start state. |
| **Assertions** | FCM message payload contains correct `contextType`, `contextId`, and `expenseId`. Deep-link resolves to the correct screen. Cold-start deep-link loads auth, then navigates to the target. |
| **Negative cases** | Deep-link with an invalid `expenseId` — verify error dialog appears (entity not found). |
| **Tear-down** | Clear emulator state. |

### 4.7 CUJ-7: Offline Expense and Sync

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_07_offline_sync_test.dart` |
| **Emulator services** | Auth, Firestore, Functions |
| **Setup steps** | 1. Start emulators. 2. Create two users and a friendship. 3. Sign in as User A. 4. Enable Firestore offline persistence. |
| **Test steps** | 1. Disable network connectivity (simulate offline). 2. Add an expense of 30000 paise, equally split. 3. Verify expense appears in local UI with a "pending sync" indicator. 4. Re-enable network connectivity. 5. Wait for sync to complete. 6. Verify the expense is written to Firestore emulator. 7. Verify simplified balances are recomputed by the Cloud Function. |
| **Assertions** | Expense document exists in Firestore after reconnection. `simplifiedBalances` is updated by the Cloud Function (invariant 2). Amounts are integer paise (invariant 1). |
| **Negative cases** | Two users edit the same expense offline — on reconnection, last-write-wins and the overridden user sees a notification (FR-OF-03). |
| **Tear-down** | Clear emulator state. |

### 4.8 CUJ-8: Dark Mode Legibility

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_08_dark_mode_test.dart` |
| **Emulator services** | Auth, Firestore |
| **Setup steps** | 1. Start emulators. 2. Create a test user with seeded data (friends, groups, expenses). 3. Set device theme to dark mode. |
| **Test steps** | 1. Navigate through every primary screen: SCR-06, SCR-09, SCR-11, SCR-13, SCR-15, SCR-19, SCR-20, SCR-23, SCR-25, SCR-26. 2. Capture screenshots of each screen. 3. Verify no illegible text, missing contrast, or invisible elements. |
| **Assertions** | All text meets WCAG 2.1 AA contrast ratios (>= 4.5:1) against dark backgrounds (SRS section 5.6). All interactive elements are visible and tappable. |
| **Negative cases** | N/A (visual verification). |
| **Tear-down** | Reset device theme. Clear emulator state. |

### 4.9 CUJ-9: Large-Data Performance

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_09_large_data_test.dart` |
| **Emulator services** | Auth, Firestore, Functions |
| **Setup steps** | 1. Start emulators. 2. Create a group with 10 members. 3. Seed 55+ expenses with varied payers and split methods. |
| **Test steps** | 1. Sign in as a group member. 2. Navigate to Group Detail (SCR-15). 3. Scroll through the expense list. 4. Measure scroll frame rate. 5. Trigger simplified-debts recomputation by adding a new expense. 6. Measure recomputation time. |
| **Assertions** | Scroll performance: no frame drops below 60 fps on Tier 1 devices (measured via Flutter DevTools). Simplified-debts computation completes within 500 ms (P95) (SRS section 5.2). Dashboard renders within 1.5 seconds (NFR-PE-03). |
| **Negative cases** | N/A (performance boundary test). |
| **Tear-down** | Clear emulator state. |

### 4.10 CUJ-10: Account Deletion

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_10_account_deletion_test.dart` |
| **Emulator services** | Auth, Firestore, Functions |
| **Setup steps** | 1. Start emulators. 2. Create User A with friends, groups, expenses, and settlements. 3. Ensure all balances are settled (zero). 4. Sign in as User A. |
| **Test steps** | 1. Navigate to Profile (SCR-26). 2. Navigate to Support/Deletion (SCR-28). 3. Trigger account deletion flow. 4. Confirm deletion. 5. Verify the Cloud Function fires. 6. Verify User A is signed out and redirected to the onboarding screen. |
| **Assertions** | User A's personal data in Firestore is anonymised or deleted. User A's Auth record is removed from the Auth emulator. Shared group documents retain anonymised references. The `accountDeletion` Cloud Function completed without error. |
| **Negative cases** | Attempt deletion with a non-zero balance — verify the flow is blocked (FR-GR-06). |
| **Tear-down** | Clear emulator state. |

### 4.11 CUJ-11: Share-Sheet Invite

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_11_share_invite_test.dart` |
| **Emulator services** | Auth, Firestore |
| **Setup steps** | 1. Start emulators. 2. Create User A and a group. 3. Sign in as User A. |
| **Test steps** | 1. Navigate to Invite Members (SCR-16). 2. Tap "Share Invite Link". 3. Verify the system share sheet is invoked (not a specific app). 4. Verify the shared text contains a valid deep link and install fallback URL. 5. Repeat for friend invite from SCR-10. |
| **Assertions** | The share intent uses the platform system share sheet only (invariant 3). Shared message contains a universal link (iOS) or App Link (Android). Link includes the correct group/friend identifier. No WhatsApp, Telegram, or other app-specific package is imported or targeted (invariant 3). |
| **Negative cases** | Verify that no `share_plus` target parameter or platform-specific share package is used in the codebase. |
| **Tear-down** | Clear emulator state. |

### 4.12 CUJ-12: Contact Support

| Field | Value |
|-------|-------|
| **Test name** | `integration_test/cuj_12_contact_support_test.dart` |
| **Emulator services** | Auth, Firestore |
| **Setup steps** | 1. Start emulators. 2. Create a test user. 3. Configure Remote Config emulator with support email address. 4. Sign in as test user. |
| **Test steps** | 1. Navigate to Profile (SCR-26). 2. Tap "Contact Support" (SCR-28). 3. Verify `mailto:` intent is fired with correct address from Remote Config. 4. Verify pre-filled body includes `userId`, app version, OS version, and device model. 5. Simulate "no mail client configured". 6. Verify fallback dialog appears with support email and a "Copy" button. |
| **Assertions** | `mailto:` URI contains the correct support address (from Remote Config, not hardcoded). Pre-filled body includes all required diagnostic fields (FR-PR-05). Fallback dialog appears when no mail client is available (FR-SH-04). "Copy" button places the email address on the clipboard. |
| **Negative cases** | Remote Config fetch failure — verify the app handles gracefully (cached value or error state). |
| **Tear-down** | Clear emulator state. |

---

## 5. Security Rules Tests

All security rules tests run against the Firestore Emulator using the
`@firebase/rules-unit-testing` library (SRS section 10.4). Each rule path has at
least one positive (allowed) and one negative (denied) test case.

### 5.1 User Document Rules (`users/{userId}`)

| ID | Test Case | Auth Context | Operation | Expected | SRS Reference |
|----|-----------|-------------|-----------|----------|---------------|
| SR-U-01 | Owner reads own profile | Authenticated as `userId` | `get users/{userId}` | Allow | 7.5 |
| SR-U-02 | Owner updates own profile | Authenticated as `userId` | `update users/{userId}` | Allow | 7.5 |
| SR-U-03 | Other user reads someone else's profile | Authenticated as different user | `get users/{otherUserId}` | Allow (public fields only) | 7.5 |
| SR-U-04 | Other user writes to someone else's profile | Authenticated as different user | `update users/{otherUserId}` | **Deny** | 7.5 |
| SR-U-05 | Unauthenticated read | Not authenticated | `get users/{userId}` | **Deny** | 5.4 |

### 5.2 Friendship Document Rules (`friendships/{friendshipId}`)

| ID | Test Case | Auth Context | Operation | Expected | SRS Reference |
|----|-----------|-------------|-----------|----------|---------------|
| SR-F-01 | Participant reads friendship | Authenticated as member in `memberIds` | `get friendships/{id}` | Allow | 7.5 |
| SR-F-02 | Non-participant reads friendship | Authenticated as non-member | `get friendships/{id}` | **Deny** | 7.5 |
| SR-F-03 | Participant writes to general fields | Authenticated as member | `update friendships/{id}` (non-simplifiedBalances fields) | Allow | 7.5 |
| SR-F-04 | Client writes to `simplifiedBalances` | Authenticated as member | `update friendships/{id}` with `simplifiedBalances` field | **Deny** | 7.3, 7.5, Invariant 2 |
| SR-F-05 | Unauthenticated read | Not authenticated | `get friendships/{id}` | **Deny** | 5.4 |

### 5.3 Group Document Rules (`groups/{groupId}`)

| ID | Test Case | Auth Context | Operation | Expected | SRS Reference |
|----|-----------|-------------|-----------|----------|---------------|
| SR-G-01 | Group member reads group | Authenticated as member in `memberIds` | `get groups/{id}` | Allow | 7.5 |
| SR-G-02 | Non-participant reads group | Authenticated as non-member | `get groups/{id}` | **Deny** | 7.5 |
| SR-G-03 | Admin updates group metadata | Authenticated as `adminId` | `update groups/{id}` (name, type, coverPhoto) | Allow | 7.5 |
| SR-G-04 | Client writes to `simplifiedBalances` on group | Authenticated as member | `update groups/{id}` with `simplifiedBalances` field | **Deny** | 7.3, 7.5, Invariant 2 |
| SR-G-05 | Non-member writes to group | Authenticated as non-member | `update groups/{id}` | **Deny** | 7.5 |

### 5.4 Expense Document Rules (`groups/{groupId}/expenses/{expenseId}`)

| ID | Test Case | Auth Context | Operation | Expected | SRS Reference |
|----|-----------|-------------|-----------|----------|---------------|
| SR-E-01 | Group member reads expense | Authenticated as group member | `get groups/{gid}/expenses/{eid}` | Allow | 7.5 |
| SR-E-02 | Non-participant reads expense | Authenticated as non-member | `get groups/{gid}/expenses/{eid}` | **Deny** | 7.5 |
| SR-E-03 | Member creates expense with valid splits | Authenticated as group member | `create groups/{gid}/expenses/{eid}` where sum of `splits[].sharePaise == amountPaise` | Allow | 7.5, FR-EX-04 |
| SR-E-04 | Splits do not sum to total | Authenticated as group member | `create groups/{gid}/expenses/{eid}` where sum of `splits[].sharePaise != amountPaise` | **Deny** | 7.5, FR-EX-04, Invariant 1 |
| SR-E-05 | Non-member creates expense | Authenticated as non-member | `create groups/{gid}/expenses/{eid}` | **Deny** | 7.5 |
| SR-E-06 | Creator edits own expense | Authenticated as `createdBy` | `update groups/{gid}/expenses/{eid}` | Allow | 7.5, FR-EX-06 |
| SR-E-07 | Non-creator edits expense | Authenticated as group member but not `createdBy` | `update groups/{gid}/expenses/{eid}` | **Deny** | 7.5 |

### 5.5 Settlement Document Rules (`settlements/{settlementId}`)

| ID | Test Case | Auth Context | Operation | Expected | SRS Reference |
|----|-----------|-------------|-----------|----------|---------------|
| SR-S-01 | Settler creates settlement where `fromUserId == auth.uid` | Authenticated as settler | `create settlements/{id}` | Allow | 7.5 |
| SR-S-02 | User creates settlement on behalf of another | Authenticated but `fromUserId != auth.uid` | `create settlements/{id}` | **Deny** | 7.5 |
| SR-S-03 | Participant reads settlement | Authenticated as `fromUserId` or `toUserId` | `get settlements/{id}` | Allow | 7.5 |
| SR-S-04 | Non-participant reads settlement | Authenticated as unrelated user | `get settlements/{id}` | **Deny** | 7.5 |

### 5.6 Activity Feed Rules (`activity/{userId}/items/{itemId}`)

| ID | Test Case | Auth Context | Operation | Expected | SRS Reference |
|----|-----------|-------------|-----------|----------|---------------|
| SR-A-01 | User reads own activity feed | Authenticated as `userId` | `list activity/{userId}/items` | Allow | 7.5 |
| SR-A-02 | User reads another user's activity feed | Authenticated as different user | `list activity/{otherUserId}/items` | **Deny** | 7.5 |
| SR-A-03 | Client writes to activity feed | Authenticated as `userId` | `create activity/{userId}/items/{id}` | **Deny** (server-only) | 7.5 |

### 5.7 Critical Invariant Tests (Cross-Cutting)

These tests verify the most critical security invariants and must always pass.

| ID | Test Case | Description | Expected | Invariant |
|----|-----------|-------------|----------|-----------|
| SR-INV-01 | Client cannot write `simplifiedBalances` on friendship | Any authenticated client attempts to set or modify the `simplifiedBalances` field on any friendship document. | **Deny** | Invariant 2 |
| SR-INV-02 | Client cannot write `simplifiedBalances` on group | Any authenticated client attempts to set or modify the `simplifiedBalances` field on any group document. | **Deny** | Invariant 2 |
| SR-INV-03 | Expense splits must sum to total | Security rule validates `sum(splits[].sharePaise) == amountPaise` on create and update. | **Deny** if mismatch | Invariant 1, FR-EX-04 |
| SR-INV-04 | Non-participant cannot read friendship | A user not in `memberIds` cannot read any field of a friendship document. | **Deny** | SRS 5.4, 7.5 |
| SR-INV-05 | Non-participant cannot read group | A user not in `memberIds` cannot read any field of a group document. | **Deny** | SRS 5.4, 7.5 |
| SR-INV-06 | Non-participant cannot read expense | A user who is not a member of the parent group/friendship cannot read expense subcollection documents. | **Deny** | SRS 5.4, 7.5 |
| SR-INV-07 | Monetary values are integers | Security rule validates that `amountPaise` and all `splits[].sharePaise` are integers (not floats). | **Deny** if any value is non-integer | Invariant 1 |

---

## 6. Device Matrix

Source: SRS section 10.3, `.github/shared/test-strategy.md`.

### 6.1 Tier Definitions

| Tier | Policy | Test Types Run |
|------|--------|----------------|
| Tier 1 (must pass) | All tests must pass. Release is blocked on any failure. | Unit tests, widget tests, integration tests (all 12 CUJs), manual smoke tests, accessibility walkthroughs (VoiceOver/TalkBack), performance profiling. |
| Tier 2 (should pass) | Tests should pass. Failures are triaged as S2 or S3 bugs. Release is not blocked but a fix must be planned. | Unit tests, widget tests, integration tests (CUJ-1, CUJ-2, CUJ-3, CUJ-8), manual smoke tests. |
| Tier 3 (best effort) | Best-effort testing. Failures are logged as S4 bugs for post-v1.0 backlog. | Manual smoke tests only. |

### 6.2 Device Assignments

| Tier | iOS Devices | Android Devices |
|------|-------------|-----------------|
| Tier 1 (must pass) | iPhone 12 (iOS 17), iPhone 14 (iOS 17) | Pixel 6 (Android 14), Samsung Galaxy A-series (Android 13) |
| Tier 2 (should pass) | iPhone SE 2nd generation (iOS 14) | Xiaomi Redmi (Android 11), Low-end OEM device (Android 8) |
| Tier 3 (best effort) | iPad in portrait orientation (post-v1.0) | Tablets (post-v1.0) |

### 6.3 Test Distribution

| Test Type | Where It Runs | Tier 1 | Tier 2 | Tier 3 |
|-----------|---------------|--------|--------|--------|
| Unit tests | CI (GitHub Actions) | Yes | Yes | N/A |
| Widget tests | CI (GitHub Actions) | Yes | Yes | N/A |
| Integration tests (emulator) | CI (GitHub Actions) | All 12 CUJs | CUJ-1, CUJ-2, CUJ-3, CUJ-8 | N/A |
| Security rules tests | CI (GitHub Actions) | Yes | N/A | N/A |
| Simplified-debts canonical matrix | CI (GitHub Actions) | Yes | N/A | N/A |
| Manual smoke tests | Real devices | Full pass | Focused pass | Exploratory |
| Performance profiling | Real devices + Flutter DevTools | Yes (NFR-PE-01 to NFR-PE-06) | Cold-start only | N/A |
| Accessibility walkthroughs | Real devices | VoiceOver + TalkBack | TalkBack only | N/A |
| Dark mode verification | Real devices | Yes (CUJ-8) | Yes | N/A |
| Pseudolocalisation pass | CI + Real devices | Yes | N/A | N/A |

### 6.4 Minimum OS Versions

Per SRS section 5.8:

- **iOS:** 14.0 (verified on Tier 2 iPhone SE 2nd gen)
- **Android:** API 26 / Android 8.0 (verified on Tier 2 low-end OEM)

### 6.5 Non-Functional Targets by Tier

| Metric | Target | Tier 1 | Tier 2 | SRS Reference |
|--------|--------|--------|--------|---------------|
| Cold-start launch time | <= 3 s (P95) | Must meet | Should meet | NFR-PE-01 |
| Warm-start launch time | <= 1 s (P95) | Must meet | Should meet | NFR-PE-02 |
| Dashboard render time | <= 1.5 s (P95) | Must meet | Best effort | NFR-PE-03 |
| Add-expense save round-trip | <= 2.5 s (P95) | Must meet | Best effort | NFR-PE-04 |
| Firestore read latency | <= 400 ms (P95) | Must meet | Best effort | NFR-PE-05 |
| App install size (Android) | <= 60 MB | Must meet | Must meet | NFR-PE-06 |
| App install size (iOS) | <= 90 MB | Must meet | Must meet | NFR-PE-06 |
| Crash-free user rate | >= 99.5% | Must meet | Must meet | SRS 5.3 |

---

*-- End of Document --*