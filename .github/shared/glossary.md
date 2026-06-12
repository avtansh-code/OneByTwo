# Glossary

Terms used throughout the One By Two codebase and documentation. Definitions are
consistent with the SRS (docs/OneByTwo_Requirements_Spec.md, section 1.4).

| Term | Definition |
|---|---|
| ADR | Architecture Decision Record — a lightweight document capturing a significant technical decision, its context, and consequences. |
| Activity feed | Chronological per-user log of expense and settlement events. Reminder items are server-written; group-change events are not part of v1.0. |
| App Check | Firebase service that verifies requests originate from a genuine app instance, not a spoofed client. |
| CI/CD | Continuous Integration / Continuous Deployment. |
| Cloud Function | Server-side function running on Firebase Cloud Functions (Node 22 / TypeScript), region-pinned to `asia-south1`. |
| Crashlytics | Firebase crash-reporting service integrated on both iOS and Android. |
| Emulator Suite | Firebase Emulator Suite — local emulation of Auth, Firestore, Functions, and Storage for development and testing. |
| FCM | Firebase Cloud Messaging — used for push notifications. |
| Firestore | Cloud Firestore — Firebase's NoSQL document database and the primary data store for One By Two. |
| Friendship | A one-to-one connection between two users, stored in the `friendships` collection. |
| Group | A multi-member shared context stored in the `groups` collection. In v1.0 the Firestore schema and Security Rules exist, but there is no client UI — groups are **data-layer-only** (planned for Sprint 3). |
| INR / Rupee | Indian Rupee — the only supported currency. Symbol: ₹. |
| MAU | Monthly Active Users. |
| Notifications | The `features/notifications/` client module: FCM token registration, foreground handling, and tap routing. Outbound pushes are sent server-side by the `send*Notification` Cloud Functions, gated by each recipient's `notificationPrefs`. |
| OTP | One-Time Password sent via SMS for phone-number verification. |
| P0 / P1 / P2 | Priority levels: must-have / should-have / nice-to-have. |
| Paise | Sub-unit of the Indian Rupee (1 INR = 100 paise). All money is stored as integer paise. |
| Reminder | A nudge asking a counterparty to settle an outstanding balance. The client (`features/reminders/`) invokes the `sendReminderNotification` callable, which is rate-limited server-side via `_rateLimits`. |
| Remote Config | Firebase Remote Config — used to hold the support email address and feature flags. |
| Riverpod | State management library for Flutter (version 2.x). |
| S1–S4 | Bug severity levels: Critical / Major / Minor / Trivial (SRS section 10.5). |
| Security Rules | Firestore Security Rules that enforce participant-scoped access and the `simplifiedBalances` write restriction. |
| Shell | The `features/shell/` client module: the bottom-navigation scaffold, the central floating action button, and the expense-context selector. |
| Simplified Debts | Algorithm that minimises the number of pairwise transactions needed to settle all balances. The sole debt mechanism in One By Two. |
| `simplifiedBalances` | Denormalised field on `friendships` and `groups` documents. Server-maintained, client-read-only. |
| Split methods | Ways to divide an expense: Equally, Unequal, By Percentage, By Shares, By Exact Amounts. v1.0 enables **Equally** and **By Exact Amounts**; the other methods are defined in the domain enum but not yet enabled. |
| SRS | Software Requirements Specification — the single source of truth (`docs/OneByTwo_Requirements_Spec.md`). |
| System share sheet | Platform-native sharing UI (iOS UIActivityViewController / Android Intent.ACTION_SEND). |
