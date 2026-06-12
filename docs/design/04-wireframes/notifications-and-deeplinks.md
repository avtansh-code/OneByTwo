# Notifications and Deep Links Wireframes

This document specifies the visual layouts, interaction flows, and state definitions
for all notification and deep-link surfaces in One By Two v1.0. It is authored by
the UX/UI Designer and handed off to the Flutter Developer for implementation.

> **Status.** Implemented: in-app banner (`InAppNotificationBanner`), pre-permission dialog (`pre_permission_dialog.dart`), lifecycle host (`notifications_lifecycle_host.dart`), and deep-link resolution (`NotificationDeepLinks`, via `MaterialPageRoute`). There is **no URL deep-link scheme**; `group_invite` → 'Groups are coming soon' snackbar; deleted/malformed → 'This item is no longer available'.

**SRS version:** 1.1
**Primary requirements:** FR-AC-03, FR-AC-04, FR-AC-05 (SRS section 4.7),
FR-PR-03 (SRS section 4.2), FR-SH-02 (SRS section 4.11), FR-GR-02, FR-GR-03
(SRS section 4.4).
**Cross-references:** `docs/design/03-architecture/data-flow.md`,
`docs/design/01-information-architecture/navigation-flow.md`,
`docs/design/01-information-architecture/site-map.md` (section 3).

---

## Design Token Reference

All surfaces in this document adhere to the visual system defined in SRS
section 6.2:

| Token | Value | Application in this document |
|---|---|---|
| Primary | `#1F4E79` / `#2E86AB` accent | Banner icon tint, "Enable Notifications" button |
| Secondary | `#F4A261` (Saffron/Marigold) | Reminder notification accent |
| Success | `#2A9D8F` (Emerald) | Settlement-received banner highlight |
| Danger | `#E76F51` (Coral Red) | Error dialog icon, destructive states |
| Surface | `#FFFFFF` / `#121212` dark mode | Banner background, dialog surface |
| Corner radius | 16 dp (banner), 24 dp (dialog/sheet) | All containers |
| Elevation | 4 dp shadow on banner; 8 dp on dialog | Depth layering |
| Motion | 300 ms ease-in-out (banner slide); 200 ms fade (dismiss) | All animations |
| Typography | Plus Jakarta Sans / Inter; system fallback | All text elements |

---

## 1. Push Permission Prompt

**When shown:** After the user completes profile setup (SRS section 6.3, screen 4)
and lands on the Home dashboard for the first time. This is NOT shown at app launch
or during onboarding slides (SRS section 5.6 -- avoid interrupting the user before
they understand the app's value).

**Requirement mapping:** FR-AC-03 (push notifications via FCM), FR-PR-03
(per-category notification preferences).

### 1.1 Layout -- Custom Pre-Permission Dialog

```
+--------------------------------------------------+
|                                                  |
|  (dark scrim overlay, 40% opacity)               |
|                                                  |
|  +--------------------------------------------+  |
|  |              [24 dp radius]                |  |
|  |                                            |  |
|  |         [ Bell illustration ]              |  |
|  |            64 x 64 dp                      |  |
|  |         tinted Primary #2E86AB             |  |
|  |                                            |  |
|  |    "Stay in the loop"                      |  |
|  |    Heading/20 Bold, On-Surface             |  |
|  |    Centre-aligned                          |  |
|  |                                            |  |
|  |    "Get notified when friends add          |  |
|  |     expenses or settle up. You can         |  |
|  |     change this any time in Settings."     |  |
|  |    Body/14 Regular, On-Surface/70%         |  |
|  |    Centre-aligned                          |  |
|  |                                            |  |
|  |    16 dp vertical spacing                  |  |
|  |                                            |  |
|  |  +--------------------------------------+  |  |
|  |  |       Enable Notifications           |  |  |
|  |  |  Filled button, Primary #1F4E79      |  |  |
|  |  |  48 dp height, full width - 32 dp    |  |  |
|  |  |  Label/16 SemiBold, On-Primary       |  |  |
|  |  +--------------------------------------+  |  |
|  |                                            |  |
|  |         "Not now"                          |  |
|  |    Text button, On-Surface/60%             |  |
|  |    Body/14 Medium                          |  |
|  |    44 dp min tap target (SRS 5.6)          |  |
|  |                                            |  |
|  +--------------------------------------------+  |
|                                                  |
+--------------------------------------------------+
```

### 1.2 Interaction States

| State | Behaviour |
|---|---|
| **Default** | Dialog appears with a 300 ms fade-in over the Home dashboard. |
| **Tap "Enable Notifications"** | Dismiss dialog (200 ms fade-out). Trigger the native OS permission prompt (iOS `requestAuthorization`, Android `POST_NOTIFICATIONS`). |
| **OS prompt -- Allow** | FCM token is registered on the user's Firestore document (`fcmTokens` array union, per data-flow.md Flow 1). User proceeds to Home. |
| **OS prompt -- Deny** | No token registered. The app records the denial locally. The user may enable notifications later from `/profile/notifications` (FR-PR-03). |
| **Tap "Not now"** | Dismiss dialog (200 ms fade-out). No OS prompt is triggered. Record local flag so the dialog is not shown again this session. |
| **Back gesture / scrim tap** | Equivalent to "Not now". |

### 1.3 Accessibility

- Dialog traps focus (SRS section 5.6 -- screen-reader compatible).
- Semantic label on illustration: "Notification bell icon".
- "Enable Notifications" button: `semanticsLabel: "Enable push notifications"`.
- "Not now" button: `semanticsLabel: "Skip enabling notifications for now"`.
- All text meets WCAG 2.1 AA contrast (greater than or equal to 4.5:1 against Surface).
- Both buttons meet minimum tap target: 48 x 48 dp (SRS section 5.6).

---

## 2. Notification Delivery -- Foreground (In-App Banner)

**When shown:** The app is in the foreground and a push notification arrives via
FCM. Instead of a system notification, a custom in-app banner is displayed
(FR-AC-03). The notification must respect per-category preferences (FR-AC-04).

### 2.1 Layout -- In-App Notification Banner

```
+--------------------------------------------------+
|  STATUS BAR                                      |
+--------------------------------------------------+
|  +--------------------------------------------+  |
|  |  [16 dp radius, 4 dp elevation]           |  |
|  |  8 dp margin horizontal, 8 dp from top    |  |
|  |                                            |  |
|  |  +----+  Title text           timestamp    |  |
|  |  |icon|  Body text (max 2 lines,           |  |
|  |  |32dp|  ellipsis overflow)                |  |
|  |  +----+                                    |  |
|  |                                            |  |
|  |  Min height: 64 dp                         |  |
|  |  Padding: 12 dp all sides                  |  |
|  +--------------------------------------------+  |
|                                                  |
|  [ Existing screen content continues below ]     |
|                                                  |
+--------------------------------------------------+
```

### 2.2 Banner Anatomy

| Element | Specification |
|---|---|
| **Container** | Surface colour, 16 dp corner radius, 4 dp elevation shadow. 8 dp horizontal margin from screen edges. |
| **Icon** | 32 x 32 dp, category-specific. Expense: receipt icon, tinted Primary. Settlement: tick-circle, tinted Success `#2A9D8F`. Reminder: bell icon, tinted Secondary `#F4A261`. |
| **Title** | Label/14 SemiBold, On-Surface. Single line, ellipsis if truncated. Examples: "Rahul added an expense", "Priya settled up". |
| **Body** | Body/12 Regular, On-Surface/70%. Maximum 2 lines, ellipsis overflow. Examples: "Dinner at Barbeque Nation -- Rs.1,200", "You received Rs.350". |
| **Timestamp** | Caption/10 Regular, On-Surface/40%. Aligned top-right. Displays relative time: "Just now", "2m ago". |
| **Touch target** | Entire banner is tappable. Minimum 64 dp height satisfies 48 dp tap target requirement (SRS section 5.6). |

### 2.3 Interaction States

| State | Behaviour |
|---|---|
| **Appear** | Slides down from top of screen, 300 ms ease-in-out (SRS section 6.2 motion token). |
| **Auto-dismiss** | Fades out after 4 seconds, 200 ms ease-out. |
| **Swipe up** | User swipes up to dismiss immediately. 200 ms ease-out animation. |
| **Tap** | Banner dismisses (200 ms fade). App navigates to the relevant screen via GoRouter deep-link resolution (FR-AC-05). Navigation targets per the Deep-Link Map in section 6. |
| **Multiple notifications** | If a second notification arrives while a banner is visible, the current banner is replaced with a 150 ms crossfade. Only one banner is shown at a time. |
| **Category disabled** | If the user has disabled this notification category in `/profile/notifications` (FR-AC-04, FR-PR-03), no banner is shown. |

### 2.4 Accessibility

- Banner is announced by screen readers as a live region (polite priority).
- Semantic label: "[Title]. [Body]. Tap to view details. Swipe up to dismiss."
- Dismiss action exposed to VoiceOver/TalkBack custom actions.
- All text meets WCAG 2.1 AA contrast ratios (SRS section 5.6).
- Auto-dismiss timer pauses if the screen reader is active (accessibility best
  practice; prevents content disappearing before it can be read).

---

## 3. Notification Delivery -- Background and Closed App

**When shown:** The app is backgrounded or terminated. FCM delivers a standard
system notification through the OS notification tray (FR-AC-03).

### 3.1 System Notification Specification

```
+--------------------------------------------------+
|  SYSTEM NOTIFICATION TRAY                        |
+--------------------------------------------------+
|  +--------------------------------------------+  |
|  |  [App Icon]  One By Two         now           |  |
|  |                                            |  |
|  |  Title: "Rahul added an expense"           |  |
|  |  Body:  "Dinner -- Rs.600. You owe Rs.200."  |  |
|  +--------------------------------------------+  |
+--------------------------------------------------+
```

### 3.2 Notification Content Templates

| Notification Type | Title Template | Body Template |
|---|---|---|
| New expense | "{name} added an expense" | "{description} -- Rs.{amount}. {youOweOrAreOwed}." |
| Expense edited | "{name} edited an expense" | "{description} was updated to Rs.{amount}." |
| Expense deleted | "{name} deleted an expense" | "{description} (Rs.{amount}) was removed." |
| Settlement received | "{name} settled up" | "You received Rs.{amount}." |
| Reminder | "Reminder from {name}" | "{name} is nudging you about Rs.{amount}." |
| Group invite | "{name} invited you to a group" | "Join \"{groupName}\" to start splitting." |

### 3.3 Interaction

| Action | Behaviour |
|---|---|
| **Tap notification** | Opens the app. If app was terminated (cold start), follows the cold-start deep-link flow (section 4). If app was backgrounded (warm start), the notification handler calls `GoRouter.go()` to navigate directly to the target screen (FR-AC-05). Auth guard validates before navigation (per navigation-flow.md section 4). |
| **Dismiss notification** | Standard OS swipe-to-dismiss. No app-side action. |

### 3.4 Dark Mode

System notifications inherit OS-level dark mode styling. No custom dark mode
handling is required for system notifications.

### 3.5 Accessibility

- Notification title and body are read by the OS screen reader automatically.
- Amounts are formatted with grouping separators for readability (e.g., "1,200").
- All amounts are displayed in rupees at the UI layer; stored as integer paise
  internally (Invariant 1, SRS section 7.3).

---

## 4. Cold-Start Deep Link

**When triggered:** User taps a push notification or an invite link while the app
is fully terminated (FR-AC-05, FR-AU-07).

**Flow source:** navigation-flow.md section 2 (Entry Points) and section 4
(Auth Guard).

### 4.1 Flow Diagram

```
  +-------------------+
  | User taps         |
  | notification or   |
  | invite link       |
  +--------+----------+
           |
           v
  +-------------------+
  | OS launches app   |
  | with payload      |
  +--------+----------+
           |
           v
  +-------------------+
  | Splash screen     |
  | (branding, max    |
  |  2 seconds)       |
  +--------+----------+
           |
           v
  +-------------------+
  | Auth guard check  |
  | (GoRouter         |
  |  redirect)        |
  +--------+----------+
           |
     +-----+------+
     |            |
     v            v
  +------+   +---------+
  | Auth  |   | Auth    |
  | valid |   | invalid |
  +--+---+   +----+----+
     |            |
     v            v
  +------+   +----------+
  | Store |   | Store    |
  | n/a   |   | deep-    |
  |       |   | link     |
  +--+---+   | intent   |
     |       +----+-----+
     |            |
     v            v
  +--------+  +----------+
  | Resolve|  | Phone    |
  | deep-  |  | auth     |
  | link   |  | flow     |
  | target |  +----+-----+
  +--+--+--+      |
     |  |         v
     |  |    +----------+
     |  |    | On auth  |
     |  |    | success, |
     |  |    | restore  |
     |  |    | deep-    |
     |  |    | link     |
     |  |    +----+-----+
     |  |         |
     |  +----+----+
     |       |
     v       v
  +---+------+----+
  | Target entity  |
  | exists?        |
  +---+--------+---+
      |        |
      v        v
  +------+  +----------+
  | YES  |  |   NO     |
  | Nav  |  | Show     |
  | to   |  | error    |
  | dest.|  | dialog   |
  +------+  +----+-----+
                 |
                 v
            +----------+
            | Navigate  |
            | to Home   |
            | dashboard |
            +----------+
```

### 4.2 States

| State | Visual | Behaviour |
|---|---|---|
| **Splash** | App logo centred on Primary background. No loading indicator. | Displays for the duration of auth initialisation, maximum 2 seconds. |
| **Auth check -- loading** | Splash screen persists. | Firebase Auth restores persisted session (FR-AU-07). |
| **Auth valid, entity exists** | No intermediate screen. | GoRouter navigates to deep-link destination. The screen renders with its standard loading state (skeleton) while data is fetched (SRS section 6.4). |
| **Auth valid, entity not found** | Error dialog overlays the Home dashboard (see section 4.3). | User is navigated to Home, then the dialog appears. |
| **Auth invalid** | Phone entry screen (`/auth/phone`). | Deep-link intent is stored in memory. After successful authentication, GoRouter replays the stored deep-link (FR-AC-05 -- "even from a cold start"). |

### 4.3 Entity-Not-Found Error Dialog

```
+--------------------------------------------------+
|                                                  |
|  (dark scrim overlay, 40% opacity)               |
|                                                  |
|  +--------------------------------------------+  |
|  |              [24 dp radius]                |  |
|  |                                            |  |
|  |         [ Warning illustration ]           |  |
|  |            48 x 48 dp                      |  |
|  |         tinted Danger #E76F51              |  |
|  |                                            |  |
|  |    "This item is no longer available"      |  |
|  |    Heading/18 SemiBold, On-Surface         |  |
|  |    Centre-aligned                          |  |
|  |                                            |  |
|  |    "It may have been deleted or you        |  |
|  |     may no longer have access."            |  |
|  |    Body/14 Regular, On-Surface/70%         |  |
|  |    Centre-aligned                          |  |
|  |                                            |  |
|  |  +--------------------------------------+  |  |
|  |  |            Go to Home                |  |  |
|  |  |  Filled button, Primary #1F4E79      |  |  |
|  |  |  48 dp height, full width - 32 dp    |  |  |
|  |  +--------------------------------------+  |  |
|  |                                            |  |
|  +--------------------------------------------+  |
|                                                  |
+--------------------------------------------------+
```

**Fallback navigation** follows the parent-resolution rules from
site-map.md section 3.3:

| Missing Entity | Fallback Destination |
|---|---|
| `/expense/:id` not found | `/activity` (Activity Feed) |
| `/friend/:id` not found | `/friends` (Friends List) |
| `/group/:id` not found | `/groups` (Groups List) |
| `/group/:gid/expense/:eid` not found | `/groups/:gid` if group exists; else `/groups` |
| `/settle/:id` not found | `/activity` (Activity Feed) |
| `/invite/group/:code` expired or revoked | `/groups` (Groups List) |

### 4.4 Accessibility

- Error dialog traps focus and is announced by screen readers.
- Semantic label on warning icon: "Warning icon".
- "Go to Home" button: minimum 48 x 48 dp tap target (SRS section 5.6).

---

## 5. Share-Sheet Invite Link Resolution

**When triggered:** A user taps a One By Two invite link received via SMS, WhatsApp,
or any messaging app (FR-SH-02, FR-GR-02, FR-GR-03). The link is surfaced
through the system share sheet only (Invariant 3).

**Link format:** Universal Link (iOS) / App Link (Android), per
navigation-flow.md section 2 and site-map.md section 3.4 (ADR-0015).

### 5.1 Flow Diagram -- App Installed

```
  +-------------------+
  | User taps invite  |
  | link in messaging |
  | app               |
  +--------+----------+
           |
           v
  +-------------------+
  | OS resolves       |
  | Universal Link /  |
  | App Link          |
  +--------+----------+
           |
           v
  +-------------------+
  | App opens with    |
  | link payload      |
  +--------+----------+
           |
           v
  +-------------------+
  | Auth guard check  |
  | (GoRouter         |
  |  redirect)        |
  +--------+----------+
           |
     +-----+------+
     |            |
     v            v
  +------+   +---------+
  | Auth  |   | Auth    |
  | valid |   | invalid |
  +--+---+   +----+----+
     |            |
     |            v
     |       +----------+
     |       | Store    |
     |       | invite   |
     |       | intent   |
     |       +----+-----+
     |            |
     |            v
     |       +----------+
     |       | Auth     |
     |       | flow     |
     |       +----+-----+
     |            |
     v            v
  +---+------+----+
  | Resolve invite |
  | token          |
  +---+--------+---+
      |        |
      v        v
  +------+  +----------+
  | Valid |  | Expired  |
  | token |  | or       |
  |       |  | revoked  |
  +--+---+  +----+-----+
     |            |
     v            v
  +--------+  +----------+
  | Group  |  | Error    |
  | Invite |  | dialog:  |
  | Accept |  | "This    |
  | screen |  | invite   |
  |        |  | has      |
  |        |  | expired" |
  +--------+  +----+-----+
                   |
                   v
              +----------+
              | Navigate  |
              | to Groups |
              | list      |
              +----------+
```

### 5.2 Group Invite Acceptance Screen

```
+--------------------------------------------------+
|  STATUS BAR                                      |
+--------------------------------------------------+
|  [<- Back]                                       |
|                                                  |
|  +--------------------------------------------+  |
|  |              [24 dp radius]                |  |
|  |                                            |  |
|  |      [ Group cover image / icon ]          |  |
|  |            80 x 80 dp, circular            |  |
|  |                                            |  |
|  |    "{inviterName} invited you to"          |  |
|  |    Body/14 Regular, On-Surface/70%         |  |
|  |    Centre-aligned                          |  |
|  |                                            |  |
|  |    "{groupName}"                           |  |
|  |    Heading/22 Bold, On-Surface             |  |
|  |    Centre-aligned                          |  |
|  |                                            |  |
|  |    "{memberCount} members"                 |  |
|  |    Caption/12 Regular, On-Surface/50%      |  |
|  |    Centre-aligned                          |  |
|  |                                            |  |
|  |    24 dp vertical spacing                  |  |
|  |                                            |  |
|  |  +--------------------------------------+  |  |
|  |  |         Join Group                   |  |  |
|  |  |  Filled button, Primary #1F4E79      |  |  |
|  |  |  48 dp height, full width - 32 dp    |  |  |
|  |  |  Label/16 SemiBold, On-Primary       |  |  |
|  |  +--------------------------------------+  |  |
|  |                                            |  |
|  |         "Decline"                          |  |
|  |    Text button, On-Surface/60%             |  |
|  |    Body/14 Medium                          |  |
|  |    44 dp min tap target                    |  |
|  |                                            |  |
|  +--------------------------------------------+  |
|                                                  |
+--------------------------------------------------+
```

### 5.3 Flow Diagram -- App Not Installed

```
  +-------------------+
  | User taps invite  |
  | link in messaging |
  | app               |
  +--------+----------+
           |
           v
  +-------------------+
  | OS cannot resolve |
  | Universal Link /  |
  | App Link          |
  +--------+----------+
           |
           v
  +-------------------+
  | Fallback URL      |
  | redirects to      |
  | App Store (iOS)   |
  | or Play Store     |
  | (Android)         |
  +--------+----------+
           |
           v
  +-------------------+
  | User installs app |
  | and opens it      |
  +--------+----------+
           |
           v
  +-------------------+
  | Standard cold     |
  | start flow        |
  | (no deferred      |
  | deep link in      |
  | v1.0)             |
  +-------------------+
```

**Note:** Deferred deep linking (preserving the invite intent through an install)
is not in scope for v1.0. The user will need to tap the invite link again after
installing the app. This is a candidate for v1.1 enhancement.

### 5.4 Invite Link Expired Dialog

```
+--------------------------------------------------+
|                                                  |
|  (dark scrim overlay, 40% opacity)               |
|                                                  |
|  +--------------------------------------------+  |
|  |              [24 dp radius]                |  |
|  |                                            |  |
|  |         [ Link-broken illustration ]       |  |
|  |            48 x 48 dp                      |  |
|  |         tinted Danger #E76F51              |  |
|  |                                            |  |
|  |    "This invite link has expired"          |  |
|  |    Heading/18 SemiBold, On-Surface         |  |
|  |    Centre-aligned                          |  |
|  |                                            |  |
|  |    "Ask the group admin to send you a      |  |
|  |     fresh invite."                         |  |
|  |    Body/14 Regular, On-Surface/70%         |  |
|  |    Centre-aligned                          |  |
|  |                                            |  |
|  |  +--------------------------------------+  |  |
|  |  |              Got it                  |  |  |
|  |  |  Filled button, Primary #1F4E79      |  |  |
|  |  |  48 dp height, full width - 32 dp    |  |  |
|  |  +--------------------------------------+  |  |
|  |                                            |  |
|  +--------------------------------------------+  |
|                                                  |
+--------------------------------------------------+
```

### 5.5 Interaction States

| State | Behaviour |
|---|---|
| **Valid invite, authenticated** | Navigate directly to Group Invite Acceptance screen. |
| **Valid invite, unauthenticated** | Store invite intent. Complete auth flow. On success, navigate to Group Invite Acceptance screen (FR-AC-05). |
| **Expired invite (7-day expiry, FR-GR-03)** | Show expired dialog. On dismiss, navigate to `/groups`. |
| **Revoked invite (admin revoked, FR-GR-03)** | Show expired dialog (same visual; body text: "This invite is no longer valid"). On dismiss, navigate to `/groups`. |
| **Tap "Join Group"** | Button enters loading state (spinner replaces label). On success, navigate to Group Detail (`/groups/:id`). On failure, show inline error toast with "Retry" affordance (SRS section 6.4). |
| **Tap "Decline"** | Navigate to `/groups` (Groups List). No server call. |

### 5.6 Accessibility

- Group Invite Acceptance screen: all interactive elements meet 48 x 48 dp tap
  targets (SRS section 5.6).
- Group name announced by screen reader with context: "You have been invited to
  [groupName] by [inviterName]."
- Expired dialog traps focus.
- All text meets WCAG 2.1 AA contrast ratios.

---

## 6. Deep-Link Map

This table defines the mapping from notification type to payload structure,
destination screen, and fallback behaviour. It extends the deep-link payload
contract defined in navigation-flow.md section 5.

| Notification Type | Payload Fields | Destination Screen | Route Path | Fallback (entity missing) | SRS Reference |
|---|---|---|---|---|---|
| New expense | `type: "expense_added"`, `contextType: "group"` or `"friendship"`, `contextId`, `itemId` (expenseId) | Group Detail or Friend Detail, scrolled to expense | `/group/:contextId/expense/:itemId` or `/expense/:itemId` | `/home` | FR-AC-03, FR-AC-05 |
| Expense edited | `type: "expense_edited"`, `contextType`, `contextId`, `itemId` (expenseId) | Group Detail or Friend Detail, scrolled to expense | `/group/:contextId/expense/:itemId` or `/expense/:itemId` | `/home` | FR-AC-03, FR-AC-05 |
| Expense deleted | `type: "expense_deleted"`, `contextType`, `contextId` | Group Detail or Friend Detail (expense no longer exists) | `/group/:contextId` or `/friend/:contextId` | `/home` | FR-AC-03, FR-AC-05 |
| Settlement received | `type: "settlement_received"`, `contextType`, `contextId`, `itemId` (settlementId) | Friend Detail or Group Detail | `/friend/:contextId` or `/group/:contextId` | `/home` | FR-AC-03, FR-AC-05 |
| Reminder | `type: "reminder"`, `contextType: "friendship"`, `contextId` (friendshipId) | Friend Detail | `/friend/:contextId` | `/home` | FR-AC-03, FR-SE-09, FR-AC-05 |
| Group invite | `type: "group_invite"`, `contextId` (groupId), `inviteToken` | Group Invite Acceptance | `/invite/group/:inviteToken` | `/home` | FR-GR-02, FR-GR-03, FR-AC-05 |

### 6.1 Payload Schema

All notification payloads conform to the contract in navigation-flow.md section 5:

```
{
  "type":        string,   // e.g., "expense_added", "settlement_received"
  "contextType": string,   // "friendship" | "group"
  "contextId":   string,   // Firestore document ID
  "itemId":      string?   // Optional; expense or settlement ID
  "inviteToken": string?   // Optional; only for group_invite type
}
```

### 6.2 Resolution Logic

1. GoRouter `redirect` runs the auth guard (navigation-flow.md section 4).
2. If authenticated, the route resolver reads `type` to determine the target route.
3. If `contextType` is `"group"`, the route resolves to a `/group/` prefixed path;
   if `"friendship"`, to a `/friend/` prefixed path.
4. If the target document does not exist (Firestore returns not-found), the
   entity-not-found error dialog is shown (section 4.3) and the user is navigated
   to the fallback destination per site-map.md section 3.3.
5. If the payload is malformed or missing required fields, the user is navigated to
   `/home` (navigation-flow.md section 5).

---

## 7. Microcopy Reference

All microcopy follows the tone defined in SRS section 6.5: friendly, concise,
and lightly playful. No legalistic language.

| Surface | Copy | Notes |
|---|---|---|
| Push permission -- heading | "Stay in the loop" | Warm, inviting. |
| Push permission -- body | "Get notified when friends add expenses or settle up. You can change this any time in Settings." | Explains value; reassures user of control. |
| Push permission -- primary button | "Enable Notifications" | Clear action. |
| Push permission -- secondary button | "Not now" | Non-judgmental opt-out. |
| In-app banner -- expense | "{name} added an expense" | Personalised with friend's display name. |
| In-app banner -- settlement | "{name} settled up" | Positive tone. |
| In-app banner -- reminder | "{name} sent you a nudge" | Playful. Avoids "reminder" which feels transactional. |
| Entity not found -- heading | "This item is no longer available" | Factual, not alarming. |
| Entity not found -- body | "It may have been deleted or you may no longer have access." | Covers both cases without blame. |
| Invite expired -- heading | "This invite link has expired" | Direct. |
| Invite expired -- body | "Ask the group admin to send you a fresh invite." | Actionable guidance. |
| Group invite -- join context | "{inviterName} invited you to" | Personal, warm. |

---

## 8. Extension Points

These features are explicitly out of scope for v1.0 but the designs above
are structured to accommodate them without rework.

| Extension | Description | Impact on Current Design |
|---|---|---|
| **In-app notification inbox** | A persistent list of all notifications, replacing or supplementing push delivery. Could be added as a sub-tab or overlay on the Activity Feed (SRS section 6.3, screen 10). | The in-app banner component (section 2) can be reused as a list item in the inbox. The deep-link map (section 6) applies identically to inbox item taps. |
| **Rich notifications with action buttons** | iOS/Android support for action buttons directly in system notifications (e.g., "Settle Up", "View Expense"). | Payload schema (section 6.1) already carries sufficient context to construct action deep links. No visual changes to in-app surfaces. |
| **Deferred deep linking** | Preserving invite intent through app install (section 5.3). | Requires integration with Firebase Dynamic Links or a third-party deferred deep-link service. No visual changes to in-app surfaces. |
| **Notification grouping** | OS-level grouping of multiple notifications from the same group or conversation. | No visual changes to in-app surfaces. Requires FCM payload configuration (thread ID on iOS, channel/group on Android). |

---

## 9. SRS Cross-References

| SRS Section | Relevance to This Document |
|---|---|
| 4.2 (FR-PR-03) | Per-category notification preferences; user control over what triggers a notification. |
| 4.4 (FR-GR-02, FR-GR-03) | Group invite via shareable link; invite expiry (7 days) and revocability. |
| 4.7 (FR-AC-03) | Push notification triggers: new expense, edit/delete expense, settlement, reminder. |
| 4.7 (FR-AC-04) | Notifications respect per-category preferences. |
| 4.7 (FR-AC-05) | Notification tap deep-links to relevant screen, including cold start. |
| 4.11 (FR-SH-02) | Invite links include deep link with App Store/Play Store fallback. |
| 5.6 | Tap targets (48 x 48 dp), WCAG 2.1 AA contrast, dynamic font scaling, dark mode, screen-reader semantic labels. |
| 6.2 | Visual system tokens (colours, typography, corner radius, elevation, motion). |
| 6.4 | Empty, error, and loading states with actionable copy and "Retry" affordance. |
| 6.5 | Microcopy tone: friendly, concise, lightly playful. |
| 7.3 | Money displayed as rupees at UI layer; stored as integer paise (Invariant 1). |
| Invariant 3 | System share sheet only; no targeting of specific messaging apps. |