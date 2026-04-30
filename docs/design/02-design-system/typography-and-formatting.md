# Typography and Formatting

Text formatting rules for One By Two v1.0. This document is the single reference for every currency, date, phone number, and name display rule in the application. It is authored by the UX/UI Designer and consumed by the Flutter Developer during implementation.

All rules derive from the Software Requirements Specification (version 1.1). SRS section citations are provided inline.

---

## 1. Indian Numbering System (INR)

### 1.1 Source Requirements

- **FR-EX-09 (SRS section 4.5):** "Currency symbol shall always be ₹ and amounts shall be formatted using the Indian numbering system (e.g., ₹1,23,456.00)." Priority: P0.
- **SRS section 5.9:** "Currency formatting: Indian numbering system, two decimal places, ₹ symbol prefix."
- **Invariant 1 (SRS section 7.3):** All monetary values are stored and transmitted as integer paise (1 INR = 100 paise). Conversion to rupees with two decimal places happens exclusively at the UI layer.

### 1.2 Comma Placement Rules

The Indian numbering system differs from the Western system. The rules are:

1. The first comma is placed after the **thousands** position (three digits from the decimal point), exactly as in the Western system.
2. Every subsequent comma is placed after every **two** digits, not three.
3. There is no comma for values below 1,000.

The grouping pattern, reading right to left from the decimal point, is: 3, 2, 2, 2, ...

| Indian Term | Value | Formatted |
|-------------|-------|-----------|
| One | 1 | ₹1.00 |
| Ten | 10 | ₹10.00 |
| Hundred | 100 | ₹100.00 |
| Thousand | 1,000 | ₹1,000.00 |
| Ten thousand | 10,000 | ₹10,000.00 |
| Lakh | 1,00,000 | ₹1,00,000.00 |
| Ten lakh | 10,00,000 | ₹10,00,000.00 |
| Crore | 1,00,00,000 | ₹1,00,00,000.00 |
| Ten crore | 10,00,00,000 | ₹10,00,00,000.00 |

### 1.3 Formatting Specification

| Rule | Detail |
|------|--------|
| Symbol | Always prefix with `₹` (Unicode U+20B9). No space between the symbol and the digits. |
| Decimal places | Always exactly two. No rounding to whole numbers. |
| Negative values | Never display a minus sign. Use contextual labels and colour instead (see section 3). |
| Zero value | Display as `₹0.00`. |
| Thousands separator | Comma (`,`). |
| Decimal separator | Full stop (`.`). |
| Grouping | Indian system: 3 digits, then groups of 2 (see section 1.2). |

### 1.4 Paise-to-Display Conversion Table

All values in the data layer are integer paise. The UI layer divides by 100 and formats. The following worked examples are the canonical test vectors for any formatting utility.

| Paise Value (int) | Rupee Value | Formatted Display |
|--------------------|-------------|-------------------|
| 0 | 0.00 | ₹0.00 |
| 1 | 0.01 | ₹0.01 |
| 50 | 0.50 | ₹0.50 |
| 100 | 1.00 | ₹1.00 |
| 5000 | 50.00 | ₹50.00 |
| 50000 | 500.00 | ₹500.00 |
| 100000 | 1000.00 | ₹1,000.00 |
| 500000 | 5000.00 | ₹5,000.00 |
| 5000000 | 50000.00 | ₹50,000.00 |
| 10000000 | 100000.00 | ₹1,00,000.00 |
| 50000000 | 500000.00 | ₹5,00,000.00 |
| 500000000 | 5000000.00 | ₹50,00,000.00 |
| 5000000000 | 50000000.00 | ₹5,00,00,000.00 |
| 12345678900 | 123456789.00 | ₹12,34,56,789.00 |

### 1.5 Implementation Notes

- Use the `hi_IN` locale with Dart's `NumberFormat` or build a custom formatter that enforces the grouping rules above. The `en_IN` locale in the `intl` package also supports Indian grouping.
- Never perform string manipulation on a `double`. Convert integer paise to an integer quotient and integer remainder, then format.
- The formatter must be a pure function: `String formatPaise(int paise)`. It must be unit-tested against every row in the table above.

---

## 2. Compact / Abbreviated Currency Display

### 2.1 When to Use

| Context | Format |
|---------|--------|
| Home dashboard net balance (FR-HD-01, SRS section 4.8) | Full format |
| Home dashboard top-5 friend/group cards (FR-HD-02) | Compact format if value >= ₹1,00,000 |
| Friends list / Groups list row | Compact format if value >= ₹1,00,000 |
| Friend detail / Group detail balance header | Full format |
| Expense amount in list row | Full format |
| Expense detail screen | Full format |
| Settle Up amount | Full format |
| Activity feed row | Compact format if value >= ₹1,00,000 |

**Rule:** Use full format by default. Use compact format only in horizontally constrained list rows and cards where the full format would cause truncation or layout overflow. Never use compact format for input fields, detail screens, or settlement amounts.

### 2.2 Abbreviation Rules

| Range (Rupees) | Suffix | Precision | Examples |
|----------------|--------|-----------|----------|
| 0 to 99,999 | None | Full format | ₹50,000.00 |
| 1,00,000 to 99,99,999 | L (Lakh) | One decimal, drop trailing zero | ₹1.2L, ₹15L, ₹99.9L |
| 1,00,00,000 and above | Cr (Crore) | One decimal, drop trailing zero | ₹1.5Cr, ₹12Cr |

Detailed rules:

- The suffix is uppercase `L` for lakh and title-case `Cr` for crore.
- Display one decimal place. If the decimal is `.0`, drop it entirely (e.g., ₹5L, not ₹5.0L).
- Always prefix with `₹`. No space between the symbol and the number.
- No space between the number and the suffix.
- Round to the nearest tenth. Standard banker's rounding (half-even).

| Paise Value (int) | Rupee Value | Compact Display |
|--------------------|-------------|-----------------|
| 10000000 | 1,00,000 | ₹1L |
| 12000000 | 1,20,000 | ₹1.2L |
| 12345600 | 1,23,456 | ₹1.2L |
| 50000000 | 5,00,000 | ₹5L |
| 150000000 | 15,00,000 | ₹15L |
| 999999900 | 99,99,999 | ₹100L |
| 1000000000 | 1,00,00,000 | ₹1Cr |
| 1500000000 | 1,50,00,000 | ₹1.5Cr |
| 12345678900 | 12,34,56,789 | ₹12.3Cr |

### 2.3 Accessibility

When compact format is used, the screen reader semantic label must read the full unabbreviated value. For example, a widget displaying `₹1.2L` must have a semantic label of "1 lakh 20 thousand rupees" (SRS section 5.6).

---

## 3. Negative Balance Formatting

### 3.1 Source Requirements

- **SRS section 6.2:** Success colour Emerald (`#2A9D8F`) for "You are owed"; Danger colour Coral Red (`#E76F51`) for "You owe".
- **FR-HD-01 (SRS section 4.8):** Net balance displayed as "You are owed ₹X" or "You owe ₹Y".

### 3.2 Display Rules

Never display a minus sign or negative number. All balance communication is through colour and contextual labels.

| State | Colour Token | Light Mode Hex | Dark Mode Hex | Label Pattern |
|-------|-------------|----------------|---------------|---------------|
| You are owed (positive) | `color.success` | `#2A9D8F` | `#2A9D8F` (adjusted for dark surface contrast) | "You are owed ₹X" |
| You owe (negative) | `color.danger` | `#E76F51` | `#E76F51` (adjusted for dark surface contrast) | "You owe ₹X" |
| Settled (zero) | `color.onSurface.secondary` | Neutral grey `#6B7280` | `#9CA3AF` | "All settled up" or ₹0.00 |

### 3.3 Contextual Label Variants

The label wording changes depending on the screen context:

| Screen | Positive (owed to you) | Negative (you owe) | Zero |
|--------|------------------------|---------------------|------|
| Home dashboard hero | "You are owed ₹5,000.00" | "You owe ₹3,500.00" | "You're all settled up" |
| Friend list row | "owes you ₹350.00" | "you owe ₹200.00" | "settled up" |
| Friend detail header | "Rahul owes you ₹350.00" | "You owe Rahul ₹200.00" | "All settled up with Rahul" |
| Group list row | "you are owed ₹1,200.00" | "you owe ₹800.00" | "settled up" |
| Group detail member row | "owes ₹500.00" | "gets back ₹500.00" | "settled up" |
| Activity feed | "₹350.00" (colour indicates direction) | "₹200.00" (colour indicates direction) | -- |

### 3.4 Typography Weight

- Balance amounts use `fontWeight: w600` (semi-bold) to draw visual attention.
- Contextual labels ("You owe", "owes you") use `fontWeight: w400` (regular).
- The amount and the label are on the same baseline where space permits.

### 3.5 Accessibility

- Colour alone must not convey meaning (WCAG 2.1 AA, SRS section 5.6). The contextual label ("You owe" vs "You are owed") provides the textual distinction.
- Screen reader labels must include both the direction and the amount: "You owe 350 rupees" or "You are owed 5 thousand rupees".

---

## 4. Date and Time Formatting

### 4.1 Source Requirements

- **SRS section 5.9:** "Date/time displayed in IST (`Asia/Kolkata`) regardless of device locale."
- All timestamps in Firestore are stored as UTC. Conversion to IST (UTC+05:30) happens at the UI layer.

### 4.2 Format Table

| Context | Format Pattern | Example | Notes |
|---------|---------------|---------|-------|
| Expense date | `d MMM yyyy` | 15 Jan 2026 | No leading zero on day. Month abbreviated to 3 letters. |
| Activity feed (today) | `h:mm a` | 2:30 PM | 12-hour clock. No leading zero on hour. |
| Activity feed (yesterday) | `'Yesterday,' h:mm a` | Yesterday, 4:15 PM | Literal "Yesterday" prefix. |
| Activity feed (this week, not today/yesterday) | `EEE, h:mm a` | Mon, 2:30 PM | Abbreviated day name, 3 letters. |
| Activity feed (this year, older than this week) | `d MMM` | 15 Jan | Day and abbreviated month only. |
| Activity feed (previous years) | `d MMM yyyy` | 15 Jan 2025 | Full date, no time. |
| Full timestamp (detail screens) | `d MMM yyyy, h:mm a` | 15 Jan 2026, 2:30 PM | Used on expense detail, settlement detail. |
| Settle Up date | `d MMM yyyy` | 15 Jan 2026 | Date only, no time. |
| Group creation / membership change | `d MMM yyyy` | 15 Jan 2026 | Date only. |

### 4.3 Relative Time

For items within the last 24 hours, relative time labels may be used in the activity feed and notification cards:

| Elapsed Time | Display |
|--------------|---------|
| 0 to 59 seconds | "Just now" |
| 1 to 59 minutes | "X min ago" (e.g., "2 min ago") |
| 1 to 23 hours | "X hr ago" (e.g., "1 hr ago", "5 hrs ago") |
| 24 hours and beyond | Fall back to the absolute formats in section 4.2. |

Rules:
- Use singular "min" and "hr" (not "mins" or "hours") for brevity.
- Exception: use "hrs" (plural) for 2 hours and above.
- Relative time is used only in the activity feed and push notification bodies. All other screens use absolute formats.
- Relative time must be recalculated on screen focus or pull-to-refresh, not on a live timer.

### 4.4 Timezone

- All displayed times are in IST (UTC+05:30), regardless of the device's system timezone (SRS section 5.9).
- The timezone is not displayed in the formatted string. Users in India expect IST implicitly.
- If a future version supports multiple timezones, the formatting layer must be refactored; for v1.0, IST is hardcoded.

### 4.5 Accessibility

- Screen reader labels for dates use the unabbreviated form: "15 January 2026" not "15 Jan 2026".
- Screen reader labels for times include explicit "AM" or "PM" and "Indian Standard Time" on detail screens.

---

## 5. Phone Number Display

### 5.1 Source Requirements

- **SRS section 3.2:** Target users authenticate with +91 phone numbers.
- **SRS section 6.3, screen 2:** Phone-number entry screen has a locked +91 prefix.

### 5.2 Format

| Context | Format | Example |
|---------|--------|---------|
| Phone entry field | `+91` prefix (non-editable) + `XXXXX XXXXX` | +91 98765 43210 |
| Profile display | `+91 XXXXX XXXXX` | +91 98765 43210 |
| Contact list / friend list | Not displayed (name only) | -- |
| Screen reader label | "+91 9 8 7 6 5 4 3 2 1 0" (digit-by-digit after country code) | -- |

Rules:
- Always display the `+91` country code prefix.
- Group the 10-digit number as `XXXXX XXXXX` (five and five) with a single space.
- No hyphens, no parentheses, no dots.
- In contexts where the phone number is secondary information (e.g., a friend's profile sheet), the number may be partially masked: `+91 XXXXX X3210` (last 4 digits visible). This is a privacy consideration, not a formatting rule; the product manager will specify which screens require masking.

---

## 6. Name Display

### 6.1 Source Requirements

- **SRS section 6.3:** Profile setup captures display name.
- **FR-HD-01, FR-HD-02 (SRS section 4.8):** Dashboard shows friend and group names.

### 6.2 Truncation Rules

| Context | Max Characters | Truncation Method |
|---------|---------------|-------------------|
| List row (friends, groups, activity) | 20 | Ellipsis (`...`) after 20th character |
| Card title (dashboard top-5) | 16 | Ellipsis after 16th character |
| Detail screen header | 30 | Ellipsis after 30th character |
| Expense description in list | 24 | Ellipsis after 24th character |
| Full detail (profile, expense detail) | No limit | Wrap to next line |

Rules:
- Truncation is visual only. The full name must be available to screen readers and in tooltips (long-press).
- Truncation must not break mid-word if the break would leave fewer than 3 characters of the final word. In such cases, truncate before the word.
- Use the `TextOverflow.ellipsis` property in Flutter; do not manually append `...`.

### 6.3 "You" Replacement

When the currently authenticated user appears as a participant in an expense, settlement, or balance context, replace their display name with "You" (capitalised).

| Data | Display |
|------|---------|
| Payer is current user | "You paid ₹1,200.00" |
| Payer is another user | "Rahul paid ₹1,200.00" |
| Balance with current user | "You owe ₹350.00" |
| Split participant list | "You, Rahul, Priya" |
| Activity feed actor is current user | "You added an expense" |

Rules:
- "You" always appears first in participant lists, regardless of alphabetical order.
- The possessive form is "Your", not "you's".
- In screen reader labels, "You" is read as "You" (not the user's actual name) to match the visual display.

### 6.4 Sort Order

- Friend lists and group member lists are sorted alphabetically by display name (case-insensitive).
- "You" (the current user) always appears first in participant lists, before alphabetical sorting of other names.
- Groups are sorted by most recent activity (not alphabetical) on the Groups tab.

---

## 7. Typography Scale

### 7.1 Source Requirements

- **SRS section 6.2:** "Typography: Inter or Plus Jakarta Sans (Latin); fallback to system."
- **SRS section 5.6:** "The app shall fully support OS-level dynamic font scaling."

### 7.2 Type Scale

The following scale uses Material 3 naming conventions and is implemented via Flutter's `TextTheme`.

| Token Name | Font Family | Weight | Size (sp) | Line Height | Letter Spacing | Usage |
|------------|-------------|--------|-----------|-------------|----------------|-------|
| `displayLarge` | Plus Jakarta Sans | w700 | 32 | 40 | -0.5 | Dashboard net balance amount |
| `displayMedium` | Plus Jakarta Sans | w700 | 28 | 36 | -0.25 | Section headers (unused in v1.0, reserved) |
| `headlineLarge` | Plus Jakarta Sans | w600 | 24 | 32 | 0 | Screen titles |
| `headlineMedium` | Plus Jakarta Sans | w600 | 20 | 28 | 0 | Card titles, detail screen headers |
| `titleLarge` | Plus Jakarta Sans | w600 | 18 | 24 | 0.15 | List section headers |
| `titleMedium` | Plus Jakarta Sans | w500 | 16 | 22 | 0.15 | List item primary text, expense descriptions |
| `titleSmall` | Plus Jakarta Sans | w500 | 14 | 20 | 0.1 | Chip labels, secondary list text |
| `bodyLarge` | Inter | w400 | 16 | 24 | 0.15 | Body text, input fields |
| `bodyMedium` | Inter | w400 | 14 | 20 | 0.25 | Secondary body text, notes |
| `bodySmall` | Inter | w400 | 12 | 16 | 0.4 | Captions, timestamps, helper text |
| `labelLarge` | Inter | w500 | 14 | 20 | 0.1 | Button text |
| `labelMedium` | Inter | w500 | 12 | 16 | 0.5 | Tab labels, bottom nav labels |
| `labelSmall` | Inter | w500 | 11 | 16 | 0.5 | Overline text, badges |

### 7.3 Currency Amount Typography

Currency amounts have specific overrides regardless of context:

| Element | Token | Weight Override | Tabular Figures |
|---------|-------|-----------------|-----------------|
| Net balance hero (dashboard) | `displayLarge` | w700 | Yes |
| Balance in list row | `titleMedium` | w600 | Yes |
| Expense amount (detail) | `headlineMedium` | w600 | Yes |
| Expense amount (list row) | `titleMedium` | w600 | Yes |
| Input field (amount entry) | `headlineLarge` | w600 | Yes |

**Tabular figures** (`fontFeatures: [FontFeature.tabularFigures()]`) must be enabled for all currency displays so that digits align vertically in lists.

### 7.4 Dynamic Font Scaling

- All text sizes are specified in `sp` (scale-independent pixels) to honour OS-level font scaling (SRS section 5.6).
- Layouts must not clip or overlap at up to 2x font scale.
- At 1.5x and above, long currency values may trigger the compact format (section 2) even on screens that would normally use the full format. The threshold is layout-driven: if the full format would cause overflow, switch to compact.

---

## 8. Microcopy Tone

### 8.1 Source Requirements

- **SRS section 6.5:** "Friendly, concise, and lightly playful. No legalistic language outside the privacy policy and terms of service."

### 8.2 Guiding Principles

1. **Friendly, not formal.** Write as though speaking to a friend, not a customer.
2. **Concise.** Favour short sentences. One idea per line.
3. **Lightly playful.** A gentle touch of personality; never forced or twee.
4. **Culturally resonant.** References should feel natural to Indian users without being exclusionary.
5. **Actionable.** Every message should tell the user what to do next or confirm what just happened.

### 8.3 Standard Microcopy

#### Empty States (SRS section 6.4)

| Screen | Headline | Body | Action Label |
|--------|----------|------|--------------|
| Friends list (no friends) | "No friends yet" | "Add a friend to start splitting expenses." | "Add Friend" |
| Groups list (no groups) | "No groups yet" | "Create a group for your flat, trip, or dinner squad." | "Create Group" |
| Expense list (no expenses) | "No expenses here" | "Tap the + button to add your first expense." | -- (FAB serves as action) |
| Activity feed (empty) | "Nothing here yet" | "Your activity will show up as you add expenses and settle up." | -- |
| Settlement history (empty) | "No settlements yet" | "Settle up with a friend to see the record here." | -- |

#### Error States (SRS section 6.4)

| Scenario | Message | Action |
|----------|---------|--------|
| Network error (generic) | "Something went wrong. Check your connection and try again." | "Retry" |
| Timeout | "That took too long. Give it another go." | "Retry" |
| Server error (5xx) | "Our end, not yours. Please try again in a moment." | "Retry" |
| Split validation failure | "The splits don't add up to the total. Adjust and try again." | -- (inline) |
| Expense save failure | "Could not save the expense. Please try again." | "Retry" |
| Permission denied | "You don't have permission to do that." | "Go Back" |
| Persistent error (after 2 retries) | "Still not working? Reach out to us and we'll sort it." | "Contact Support" |

#### Success / Confirmation

| Action | Message |
|--------|---------|
| Expense added | "Expense added" (snackbar, 3 seconds) |
| Expense edited | "Expense updated" (snackbar, 3 seconds) |
| Expense deleted | "Expense deleted" (snackbar with "Undo", 5 seconds) |
| Settlement recorded | "Settled up -- nice one!" (snackbar, 3 seconds) |
| Friend added | "Friend added" (snackbar, 3 seconds) |
| Group created | "Group created" (snackbar, 3 seconds) |
| Profile updated | "Profile updated" (snackbar, 3 seconds) |
| Reminder sent | "Nudge sent" (snackbar, 3 seconds) |

#### Loading States (SRS section 6.4)

- Primary pattern: skeleton screens (shimmer placeholders matching the layout shape).
- Skeleton screens appear immediately on navigation.
- If data has not arrived after 1.5 seconds, overlay a subtle circular progress indicator at the centre of the skeleton.
- Loading microcopy is not displayed on skeleton screens. It is used only in modal actions:
  - Saving expense: "Saving..."
  - Recording settlement: "Settling up..."
  - Sending reminder: "Sending nudge..."
  - Deleting: "Deleting..."

#### Destructive Action Confirmation

| Action | Dialog Title | Dialog Body | Confirm Label | Cancel Label |
|--------|-------------|-------------|---------------|--------------|
| Delete expense | "Delete this expense?" | "This will update balances for everyone involved." | "Delete" | "Cancel" |
| Delete group | "Delete this group?" | "All expenses and balances in this group will be removed. This cannot be undone." | "Delete Group" | "Cancel" |
| Remove group member | "Remove [Name]?" | "Their share of existing expenses will be reassigned." | "Remove" | "Cancel" |

### 8.4 Language and Style Rules

| Rule | Correct | Incorrect |
|------|---------|-----------|
| Use contractions | "You're all settled up" | "You are all settled up" (acceptable but less warm) |
| Sentence case for UI labels | "Add expense" | "Add Expense" |
| Title case for screen titles | "Friends" | "friends" |
| No full stops on single-sentence snackbars | "Expense added" | "Expense added." |
| Full stops on multi-sentence body text | "The splits don't add up to the total. Adjust and try again." | (omitting the full stop) |
| No exclamation marks except celebrations | "Settled up -- nice one!" | "Error! Something went wrong!" |
| British English spelling | "colour", "favourite", "organised" | "color", "favorite", "organized" |
| Use "settled up" not "paid off" | "All settled up" | "All paid off" |

---

## 9. Cross-Cutting Accessibility Requirements

These requirements apply across all formatting rules above. They derive from SRS section 5.6.

| Requirement | Specification |
|-------------|--------------|
| Contrast ratio (body text) | Minimum 4.5:1 against surface (WCAG 2.1 AA) |
| Contrast ratio (large text, 18sp+) | Minimum 3:1 against surface |
| Colour semantics | Colour is never the sole indicator of meaning; always paired with text labels |
| Tap targets | Minimum 44x44 pt (iOS), 48x48 dp (Android) |
| Screen reader: currency | Read as "[amount] rupees", e.g., "5 thousand rupees" or "350 rupees" |
| Screen reader: dates | Read unabbreviated, e.g., "15 January 2026" |
| Screen reader: phone numbers | Read digit-by-digit after country code |
| Screen reader: balance direction | Include "you owe" or "you are owed" in the semantic label |
| Dynamic font scaling | All text respects OS scaling up to 2x without clipping |
| Dark mode | All colour tokens have dark-mode variants; verified for contrast compliance |

---

*This specification is version-locked to One By Two v1.0. Any formatting rule not covered here (e.g., multi-currency, Hindi localisation) is out of scope per SRS section 12.3.*