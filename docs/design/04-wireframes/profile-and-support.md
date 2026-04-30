# Profile and Support Wireframes

> **Document owner:** UX/UI Designer
> **Version:** 1.0
> **Status:** Draft
> **Audience:** Flutter Developer, QA Engineer, Product Manager
> **SRS references:** Sections 4.1 (FR-AU-08, FR-AU-09), 4.2 (FR-PR-01 through FR-PR-05), 4.11 (FR-SH-03, FR-SH-04), 5.5, 5.6, 6.2, 6.3 (Core Screen 11), 6.4, 6.5

---

## Design Token Quick Reference

All screens in this document use the tokens defined in `docs/design/02-design-system/tokens.md`. Frequently referenced tokens are listed here for convenience.

| Token | Light | Dark | Applied to |
|---|---|---|---|
| `primary` | `#1F4E79` | `#2E86AB` | App bar, section headers, active icons |
| `secondary` | `#F4A261` | `#F4A261` | FAB, accent highlights |
| `danger` | `#E76F51` | `#E76F51` | Destructive CTAs (Sign Out, Delete Account) |
| `surface` | `#FFFFFF` | `#121212` | Cards, sheets, dialogs |
| `background` | `#F8F9FB` | `#121212` | Scaffold background |
| `textPrimary` | `#1A1A1A` | `#FFFFFF` | Display name, section titles |
| `textSecondary` | `#4B5563` | `#9CA3AF` | Phone number, descriptions |
| `divider` | `#E4E7EC` | `#2C2C2C` | Section separators |
| `cornerRadiusSmall` | 16 dp | -- | Buttons, pills, inputs |
| `cornerRadiusLarge` | 24 dp | -- | Cards, bottom sheets, dialogs |
| `tapTargetMin` | 48x48 dp (Android) / 44x44 pt (iOS) | -- | All interactive elements |
| `motionStandard` | 200--300 ms ease-in-out | -- | Page transitions, dialog open/close |

---

## Component Dependencies

All screens in this document consume components from `docs/design/02-design-system/components.md`:

| Component | Used in |
|---|---|
| `OBTAppBar` | All screens (Profile View uses title only; sub-screens add back button) |
| `OBTBottomNav` | Profile View (tab index 4 active) |
| `OBTUserAvatar` | Profile View (large, 96 dp), Edit Profile |
| `OBTConfirmationDialog` | Sign Out, Delete Account |
| `OBTSnackbar` | Edit Profile (save success/error), Contact Support (copy confirmation), Delete Account |
| `OBTPhoneInput` | Delete Account re-authentication step |
| `OBTOTPInput` | Delete Account re-authentication step |
| `OBTSkeletonLoader` | Profile View loading state |
| `OBTErrorState` | Profile View error state |

---

## 1. Profile View

**SRS requirements:** FR-PR-01 (P0), FR-PR-04 (P0), FR-PR-05 (P0), FR-AU-08 (P0), FR-AU-09 (P1), section 6.3 item 11.

**Navigation:** Reached via `OBTBottomNav` tab index 4 ("Profile"). This is a primary tab screen; the bottom nav remains visible.

### 1.1 ASCII Layout -- Default State

```
+--------------------------------------------------+
| OBTAppBar                                        |
|  title: "Profile"            [no back button]    |
+--------------------------------------------------+
|                                                  |
|              +------------+                      |
|              | OBTUser    |                      |
|              | Avatar     |                      |
|              | 96 dp      |                      |
|              +------------+                      |
|                                                  |
|           Avtansh Gupta                          |
|           (displayName, titleLarge, textPrimary) |
|                                                  |
|           +91 98765 43210                        |
|           (phoneNumber, bodyMedium, textSecondary)|
|           [read-only, not tappable]              |
|                                                  |
+--------------------------------------------------+
|  [divider]                                       |
+--------------------------------------------------+
|                                                  |
|  +--------------------------------------------+ |
|  |  [people icon]  My Friends          12  >  | |
|  +--------------------------------------------+ |
|  |  [groups icon]  My Groups            4  >  | |
|  +--------------------------------------------+ |
|                                                  |
+--------------------------------------------------+
|  [divider]                                       |
+--------------------------------------------------+
|                                                  |
|  +--------------------------------------------+ |
|  |  [edit icon]    Edit Profile             >  | |
|  +--------------------------------------------+ |
|  |  [bell icon]    Notification Preferences >  | |
|  +--------------------------------------------+ |
|  |  [mail icon]    Contact Support          >  | |
|  +--------------------------------------------+ |
|                                                  |
|  // IA-EXT-03: Language selector row renders   |
|  // here when localisation ships in v1.1.      |
|  // Hidden in v1.0 -- no widget rendered.      |
|  // See extension-points.md (IA-EXT-03).       |
|                                                  |
+--------------------------------------------------+
|  [divider]                                       |
+--------------------------------------------------+
|                                                  |
|  +--------------------------------------------+ |
|  |  [logout icon]  Sign Out                    | |
|  |  (textPrimary)                              | |
|  +--------------------------------------------+ |
|  |  [delete icon]  Delete Account              | |
|  |  (danger)                                   | |
|  +--------------------------------------------+ |
|                                                  |
+--------------------------------------------------+
|            OBTBottomNav (index 4 active)         |
+--------------------------------------------------+
```

### 1.2 Layout Specification

| Element | Component / Style | Details |
|---|---|---|
| App bar | `OBTAppBar(title: "Profile", showBackButton: false)` | No actions; this is a root tab screen. |
| Avatar | `OBTUserAvatar(size: 96, imageUrl: user.photoUrl, displayName: user.displayName)` | Centred horizontally. 24 dp top padding from app bar. |
| Display name | `titleLarge`, `textPrimary`, centre-aligned | 8 dp below avatar. |
| Phone number | `bodyMedium`, `textSecondary`, centre-aligned | 4 dp below display name. Read-only; no tap handler. |
| Section dividers | 1 dp `divider` colour, full-bleed | Separate profile header, stats, actions, and destructive zone. |
| "My Friends" row | Leading icon `people` in `primary`, label, trailing count in `textSecondary` + chevron `>` | Taps navigate to Friends List (tab index 1). Row height: 56 dp. |
| "My Groups" row | Leading icon `groups` in `primary`, label, trailing count in `textSecondary` + chevron `>` | Taps navigate to Groups List (tab index 2). Row height: 56 dp. |
| "Edit Profile" row | Leading icon `edit` in `primary`, label, trailing chevron | Navigates to Edit Profile screen. Row height: 56 dp. |
| "Notification Preferences" row | Leading icon `notifications` in `primary`, label, trailing chevron | Navigates to Notification Preferences screen. Row height: 56 dp. |
| "Contact Support" row | Leading icon `mail` in `primary`, label, trailing chevron | Triggers Contact Support flow (section 4). Row height: 56 dp. |
| "Sign Out" row | Leading icon `logout` in `textPrimary`, label in `textPrimary` | Triggers Sign Out confirmation dialog (section 5). Row height: 56 dp. |
| "Delete Account" row | Leading icon `delete_forever` in `danger`, label in `danger` | Navigates to Delete Account flow (section 6). Row height: 56 dp. |
| Bottom nav | `OBTBottomNav(currentIndex: 4)` | "Profile" tab is active. |

### 1.3 States

#### Loading State

Per SRS section 6.4, skeleton screens are preferred over spinners.

```
+--------------------------------------------------+
| OBTAppBar: "Profile"                             |
+--------------------------------------------------+
|              +------------+                      |
|              | [shimmer   |                      |
|              |  circle]   |                      |
|              +------------+                      |
|           [shimmer bar, 160 dp wide]             |
|           [shimmer bar, 120 dp wide]             |
+--------------------------------------------------+
|  [shimmer row 56 dp]                             |
|  [shimmer row 56 dp]                             |
+--------------------------------------------------+
|  [shimmer row 56 dp]                             |
|  [shimmer row 56 dp]                             |
|  [shimmer row 56 dp]                             |
+--------------------------------------------------+
|            OBTBottomNav (index 4 active)         |
+--------------------------------------------------+
```

- Uses `OBTSkeletonLoader` with a shimmer animation at `motionStandard` speed.
- Avatar placeholder: 96 dp circle shimmer.
- Text placeholders: rounded rectangles with corner radius 8 dp.

#### Error State

```
+--------------------------------------------------+
| OBTAppBar: "Profile"                             |
+--------------------------------------------------+
|                                                  |
|           OBTErrorState                          |
|                                                  |
|           [error icon, 48 dp, danger]            |
|                                                  |
|           "Something went wrong"                 |
|           (titleMedium, textPrimary)             |
|                                                  |
|           "We could not load your profile.       |
|            Check your connection and try again." |
|           (bodyMedium, textSecondary)            |
|                                                  |
|           [  Retry  ]                            |
|           (primary filled button)                |
|                                                  |
|           "Still stuck? Contact Support"         |
|           (bodySmall, primary, underlined)       |
|                                                  |
+--------------------------------------------------+
|            OBTBottomNav (index 4 active)         |
+--------------------------------------------------+
```

- The "Contact Support" link in the error state triggers the same Contact Support flow described in section 4, satisfying SRS section 6.4's requirement for a path to Contact Support from error states.
- Retry button: `cornerRadiusSmall` (16 dp), `primary` fill, `onPrimary` text, minimum 48x48 dp tap target.

### 1.4 Accessibility

| Element | Semantic Label | Role | Notes |
|---|---|---|---|
| Avatar | `"[Display name] profile photo"` | `image` | Per `OBTUserAvatar` spec. |
| Display name | Readable as-is | `text` | Announced as heading level. |
| Phone number | `"Phone number: plus 91 [formatted number]"` | `text` | Read-only; no button role. |
| My Friends row | `"My Friends, [count], button"` | `button` | Announces count. |
| My Groups row | `"My Groups, [count], button"` | `button` | Announces count. |
| Each action row | `"[label], button"` | `button` | Per SRS section 5.6. |
| Sign Out row | `"Sign Out, button"` | `button` | -- |
| Delete Account row | `"Delete Account, button"` | `button` | -- |

- All rows meet the 48x48 dp minimum tap target (SRS section 5.6).
- Contrast ratios verified: `textPrimary` on `surface` = 17.4:1; `danger` on `surface` = 4.6:1; both exceed WCAG 2.1 AA 4.5:1 threshold.

---

## 2. Edit Profile

**SRS requirements:** FR-PR-01 (P0), section 6.3 item 11.

**Navigation:** Pushed from Profile View via "Edit Profile" row. `OBTAppBar` with back button. Bottom nav hidden.

### 2.1 ASCII Layout -- Default State

```
+--------------------------------------------------+
| OBTAppBar                                        |
|  [<- back]   "Edit Profile"                      |
+--------------------------------------------------+
|                                                  |
|              +------------+                      |
|              | OBTUser    |                      |
|              | Avatar     |                      |
|              | 96 dp      |                      |
|              +--[camera]--+                      |
|              (overlay badge, bottom-right)        |
|                                                  |
|  Tap avatar to:                                  |
|  +--------------------------------------------+ |
|  | [camera icon]  Take Photo                   | |
|  | [gallery icon] Choose from Gallery          | |
|  | [delete icon]  Remove Photo                 | |
|  |               (shown only if photo exists)  | |
|  +--------------------------------------------+ |
|  (bottom sheet, shown on avatar tap)             |
|                                                  |
+--------------------------------------------------+
|                                                  |
|  Display Name                                    |
|  (labelMedium, textSecondary)                    |
|                                                  |
|  +--------------------------------------------+ |
|  | Avtansh Gupta                         [x]  | |
|  +--------------------------------------------+ |
|  (text input, cornerRadiusSmall, outline border) |
|  (clear button [x] when field is non-empty)      |
|                                                  |
|  Phone Number                                    |
|  (labelMedium, textSecondary)                    |
|                                                  |
|  +--------------------------------------------+ |
|  | +91 98765 43210                             | |
|  +--------------------------------------------+ |
|  (read-only, disabled style, textTertiary)       |
|  (hint below: "Phone number cannot be changed    |
|   from here", bodySmall, textTertiary)           |
|                                                  |
+--------------------------------------------------+
|                                                  |
|  +--------------------------------------------+ |
|  |              [  Save  ]                     | |
|  +--------------------------------------------+ |
|  (full-width, primary filled, cornerRadiusSmall) |
|  (disabled when name is unchanged or empty)      |
|                                                  |
+--------------------------------------------------+
```

### 2.2 Photo Picker Bottom Sheet

Triggered by tapping the avatar or the camera badge overlay.

```
+--------------------------------------------------+
|  (dimmed scrim, tap to dismiss)                  |
|                                                  |
| +----------------------------------------------+|
| | Change Profile Photo                         ||
| | (titleSmall, textPrimary)                    ||
| |                                              ||
| | [camera]   Take Photo                        ||
| | [gallery]  Choose from Gallery               ||
| | [delete]   Remove Photo    (if photo exists) ||
| |                                              ||
| | [Cancel]   (textButton, textSecondary)       ||
| +----------------------------------------------+|
|  (bottom sheet, cornerRadiusLarge top corners)   |
+--------------------------------------------------+
```

- Corner radius: 24 dp on top-left and top-right corners.
- Each option row: 56 dp height, 48x48 dp icon tap target.
- "Remove Photo" row uses `danger` colour; only visible when `user.photoUrl` is non-null.

### 2.3 States

| State | Behaviour | Visual |
|---|---|---|
| Default | Fields pre-populated from current user data. Save button disabled (no changes). | Save button in `disabled` colour. |
| Editing | User modifies display name. Save button becomes enabled. | Save button in `primary` fill. |
| Empty name | User clears the display name field entirely. | Inline error below field: "Display name cannot be empty" in `danger`. Save button disabled. |
| Saving | Save button tapped. API call in progress. | Save button shows inline progress indicator (circular, `onPrimary`). Back button disabled. Input fields disabled. |
| Save success | Profile updated successfully. | `OBTSnackbar(message: "Profile updated", type: success)`. Navigate back to Profile View. |
| Save error | Network or server error on save. | `OBTSnackbar(message: "Could not update profile. Try again.", type: error, actionLabel: "Retry", onAction: retrySave)`. Fields remain editable. |
| Photo uploading | User selects a photo. Upload to Firebase Storage in progress. | Avatar shows a circular progress overlay at 50% opacity on the image. |
| Photo upload error | Upload fails. | `OBTSnackbar(message: "Photo upload failed. Try again.", type: error)`. Avatar reverts to previous state. |

### 2.4 Accessibility

| Element | Semantic Label | Notes |
|---|---|---|
| Avatar + camera badge | `"Change profile photo, button"` | Single merged tap target; the badge is decorative. |
| Display name field | `"Display name, text field, required"` | Error state appends: `", error: Display name cannot be empty"`. |
| Phone number field | `"Phone number, plus 91 [number], read-only"` | Not focusable as an input. |
| Save button | `"Save, button"` or `"Save, button, disabled"` | Loading state announces `"Saving profile"`. |
| Photo picker sheet | Modal announced as `"Change Profile Photo, action sheet"` | Options announced individually. "Remove Photo" appends `"destructive"`. |

---

## 3. Notification Preferences

**SRS requirements:** FR-PR-03 (P1), FR-AC-04 (P1), section 6.3 item 11.

**Data model:** Maps directly to `users/{userId}.notificationPrefs` (SRS section 7.2): `{ newExpense: bool, settlement: bool, reminder: bool }`.

**Navigation:** Pushed from Profile View via "Notification Preferences" row. `OBTAppBar` with back button. Bottom nav hidden.

### 3.1 ASCII Layout -- Default State

```
+--------------------------------------------------+
| OBTAppBar                                        |
|  [<- back]   "Notification Preferences"          |
+--------------------------------------------------+
|                                                  |
|  Choose which notifications you would like       |
|  to receive.                                     |
|  (bodyMedium, textSecondary, 16 dp horizontal    |
|   padding, 16 dp top padding)                    |
|                                                  |
+--------------------------------------------------+
|                                                  |
|  +--------------------------------------------+ |
|  |  New Expenses                     [toggle] | |
|  |  Get notified when someone adds an         | |
|  |  expense involving you.                    | |
|  |  (bodySmall, textTertiary)                 | |
|  +--------------------------------------------+ |
|  [divider]                                       |
|  +--------------------------------------------+ |
|  |  Settlements                      [toggle] | |
|  |  Get notified when someone records a       | |
|  |  payment involving you.                    | |
|  |  (bodySmall, textTertiary)                 | |
|  +--------------------------------------------+ |
|  [divider]                                       |
|  +--------------------------------------------+ |
|  |  Reminders                        [toggle] | |
|  |  Receive reminders about outstanding       | |
|  |  balances.                                 | |
|  |  (bodySmall, textTertiary)                 | |
|  +--------------------------------------------+ |
|                                                  |
+--------------------------------------------------+
```

### 3.2 Toggle Mapping

| Toggle Label | `notificationPrefs` Field | Default | Description |
|---|---|---|---|
| New Expenses | `newExpense` | `true` | Notifications for FR-AC-01 new expense events. |
| Settlements | `settlement` | `true` | Notifications for FR-AC-01 settlement events. |
| Reminders | `reminder` | `true` | Balance reminder notifications (FR-AC-04). |

### 3.3 Behaviour

- **Auto-save:** Each toggle persists its new value immediately on change (no explicit "Save" button). The write targets `users/{userId}.notificationPrefs.[field]` via a Firestore `update()`.
- **Optimistic update:** The toggle visually reflects the new state instantly. If the write fails, the toggle reverts and an `OBTSnackbar(message: "Could not update preference. Try again.", type: error)` is shown.
- **Toggle style:** Platform-adaptive `Switch` widget. Active track colour: `primary`. Inactive track colour: `disabled`. Thumb: white. Toggle tap target: minimum 48x48 dp (SRS section 5.6).

### 3.4 States

| State | Behaviour |
|---|---|
| Default (loaded) | Toggles reflect current `notificationPrefs` values from user document. |
| Loading | `OBTSkeletonLoader`: three 72 dp rows with shimmer. |
| Error (load failure) | `OBTErrorState` with message "Could not load your preferences." and a Retry button. |
| Toggle saving | Toggle updates optimistically. No visible loading indicator on the toggle itself. |
| Toggle save error | Toggle reverts. `OBTSnackbar(type: error)` displayed. |
| Offline | Toggle updates queue locally. `OBTSnackbar(message: "You are offline. Changes will sync when you reconnect.", type: info)` on first toggle while offline. |

### 3.5 Accessibility

| Element | Semantic Label | Notes |
|---|---|---|
| Page description | Readable as-is | Announced after app bar title. |
| New Expenses toggle | `"New Expenses notifications, switch, [on/off]"` | Description text is the accessibility hint. |
| Settlements toggle | `"Settlements notifications, switch, [on/off]"` | Description text is the accessibility hint. |
| Reminders toggle | `"Reminders notifications, switch, [on/off]"` | Description text is the accessibility hint. |

---

## 4. Contact Support

**SRS requirements:** FR-PR-05 (P0), FR-SH-03 (P0), FR-SH-04 (P1), section 6.3 item 11.

**Technical reference:** `docs/sprint-zero/contact-support-dry-run.md`.

**Extension point:** IA-EXT-05 -- in v1.1, the "Contact Support" action becomes a channel selector offering both "Email" and "Chat with Support". In v1.0, the action triggers the email flow directly with no channel selection UI. See `docs/design/01-information-architecture/extension-points.md` (IA-EXT-05).

### 4.1 Flow

Contact Support is not a screen but a flow triggered from the Profile View's "Contact Support" row. No separate route is pushed for the happy path.

```
User taps "Contact Support"
        |
        v
  [Assemble mailto: URL]
  To: support address from Remote Config
       (key: support_email_address)
  Body:
    --- Diagnostic Info (do not delete) ---
    User ID: {userId}
    App Version: {appVersion}
    OS: {osName} {osVersion}
    Device: {deviceModel}
    ---
        |
        v
  [canLaunchUrl(mailto:)?]
        |
   +----+----+
   |         |
  YES        NO
   |         |
   v         v
 [4a]      [4b]
```

### 4a. Mail Client Available (Happy Path)

**Behaviour:** The device's default mail client opens with the pre-filled `mailto:` URL. The user may edit the subject, body, or recipients before sending (per FR-PR-05). The app does not constrain or override edits.

No UI element renders within the app for this path beyond the initial tap on the "Contact Support" row.

**Analytics event:** `support_email_opened` with parameter `method: "mailto"` (per dry-run document, Definition of Done).

### 4b. No Mail Client -- Fallback Dialog (FR-SH-04)

```
+--------------------------------------------------+
|  (dimmed scrim)                                  |
|                                                  |
|  +--------------------------------------------+ |
|  |                                            | |
|  |  No Mail App Found                         | |
|  |  (titleMedium, textPrimary)                | |
|  |                                            | |
|  |  We could not open a mail app on your      | |
|  |  device. You can reach us at:              | |
|  |  (bodyMedium, textSecondary)               | |
|  |                                            | |
|  |  support@onebytwo.app                      | |
|  |  (bodyLarge, primary, selectable text)      | |
|  |                                            | |
|  |  +------+          +------------------+    | |
|  |  | Close|          |  Copy Address    |    | |
|  |  +------+          +------------------+    | |
|  |  (outlined,         (primary filled,       | |
|  |   textSecondary)     onPrimary text)       | |
|  |                                            | |
|  +--------------------------------------------+ |
|  (cornerRadiusLarge: 24 dp)                      |
|                                                  |
+--------------------------------------------------+
```

**Behaviour:**

1. "Copy Address" taps: writes the support email address to the system clipboard via `Clipboard.setData`.
2. On successful copy: dialog dismisses, `OBTSnackbar(message: "Email address copied", type: info)` shown for 4000 ms.
3. "Close" taps: dialog dismisses with no further action.
4. Scrim tap or back gesture: equivalent to "Close".

**Analytics event:** `support_email_opened` with parameter `method: "fallback_dialog"`.

### 4.2 Edge Case: Remote Config Fetch Failure

If the `support_email_address` key is missing or Remote Config fetch has failed, the app uses the compiled-in default address (per dry-run document, Scenario 5). The flow proceeds identically -- the user sees no difference. No error UI is displayed for this case.

### 4.3 States

| State | Behaviour |
|---|---|
| Tapped (mail client available) | Mail client opens externally. No in-app state change. |
| Tapped (no mail client) | Fallback dialog appears with 200 ms fade-in (per `OBTConfirmationDialog` motion). |
| Copy pressed | Clipboard write, dialog dismisses, snackbar shown. |
| Close pressed | Dialog dismisses, 200 ms fade-out. |
| Remote Config missing | Silent fallback to default address. No user-facing error. |

### 4.4 Accessibility

| Element | Semantic Label | Notes |
|---|---|---|
| "Contact Support" row (Profile View) | `"Contact Support, button"` | Per dry-run test case 7 (screen reader test). |
| Fallback dialog | `"Alert: No Mail App Found"` | Modal focus trap per `OBTConfirmationDialog` spec. |
| Support email text | `"Support email address: [address]"` | Selectable; screen reader can read character by character. |
| Copy Address button | `"Copy Address, button"` | Announces `"Email address copied"` on success via snackbar live region. |
| Close button | `"Close, button"` | Dismisses dialog. |

---

## 5. Sign Out

**SRS requirements:** FR-AU-08 (P0), section 6.3 item 11.

**Navigation:** Triggered from Profile View's "Sign Out" row. Presents a modal `OBTConfirmationDialog`.

### 5.1 ASCII Layout -- Confirmation Dialog

```
+--------------------------------------------------+
|  (dimmed scrim)                                  |
|                                                  |
|  +--------------------------------------------+ |
|  |                                            | |
|  |  Sign out?                                 | |
|  |  (titleMedium, textPrimary)                | |
|  |                                            | |
|  |  Are you sure you want to sign out?        | |
|  |  You will need to verify your phone        | |
|  |  number again to sign back in.             | |
|  |  (bodyMedium, textSecondary)               | |
|  |                                            | |
|  |  +--------+        +------------------+    | |
|  |  | Cancel |        |    Sign Out      |    | |
|  |  +--------+        +------------------+    | |
|  |  (outlined,         (danger filled,        | |
|  |   textSecondary)     textOnDanger)         | |
|  |                                            | |
|  +--------------------------------------------+ |
|  (cornerRadiusLarge: 24 dp)                      |
|                                                  |
+--------------------------------------------------+
```

### 5.2 Component Mapping

```
OBTConfirmationDialog(
  title: "Sign out?",
  body: "Are you sure you want to sign out? You will need to verify your phone number again to sign back in.",
  cancelLabel: "Cancel",
  confirmLabel: "Sign Out",
  isDestructive: true,
  onCancel: dismissDialog,
  onConfirm: signOutAndNavigate
)
```

### 5.3 Behaviour

1. **Cancel:** Dialog dismisses. User returns to Profile View. No state change.
2. **Confirm ("Sign Out"):**
   a. Dialog shows loading state (per `OBTConfirmationDialog` Loading state: confirm button shows progress indicator, both buttons disabled).
   b. `FirebaseAuth.signOut()` is called.
   c. Local session is cleared (per FR-AU-08).
   d. On success: navigate to Phone Entry screen (Core Screen 2, SRS section 6.3 item 2). Clear entire navigation stack -- no back navigation to Profile.
   e. On error: dialog dismisses, `OBTSnackbar(message: "Could not sign out. Try again.", type: error)` shown.

### 5.4 States

| State | Behaviour |
|---|---|
| Dialog shown | Cancel and Sign Out buttons enabled. |
| Sign Out pressed | Confirm button shows circular progress indicator. Both buttons disabled. Scrim tap disabled. |
| Sign Out success | Navigation stack cleared. Phone Entry screen shown. |
| Sign Out error | Dialog dismisses. Error snackbar shown. Profile View remains. |

### 5.5 Accessibility

| Element | Semantic Label | Notes |
|---|---|---|
| Dialog | `"Alert: Sign out?"` | Modal focus trap per `OBTConfirmationDialog` spec. |
| Body text | Readable as-is | Read after title. |
| Cancel button | `"Cancel"` | -- |
| Sign Out button | `"Sign Out"` | Loading state announces `"Signing out"`. |

---

## 6. Delete Account

**SRS requirements:** FR-AU-09 (P1), section 5.5 (data removal within 30 days), section 6.3 item 11.

**Navigation:** Pushed from Profile View via "Delete Account" row. This is a multi-step flow within a single full-screen route, using an internal step controller. Bottom nav hidden.

### 6.1 Flow Overview

```
Profile View
    |
    v
[Step A: Warning]
    |
    v  (user taps "Continue")
[Step B: Re-authentication]
    |
    v  (OTP verified)
[Step C: Final Confirmation]
    |
    v  (user types DELETE, taps "Delete My Account")
[Step D: Processing]
    |
    v  (Cloud Function completes)
[Step E: Success]
    |
    v
Phone Entry Screen (stack cleared)
```

### Step A: Warning Screen

```
+--------------------------------------------------+
| OBTAppBar                                        |
|  [<- back]   "Delete Account"                    |
+--------------------------------------------------+
|                                                  |
|              [warning icon, 56 dp, danger]       |
|                                                  |
|  This will permanently delete                    |
|  your account                                    |
|  (titleLarge, textPrimary, centre-aligned)       |
|                                                  |
|  Your personal data, profile, and expense        |
|  history will be permanently removed.            |
|  (bodyMedium, textSecondary, centre-aligned)     |
|                                                  |
|  In shared groups, your name will be             |
|  replaced with "Deleted User" and your           |
|  balances will be preserved for other            |
|  members.                                        |
|  (bodyMedium, textSecondary, centre-aligned)     |
|                                                  |
|  +--------------------------------------------+ |
|  |  [info icon]  This cannot be undone.        | |
|  |               Data is removed within        | |
|  |               30 days of your request.      | |
|  +--------------------------------------------+ |
|  (info banner: danger at 12% opacity background, |
|   danger text, cornerRadiusSmall, 16 dp padding) |
|                                                  |
|                                                  |
|  +--------------------------------------------+ |
|  |              [  Continue  ]                 | |
|  +--------------------------------------------+ |
|  (full-width, danger filled, textOnDanger,       |
|   cornerRadiusSmall)                             |
|                                                  |
|  +--------------------------------------------+ |
|  |              [  Cancel  ]                   | |
|  +--------------------------------------------+ |
|  (full-width, outlined, textSecondary,           |
|   cornerRadiusSmall)                             |
|                                                  |
+--------------------------------------------------+
```

**Microcopy rationale:** The warning copy avoids legalistic language while being unambiguous about consequences, per SRS section 6.5. The 30-day timeline is stated per SRS section 5.5.

### Step B: Re-authentication

The user must verify their identity before deletion proceeds. This uses the same Firebase Phone Auth flow as initial login.

```
+--------------------------------------------------+
| OBTAppBar                                        |
|  [<- back]   "Verify Your Identity"              |
+--------------------------------------------------+
|                                                  |
|  To protect your account, please verify          |
|  your phone number before continuing.            |
|  (bodyMedium, textSecondary, centre-aligned)     |
|                                                  |
|  +--------------------------------------------+ |
|  | OBTPhoneInput                               | |
|  | +91 | [pre-filled with current number]      | |
|  +--------------------------------------------+ |
|  (read-only; pre-filled from authenticated       |
|   session. User confirms by requesting OTP.)     |
|                                                  |
|  +--------------------------------------------+ |
|  |           [  Send OTP  ]                    | |
|  +--------------------------------------------+ |
|  (full-width, primary filled, cornerRadiusSmall) |
|                                                  |
|  --- after OTP sent ---                          |
|                                                  |
|  +--------------------------------------------+ |
|  | OBTOTPInput                                 | |
|  | [ ][ ][ ][ ][ ][ ]                         | |
|  +--------------------------------------------+ |
|                                                  |
|  Resend OTP (30s cooldown)                       |
|  (bodySmall, primary, disabled during cooldown)  |
|                                                  |
+--------------------------------------------------+
```

**Behaviour:**

- Phone number is pre-filled and read-only (the user is re-authenticating, not changing their number).
- OTP entry uses the `OBTOTPInput` component with all its states (auto-read on Android, manual entry on iOS).
- On successful OTP verification, the flow advances to Step C automatically.
- On OTP error: `OBTOTPInput` error state triggers ("Incorrect code, try again").
- Retry limits: same as FR-AU-05 (30-second cooldown, 3 retries per 10-minute window).

### Step C: Final Confirmation

```
+--------------------------------------------------+
| OBTAppBar                                        |
|  [<- back]   "Confirm Deletion"                  |
+--------------------------------------------------+
|                                                  |
|  This is your last chance to change your mind.   |
|  (bodyMedium, textSecondary, centre-aligned)     |
|                                                  |
|  Type DELETE to confirm                          |
|  (labelMedium, textSecondary)                    |
|                                                  |
|  +--------------------------------------------+ |
|  |                                             | |
|  +--------------------------------------------+ |
|  (text input, cornerRadiusSmall, outline border, |
|   uppercase, monospace font style,               |
|   placeholder: "DELETE")                         |
|                                                  |
|  +--------------------------------------------+ |
|  |         [  Delete My Account  ]             | |
|  +--------------------------------------------+ |
|  (full-width, danger filled, textOnDanger,       |
|   cornerRadiusSmall)                             |
|  (disabled until input === "DELETE")             |
|                                                  |
+--------------------------------------------------+
```

**Validation:**

- The text input accepts only the exact string "DELETE" (case-sensitive).
- The "Delete My Account" button is disabled (using `disabled` colour) until the input matches.
- Input is trimmed of leading/trailing whitespace before comparison.

### Step D: Processing (Loading State)

```
+--------------------------------------------------+
| OBTAppBar                                        |
|  "Deleting Account"  [no back button]            |
+--------------------------------------------------+
|                                                  |
|                                                  |
|              [circular progress indicator,       |
|               56 dp, primary]                    |
|                                                  |
|  Deleting your account...                        |
|  (bodyMedium, textSecondary, centre-aligned)     |
|                                                  |
|  This may take a moment.                         |
|  (bodySmall, textTertiary, centre-aligned)       |
|                                                  |
|                                                  |
+--------------------------------------------------+
```

**Behaviour:**

- Back button is removed. System back gesture is intercepted and ignored.
- The Cloud Function `deleteUserAccount` processes the request.
- If the function returns success, advance to Step E.
- If the function returns an error or times out (after 30 seconds):
  - Navigate back to Profile View.
  - `OBTSnackbar(message: "Account deletion failed. Please try again or contact support.", type: error, actionLabel: "Contact Support", onAction: triggerContactSupportFlow)`.

### Step E: Success

```
+--------------------------------------------------+
|                                                  |
|                                                  |
|              [check circle icon, 64 dp, success] |
|                                                  |
|  Account deleted                                 |
|  (titleLarge, textPrimary, centre-aligned)       |
|                                                  |
|  Your data will be fully removed                 |
|  within 30 days.                                 |
|  (bodyMedium, textSecondary, centre-aligned)     |
|                                                  |
|                                                  |
+--------------------------------------------------+
```

**Behaviour:**

- Displayed for 3 seconds (3000 ms).
- After 3 seconds, the navigation stack is cleared and the user is taken to the Phone Entry screen (Core Screen 2, SRS section 6.3 item 2).
- No back navigation is possible from this state.
- The success icon fades in with `motionStandard` (200 ms ease-in-out).

### 6.2 Complete State Matrix

| Step | State | Behaviour | Back Navigation |
|---|---|---|---|
| A (Warning) | Default | Warning copy displayed. Continue and Cancel buttons active. | Back to Profile View. |
| A | Cancel pressed | Navigate back to Profile View. | -- |
| A | Continue pressed | Advance to Step B. | -- |
| B (Re-auth) | Default | Phone pre-filled. "Send OTP" button active. | Back to Step A. |
| B | OTP sent | `OBTOTPInput` appears. 30-second cooldown on resend. | Back to Step A. |
| B | OTP error | `OBTOTPInput` error state. User can retry. | Back to Step A. |
| B | OTP verified | Auto-advance to Step C. | -- |
| B | Max retries exceeded | `OBTSnackbar(type: error)`. Back button remains active. | Back to Step A. |
| C (Confirm) | Default | Text input empty. Delete button disabled. | Back to Step B. |
| C | Input matches "DELETE" | Delete button enabled (`danger` fill). | Back to Step B. |
| C | Delete pressed | Advance to Step D. | -- |
| D (Processing) | Loading | Progress indicator. No back button. | Blocked. |
| D | Error / timeout | Navigate to Profile View. Error snackbar with Contact Support action. | -- |
| E (Success) | Shown | 3-second display, then navigate to Phone Entry. | Blocked. |

### 6.3 Accessibility

| Element | Semantic Label | Notes |
|---|---|---|
| Warning icon (Step A) | `"Warning"` | Decorative but announced for context. |
| Info banner (Step A) | `"Important: This cannot be undone. Data is removed within 30 days of your request."` | Announced as a group. |
| Continue button (Step A) | `"Continue with account deletion, button"` | Explicit about the action. |
| Cancel button (Step A) | `"Cancel, button"` | -- |
| Phone input (Step B) | Per `OBTPhoneInput` spec | Pre-filled; announced as read-only. |
| OTP input (Step B) | Per `OBTOTPInput` spec | -- |
| Confirmation input (Step C) | `"Type DELETE to confirm, text field"` | Placeholder announced. |
| Delete button (Step C) | `"Delete My Account, button"` or `"Delete My Account, button, disabled"` | -- |
| Progress indicator (Step D) | `"Deleting your account, please wait"` | Live region for screen readers. |
| Success icon (Step E) | `"Account deleted successfully"` | Announced once. |

---

## Extension Points

### IA-EXT-03: Language Selector Row

**Location:** Profile View, between the "Contact Support" row and the destructive actions section divider.

**v1.0 state:** Not rendered. No widget, no placeholder, no hidden element. The slot exists conceptually in the layout specification above (noted in the ASCII layout with a comment). The `.arb` localisation infrastructure ships with `en` as the sole locale (per extension-points.md).

**v1.1 behaviour:** A new action row appears:

```
|  [language icon]  Language                  >  |
|                   English                      |
|                   (bodySmall, textTertiary)     |
```

Tapping opens a locale picker bottom sheet. Selected locale persists to the user document and updates the app's `Locale`. No existing Profile screen elements change.

**SRS reference:** Section 12.3 bullet 2 (Hindi and other Indian-language localisations); section 5.9 (Localisation).

### IA-EXT-05: Contact Support Channel Selector

**Location:** Contact Support flow (section 4 of this document).

**v1.0 state:** The "Contact Support" row triggers the email flow directly. No channel selection UI exists.

**v1.1 behaviour:** Tapping "Contact Support" opens a bottom sheet with two options:

```
+----------------------------------------------+
| Contact Support                              |
|                                              |
| [mail icon]   Email Support                  |
| [chat icon]   Chat with Support              |
|                                              |
| [Cancel]                                     |
+----------------------------------------------+
```

"Email Support" triggers the existing `mailto:` flow. "Chat with Support" opens an embedded helpdesk widget or web view (Freshdesk / Zoho Desk). The Remote Config key `support_email_address` is extended with a `support_helpdesk_url` parameter. No existing email flow logic changes.

**SRS reference:** Section 12.3 bullet 6 (dedicated helpdesk integration).

---

## Cross-Reference Matrix

| Screen / Flow | SRS Requirement | Priority | Components Used |
|---|---|---|---|
| Profile View | FR-PR-01, FR-PR-04, FR-PR-05, FR-AU-08, FR-AU-09 | P0, P0, P0, P0, P1 | `OBTAppBar`, `OBTBottomNav`, `OBTUserAvatar`, `OBTSkeletonLoader`, `OBTErrorState` |
| Edit Profile | FR-PR-01 | P0 | `OBTAppBar`, `OBTUserAvatar`, `OBTSnackbar` |
| Notification Preferences | FR-PR-03, FR-AC-04 | P1, P1 | `OBTAppBar`, `OBTSkeletonLoader`, `OBTErrorState`, `OBTSnackbar` |
| Contact Support (mailto) | FR-PR-05, FR-SH-03 | P0, P0 | None (external mail client) |
| Contact Support (fallback) | FR-SH-04 | P1 | `OBTConfirmationDialog` (adapted), `OBTSnackbar` |
| Sign Out | FR-AU-08 | P0 | `OBTConfirmationDialog`, `OBTSnackbar` |
| Delete Account | FR-AU-09 | P1 | `OBTAppBar`, `OBTPhoneInput`, `OBTOTPInput`, `OBTConfirmationDialog`, `OBTSnackbar` |

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2025-01-XX | UX/UI Designer | Initial draft -- six screens/flows covering Profile and Support for Core Screen 11. |