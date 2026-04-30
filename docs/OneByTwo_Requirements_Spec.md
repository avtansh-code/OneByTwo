# One By Two

> **Split it. Settle it. Simple.**

**Software Requirements Specification**
Expense Sharing Mobile Application for India

| Field | Value |
|---|---|
| Document Version | 1.1 |
| Status | Approved baseline for AI Agent Team execution |
| Platform | iOS & Android (Flutter) |
| Backend | Google Firebase (single production project) |
| Target Market | India (₹ INR only, +91 phone numbers) |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [AI Agent Team Structure & Responsibilities](#2-ai-agent-team-structure--responsibilities)
3. [Overall Description](#3-overall-description)
4. [Functional Requirements](#4-functional-requirements)
5. [Non-Functional Requirements](#5-non-functional-requirements)
6. [User Experience & Design Requirements](#6-user-experience--design-requirements)
7. [Architecture & Data Model](#7-architecture--data-model)
8. [Development Workflow & Local Testing](#8-development-workflow--local-testing)
9. [CI/CD & Deployment](#9-cicd--deployment)
10. [Quality Assurance Strategy](#10-quality-assurance-strategy)
11. [Release Plan](#11-release-plan)
12. [Risks, Assumptions & Resolved Decisions](#12-risks-assumptions--resolved-decisions)
13. [Appendices](#13-appendices)

---

## 1. Introduction

### 1.1 Purpose

This Software Requirements Specification (SRS) describes the functional and non-functional requirements for **One By Two**, an expense-sharing mobile application built for the Indian market. The document is the single source of truth that an AI agent team — composed of Product Managers, Architects, Developers, QA Engineers, and DevOps Engineers — will use to design, build, test, and ship the product. Each section is structured so that role-specialised agents can extract the inputs they need without ambiguity.

### 1.2 Product Vision

One By Two helps friends, flatmates, families, and groups in India track shared expenses and settle balances effortlessly. Inspired by category leaders such as Splitwise, the product is reimagined for India-first usage with rupee-only accounting, +91 phone-number authentication, and a clean, modern visual language designed for everyday use across iOS and Android.

### 1.3 Scope

One By Two, version 1.0, will deliver the following capabilities:

- Phone-number based authentication (OTP) restricted to +91 country code.
- One-to-one and group expense tracking with multiple split methods.
- Real-time balance calculation using **Simplified Debts** as the only and default debt mechanism.
- Settlement recording and a chronological activity feed.
- Friend and group management with invitations via the **system share sheet** and contacts.
- Push notifications for expenses, settlements, and reminders.
- Offline-tolerant data entry with automatic sync when connectivity returns.
- Modern, India-first UI/UX optimised for mobile devices.
- In-app **mailto:** support link for user help.

**Out of scope for v1.0:** integrated payments (UPI / payment gateway redirection), multi-currency support, web/desktop clients, in-app advertising, AI-driven expense suggestions, raw "who paid whom" debt graphs (replaced by Simplified Debts), and helpdesk-platform integration. These may be considered for future releases.

### 1.4 Definitions, Acronyms, and Abbreviations

| Term | Definition |
|---|---|
| OTP | One-Time Password sent over SMS for phone-number verification |
| MAU | Monthly Active Users |
| SRS | Software Requirements Specification (this document) |
| FR | Functional Requirement |
| NFR | Non-Functional Requirement |
| RTDB / Firestore | Cloud Firestore — Firebase's NoSQL document database |
| FCM | Firebase Cloud Messaging |
| CI/CD | Continuous Integration / Continuous Deployment |
| P0 / P1 / P2 | Priority levels: must-have / should-have / nice-to-have |
| INR / ₹ | Indian Rupee — the only supported currency |
| Simplified Debts | An algorithm that minimises the number of pairwise transactions required to settle all balances within a group or friendship context. **In One By Two, this is the only debt-tracking mechanism.** |

### 1.5 Intended Audience

This document is written for the AI agent team (PM, Architect, Devs, QA, DevOps) and any human stakeholders reviewing or auditing their work. Each agent role should treat the sections most relevant to their responsibilities as authoritative inputs to their tasks.

---

## 2. AI Agent Team Structure & Responsibilities

One By Two is to be built by a coordinated set of AI agents, each playing a distinct role. The following table defines the responsibilities and the primary deliverables expected from every role. The agents are expected to collaborate iteratively: PM defines, Architect designs, Devs implement, QA validates, and DevOps releases.

| Role | Primary Responsibilities | Key Deliverables |
|---|---|---|
| **Product Manager (PM)** | Translates this SRS into prioritised user stories and acceptance criteria; manages the backlog; owns scope decisions. | User stories, acceptance criteria, sprint backlog, release notes |
| **Solution Architect** | Designs system architecture, data model, security model, and integration boundaries; reviews technical decisions. | Architecture diagram, Firestore schema, security rules, ADRs |
| **Flutter Developer (Mobile)** | Implements iOS and Android UI, state management, offline support, and Firebase SDK integrations. | Flutter code, widget tests, build artifacts (.ipa, .apk, .aab) |
| **Backend / Cloud Functions Developer** | Implements Cloud Functions for business logic that should not run on the client (e.g., simplified-debts computation, group invites, account deletion). | Cloud Functions code, integration tests, function deployment scripts |
| **QA Engineer** | Owns the test plan, writes automated and manual test cases, validates UAT, and signs off releases. | Test plan, test cases, automation suite, bug reports, release sign-off |
| **DevOps Engineer** | Owns local emulator setup, GitHub Actions pipelines, secrets management, store credentials, and Firebase deployments. | GitHub workflows, Fastlane configs, signing setup, deploy runbooks |
| **UX / UI Designer Agent** | Produces a modern, India-first visual system; wireframes; component library; accessibility specs. | Figma-equivalent specs, design tokens, asset bundle |

### 2.1 Working Agreement Between Agents

1. PM agent breaks every requirement in this SRS into user stories with acceptance criteria before any code is written.
2. Architect agent must approve schema or security-rule changes before merge.
3. All code changes require: passing unit tests, passing widget tests, lint-clean output, and QA agent review.
4. DevOps agent owns secrets and never commits credentials; the architect approves any change to deployment topology.
5. QA agent must sign off the release candidate before DevOps promotes a build to production.

---

## 3. Overall Description

### 3.1 Product Perspective

One By Two is a self-contained mobile application backed by a single Firebase project. It does not depend on any other internal systems. External integrations are limited to Firebase services (Auth, Firestore, Cloud Functions, Cloud Messaging, Storage, Crashlytics, Analytics) and platform-native services (iOS contacts, Android contacts, system share sheet, default mail client).

### 3.2 User Classes and Characteristics

| User Class | Description | Technical Comfort |
|---|---|---|
| Casual user | Uses the app a few times a month to split bills with friends. | Low–Medium |
| Power user | Tracks daily group expenses (flatmates, trips, family). | Medium–High |
| Group admin | Creates and manages groups, adds members, settles balances. | Medium |

### 3.3 Operating Environment

- iOS 14 and above (iPhone only for v1.0; iPad layout deferred).
- Android 8.0 (API 26) and above.
- Backend: a single Firebase project (production) hosting Auth, Firestore, Cloud Functions, FCM, Storage, Crashlytics, Analytics.
- Network: app must function on 3G/4G/5G, with reasonable degradation on flaky networks.

### 3.4 Design and Implementation Constraints

- Frontend MUST be implemented in Flutter (latest stable channel) with Dart null-safety enabled.
- Backend MUST use Google Firebase. No alternative backends are permitted.
- Authentication MUST be Firebase Phone Auth, restricted to +91 phone numbers.
- Currency MUST be Indian Rupee (₹). All amounts displayed in ₹ with two decimal places.
- Only one Firebase environment exists: **production**. There are NO separate dev or staging projects. Local development uses Firebase Emulator Suite.
- Source control: GitHub. CI/CD: GitHub Actions.
- App distribution: Apple App Store (iOS) and Google Play Store (Android), via signed builds.
- Debt model: **Simplified Debts only.** No raw payer-to-payee debt graph is exposed in the UI.
- Sharing: **system share sheet only.** No platform-specific (e.g., WhatsApp) deep-link integration in v1.0.
- Support: **in-app `mailto:` link only.** No third-party helpdesk tooling.

### 3.5 Assumptions and Dependencies

- The Firebase project has been created by the customer; configuration (Auth methods, Firestore, security rules, indexes, FCM keys) is to be performed by the DevOps and Architect agents.
- Apple Developer and Google Play Console accounts exist and credentials will be supplied to the DevOps agent via GitHub secrets.
- SMS quotas for Phone Auth are sufficient for the launch user base; if exceeded, the architect agent must propose a mitigation.
- The brand name **One By Two** is locked for both app stores; trademark verification is the customer's responsibility and is considered closed for the purposes of engineering.
- A dedicated support email address (e.g., `avtanshgupta@One By Two.app`) will be provisioned by the customer before GA and supplied to the DevOps agent via Firebase Remote Config.

---

## 4. Functional Requirements

Functional requirements are grouped by feature area. Each requirement carries a unique identifier (FR-XX-NN), a priority (P0/P1/P2), and clear acceptance criteria. The PM agent must convert each item into one or more user stories.

### 4.1 Authentication & Onboarding

| ID | Requirement | Priority |
|---|---|---|
| FR-AU-01 | The app shall allow new and returning users to sign in using only their mobile phone number with the +91 country code prefix locked. | P0 |
| FR-AU-02 | The app shall reject any phone number that is not a valid 10-digit Indian mobile number after the +91 prefix. | P0 |
| FR-AU-03 | On submitting a valid phone number, the app shall trigger Firebase Phone Auth to send a 6-digit OTP via SMS. | P0 |
| FR-AU-04 | The app shall auto-read the OTP on Android using SMS Retriever where available and shall provide manual entry on iOS. | P0 |
| FR-AU-05 | The app shall allow the user to request a new OTP after a 30-second cooldown, capped at 3 retries per 10-minute window. | P0 |
| FR-AU-06 | On the very first successful login, the app shall prompt the user to enter their display name and (optionally) upload a profile photo. | P0 |
| FR-AU-07 | The app shall persist the authenticated session and auto-login on subsequent launches unless the user signs out. | P0 |
| FR-AU-08 | The user shall be able to sign out from the Profile screen, which clears the local session and returns to the login screen. | P0 |
| FR-AU-09 | The user shall be able to permanently delete their account, which triggers a Cloud Function that anonymises their data in shared groups and removes personal records within 30 days. | P1 |

### 4.2 Profile Management

| ID | Requirement | Priority |
|---|---|---|
| FR-PR-01 | Users shall be able to view and edit their display name and profile photo. | P0 |
| FR-PR-02 | Users shall be able to update their phone number through a re-verification flow (OTP to the new number). | P1 |
| FR-PR-03 | Users shall be able to set notification preferences per category (new expense, settlement, reminders). | P1 |
| FR-PR-04 | Users shall be able to view a list of all friends and groups they are part of from their profile. | P0 |
| FR-PR-05 | The Profile screen shall expose a **"Contact Support"** action that opens the device's default mail client via a `mailto:` URL pre-filled with the support address (configured via Remote Config), the user's `userId`, app version, OS, and device model in the body for triage. The user can edit before sending. | P0 |

### 4.3 Friends (1-to-1)

| ID | Requirement | Priority |
|---|---|---|
| FR-FR-01 | Users shall be able to add a friend by selecting a contact from their phone book or by entering a +91 number manually. | P0 |
| FR-FR-02 | If the contact is already a One By Two user, the friend shall be linked immediately. Otherwise, the app shall offer to invite the contact by handing off to the **system share sheet** with a pre-filled message and an install link. The OS-presented options (SMS, WhatsApp, Telegram, etc.) are entirely the user's choice; the app does not target any specific channel. | P0 |
| FR-FR-03 | Users shall see a list of all friends with the net balance for each (₹ owed to user, ₹ user owes, or "settled up"), computed using the Simplified Debts algorithm. | P0 |
| FR-FR-04 | Users shall be able to view a per-friend transaction history (expenses + settlements), sorted reverse chronologically. | P0 |
| FR-FR-05 | Users shall be able to delete a friend connection only if there is no outstanding balance. | P1 |

### 4.4 Groups

| ID | Requirement | Priority |
|---|---|---|
| FR-GR-01 | Users shall be able to create a group with a name, type (Trip / Home / Couple / Other), and optional cover photo. | P0 |
| FR-GR-02 | Users shall be able to invite members to a group via contact picker, +91 phone number, or shareable invite link surfaced through the **system share sheet**. | P0 |
| FR-GR-03 | An invite link shall expire 7 days after creation and shall be revocable by the group admin. | P0 |
| FR-GR-04 | Group members shall see all expenses, member balances (Simplified), and group activity within that group. | P0 |
| FR-GR-05 | The group admin shall be able to remove a member only if that member's simplified balance with the group is zero. | P0 |
| FR-GR-06 | Any member shall be able to leave a group only if their simplified balance is zero. | P0 |
| FR-GR-07 | The group admin shall be able to delete a group only if all member balances are zero. | P0 |

### 4.5 Expense Management

| ID | Requirement | Priority |
|---|---|---|
| FR-EX-01 | Users shall be able to add an expense with: amount in ₹, description, date, category, payer, split method, and optional notes. | P0 |
| FR-EX-02 | An expense may be created within a 1-to-1 friend context or within a group context. | P0 |
| FR-EX-03 | The app shall support the following split methods: Equally, Unequal (by amount), By Percentage, By Shares, and By Exact Amounts. | P0 |
| FR-EX-04 | The app shall validate that splits sum exactly to the expense total. Discrepancies shall block save with a clear inline error. | P0 |
| FR-EX-05 | Users shall be able to attach a receipt image to an expense (camera or gallery), stored in Firebase Storage. | P1 |
| FR-EX-06 | Users shall be able to edit or delete any expense they created. Edits and deletions shall be reflected in real time for all involved users and shall trigger recomputation of simplified balances. | P0 |
| FR-EX-07 | Each edit or delete shall be recorded in the activity feed with author and timestamp. | P0 |
| FR-EX-08 | The app shall support predefined expense categories (Food, Travel, Rent, Utilities, Groceries, Entertainment, Shopping, Other) with appropriate icons. | P0 |
| FR-EX-09 | Currency symbol shall always be ₹ and amounts shall be formatted using the Indian numbering system (e.g., ₹1,23,456.00). | P0 |

### 4.6 Settlements & Simplified Debts

| ID | Requirement | Priority |
|---|---|---|
| FR-SE-01 | The app shall compute and display **only Simplified Debts** as the canonical balance view. The raw "who paid for whom" graph shall not be shown to end users. | P0 |
| FR-SE-02 | The simplified-debts algorithm shall minimise the number of pairwise transactions needed to settle a friendship or group. Implementation shall be deterministic so that two clients viewing the same data see the same suggested settlements. | P0 |
| FR-SE-03 | The algorithm shall execute as a Cloud Function and shall write the result to a `simplifiedBalances` field on the relevant `friendship` or `group` document. The client shall read this denormalised result; it shall not recompute simplification on-device. | P0 |
| FR-SE-04 | Simplified balances shall be recomputed atomically inside the same Cloud Function transaction whenever an expense, edit, delete, or settlement is recorded. | P0 |
| FR-SE-05 | Users shall be able to record a settlement (a payment from one user to another) with amount, date, and optional note. The "Settle Up" UI shall pre-fill the recipient and amount based on the simplified-debts suggestion. | P0 |
| FR-SE-06 | Recording a settlement shall update simplified balances in real time for both users (and, if in a group context, all group members). | P0 |
| FR-SE-07 | The app shall surface a "Settle Up" call-to-action on every screen that shows a non-zero simplified balance. | P0 |
| FR-SE-08 | Users shall be able to view a settlement history per friend and per group. | P0 |
| FR-SE-09 | Users shall be able to send a free-text reminder (in-app push notification) to a friend who owes them money per the simplified balances. Rate-limited to one reminder per friend per 24 hours. | P1 |

> **Architect note:** because Simplified Debts is the *only* mechanism, the schema does not need to retain a per-pair raw debt ledger. The source of truth is the expense + settlement log, with `simplifiedBalances` as a derived, server-maintained projection. See §7.

### 4.7 Activity Feed & Notifications

| ID | Requirement | Priority |
|---|---|---|
| FR-AC-01 | The app shall provide an Activity tab showing a chronological feed of all events (expenses added/edited/deleted, settlements, group changes) involving the user. | P0 |
| FR-AC-02 | Tapping on an activity item shall deep-link the user to the relevant expense, friend, or group screen. | P0 |
| FR-AC-03 | The app shall send push notifications via FCM for: new expense involving the user, edit/delete of an expense involving the user, new settlement received, and reminders. | P0 |
| FR-AC-04 | Notifications shall respect the user's per-category preferences (FR-PR-03). | P1 |
| FR-AC-05 | Tapping a notification shall deep-link the user to the relevant screen, even from a cold start. | P0 |

### 4.8 Home Dashboard

| ID | Requirement | Priority |
|---|---|---|
| FR-HD-01 | The Home dashboard shall display the user's overall net simplified balance ("You are owed ₹X" / "You owe ₹Y") as the primary visual element. | P0 |
| FR-HD-02 | The Home dashboard shall surface the top 5 friends/groups by absolute simplified balance, with quick access to settle. | P0 |
| FR-HD-03 | The Home dashboard shall show a current-month spend summary with a category breakdown (donut/bar chart). | P1 |
| FR-HD-04 | A persistent floating action button shall allow adding a new expense from any primary tab. | P0 |

### 4.9 Search & Filters

| ID | Requirement | Priority |
|---|---|---|
| FR-SR-01 | Users shall be able to search expenses by description, amount, category, or member. | P1 |
| FR-SR-02 | Users shall be able to filter expenses by date range, group, and category. | P1 |

### 4.10 Offline Support

| ID | Requirement | Priority |
|---|---|---|
| FR-OF-01 | Users shall be able to view previously-loaded expenses, friends, groups, and simplified balances when offline. | P0 |
| FR-OF-02 | Users shall be able to add an expense or settlement while offline. The app shall queue the write and sync when connectivity returns; the simplified-balances Cloud Function will run on sync. | P1 |
| FR-OF-03 | Conflicts arising from offline edits shall be resolved using last-write-wins on the server, with the user notified if their write is overridden. Simplified balances are recomputed after every conflict resolution. | P1 |

### 4.11 Sharing & Support

| ID | Requirement | Priority |
|---|---|---|
| FR-SH-01 | All outbound sharing (friend invites, group invites, "share my balance") shall use the platform's **system share sheet**. The app shall not target any specific messaging app. | P0 |
| FR-SH-02 | Shared messages shall include a deep link to the install page (universal link on iOS, App Link on Android) and a fallback play.google.com / apps.apple.com URL. | P0 |
| FR-SH-03 | The Profile screen shall include a "Contact Support" action that opens a `mailto:` link with the support email address, app version, OS version, device model, and `userId` pre-filled in the body. The support address is read from Firebase Remote Config so it can be changed without an app update. | P0 |
| FR-SH-04 | If no mail client is configured on the device, the app shall display a fallback dialog showing the support email address with a "Copy" button. | P1 |

---

## 5. Non-Functional Requirements

### 5.1 Performance

| ID | Requirement | Target |
|---|---|---|
| NFR-PE-01 | Cold-start launch time on a mid-range Android device. | ≤ 3 seconds (P95) |
| NFR-PE-02 | Warm-start launch time. | ≤ 1 second (P95) |
| NFR-PE-03 | Time to render Home dashboard after auth (cached state). | ≤ 1.5 seconds (P95) |
| NFR-PE-04 | Add-expense save round-trip time on 4G (including simplified-balances recomputation). | ≤ 2.5 seconds (P95) |
| NFR-PE-05 | Average API/Firestore read latency from app perspective. | ≤ 400 ms (P95) |
| NFR-PE-06 | App size on first install. | ≤ 60 MB (Android), ≤ 90 MB (iOS) |

### 5.2 Scalability

- The system shall support 100,000 MAU at launch and scale linearly to 1,000,000 MAU without architectural change.
- Firestore data model shall be designed to avoid hot documents (no single document is written by more than ~1 user/sec on average).
- Cloud Functions (including the simplified-debts function) shall be region-pinned to `asia-south1` (Mumbai) for low-latency Indian traffic.
- Simplified-debts computation shall complete in ≤ 500 ms (P95) for groups up to 50 members; larger groups are out of scope for v1.0.

### 5.3 Availability & Reliability

- Target uptime: 99.9% measured against successful client requests per month.
- Crash-free user rate (Crashlytics): ≥ 99.5% per release.
- All financial state mutations (expenses, settlements, simplified-balance recomputation) shall be atomic via Firestore transactions or batched writes.

### 5.4 Security

- All client-server traffic shall use TLS 1.2 or higher (enforced by Firebase by default).
- Firestore Security Rules shall enforce that a user can only read/write data they are a participant in (own profile, own friend edges, own groups, expenses they are part of).
- Authentication state shall be verified server-side in every Cloud Function via the Firebase Admin SDK.
- Personally identifiable information (phone number, name, photo URL) shall never be logged in Crashlytics or Analytics.
- Receipt images in Firebase Storage shall be served via signed URLs and access-controlled by Storage Rules.
- API keys and signing certificates shall be stored exclusively in GitHub Actions secrets, never in source.
- App Check (with Play Integrity on Android and DeviceCheck on iOS) shall be enabled for Firestore, Storage, and Cloud Functions.
- The simplified-balances field shall be writable **only** by the dedicated Cloud Function service account, never by client SDKs.

### 5.5 Privacy & Compliance

- The app shall comply with India's Digital Personal Data Protection Act (DPDP), 2023, including consented data collection and the right to delete.
- A privacy policy and terms of service shall be linked from the onboarding screen and the profile.
- Account deletion (FR-AU-09) shall remove or anonymise all personal data within 30 days of request.

### 5.6 Usability & Accessibility

- All primary actions shall be reachable within 2 taps from the Home dashboard.
- Tap targets shall be at least 44×44 pt (iOS) and 48×48 dp (Android).
- Text shall meet WCAG 2.1 AA contrast ratios (≥ 4.5:1 for body text).
- The app shall fully support OS-level dynamic font scaling and dark mode.
- The app shall be screen-reader compatible (VoiceOver and TalkBack), with semantic labels on every interactive widget.
- English shall be the default language for v1.0; the architecture shall support Hindi and other Indian languages in future releases without refactor.

### 5.7 Maintainability

- Codebase shall follow `effective_dart` and use a consistent linter (`flutter_lints` or `very_good_analysis`).
- Modular architecture: feature-first folder structure (`auth`, `friends`, `groups`, `expenses`, `settlements`, `profile`, `common`).
- State management: Riverpod 2.x (or BLoC if architect prefers); decision recorded as an ADR.
- Minimum unit + widget test coverage: 70% for non-UI code, 50% overall, enforced in CI.
- All public Dart APIs and Cloud Functions shall be documented with DartDoc / JSDoc comments.
- The simplified-debts algorithm shall be implemented in a single, isolated module with its own unit-test suite covering the canonical Splitwise-style test cases.

### 5.8 Portability

- Single Flutter codebase deploys to iOS and Android.
- No platform-specific native code unless strictly required (e.g., contact picker bridges).

### 5.9 Localisation & Internationalisation

- All user-facing strings shall be externalised via Flutter's `intl` package (`.arb` files).
- Date/time displayed in IST (`Asia/Kolkata`) regardless of device locale.
- Currency formatting: Indian numbering system, two decimal places, ₹ symbol prefix.

### 5.10 Observability

- Firebase Crashlytics integrated on both platforms with mandatory dSYM/symbol upload from CI.
- Firebase Analytics events for key funnels: `signup_started`, `signup_completed`, `expense_added`, `settlement_recorded`, `group_created`, `friend_added`, `simplified_balance_computed`, `support_email_opened`.
- Cloud Functions shall emit structured logs (JSON) and shall be alerted on error-rate spikes via Cloud Monitoring.

---

## 6. User Experience & Design Requirements

### 6.1 Design Philosophy

One By Two's UI is to feel modern, friendly, and unmistakably Indian. The design language draws on Material 3 and Apple Human Interface Guidelines, while expressing a distinct brand identity through colour, typography, and motion. The aesthetic is warm and energetic, not corporate.

### 6.2 Visual System

| Token | Value | Usage |
|---|---|---|
| Primary | Indigo Blue (`#1F4E79` / `#2E86AB` accent) | Primary actions, highlights, balance positives |
| Secondary | Saffron / Marigold (`#F4A261`) | Secondary highlights, India-flavoured accents |
| Success | Emerald (`#2A9D8F`) | "You are owed", positive states |
| Danger | Coral Red (`#E76F51`) | "You owe", destructive actions |
| Surface | Pure white / `#121212` in dark mode | Cards, sheets |
| Typography | Inter or Plus Jakarta Sans (Latin); fallback to system | All UI text |
| Corner radius | 16 dp / 24 dp on cards and sheets | Soft, modern feel |
| Elevation | Subtle shadows, layered surfaces | Depth without heaviness |
| Motion | 200–300 ms ease-in-out transitions; spring physics on FAB | Delightful but quiet |

### 6.3 Core Screens

1. Splash & Onboarding (3 illustrated slides)
2. Phone-number entry (locked +91 prefix)
3. OTP verification
4. Profile setup (name, photo)
5. Home dashboard (simplified balance, top friends/groups, FAB to add expense)
6. Friends list & Friend detail
7. Groups list & Group detail
8. Add / Edit expense (multi-step bottom sheet)
9. Settle Up flow (driven by simplified-debts suggestion)
10. Activity feed
11. Profile & Settings (incl. Contact Support)

### 6.4 Empty, Error & Loading States

Every list and detail screen shall have explicit empty, loading (skeleton screens preferred over spinners), and error states with actionable copy. Error states shall provide a "Retry" affordance and a path to Contact Support (see FR-PR-05).

### 6.5 Microcopy Tone

Friendly, concise, and lightly playful. Examples: *"You're all settled up — high five!"*, *"Looks like Rahul still owes you ₹350. Send a nudge?"*, *"Adding expense… hold tight."* No legalistic language outside the privacy policy and terms of service.

---

## 7. Architecture & Data Model

### 7.1 High-Level Architecture

One By Two follows a thin-client / smart-backend split. The Flutter app handles UI, local caching, and direct Firestore reads/writes for *user-authored* data. Sensitive or aggregate operations — group invites, **simplified-debts computation**, account deletion — execute as Cloud Functions to keep logic away from the client and to guarantee one canonical answer.

- **Client:** Flutter app with Riverpod state management, Firebase SDKs (`auth`, `firestore`, `storage`, `messaging`, `crashlytics`, `analytics`, `app_check`).
- **Backend:** Firebase Auth (Phone), Cloud Firestore (primary data store), Cloud Storage (receipts, avatars), Cloud Functions for Firebase (Node.js 20 / TypeScript), Cloud Messaging.
- **CI/CD:** GitHub Actions running unit tests, integration tests against Firebase Emulator Suite, build, sign, and deploy.

### 7.2 Firestore Data Model (Logical)

Top-level collections (each document below shows the most relevant fields; types are illustrative):

#### `users/{userId}`

- `phoneNumber: string` (`+91XXXXXXXXXX`)
- `displayName: string`
- `photoUrl: string | null`
- `fcmTokens: string[]`
- `createdAt`, `updatedAt: timestamp`
- `notificationPrefs: { newExpense, settlement, reminder }: bool`

#### `friendships/{friendshipId}`

- `memberIds: string[2]` — sorted for deterministic ID
- `simplifiedBalances: { [debtorUserId]: { [creditorUserId]: amountPaise } }` — *server-maintained, client-read-only*
- `lastActivityAt: timestamp`

#### `groups/{groupId}`

- `name: string`
- `type: 'trip' | 'home' | 'couple' | 'other'`
- `coverPhotoUrl: string | null`
- `memberIds: string[]`
- `adminId: string`
- `simplifiedBalances: { [debtorUserId]: { [creditorUserId]: amountPaise } }` — *server-maintained, client-read-only*
- `createdAt`, `updatedAt: timestamp`

#### `groups/{groupId}/expenses/{expenseId}` and `friendships/{id}/expenses/{id}`

- `amountPaise: number` — store ₹ as integer paise to avoid floating-point error
- `description: string`
- `category: enum`
- `date: timestamp`
- `payerId: string`
- `splits: [{ userId, sharePaise }]`
- `splitMethod: 'equal' | 'unequal' | 'percentage' | 'shares' | 'exact'`
- `receiptUrl: string | null`
- `createdBy`, `createdAt`, `updatedAt`
- `deleted: boolean` (soft delete)

#### `settlements/{settlementId}`

- `fromUserId`, `toUserId: string`
- `amountPaise: number`
- `contextType: 'friendship' | 'group'`
- `contextId: string`
- `date: timestamp`
- `note: string | null`

#### `activity/{userId}/items/{itemId}`

- `type: 'expense_added' | 'expense_edited' | 'expense_deleted' | 'settlement' | 'group_change'`
- `payload: map`
- `createdAt: timestamp`

### 7.3 Key Architectural Decisions

- Money is stored as integer **paise** (1 ₹ = 100 paise) to prevent floating-point drift; conversion to ₹ happens at the UI layer.
- `simplifiedBalances` is the single denormalised source of truth for "who owes whom"; the client never computes it. This is enforced by Security Rules (clients can read but not write the field).
- A Cloud Function `recomputeSimplifiedBalances(contextType, contextId)` runs inside a Firestore transaction whenever an expense or settlement is created, edited, or deleted. The function reads all non-deleted expenses + settlements for the context, runs the simplification algorithm, and writes the result.
- Heavy operations (account deletion, group invite acceptance) run as Cloud Functions so the client cannot bypass invariants.
- Soft delete on expenses preserves audit history for the activity feed and allows balances to be re-derived from the log if `simplifiedBalances` ever needs to be rebuilt.
- Indexes: composite indexes for `(groupId, date desc)`, `(userId, date desc)`, and `(memberIds, lastActivityAt desc)` shall be defined in `firestore.indexes.json`.

### 7.4 Simplified Debts Algorithm — Specification

The reference algorithm, to be implemented as a pure function in `functions/src/simplifiedDebts.ts`:

1. For each member, compute `netPaise = sum(paid for them by self) − sum(paid for self by others) − sum(settlements out) + sum(settlements in)`.
2. Partition members into **creditors** (`net > 0`) and **debtors** (`net < 0`). Members with `net == 0` are dropped.
3. Repeatedly pair the largest creditor with the largest debtor and emit a transfer of `min(|debtor|, |creditor|)`. Subtract from both. Continue until both lists are empty.
4. Emit the result as a flat list of `{ from, to, amountPaise }` and project it into the nested `simplifiedBalances` map.
5. Determinism: when multiple creditors or debtors tie, break ties by ascending `userId` so all clients see the same result.

The function MUST have unit tests covering: empty input; single-member group; perfectly balanced group; cyclic debts that simplify to zero; and the canonical 3-person and 5-person cases.

### 7.5 Security Rules (Principles)

- A document is readable/writable only by users listed in its `memberIds` / participants array.
- Expense writes shall validate that splits sum to the expense amount in paise (server-side rule check, in addition to client-side).
- Settlement writes shall validate that `fromUserId == request.auth.uid`.
- The `simplifiedBalances` field on `friendships` and `groups` is **read-only to clients**. Only the Cloud Functions service account may write it.
- Public collections do not exist; everything is participant-scoped.

---

## 8. Development Workflow & Local Testing

### 8.1 Local Development Stack

| Component | Tool | Notes |
|---|---|---|
| IDE | VS Code or Android Studio | Flutter & Dart plugins required |
| Flutter | Latest stable channel | Pinned via `fvm` or `.tool-versions` |
| iOS Simulator | Xcode-bundled simulators | Minimum iOS 14 |
| Android Emulator | Pixel 6 image, API 34 | Plus minimum-supported API 26 image |
| Firebase Emulator Suite | Auth, Firestore, Functions, Storage | Started via `firebase emulators:start` |
| Node.js | v20 LTS | For Cloud Functions |
| Git hooks | `lefthook` or `husky` | Run lint, format, test on pre-commit |

### 8.2 Local Testing Flow

1. Developer agent runs `firebase emulators:start`, which spins up Auth, Firestore, Functions, and Storage emulators on `localhost`.
2. Flutter app, when run in debug mode, points to the emulator hosts (`localhost` on iOS sim, `10.0.2.2` on Android emulator) via a feature flag.
3. Developer writes feature code and unit + widget tests.
4. Cloud Functions are unit-tested with the `firebase-functions-test` SDK and integration-tested against the emulator. The simplified-debts function has its own dedicated test suite (see §7.4).
5. Developer runs the app on both an iOS simulator and an Android emulator, verifying parity.
6. Once feature passes locally, developer pushes a branch and opens a pull request.

### 8.3 Branching Strategy

- Trunk-based development on the `main` branch.
- Short-lived feature branches: `feat/<scope>`, `fix/<scope>`, `chore/<scope>`.
- All merges to `main` go through pull request with at least one approving review (the QA agent for QA-impacting changes, the architect agent for schema/security/simplified-debts changes).

---

## 9. CI/CD & Deployment

### 9.1 Environment Reality

There is exactly **one** Firebase project: production. There are no separate dev or staging Firebase projects. To compensate, all pre-merge testing happens against the Firebase Emulator Suite locally and in CI. The DevOps agent must therefore design pipelines that protect the single production project from regressions.

### 9.2 GitHub Actions Pipelines

#### 9.2.1 Pull Request Pipeline (`.github/workflows/pr.yml`)

1. **Trigger:** `pull_request` to `main`.
2. **Steps:** checkout → setup Flutter → setup Node 20 → `flutter pub get` → `dart format --set-exit-if-changed` → `flutter analyze` → `flutter test --coverage` → `cd functions && npm ci && npm run lint && npm test`.
3. Spin up Firebase emulators in CI and run integration tests against them, including the simplified-debts canonical cases.
4. Upload coverage to a coverage artifact; fail if below threshold.
5. Build (no signing) for both iOS and Android to catch build errors early.

#### 9.2.2 Production Release Pipeline (`.github/workflows/release.yml`)

1. **Trigger:** pushing a Git tag matching `v*.*.*` on `main`, or manual `workflow_dispatch`.
2. Required checks: PR pipeline must have passed on the commit being released.
3. Steps: checkout → run full test suite once more as a guard.
4. Deploy Firestore rules, indexes, and Cloud Functions to the production Firebase project via Firebase CLI (token from secret `FIREBASE_TOKEN`).
5. Build signed Android App Bundle (`.aab`) using Fastlane; upload to Google Play Internal Track.
6. Build signed iOS `.ipa` using Fastlane `match`; upload to TestFlight.
7. Promotion to Play Production and App Store Review is a manual approval step (GitHub Environments protection rule) requiring QA agent sign-off.
8. Post-deploy: smoke-test the production Cloud Functions via a synthetic monitor; create a GitHub Release with auto-generated release notes.

### 9.3 Required GitHub Secrets

| Secret | Purpose |
|---|---|
| `FIREBASE_TOKEN` | CI deploy of rules, indexes, and Cloud Functions |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Alt for Firebase Admin in CI tests |
| `ANDROID_KEYSTORE_BASE64` | Android release signing keystore |
| `ANDROID_KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD` | Keystore credentials |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play upload via Fastlane `supply` |
| `APP_STORE_CONNECT_API_KEY_ID` / `ISSUER_ID` / `KEY_BASE64` | TestFlight / App Store Connect upload |
| `MATCH_GIT_URL` / `MATCH_PASSWORD` | Fastlane `match` certificate sync |
| `OPS_NOTIFY_WEBHOOK` | Slack/Teams webhook for release notifications |

### 9.4 Production Safety Controls

- Required status checks on `main`: PR pipeline must pass before merge.
- Branch protection rules: no direct pushes to `main`, no force-push, signed commits required.
- GitHub Environments: `production-firebase`, `production-ios`, `production-android` each require manual approval from a designated reviewer (the QA agent for app stores, the architect agent for Firebase backend).
- Feature flags: critical new features ship behind Firebase Remote Config flags so they can be disabled without a rollback. The support email address is also held in Remote Config.
- Rollback strategy: previous release artifacts (`.aab`, `.ipa`, Cloud Function source) are retained for 90 days as workflow artifacts and can be redeployed manually.

---

## 10. Quality Assurance Strategy

### 10.1 Test Pyramid

| Level | Tooling | Coverage Goal |
|---|---|---|
| Unit tests | `flutter_test`, `mocktail`, `firebase-functions-test` | ≥ 70% of non-UI code |
| Widget tests | `flutter_test`, `golden_toolkit` | Every reusable widget and key screen |
| Integration tests | `integration_test` against Firebase Emulator Suite | All critical user journeys |
| Manual smoke tests | Internal QA on real devices | Pre-release sign-off |

### 10.2 Critical User Journeys (Must-Pass)

1. First-time user: onboarding → phone OTP → profile setup → home dashboard.
2. Add a friend by contact, add an expense split equally, see simplified balance update.
3. Create a group of 4, add an expense with unequal split, settle one member using the simplified-debts suggestion.
4. Edit an existing expense; verify simplified balances and activity feed update for all participants.
5. Delete an expense; verify simplified balances are correctly recomputed.
6. Receive a push notification on background and foreground; verify deep-link.
7. Offline: add expense without network; reconnect; verify sync and balance recomputation.
8. Dark mode: navigate every screen and verify legibility.
9. Large-data: group with 50+ expenses scrolls smoothly and renders correctly; simplified-debts function returns within SLA.
10. Account deletion: trigger flow, verify data anonymisation in shared groups.
11. Share-sheet invite (friend and group): invite text and deep link are correct; the OS share sheet is the only handoff surface.
12. Contact Support: tapping opens the device mail composer with the correct address and pre-filled diagnostic body; fallback dialog appears when no mail client is configured.

### 10.3 Device & OS Coverage Matrix

| Tier | iOS | Android |
|---|---|---|
| Tier 1 (must pass) | iPhone 12, iPhone 14 (iOS 17) | Pixel 6 (Android 14), Samsung Galaxy A-series (Android 13) |
| Tier 2 (should pass) | iPhone SE 2nd gen (iOS 14) | Xiaomi Redmi (Android 11), low-end OEM (Android 8) |
| Tier 3 (best effort) | iPad portrait (post-v1.0) | Tablets (post-v1.0) |

### 10.4 Non-Functional Testing

- **Performance:** cold-start, scroll FPS, memory usage profiled with Flutter DevTools.
- **Security:** Firestore rules tested with the rules-unit-testing emulator, including negative cases (especially: clients attempting to write `simplifiedBalances`).
- **Accessibility:** VoiceOver and TalkBack walkthroughs of all primary flows.
- **Localisation:** pseudolocalisation pass to catch hardcoded strings.
- **Penetration test (light):** manual checks for OTP brute-force, deep-link spoofing, and insecure storage.

### 10.5 Bug Severity Definitions

| Severity | Definition | SLA to fix |
|---|---|---|
| S1 — Critical | App crashes on launch or core flow blocked for all users; data loss or financial error (incl. wrong simplified balances). | Same-day hotfix |
| S2 — Major | Feature broken with no workaround; affects many users. | Within 3 business days |
| S3 — Minor | Feature broken with workaround; cosmetic but visible. | Next sprint |
| S4 — Trivial | Polish, copy, edge-case visual. | Backlog, time-permitting |

---

## 11. Release Plan

### 11.1 Phased Roll-out

1. **Alpha (Week 0):** Build feature-complete app behind closed test track on Play Console + TestFlight; QA agent runs the full test plan.
2. **Closed Beta (Weeks 1–2):** Invite ~50 real users; monitor Crashlytics and Analytics.
3. **Open Beta (Weeks 3–4):** Public Play Open Testing track + TestFlight public link; gather usage telemetry.
4. **GA (Week 5+):** Promote to Play Production and App Store Review using a staged rollout (10% → 50% → 100%).

### 11.2 Launch Readiness Checklist

- [ ] All P0 functional requirements implemented and tested.
- [ ] All NFR targets met or formally accepted as known limitations.
- [ ] Privacy policy, terms of service, support email live and linked from the app (support email configured in Remote Config).
- [ ] Play Console and App Store Connect listings complete (icon, screenshots, description, age rating, data-safety form) under the locked brand name **One By Two**.
- [ ] Firebase production project hardened: App Check enforced, Firestore rules deployed, indexes deployed, Cloud Functions deployed, billing alerts configured.
- [ ] Crashlytics, Analytics, and Performance Monitoring enabled and dashboards reviewed.
- [ ] DevOps runbooks for hotfix, rollback, and incident response committed to the repo.
- [ ] Simplified-debts canonical test cases pass in CI on the release commit.

---

## 12. Risks, Assumptions & Resolved Decisions

### 12.1 Top Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Single-environment Firebase (no staging) | Bad release affects all users immediately. | Heavy reliance on Emulator Suite; feature flags via Remote Config; staged rollout (10% → 50% → 100%) on Play. |
| SMS OTP cost / Phone Auth quota limits | User onboarding may fail at scale. | Monitor SMS usage; budget alerts; reCAPTCHA for abuse; document fallback path. |
| Floating-point money errors | Wrong balances and settlements. | Store money as integer paise everywhere. |
| Hot documents on group balances | Throttling during group activity. | Keep simplified-balance updates inside transactions; consider sharded counters if size grows. |
| Account deletion / DPDP compliance miss | Regulatory exposure. | Cloud Function with deletion audit log; documented 30-day SLA; legal review before launch. |
| Bug in simplified-debts algorithm | All balances incorrect — high blast radius because it is the *only* debt mechanism. | Extensive unit-test coverage with canonical cases; idempotent recomputation function; ability to rebuild from the immutable expense + settlement log if needed. |
| No mail client on user device | Support flow appears broken. | Fallback "Copy support email" dialog (FR-SH-04). |

### 12.2 Resolved Decisions (Open Questions Closed)

| Question | Decision |
|---|---|
| Should v1.0 ship with WhatsApp invite as the default share target, or just the system share sheet? | **System share sheet only.** No platform-specific channel integration in v1.0. The OS-presented options (SMS, WhatsApp, Telegram, etc.) are the user's choice. |
| Final brand name lock-in for app stores. | **Locked: One By Two.** All store listings, marketing assets, and code identifiers shall use this name. |
| Support channel: in-app email link vs. helpdesk integration (Freshdesk / Zoho Desk)? | **In-app `mailto:` email link.** A Profile → "Contact Support" action opens the device's default mail client pre-filled with diagnostic context. Address held in Remote Config so it can change without an app update. |
| Should the Simplify Debts feature be P0 or P1 for launch? | **P0 — and it is the *only* debt mechanism.** One By Two does not display a raw payer-to-payee debt graph. All "who owes whom" views, the Home dashboard, and the Settle Up flow read from the server-maintained `simplifiedBalances` field. |

### 12.3 Future / Out-of-Scope (Post v1.0)

- UPI deep-link integration to settle balances directly via PhonePe/GPay/Paytm.
- Hindi and other Indian-language localisations.
- Recurring expenses and subscription splits.
- Web companion app.
- AI-assisted receipt OCR and category prediction.
- Dedicated helpdesk integration (Freshdesk / Zoho Desk) if support volume justifies it.

---

## 13. Appendices

### 13.1 Suggested Project Structure (Flutter)

```
lib/
  app/        — app shell, routing, theme
  core/       — error handling, money utils, formatters, extensions
  data/       — Firebase repositories, DTOs
  features/
    auth/
    friends/
    groups/
    expenses/
    settlements/
    profile/
    activity/
  l10n/       — .arb localisation files

functions/    — Cloud Functions (TypeScript)
  src/
    simplifiedDebts.ts
    accountDeletion.ts
    triggers/

ios/, android/    — platform shells
.github/workflows/ — CI/CD pipelines

firebase.json
firestore.rules
firestore.indexes.json
storage.rules
```

### 13.2 Acceptance Criteria Template (for PM agent)

Each user story shall follow this format:

- **Title:** *concise feature title*
- **Story:** As a `<user role>`, I want `<capability>` so that `<benefit>`.
- **Preconditions:** *state required before*
- **Acceptance Criteria** (Given/When/Then), at least 3 scenarios including 1 negative case.
- **Definition of Done:** code merged, tests written and passing, QA verified, telemetry in place, docs updated.

### 13.3 Document Control

| Version | Date | Author | Notes |
|---|---|---|---|
| 1.0 | Initial release | Product team | First baseline for AI agent execution. |
| 1.1 | This revision | Product team | Closed all open questions: system share sheet only; brand name locked as One By Two; in-app `mailto:` support; Simplified Debts as the sole P0 debt mechanism. |

---

*— End of Document —*