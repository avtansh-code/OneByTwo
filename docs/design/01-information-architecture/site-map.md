# One By Two — Information Architecture: Site Map

> **Document status:** Draft
> **SRS version:** 1.1
> **Audience:** UX/UI Designer, Solution Architect, Flutter Developer

This document defines the hierarchical screen map, navigation types, route
paths, and deep-link URL scheme for One By Two v1.0. All content is derived from
the authoritative SRS (sections 4, 6.3, 13.1) and the sprint-zero routing
proposal (GoRouter with declarative routes and an auth-guard redirect layer).

---

## 1. Hierarchical Screen Map

The tree below lists every screen in v1.0, organised by authentication state and
tab structure. Indentation denotes parent-child hierarchy.

```
Root
├── Unauthenticated
│   ├── Splash                                   /splash
│   ├── Onboarding (3 illustrated slides)        /onboarding
│   ├── Phone Entry (locked +91 prefix)          /auth/phone
│   ├── OTP Verification                         /auth/otp
│   └── Profile Setup (name, optional photo)     /auth/profile-setup
│
└── Authenticated (Shell with Bottom Navigation + FAB)
    │
    ├── [Tab] Home (Dashboard)                   /home
    │   └── (Inline) Monthly Spend Summary       — rendered within /home
    │
    ├── [Tab] Friends                            /friends
    │   ├── Friends List                         /friends              (tab root)
    │   ├── Add Friend                           /friends/add
    │   ├── Friend Detail                        /friends/:friendshipId
    │   └── Friend History                       /friends/:friendshipId/history
    │
    ├── [Tab] Groups                             /groups
    │   ├── Groups List                          /groups               (tab root)
    │   ├── Create Group                         /groups/create
    │   ├── Group Detail                         /groups/:groupId
    │   ├── Group Invite                         /groups/:groupId/invite
    │   ├── Group Members                        /groups/:groupId/members
    │   └── Group History                        /groups/:groupId/history
    │
    ├── [Tab] Activity (Feed)                    /activity
    │
    ├── [Tab] Profile                            /profile
    │   ├── Profile View / Edit                  /profile              (tab root)
    │   ├── Notification Preferences             /profile/notifications
    │   ├── Contact Support                      /profile/support
    │   └── Account Deletion                     /profile/delete-account
    │
    ├── Modals / Bottom Sheets (overlay, no dedicated route)
    │   ├── Add Expense (multi-step bottom sheet)
    │   ├── Edit Expense (bottom sheet)
    │   ├── Settle Up (bottom sheet)
    │   ├── Delete Confirmation Dialog (expense, friend, group)
    │   └── Sign-Out Confirmation Dialog
    │
    └── Search (overlay or full-screen)          /search
```

### Sources

| Screen cluster             | SRS reference                                      |
| -------------------------- | -------------------------------------------------- |
| Splash, Onboarding         | Section 6.3 item 1; FR-AU-01                       |
| Phone Entry, OTP, Profile  | Section 6.3 items 2-4; FR-AU-01 to FR-AU-06        |
| Home Dashboard             | Section 6.3 item 5; FR-HD-01 to FR-HD-04           |
| Friends                    | Section 6.3 item 6; FR-FR-01 to FR-FR-05           |
| Groups                     | Section 6.3 item 7; FR-GR-01 to FR-GR-07           |
| Add / Edit Expense         | Section 6.3 item 8; FR-EX-01 to FR-EX-09           |
| Settle Up                  | Section 6.3 item 9; FR-SE-01 to FR-SE-08           |
| Activity Feed              | Section 6.3 item 10; FR-AC-01 to FR-AC-05          |
| Profile and Settings       | Section 6.3 item 11; FR-PR-01 to FR-PR-05, FR-AU-08, FR-AU-09 |
| Search                     | FR-SR-01, FR-SR-02                                 |
| Sharing (system share sheet) | FR-SH-01, FR-SH-02 (no dedicated screen; OS-level) |

---

## 2. Navigation Types

Each row describes a user-initiated transition, the navigation mechanism used,
and the GoRouter behaviour.

### 2.1 Unauthenticated Flow

| From                  | To                    | Type        | Notes                                                                                          |
| --------------------- | --------------------- | ----------- | ---------------------------------------------------------------------------------------------- |
| App launch (cold)     | Splash                | —           | Initial route. Auth state check begins here.                                                   |
| Splash                | Onboarding            | `replace`   | Shown only on first install (local flag). Replaces splash so back-button exits the app.        |
| Splash                | Phone Entry            | `replace`   | Returning user who has not completed login. Replaces splash.                                   |
| Splash                | Home                  | `replace`   | Authenticated user with existing profile (FR-AU-07 auto-login). Redirect via auth guard.       |
| Onboarding (slide 3)  | Phone Entry            | `replace`   | Completes onboarding; replaces so user cannot swipe back to slides.                            |
| Phone Entry            | OTP Verification       | `push`      | User can press back to correct their phone number (sprint-zero routing proposal).              |
| OTP Verification       | Profile Setup          | `replace`   | First-time user (no `users/{userId}` doc). Replaces so back does not return to OTP.            |
| OTP Verification       | Home                  | `replace`   | Returning user (existing profile). Redirect via auth guard (FR-AU-07).                         |
| Profile Setup          | Home                  | `replace`   | After saving display name. Replaces so back does not return to setup.                          |

### 2.2 Authenticated — Tab Switches

| From       | To         | Type  | Notes                                                        |
| ---------- | ---------- | ----- | ------------------------------------------------------------ |
| Any tab    | Any tab    | `tab` | Bottom navigation bar switch. Each tab maintains its own navigation stack. No push/pop. |

### 2.3 Authenticated — Within Tabs (Push Navigations)

| From               | To                        | Type   | Notes                                                       |
| ------------------ | ------------------------- | ------ | ----------------------------------------------------------- |
| Friends List       | Add Friend                | `push` | Contact picker or manual +91 entry (FR-FR-01).              |
| Friends List       | Friend Detail             | `push` | Shows net balance and transaction list (FR-FR-03).          |
| Friend Detail      | Friend History            | `push` | Reverse-chronological expense and settlement log (FR-FR-04).|
| Groups List        | Create Group              | `push` | Name, type, optional cover photo (FR-GR-01).                |
| Groups List        | Group Detail              | `push` | Expenses, member balances, activity (FR-GR-04).             |
| Group Detail       | Group Invite              | `push` | Contact picker, +91 entry, or share-link via system share sheet (FR-GR-02). |
| Group Detail       | Group Members             | `push` | Member list with balances; admin actions (FR-GR-05).        |
| Group Detail       | Group History             | `push` | Chronological group activity log.                           |
| Profile            | Notification Preferences  | `push` | Per-category toggles (FR-PR-03).                            |
| Profile            | Contact Support           | `push` | Opens `mailto:` link or fallback copy dialog (FR-SH-03, FR-SH-04). |
| Profile            | Account Deletion          | `push` | Confirmation flow; triggers Cloud Function (FR-AU-09).      |
| Activity Feed      | Expense / Friend / Group  | `push` | Deep-link to relevant detail screen (FR-AC-02).             |
| Search             | Expense / Friend / Group  | `push` | Navigate to matching result detail.                         |

### 2.4 Authenticated — Modals and Bottom Sheets

| Trigger                          | Overlay                    | Type    | Notes                                                      |
| -------------------------------- | -------------------------- | ------- | ---------------------------------------------------------- |
| FAB (any tab)                    | Add Expense (bottom sheet) | `modal` | Multi-step: amount, split method, category (FR-EX-01, FR-HD-04). |
| Expense row tap (in detail view) | Edit Expense (bottom sheet)| `modal` | Pre-filled with existing data (FR-EX-06).                  |
| "Settle Up" CTA                  | Settle Up (bottom sheet)   | `modal` | Pre-filled recipient and amount from simplified debts (FR-SE-05, FR-SE-07). |
| Delete expense action            | Delete Confirmation dialog | `modal` | Destructive action guard (FR-EX-06).                       |
| Delete friend action             | Delete Confirmation dialog | `modal` | Blocked if outstanding balance (FR-FR-05).                 |
| Delete group action              | Delete Confirmation dialog | `modal` | Blocked if any member balance is non-zero (FR-GR-07).      |
| "Sign Out" tap                   | Sign-Out Confirmation      | `modal` | Confirmation dialog; clears session on confirm (FR-AU-08). |

### 2.5 Auth Guard Redirects

| Condition                                          | Redirect target | Type       | SRS reference |
| -------------------------------------------------- | --------------- | ---------- | ------------- |
| Unauthenticated user attempts to access any `/home`, `/friends`, `/groups`, `/activity`, `/profile`, or deep-link route | `/auth/phone`   | `redirect` | FR-AU-07      |
| Authenticated user attempts to access `/auth/*`    | `/home`         | `redirect` | FR-AU-07      |
| Authenticated first-time user (no profile doc)     | `/auth/profile-setup` | `redirect` | FR-AU-06 |

---

## 3. Deep-Link URL Scheme

Deep links enable navigation from push notifications (FR-AC-05) and from shared
invite links (FR-SH-02). The app registers as a handler for universal links
(iOS) and App Links (Android).

### 3.1 Notification Deep-Link Destinations

Per FR-AC-03 and FR-AC-05, tapping a notification shall navigate the user to the
relevant screen, including from a cold start. The following URL patterns are
supported:

| URL pattern                              | Destination screen     | Trigger notification type                     | SRS reference       |
| ---------------------------------------- | ---------------------- | --------------------------------------------- | ------------------- |
| `/expense/:expenseId`                    | Expense detail view    | New expense, expense edited, expense deleted  | FR-AC-03, FR-AC-05  |
| `/friend/:friendshipId`                  | Friend Detail          | Friend activity, settlement received          | FR-AC-02, FR-AC-05  |
| `/group/:groupId`                        | Group Detail           | Group changes (member added/removed)          | FR-AC-02, FR-AC-05  |
| `/group/:groupId/expense/:expenseId`     | Expense detail (group) | New group expense, group expense edited       | FR-AC-03, FR-AC-05  |
| `/settle/:settlementId`                  | Settlement detail view | Settlement recorded                           | FR-AC-03, FR-AC-05  |
| `/activity`                              | Activity Feed tab      | Generic activity notification, reminders      | FR-AC-01, FR-AC-05  |

### 3.2 Shared / Invite Deep-Link Destinations

Per FR-SH-02, shared messages include a deep link. On a device where the app is
installed, these resolve to in-app screens. On a device without the app, they
fall back to the App Store or Play Store listing.

| URL pattern                              | Destination screen     | SRS reference       |
| ---------------------------------------- | ---------------------- | ------------------- |
| `/invite/group/:inviteCode`              | Group Detail (join)    | FR-GR-02, FR-GR-03, FR-SH-02 |
| `/invite/friend/:referralCode`           | Add Friend (pre-fill)  | FR-FR-02, FR-SH-02  |

### 3.3 Fallback Behaviour

When a deep-linked entity does not exist or the user lacks access, the app shall
degrade gracefully. This satisfies SRS section 6.4 (every screen shall have
explicit error states with actionable copy).

| Condition                                              | Behaviour                                                                                                 |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| Entity not found (e.g., deleted expense, expired invite) | Display an inline error message ("This item is no longer available") and navigate to the parent screen.  |
| Parent resolution: `/expense/:id` not found            | Navigate to `/activity` (Activity Feed).                                                                  |
| Parent resolution: `/friend/:id` not found             | Navigate to `/friends` (Friends List).                                                                    |
| Parent resolution: `/group/:id` not found              | Navigate to `/groups` (Groups List).                                                                      |
| Parent resolution: `/group/:gid/expense/:eid` not found | Navigate to `/groups/:gid` if the group exists; otherwise navigate to `/groups`.                         |
| Parent resolution: `/settle/:id` not found             | Navigate to `/activity` (Activity Feed).                                                                  |
| Parent resolution: `/invite/group/:code` expired or revoked | Display "This invite link has expired" with a dismiss action; navigate to `/groups`.                  |
| User is unauthenticated                                | Auth guard redirects to `/auth/phone`; after successful login, the original deep-link destination is restored and the user is forwarded there (FR-AC-05 — "even from a cold start"). |

### 3.4 Universal Link / App Link Format

The production deep-link domain follows the pattern:

```
https://onebytwo.app/<path>
```

For example:
- `https://onebytwo.app/group/abc123` resolves to Group Detail for group `abc123`.
- `https://onebytwo.app/invite/group/xyz789` resolves to the group join flow.

Fallback URLs for devices without the app installed (FR-SH-02):
- iOS: `https://apps.apple.com/app/one-by-two/<appId>`
- Android: `https://play.google.com/store/apps/details?id=<packageName>`

---

## 4. Complete Route Table

For developer reference, the following table consolidates every named route in
the GoRouter configuration, aligned with the feature-first folder structure
(SRS section 13.1).

| Route path                             | Screen name              | Feature module    | Auth required |
| -------------------------------------- | ------------------------ | ----------------- | ------------- |
| `/splash`                              | Splash                   | `auth`            | No            |
| `/onboarding`                          | Onboarding               | `auth`            | No            |
| `/auth/phone`                          | Phone Entry              | `auth`            | No            |
| `/auth/otp`                            | OTP Verification         | `auth`            | No            |
| `/auth/profile-setup`                  | Profile Setup            | `auth`            | Yes (new user)|
| `/home`                                | Home Dashboard           | `app` (shell)     | Yes           |
| `/friends`                             | Friends List             | `friends`         | Yes           |
| `/friends/add`                         | Add Friend               | `friends`         | Yes           |
| `/friends/:friendshipId`               | Friend Detail            | `friends`         | Yes           |
| `/friends/:friendshipId/history`       | Friend History           | `friends`         | Yes           |
| `/groups`                              | Groups List              | `groups`          | Yes           |
| `/groups/create`                       | Create Group             | `groups`          | Yes           |
| `/groups/:groupId`                     | Group Detail             | `groups`          | Yes           |
| `/groups/:groupId/invite`              | Group Invite             | `groups`          | Yes           |
| `/groups/:groupId/members`             | Group Members            | `groups`          | Yes           |
| `/groups/:groupId/history`             | Group History            | `groups`          | Yes           |
| `/activity`                            | Activity Feed            | `activity`        | Yes           |
| `/profile`                             | Profile View / Edit      | `profile`         | Yes           |
| `/profile/notifications`               | Notification Preferences | `profile`         | Yes           |
| `/profile/support`                     | Contact Support          | `profile`         | Yes           |
| `/profile/delete-account`              | Account Deletion         | `profile`         | Yes           |
| `/search`                              | Search                   | `app` (shell)     | Yes           |
| `/expense/:expenseId`                  | Expense Detail           | `expenses`        | Yes           |
| `/settle/:settlementId`               | Settlement Detail        | `settlements`     | Yes           |
| `/invite/group/:inviteCode`            | Group Join               | `groups`          | Yes           |
| `/invite/friend/:referralCode`         | Friend Add (pre-fill)    | `friends`         | Yes           |

---

## 5. Notes and Constraints

1. **System share sheet only (Invariant 3).** The Group Invite and Add Friend
   screens surface outbound links exclusively via the platform system share
   sheet. No specific messaging app is targeted (SRS sections 3.4, 4.11, 12.2;
   FR-SH-01).

2. **Simplified balances are read-only on the client (Invariant 2).** Screens
   that display balances (Home Dashboard, Friend Detail, Group Detail, Settle Up)
   read from the `simplifiedBalances` field. They never write to it (SRS
   sections 4.6, 7.3, 7.5).

3. **Money displayed in rupees, stored in paise (Invariant 1).** All balance and
   amount values shown on screens are formatted in the Indian numbering system
   with the rupee symbol (FR-EX-09). Conversion from integer paise to display
   rupees occurs at the UI layer only.

4. **Offline viewing (FR-OF-01).** All list and detail screens must render from
   the Firestore local cache when the device is offline. The navigation graph
   does not change; only write operations are queued.

5. **Empty, error, and loading states (SRS section 6.4).** Every screen in this
   map must implement explicit empty, loading (skeleton preferred), and error
   states with a "Retry" affordance and a path to Contact Support.

6. **Invite link expiry (FR-GR-03).** Group invite links expire after 7 days and
   are revocable by the group admin. The deep-link handler must check validity
   server-side before presenting the join flow.

---

*End of document.*
