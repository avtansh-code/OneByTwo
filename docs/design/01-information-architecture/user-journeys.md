# User Journeys

Information Architecture phase -- Critical User Journeys mapped to SRS
functional requirements with step-by-step happy paths.

**Source:** SRS sections 4, 6.3, 10.2 (docs/OneByTwo_Requirements_Spec.md v1.1)
and `.github/shared/test-strategy.md`.

---

## CUJ-01 -- First-Time User: Onboarding to Home Dashboard

**Title:** First-time user: onboarding, phone OTP, profile setup, home dashboard.

**SRS Requirements Exercised:**
FR-AU-01, FR-AU-02, FR-AU-03, FR-AU-04, FR-AU-05, FR-AU-06, FR-AU-07,
FR-HD-01, FR-HD-02, FR-HD-04.

**Step-by-Step Happy Path:**

1. User launches the app for the first time. The Splash screen displays the One By Two brand mark whilst the app initialises (SRS section 6.3, screen 1).
2. App detects no authenticated session (FR-AU-07) and navigates to the Onboarding carousel -- three illustrated slides explaining the value proposition (SRS section 6.3, screen 1).
3. User swipes through all three onboarding slides and taps "Get Started".
4. App navigates to the Phone Number Entry screen with the +91 prefix locked and non-editable (FR-AU-01; SRS section 6.3, screen 2).
5. User enters a 10-digit Indian mobile number. The app validates the format inline (FR-AU-02) and enables the "Continue" button.
6. User taps "Continue". The app triggers Firebase Phone Auth to send a 6-digit OTP via SMS (FR-AU-03) and navigates to the OTP Verification screen (SRS section 6.3, screen 3).
7. On Android, the app auto-reads the OTP via SMS Retriever; on iOS, the user enters the code manually (FR-AU-04). The 30-second resend cooldown is visible (FR-AU-05).
8. Upon successful OTP verification, the app detects this is a first login and navigates to the Profile Setup screen (FR-AU-06; SRS section 6.3, screen 4).
9. User enters a display name (required) and optionally uploads a profile photo from their gallery or camera.
10. User taps "Done". The app persists the session (FR-AU-07), writes the user profile to Firestore, and navigates to the Home Dashboard (SRS section 6.3, screen 5).
11. Home Dashboard renders the net simplified balance summary (FR-HD-01), an empty top-friends/groups section (FR-HD-02), and the persistent floating action button for adding expenses (FR-HD-04).

---

## CUJ-02 -- Add Friend and Equally-Split Expense

**Title:** Add friend by contact, add equally-split expense, see simplified balance update.

**SRS Requirements Exercised:**
FR-FR-01, FR-FR-02, FR-FR-03, FR-FR-04, FR-SE-01, FR-SE-03, FR-SE-04,
FR-EX-01, FR-EX-02, FR-EX-03, FR-EX-04, FR-EX-09, FR-HD-01.

**Step-by-Step Happy Path:**

1. User is on the Home Dashboard (SRS section 6.3, screen 5). User navigates to the Friends List screen (SRS section 6.3, screen 6).
2. User taps "Add Friend". The app presents the device contact picker (FR-FR-01).
3. User selects a contact who is already a registered One By Two user. The app links the friendship immediately (FR-FR-02) and navigates to the Friend Detail screen (SRS section 6.3, screen 6).
4. The Friend Detail screen shows the current simplified balance as "settled up" (FR-FR-03) and an empty transaction history (FR-FR-04).
5. User taps the floating action button to add a new expense. The Add Expense bottom sheet opens in the friend context (FR-EX-02; SRS section 6.3, screen 8).
6. User enters the amount in rupees (displayed with the Indian numbering system and the rupee symbol -- FR-EX-09), a description, a date, and selects a category (FR-EX-01).
7. User selects "Equally" as the split method (FR-EX-03). The app shows the split preview: each participant owes half the total.
8. The app validates that the splits sum exactly to the expense total in paise (FR-EX-04). The "Save" button is enabled.
9. User taps "Save". The app writes the expense to Firestore. The `recomputeSimplifiedBalances` Cloud Function fires, computes the new simplified debts, and writes the result to the friendship document (FR-SE-03, FR-SE-04).
10. The Friend Detail screen updates in real time to show the new simplified balance -- e.g., "Friend owes you X" (FR-FR-03, FR-SE-01).
11. User navigates back to the Home Dashboard, which now reflects the updated net simplified balance (FR-HD-01).

---

## CUJ-03 -- Group Expense with Unequal Split and Settlement

**Title:** Create a group of 4, add an expense with unequal split, settle one member using the simplified-debts suggestion.

**SRS Requirements Exercised:**
FR-GR-01, FR-GR-02, FR-GR-04, FR-EX-01, FR-EX-02, FR-EX-03, FR-EX-04,
FR-EX-09, FR-SE-01, FR-SE-02, FR-SE-03, FR-SE-04, FR-SE-05, FR-SE-06,
FR-SE-07, FR-SE-08.

**Step-by-Step Happy Path:**

1. User navigates from the Home Dashboard to the Groups List screen (SRS section 6.3, screen 7).
2. User taps "Create Group". The app presents the group creation form. User enters a group name, selects the type "Trip" (FR-GR-01), and optionally adds a cover photo.
3. User adds three other members via the contact picker or by entering +91 phone numbers (FR-GR-02). All three are existing One By Two users.
4. User taps "Create". The app writes the group document and navigates to the Group Detail screen (SRS section 6.3, screen 7).
5. Group Detail shows four members, all simplified balances at zero, and an empty expense list (FR-GR-04).
6. User taps the floating action button to add an expense within the group context (FR-EX-02; SRS section 6.3, screen 8).
7. User enters amount, description, date, and category (FR-EX-01). User selects "Unequal (by amount)" as the split method (FR-EX-03) and manually assigns different amounts to each of the four members.
8. The app validates that the four split amounts sum exactly to the expense total (FR-EX-04). User taps "Save".
9. The `recomputeSimplifiedBalances` Cloud Function fires, minimises the pairwise transactions for the group (FR-SE-02), and writes the result (FR-SE-03, FR-SE-04).
10. Group Detail refreshes to show each member's simplified balance. A "Settle Up" call-to-action is visible next to each non-zero balance (FR-SE-07, FR-SE-01).
11. User taps "Settle Up" next to one member. The Settle Up flow opens (SRS section 6.3, screen 9), pre-filled with the recipient and the amount suggested by the simplified-debts algorithm (FR-SE-05).
12. User confirms the settlement details and taps "Record Settlement". The settlement is written, and the Cloud Function recomputes simplified balances in real time for all group members (FR-SE-06).
13. Group Detail updates: the settled member's balance is now zero, and the remaining balances are adjusted accordingly (FR-GR-04). The settlement appears in the group's settlement history (FR-SE-08).

---

## CUJ-04 -- Edit Existing Expense

**Title:** Edit an existing expense; verify simplified balances and activity feed update for all participants.

**SRS Requirements Exercised:**
FR-EX-06, FR-EX-07, FR-EX-01, FR-EX-04, FR-SE-04, FR-SE-01,
FR-AC-01, FR-AC-02, FR-AC-03.

**Step-by-Step Happy Path:**

1. User navigates to a Friend Detail or Group Detail screen that contains at least one existing expense (SRS section 6.3, screens 6 or 7).
2. User taps on an expense to view its details. The expense detail view shows the current amount, description, payer, splits, and category.
3. User taps "Edit". The Add/Edit Expense bottom sheet opens pre-populated with the existing values (SRS section 6.3, screen 8; FR-EX-06).
4. User changes the amount and adjusts the split allocations accordingly.
5. The app validates that the updated splits sum exactly to the new expense total (FR-EX-04). The "Save" button is enabled.
6. User taps "Save". The app writes the updated expense. The `recomputeSimplifiedBalances` Cloud Function fires and recomputes the simplified balances atomically (FR-SE-04).
7. The detail screen updates to show the revised simplified balances for all participants (FR-SE-01).
8. The edit is recorded in the Activity Feed with the author and timestamp (FR-EX-07). User navigates to the Activity Feed screen (SRS section 6.3, screen 10; FR-AC-01) and confirms the edit event appears.
9. User taps on the activity item. The app deep-links to the edited expense detail (FR-AC-02).
10. Other participants receive a push notification about the expense edit (FR-AC-03).

---

## CUJ-05 -- Delete Expense

**Title:** Delete an expense; verify simplified balances are correctly recomputed.

**SRS Requirements Exercised:**
FR-EX-06, FR-EX-07, FR-SE-04, FR-SE-01, FR-AC-01, FR-AC-03.

**Step-by-Step Happy Path:**

1. User navigates to a Friend Detail or Group Detail screen showing an existing expense and a non-zero simplified balance (SRS section 6.3, screens 6 or 7).
2. User notes the current simplified balance values for reference.
3. User taps on the expense they created to view its details.
4. User taps "Delete". The app presents a confirmation dialogue: "Are you sure you want to delete this expense? This action cannot be undone."
5. User confirms the deletion. The app soft-deletes the expense in Firestore (FR-EX-06).
6. The `recomputeSimplifiedBalances` Cloud Function fires atomically, excluding the deleted expense from the computation (FR-SE-04).
7. The detail screen updates to show the recomputed simplified balances. If the deleted expense was the only expense, balances return to zero (FR-SE-01).
8. The deletion is recorded in the Activity Feed with the author and timestamp (FR-EX-07). User navigates to the Activity Feed screen (SRS section 6.3, screen 10; FR-AC-01) and verifies the deletion event is present.
9. Other participants receive a push notification about the expense deletion (FR-AC-03).

---

## CUJ-06 -- Push Notification and Deep-Link

**Title:** Receive a push notification on background and foreground; verify deep-link.

**SRS Requirements Exercised:**
FR-AC-03, FR-AC-04, FR-AC-05, FR-AC-02.

**Step-by-Step Happy Path:**

1. A second user adds an expense involving the test user (triggering the `recomputeSimplifiedBalances` Cloud Function and an FCM notification -- FR-AC-03).
2. **Background scenario:** The test user's app is in the background. The device displays an OS-level push notification with the expense summary.
3. The notification respects the user's per-category preferences; if "new expense" notifications are enabled, the notification is delivered (FR-AC-04).
4. User taps the notification. The app launches (or resumes) and deep-links directly to the relevant expense detail screen (FR-AC-05).
5. User verifies the expense details are correctly displayed and the simplified balance is up to date.
6. **Foreground scenario:** The test user's app is in the foreground on the Home Dashboard (SRS section 6.3, screen 5).
7. A second user records a settlement involving the test user. An in-app notification banner appears at the top of the screen (FR-AC-03).
8. User taps the in-app banner. The app navigates to the relevant settlement or friend/group screen (FR-AC-05, FR-AC-02).
9. User verifies the settlement details and the updated simplified balance.

---

## CUJ-07 -- Offline Expense Entry and Sync

**Title:** Offline: add expense without network; reconnect; verify sync and balance recomputation.

**SRS Requirements Exercised:**
FR-OF-01, FR-OF-02, FR-OF-03, FR-SE-04, FR-SE-01, FR-EX-01, FR-EX-04.

**Step-by-Step Happy Path:**

1. User has previously loaded friends, groups, and expenses whilst online. The app has cached this data locally.
2. User enables aeroplane mode (network is unavailable).
3. User opens the app. Previously-loaded data -- expenses, friends, groups, and simplified balances -- is displayed from the local cache (FR-OF-01).
4. User taps the floating action button to add a new expense. The Add Expense bottom sheet opens (SRS section 6.3, screen 8).
5. User enters amount, description, date, category, and split method (FR-EX-01). The app validates splits sum to the total (FR-EX-04).
6. User taps "Save". The app queues the write locally and displays the expense in the list with a "pending sync" indicator (FR-OF-02).
7. The simplified balance on the detail screen does not yet update (it is server-maintained and cannot be computed on-device -- SRS section 7.3, invariant 2).
8. User disables aeroplane mode. The app detects network connectivity and syncs the queued expense to Firestore (FR-OF-02).
9. The `recomputeSimplifiedBalances` Cloud Function fires on the server (FR-SE-04). The simplified balance updates on the client in real time (FR-SE-01).
10. The "pending sync" indicator disappears, confirming successful synchronisation.
11. If a conflicting edit occurred whilst offline, the server resolves it using last-write-wins, and the user is notified of the override (FR-OF-03).

---

## CUJ-08 -- Dark Mode Legibility

**Title:** Dark mode: navigate every screen and verify legibility.

**SRS Requirements Exercised:**
NFR (SRS section 5.6 -- dark mode support), FR-HD-01, FR-HD-02, FR-HD-04,
FR-FR-03, FR-GR-04, FR-AC-01, FR-PR-01, FR-EX-01, FR-SE-05.

**Step-by-Step Happy Path:**

1. User enables dark mode at the OS level. The app detects the system theme and switches to the dark colour scheme: surface colour `#121212`, adjusted text and icon colours for WCAG 2.1 AA contrast (SRS sections 5.6, 6.2).
2. User views the Splash and Onboarding screens (SRS section 6.3, screen 1). All illustrations, text, and controls are legible against the dark surface.
3. User proceeds through Phone Number Entry (screen 2) and OTP Verification (screen 3). Input fields, prefix label, and buttons meet contrast requirements.
4. User views the Home Dashboard (screen 5). The net balance, top friends/groups cards, category chart, and FAB are all legible (FR-HD-01, FR-HD-02, FR-HD-04).
5. User navigates to the Friends List and a Friend Detail screen (screen 6). Balance labels (green for "owed to you", red for "you owe") remain distinguishable (FR-FR-03).
6. User navigates to the Groups List and a Group Detail screen (screen 7). Member balances and expense list render correctly (FR-GR-04).
7. User opens the Add/Edit Expense bottom sheet (screen 8). Form fields, category icons, split method selector, and validation error text are all legible (FR-EX-01).
8. User opens the Settle Up flow (screen 9). Pre-filled amounts and the confirmation button are readable (FR-SE-05).
9. User navigates to the Activity Feed (screen 10). Feed items, timestamps, and deep-link tap targets are legible (FR-AC-01).
10. User navigates to Profile and Settings (screen 11). Display name, photo, notification preferences, sign-out button, and "Contact Support" link are all legible (FR-PR-01).

---

## CUJ-09 -- Large-Data Scroll Performance

**Title:** Large-data: group with 50+ expenses scrolls smoothly and renders correctly; simplified-debts function returns within SLA.

**SRS Requirements Exercised:**
FR-GR-04, FR-SE-02, FR-SE-03, FR-EX-09, NFR-PE-04, NFR-PE-05
(SRS sections 5.1, 5.2).

**Step-by-Step Happy Path:**

1. A test group exists with 50 or more expenses of varying split methods, categories, and amounts. Multiple settlements have been recorded.
2. User navigates to the Group Detail screen for this group (SRS section 6.3, screen 7).
3. The expense list loads and renders. The initial render completes within the dashboard render SLA of 1.5 seconds (NFR-PE-03).
4. User scrolls through the full expense list. Scroll performance maintains a smooth frame rate without jank or dropped frames (SRS section 5.1).
5. All amounts are formatted using the Indian numbering system with the rupee symbol (FR-EX-09).
6. User verifies that the simplified balances displayed are correct and consistent across all group members (FR-GR-04, FR-SE-02).
7. User adds one more expense. The `recomputeSimplifiedBalances` Cloud Function processes all 51+ expenses and returns within the 500 ms SLA for groups up to 50 members (SRS section 5.2; FR-SE-03).
8. The updated simplified balances appear on screen within the add-expense round-trip SLA of 2.5 seconds (NFR-PE-04).

---

## CUJ-10 -- Account Deletion

**Title:** Account deletion: trigger flow, verify data anonymisation in shared groups.

**SRS Requirements Exercised:**
FR-AU-09, FR-AU-08, FR-PR-01 (SRS sections 4.1, 5.5).

**Step-by-Step Happy Path:**

1. User navigates to the Profile and Settings screen (SRS section 6.3, screen 11; FR-PR-01).
2. User scrolls to the "Delete Account" option and taps it.
3. The app presents a confirmation dialogue explaining the consequences: all personal data will be anonymised within 30 days, shared expenses will retain anonymised records, and this action is irreversible (FR-AU-09; SRS section 5.5).
4. User confirms the deletion request.
5. The app triggers the `accountDeletion` Cloud Function (FR-AU-09). The function marks the account for deletion and begins the anonymisation process.
6. The app clears the local session (as per sign-out -- FR-AU-08) and navigates the user back to the Phone Number Entry screen (SRS section 6.3, screen 2).
7. In shared groups, the deleted user's display name and profile photo are replaced with anonymised placeholders (e.g., "Deleted User"). Expense and settlement records remain for balance integrity but contain no personally identifiable information.
8. Attempting to log in again with the same phone number treats the user as a new account (FR-AU-06).

---

## CUJ-11 -- Share-Sheet Invite

**Title:** Share-sheet invite (friend and group): invite text and deep link are correct; the OS share sheet is the only handoff surface.

**SRS Requirements Exercised:**
FR-FR-02, FR-GR-02, FR-GR-03, FR-SH-01, FR-SH-02.

**Step-by-Step Happy Path:**

1. **Friend invite:** User navigates to the Friends List screen (SRS section 6.3, screen 6) and taps "Add Friend".
2. User selects a contact from their phone book who is not yet a One By Two user (FR-FR-01).
3. The app detects the contact is not registered and offers to invite them. User taps "Invite" (FR-FR-02).
4. The platform's system share sheet opens (FR-SH-01). The app does not target any specific messaging application (SRS section 3.4, invariant 3).
5. The share payload contains a pre-filled message with a deep link (universal link on iOS, App Link on Android) and a fallback app store URL (FR-SH-02).
6. User selects their preferred sharing channel from the OS-presented options and sends the invite.
7. **Group invite:** User navigates to a Group Detail screen (SRS section 6.3, screen 7) and taps "Invite Members" (FR-GR-02).
8. User chooses to share via invite link. The app generates a link that expires in 7 days (FR-GR-03).
9. The system share sheet opens with the invite link and a pre-filled message (FR-SH-01, FR-SH-02).
10. User sends the invite via their chosen channel. The group admin can later revoke the invite link from the group settings (FR-GR-03).

---

## CUJ-12 -- Contact Support

**Title:** Contact Support: tapping opens the device mail composer with the correct address and pre-filled diagnostic body; fallback dialogue appears when no mail client is configured.

**SRS Requirements Exercised:**
FR-PR-05, FR-SH-03, FR-SH-04.

**Step-by-Step Happy Path:**

1. User navigates to the Profile and Settings screen (SRS section 6.3, screen 11).
2. User taps "Contact Support" (FR-PR-05).
3. The app reads the support email address from Firebase Remote Config (FR-SH-03).
4. The app constructs a `mailto:` URL with the support address in the "to" field and pre-fills the email body with diagnostic information: the user's `userId`, app version, OS version, and device model (FR-SH-03, FR-PR-05).
5. The device's default mail client opens with the pre-filled fields. The user can review and edit the email body before sending.
6. User sends the support email.
7. **Fallback scenario:** On a device with no mail client configured, the `mailto:` intent fails.
8. The app detects the failure and displays a fallback dialogue showing the support email address in plain text, along with a "Copy" button (FR-SH-04).
9. User taps "Copy". The support email address is copied to the device clipboard.
10. User can then paste the address into any communication channel of their choice.

---

## Cross-Reference: Screens to Journeys

The table below maps each core screen (SRS section 6.3) to the journeys that
exercise it, ensuring full coverage.

| # | Screen | Journeys |
|---|--------|----------|
| 1 | Splash and Onboarding | CUJ-01, CUJ-08 |
| 2 | Phone Number Entry | CUJ-01, CUJ-08, CUJ-10 |
| 3 | OTP Verification | CUJ-01, CUJ-08 |
| 4 | Profile Setup | CUJ-01 |
| 5 | Home Dashboard | CUJ-01, CUJ-02, CUJ-06, CUJ-07, CUJ-08 |
| 6 | Friends List and Friend Detail | CUJ-02, CUJ-04, CUJ-05, CUJ-06, CUJ-08, CUJ-11 |
| 7 | Groups List and Group Detail | CUJ-03, CUJ-04, CUJ-05, CUJ-08, CUJ-09, CUJ-11 |
| 8 | Add / Edit Expense | CUJ-02, CUJ-03, CUJ-04, CUJ-07, CUJ-08, CUJ-09 |
| 9 | Settle Up Flow | CUJ-03, CUJ-08 |
| 10 | Activity Feed | CUJ-04, CUJ-05, CUJ-08 |
| 11 | Profile and Settings | CUJ-08, CUJ-10, CUJ-12 |
