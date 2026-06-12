# Push Notifications -- Technical Design

**SRS version:** 1.1
**Primary requirements:** FR-AC-03, FR-AC-04, FR-AC-05 (SRS section 4.7),
FR-SE-09 (SRS section 4.6), FR-PR-03 (SRS section 4.2).
**Cross-references:** `docs/design/04-wireframes/notifications-and-deeplinks.md`,
`docs/design/03-architecture/data-flow.md`,
`docs/design/01-information-architecture/navigation-flow.md`.

---

## 1. FCM Token Lifecycle

### 1.1 Acquisition

The client acquires an FCM registration token from Firebase Cloud Messaging
immediately after the user completes phone authentication (FR-AU-07, SRS
section 4.1) and grants push notification permission. Token acquisition does
not occur at app launch or during onboarding; it is deferred until the custom
pre-permission dialog is accepted (see section 5 below and wireframes document
section 1).

### 1.2 Storage

Tokens are stored as a `string[]` array on the user's Firestore document at
`users/{userId}.fcmTokens` (SRS section 7.2). The array supports multi-device
usage: a single user may be signed in on more than one phone or tablet
simultaneously, and each device holds a distinct FCM token.

When a new token is acquired, the client writes it using a Firestore
`arrayUnion` operation. This is idempotent -- re-adding an existing token is
a no-op.

### 1.3 Refresh

The client registers an `onTokenRefresh` listener at app startup. When FCM
rotates the token (which may happen at any time at the platform's discretion),
the listener:

1. Removes the previous token from the `fcmTokens` array via `arrayRemove`.
2. Adds the new token via `arrayUnion`.

Both operations execute in a single batched write to avoid a window where no
valid token exists.

### 1.4 Cleanup

Stale tokens are removed in two circumstances:

| Trigger | Action | Responsible layer |
|---|---|---|
| **User signs out** | The client removes its current device token from `fcmTokens` via `arrayRemove` before calling `FirebaseAuth.signOut()`. | Flutter client |
| **FCM 410 / `NotRegistered` response** | When a Cloud Function attempts to send a message and receives a `messaging/registration-token-not-registered` error (HTTP 410), it removes the offending token from the user's `fcmTokens` array. | Cloud Function (server-side) |

This ensures the array does not accumulate defunct tokens over time.

---

## 2. Notification Payload Schema

All notifications are sent as **data-only messages** (no `notification` block in
the FCM payload). The client is responsible for constructing the system
notification when the app is in the background, and for rendering an in-app
banner when the app is in the foreground. This gives full control over
presentation and deep-link handling on both platforms.

### 2.1 Common Envelope

Every notification payload conforms to the following envelope:

```json
{
  "data": {
    "type":        "<notification_type>",
    "contextType": "friendship" | "group",
    "contextId":   "<Firestore document ID>",
    "itemId":      "<expense or settlement ID, optional>",
    "inviteToken": "<invite token, optional>",
    "title":       "<rendered title string>",
    "body":        "<rendered body string>",
    "senderName":  "<display name of the acting user>",
    "amountPaise": "<integer amount in paise, optional>",
    "createdAt":   "<ISO 8601 timestamp>"
  },
  "android": {
    "priority": "high"
  },
  "apns": {
    "headers": {
      "apns-priority": "10"
    },
    "payload": {
      "aps": {
        "content-available": 1
      }
    }
  }
}
```

All data values are strings (FCM data payload constraint). The client parses
numeric fields after receipt.

### 2.2 Per-Type Definitions

The `title` and `body` fields are rendered server-side by `renderPayload`
(`functions/src/notifications/payload-renderer.ts`) using the templates below.
Amounts are converted from integer paise to a rupee display string by
`formatInrFromPaise` (`functions/src/utils/format-inr.ts`) — integer rupees only,
with the `₹` symbol and Indian-numbering grouping (e.g. 120000 paise becomes
`₹1,200`) — before insertion into the template. This keeps the client presentation
layer thin.

| Notification Type (`type` value) | Title Template | Body Template | Required Data Fields | Priority |
|---|---|---|---|---|
| `expense_added` | "{senderName} added an expense" | "{description} -- {₹amount}." | `contextType`, `contextId`, `itemId`, `senderName`, `amountPaise` | High |
| `expense_edited` | "{senderName} edited an expense" | "{description} was updated to {₹amount}." | `contextType`, `contextId`, `itemId`, `senderName`, `amountPaise` | High |
| `expense_deleted` | "{senderName} deleted an expense" | "{description} ({₹amount}) was removed." | `contextType`, `contextId`, `senderName`, `amountPaise` (`itemId` optional) | High |
| `settlement_received` | "{senderName} settled up" | "You received {₹amount}." | `contextType`, `contextId`, `itemId`, `senderName`, `amountPaise` | High |
| `reminder` | "Reminder from {senderName}" | "{senderName} is nudging you about {₹amount}." | `contextType`, `contextId`, `senderName`, `amountPaise` | High |
| `group_invite` | "{senderName} invited you to a group" | "Join \"{groupName}\" to start splitting." | `contextId`, `inviteToken`, `senderName`, `groupName` | High |

`{₹amount}` denotes the output of `formatInrFromPaise(amountPaise)`. The
`group_invite` template carries no monetary value and omits `amountPaise`.

All six types use **high priority** because they are user-visible and
time-sensitive (SRS section 4.7, FR-AC-03).

### 2.3 Notification Preferences Filter

Before sending, the Cloud Function checks the recipient's `notificationPrefs`
map on `users/{userId}` (SRS section 7.2). The map contains boolean flags:

```
notificationPrefs: {
  newExpense:  bool,   // gates expense_added, expense_edited, expense_deleted
  settlement:  bool,   // gates settlement_received
  reminder:    bool    // gates reminder
}
```

If the relevant flag is `false`, the notification is suppressed. Group invite
notifications are not subject to preference filtering -- they are always
delivered (FR-GR-02). This satisfies FR-AC-04 (SRS section 4.7).

The filter is implemented by `isNotificationAllowed(type, prefs)` in
`functions/src/notifications/prefs-filter.ts`. A missing `notificationPrefs` map, or
a missing individual flag, defaults to **allowed** (the function tests `flag !==
false`), mirroring the FR-AU-06 schema default.

### 2.4 Server-Side Module (`functions/src/notifications/`)

The notification logic is a **shared module, not a deployed Cloud Function**. It is
consumed by the `sendReminderNotification` callable and by the
`onExpenseWriteFriendship` and `onSettlementWrite` triggers, which inject it as the
optional `notificationsApi` dependency.

Public surface (`functions/src/notifications/index.ts`, the `NotificationsApi`):

- `sendExpenseNotification` — fans out to all non-author members of a friendship.
- `sendSettlementNotification` — notifies only the payee (`toUserId`).
- `sendReminderNotification` — notifies the friend who owes the sender.

Each high-level dispatcher reads the recipient `users/{uid}` document, applies
`isNotificationAllowed`, renders the payload via `renderPayload`, and dispatches via
the low-level leaf:

- `sendFcmToTokens` (`fcm-send.ts`) sends **one `messaging.send(...)` call per
  token** in parallel via `Promise.allSettled` (the deprecated `sendMulticast` is
  not used). A token rejected with `messaging/registration-token-not-registered`
  (HTTP 410) is pruned from the user's `fcmTokens` array via
  `FieldValue.arrayRemove`. The constructed message is data-only with
  `android.priority: "high"` and `apns` `apns-priority: 10` / `content-available: 1`
  (matching section 2.1).
- PII in logs: the recipient `userId` is hashed via `hashId` (16 hex), and raw FCM
  tokens are never logged — only an 8-hex `fingerprintToken` value is logged for
  correlation.

---

## 3. Foreground vs Background Handling

### 3.1 Foreground -- In-App Banner

When the app is in the foreground and a data message arrives via FCM:

1. The client's `onMessage` handler receives the payload.
2. It checks the user's local notification preferences (mirrored from
   Firestore). If the category is disabled (FR-AC-04), the message is
   silently dropped.
3. If enabled, the client renders a custom in-app banner (not a system
   notification). The banner slides down from the top of the screen with a
   300 ms ease-in-out animation and auto-dismisses after 4 seconds. Visual
   specifications are defined in the wireframes document, section 2.
4. Tapping the banner navigates to the deep-link destination per section 4.

No system notification is shown while the app is in the foreground. This avoids
duplicate alerts and keeps the user within the app context.

### 3.2 Background -- System Notification

When the app is backgrounded or suspended:

1. The `onBackgroundMessage` handler receives the data payload.
2. The handler constructs a local notification using the `title` and `body`
   fields from the payload and displays it via the system notification tray.
3. The notification payload is attached to the notification's data bundle so
   that deep-link resolution can occur when the user taps it.

Visual rendering of background notifications is controlled by the operating
system. Dark mode styling is inherited from OS-level preferences (wireframes
document, section 3.4).

### 3.3 Cold Start -- Terminated App

When the user taps a notification while the app is fully terminated:

1. The OS launches the app with the notification payload attached.
2. The splash screen is displayed (maximum 2 seconds) while Firebase Auth
   restores the persisted session (FR-AU-07, SRS section 4.1).
3. The GoRouter auth guard checks authentication state:
   - **Authenticated:** the deep-link intent is resolved immediately and the
     user is navigated to the target screen.
   - **Not authenticated:** the deep-link intent is stored in memory. The user
     is directed to the phone authentication flow. Upon successful sign-in,
     GoRouter replays the stored deep-link (FR-AC-05).
4. If the target entity no longer exists (Firestore returns not-found), the
   entity-not-found error dialog is shown and the user is navigated to the
   fallback destination (wireframes document, section 4.3).

This satisfies FR-AC-05: "Tapping a notification shall deep-link the user to
the relevant screen, even from a cold start" (SRS section 4.7).

---

## 4. Deep-Link Map

The following table defines the complete mapping from notification type to data
fields, destination route, and fallback behaviour. It aligns with the payload
schema in section 6 of the wireframes document and the route definitions in
`navigation-flow.md`.

| Notification Type | Data Fields | Destination Route | Fallback (entity missing) |
|---|---|---|---|
| `expense_added` | `type`, `contextType`, `contextId`, `itemId` | `/group/:contextId/expense/:itemId` (group) or `/friend/:contextId/expense/:itemId` (friendship) | `/home` |
| `expense_edited` | `type`, `contextType`, `contextId`, `itemId` | `/group/:contextId/expense/:itemId` (group) or `/friend/:contextId/expense/:itemId` (friendship) | `/home` |
| `expense_deleted` | `type`, `contextType`, `contextId` | `/group/:contextId` (group) or `/friend/:contextId` (friendship). No `itemId` -- the expense has been soft-deleted. | `/home` |
| `settlement_received` | `type`, `contextType`, `contextId`, `itemId` | `/friend/:contextId` (friendship) or `/group/:contextId` (group) | `/home` |
| `reminder` | `type`, `contextType: "friendship"`, `contextId` | `/friend/:contextId` | `/home` |
| `group_invite` | `type`, `contextId`, `inviteToken` | `/invite/group/:inviteToken` | `/home` |

### 4.1 Resolution Logic

1. GoRouter `redirect` executes the auth guard (see section 3.3).
2. The route resolver reads the `type` field to determine the target route.
3. If `contextType` is `"group"`, the route resolves to a `/group/`-prefixed
   path; if `"friendship"`, to a `/friend/`-prefixed path.
4. If the target Firestore document does not exist, the entity-not-found error
   dialog is shown (wireframes document, section 4.3) and the user is navigated
   to the fallback destination.
5. If the payload is malformed or missing required fields, the user is navigated
   to `/home`.

### 4.2 Entity-Not-Found Fallback Detail

For finer-grained fallback behaviour (e.g., navigating to the parent group
rather than `/home` when a group expense is missing but the group still exists),
the following extended fallback rules from the wireframes document section 4
apply:

| Missing Entity | Fallback Destination |
|---|---|
| `/expense/:id` not found | `/activity` (Activity Feed) |
| `/friend/:id` not found | `/friends` (Friends List) |
| `/group/:id` not found | `/groups` (Groups List) |
| `/group/:gid/expense/:eid` not found | `/group/:gid` if group exists; otherwise `/groups` |
| `/settle/:id` not found | `/activity` (Activity Feed) |
| `/invite/group/:code` expired or revoked | `/groups` (Groups List) |

---

## 5. Permission Prompt Timing

### 5.1 When to Prompt

The push notification permission prompt is shown **after the user completes
profile setup and lands on the Home dashboard for the first time** (SRS
section 6.3, screen 4; wireframes document, section 1). It is explicitly
**not** shown at app launch or during onboarding slides. This follows the
principle of requesting permission after the user understands the app's value
proposition (SRS section 5.6).

### 5.2 Custom Pre-Permission Dialog

Before triggering the native OS permission prompt (`requestAuthorization` on
iOS, `POST_NOTIFICATIONS` on Android 13+), the app displays a custom dialog
explaining the benefit of enabling notifications. This dialog:

- Uses the heading "Stay in the loop" and body copy "Get notified when friends
  add expenses or settle up. You can change this any time in Settings."
- Offers two actions: "Enable Notifications" (primary) and "Not now"
  (secondary text button).
- Does not re-appear in the same session if dismissed. A local flag tracks
  whether the dialog has been shown.

If the user taps "Enable Notifications", the native OS prompt is triggered.
If the user taps "Not now" (or dismisses via back gesture or scrim tap), no
OS prompt is shown and no FCM token is acquired.

### 5.3 Handling Denied Permission

If the user denies the OS-level permission prompt:

1. No FCM token is registered on the Firestore document.
2. The denial is recorded locally so the pre-permission dialog is not shown
   again automatically.
3. The user may enable notifications at any time from the notification
   preferences screen at `/profile/notifications` (FR-PR-03, SRS section 4.2).
   If the OS-level permission has been permanently denied, the app directs the
   user to the system settings page for the app.

---

## 6. Rate Limiting

### 6.1 Reminder Notifications

Reminder notifications are rate-limited to **one reminder per friend per 24
hours** (FR-SE-09, SRS section 4.6). This limit is enforced entirely
server-side in the `sendReminderNotification` callable
(`functions/src/send-reminder-notification/function.ts`).

**Enforcement mechanism:**

1. The rate-limit state is stored at `_rateLimits/{senderUid}/sends/{recipientUid}`
   (one document per sender/recipient pair), holding `lastSentAt`, `windowStart`,
   and `count`. The window length is `REMINDER_WINDOW_MS` (24 hours).
2. Before dispatching, the function reads this document. If `lastSentAt` is within
   the last 24 hours, it throws `HttpsError('resource-exhausted', …, { errorCode:
   'RATE_LIMITED', nextAllowedAtIso })`, where `nextAllowedAtIso` is the ISO 8601
   instant after which the next reminder is allowed. The client surfaces a
   user-facing message derived from this.
3. Otherwise the function dispatches the FCM notification, then writes the rate-limit
   record, writes a recipient-only activity-feed item at
   `activity/{recipientUid}/items/{auto-id}` (fire-and-forget), and returns
   `{ success: true, nextAllowedAtIso }`. If FCM dispatch fails for all of the
   recipient's tokens, the function throws `FCM_DISPATCH_FAILED` (`unavailable`) and
   the rate-limit record is **not** written, so the sender may retry.

The reminder also enforces preconditions before the rate-limit check: the caller
must be a member of the context (`NOT_A_MEMBER` otherwise), and the recipient must
owe the caller per `simplifiedBalances[recipientUid][senderUid]`
(`RECIPIENT_DOESNT_OWE` otherwise). Group contexts are rejected with
`GROUP_CONTEXT_NOT_SUPPORTED`. See
`docs/design/07-technical/cloud-functions-error-codes.md` for the full list.

The client displays the server error message inline. The rate limit is not
enforced client-side (the client may optimistically disable the "Send Reminder"
button based on local state, but the server is the authoritative gate).

### 6.2 General Notification Volume

No per-user rate limiting is applied to non-reminder notification types in
v1.0. Expense and settlement notifications are triggered by discrete user
actions and are therefore naturally bounded. Should notification volume become
a concern, per-user throttling or batching (e.g., "3 new expenses in Group X")
may be introduced in a future version -- this is noted as an extension point
in the wireframes document, section 8.

---

## 7. Security Considerations

### 7.1 Token Confidentiality

FCM tokens are sensitive credentials. The `fcmTokens` field on
`users/{userId}` must be readable and writable only by the owning user.
Firestore Security Rules enforce this:

```
match /users/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow update: if request.auth != null && request.auth.uid == userId;
}
```

Cloud Functions (running with admin credentials) bypass Security Rules and
may read any user's `fcmTokens` to dispatch notifications.

### 7.2 Notification Content

Notification payloads must not contain sensitive financial details beyond the
minimum required for the notification templates (amount and description).
Full expense breakdowns, split details, and balance summaries are never
included in the push payload -- they are fetched from Firestore after the
user opens the app and navigates to the target screen.

---

## 8. SRS Cross-References

| SRS Section | Relevance |
|---|---|
| 4.1 (FR-AU-07) | Persisted auth session; cold-start deep-link depends on session restoration. |
| 4.2 (FR-PR-03) | Per-category notification preferences control which notifications are delivered. |
| 4.6 (FR-SE-09) | Reminder rate limit: one per friend per 24 hours. |
| 4.7 (FR-AC-03) | Push notification triggers: new expense, edit/delete expense, settlement, reminder. |
| 4.7 (FR-AC-04) | Notifications respect per-category user preferences. |
| 4.7 (FR-AC-05) | Notification tap deep-links to relevant screen, including cold start. |
| 7.2 | `fcmTokens: string[]` and `notificationPrefs` map on `users/{userId}`. |
| 7.3 | Money stored as integer paise; conversion to rupees at UI/notification layer. |
