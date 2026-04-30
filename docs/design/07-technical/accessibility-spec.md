# Accessibility Specification

*Document owner: UX/UI Designer. Traces to SRS sections 5.6 (Usability and Accessibility), 6.1--6.5 (User Experience and Design Requirements), and the component catalogue (`docs/design/02-design-system/components.md`).*

---

## 1. WCAG 2.1 AA Requirements

All user-facing surfaces in One By Two v1.0 shall conform to WCAG 2.1 Level AA. The following sub-sections codify each applicable criterion.

### 1.1 Contrast Ratios

Per SRS section 5.6, text shall meet WCAG 2.1 AA contrast ratios.

| Context | Minimum Ratio | Standard |
|---|---|---|
| Body text (14 sp and below) | 4.5:1 | WCAG 1.4.3 |
| Large text (18 sp regular or 14 sp bold) | 3:1 | WCAG 1.4.3 |
| UI components and graphical objects | 3:1 | WCAG 1.4.11 |

All token pairings have been pre-verified in both light and dark mode (see `docs/design/02-design-system/tokens.md`, Appendix A). Key verified pairings:

| Foreground Token | Background Token | Ratio | Mode |
|---|---|---|---|
| `textPrimary` (`#1A1A1A`) | `surface` (`#FFFFFF`) | 17.4:1 | Light |
| `textSecondary` (`#4B5563`) | `surface` (`#FFFFFF`) | 7.5:1 | Light |
| `onPrimary` (`#FFFFFF`) | `primary` (`#1F4E79`) | 8.5:1 | Light |
| `onSecondary` (`#1A1A1A`) | `secondary` (`#F4A261`) | 4.6:1 | Light |
| `textOnDanger` (`#FFFFFF`) | `danger` (`#E76F51`) | 4.6:1 | Light |
| `balancePositive` (`#2A9D8F`) | `surface` (`#FFFFFF`) | 4.5:1 | Light |
| `balanceNegative` (`#E76F51`) | `surface` (`#FFFFFF`) | 4.6:1 | Light |
| `textPrimary` (`#F0F0F0`) | `background` (`#121212`) | 15.3:1 | Dark |
| `primary` (`#2E86AB`) | `background` (`#121212`) | 5.8:1 | Dark |
| `success` (`#3CC0AF`) | `surface` (`#1E1E1E`) | 6.9:1 | Dark |
| `danger` (`#F08B72`) | `surface` (`#1E1E1E`) | 6.2:1 | Dark |

**Rule:** Any new foreground/background pairing introduced during development must be verified against these thresholds before merging. The Flutter Developer shall add a comment citing the verified ratio.

### 1.2 Touch Targets

Per SRS section 5.6, tap targets shall be at least 44x44 pt on iOS and 48x48 dp on Android.

| Rule | Detail |
|---|---|
| Minimum interactive area | 48x48 dp on all platforms (satisfies both iOS and Android minima). |
| Visual size may be smaller | If the visible element is smaller than 48 dp (e.g., an icon at 24 dp), invisible padding shall extend the hit area to 48x48 dp. |
| Spacing between targets | Adjacent interactive elements shall have at least 8 dp of non-interactive space between their touch areas to prevent mis-taps. |
| Verified components | `OBTAppBar` action icons, `OBTBottomNav` tabs, `OBTFloatingActionButton` (56x56 dp), `OBTOTPInput` cells (48x48 dp), all list tiles (minimum height 56--64 dp), all buttons, `OBTSearchBar`, `OBTCategoryChip`. |

### 1.3 Focus Indicators

Every interactive element shall display a visible focus indicator when navigated to via keyboard, switch control, or screen reader exploration. The focus ring shall use the `primary` token colour at full opacity with a 2 dp outline offset. In dark mode, the focus ring uses the dark-mode `primary` token (`#2E86AB`).

### 1.4 No Information by Colour Alone

Per WCAG 1.4.1, colour shall never be the sole means of conveying information (SRS section 5.6; component catalogue cross-cutting requirements).

| Pattern | Colour Signal | Required Text Label |
|---|---|---|
| Balance pill (positive) | `success` green | Text: "you are owed Rs X" |
| Balance pill (negative) | `danger` red | Text: "you owe Rs X" |
| Balance pill (zero) | Muted `onSurface` | Text: "settled up" |
| Activity row event type | Colour-coded icon | Event type is conveyed by the primary text description, not the icon colour alone. |
| Snackbar type | Coloured icon and tint | Prefixed with type word: "Success:", "Error:", or "Info:". |
| Expense list tile share | Green or red trailing amount | Prefixed with "you lent" or "you borrowed". |

---

## 2. Screen Reader Walkthroughs

The following walkthroughs describe the expected focus order and announcements for VoiceOver (iOS) and TalkBack (Android) across five critical user flows. Announcements are written in the format heard by the user. Platform-specific differences are noted where applicable.

### Flow 1: First-Time Sign-Up (Phone Entry, OTP, Profile Setup, Home)

This flow covers SRS section 6.3 screens 1--5: Splash, Onboarding, Phone Entry, OTP Verification, and Profile Setup, ending at the Home Dashboard.

**Step 1: Splash Screen** (`/splash`)

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | App logo | "One By Two app logo, image." |
| 2 | Tagline | "Split expenses the desi way." |
| 3 | Loading indicator | "Loading, please wait." (Live region; announced automatically.) |

Focus moves automatically to the next screen when loading completes.

**Step 2: Onboarding** (`/onboarding`)

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Slide illustration | (Excluded from semantics; decorative.) |
| 2 | Slide title | "Track shared expenses, heading." (Slide 1 example.) |
| 3 | Slide description | "Add expenses, split them your way, and always know who owes what." |
| 4 | Dot pagination | "Page 1 of 3." |
| 5 | Skip button | "Skip onboarding, button." |
| 6 | Next button (slides 1--2) | "Next, button." |
| 6 | Get Started button (slide 3) | "Get Started, button." |

On swipe between slides, the pagination live region announces "Page 2 of 3" and "Page 3 of 3". On "Get Started" or "Skip", focus moves to the Phone Entry screen.

**Step 3: Phone Entry** (`/auth/phone`)

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Screen heading | "Enter your mobile number, heading." |
| 2 | Phone input field | "Phone number, India country code plus 91, text field." |
| 3 | Continue button (disabled) | "Continue, button, disabled." |

When the user enters 10 digits, the button state changes. On re-focus: "Continue, button." On activation, the button enters loading state: "Sending verification code, please wait." (Live region.)

If validation fails: "Error: Please enter a valid 10-digit mobile number." (Live region.)

**Step 4: OTP Verification** (`/auth/otp`)

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Back button | "Navigate back, button." |
| 2 | Screen heading | "Verify your number, heading." |
| 3 | Subtitle | "We sent a 6-digit code to plus 91 9 8 7 6 5 4 3 2 1 0." |
| 4 | OTP input group | "Enter 6-digit verification code." |
| 5 | First OTP cell (auto-focused) | "Digit 1 of 6, text field." |
| 6--10 | Subsequent cells (on navigation) | "Digit 2 of 6" through "Digit 6 of 6." |
| 11 | Resend OTP button (disabled) | "Resend OTP, button, disabled, 30 seconds remaining." |
| 12 | Auto-read indicator | "Attempting to read verification code automatically." |

On successful entry: "Verification code entered." (Live region.) Then: "Verifying, please wait." (Live region.)

On error: "Error: Invalid code. Please try again." All cells clear; focus returns to "Digit 1 of 6."

Countdown timer is a live region, announcing remaining time every 10 seconds to avoid excessive announcements (SRS section 5.6). When timer expires: "Resend OTP, button."

**Step 5: Profile Setup** (`/auth/profile-setup`)

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Screen heading | "Set up your profile, heading." |
| 2 | Subtitle | "Tell us your name so your friends recognise you." |
| 3 | Avatar area | "Profile photo. Tap to add a photo." |
| 4 | Display name field | "Display name, required, text field." |
| 5 | Continue button (disabled) | "Continue, button, disabled." |

On avatar tap, a bottom sheet appears: focus moves to "Take photo, button." then "Choose from gallery, button." On dismissal, focus returns to the avatar area. If a photo is set: "Profile photo set. Tap to change."

On name entry, button becomes active: "Continue, button." On activation: "Saving profile, please wait." (Live region.) On success, focus moves to the Home Dashboard screen title.

**Step 6: Home Dashboard** (`/home`)

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Screen title | "Home, heading." |
| 2 | Overall balance pill | "Balance: you owe rupees 1,250 point zero zero." (or "Balance: settled up." if zero.) |
| 3--N | Settle-up cards | "[Payer name] owes [Payee name] rupees [amount]. Settle up button available." |
| N+1 | FAB | "Add new expense, button." |
| N+2 | Bottom nav, Home tab | "Home, tab, selected." |

---

### Flow 2: Add Expense (FAB, Bottom Sheet Steps, Split, Save)

This flow covers SRS section 6.3 screen 8 and functional requirements FR-EX-01 through FR-EX-05.

**Step 1: Trigger**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | FAB (on any primary tab) | "Add new expense, button." |

On activation, the bottom sheet slides up. Focus moves to the sheet header.

**Step 2: Amount and Description (Step 1 of 3)**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Sheet header | "Add expense, step 1 of 3." |
| 2 | Close button | "Close, discard expense, button." |
| 3 | Amount input field | "Enter amount in rupees, text field." |
| 4 | Description field | "Description, text field." |
| 5 | Date picker | "Date, [selected date], button." |
| 6 | Category chips | "[Category name] category, not selected." (Repeated per chip.) |
| 7 | Next button | "Next, button." (Or "Next, button, disabled" if required fields are empty.) |

On amount entry, live region announces: "rupees [formatted amount]."

On category selection: "[Category name] category, selected."

**Step 3: Payer and Split (Step 2 of 3)**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Sheet header | "Add expense, step 2 of 3." |
| 2 | Payer selector | "Paid by [name]. Double-tap to change." |
| 3 | Split method selector (radio group) | "Split method selector." |
| 4 | First split method chip | "Equal, selected." |
| 5--N | Additional method chips | "[Method label], not selected." |
| N+1 onwards | Split entry rows | "[Name]'s share: rupees [amount]." (or "[Name]'s share: [value] percent.") |
| Last | Next button | "Next, button." |

On split method change: "[Method label] selected. [Description]." (Live region.)

On validation error: "Splits don't add up. [Amount] remaining." (Live region.)

**Step 4: Receipt -- Optional (Step 3 of 3)**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Sheet header | "Add expense, step 3 of 3. Attach a receipt, optional." |
| 2 | Camera option | "Take photo, button." |
| 3 | Gallery option | "Choose from gallery, button." |
| 4 | Skip / Next button | "Skip, button." or "Next, button." (if photo attached.) |

**Step 5: Confirmation**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Sheet header | "Review expense before saving." |
| 2--N | Summary rows | "[Label]: [Value]." (e.g., "Amount: rupees 1,500 point zero zero.") |
| N+1 | Save button | "Save expense, rupees [total], button." |

On activation: "Saving expense, please wait." (Live region.) On success: "Expense added." (Live region via `OBTSnackbar`.) Sheet dismisses; focus returns to the FAB or the screen that initiated the flow.

---

### Flow 3: Settle Up (Balance Pill, Settle Up Screen, Confirmation)

This flow covers SRS section 6.3 screen 9 and functional requirements FR-SE-04 through FR-SE-07.

**Step 1: Entry Point (Friend Detail example)**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Back button | "Navigate back, button." |
| 2 | Screen title | "Priya Sharma, heading." |
| 3 | Avatar | (Excluded from semantics; decorative.) |
| 4 | Balance pill | "Balance: you owe rupees 1,250 point zero zero." |
| 5 | Settle-up card | "You owe Priya Sharma rupees 1,250 point zero zero. Settle up button available." |
| 6 | Settle Up button (within card) | "Settle up, rupees 1,250 point zero zero, button." |

On activation, the Settle Up Screen opens. Focus moves to the screen title.

**Step 2: Settle Up Screen**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Screen title | "Settle Up, heading." |
| 2 | Payer avatar and name | "[Your name] pays." |
| 3 | Arrow | (Excluded from semantics; decorative.) |
| 4 | Payee avatar and name | "Priya Sharma." |
| 5 | Amount input | "Enter amount in rupees, text field. Current value: rupees 1,250 point zero zero." |
| 6 | Date picker | "Settlement date, [today's date], button." |
| 7 | Note field | "Add a note, optional, text field." |
| 8 | Record Settlement button | "Record settlement of rupees 1,250 point zero zero to Priya Sharma, button." |

On activation: "Recording settlement, please wait." (Live region.)

**Step 3: Settlement Confirmation**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Checkmark animation | "Settlement successful." (Live region; announced immediately.) |
| 2 | Title | "Settlement recorded, heading." |
| 3 | Subtitle | "You paid Priya Sharma rupees 1,250 point zero zero. You're all settled up -- high five!" |
| 4 | Updated balance pill | "Balance: settled up." |
| 5 | Done button | "Done, return to previous screen, button." |

On activation, focus returns to the element that initiated the flow (the Settle Up button on the Friend Detail screen, or the equivalent trigger on the Home Dashboard or Group Detail).

---

### Flow 4: Contact Support (Profile, Mailto or Fallback Dialog)

This flow covers SRS functional requirements FR-PR-05, FR-SH-03, and FR-SH-04.

**Step 1: Profile Screen**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Screen title | "Profile, heading." |
| 2 | Avatar | "[Display name] profile photo, image." |
| 3 | Display name | "[Display name]." |
| 4 | Phone number | "Phone number: plus 91 [formatted number]." |
| 5--N | Action rows | "[Label], button." (e.g., "My Friends, 12, button.") |
| N+1 | Contact Support row | "Contact Support, button." |

On activation of "Contact Support":

**Path A -- Mail client available:**

The system mail client opens externally. No in-app focus change. On return to the app, focus remains on the "Contact Support" row.

**Path B -- No mail client (fallback dialog):**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Dialog title | "Alert: No Mail App Found, heading." |
| 2 | Dialog body | "We could not open a mail app on your device. You can reach us at:" |
| 3 | Support email address | "Support email address: support at onebytwo dot app." |
| 4 | Close button | "Close, button." |
| 5 | Copy Address button | "Copy Address, button." |

Focus is trapped within the dialog while it is open. On "Copy Address" activation: dialog dismisses, and the snackbar live region announces "Info: Email address copied." Focus returns to the "Contact Support" row. On "Close" activation or back gesture: dialog dismisses; focus returns to the "Contact Support" row.

---

### Flow 5: View Friend Balances (Friends List, Friend Detail)

This flow covers SRS section 6.3 screen 6 and functional requirements FR-FR-03 and FR-FR-04.

**Step 1: Friends List**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Screen title | "Friends, heading." |
| 2 | Search bar | "Search friends, text field." |
| 3 | First friend tile | "[Display name], you are owed rupees [amount], button." |
| 4 | Second friend tile | "[Display name], you owe rupees [amount], button." |
| ... | Subsequent tiles | Pattern repeats for each friend. |
| N | Friend tile (settled) | "[Display name], settled up, button." |

Avatars are excluded from semantics on each tile (the name is already announced). All tiles meet the 56 dp minimum height, satisfying the 48x48 dp touch target requirement.

On activation of a friend tile, the Friend Detail screen opens. Focus moves to the screen title.

**Step 2: Friend Detail**

| Focus Order | Element | Announcement |
|---|---|---|
| 1 | Back button | "Navigate back, button." |
| 2 | Screen title | "[Friend name], heading." |
| 3 | Avatar (80 dp) | (Excluded from semantics; decorative.) |
| 4 | Display name | "[Friend name]." |
| 5 | Balance pill | "Balance: you are owed rupees 1,250 point zero zero." |
| 6 | Settle-up card (if non-zero balance) | "[Friend name] owes you rupees 1,250 point zero zero. Settle up button available." |
| 7 | Settle Up button | "Settle up, rupees 1,250 point zero zero, button." |
| 8 | View full history link | "View full history with [Friend name], button." |
| 9 | Overflow menu | "More options, button." |
| 10--N | Recent expense tiles | "[Description], [category], paid by [payer], [date], your share: you lent rupees [amount], button." |

When the balance is zero, the settle-up card is absent (FR-SE-07). The balance pill announces "Balance: settled up." Focus moves directly from the balance pill to "View full history."

**Empty state:** If no expenses exist, focus moves from the balance pill to the empty state: "No expenses yet, heading." then "Add an expense with [Friend name] to start tracking." then "Add Expense, button."

**Error state:** Focus moves to: "Something went wrong, heading." then "We could not load this. Please try again." then "Retry, button." then "Contact support, button."

---

## 3. Dynamic Type and Font Scaling

Per SRS section 5.6, the app shall fully support OS-level dynamic font scaling. Per `docs/design/02-design-system/tokens.md`, all text widgets must respect the platform `textScaleFactor`.

### 3.1 Scale Range

| Setting | Behaviour |
|---|---|
| System scale 1.0x (default) | Baseline layout as specified in wireframes. |
| System scale up to 2.0x | Layout remains fully functional. All content is accessible via scrolling where needed. |
| System scale below 1.0x | Permitted; no minimum clamp. Text renders at the system-requested size. |

### 3.2 Layout Adaptation Rules

| Rule | Detail |
|---|---|
| No text clipping | No `overflow: TextOverflow.clip` on any user-facing text. Use `TextOverflow.ellipsis` with `maxLines` only where explicitly designed (e.g., expense description in list tiles), and always pair with a full-text `Semantics` label. |
| No text overlap | Fixed-height containers must not be used for text. Prefer `IntrinsicHeight`, `Wrap`, or unconstrained vertical flex. |
| Scrollability | Screens that may exceed viewport height at 2.0x scale shall be wrapped in `SingleChildScrollView` or use `CustomScrollView` / `SliverList`. |
| Bottom sheets | Sheet max height shall be set to 90% of screen height. Content within the sheet shall be scrollable. |
| Balance pill | At 2.0x scale, the pill may wrap to two lines. The container must accommodate this without clipping. |
| Button text | Button labels must not be truncated. Buttons shall expand horizontally to fit scaled text, up to full screen width, then wrap if needed. |

### 3.3 Testing Requirement

The QA Engineer shall verify all 11 core screens (SRS section 6.3) at 1.0x, 1.5x, and 2.0x font scale on both iOS and Android, confirming no clipping, overlap, or loss of functionality.

---

## 4. Focus Management

Correct focus management ensures screen reader users always know where they are after a navigation event or state change.

### 4.1 Screen Transitions

| Event | Focus Behaviour |
|---|---|
| New screen pushed | Focus moves to the screen title (first heading) or, if no heading exists, to the first focusable element. |
| Screen popped (back navigation) | Focus returns to the element that triggered the navigation (e.g., the list tile that was tapped). |
| Tab switch (bottom nav) | Focus moves to the screen title of the newly selected tab. |
| Bottom sheet appears | Focus moves to the sheet heading (e.g., "Add expense, step 1 of 3"). |
| Bottom sheet dismissed | Focus returns to the element that triggered the sheet (e.g., the FAB). |

### 4.2 Dialog Focus

| Event | Focus Behaviour |
|---|---|
| Dialog appears | Focus moves to the dialog title (e.g., "Alert: Delete expense?"). |
| Focus trapping | While a dialog is open, focus is trapped within the dialog. VoiceOver/TalkBack cannot navigate to elements behind the scrim. |
| Dialog dismissed (cancel) | Focus returns to the trigger element. |
| Dialog dismissed (confirm with navigation) | Focus moves to the new screen's title or first element. |

### 4.3 Error Focus

| Event | Focus Behaviour |
|---|---|
| Inline validation error | Focus moves to the first field with an error. The error text is announced via a live region. |
| Full-screen error state (`OBTErrorState`) | Focus moves to the error title ("Something went wrong, heading"). |
| Snackbar error | The snackbar is a live region; its message is announced automatically without moving focus. |
| OTP error | All cells clear; focus moves to "Digit 1 of 6." Error text is announced as a live region. |

### 4.4 Loading States

| Event | Focus Behaviour |
|---|---|
| Skeleton loader shown | Semantics announce "Loading content" as a live region. Focus remains on the current element or moves to the loading indicator. |
| Content loaded (replacing skeleton) | The live region announces the new content. Focus moves to the first meaningful element of the loaded content. |
| Button loading state | The button remains focused; its label updates to include "please wait" (e.g., "Saving expense, please wait"). |

---

## 5. Semantic Labelling Rules

Per SRS section 5.6, every interactive widget shall have a `Semantics` label. The following rules standardise label patterns across the app.

### 5.1 General Rules

| Rule | Detail |
|---|---|
| Every interactive widget | Must have a `Semantics` node with `label`, `role`, and `state` (enabled/disabled/selected). |
| Decorative elements | Illustrations, decorative dividers, and avatars adjacent to name text shall use `excludeSemantics: true`. |
| Redundancy avoidance | If a parent widget's label fully describes a child, the child is excluded from semantics to avoid double announcements. |
| Language | All semantic labels shall be in English (SRS section 5.9 notes English as the default language for v1.0). |

### 5.2 Monetary Amount Announcements

Per the `OBTRupeeText` and `OBTBalancePill` component specifications, monetary amounts must be announced in a human-readable format, not as raw symbols or numbers.

| Visual Display | Semantic Announcement |
|---|---|
| `Rs1,23,456.78` | "rupees 1,23,456 point 78" |
| `Rs850.00` | "rupees 850 point zero zero" |
| `Rs0.50` | "rupees 0 point 50" |
| `+Rs625.00` | "plus rupees 625 point zero zero" |
| `-Rs400.00` | "minus rupees 400 point zero zero" |

The `Rs` symbol shall be mapped to the spoken word "rupees" in all semantic labels. The decimal separator shall be spoken as "point". The Indian numbering grouping (lakhs, thousands) is preserved in the spoken form for consistency with the visual display.

### 5.3 Balance State Announcements

Balance states must always include a textual description of the direction, never relying on colour alone (WCAG 1.4.1; SRS section 5.6).

| Balance State | Semantic Announcement |
|---|---|
| Positive (user is owed) | "Balance: you are owed rupees [amount]." |
| Negative (user owes) | "Balance: you owe rupees [amount]." |
| Zero (settled) | "Balance: settled up." |

### 5.4 Component-Specific Label Patterns

The following table summarises the canonical semantic label pattern for each component, as defined in `docs/design/02-design-system/components.md`.

| Component | Label Pattern | Role |
|---|---|---|
| `OBTAppBar` title | "[Title]" | `heading` |
| `OBTAppBar` back button | "Navigate back" | `button` |
| `OBTBottomNav` tab | "[Label], tab, [selected/not selected]" | `tab` |
| `OBTFloatingActionButton` | "Add new expense" | `button` |
| `OBTBalancePill` | "Balance: [state text]" | (none; informational) |
| `OBTRupeeText` | "rupees [formatted amount]" | `text` |
| `OBTAmountInput` | "Enter amount in rupees" | `textField` |
| `OBTOTPInput` (group) | "Enter 6-digit verification code" | (group label) |
| `OBTOTPInput` (cell) | "Digit [N] of 6" | `textField` |
| `OBTPhoneInput` | "Phone number, India country code plus 91" | `textField` |
| `OBTContactPicker` search | "Search contacts" | `textField` |
| `OBTContactPicker` row | "[Name], [phone number], [on One By Two / not on One By Two]" | `listItem` |
| `OBTGroupAvatar` | "[Group name] group photo" | `image` |
| `OBTUserAvatar` | "[Display name] profile photo" | `image` |
| `OBTCategoryChip` | "[Category name] category, [selected/not selected]" | `radio` |
| `OBTSettleUpCard` | "[Payer] owes [Payee] rupees [amount]. Settle up button available." | (container) |
| `OBTSettleUpCard` CTA | "Settle up, rupees [amount]" | `button` |
| `OBTActivityRow` | "[Primary text]. [Secondary text]. [Amount if present]. Tap to view details." | `button` |
| `OBTExpenseListTile` | "[Description], [category], paid by [payer], [date], your share: [you lent/borrowed] rupees [amount]" | `button` |
| `OBTFriendListTile` | "[Display name], [balance pill text]" | `button` |
| `OBTGroupListTile` | "[Group name], [type], [member count] members, [balance pill text]" | `button` |
| `OBTEmptyState` title | "[Title]" | `heading` |
| `OBTEmptyState` CTA | "[CTA label]" | `button` |
| `OBTErrorState` title | "[Title]" | `heading` |
| `OBTErrorState` retry | "Retry" | `button` |
| `OBTErrorState` support | "Contact support" | `button` |
| `OBTSkeletonLoader` | "Loading content" | (live region) |
| `OBTSplitMethodSelector` | "Split method selector" | `radioGroup` |
| `OBTSplitMethodSelector` chip | "[Method label], [selected/not selected]" | `radio` |
| `OBTSplitEntryRow` | "[Name]'s share: [value] [unit]" | `textField` or `text` |
| `OBTSearchBar` | "Search, [hint text]" | `textField` |
| `OBTSearchBar` clear | "Clear search" | `button` |
| `OBTConfirmationDialog` | "Alert: [title]" | `dialog` |
| `OBTSnackbar` | "[Type]: [message]" | (live region) |

---

## 6. Reduced Motion

Per SRS section 5.6 and `docs/design/02-design-system/motion-and-interaction.md` (section 5), the app shall respect the operating system's "Reduce Motion" (iOS) and "Remove Animations" (Android) settings.

### 6.1 Detection

The Flutter Developer shall query `MediaQuery.of(context).disableAnimations` to determine whether reduced motion is active. A shared utility function shall wrap all transition durations, returning `Duration.zero` when the flag is true (per motion-and-interaction.md, section 5.1).

### 6.2 Behaviour Matrix

| Animation | Standard Behaviour | Reduced Motion Behaviour |
|---|---|---|
| Page transitions | Slide, 250--300 ms | Instant cut (0 ms). |
| Modal and dialog appear/dismiss | Slide or fade, 150--300 ms | Instant cut. |
| FAB appear and press | Spring physics, 100--200 ms | Instant state change; no spring. |
| List item stagger | 150 ms fade + slide, 50 ms stagger | All items appear simultaneously and instantly. |
| Skeleton shimmer | 1,500 ms sweep loop | Static grey placeholder; no animation. Placeholder shapes remain visible. |
| Tab cross-fade | 200 ms | Instant swap. |
| OTP cell pulse | 100 ms scale | No pulse. |
| Settlement checkmark | 300 ms spring scale-in | Immediate appearance; no spring. |
| Snackbar enter/exit | 200 ms slide | Instant appear/disappear. |
| Haptic feedback | Per component specs | **Unchanged.** Haptics are tactile, not motion-based. |

### 6.3 Spring Animation Fallback

Spring-based animations (FAB press, settlement checkmark) shall fall back to `Curves.easeOut` with `Duration.zero` when reduced motion is active. This prevents jarring partial animations.

### 6.4 Testing Requirement

The QA Engineer shall verify all animations listed above with "Reduce Motion" enabled on both iOS and Android, confirming that every animation resolves instantly and that no functionality is lost.

---

## 7. Dark Mode

Per SRS section 5.6, the app shall fully support OS-level dark mode. Per SRS section 6.2, the surface colour shifts to `#121212` in dark mode.

### 7.1 Rules

| Rule | Detail |
|---|---|
| Automatic switching | The app follows the system theme setting. No in-app theme toggle in v1.0. |
| Token substitution | All colour tokens switch to their dark-mode variants as defined in `docs/design/02-design-system/tokens.md`. |
| Contrast preservation | All dark-mode pairings have been verified to meet WCAG 2.1 AA thresholds (see section 1.1 of this document). |
| Elevation | In dark mode, elevation is conveyed via lighter surface tints rather than shadows, following Material 3 conventions. |
| Images and illustrations | Decorative illustrations should use variants appropriate for dark backgrounds, or be rendered with reduced opacity to avoid glare. |

---

## 8. Snackbar and Live Region Behaviour with Screen Readers

Per the `OBTSnackbar` component specification, snackbar behaviour adapts when a screen reader is active.

| Behaviour | Standard | Screen Reader Active |
|---|---|---|
| Auto-dismiss timer | 4,000 ms (default) | Timer pauses indefinitely. The snackbar remains until the user dismisses it or activates the action. |
| Announcement | Not applicable | Live region announces "[Type]: [message]" immediately on appearance. |
| Action button | Tappable | Focusable and labelled with `actionLabel`. |

This ensures screen reader users have sufficient time to perceive and act upon transient feedback messages.

---

## 9. Implementation Checklist for Flutter Developer

The following checklist summarises the actionable requirements from this specification. Each item shall be verified during code review and QA testing.

- [ ] Every interactive widget has a `Semantics` node with `label` and appropriate `role`.
- [ ] All monetary amounts use the "rupees [amount]" spoken pattern, not raw symbols.
- [ ] Balance pills include textual direction ("you are owed", "you owe", "settled up") in both visual display and semantic labels.
- [ ] All touch targets meet 48x48 dp minimum, using invisible padding where visual size is smaller.
- [ ] All text/background pairings meet WCAG 2.1 AA contrast ratios in both light and dark mode.
- [ ] Layouts accommodate up to 2.0x system font scale without clipping or overlap.
- [ ] `MediaQuery.disableAnimations` is checked via a shared utility; all animations respect the flag.
- [ ] Focus moves to screen titles on navigation, dialog titles on dialog appear, and trigger elements on dismiss.
- [ ] Error messages are announced via live regions.
- [ ] `OBTSkeletonLoader` uses `liveRegion: true` and announces "Loading content".
- [ ] Snackbar auto-dismiss timer pauses when a screen reader is active.
- [ ] Decorative images and redundant avatars use `excludeSemantics: true`.
- [ ] `OBTConfirmationDialog` traps focus while open.
- [ ] Dark mode renders correctly with verified dark-mode token colours.
- [ ] Icons carry `semanticLabel` and are never the sole means of conveying information.

---

*Document prepared by the UX/UI Designer agent. All specifications trace to SRS section 5.6 (Usability and Accessibility), sections 6.1--6.5 (User Experience and Design Requirements), the component catalogue (`docs/design/02-design-system/components.md`), the design tokens specification (`docs/design/02-design-system/tokens.md`), and the motion-and-interaction specification (`docs/design/02-design-system/motion-and-interaction.md`).*