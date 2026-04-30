# OneByTwo v1.0 -- Component Catalogue

This document defines the reusable widget library for OneByTwo v1.0. Every component is specified with its visual description, data inputs, interactive states, accessibility behaviour, and the SRS requirements it satisfies. The Flutter Developer should consume this catalogue as the authoritative design contract when implementing the `lib/common/widgets/` and feature-specific widget directories.

All monetary values arriving as props are **integer paise** (Invariant 1). Conversion to rupees with Indian numbering formatting is the responsibility of the UI layer -- specifically, the `OBTRupeeText` component or the formatter it wraps.

---

## Design Token Reference

All components draw from the visual system defined in SRS section 6.2. Tokens are referenced by name throughout.

| Token Name | Light Value | Dark Value | Usage |
|---|---|---|---|
| `primary` | `#1F4E79` | `#2E86AB` | Primary actions, highlights |
| `secondary` | `#F4A261` | `#F4A261` | Secondary highlights, India-flavoured accents |
| `success` | `#2A9D8F` | `#2A9D8F` | "You are owed", positive balance states |
| `danger` | `#E76F51` | `#E76F51` | "You owe", destructive actions |
| `surface` | `#FFFFFF` | `#121212` | Cards, sheets, backgrounds |
| `cornerRadiusSmall` | 16 dp | 16 dp | Buttons, pills, inputs |
| `cornerRadiusLarge` | 24 dp | 24 dp | Cards, bottom sheets |
| `motionStandard` | 200--300 ms ease-in-out | -- | Transitions, state changes |
| `motionSpring` | Spring physics (damping ~0.7) | -- | FAB press/release |
| `elevationLow` | 1 dp shadow | -- | Resting cards |
| `elevationMedium` | 4 dp shadow | -- | Raised cards, FAB |
| `tapTargetMin` | 48x48 dp (Android) / 44x44 pt (iOS) | -- | All interactive elements |

Typography: Inter or Plus Jakarta Sans (Latin); system fallback for non-Latin scripts.

---

## 1. OBTAppBar

**Visual description:** A custom top app bar with a centred or left-aligned title, an optional leading back/close icon, and up to two trailing action icons, rendered on the surface colour with subtle bottom elevation.

| Property | Type | Required | Description |
|---|---|---|---|
| `title` | `String` | Yes | Screen title text. |
| `showBackButton` | `bool` | No (default: `false`) | Whether to render the leading back arrow. |
| `onBack` | `VoidCallback?` | No | Callback when back is tapped; if null, uses `Navigator.pop`. |
| `actions` | `List<OBTAppBarAction>` | No (default: empty) | Trailing icon buttons (max 2). Each action has `icon`, `onTap`, `semanticLabel`. |
| `elevation` | `double` | No (default: 0.5) | Bottom shadow depth. |

**States:**

| State | Behaviour |
|---|---|
| Default | Title displayed; actions in idle colour (`primary`). |
| Pressed (action icon) | Ink ripple on the icon; 200 ms fade. |
| Scrolled-under | Elevation increases to `elevationMedium`; surface tints slightly. |

**Accessibility:**

- Semantics: The title is announced as a heading (`Semantics(header: true)`).
- Back button carries the label `"Navigate back"`.
- Each action icon must have a unique `semanticLabel` (e.g., `"Search"`, `"Settings"`).
- Minimum tap target: 48x48 dp for all interactive elements.

**SRS references:** Section 6.3 (all core screens use the app bar); section 5.6 (tap targets, screen-reader labels).

---

## 2. OBTBottomNav

**Visual description:** A five-tab bottom navigation bar with icon-and-label pairs, a subtle top border, and the active tab indicated by a filled icon and `primary` colour tint, resting on the `surface` colour.

| Property | Type | Required | Description |
|---|---|---|---|
| `currentIndex` | `int` | Yes | Index of the active tab (0--4). |
| `onTabSelected` | `Function(int)` | Yes | Callback when a tab is tapped. |

**Tabs (fixed):**

| Index | Label | Icon (outlined/filled) | Destination |
|---|---|---|---|
| 0 | Home | `home` | Home Dashboard |
| 1 | Friends | `people` | Friends List |
| 2 | Groups | `groups` | Groups List |
| 3 | Activity | `notifications` | Activity Feed |
| 4 | Profile | `person` | Profile & Settings |

**States:**

| State | Behaviour |
|---|---|
| Default (inactive tab) | Outlined icon, muted label colour. |
| Active tab | Filled icon, `primary` colour label, indicator pill behind icon. |
| Pressed | Ink ripple; 200 ms transition to active state. |

**Accessibility:**

- Each tab is a `BottomNavigationBarItem` with `label` as the semantic label.
- Active tab announces `"Selected"` suffix (e.g., `"Home, tab, selected"`).
- Role: `tab` within a `tabBar` semantic group.
- Minimum tap target per tab: 48x48 dp.

**SRS references:** Section 6.3 (Home, Friends, Groups, Activity, Profile are the five primary screens); FR-HD-01 through FR-HD-04 (Home); FR-AC-01 (Activity); FR-PR-01 through FR-PR-05 (Profile); section 5.6.

---

## 3. OBTFloatingActionButton

**Visual description:** A circular FAB in `secondary` (Saffron/Marigold) with a white `+` icon, floating above the bottom navigation bar with `elevationMedium`, and employing spring physics on press.

| Property | Type | Required | Description |
|---|---|---|---|
| `onPressed` | `VoidCallback` | Yes | Opens the Add Expense flow. |
| `heroTag` | `String` | No (default: `"addExpenseFAB"`) | Hero animation tag for page transitions. |

**States:**

| State | Behaviour |
|---|---|
| Default | Resting at `elevationMedium`; `secondary` background, white `+` icon. |
| Pressed | Spring-physics scale-down to 0.92x, elevation increases; 200 ms spring release on lift. |
| Disabled | Not applicable -- FAB is always active on primary tabs. |

**Accessibility:**

- Semantic label: `"Add new expense"`.
- Role: `button`.
- Announces `"Add new expense, button"` on focus.
- Tap target: 56x56 dp (exceeds 48x48 dp minimum).

**SRS references:** FR-HD-04 (persistent FAB on any primary tab); section 6.2 (spring physics on FAB); section 5.6 (tap target).

---

## 4. OBTBalancePill

**Visual description:** A compact, rounded pill (corner radius 16 dp) displaying a formatted rupee balance, colour-coded green for credit, red for debit, and grey for settled, with a tinted background at 12% opacity of the text colour.

| Property | Type | Required | Description |
|---|---|---|---|
| `balancePaise` | `int` | Yes | Net balance in paise. Positive = user is owed; negative = user owes; zero = settled. |
| `size` | `enum { small, medium }` | No (default: `medium`) | Controls font size and padding. |

**Rendering logic:**

| Condition | Text | Text Colour | Background |
|---|---|---|---|
| `balancePaise > 0` | `"you are owed ₹X"` | `success` (`#2A9D8F`) | `success` at 12% opacity |
| `balancePaise < 0` | `"you owe ₹X"` | `danger` (`#E76F51`) | `danger` at 12% opacity |
| `balancePaise == 0` | `"settled up"` | `onSurface` (muted) | `onSurface` at 8% opacity |

Amount `X` is formatted via `OBTRupeeText` logic (Indian numbering, two decimal places from paise conversion).

**States:**

| State | Behaviour |
|---|---|
| Default | Static pill; no interaction. |
| Pressed | Not interactive on its own; parent widget handles taps. |

**Accessibility:**

- Semantic label pattern: `"Balance: you are owed rupees 1,234.50"` or `"Balance: you owe rupees 500.00"` or `"Balance: settled up"`.
- Uses `Semantics(label:)` with the full spoken text; the rupee symbol is read as `"rupees"`.
- Excludes decorative background from semantics.

**SRS references:** FR-FR-03, FR-GR-04, FR-HD-01 (simplified balance display); FR-SE-01 (simplified debts as canonical view); FR-EX-09 (INR formatting); section 6.2 (success/danger tokens).

---

## 5. OBTRupeeText

**Visual description:** An inline text widget rendering a monetary value prefixed with the `₹` symbol and formatted using the Indian numbering system (e.g., `₹1,23,456.78`), with configurable font weight and colour.

| Property | Type | Required | Description |
|---|---|---|---|
| `amountPaise` | `int` | Yes | Amount in paise (Invariant 1). |
| `style` | `TextStyle?` | No | Override default text style. |
| `showSign` | `bool` | No (default: `false`) | Prefix with `+` or `-` for signed display. |
| `color` | `Color?` | No | Override text colour (useful for balance contexts). |
| `compact` | `bool` | No (default: `false`) | Abbreviate large values (e.g., `₹1.2L`) -- not for v1.0; reserved prop. |

**Formatting rules:**

1. Divide `amountPaise` by 100 to get rupees.
2. Always show exactly two decimal places.
3. Apply Indian grouping: last three digits, then groups of two (e.g., `12,34,567.00`).
4. Prefix with `₹` (no space between symbol and digits).
5. Absolute value for display; sign controlled by `showSign`.

**States:**

| State | Behaviour |
|---|---|
| Default | Renders formatted text. |
| No other states | Pure display widget. |

**Accessibility:**

- Semantic label: `"rupees [amount in words or digits]"` -- e.g., `"rupees 1,23,456.78"`.
- The `₹` symbol is mapped to the spoken word `"rupees"` in the semantic label so screen readers do not say `"currency sign"`.

**SRS references:** FR-EX-09 (₹ symbol, Indian numbering); section 5.9 (Indian numbering, two decimal places, ₹ prefix); Invariant 1 (integer paise).

---

## 6. OBTAmountInput

**Visual description:** A text field with a non-editable `₹` prefix, large numeric font, bottom-aligned in the input area, with real-time Indian numbering formatting as the user types, and an optional decimal toggle.

| Property | Type | Required | Description |
|---|---|---|---|
| `initialAmountPaise` | `int?` | No | Pre-filled amount for edit flows. |
| `onChanged` | `Function(int)` | Yes | Returns the current value in paise on every valid change. |
| `autoFocus` | `bool` | No (default: `true`) | Whether to open the keyboard immediately. |
| `errorText` | `String?` | No | Inline validation message displayed below the field. |
| `enabled` | `bool` | No (default: `true`) | Controls editability. |

**Behaviour:**

- Keyboard type: numeric with decimal.
- As the user types, digits are live-formatted with Indian grouping separators.
- Maximum value: `₹99,99,999.99` (99,99,999 rupees 99 paise) -- prevents overflow.
- Backspace removes one digit at a time; separators reflow automatically.
- Output value is always integer paise.

**States:**

| State | Behaviour |
|---|---|
| Default (empty) | `₹` prefix shown; placeholder text `"0.00"` in muted colour. |
| Focused | Bottom border animates to `primary`; `₹` prefix in `primary` colour. |
| Filled | Formatted value displayed; bottom border returns to default. |
| Error | Bottom border in `danger`; `errorText` shown below in `danger` colour. |
| Disabled | Greyed out; no keyboard response. |

**Accessibility:**

- Semantic label: `"Enter amount in rupees"`.
- Announces current value on change: `"rupees [formatted amount]"`.
- Error state announces the error text after the value.
- Role: `textField`.

**SRS references:** FR-EX-01 (amount entry); FR-EX-09 (₹ formatting, Indian numbering); FR-EX-04 (split validation relies on accurate paise input); Invariant 1 (integer paise output); section 5.6 (tap target for the field).

---

## 7. OBTOTPInput

**Visual description:** A row of six individual square cells (48x48 dp each), each holding a single digit, with automatic cursor advance on entry and automatic cursor retreat on backspace, underlined in `primary` when focused.

| Property | Type | Required | Description |
|---|---|---|---|
| `onCompleted` | `Function(String)` | Yes | Fires when all six digits have been entered. |
| `onChanged` | `Function(String)` | No | Fires on every digit change with the current partial code. |
| `errorText` | `String?` | No | Error message shown below the cells (e.g., `"Incorrect code, try again"`). |
| `isLoading` | `bool` | No (default: `false`) | Shows a progress indicator in place of cells during verification. |
| `enabled` | `bool` | No (default: `true`) | Disables input during cooldown or verification. |

**States:**

| State | Behaviour |
|---|---|
| Default (empty) | Six empty cells with muted bottom borders. |
| Focused (cell N) | Cell N has a `primary`-coloured bottom border and a blinking cursor. |
| Filled | Digit displayed centred in the cell; border becomes solid muted. |
| Error | All cell borders turn `danger`; `errorText` appears below in `danger` colour; cells clear after 1 second for retry. |
| Loading | Cells replaced by a centred indeterminate progress indicator in `primary`. |
| Disabled | Cells greyed out; keyboard dismissed. |

**Behaviour notes:**

- On Android, attempts auto-read via SMS Retriever API (FR-AU-04); on success, all six cells populate and `onCompleted` fires.
- On iOS, allows paste from clipboard if the pasted string is exactly six digits.
- Tapping a filled cell moves the cursor to that cell for correction.

**Accessibility:**

- Semantic label for the group: `"Enter 6-digit verification code"`.
- Each cell announces `"Digit [N] of 6"` on focus.
- On completion, announces `"Verification code entered"`.
- Error state announces the error text.

**SRS references:** FR-AU-03, FR-AU-04 (OTP entry and auto-read); FR-AU-05 (retry after cooldown -- handled by parent screen, not this widget); section 5.6 (48x48 dp cells meet tap target).

---

## 8. OBTPhoneInput

**Visual description:** A text field with a non-editable `+91` prefix rendered in a distinct left-aligned compartment separated by a vertical divider, followed by the editable 10-digit phone number area with spacing formatted as `XXXXX XXXXX`.

| Property | Type | Required | Description |
|---|---|---|---|
| `onChanged` | `Function(String)` | Yes | Returns the raw 10-digit string (no spaces, no prefix) on every change. |
| `onSubmitted` | `Function(String)` | No | Fires on keyboard "done" action. |
| `errorText` | `String?` | No | Inline validation error (e.g., `"Please enter a valid 10-digit mobile number"`). |
| `autoFocus` | `bool` | No (default: `true`) | Opens the numeric keyboard immediately. |
| `enabled` | `bool` | No (default: `true`) | Controls editability. |

**Validation (client-side):**

- Accepts only digits.
- Rejects if length is not exactly 10 after stripping spaces.
- FR-AU-02: must be a valid Indian mobile number (starts with 6, 7, 8, or 9).

**States:**

| State | Behaviour |
|---|---|
| Default (empty) | `+91` prefix shown; placeholder `"Enter mobile number"` in muted colour. |
| Focused | Bottom border animates to `primary`. |
| Filled (valid) | Formatted number displayed; border returns to default. |
| Error | Bottom border in `danger`; `errorText` below. |
| Disabled | Greyed out; `+91` prefix remains visible but muted. |

**Accessibility:**

- Semantic label: `"Phone number, India country code plus 91"`.
- The `+91` prefix is announced but marked as non-editable.
- Error state announces the error text.
- Role: `textField`.

**SRS references:** FR-AU-01 (locked +91 prefix); FR-AU-02 (10-digit validation); section 6.3 (Phone-number entry screen); section 5.6 (tap target, screen reader).

---

## 9. OBTContactPicker

**Visual description:** A full-screen overlay or bottom sheet presenting the device contact list with a search bar at the top, alphabetical section headers, and each row showing the contact name, phone number, and a trailing indicator if the contact is already a OneByTwo user.

| Property | Type | Required | Description |
|---|---|---|---|
| `onContactSelected` | `Function(Contact)` | Yes | Returns the selected contact (name, phone number). |
| `existingUserIds` | `Set<String>` | No | Set of phone numbers already on OneByTwo, used to show the "on OneByTwo" badge. |
| `excludeNumbers` | `Set<String>` | No | Numbers to hide (e.g., already in the group). |
| `title` | `String` | No (default: `"Select contact"`) | Header text. |

**Sub-components:**

- `OBTSearchBar` (component 23) at the top for filtering.
- Each contact row: avatar (initials fallback), name, phone number, optional `"on OneByTwo"` chip.

**States:**

| State | Behaviour |
|---|---|
| Default | Contact list loaded, sorted alphabetically. |
| Loading | `OBTSkeletonLoader` rows while contacts are being read from the device. |
| Empty (no contacts) | `OBTEmptyState` with message `"No contacts found. You can enter a number manually."` |
| Search active | Filtered list updates in real time; no results shows inline `"No matches"`. |
| Permission denied | `OBTErrorState` with message `"Contact access is needed to add friends. You can grant permission in Settings."` and a CTA to open device settings. |

**Accessibility:**

- The search bar is labelled `"Search contacts"`.
- Each contact row announces `"[Name], [phone number], [on OneByTwo / not on OneByTwo]"`.
- Section headers announced as headings.
- Role: `list` for the contact list; `listItem` for each row.

**SRS references:** FR-FR-01 (add friend via contact picker); FR-FR-02 (distinguish existing users from invitable contacts); FR-GR-02 (invite group members via contact picker); section 5.6 (tap targets, screen reader).

---

## 10. OBTGroupAvatar

**Visual description:** A circular avatar (default 48 dp diameter) displaying the group's cover photo, or a fallback showing a coloured background derived from the group name's hash with the first letter of the group name in white, bold, centred text.

| Property | Type | Required | Description |
|---|---|---|---|
| `imageUrl` | `String?` | No | URL of the group cover photo from Firebase Storage. |
| `groupName` | `String` | Yes | Used for fallback initial and colour hash. |
| `size` | `double` | No (default: 48 dp) | Diameter. |
| `groupType` | `enum { trip, home, couple, other }` | No | If provided, overlays a tiny type icon at the bottom-right. |

**States:**

| State | Behaviour |
|---|---|
| Image loaded | Circular-cropped photo displayed. |
| Image loading | Circular shimmer placeholder. |
| Image error / no URL | Fallback initial on hashed-colour background. |

**Accessibility:**

- Semantic label: `"[Group name] group photo"` or `"[Group name] group, [type]"` if type is provided.
- Decorative when adjacent to a text label that already names the group -- in that case, `excludeSemantics: true` on the avatar and the label carries the semantics.

**SRS references:** FR-GR-01 (group with name, type, optional cover photo); section 6.3 (Groups list and Group detail screens); section 5.6.

---

## 11. OBTUserAvatar

**Visual description:** A circular avatar (default 40 dp diameter) displaying the user's profile photo, or a fallback showing a coloured background derived from the user's name hash with the user's initials (first letter of first name and first letter of last name, or single initial) in white, bold, centred text.

| Property | Type | Required | Description |
|---|---|---|---|
| `imageUrl` | `String?` | No | URL of the profile photo. |
| `displayName` | `String` | Yes | Used for fallback initials and colour hash. |
| `size` | `double` | No (default: 40 dp) | Diameter. |
| `showOnlineIndicator` | `bool` | No (default: `false`) | Reserved for future use. |

**States:**

| State | Behaviour |
|---|---|
| Image loaded | Circular-cropped photo. |
| Image loading | Circular shimmer placeholder. |
| Image error / no URL | Initials on hashed-colour background. |

**Accessibility:**

- Semantic label: `"[Display name] profile photo"`.
- When used inside a list tile that already announces the name, set `excludeSemantics: true`.

**SRS references:** FR-PR-01 (profile photo); FR-AU-06 (profile setup photo); section 6.3 (Profile, Friends, Groups screens); section 5.6.

---

## 12. OBTCategoryChip

**Visual description:** A compact chip with a leading category icon and the category label text, using a tinted background matching the category's assigned colour at 12% opacity, with corner radius 16 dp.

| Property | Type | Required | Description |
|---|---|---|---|
| `category` | `enum { food, travel, rent, utilities, groceries, entertainment, shopping, other }` | Yes | The expense category. |
| `isSelected` | `bool` | No (default: `false`) | Whether the chip is in a selected state (used in filter/picker contexts). |
| `onTap` | `VoidCallback?` | No | If provided, the chip is interactive. |

**Category icon and colour mapping:**

| Category | Icon | Colour |
|---|---|---|
| Food | `restaurant` | `#E76F51` (warm) |
| Travel | `flight` | `#2E86AB` (blue) |
| Rent | `home` | `#1F4E79` (indigo) |
| Utilities | `bolt` | `#F4A261` (saffron) |
| Groceries | `shopping_cart` | `#2A9D8F` (emerald) |
| Entertainment | `movie` | `#9B59B6` (purple) |
| Shopping | `shopping_bag` | `#E67E22` (orange) |
| Other | `more_horiz` | `#7F8C8D` (grey) |

**States:**

| State | Behaviour |
|---|---|
| Default (unselected) | Tinted background, muted icon and label. |
| Selected | Full category colour background at 20% opacity; icon and label in full colour; subtle border. |
| Pressed | Ink ripple; 200 ms transition. |
| Disabled | Not applicable for v1.0. |

**Accessibility:**

- Semantic label: `"[Category name] category"` (e.g., `"Food category"`).
- When selectable, announces `"[Category name] category, [selected/not selected]"`.
- Role: `button` when interactive; none when purely decorative.
- Minimum tap target: 48x48 dp (chip height may be less, but touch target extends).

**SRS references:** FR-EX-08 (predefined categories with icons); FR-SR-02 (filter by category); section 6.2 (corner radius 16 dp).

---

## 13. OBTSettleUpCard

**Visual description:** A surface card (corner radius 24 dp, `elevationLow`) showing a payer avatar, a directional arrow, a payee avatar, the settlement amount in `danger` colour, and a prominent `"Settle Up"` CTA button in `primary`.

| Property | Type | Required | Description |
|---|---|---|---|
| `payerName` | `String` | Yes | Display name of the person who owes. |
| `payerImageUrl` | `String?` | No | Profile photo URL of the payer. |
| `payeeName` | `String` | Yes | Display name of the person who is owed. |
| `payeeImageUrl` | `String?` | No | Profile photo URL of the payee. |
| `amountPaise` | `int` | Yes | Suggested settlement amount in paise. |
| `onSettleUp` | `VoidCallback` | Yes | Opens the Settle Up flow with pre-filled data. |
| `context` | `String?` | No | Optional context label (e.g., group name). |

**States:**

| State | Behaviour |
|---|---|
| Default | Card at rest; CTA button in `primary`. |
| CTA Pressed | Button ink ripple; transitions to Settle Up flow. |
| Loading (settling) | CTA replaced by a small progress indicator; card non-interactive. |

**Accessibility:**

- Semantic label: `"[Payer name] owes [Payee name] rupees [amount]. Settle up button available."`.
- The `"Settle Up"` button has its own label: `"Settle up, rupees [amount]"`.
- Role: card is a semantic container; CTA is a `button`.

**SRS references:** FR-SE-05 (pre-filled settle up UI); FR-SE-07 (Settle Up CTA on every screen with non-zero balance); FR-HD-02 (top 5 with quick settle); section 6.2 (corner radius 24 dp, elevation).

---

## 14. OBTActivityRow

**Visual description:** A single row in the activity feed with a leading coloured icon indicating the event type, a two-line text block (primary text describing the event, secondary text with relative timestamp), and an optional trailing amount.

| Property | Type | Required | Description |
|---|---|---|---|
| `eventType` | `enum { expenseAdded, expenseEdited, expenseDeleted, settlementRecorded, groupCreated, groupMemberAdded, groupMemberRemoved, friendAdded }` | Yes | Determines the icon and colour. |
| `primaryText` | `String` | Yes | Main description (e.g., `"Priya added 'Dinner at Dosa Plaza'"`). |
| `secondaryText` | `String` | Yes | Relative timestamp (e.g., `"2 hours ago"`). |
| `amountPaise` | `int?` | No | Trailing amount if relevant. |
| `onTap` | `VoidCallback` | Yes | Deep-links to the relevant screen. |

**Event type icon mapping:**

| Event Type | Icon | Colour |
|---|---|---|
| expenseAdded | `receipt_long` | `primary` |
| expenseEdited | `edit` | `secondary` |
| expenseDeleted | `delete` | `danger` |
| settlementRecorded | `check_circle` | `success` |
| groupCreated | `group_add` | `primary` |
| groupMemberAdded | `person_add` | `primary` |
| groupMemberRemoved | `person_remove` | `danger` |
| friendAdded | `person_add` | `success` |

**States:**

| State | Behaviour |
|---|---|
| Default | Idle row. |
| Pressed | Background tints to `primary` at 6% opacity; 200 ms transition; navigates on release. |
| Unread | Left edge has a 3 dp `primary` bar indicator. |
| Read | No left bar. |

**Accessibility:**

- Semantic label: `"[Primary text]. [Secondary text]. [Amount if present]. Tap to view details."`.
- Role: `button` (tappable).
- Minimum row height: 56 dp (ensures 48x48 dp tap target with padding).

**SRS references:** FR-AC-01 (activity feed); FR-AC-02 (deep-link on tap); FR-EX-07 (edit/delete in feed); section 6.3 (Activity feed screen); section 5.6.

---

## 15. OBTExpenseListTile

**Visual description:** A list tile with a leading category icon chip, a two-line text block (expense description on line one; payer name and date on line two), and a trailing balance amount coloured by whether the current user paid or owes.

| Property | Type | Required | Description |
|---|---|---|---|
| `description` | `String` | Yes | Expense description text. |
| `category` | `CategoryEnum` | Yes | Expense category (renders the leading `OBTCategoryChip` icon). |
| `payerName` | `String` | Yes | Who paid. |
| `date` | `DateTime` | Yes | Expense date, displayed as `dd MMM` (e.g., `"14 Mar"`). |
| `totalAmountPaise` | `int` | Yes | Total expense amount in paise. |
| `userSharePaise` | `int` | Yes | Current user's share in paise (signed: positive = user lent, negative = user borrowed). |
| `onTap` | `VoidCallback` | Yes | Navigates to expense detail. |

**States:**

| State | Behaviour |
|---|---|
| Default | Idle tile. |
| Pressed | Background tints; 200 ms transition. |

**Accessibility:**

- Semantic label: `"[Description], [category], paid by [payer], [date], your share: [you lent / you borrowed] rupees [amount]"`.
- Role: `button`.
- Minimum tile height: 64 dp.

**SRS references:** FR-EX-01 (expense fields); FR-EX-08 (categories); FR-EX-09 (INR formatting); FR-FR-04 (per-friend expense history); FR-GR-04 (group expense list); section 5.6.

---

## 16. OBTFriendListTile

**Visual description:** A list tile with a leading `OBTUserAvatar`, a primary line showing the friend's display name, and a trailing `OBTBalancePill` showing the net simplified balance.

| Property | Type | Required | Description |
|---|---|---|---|
| `displayName` | `String` | Yes | Friend's display name. |
| `imageUrl` | `String?` | No | Profile photo URL. |
| `balancePaise` | `int` | Yes | Net simplified balance in paise (positive = owed to user). |
| `onTap` | `VoidCallback` | Yes | Navigates to Friend detail. |

**States:**

| State | Behaviour |
|---|---|
| Default | Idle tile. |
| Pressed | Background tints; 200 ms transition. |

**Accessibility:**

- Semantic label: `"[Display name], [balance pill text]"`.
- The avatar is excluded from semantics (name is already announced).
- Role: `button`.
- Minimum tile height: 56 dp.

**SRS references:** FR-FR-03 (friends list with balance); FR-SE-01 (simplified balance only); section 6.3 (Friends list screen); section 5.6.

---

## 17. OBTGroupListTile

**Visual description:** A list tile with a leading `OBTGroupAvatar`, a two-line text block (group name on line one; group type badge and member count on line two), and a trailing `OBTBalancePill`.

| Property | Type | Required | Description |
|---|---|---|---|
| `groupName` | `String` | Yes | Group display name. |
| `imageUrl` | `String?` | No | Group cover photo URL. |
| `groupType` | `GroupTypeEnum` | Yes | Trip, Home, Couple, or Other. |
| `memberCount` | `int` | Yes | Number of members. |
| `balancePaise` | `int` | Yes | User's net simplified balance within this group. |
| `onTap` | `VoidCallback` | Yes | Navigates to Group detail. |

**Group type badge rendering:**

| Type | Label | Colour |
|---|---|---|
| Trip | `"Trip"` | `#2E86AB` |
| Home | `"Home"` | `#1F4E79` |
| Couple | `"Couple"` | `#E76F51` |
| Other | `"Other"` | `#7F8C8D` |

**States:**

| State | Behaviour |
|---|---|
| Default | Idle tile. |
| Pressed | Background tints; 200 ms transition. |

**Accessibility:**

- Semantic label: `"[Group name], [group type], [member count] members, [balance pill text]"`.
- Avatar excluded from semantics.
- Role: `button`.
- Minimum tile height: 64 dp.

**SRS references:** FR-GR-01 (group with name and type); FR-GR-04 (group balance); section 6.3 (Groups list screen); section 5.6.

---

## 18. OBTEmptyState

**Visual description:** A vertically centred layout containing an illustrated SVG graphic at the top, a bold title below, a muted subtitle with helpful context, and an optional primary CTA button at the bottom, all on the `surface` background.

| Property | Type | Required | Description |
|---|---|---|---|
| `illustration` | `SvgAsset` | Yes | SVG illustration asset key. |
| `title` | `String` | Yes | Bold heading (e.g., `"No expenses yet"`). |
| `subtitle` | `String` | Yes | Explanatory subtext (e.g., `"Add your first expense and start splitting!"`). |
| `ctaLabel` | `String?` | No | Button label (e.g., `"Add Expense"`). |
| `onCtaTap` | `VoidCallback?` | No | CTA callback. |

**Microcopy examples (per SRS 6.5 tone):**

| Screen | Title | Subtitle |
|---|---|---|
| Friends list | `"No friends yet"` | `"Add a friend and start sharing expenses."` |
| Groups list | `"No groups yet"` | `"Create a group for your flat, trip, or couple."` |
| Activity feed | `"All quiet here"` | `"Your activity will show up as you add expenses and settle up."` |
| Expense list | `"No expenses yet"` | `"Tap the + button to add your first expense."` |
| Settlement history | `"No settlements yet"` | `"Once you settle up, it will appear here."` |

**States:**

| State | Behaviour |
|---|---|
| Default | Static layout, CTA button in `primary` if present. |
| CTA Pressed | Standard button press animation. |

**Accessibility:**

- Illustration is decorative: `excludeSemantics: true`.
- Title announced as a heading.
- Subtitle announced as body text.
- CTA button has its own semantic label matching `ctaLabel`.
- The entire empty state is grouped as a single semantic node if no CTA is present.

**SRS references:** Section 6.4 (every list must have an empty state with actionable copy); section 6.5 (microcopy tone).

---

## 19. OBTErrorState

**Visual description:** A vertically centred layout with an error illustration (muted, non-alarming), a bold error title, a descriptive subtitle, a primary `"Retry"` button, and a secondary `"Contact Support"` text link below it.

| Property | Type | Required | Description |
|---|---|---|---|
| `title` | `String` | No (default: `"Something went wrong"`) | Error heading. |
| `subtitle` | `String` | No (default: `"We could not load this. Please try again."`) | Descriptive subtext. |
| `onRetry` | `VoidCallback` | Yes | Retry callback. |
| `onContactSupport` | `VoidCallback?` | No | Opens the Contact Support flow (FR-PR-05). If null, the link is hidden. |
| `errorCode` | `String?` | No | Optional technical error code displayed in small muted text for support reference. |

**States:**

| State | Behaviour |
|---|---|
| Default | Static layout with Retry button in `primary`. |
| Retry Pressed | Button shows a loading indicator; re-invokes the failed operation. |
| Retry failed again | Returns to default state; subtitle may update to `"Still not working. Try again or contact support."` |

**Accessibility:**

- Illustration is decorative: `excludeSemantics: true`.
- Title announced as a heading.
- Retry button label: `"Retry"`.
- Support link label: `"Contact support"`.
- If `errorCode` is present, it is included in semantics: `"Error code: [code]"`.

**SRS references:** Section 6.4 (error states with Retry and path to Contact Support); FR-PR-05, FR-SH-03, FR-SH-04 (Contact Support action); section 6.5 (friendly, non-alarming tone).

---

## 20. OBTSkeletonLoader

**Visual description:** A shimmer-animated placeholder matching the shape and layout of the content it replaces, using light grey rectangles and circles with a left-to-right shine gradient sweep, on the `surface` background.

| Property | Type | Required | Description |
|---|---|---|---|
| `type` | `enum { listTile, card, balancePill, expenseDetail, activityRow, profileHeader, chart }` | Yes | Determines the skeleton shape. |
| `itemCount` | `int` | No (default: 5) | Number of skeleton rows to render (for list types). |

**Skeleton shape specifications:**

| Type | Layout |
|---|---|
| `listTile` | 40 dp circle + two 12 dp-high rounded rectangles (60% and 40% width) + trailing 48x20 dp rectangle. |
| `card` | 24 dp corner-radius rectangle, full width, 120 dp height, internal placeholder lines. |
| `balancePill` | Single 80x28 dp rounded rectangle. |
| `expenseDetail` | Full-width rectangle (header) + three line placeholders + amount block. |
| `activityRow` | 32 dp circle + two-line text block at 70% and 50% width. |
| `profileHeader` | Centred 80 dp circle + 40% width text line + 60% width text line. |
| `chart` | 160x160 dp circle (donut) + three 12 dp-high bar lines. |

**States:**

| State | Behaviour |
|---|---|
| Loading | Continuous shimmer animation (left-to-right, 1.5 s loop). |
| Loaded | Widget is replaced by actual content (parent handles transition; 200 ms fade-in). |

**Accessibility:**

- Entire skeleton is marked with `Semantics(label: "Loading content", liveRegion: true)`.
- When content loads, the live region announces the new content.
- Shimmer animation respects `AccessibilityFeatures.reduceMotion`; if motion is reduced, show a static grey placeholder without animation.

**SRS references:** Section 6.4 (skeleton screens preferred over spinners); section 5.6 (screen-reader compatibility, respecting OS accessibility settings).

---

## 21. OBTSplitMethodSelector

**Visual description:** A horizontally scrollable row of selectable chips (or a segmented control), each representing a split method, with the selected method highlighted in `primary` and an underline indicator.

| Property | Type | Required | Description |
|---|---|---|---|
| `selectedMethod` | `SplitMethodEnum` | Yes | Currently selected method. |
| `onMethodChanged` | `Function(SplitMethodEnum)` | Yes | Callback when selection changes. |
| `availableMethods` | `List<SplitMethodEnum>` | No (default: all five) | Methods to show (e.g., 1-to-1 may hide "By Shares"). |

**Split methods:**

| Value | Label | Icon | Description shown on selection |
|---|---|---|---|
| `equal` | `"Equal"` | `balance` | `"Split equally among all"` |
| `unequal` | `"Unequal"` | `tune` | `"Enter exact amounts for each person"` |
| `percentage` | `"Percentage"` | `percent` | `"Assign a percentage to each person"` |
| `shares` | `"Shares"` | `pie_chart` | `"Assign share units to each person"` |
| `exact` | `"Exact"` | `pin` | `"Enter the exact amount each person owes"` |

**States:**

| State | Behaviour |
|---|---|
| Default | All chips visible; selected chip in `primary` with filled background. |
| Chip Pressed | Ink ripple; 200 ms transition to selected state. |
| Unselected chip | Outlined style, muted text. |

**Accessibility:**

- Semantic group: `"Split method selector"`.
- Each chip announces `"[Method label], [selected/not selected]"`.
- On selection change, announces `"[Method label] selected. [Description]."`.
- Role: `radioGroup` containing `radio` items.

**SRS references:** FR-EX-03 (five split methods); section 6.3 (Add/Edit expense screen); section 5.6.

---

## 22. OBTSplitEntryRow

**Visual description:** A row within the split detail view showing a member's avatar, display name, and an editable field for their share (amount, percentage, or share units depending on the active split method), with real-time validation feedback.

| Property | Type | Required | Description |
|---|---|---|---|
| `displayName` | `String` | Yes | Member's name. |
| `imageUrl` | `String?` | No | Member's profile photo. |
| `splitMethod` | `SplitMethodEnum` | Yes | Determines the input type and suffix label. |
| `value` | `int` | Yes | Current value (paise for amount modes; basis points for percentage; integer for shares). |
| `onValueChanged` | `Function(int)` | Yes | Callback with updated value. |
| `isEditable` | `bool` | No (default: `true`) | Whether the value field is editable (false for "Equal" method). |
| `errorText` | `String?` | No | Per-row validation error. |

**Input field suffix by method:**

| Method | Suffix | Input Type |
|---|---|---|
| Equal | (no input; shows calculated share) | Read-only `OBTRupeeText` |
| Unequal | `₹` prefix | Numeric with decimal |
| Percentage | `%` suffix | Numeric, 0--100 |
| Shares | `shares` suffix | Integer stepper |
| Exact | `₹` prefix | Numeric with decimal |

**States:**

| State | Behaviour |
|---|---|
| Default | Name, avatar, value field displayed. |
| Focused | Value field border in `primary`. |
| Error | Value field border in `danger`; `errorText` below the field. |
| Read-only (Equal) | Value displayed as plain text; no input affordance. |

**Accessibility:**

- Semantic label: `"[Display name]'s share: [value] [unit]"` (e.g., `"Rahul's share: rupees 250.00"` or `"Priya's share: 33 percent"`).
- Error announced after the value.
- Role: `textField` when editable; `text` when read-only.

**SRS references:** FR-EX-03 (split methods); FR-EX-04 (splits must sum to total -- validation); section 5.6.

---

## 23. OBTSearchBar

**Visual description:** A rounded text field (corner radius 16 dp) with a leading search icon, placeholder text, and a trailing clear button that appears when text is entered, rendered with a subtle `surface` background tint.

| Property | Type | Required | Description |
|---|---|---|---|
| `hintText` | `String` | No (default: `"Search"`) | Placeholder text. |
| `onChanged` | `Function(String)` | Yes | Fires on every keystroke with the current query. |
| `onClear` | `VoidCallback?` | No | Callback when the clear button is tapped. |
| `autoFocus` | `bool` | No (default: `false`) | Whether to open the keyboard immediately. |

**States:**

| State | Behaviour |
|---|---|
| Default (empty) | Search icon + hint text; no clear button. |
| Focused | Border tints to `primary`; keyboard opens. |
| Filled | Query text displayed; trailing clear (`x`) button visible. |
| No results | Handled by the parent screen, not the search bar itself. |

**Accessibility:**

- Semantic label: `"Search, [hint text]"`.
- Clear button label: `"Clear search"`.
- Role: `textField`.
- Announces query text on change (debounced to avoid excessive announcements).

**SRS references:** FR-SR-01 (search by description, amount, category, member); section 6.3 (search overlay); section 5.6.

---

## 24. OBTConfirmationDialog

**Visual description:** A centred modal dialog on a dimmed scrim, with a title, body text, and two action buttons (cancel on the left in outlined style, confirm on the right in filled style), using corner radius 24 dp.

| Property | Type | Required | Description |
|---|---|---|---|
| `title` | `String` | Yes | Dialog heading (e.g., `"Delete expense?"`). |
| `body` | `String` | Yes | Explanatory text (e.g., `"This will remove the expense for everyone in the group. This cannot be undone."`). |
| `cancelLabel` | `String` | No (default: `"Cancel"`) | Cancel button text. |
| `confirmLabel` | `String` | Yes | Confirm button text (e.g., `"Delete"`, `"Leave group"`). |
| `isDestructive` | `bool` | No (default: `false`) | If true, confirm button uses `danger` colour. |
| `onCancel` | `VoidCallback` | Yes | Dismiss callback. |
| `onConfirm` | `VoidCallback` | Yes | Confirm action callback. |

**States:**

| State | Behaviour |
|---|---|
| Default | Both buttons idle. |
| Confirm Pressed | Ink ripple; may show loading indicator if the action is async. |
| Cancel Pressed | Dialog dismisses with 200 ms fade-out. |
| Loading | Confirm button shows a small progress indicator; both buttons disabled. |

**Accessibility:**

- Dialog is announced as a modal: `"Alert: [title]"`.
- Body text is read after the title.
- Cancel button: `"Cancel"`.
- Confirm button: `"[confirmLabel]"` (e.g., `"Delete"`).
- Focus is trapped within the dialog while open.
- Escape / back gesture dismisses (equivalent to Cancel).

**SRS references:** FR-EX-06 (delete expense confirmation); FR-GR-05, FR-GR-06, FR-GR-07 (remove member, leave group, delete group); FR-FR-05 (delete friend); FR-AU-09 (account deletion); section 5.6.

---

## 25. OBTSnackbar

**Visual description:** A brief floating bar at the bottom of the screen (above the bottom nav), with an icon, a single line of text, and an optional trailing action link, using corner radius 16 dp, dismissing automatically after a configurable duration.

| Property | Type | Required | Description |
|---|---|---|---|
| `message` | `String` | Yes | Feedback text (e.g., `"Expense added"`, `"Could not save. Try again."`). |
| `type` | `enum { success, error, info }` | Yes | Determines icon and colour scheme. |
| `actionLabel` | `String?` | No | Trailing action text (e.g., `"Undo"`, `"Retry"`). |
| `onAction` | `VoidCallback?` | No | Callback for the action. |
| `durationMs` | `int` | No (default: 4000) | Auto-dismiss duration. |

**Type styling:**

| Type | Icon | Background | Text Colour |
|---|---|---|---|
| `success` | `check_circle` | `success` at 15% opacity | `success` |
| `error` | `error` | `danger` at 15% opacity | `danger` |
| `info` | `info` | `primary` at 15% opacity | `primary` |

**States:**

| State | Behaviour |
|---|---|
| Entering | Slides up from the bottom; 200 ms ease-in-out. |
| Visible | Static for `durationMs` milliseconds. |
| Action tapped | Fires `onAction`; snackbar dismisses immediately. |
| Dismissing | Slides down; 200 ms ease-in-out. |
| Swiped | User swipe-down dismisses early. |

**Accessibility:**

- Announced as a live region: `"[Type]: [message]"` (e.g., `"Success: Expense added"`).
- Action button, if present, is focusable and labelled with `actionLabel`.
- Auto-dismiss timer pauses when a screen reader is active to give users time to read.

**SRS references:** FR-EX-06 (feedback on edit/delete); FR-SE-06 (feedback on settlement); FR-OF-02 (offline queued write feedback); section 6.4 (feedback states); section 6.5 (microcopy tone); section 5.6 (screen reader).

---

## Cross-Cutting Accessibility Requirements

The following requirements from SRS section 5.6 apply to **every** component in this catalogue:

| Requirement | Implementation Rule |
|---|---|
| Tap targets shall be at least 44x44 pt (iOS) / 48x48 dp (Android). | All interactive elements must meet this minimum, using padding to extend touch area where visual size is smaller. |
| WCAG 2.1 AA contrast (at least 4.5:1 for body text). | All text/background pairings must be verified against this ratio in both light and dark mode. |
| Dynamic font scaling. | All text widgets must use relative sizing (`sp` / `MediaQuery.textScaleFactor`) and layouts must not clip at 200% scale. |
| Dark mode. | Every component must render correctly on `surface: #121212` with appropriately adjusted token colours. |
| Screen-reader compatibility. | Every interactive widget has a `Semantics` node with label, role, and state. No information is conveyed by colour alone. |
| Semantic labels on every interactive widget. | Enforced by the `semanticLabel` patterns specified per-component above. |

---

## Component Dependency Graph

The following table maps which higher-level components compose lower-level ones, to guide the Flutter Developer's build order (leaf components first).

| Component | Depends On |
|---|---|
| `OBTAppBar` | -- |
| `OBTBottomNav` | -- |
| `OBTFloatingActionButton` | -- |
| `OBTRupeeText` | -- |
| `OBTBalancePill` | `OBTRupeeText` |
| `OBTAmountInput` | `OBTRupeeText` (formatting logic) |
| `OBTOTPInput` | -- |
| `OBTPhoneInput` | -- |
| `OBTUserAvatar` | -- |
| `OBTGroupAvatar` | -- |
| `OBTCategoryChip` | -- |
| `OBTSearchBar` | -- |
| `OBTSkeletonLoader` | -- |
| `OBTSnackbar` | -- |
| `OBTConfirmationDialog` | -- |
| `OBTEmptyState` | -- |
| `OBTErrorState` | -- |
| `OBTFriendListTile` | `OBTUserAvatar`, `OBTBalancePill` |
| `OBTGroupListTile` | `OBTGroupAvatar`, `OBTBalancePill` |
| `OBTExpenseListTile` | `OBTCategoryChip`, `OBTRupeeText` |
| `OBTActivityRow` | `OBTRupeeText` |
| `OBTSettleUpCard` | `OBTUserAvatar`, `OBTRupeeText` |
| `OBTSplitMethodSelector` | -- |
| `OBTSplitEntryRow` | `OBTUserAvatar`, `OBTRupeeText`, `OBTAmountInput` |
| `OBTContactPicker` | `OBTSearchBar`, `OBTUserAvatar`, `OBTSkeletonLoader`, `OBTEmptyState`, `OBTErrorState` |

**Recommended build order:** Start with leaf components (`OBTRupeeText`, `OBTUserAvatar`, `OBTGroupAvatar`, `OBTCategoryChip`, `OBTSearchBar`, `OBTSkeletonLoader`, `OBTSnackbar`, `OBTConfirmationDialog`, `OBTEmptyState`, `OBTErrorState`, `OBTBalancePill`, `OBTAmountInput`, `OBTOTPInput`, `OBTPhoneInput`, `OBTAppBar`, `OBTBottomNav`, `OBTFloatingActionButton`), then composed components (`OBTFriendListTile`, `OBTGroupListTile`, `OBTExpenseListTile`, `OBTActivityRow`, `OBTSettleUpCard`, `OBTSplitMethodSelector`, `OBTSplitEntryRow`), and finally the full-screen composite (`OBTContactPicker`).

---

## SRS Traceability Matrix

Every functional requirement referenced by at least one component is listed below for completeness.

| SRS Requirement | Component(s) |
|---|---|
| FR-AU-01 | `OBTPhoneInput` |
| FR-AU-02 | `OBTPhoneInput` |
| FR-AU-03 | `OBTOTPInput` |
| FR-AU-04 | `OBTOTPInput` |
| FR-AU-05 | `OBTOTPInput` (parent screen handles cooldown) |
| FR-AU-06 | `OBTUserAvatar` |
| FR-AU-09 | `OBTConfirmationDialog` |
| FR-PR-01 | `OBTUserAvatar` |
| FR-PR-05 | `OBTErrorState` |
| FR-FR-01 | `OBTContactPicker` |
| FR-FR-02 | `OBTContactPicker` |
| FR-FR-03 | `OBTFriendListTile`, `OBTBalancePill` |
| FR-FR-04 | `OBTExpenseListTile` |
| FR-FR-05 | `OBTConfirmationDialog` |
| FR-GR-01 | `OBTGroupAvatar`, `OBTGroupListTile` |
| FR-GR-02 | `OBTContactPicker` |
| FR-GR-04 | `OBTGroupListTile`, `OBTBalancePill`, `OBTExpenseListTile` |
| FR-GR-05, FR-GR-06, FR-GR-07 | `OBTConfirmationDialog` |
| FR-EX-01 | `OBTAmountInput`, `OBTExpenseListTile` |
| FR-EX-03 | `OBTSplitMethodSelector`, `OBTSplitEntryRow` |
| FR-EX-04 | `OBTSplitEntryRow` (validation), `OBTAmountInput` |
| FR-EX-06 | `OBTConfirmationDialog`, `OBTSnackbar` |
| FR-EX-07 | `OBTActivityRow` |
| FR-EX-08 | `OBTCategoryChip` |
| FR-EX-09 | `OBTRupeeText`, `OBTAmountInput`, `OBTBalancePill` |
| FR-SE-01 | `OBTBalancePill` |
| FR-SE-05 | `OBTSettleUpCard` |
| FR-SE-06 | `OBTSnackbar` |
| FR-SE-07 | `OBTSettleUpCard` |
| FR-AC-01 | `OBTActivityRow` |
| FR-AC-02 | `OBTActivityRow` |
| FR-SR-01 | `OBTSearchBar` |
| FR-SR-02 | `OBTCategoryChip`, `OBTSearchBar` |
| FR-HD-01 | `OBTBalancePill` |
| FR-HD-02 | `OBTSettleUpCard` |
| FR-HD-04 | `OBTFloatingActionButton` |
| FR-OF-02 | `OBTSnackbar` |
| FR-SH-03, FR-SH-04 | `OBTErrorState` (Contact Support link) |
| Section 5.6 | All components (accessibility) |
| Section 6.2 | All components (visual tokens) |
| Section 6.3 | All components (core screens) |
| Section 6.4 | `OBTEmptyState`, `OBTErrorState`, `OBTSkeletonLoader` |
| Section 6.5 | `OBTEmptyState`, `OBTErrorState`, `OBTSnackbar` (microcopy) |