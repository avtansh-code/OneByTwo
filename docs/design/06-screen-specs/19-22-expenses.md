# Screen Specifications: Expense Flow (SCR-19 to SCR-22)

> **Document owner:** UX/UI Designer
> **Version:** 1.0
> **Status:** Draft
> **Audience:** Flutter Developer, Solution Architect, QA Engineer
> **SRS baseline:** v1.1, sections 4.5, 5.6, 5.10, 6.1--6.5
> **Wireframe baseline:** `docs/design/04-wireframes/expense-flow.md` v1.0
> **Component baseline:** `docs/design/02-design-system/components.md`

This document specifies the four expense-flow screens for OneByTwo v1.0. Each screen is defined with its identifier, purpose, routing, requirements traceability, component usage, all six states, input validation, telemetry, accessibility, edge cases, and open questions.

All monetary values are **integer paise** (Invariant 1; SRS section 7.3). Conversion to rupees with the Indian numbering system occurs exclusively at the UI layer. Currency symbol is always `₹` (FR-EX-09; SRS section 5.9).

---

## SCR-19: Add Expense -- Amount and Details

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-19 |
| **Screen Name** | Add Expense -- Amount and Details |
| **Purpose** | Capture the monetary amount, description, date, expense category, and optional notes for a new expense. This is step 1 of the three-step Add Expense bottom sheet (SRS section 6.3, item 8). |
| **Route** | Modal bottom sheet; no named route. Invoked programmatically from the parent screen via `showModalBottomSheet`. Internal step index: `0`. |

### SRS Requirements

| ID | Requirement | How Covered |
|---|---|---|
| FR-EX-01 | Amount in INR, description, date, category, optional notes | All five fields are present on this step. |
| FR-EX-08 | Eight predefined categories with icons (Food, Travel, Rent, Utilities, Groceries, Entertainment, Shopping, Other) | `OBTCategoryChip` grid (4x2). |
| FR-EX-09 | `₹` symbol; Indian numbering system (e.g. `₹1,23,456.00`) | `OBTAmountInput` live formatting; `OBTRupeeText` for preview. |

### Navigation

| Direction | Target |
|---|---|
| **Reachable from** | `OBTFloatingActionButton` on any primary tab (FR-HD-04); "Add Expense" CTA on Friend Detail; "Add Expense" CTA on Group Detail; `OBTEmptyState` CTA on an expense list. |
| **Leads to** | SCR-20 (step 2: Split Method) on successful validation and "Next" tap. Dismissal returns to the invoking screen with no side effects. |

### Components Used

| Component | Configuration | Catalogue Ref |
|---|---|---|
| `OBTAmountInput` | `autoFocus: true`; `onChanged` returns paise; max value `9,99,99,999` paise (`₹99,99,999.99`) | Item 6 |
| `OBTCategoryChip` | Eight chips in a 4x2 grid; `isSelected` toggles on tap; single-select | Item 12 |
| `OBTRupeeText` | Live preview of the entered amount in Indian numbering | Item 5 |
| Platform date picker | Defaults to today; max date = today; displays as `dd MMM yyyy` | Flutter `showDatePicker` |
| Description text field | Standard input; max 100 characters; placeholder: "e.g. Dinner at Dosa Plaza" | -- |
| Notes text field | Multi-line input; max 500 characters; placeholder: "Add any extra details..." | -- |
| `OBTSnackbar` | For discard-confirmation feedback if applicable | Item 25 |

### States

| # | State | Behaviour |
|---|---|---|
| 1 | **Empty (default)** | Amount shows `₹0.00` placeholder. Description empty. Date defaults to today. No category selected. Notes empty. "Next" button disabled (uses `disabled` token). Sheet title: "Add Expense (1/3)". |
| 2 | **Partially filled** | One or more required fields (amount, description, category) remain incomplete. "Next" button stays disabled. Completed fields show their values normally. |
| 3 | **Valid** | Amount > 0, description non-empty (trimmed), and one category selected. "Next" button activates in `primary` colour. |
| 4 | **Error** | Triggered on "Next" tap when validation fails, or on field blur. Specific error messages appear inline beneath the offending fields (see Inputs/Validation below). Fields with errors show a `danger` border. |
| 5 | **Loading** | Applicable only in the edit flow (SCR-22). `OBTSkeletonLoader` type `expenseDetail` displayed while fetching existing values (SRS section 6.4). Shimmer animation, 1500 ms loop. |
| 6 | **Offline** | If the device is offline when the sheet opens, a non-blocking `OBTSnackbar` type `info` appears: "You're offline. You can still add this expense -- it will sync when you're back online." (FR-OF-02). All fields remain interactive. |

### Inputs and Validation

| Field | Type | Required | Constraints | Error Message |
|---|---|---|---|---|
| Amount | Numeric (paise output) | Yes | Must be > 0; max `9,99,99,999` paise (`₹99,99,999.99`) | "Enter an amount greater than zero." / "Amount cannot exceed ₹99,99,999.99." |
| Description | Text | Yes | 1--100 characters (trimmed); no leading/trailing whitespace stored | "Add a short description." / "Description must be under 100 characters." |
| Date | Date | Yes | Cannot be in the future; defaults to today | "Date cannot be in the future." |
| Category | Enum (single-select) | Yes | One of the eight predefined values | "Pick a category." |
| Notes | Text | No | 0--500 characters | "Notes must be under 500 characters." |

All error messages are displayed inline beneath the respective field in `danger` colour (`#E76F51`). Validation runs on "Next" tap; amount and description fields also validate on blur. Errors clear automatically when the user corrects the input.

### Telemetry Events

| Event Name | Trigger | Parameters | SRS Ref |
|---|---|---|---|
| `expense_step1_opened` | Sheet step 1 becomes visible | `context_type` (`friend` / `group`), `context_id`, `entry_point` (`fab` / `friend_detail` / `group_detail` / `empty_state`) | Section 5.10 |
| `expense_step1_completed` | User taps "Next" and validation passes | `amount_paise`, `category`, `has_notes` (bool) | Section 5.10 |
| `expense_step1_abandoned` | User dismisses the sheet from step 1 | `fields_filled_count` (0--5), `time_spent_ms` | Section 5.10 |
| `expense_category_selected` | User taps a category chip | `category` | Section 5.10 |

### Accessibility

| Requirement | Implementation | SRS Ref |
|---|---|---|
| Screen announcement | Sheet is announced as: "Add expense, step 1 of 3." | Section 5.6 |
| Close button | Semantic label: "Close, discard expense." | Section 5.6 |
| Amount field | Semantic label: "Enter amount in rupees." Announces current value on change. | Section 5.6; Item 6 |
| Category chips | Each chip: "[Category name] category, [selected / not selected]." | Section 5.6; Item 12 |
| Date picker | Semantic label: "Select expense date. Currently [date]." | Section 5.6 |
| Notes field | Semantic label: "Notes, optional." | Section 5.6 |
| Tap targets | All interactive elements meet 48x48 dp minimum (Android) / 44x44 pt (iOS). | Section 5.6 |
| Contrast | All text/background pairs meet WCAG 2.1 AA (4.5:1 body text). Verified in both light and dark mode. | Section 5.6 |
| Dynamic font scaling | Layout must not clip at 200% text scale. Category grid wraps to additional rows if needed. | Section 5.6 |
| Error announcements | Validation errors announced as live regions. | Section 5.6 |

### Edge Cases

1. **Maximum amount boundary:** User enters exactly `₹99,99,999.99`. The field must accept this value. Entering one more digit (or paise beyond `.99`) must be silently rejected; the cursor remains in place without visual jitter.
2. **Whitespace-only description:** A description consisting solely of spaces or newlines must be treated as empty. Trimming occurs before validation. Error message: "Add a short description."
3. **Date picker in different time zone:** The device may be set to a time zone other than IST. The date picker must still compare against today in IST (`Asia/Kolkata`) per SRS section 5.9, preventing selection of a date that is "tomorrow" in IST even if it is "today" locally.
4. **Rapid category switching:** Tapping multiple category chips in quick succession must debounce to the last tap. Only one chip may be in the `selected` state at any time. No intermediate visual glitch.
5. **Sheet dismissed mid-entry:** If the user swipes down or taps the scrim to dismiss while fields are partially filled, no data is persisted. No confirmation dialog is shown for step 1 (the cost of re-entry is low).

### Open Questions

1. Should a discard-confirmation dialog appear if the user has filled in significant data (e.g. amount and description) and then dismisses the sheet? The current spec says no, but this may cause user frustration on accidental dismissal.
2. Should the notes field support rich text (bold, lists) in a future release, or is plain text the permanent design? This affects the data model.
3. For the edit flow (SCR-22), should changed fields be visually differentiated on step 1, or only on the confirmation step?

---

## SCR-20: Add Expense -- Split Method

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-20 |
| **Screen Name** | Add Expense -- Split Method |
| **Purpose** | Select the payer and the split method, then assign each participant's share of the expense. This is step 2 of the three-step Add Expense bottom sheet. |
| **Route** | Modal bottom sheet (continued); internal step index: `1`. No named route. |

### SRS Requirements

| ID | Requirement | How Covered |
|---|---|---|
| FR-EX-02 | Expense within a 1-to-1 friend context or a group context | Participant list is derived from the friendship pair or group member list. |
| FR-EX-03 | Five split methods: Equal, Unequal, Percentage, Shares, Exact | `OBTSplitMethodSelector` with all five options. |
| FR-EX-04 | Splits must sum exactly to the expense total (in paise). Discrepancies block save with a clear inline error. | Running total comparison; "Next" button disabled until paise sum matches. |

### Navigation

| Direction | Target |
|---|---|
| **Reachable from** | SCR-19 (step 1) upon successful validation and "Next" tap. |
| **Leads to** | SCR-21 (step 3: Receipt and Confirm) on successful split validation and "Next" tap. Back navigation returns to SCR-19 with all step-1 values preserved. |

### Components Used

| Component | Configuration | Catalogue Ref |
|---|---|---|
| `OBTSplitMethodSelector` | `selectedMethod: equal` (default); `onMethodChanged`; `availableMethods: all five` | Item 21 |
| `OBTSplitEntryRow` | One per participant; input type varies by split method | Item 22 |
| `OBTUserAvatar` | Leading avatar in payer selector and each split row | Item 11 |
| `OBTRupeeText` | Calculated share display (Equal mode); running total | Item 5 |
| Payer dropdown | Scrollable list of participants; defaults to current user ("You"); selected with `primary` checkmark | -- |

### Split Methods -- Detailed Specification

#### Method 1: Equal

| Aspect | Detail |
|---|---|
| **Description text** | "Split equally among all" |
| **Input type** | None. Shares are auto-calculated and displayed as read-only `OBTRupeeText`. |
| **Calculation** | `sharePaise = totalPaise / participantCount` (integer division). Remainder of `totalPaise % participantCount` paise is distributed one paise each to the first N participants (ordered alphabetically by display name). |
| **Validation** | Always valid by construction. "Next" button enabled immediately. |
| **Error scenarios** | None under normal conditions. |
| **Rounding example** | `₹100.00` (10000 paise) split among 3: participant A gets 3334 paise, B gets 3333 paise, C gets 3333 paise. Sum = 10000 paise exactly. |

#### Method 2: Unequal (by Amount)

| Aspect | Detail |
|---|---|
| **Description text** | "Enter exact amounts for each person" |
| **Input type** | Numeric text field with `₹` prefix per participant. Decimal input allowed. Output in paise. |
| **Validation rule** | Sum of all `sharePaise` values must equal `totalPaise` exactly. Each individual share must be >= 0 paise. At least one share must be > 0. |
| **Running total display** | "Split total: ₹[current] / ₹[target]" with a checkmark or error indicator. |
| **Error: sum < total** | Running total in `danger` colour. Message: "Splits don't add up -- ₹[difference] remaining." "Next" disabled. |
| **Error: sum > total** | Running total in `danger` colour. Message: "Splits don't add up -- ₹[difference] over." "Next" disabled. |
| **Error: negative value** | Per-row error: "Share must be zero or more." |
| **Error: all shares zero** | Inline error below the list: "At least one person must have a share greater than zero." |

#### Method 3: Percentage

| Aspect | Detail |
|---|---|
| **Description text** | "Assign a percentage to each person" |
| **Input type** | Numeric text field with `%` suffix per participant. Integer values 0--100. |
| **Calculated share** | Displayed as `= ₹[amount]` beside each row. Calculated as `floor(totalPaise * percentage / 100)`. Remainder paise distributed to participants with the largest fractional parts (largest-remainder method) to guarantee paise-exact summation. |
| **Validation rule** | Sum of all percentages must equal exactly 100. Each percentage must be >= 0. At least one percentage must be > 0. |
| **Running total display** | "Percentage total: [current]% / 100%" |
| **Error: sum != 100** | Percentage total in `danger` colour. Message: "Percentages must add up to 100%." "Next" disabled. |
| **Error: negative value** | Per-row error: "Percentage must be zero or more." |
| **Error: value > 100** | Per-row error: "Percentage cannot exceed 100%." |
| **Error: all zero** | Inline error: "At least one person must have a percentage greater than zero." |
| **Rounding example** | `₹1,000.00` (100000 paise), 3 participants at 33%, 33%, 34%: A = 33000, B = 33000, C = 34000. Sum = 100000 paise exactly. |

#### Method 4: Shares

| Aspect | Detail |
|---|---|
| **Description text** | "Assign share units to each person" |
| **Input type** | Integer stepper ([-] / [+] buttons) per participant. Minimum value: 0. Maximum value: 999. Default: 1 share each. |
| **Calculated share** | `sharePaise = floor(totalPaise * memberShares / totalShares)`. Remainder paise distributed via largest-remainder method. Displayed as `= ₹[amount]` beside each row. |
| **Validation rule** | Total shares must be > 0 (i.e. at least one participant has shares > 0). |
| **Running total display** | "Total shares: [N]" and "Split total: ₹[calculated sum]" (always equals total by construction when totalShares > 0). |
| **Error: all shares zero** | Inline error: "At least one person must have one or more shares." "Next" disabled. |
| **Error: individual negative** | Not possible with stepper UI (minimum is 0). |
| **Rounding example** | `₹1,500.00` (150000 paise), shares 2, 2, 1 (total 5): A = 60000, B = 60000, C = 30000. Sum = 150000 paise exactly. |

#### Method 5: Exact

| Aspect | Detail |
|---|---|
| **Description text** | "Enter the exact amount each person owes" |
| **Input type** | Numeric text field with `₹` prefix per participant. Decimal input allowed. Output in paise. |
| **Validation rule** | Identical to Unequal. Sum of all `sharePaise` must equal `totalPaise` exactly. Each share >= 0 paise. At least one share > 0. |
| **Running total display** | "Split total: ₹[current] / ₹[target]" |
| **Error: sum < total** | "Splits don't add up -- ₹[difference] remaining." |
| **Error: sum > total** | "Splits don't add up -- ₹[difference] over." |
| **Error: negative value** | Per-row error: "Share must be zero or more." |
| **Error: all zero** | Inline error: "At least one person must have a share greater than zero." |
| **Design note** | Functionally identical to Unequal. The distinction exists for user mental-model clarity: "Unequal" implies splitting an existing total unevenly, whilst "Exact" implies knowing precisely what each person owes. The data model stores both as `splitMethod: 'unequal'` vs `splitMethod: 'exact'`. |

### Paise-Exact Summation Rule (FR-EX-04)

All split calculations must guarantee that the sum of `sharePaise` values across all participants equals `totalPaise` exactly, with zero remainder. This is enforced as follows:

1. **Integer arithmetic only.** No floating-point intermediate values. All division is integer division (floor).
2. **Remainder distribution.** After floor-division, the remainder `totalPaise - sum(floor-shares)` is distributed one paise at a time to participants ordered by largest fractional remainder (largest-remainder method). Ties are broken alphabetically by display name for determinism.
3. **Client-side validation.** Before enabling the "Next" button, the client sums all `sharePaise` values and compares to `totalPaise`. If they differ by even 1 paisa, the "Next" button remains disabled and the error state is shown.
4. **Server-side re-validation.** The Cloud Function re-validates the paise sum on write. A mismatch results in a rejected write and an error returned to the client.

### States

| # | State | Behaviour |
|---|---|---|
| 1 | **Default (Equal selected)** | Auto-calculated shares displayed as read-only `OBTRupeeText`. Running total shows green checkmark. "Next" enabled. |
| 2 | **Partially filled (non-Equal method)** | One or more editable share fields are empty or zero. Running total shows discrepancy. "Next" disabled. |
| 3 | **Valid** | Splits sum to total exactly. Running total in `success` colour with checkmark. "Next" enabled in `primary`. |
| 4 | **Error** | Running total in `danger` colour. Inline error message describes the discrepancy. Per-row errors shown where applicable. "Next" disabled. `HapticFeedback.lightImpact` on failed "Next" tap. |
| 5 | **Loading** | Inline 24x24 dp circular indicator in `primary` in the split breakdown area whilst computing split previews (300 ms display delay). |
| 6 | **Payer picker open** | Modal overlay listing all participants with radio selection. Selected payer indicated with `primary` checkmark. Changing payer does not alter split amounts. |

### Inputs and Validation

| Field | Type | Required | Constraints | Error Message |
|---|---|---|---|---|
| Payer | Selection (dropdown) | Yes | Must be a participant in the context | "Select who paid." |
| Split method | Selection (chips) | Yes | One of: `equal`, `unequal`, `percentage`, `shares`, `exact` | N/A (always has a default) |
| Individual share (Unequal/Exact) | Numeric (paise) | Yes (per participant) | >= 0 paise; sum must equal `totalPaise` | "Share must be zero or more." |
| Individual percentage | Numeric (integer) | Yes (per participant) | 0--100; sum must equal 100 | "Percentage must be zero or more." / "Percentage cannot exceed 100%." |
| Individual shares (Shares) | Integer (stepper) | Yes (per participant) | 0--999; total shares > 0 | "At least one person must have one or more shares." |

### Telemetry Events

| Event Name | Trigger | Parameters | SRS Ref |
|---|---|---|---|
| `expense_step2_opened` | Sheet step 2 becomes visible | `split_method` (default), `participant_count` | Section 5.10 |
| `expense_split_method_changed` | User selects a different split method | `from_method`, `to_method` | Section 5.10 |
| `expense_payer_changed` | User changes the payer | `payer_is_self` (bool) | Section 5.10 |
| `expense_step2_completed` | User taps "Next" and validation passes | `split_method`, `participant_count`, `payer_is_self` | Section 5.10 |
| `expense_split_validation_failed` | User taps "Next" but splits do not sum to total | `split_method`, `discrepancy_paise`, `direction` (`under` / `over`) | Section 5.10 |
| `expense_step2_abandoned` | User dismisses the sheet from step 2 | `split_method`, `time_spent_ms` | Section 5.10 |

### Accessibility

| Requirement | Implementation | SRS Ref |
|---|---|---|
| Screen announcement | "Add expense, step 2 of 3." | Section 5.6 |
| Split method selector | Announced as radio group: "Split method selector." Each chip: "[Method], [selected / not selected]." On change: "[Method] selected. [Description]." | Section 5.6; Item 21 |
| Split entry rows | Each row: "[Name]'s share: rupees [amount]" or "[Name]'s share: [value] percent." | Section 5.6; Item 22 |
| Payer selector | "Paid by [name]. Double-tap to change." | Section 5.6 |
| Validation error | Announced as live region: "Splits don't add up. [Amount] remaining." | Section 5.6 |
| Running total | Live region updates on each value change, debounced to 500 ms to avoid excessive announcements. | Section 5.6 |
| Stepper buttons (Shares) | Decrement: "Decrease [name]'s shares." Increment: "Increase [name]'s shares." Value announced on change. | Section 5.6 |
| Tap targets | All interactive elements >= 48x48 dp. Stepper buttons are 48x48 dp each. | Section 5.6 |
| Contrast | All text and indicator colours verified >= 4.5:1 against `surface` in both light and dark mode. | Section 5.6 |

### Edge Cases

1. **Two-person split (friend context):** Only two participants exist. The "Equal" method produces two identical shares. The "Shares" method stepper still functions but the practical utility is limited. All five methods remain available per FR-EX-03.
2. **Single-paise rounding in Percentage mode:** `₹0.01` (1 paisa) split at 33%, 33%, 34% among three people. Floor division yields 0, 0, 0 paise. The 1-paisa remainder is assigned to the participant with the largest fractional part (the 34% participant). Result: 0, 0, 1 paise. The system handles this gracefully without error.
3. **Very large group (50 members):** The split entry list must be scrollable within the bottom sheet. Performance must remain smooth. The running total recalculation must not block the UI thread; it runs synchronously but is O(n) and trivially fast for n <= 50.
4. **Switching split methods mid-entry:** If the user enters custom amounts in "Unequal" mode and then switches to "Equal", the custom values are discarded and replaced with auto-calculated equal shares. Switching back to "Unequal" does not restore the previously entered values. A future enhancement may preserve values per method.
5. **Participant with zero share:** A participant may have a 0 share in Unequal, Percentage, Shares, or Exact modes. This is valid. The participant is still recorded in the expense splits array with `sharePaise: 0`. This allows the expense to appear in their activity feed.

### Open Questions

1. Should switching between Unequal and Exact preserve the entered values, given that the two methods are functionally identical in data terms?
2. In Percentage mode, should the input accept decimal percentages (e.g. 33.33%) or only integers? The current spec uses integers for simplicity, but this limits precision for large amounts.
3. Should the payer be allowed to be someone outside the split (i.e. a participant with 0% share who paid the full amount)? The current spec permits this implicitly via zero shares.

---

## SCR-21: Add Expense -- Receipt and Confirm

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-21 |
| **Screen Name** | Add Expense -- Receipt and Confirm |
| **Purpose** | Optionally attach a receipt image and review a full summary of the expense before saving. This is step 3 (final) of the three-step Add Expense bottom sheet. It combines the receipt attachment (wireframe step 3) and confirmation (wireframe step 4) into a single scrollable screen to reduce step count. |
| **Route** | Modal bottom sheet (continued); internal step index: `2`. No named route. |

### SRS Requirements

| ID | Requirement | How Covered |
|---|---|---|
| FR-EX-05 | Attach receipt image (camera or gallery), stored in Firebase Storage | Camera/gallery picker; image upload; thumbnail preview. |
| FR-EX-06 | Users can edit or delete any expense they created; edits reflected in real time; triggers recomputation of simplified balances | "Save Expense" action writes the document. Server-side `recomputeSimplifiedBalances` runs on write (Invariant 2). |

### Navigation

| Direction | Target |
|---|---|
| **Reachable from** | SCR-20 (step 2) upon successful split validation and "Next" tap. |
| **Leads to** | On save success: sheet dismisses; returns to the invoking screen (Friend Detail, Group Detail, or Home). On "Edit" tap: returns to SCR-19 with all values preserved. |

### Components Used

| Component | Configuration | Catalogue Ref |
|---|---|---|
| Image picker area | Dashed-border container, 240 dp height, `cornerRadiusLarge` | -- |
| "Take Photo" button | Outlined button, leading camera icon, 48 dp height | -- |
| "From Gallery" button | Outlined button, leading image icon, 48 dp height | -- |
| Receipt thumbnail | Image preview with `cornerRadiusLarge`, constrained to 240x320 dp | -- |
| Summary card | `surface` background, `cornerRadiusXL` (24 dp), `elevationLow` | Tokens |
| `OBTRupeeText` | Amount and each split share in Indian numbering | Item 5 |
| `OBTCategoryChip` | Read-only display of selected category | Item 12 |
| `OBTUserAvatar` | Payer avatar and each participant avatar | Item 11 |
| `OBTSnackbar` | Success ("Expense added -- done!") and error ("Could not save. Try again.") feedback | Item 25 |
| `OBTConfirmationDialog` | Not used on this screen (used on SCR-22 for delete) | -- |

### States

| # | State | Behaviour |
|---|---|---|
| 1 | **Default (no receipt)** | Receipt section shows placeholder area with camera icon and instructional text ("Tap to take a photo or pick from gallery"). Both "Take Photo" and "From Gallery" buttons visible. Below, the summary card displays all expense details. "Save Expense" button in `primary`, 48 dp height. |
| 2 | **Receipt attached** | Thumbnail displayed in the placeholder area. "Replace" and "Remove" buttons replace "Take Photo" and "From Gallery". Summary card shows a receipt thumbnail in the receipt row. |
| 3 | **Uploading receipt** | Thumbnail area shows a circular progress indicator in `primary` overlaid on the image preview at reduced opacity (0.5). "Save Expense" button disabled. |
| 4 | **Saving** | "Save Expense" button label replaced with a 16x16 dp circular progress indicator. Button disabled. A 2 dp linear progress bar in `primaryVariant` appears at the sheet top. |
| 5 | **Success** | Sheet dismisses with 250 ms slide-down animation. `OBTSnackbar` type `success`: "Expense added -- done!" `HapticFeedback.mediumImpact`. Simplified balances recomputed server-side (Invariant 2). |
| 6 | **Error** | `OBTSnackbar` type `error`: "Could not save. Try again." "Save Expense" button returns to default state. User may retry or navigate back to edit. Receipt upload error: `OBTSnackbar` type `error`: "Could not attach receipt. Try again." Image picker area returns to default (no receipt). |

### Inputs and Validation

| Field | Type | Required | Constraints | Error Message |
|---|---|---|---|---|
| Receipt image | Image (JPEG/PNG) | No | Max file size: 10 MB. Accepted formats: JPEG, PNG, HEIC (converted to JPEG on upload). Minimum dimensions: 100x100 px. | "Image is too large. Please choose a photo under 10 MB." / "This file format is not supported. Please use a JPEG or PNG image." |
| All expense fields | (Read-only summary) | Yes | Already validated on SCR-19 and SCR-20 | -- |

Note: The "Save Expense" button performs a final client-side re-validation of all fields and the paise-exact split sum before writing. If any prior validation is no longer satisfied (e.g. due to a race condition or state corruption), the save is blocked and an `OBTSnackbar` type `error` appears: "Something went wrong. Please go back and check your details."

### Telemetry Events

| Event Name | Trigger | Parameters | SRS Ref |
|---|---|---|---|
| `expense_step3_opened` | Sheet step 3 becomes visible | `has_receipt_from_edit` (bool, for edit flow) | Section 5.10 |
| `expense_receipt_attached` | User attaches a receipt image | `source` (`camera` / `gallery`), `file_size_bytes` | Section 5.10 |
| `expense_receipt_removed` | User removes an attached receipt | -- | Section 5.10 |
| `expense_added` | Expense successfully saved | `amount_paise`, `category`, `split_method`, `participant_count`, `has_receipt` (bool), `context_type`, `context_id` | Section 5.10 (canonical funnel event) |
| `expense_save_failed` | Save operation fails | `error_code`, `retry_count` | Section 5.10 |
| `expense_step3_abandoned` | User dismisses the sheet from step 3 | `had_receipt`, `time_spent_ms` | Section 5.10 |

### Accessibility

| Requirement | Implementation | SRS Ref |
|---|---|---|
| Screen announcement | "Add expense, step 3 of 3. Review and save." | Section 5.6 |
| Receipt area (empty) | "Attach a receipt, optional. Take photo or choose from gallery." | Section 5.6 |
| "Take Photo" button | "Take photo of receipt." | Section 5.6 |
| "From Gallery" button | "Choose receipt from photo library." | Section 5.6 |
| Receipt thumbnail | "Receipt image attached. Double-tap to view full size." | Section 5.6 |
| "Remove" button | "Remove receipt." | Section 5.6 |
| "Replace" button | "Replace receipt." | Section 5.6 |
| Summary card | Each row announced as "[Label]: [Value]" (e.g. "Amount: rupees 1,500 point zero zero"). | Section 5.6 |
| "Save Expense" button | "Save expense, rupees [total]." | Section 5.6 |
| Loading state | Live region: "Saving expense, please wait." | Section 5.6 |
| Success state | Live region: "Expense added." | Section 5.6 |
| Tap targets | All interactive elements >= 48x48 dp. | Section 5.6 |
| Contrast | Verified >= 4.5:1 in both light and dark mode. | Section 5.6 |

### Edge Cases

1. **Camera permission denied:** If the user taps "Take Photo" but camera permission is denied, display an `OBTSnackbar` type `info`: "Camera access is needed to take a photo. You can grant permission in Settings." with an action label "Settings" that opens the device settings. Fall back to gallery-only mode.
2. **Gallery permission denied:** Similar treatment. `OBTSnackbar` type `info`: "Photo library access is needed. You can grant permission in Settings." Both buttons remain visible but tapping the denied option re-prompts or directs to Settings.
3. **Network loss during save:** If the device goes offline after the user taps "Save Expense", the write is queued locally (FR-OF-02). The `OBTSnackbar` type `info` appears: "You're offline. This expense will be saved when you're back online." The sheet dismisses normally. The `expense_added` telemetry event fires with `offline: true`.
4. **Receipt upload succeeds but expense save fails:** The uploaded receipt image becomes orphaned in Firebase Storage. A server-side cleanup Cloud Function (out of scope for this screen spec but noted for the Architect) should garbage-collect orphaned receipts after 24 hours.
5. **Very large receipt image (just under 10 MB):** Upload may take several seconds on slow connections. The uploading state must remain visible. If the upload exceeds 30 seconds, show an `OBTSnackbar` type `error`: "Upload is taking too long. Try a smaller image or check your connection."

### Open Questions

1. Should the receipt section and the confirmation summary be on a single scrollable step (as specified here) or remain as two separate steps (as in the wireframe)? The single-step approach reduces friction but creates a longer scroll.
2. Should a "Skip receipt" text button be shown, or is the ability to simply tap "Save Expense" without attaching a receipt sufficient?
3. Should the summary card highlight fields that differ from defaults (e.g. a non-today date, a non-"You" payer) to help users catch errors before saving?

---

## SCR-22: Edit/Delete Expense

### Screen Identity

| Field | Value |
|---|---|
| **Screen ID** | SCR-22 |
| **Screen Name** | Edit/Delete Expense |
| **Purpose** | Allow the expense creator to modify any field of an existing expense or to soft-delete it. Edits and deletions are reflected in real time for all involved users and trigger server-side recomputation of simplified balances (Invariant 2). Both actions are recorded in the activity feed (FR-EX-07). |
| **Route** | Edit: Modal bottom sheet reusing the three-step flow from SCR-19/20/21 with pre-filled values. Delete: `OBTConfirmationDialog` overlay on the Expense Detail screen. No dedicated named route; invoked from Expense Detail. |

### SRS Requirements

| ID | Requirement | How Covered |
|---|---|---|
| FR-EX-06 | Edit or delete any expense the user created; reflected in real time; triggers recomputation of simplified balances | Pre-filled edit form; "Save Changes" CTA; delete confirmation dialog; server-side `recomputeSimplifiedBalances` (Invariant 2). |
| FR-EX-07 | Each edit or delete recorded in the activity feed with author and timestamp | Server-side activity feed write; UI confirms via `OBTSnackbar`. |

### Navigation

| Direction | Target |
|---|---|
| **Reachable from** | Expense Detail screen -- "Edit" action icon in `OBTAppBar`; "Delete" action icon or overflow menu item. Only visible to the expense creator. |
| **Leads to** | Edit success: sheet dismisses; returns to Expense Detail with updated values. Delete success: navigates back to the parent list (Friend Detail or Group Detail expense list). |

### Components Used

| Component | Configuration | Catalogue Ref |
|---|---|---|
| All SCR-19 components | Pre-filled with existing values. Sheet title: "Edit Expense (N/3)". | Items 5, 6, 11, 12 |
| All SCR-20 components | Pre-filled with existing split method and values. | Items 5, 11, 21, 22 |
| All SCR-21 components | Existing receipt thumbnail displayed (if attached). CTA label: "Save Changes". | Items 5, 11, 12, 25 |
| `OBTConfirmationDialog` | `title: "Delete this expense?"`, `body: "This will update balances for all participants. This cannot be undone."`, `confirmLabel: "Delete"`, `isDestructive: true` | Item 24 |
| `OBTSnackbar` | Success: "Changes saved." / "Expense deleted." Error: "Could not save changes. Try again." / "Could not delete. Try again." | Item 25 |
| `OBTErrorState` | For fetch failure: title "Could not load expense", subtitle "We could not load this. Please try again.", "Retry" button | Item 19 |
| `OBTSkeletonLoader` | Type `expenseDetail` while fetching existing values | Item 20 |

### Edit Flow -- Differences from Add Flow

| Aspect | Add Expense (SCR-19/20/21) | Edit Expense (SCR-22) |
|---|---|---|
| Sheet title | "Add Expense (N/3)" | "Edit Expense (N/3)" |
| Field values | Empty defaults | Pre-filled from existing expense document |
| Amount input | `initialAmountPaise: null` | `initialAmountPaise: existingAmountPaise` |
| Category | No selection | Existing category pre-selected |
| Date | Today | Existing expense date |
| Payer | Current user | Existing payer |
| Split method | Equal (default) | Existing method with existing share values |
| Receipt | Empty | Existing thumbnail displayed (if attached) |
| Primary CTA | "Save Expense" | "Save Changes" |
| Success snackbar | "Expense added -- done!" | "Changes saved." |
| Changed-field indicator | None | Changed fields on the confirmation summary card have a left border in `secondary` (`#F4A261`) |
| No-changes guard | N/A | "Save Changes" button disabled if no modifications detected |

### Delete Flow

The delete flow is triggered from the Expense Detail screen and uses the `OBTConfirmationDialog` overlay.

**Dialog content:**

- **Title:** "Delete this expense?"
- **Body:** "This will update balances for all participants. This cannot be undone."
- **Cancel button:** Outlined style. Label: "Cancel".
- **Confirm button:** Filled style in `danger` colour (`#E76F51`). Label: "Delete".

### States

| # | State | Behaviour |
|---|---|---|
| 1 | **Loading (initial fetch)** | `OBTSkeletonLoader` type `expenseDetail` while fetching existing expense values (SRS section 6.4). Shimmer animation, 1500 ms loop. Matches the shape of the amount input, description field, date picker, and category grid. |
| 2 | **Pre-filled (edit ready)** | All fields populated with existing values. User may modify any field. "Save Changes" button disabled until at least one modification is detected. |
| 3 | **Valid (changes made)** | One or more fields differ from the original values. All validations pass (same rules as SCR-19/SCR-20). "Save Changes" button enabled in `primary`. |
| 4 | **Error (validation)** | Same error behaviours as SCR-19 and SCR-20. Additionally, if the expense was concurrently deleted by another user, an `OBTErrorState` appears: title "Expense no longer exists", subtitle "This expense was deleted by another user." with no Retry button; a "Go Back" CTA navigates to the parent list. |
| 5 | **Saving / Deleting** | Edit: same loading behaviour as SCR-21 step 4 (linear progress bar + button spinner). Delete: Delete button in the dialog shows a 16x16 dp progress indicator; both dialog buttons disabled. |
| 6 | **Fetch error** | `OBTErrorState` with title "Could not load expense", subtitle "We could not load this. Please try again.", and "Retry" button (SRS section 6.4). Secondary "Contact Support" text link below. |

### Inputs and Validation

All inputs and validation rules are identical to SCR-19 and SCR-20, with the following additions:

| Field | Type | Required | Constraints | Error Message |
|---|---|---|---|---|
| All SCR-19 fields | (as above) | (as above) | (as above) | (as above) |
| All SCR-20 fields | (as above) | (as above) | (as above) | (as above) |
| Receipt (edit) | Image | No | Same as SCR-21. User may replace or remove an existing receipt. | (same as SCR-21) |
| Delete confirmation | Button tap | N/A | User must tap "Delete" in the confirmation dialog | N/A |

Additional edit-specific validation:

- **No-op guard:** If no fields have been modified, "Save Changes" is disabled. Comparing field-by-field: amount (paise), description (trimmed string), date, category, notes (trimmed), payer, split method, each participant's `sharePaise`, and receipt presence.
- **Concurrent edit detection:** If the expense's `updatedAt` timestamp on the server differs from the value fetched at edit-start, the save is rejected. `OBTSnackbar` type `error`: "This expense was updated by someone else. Please reload and try again." The sheet returns to the pre-filled state with a "Reload" action on the snackbar.

### Telemetry Events

| Event Name | Trigger | Parameters | SRS Ref |
|---|---|---|---|
| `expense_edit_opened` | Edit sheet becomes visible | `expense_id`, `context_type`, `context_id` | Section 5.10 |
| `expense_edit_field_changed` | User modifies a field from its original value | `field_name` (e.g. `amount`, `description`, `category`, `split_method`) | Section 5.10 |
| `expense_edit_saved` | Edit successfully saved | `expense_id`, `fields_changed` (array of field names), `split_method` | Section 5.10 |
| `expense_edit_failed` | Edit save fails | `expense_id`, `error_code` | Section 5.10 |
| `expense_edit_abandoned` | User dismisses the edit sheet without saving | `expense_id`, `had_changes` (bool), `time_spent_ms` | Section 5.10 |
| `expense_delete_initiated` | User taps "Delete" on Expense Detail (dialog opens) | `expense_id`, `context_type` | Section 5.10 |
| `expense_delete_confirmed` | User confirms deletion in the dialog | `expense_id`, `amount_paise`, `participant_count` | Section 5.10 |
| `expense_delete_cancelled` | User cancels the deletion dialog | `expense_id` | Section 5.10 |
| `expense_delete_failed` | Deletion fails | `expense_id`, `error_code` | Section 5.10 |

### Accessibility

| Requirement | Implementation | SRS Ref |
|---|---|---|
| Edit sheet announcement | "Edit expense, step [N] of 3." | Section 5.6 |
| Changed-field indicator | Semantic label on changed fields in the summary: "[Label]: [Value], changed." The `secondary` left border is supplemented by the word "changed" for screen readers (information not conveyed by colour alone). | Section 5.6 |
| "Save Changes" button | "Save changes to expense." When disabled: "Save changes, no modifications made." | Section 5.6 |
| Delete dialog | Announced as modal: "Alert: Delete this expense?" Body text read after title. Focus trapped within dialog. Cancel: "Cancel." Delete: "Delete." | Section 5.6; Item 24 |
| Delete button state | During deletion: "Deleting, please wait." | Section 5.6 |
| Fetch error | `OBTErrorState` title announced as heading. "Retry" button: "Retry loading expense." "Contact support" link: "Contact support." | Section 5.6; Item 19 |
| Back gesture in dialog | Escape key / back gesture triggers Cancel, not destructive action. | Section 5.6 |
| Tap targets | All >= 48x48 dp. Dialog buttons >= 48 dp height. | Section 5.6 |
| Contrast | All text verified >= 4.5:1 in light and dark mode. `danger` button text on `danger` background: white text at >= 4.5:1. | Section 5.6 |

### Edge Cases

1. **Concurrent deletion by another user:** Whilst the current user is editing, another user (e.g. in a group) deletes the same expense. On save attempt, the server returns a "not found" error. The UI shows an `OBTErrorState`: title "Expense no longer exists", subtitle "This expense was deleted by another user." A "Go Back" CTA navigates to the parent list. No retry is offered.
2. **Concurrent edit by another user:** Whilst the current user is editing, another user edits the same expense. The `updatedAt` timestamp check detects this. The `OBTSnackbar` type `error` appears: "This expense was updated by someone else. Please reload and try again." with a "Reload" action. Tapping "Reload" re-fetches the expense and resets the edit form.
3. **Edit with no actual changes:** The user opens the edit flow, makes no modifications, and attempts to save. The "Save Changes" button remains disabled. This prevents unnecessary server writes and activity feed noise.
4. **Delete the only expense in a context:** After deletion, the parent expense list transitions to the `OBTEmptyState`: title "No expenses yet", subtitle "Tap the + button to add your first expense." (SRS section 6.4).
5. **Offline delete:** If the device is offline when the user confirms deletion, the delete is queued locally (FR-OF-02). `OBTSnackbar` type `info`: "You're offline. This deletion will sync when you're back online." The expense is marked as pending-delete in the local cache and shown with reduced opacity and a "Pending deletion" label. The dialog dismisses and the user returns to the parent list where the expense remains visible (dimmed) until sync completes.

### Open Questions

1. Should non-creator participants be able to edit or delete expenses, or is this strictly limited to the creator? The SRS says "any expense they created" (FR-EX-06), implying creator-only. Confirm with PM.
2. Should the delete action use soft-delete (setting `deleted: true`) visibly to the user, or should it appear as a hard delete from the user's perspective? The data model uses soft-delete (SRS section 7.3), but the UI should not expose this implementation detail.
3. Should there be an "undo" affordance on the delete snackbar (e.g. a 5-second undo window) before the server-side recomputation runs? This would improve the experience for accidental deletions but adds complexity to the server-side logic.
4. For concurrent edit detection, should the UI auto-merge non-conflicting field changes (e.g. user A changes the description whilst user B changes the amount), or should any concurrent edit be treated as a conflict? The current spec treats any concurrent edit as a full conflict.

---

## Cross-Reference Matrix

| Screen | SRS Requirement | Primary Components | Design Tokens |
|---|---|---|---|
| SCR-19 | FR-EX-01, FR-EX-08, FR-EX-09 | `OBTAmountInput`, `OBTCategoryChip`, `OBTRupeeText` | `primary`, `danger`, `secondary`, `surface`, `cornerRadiusLarge` |
| SCR-20 | FR-EX-02, FR-EX-03, FR-EX-04 | `OBTSplitMethodSelector`, `OBTSplitEntryRow`, `OBTUserAvatar`, `OBTRupeeText` | `primary`, `danger`, `success`, `surface` |
| SCR-21 | FR-EX-05, FR-EX-06 | Image picker, summary card, `OBTRupeeText`, `OBTCategoryChip`, `OBTUserAvatar`, `OBTSnackbar` | `primary`, `primaryVariant`, `surface`, `cornerRadiusXL`, `elevationLow` |
| SCR-22 | FR-EX-06, FR-EX-07 | All above + `OBTConfirmationDialog`, `OBTErrorState`, `OBTSkeletonLoader`, `OBTSnackbar` | `primary`, `danger`, `secondary`, `surface`, `cornerRadiusXL` |

## Invariant Compliance Checklist

| Invariant | Compliance |
|---|---|
| 1. Money is integer paise | All monetary inputs output paise via `OBTAmountInput`. All split calculations use integer arithmetic. All display uses `OBTRupeeText` for paise-to-rupees conversion. No floats anywhere in the money path. |
| 2. `simplifiedBalances` is server-maintained and client-read-only | Expense save/edit/delete triggers server-side `recomputeSimplifiedBalances`. The client never writes to `simplifiedBalances`. |
| 3. System share sheet only | No sharing actions on these screens. Not applicable. |
| 4. Single Firebase project | Receipt images uploaded to Firebase Storage in the single production project. All reads/writes target the single Firestore instance. |