# Glossary

Terms used throughout the OneByTwo codebase and documentation. Definitions are
consistent with the SRS (docs/OneByTwo_Requirements_Spec.md, section 1.4).

| Term | Definition |
|---|---|
| ADR | Architecture Decision Record — a lightweight document capturing a significant technical decision, its context, and consequences. |
| Activity feed | Chronological log of all events (expenses, settlements, group changes) involving a user. |
| App Check | Firebase service that verifies requests originate from a genuine app instance, not a spoofed client. |
| CI/CD | Continuous Integration / Continuous Deployment. |
| Cloud Function | Server-side function running on Firebase Cloud Functions (Node 20 / TypeScript), region-pinned to `asia-south1`. |
| Crashlytics | Firebase crash-reporting service integrated on both iOS and Android. |
| Emulator Suite | Firebase Emulator Suite — local emulation of Auth, Firestore, Functions, and Storage for development and testing. |
| FCM | Firebase Cloud Messaging — used for push notifications. |
| Firestore | Cloud Firestore — Firebase's NoSQL document database and the primary data store for OneByTwo. |
| Friendship | A one-to-one connection between two users, stored in the `friendships` collection. |
| INR / Rupee | Indian Rupee — the only supported currency. Symbol: ₹. |
| MAU | Monthly Active Users. |
| OTP | One-Time Password sent via SMS for phone-number verification. |
| P0 / P1 / P2 | Priority levels: must-have / should-have / nice-to-have. |
| Paise | Sub-unit of the Indian Rupee (1 INR = 100 paise). All money is stored as integer paise. |
| Remote Config | Firebase Remote Config — used to hold the support email address and feature flags. |
| Riverpod | State management library for Flutter (version 2.x). |
| S1–S4 | Bug severity levels: Critical / Major / Minor / Trivial (SRS section 10.5). |
| Security Rules | Firestore Security Rules that enforce participant-scoped access and the `simplifiedBalances` write restriction. |
| Simplified Debts | Algorithm that minimises the number of pairwise transactions needed to settle all balances. The sole debt mechanism in OneByTwo. |
| `simplifiedBalances` | Denormalised field on `friendships` and `groups` documents. Server-maintained, client-read-only. |
| Split methods | Ways to divide an expense: Equally, Unequal, By Percentage, By Shares, By Exact Amounts. |
| SRS | Software Requirements Specification — the single source of truth (`docs/OneByTwo_Requirements_Spec.md`). |
| System share sheet | Platform-native sharing UI (iOS UIActivityViewController / Android Intent.ACTION_SEND). |
