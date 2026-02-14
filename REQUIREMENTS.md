# OneByTwo — Product Requirements Document

> **Version:** 1.0  
> **App Name:** OneByTwo  
> **Tagline:** Split expenses. Not friendships.  
> **Audience:** Architect / Engineering Team  

---

## 1. Executive Summary

OneByTwo is a mobile-first expense sharing application designed to provide a **clean, simple, ad-free** experience for splitting expenses among friends, roommates, couples, and travel groups. It works seamlessly **online and offline**, with automatic sync when connectivity is restored.

The app is positioned as a modern, user-friendly alternative to Splitwise, SettleUp, and Tricount — solving the key pain points users face with those apps while retaining all essential expense-splitting functionality.

---

## 2. Market Analysis & Competitive Landscape

### 2.1 Key Competitors

| App | Strengths | Weaknesses |
|-----|-----------|------------|
| **Splitwise** | Large user base, debt simplification, multi-currency | Free tier limits (daily expense cap), ads, paywalled features (receipt scan, charts), sync/balance discrepancies, slow support |
| **SettleUp** | Multi-currency, cross-platform, offline support | No receipt scanning, requires accounts, limited free tier |
| **Tricount** | Simple UX, quick group setup, multi-currency | Ads in free tier, limited editing controls, no itemization |
| **Splid** | Offline sync, flexible splits | Limited feature set, basic UI |

### 2.2 User Pain Points with Existing Apps (Based on Real User Feedback)

| # | Pain Point | Impact | OneByTwo Solution |
|---|-----------|--------|-------------------|
| 1 | **Free tier throttling** — Splitwise limits daily expense additions for free users | Users can't log expenses during trips/events when they need the app most | **No artificial limits.** All core features are free and unlimited. Revenue via optional premium cosmetic/convenience features only |
| 2 | **Ads degrade UX** — Most free versions show intrusive ads | Breaks flow, especially during quick expense entry | **Completely ad-free.** Always. |
| 3 | **Complex split UX** — Splitting by percentage/shares/custom amounts is confusing | Users redo entries, abandon mid-flow | **Guided split flow** with visual previews, draft auto-save, and undo support |
| 4 | **Balance discrepancies** — Deleted expenses still affect balances; mismatch between views | Erodes trust in the app | **Single source of truth** with transparent audit log. Deletion fully clears from balances with clear history |
| 5 | **Poor offline experience** — Only basic entry works offline; no balance views | Useless during travel without connectivity | **Offline-first architecture.** Full functionality offline — view balances, add/edit expenses, settle debts. All syncs automatically |
| 6 | **No group admin/permissions** — Anyone can edit/delete anyone's expenses | Chaotic in large groups (10+ people) | **Group roles** — Owner, Admin, Member. Configurable edit/delete permissions |
| 7 | **Missing itemized bill splitting** — Users must manually calculate per-item costs | Tedious for restaurant bills, groceries | **Built-in itemized split** — assign individual items to specific people from a single bill |
| 8 | **Account required to participate** — All members must create accounts | Friction for one-time group events | **Invite-by-link** — non-registered members can join a group and participate with just a name. Account optional for basic use |
| 9 | **Slow customer support** | Users stuck with bugs, billing issues | **In-app feedback system** with community-driven help and responsive support |
| 10 | **No spending insights (free)** — Charts/analytics paywalled | Users can't understand spending patterns | **Basic spending insights included free** — category breakdowns, monthly summaries |

---

## 3. Target Users & Use Cases

### 3.1 User Personas

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| **Roommates** | 2–6 people sharing a living space | Track recurring bills (rent, utilities, groceries), settle monthly |
| **Travel Groups** | 3–15 friends on a trip | Quick entry, offline use, settle at trip end |
| **Couples** | Partners sharing daily expenses | Simple 50/50 or custom splits, running balance |
| **Event Organizers** | Planning weddings, parties, etc. | Collect contributions, track costs, share summary |
| **Casual Friends** | Occasional dinners, outings | One-off splits, no ongoing group needed |

### 3.2 Key Use Cases

1. Adding an expense paid by one person, split among group members
2. Splitting a restaurant bill item-by-item among diners
3. Recording a payment/settlement between two people
4. Viewing "who owes whom" with simplified debts
5. Managing recurring shared bills (rent, Netflix, utilities)
6. Tracking expenses across multiple currencies during travel
7. Viewing personal spending breakdown by category
8. Settling all debts at the end of a trip
9. Adding expenses offline and having them sync later
10. Inviting a non-app-user to a group via link

---

## 4. Functional Requirements

### 4.1 User Management

| ID | Requirement | Priority |
|----|-------------|----------|
| UM-01 | User registration via mobile number with OTP verification. Phone number must be unique per account | P0 |
| UM-02 | Mandatory fields for account creation: name and email | P0 |
| UM-03 | User login via mobile OTP (primary and only auth method) | P0 |
| UM-04 | User profile (name, email, phone number, avatar, preferred language) | P0 |
| UM-05 | Guest participation via invite link (no account required) | P0 |
| UM-06 | Account deletion with full data removal (GDPR compliance) | P0 |
| UM-07 | Contact book integration to find friends on the app | P1 |
| UM-08 | Phone number change with re-verification (OTP on new number) | P1 |

### 4.2 Groups

| ID | Requirement | Priority |
|----|-------------|----------|
| GR-01 | Create groups with name, cover photo, and category (Trip, Home, Couple, Event, Other) | P0 |
| GR-02 | Add/remove members from groups | P0 |
| GR-03 | Invite members via shareable link (no account required for invitee) | P0 |
| GR-04 | Group roles: Owner, Admin, Member | P1 |
| GR-05 | Configurable permissions (who can add/edit/delete expenses) | P1 |
| GR-06 | Archive groups (mark as settled/inactive) | P0 |
| GR-07 | Group-level default split type (equal, custom) | P1 |
| GR-09 | Group activity feed with chronological history | P0 |
| GR-10 | Pin/favorite frequently used groups | P1 |

### 4.3 Expenses

| ID | Requirement | Priority |
|----|-------------|----------|
| EX-01 | Add expense with: description, amount (₹), date, payer, participants | P0 |
| EX-02 | Split types: Equal, Exact amounts, Percentage, Shares (fractions) | P0 |
| EX-03 | Itemized bill split — list individual items and assign to specific people | P0 |
| EX-04 | Multiple payers for a single expense | P1 |
| EX-05 | Expense categories (Food, Transport, Groceries, Rent, Entertainment, Utilities, Shopping, Health, Travel, Other + custom) | P0 |
| EX-06 | Auto-assign category icons/colors | P1 |
| EX-07 | Add notes/comments to an expense | P0 |
| EX-08 | Attach receipt photo(s) to an expense | P0 |
| EX-09 | Receipt scanning with OCR to auto-populate amount and items | P2 |
| EX-10 | Recurring expenses with customizable frequency (daily, weekly, monthly, yearly) | P0 |
| EX-11 | Edit expense (with audit trail of changes) | P0 |
| EX-12 | Delete expense (with soft-delete & undo within 30 seconds) | P0 |
| EX-13 | Duplicate an existing expense | P1 |
| EX-14 | Draft auto-save (resume interrupted expense entry) | P1 |
| EX-15 | Expense entry outside a group (between two individuals) | P0 |
| EX-16 | Tag expenses (e.g., #day1, #hotel, #food) for filtering | P2 |
| EX-17 | Bulk expense entry mode (quick-add multiple expenses) | P2 |

### 4.4 Balances & Settlements

| ID | Requirement | Priority |
|----|-------------|----------|
| BS-01 | Real-time balance calculation showing net amounts between all pairs | P0 |
| BS-02 | Debt simplification — minimize number of transactions to settle all debts | P0 |
| BS-03 | Record manual settlement/payment between two members | P0 |
| BS-04 | "Settle All" — generate optimized settlement plan for entire group | P0 |
| BS-05 | Settlement reminders (push notification + in-app) | P1 |
| BS-06 | Export settlement summary (PDF/image) for sharing | P1 |

### ~~4.5 Multi-Currency~~ *(Removed — app targets India only, all amounts in ₹)*

| ID | Requirement | Priority |
|----|-------------|----------|
| ~~MC-01~~ | ~~Support 150+ world currencies~~ | Removed |
| ~~MC-02~~ | ~~Auto-fetch exchange rates (daily updated)~~ | Removed |
| ~~MC-03~~ | ~~Lock exchange rate at time of expense entry~~ | Removed |
| ~~MC-04~~ | ~~Manual exchange rate override~~ | Removed |
| ~~MC-05~~ | ~~Show all balances in user's home currency with conversion~~ | Removed |
| MC-01 | All amounts in Indian Rupees (₹) only | P0 |

### 4.6 Notifications

| ID | Requirement | Priority |
|----|-------------|----------|
| NT-01 | Push notifications for: new expense added, expense edited/deleted, payment recorded, settlement reminder | P0 |
| NT-02 | In-app notification center with history | P0 |
| NT-03 | Configurable notification preferences (per group, per type) | P1 |
| NT-04 | Weekly/monthly summary notification (spending digest) | P2 |
| NT-05 | "Nudge" — send a friendly reminder to someone who owes you | P1 |

### 4.7 Search & Filters

| ID | Requirement | Priority |
|----|-------------|----------|
| SF-01 | Global search across all expenses, groups, and people | P0 |
| SF-02 | Filter expenses by: date range, category, payer, group, amount range | P0 |
| SF-03 | Sort expenses by: date, amount, category | P0 |

### 4.8 Analytics & Insights

| ID | Requirement | Priority |
|----|-------------|----------|
| AN-01 | Spending breakdown by category (pie/bar chart) | P0 |
| AN-02 | Monthly spending trend (line chart) | P1 |
| AN-03 | Group-level spending summary | P0 |
| AN-04 | Personal monthly summary card | P1 |
| AN-05 | Export expense data (CSV/PDF) | P1 |

### 4.9 Activity & Audit

| ID | Requirement | Priority |
|----|-------------|----------|
| AU-01 | Complete activity log per group (who added/edited/deleted what, when) | P0 |
| AU-02 | Per-expense change history (audit trail) | P0 |
| AU-03 | Show "created by" and "last modified by" on every expense | P0 |

---

## 5. Non-Functional Requirements

### 5.1 Offline-First Architecture

| ID | Requirement | Priority |
|----|-------------|----------|
| OF-01 | **All core features must work offline** — add/edit/delete expenses, view balances, record settlements, browse history | P0 |
| OF-02 | Local-first data storage (Hive/sqflite) with Firestore offline persistence as primary data sources | P0 |
| OF-03 | Background sync when connectivity is restored (queue-based) | P0 |
| OF-04 | Conflict resolution strategy for concurrent offline edits (last-write-wins with user notification for critical conflicts) | P0 |
| OF-05 | Visual sync status indicators (synced ✓, pending ↑, conflict ⚠) | P0 |
| OF-06 | Manual sync trigger option | P1 |
| OF-07 | Sync over Wi-Fi only option (data saver mode) | P2 |

### 5.2 Performance

| ID | Requirement | Priority |
|----|-------------|----------|
| PF-01 | App cold start < 2 seconds | P0 |
| PF-02 | Expense entry to save < 500ms (local) | P0 |
| PF-03 | Balance recalculation < 1 second for groups up to 50 members | P0 |
| PF-04 | Support groups up to 100 members | P1 |
| PF-05 | Smooth scrolling for 10,000+ expenses in history | P0 |
| PF-06 | App size < 30MB (initial download) | P1 |

### 5.3 Security & Privacy

| ID | Requirement | Priority |
|----|-------------|----------|
| SP-01 | End-to-end encryption for data in transit (TLS 1.3) | P0 |
| SP-02 | Encryption at rest for local database | P0 |
| SP-03 | Firebase Authentication with secure token management | P0 |
| SP-04 | Biometric/PIN lock for app access | P1 |
| SP-05 | No third-party analytics/tracking SDKs that share data | P0 |
| SP-06 | GDPR & CCPA compliant data handling | P0 |
| SP-07 | Privacy-first: minimal data collection, transparent privacy policy | P0 |
| SP-08 | Firebase Security Rules for Firestore and Cloud Storage access control | P0 |
| SP-09 | Rate limiting and abuse protection via Cloud Functions | P0 |

### 5.4 Scalability & Reliability

| ID | Requirement | Priority |
|----|-------------|----------|
| SR-01 | Firebase auto-scaling to support 100K+ concurrent users | P1 |
| SR-02 | 99.9% uptime (Firebase SLA) | P1 |
| SR-03 | Firestore automatic scaling (no manual sharding required) | P1 |
| SR-04 | Firebase CDN for static assets, receipt images, and web app hosting | P1 |

### 5.5 Accessibility

| ID | Requirement | Priority |
|----|-------------|----------|
| AC-01 | WCAG 2.1 AA compliance | P1 |
| AC-02 | Screen reader support (VoiceOver / TalkBack) | P1 |
| AC-03 | Dynamic text sizing support | P1 |
| AC-04 | High contrast mode | P2 |
| AC-05 | Haptic feedback for key actions | P2 |

---

## 6. UI/UX Requirements

### 6.1 Design Principles

1. **Minimal & Clean** — No visual clutter. Every screen has a single clear purpose.
2. **Fast Entry** — Adding an expense should take < 10 seconds for the common case (equal split).
3. **Glanceable** — Balances, who-owes-whom, and group status visible at a glance.
4. **Forgiving** — Undo support, draft saving, and confirmation for destructive actions.
5. **Delightful** — Subtle animations, haptic feedback, and micro-interactions.
6. **Ad-Free Forever** — No banner ads, interstitials, or sponsored content. Ever.

### 6.2 Core Screens

| Screen | Purpose | Key Elements |
|--------|---------|-------------|
| **Home / Dashboard** | Overview of all balances | Total owed/owing summary, recent activity feed, quick-add FAB, group list |
| **Group Detail** | Group expenses & balances | Expense list, member balances, settle up button, group settings |
| **Add Expense** | Log a new expense | Amount input (large, prominent), payer selector, participant selector, split type picker, category, notes, receipt attach |
| **Expense Detail** | View/edit single expense | Full details, split breakdown per person, edit/delete actions, receipt view, audit history |
| **Settle Up** | Record payments | Suggested settlements, manual payment entry, payment confirmation |
| **Activity Feed** | Timeline of all actions | Chronological list of expenses, payments, edits, deletions across all groups |
| **Profile & Settings** | User preferences | Language, notification preferences, theme, data export, account management |
| **Analytics** | Spending insights | Category breakdown charts, monthly trends, group comparisons |
| **Search** | Find expenses/groups | Full-text search with filters |

### 6.3 Theme & Appearance

| Property | Specification |
|----------|--------------|
| Design system | Material Design 3 (Flutter Material library) — consistent across Android, iOS, and Web |
| Light mode | Yes (default) |
| Dark mode | Yes (auto + manual toggle) |
| Color palette | Calming, trust-evoking (greens, blues, neutrals). Red/orange for amounts owed, green for amounts owed to you |
| Typography | System fonts for performance; clean hierarchy (amount = bold/large, descriptions = regular) |
| Iconography | Rounded, friendly icons for categories and actions |
| Animations | Subtle spring animations for transitions, swipe gestures for common actions (swipe to settle, swipe to edit) |

---

## 7. Platform Requirements

| Platform | Technology | Priority |
|----------|------------|----------|
| **Android + iOS** | Flutter (Dart) — single codebase for both platforms | P0 |
| **Web App** | Flutter Web (PWA) | P1 |
| **Backend** | Google Firebase (Authentication, Firestore, Cloud Functions, Cloud Storage, Cloud Messaging) | P0 |
| **Minimum Android** | Android 8.0 (API 26) | P0 |
| **Minimum iOS** | iOS 15.0 | P0 |
| **Languages** | English, Hindi | P0 |

### 7.1 Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (Dart) |
| **State Management** | Riverpod / Bloc |
| **Local Database** | Hive / sqflite (offline-first storage) |
| **Backend** | Google Firebase |
| **Authentication** | Firebase Authentication (Phone/OTP) |
| **Database (Cloud)** | Cloud Firestore (NoSQL, real-time sync) |
| **Server Logic** | Firebase Cloud Functions (Node.js/TypeScript) |
| **File Storage** | Firebase Cloud Storage |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **Analytics** | Firebase Analytics (privacy-compliant, first-party only) |
| **Crash Reporting** | Firebase Crashlytics |
| **Remote Config** | Firebase Remote Config (feature flags) |
| **Hosting** | Firebase Hosting (web app) |

---

## 8. Backend & Infrastructure Requirements

### 8.1 Firebase Services Mapping

| Firebase Service | Responsibility |
|-----------------|---------------|
| **Firebase Auth** | Phone/OTP authentication, session management, user identity |
| **Cloud Firestore** | Primary cloud database — users, groups, expenses, balances, settlements, activity logs. Real-time listeners for live updates |
| **Cloud Functions** | Server-side logic — debt simplification, recurring expense scheduling, settlement calculations, notification triggers, data validation & security |
| **Cloud Storage** | Receipt image uploads and storage |
| **Cloud Messaging (FCM)** | Push notifications — new expenses, settlements, reminders, nudges |
| **Firebase Crashlytics** | Crash reporting and stability monitoring |
| **Firebase Analytics** | First-party usage analytics (no third-party data sharing) |
| **Firebase Remote Config** | Feature flags, A/B testing, gradual rollouts |

### 8.2 Data Storage

| Store | Use Case |
|-------|----------|
| **Cloud Firestore** | Primary NoSQL cloud database for all app data (users, groups, expenses, balances). Provides real-time sync, offline persistence, and automatic conflict resolution |
| **Hive / sqflite** | Local on-device database for offline-first storage, draft expenses, and cached data |
| **Firebase Cloud Storage** | Receipt images, group cover photos, user avatars |

### 8.3 API & Communication Design

- **Firestore real-time listeners** for live balance updates and group activity feed (replaces REST polling / WebSocket)
- **Cloud Functions (HTTPS callable)** for complex server-side operations (debt simplification, bulk operations, data exports)
- **Cloud Functions (Firestore triggers)** for reactive logic — auto-recalculate balances on expense write, send notifications on settlement
- **Firebase Security Rules** for fine-grained access control at the document level
- Rate limiting via Cloud Functions middleware

### 8.4 Sync Protocol

```
┌─────────────────┐          ┌──────────────────────┐
│  Local Cache     │◄────────►│  Firestore SDK       │
│ (Hive/sqflite)  │          │  (offline persistence │
│                  │          │   + sync engine)      │
└─────────────────┘          └──────────┬────────────┘
                                        │
                        ┌───────────────▼───────────────┐
                        │   Cloud Firestore (Backend)   │
                        │  - Real-time sync             │
                        │  - Automatic conflict         │
                        │    resolution (last-write)    │
                        │  - Security rules             │
                        └───────────────┬───────────────┘
                                        │
                        ┌───────────────▼───────────────┐
                        │  Cloud Functions (Triggers)   │
                        │  - Balance recalculation      │
                        │  - Notification dispatch      │
                        │  - Data validation            │
                        └───────────────────────────────┘
```

- **Firestore offline persistence** enabled by default — SDK handles caching, queuing, and sync automatically
- Conflict resolution: Firestore's last-write-wins for standard fields; Cloud Functions validate critical fields (e.g., amount changes trigger audit log entries)
- Sync granularity: Per-document (Firestore native)
- Additional local storage (Hive/sqflite) for app-specific caches, drafts, and computed data not stored in Firestore

---

## 9. Monetization Strategy

> Core principle: **Never paywall essential expense-splitting features.**

| Tier | Price | Features |
|------|-------|----------|
| **Free** | ₹0 | All core features: unlimited expenses, groups, members, splits, balances, basic analytics, offline mode, ad-free |
| **OneByTwo Pro** | ~₹249/month or ₹1,999/year | Receipt OCR scanning, advanced analytics (detailed charts, trends, comparisons), custom categories & tags, priority support, data export (CSV/PDF), custom themes & app icons |

### Revenue Alternatives (No Ads Ever)
- Voluntary tips / "Buy us a coffee" in-app
- B2B/Team plans for offices/organizations
- Whitelabel licensing for fintech partners

---

## 10. Data Model (High-Level ERD)

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐
│   User   │────<│ GroupMember   │>────│    Group     │
│──────────│     │──────────────│     │──────────────│
│ id       │     │ user_id      │     │ id           │
│ name     │     │ group_id     │     │ name         │
│ email    │     │ role         │     │ category     │
│ phone    │     │              │     │              │
│ avatar   │     │ joined_at    │     │ cover_photo  │
│ language │     └──────────────┘     │ created_by   │
└──────────┘                          │ archived     │
      │                               └──────────────┘
      │                                      │
      │         ┌──────────────┐              │
      └────────<│   Expense    │>─────────────┘
                │──────────────│
                │ id           │
                │ group_id     │
                │ description  │
                │ amount (₹)   │
                │ date         │
                │ category     │
                │ created_by   │
                │ is_recurring │
                │ version      │
                │ sync_status  │
                └──────┬───────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
  ┌───────▼──────┐ ┌──▼─────────┐ ┌▼──────────────┐
  │ ExpensePayer │ │ExpenseSplit│ │ ExpenseAttach  │
  │──────────────│ │────────────│ │────────────────│
  │ expense_id   │ │ expense_id │ │ expense_id     │
  │ user_id      │ │ user_id    │ │ file_url       │
  │ amount_paid  │ │ amount_owed│ │ type           │
  └──────────────┘ │ percentage │ └────────────────┘
                   └────────────┘
                   
  ┌──────────────┐     ┌──────────────┐
  │  Settlement  │     │ ActivityLog  │
  │──────────────│     │──────────────│
  │ id           │     │ id           │
  │ group_id     │     │ group_id     │
  │ from_user    │     │ user_id      │
  │ to_user      │     │ action       │
  │ amount (₹)   │     │ entity_type  │
  │ date         │     │ details      │
  │ version      │     │ timestamp    │
  │ sync_status  │     └──────────────┘
  └──────────────┘
```

---

## 11. Key Algorithms

### 11.1 Debt Simplification

The app must implement an optimized debt simplification algorithm to minimize the total number of transactions required to settle all debts within a group.

**Algorithm:** Net-balance approach
1. Calculate net balance for each member (total paid - total owed)
2. Separate into creditors (positive) and debtors (negative)
3. Match largest debtor with largest creditor
4. Transfer the minimum of their absolute amounts
5. Remove settled parties, repeat until all balanced

**Constraint:** The simplified settlement must be mathematically equivalent to the original debts (total money transferred may differ, but net result per person is identical).

### ~~11.2 Multi-Currency Conversion~~ *(Removed — ₹ only)*

~~- Store expenses in original currency~~
~~- Convert to group currency or user's home currency for display~~
~~- Use rate at time of expense creation (locked rate) for balance calculations~~
~~- Allow manual rate override~~

---

## 12. Testing Requirements

| Type | Coverage Target | Tools |
|------|-----------------|-------|
| Unit tests | 80%+ code coverage | Flutter test framework (flutter_test) |
| Widget tests | All core UI components | Flutter widget testing |
| Integration tests | All Cloud Functions, Firestore rules, sync flow | Firebase Emulator Suite, flutter_test |
| UI/E2E tests | Critical user journeys (add expense, settle, sync) | Flutter integration_test, Patrol / Maestro |
| Offline tests | All offline scenarios (add, edit, delete, sync) | Firebase Emulator Suite with network simulation |
| Performance tests | Load testing for Cloud Functions | Firebase Performance Monitoring, k6 |
| Security tests | OWASP Mobile Top 10, Firestore security rules | Firebase Security Rules unit tests, SAST tools |

---

## 13. Launch Plan & Milestones

### Phase 1 — MVP (P0 Features)
- User auth (mobile OTP)
- Groups (create, invite, manage)
- Expenses (add, edit, delete, equal/custom splits)
- Balances & debt simplification
- Settlements
- Offline-first with sync
- Basic analytics (category breakdown)
- Push notifications
- Search
- Ad-free, clean UI

### Phase 2 — Enhanced (P1 Features)
- Itemized bill splitting
- Receipt photo attachment
- Recurring expenses
- Group roles & permissions
- Nudge/reminders
- Data export (CSV/PDF)
- Web app (PWA)
### Phase 3 — Premium & Growth (P2 Features)
- Receipt OCR scanning
- Advanced analytics & trends
- Custom tags & categories
- Bulk expense entry
- B2B/Team plans

---

## 14. Success Metrics

| Metric | Target (6 months post-launch) |
|--------|-------------------------------|
| Monthly Active Users (MAU) | 50,000+ |
| Expense entry completion rate | > 90% |
| App store rating | ≥ 4.5 stars |
| Crash-free rate | > 99.5% |
| Sync success rate | > 99.9% |
| Average expense entry time | < 10 seconds |
| Day-7 retention | > 40% |
| Day-30 retention | > 25% |

---

## 15. Open Questions for Architecture Discussion

1. **Flutter state management** — Riverpod vs Bloc vs Provider? Recommend based on team familiarity and app complexity.
2. **Local storage strategy** — Hive vs sqflite vs Isar for offline-first caching alongside Firestore? Trade-offs between performance, query capability, and Firestore sync.
3. **Firestore data modeling** — Optimal document/collection structure for expenses, balances, and groups? Subcollections vs root collections? Denormalization strategy for read performance.
4. **Cloud Functions runtime** — Node.js (TypeScript) vs Python vs Go for Cloud Functions?
5. **Receipt OCR** — Google Cloud Vision API (via Cloud Functions) vs Firebase ML Kit (on-device)?
6. **Guest/link-based users** — How to handle Firestore data migration when a guest later creates a Firebase Auth account?
7. **Firestore region** — Best Firebase/Firestore region for Indian users (asia-south1 Mumbai recommended)?
8. **Offline conflict edge cases** — How to handle conflicts beyond Firestore's last-write-wins (e.g., two users editing same expense offline)?
9. **Firestore cost optimization** — Read/write cost management strategies (caching, batching, pagination) to stay within budget at scale.

---

## Appendix A: Glossary

| Term | Definition |
|------|-----------|
| **Expense** | A cost incurred by one or more payers, shared among one or more participants |
| **Split** | The division of an expense among participants |
| **Settlement** | A payment made from one user to another to reduce or clear a debt |
| **Debt Simplification** | Algorithm to reduce the number of individual transactions needed to settle all debts in a group |
| **Sync** | The process of reconciling local (offline) data with the cloud database |
| **Guest User** | A participant in a group who does not have a registered account |

---

## Appendix B: References

- Splitwise feature documentation & user reviews (Trustpilot, Product Hunt, ComplaintsBoard)
- SettleUp (settleup.io) feature documentation
- Tricount vs SettleUp comparison (relatioo.com)
- Google Material Design: UX Design for Offline (design.google)
- Android Developers: Build an offline-first app
- Hasura: Design Guide for Building Offline-First Apps
- Open source alternatives: Spliit (GitHub), SplitPro
- Splitwise community feedback portal (feedback.splitwise.com)

---

*This document is intended to serve as the single source of truth for the OneByTwo product. It should be handed off to the system architect for technical architecture design, database schema finalization, and sprint planning.*
