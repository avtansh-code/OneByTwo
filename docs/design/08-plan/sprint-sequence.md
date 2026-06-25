# Sprint Sequence — One By Two v1.0

## Assumptions

- **Sprint cadence:** two-week sprints, six sprints to feature-complete release candidate.
- **Team capacity:** to be determined by stakeholder. Story-point totals per sprint are presented as planned load; actual velocity will be calibrated after sprint 1 and capacity adjusted accordingly.
- **Priority policy (SRS section 11):** all P0 items (46 FRs, 146 SP per backlog) must be completed for v1.0 launch. P1 items (16 FRs, 40 SP) are strongly desired but descope-eligible under timeline pressure; any descoped P1 items move to a fast-follow release. No P2 items exist in the current backlog.
- **Story-point source:** sprint 1 story points are taken from `docs/sprint-zero/sprint-1-plan.md` (authoritative, refined estimates). Sprints 2 and 4 through 6 (the feature sprints) use the Fibonacci estimates from `docs/sprint-zero/backlog.md`; the new Sprint 3 (Design Conversion) is sized separately in `docs/sprint-zero/sprint-3-plan.md`. These will be refined during each sprint's planning session.
- **Infrastructure stories:** INFRA-01 and FUNC-01 are not counted in the backlog's 62 FRs / 186 SP total. They add 13 SP of enabling work in sprint 1.
- **Design Conversion sprint (new Sprint 3):** the Haldi visual-system migration is additive enabling work (like INFRA-01 / FUNC-01) — it delivers no functional requirement, so it is not part of the 62-FR / 186-SP backlog and is excluded from the FR cumulative and P0-completion totals below. Its story points are set in `docs/sprint-zero/sprint-3-plan.md`.
- **Extension-point fields (ARCH-EXT-01 through ARCH-EXT-07):** per `docs/design/03-architecture/extension-points.md`, every document created in v1.0 must write extension-point fields with their stated default values. The relevant extension points are called out in each sprint where the document type is first created.

---

## Programme Totals and Reconciliation

| Source | FRs | SP | Notes |
|---|---|---|---|
| Product backlog (`docs/sprint-zero/backlog.md`) | 62 | 186 | Canonical FR count and estimates |
| Sprint 1 re-estimation uplift | — | +9 | Sprint planning refined 9 auth/profile stories upward from 21 SP (backlog) to 30 SP (sprint-1-plan) |
| Infrastructure stories (INFRA-01, FUNC-01) | — | +13 | Enabling work outside the FR backlog |
| **Programme total** | **62 FRs + 2 infra** | **208** | Across sprints 1–6 (Sprint 3 = Design Conversion, SP set in `sprint-3-plan.md`); sprint 7 carries no new SP |

### SP by Sprint

| Sprint | Theme | New SP | Cumulative SP |
|---|---|---|---|
| 1 | Foundation and Authentication | 43 | 43 |
| 2 | Friends and Core Expenses | 50 | 93 |
| 3 | Design Conversion (Haldi) | TBD (enabling; set in `sprint-3-plan.md`) | 93 |
| 4 | Groups and Settlements | 38 | 131 |
| 5 | Notifications, Activity, Dashboard | 28 | 159 |
| 6 | Polish, Support, Offline, Search | 49 | 208 |
| 7 | QA, Performance, Release Prep | 0 (bug-fix budget) | 208 |

---

## Sprint 1: Foundation and Authentication

**Goal:** Establish a fully authenticated user entry path (phone OTP login through profile setup) with the foundational Firebase infrastructure, CI pipeline, and the simplified-debts contract stub so that all subsequent feature sprints can build on a proven, tested base.

> This sprint is defined in `docs/sprint-zero/sprint-1-plan.md` and is reproduced here verbatim.

### Stories

| ID | Title | Priority | SP | Responsible Agents |
|---|---|---|---|---|
| INFRA-01 | Firebase project configuration, emulator suite, CI pipeline | P0 | 8 | DevOps, Architect |
| FR-AU-01 | Phone number login with locked +91 prefix | P0 | 3 | Flutter Dev, QA |
| FR-AU-02 | Indian mobile number validation | P0 | 2 | Flutter Dev, QA |
| FR-AU-03 | OTP dispatch via Firebase Phone Auth | P0 | 5 | Flutter Dev, QA |
| FR-AU-04 | OTP auto-read (Android) and manual entry (iOS) | P0 | 3 | Flutter Dev, QA |
| FR-AU-05 | OTP resend with cooldown and retry cap | P0 | 3 | Flutter Dev, QA |
| FR-AU-06 | First-time profile setup prompt | P0 | 5 | Flutter Dev, QA |
| FR-AU-07 | Session persistence and auto-login | P0 | 2 | Flutter Dev, QA |
| FR-AU-08 | Sign out from Profile screen | P0 | 2 | Flutter Dev, QA |
| FR-PR-01 | View and edit profile (display name and photo) | P0 | 5 | Flutter Dev, QA |
| FUNC-01 | Simplified-debts pure function stub with canonical test suite | P0 | 5 | Functions Dev, Architect, QA |
| | **Total** | | **43** | |

### Extension-Point Obligations

- **ARCH-EXT-04 (locale on user documents):** FR-AU-06 creates the `users/{userId}` document. Every user document must include `locale: 'en-IN'` at creation time (`docs/design/03-architecture/extension-points.md`, ARCH-EXT-04).

### Design Artefacts Required Beforehand

| Artefact | Path |
|---|---|
| Information architecture — navigation flow | `docs/design/01-information-architecture/navigation-flow.md` |
| Design system — tokens and typography | `docs/design/02-design-system/tokens.md`, `docs/design/02-design-system/typography-and-formatting.md` |
| Wireframes — auth flow | `docs/design/04-wireframes/auth-flow.md` |
| Screen specs — auth and profile setup | `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` |
| Mockups — splash/onboarding, phone/OTP | `docs/design/05-mockups/01-splash-and-onboarding.html`, `docs/design/05-mockups/02-phone-and-otp.html` |
| Firestore schema (users collection) | `docs/design/07-technical/firestore-schema.md` |
| Firestore security rules | `docs/design/07-technical/firestore-security-rules.md` |
| Simplified-debts algorithm specification | `docs/design/07-technical/simplified-debts-algorithm.md` |
| Architecture extension points | `docs/design/03-architecture/extension-points.md` |

### Demo at Sprint End

User can install the app, enter a +91 phone number, receive and verify an OTP, complete first-time profile setup (display name and optional photo), be auto-logged-in on subsequent launches, view and edit their profile, and sign out. The simplified-debts pure function passes all six canonical test cases in CI. The emulator suite runs locally and the PR pipeline gates all merges to `main`.

### Risks

1. INFRA-01 is on the critical path; all Flutter stories are blocked until the emulator suite and CI pipeline are operational.
2. FR-AU-03 and FR-AU-04 carry platform-specific risk around SMS Retriever behaviour on Android emulators.
3. FR-AU-06 and FR-PR-01 share UI surface; the Architect should flag shared component extraction in technical design.

---

## Sprint 2: Friends and Core Expenses

**Goal:** Deliver the friend-management lifecycle and the complete expense-creation flow with all five split methods, backed by the fully implemented simplified-debts Cloud Function, so that two users can add each other as friends, record shared expenses, and see correct simplified balances.

### Stories

| ID | Title | Priority | SP | Responsible Agents |
|---|---|---|---|---|
| FR-FR-01 | Add friend by contact picker or +91 number | P0 | 3 | Flutter Dev, QA |
| FR-FR-02 | Link existing user or invite via system share sheet | P0 | 3 | Flutter Dev, QA |
| FR-FR-03 | Friends list with simplified net balance | P0 | 3 | Flutter Dev, QA |
| FR-FR-04 | Per-friend transaction history | P0 | 3 | Flutter Dev, QA |
| FR-EX-01 | Add expense (amount, description, date, category, payer, split, notes) | P0 | 5 | Flutter Dev, QA |
| FR-EX-02 | Expense in friend context | P0 | 2 | Flutter Dev, QA |
| FR-EX-03 | Split methods: Equal, Unequal, Percentage, Shares, Exact | P0 | 5 | Flutter Dev, QA |
| FR-EX-04 | Validate splits sum to total; block save on mismatch | P0 | 2 | Flutter Dev, QA |
| FR-EX-08 | Predefined expense categories with icons | P0 | 2 | Flutter Dev, Designer |
| FR-EX-09 | INR symbol and Indian numbering format | P0 | 1 | Flutter Dev, QA |
| FR-SE-01 | Display only simplified debts as canonical balance view | P0 | 3 | Flutter Dev, QA |
| FR-SE-02 | Deterministic min-transactions simplified-debts algorithm | P0 | 8 | Functions Dev, QA |
| FR-SE-03 | Cloud Function writes simplifiedBalances; client reads only | P0 | 5 | Functions Dev, Architect, QA |
| FR-SE-04 | Atomic recomputation on expense/settlement write | P0 | 5 | Functions Dev, QA |
| | **Total** | | **50** | |

### Extension-Point Obligations

- **ARCH-EXT-02 (currency on expenses):** every expense document must include `currency: 'INR'`.
- **ARCH-EXT-03 (recurringRule on expenses):** every expense document must include `recurringRule: null`.
- **ARCH-EXT-07 (source on expenses):** every expense document must include `source: 'manual'`.
- All per `docs/design/03-architecture/extension-points.md`.

### Design Artefacts Required Beforehand

| Artefact | Path |
|---|---|
| Wireframes — friends flow | `docs/design/04-wireframes/friends-flow.md` |
| Wireframes — expense flow | `docs/design/04-wireframes/expense-flow.md` |
| Screen specs — friends | `docs/design/06-screen-specs/09-12-friends.md` |
| Screen specs — expenses | `docs/design/06-screen-specs/19-22-expenses.md` |
| Mockups — add expense bottom sheet | `docs/design/05-mockups/04-add-expense-bottom-sheet.html` |
| Cloud Functions catalogue | `docs/design/07-technical/cloud-functions-catalogue.md` |
| Firestore schema (friendships, expenses collections) | `docs/design/07-technical/firestore-schema.md` |
| Simplified-debts algorithm (full specification) | `docs/design/07-technical/simplified-debts-algorithm.md` |
| State management design | `docs/design/07-technical/state-management.md` |
| Design system — components | `docs/design/02-design-system/components.md` |
| Architecture extension points | `docs/design/03-architecture/extension-points.md` |
| Data flow diagram | `docs/design/03-architecture/data-flow.md` |

### Demo at Sprint End

A user adds a friend (by contact picker or phone number), creates an expense with an equal split, and sees the simplified balance update in real time on the friends list. A second expense using percentage split is created. The friend's transaction history shows both expenses. All amounts display in INR with Indian numbering format (e.g., 1,00,000). The Cloud Function correctly computes and writes simplified balances; the client reads them without writing.

### Dependencies and Notes

1. FR-SE-02 upgrades the FUNC-01 stub from sprint 1 into the full, optimised algorithm. This is the highest single-story effort in the sprint (8 SP) and is on the critical path for all balance display.
2. FR-FR-02 depends on FR-SH-01 (system share sheet), which is scheduled for sprint 5. In sprint 2, the invite path will use the system share sheet directly without the deep-link store-fallback URL (FR-SH-02). The share-sheet integration must comply with Invariant 3 (system share sheet only; SRS section 3.4).
3. FR-EX-02 covers the friend context in this sprint. The group context portion is exercised in sprint 4 once groups exist.

---

## Sprint 3: Design Conversion

**Goal:** Migrate the already-built app and the shared component library onto the
**"Direction A — Haldi"** visual system (`design_handoff_one_by_two/`, adopted by ADR-0024):
the token + type foundation (`lib/app/theme.dart` → Haldi marigold palette + Bricolage
Grotesque / Hanken Grotesk), the shared-component reskin plus the new Haldi components,
per-flow screen conversion (Auth, Home, Friends, Expenses, Settlements, Activity, Profile),
dark-mode parity for every hero screen, accessibility re-verification against the new palette,
and a visual-regression / golden-test harness — with **zero change** to the data model,
Firestore security rules, the simplified-debts algorithm, or Cloud Functions.

> Stories, acceptance criteria, story points, Definition of Ready/Done, the sprint-end demo,
> risks, and the critical path are defined in `docs/sprint-zero/sprint-3-plan.md`. The visual
> source of truth is `design_handoff_one_by_two/` (ADR-0024); it supersedes the old
> visual-layer docs (`docs/design/02-design-system/*`, `04-wireframes/*`, `05-mockups/*`,
> `06-screen-specs/*`). The four invariants are re-affirmed: integer paise (rupee display only
> via `formatInrFromPaise()`), `simplifiedBalances` server-written / client-read-only, OS
> system share sheet only, single Firebase project. SRS §6.2/§6.3 are reconciled via the PM
> `update-srs` proposal (`docs/sprint-zero/srs-update-proposal-haldi.md`).

### Story Points

The Design Conversion sprint is **additive enabling work** (like INFRA-01 / FUNC-01 in
Sprint 1): it delivers no new functional requirement and carries no P0 FR SP, so it does not
appear in the FR-backlog cumulative or the P0-completion curves below. Its story-point total
is set in `docs/sprint-zero/sprint-3-plan.md`.

### Demo at Sprint End

Every converted hero screen (Home, Friends list, Settle up, Add-expense, Activity) renders in
the Haldi visual language in light **and** dark mode; the shared `OBT*` components and the new
Haldi components (skeleton loaders, balance pill, category chip/tile, and the rest) are in use;
contrast and dynamic-type (to 2.0×) checks pass against the verified Haldi pairings; the
golden-test harness proves the conversion is non-regressing. No application behaviour, balance
figure, or backend contract changes.

### Dependencies and Notes

1. **PR #1 is the token + type foundation** (`lib/app/theme.dart` → Haldi) and blocks every
   other conversion story; it is the critical path.
2. Every built surface now has a Haldi target — the change-phone OTP re-verification flow
   (FR-PR-02) was designed as Haldi Phase3g (2026-06-25), closing the last gap; it converts
   within DC-10. See `docs/audits/design-conversion/01-coverage-gap.md`.
3. The not-yet-built screens (Groups 14–20, Search, Onboarding) are **not** converted here;
   they are built directly in Haldi in the feature sprints that own them (Groups in Sprint 4).

---

## Sprint 4: Groups and Settlements

**Goal:** Deliver the full group lifecycle (create, invite, manage members, delete) and the settlement flow (settle up, history, real-time balance updates), enabling multi-party expense splitting and debt resolution within groups.

### Stories

| ID | Title | Priority | SP | Responsible Agents |
|---|---|---|---|---|
| FR-GR-01 | Create group (name, type, optional cover photo) | P0 | 3 | Flutter Dev, QA |
| FR-GR-02 | Invite members via picker, phone, or share-sheet link | P0 | 3 | Flutter Dev, QA |
| FR-GR-03 | Invite link expiry (7 days) and admin revocation | P0 | 3 | Flutter Dev, Functions Dev, QA |
| FR-GR-04 | View group expenses, member balances, and activity | P0 | 5 | Flutter Dev, QA |
| FR-GR-05 | Admin remove member (zero balance guard) | P0 | 2 | Flutter Dev, QA |
| FR-GR-06 | Member leave group (zero balance guard) | P0 | 2 | Flutter Dev, QA |
| FR-GR-07 | Admin delete group (all balances zero guard) | P0 | 2 | Flutter Dev, QA |
| FR-SE-05 | Record settlement with pre-filled Settle Up UI | P0 | 3 | Flutter Dev, QA |
| FR-SE-06 | Real-time simplified balance update on settlement | P0 | 3 | Functions Dev, QA |
| FR-SE-07 | Settle Up CTA on every non-zero balance screen | P0 | 2 | Flutter Dev, QA |
| FR-SE-08 | Settlement history per friend and per group | P0 | 3 | Flutter Dev, QA |
| FR-EX-06 | Edit or delete own expense with real-time sync | P0 | 5 | Flutter Dev, Functions Dev, QA |
| FR-EX-07 | Record edits and deletes in activity feed | P0 | 2 | Flutter Dev, Functions Dev, QA |
| | **Total** | | **38** | |

### Extension-Point Obligations

- **ARCH-EXT-01 (settlement method):** every settlement document must include `method: 'manual'`.
- **ARCH-EXT-02 (currency on settlements):** every settlement document must include `currency: 'INR'`.
- **ARCH-EXT-06 (verification status):** every settlement document must include `verificationStatus: 'unverified'`. Security rules must enforce client-read-only on this field, mirroring the `simplifiedBalances` pattern (Invariant 2; SRS section 7.5).
- All per `docs/design/03-architecture/extension-points.md`.

### Design Artefacts Required Beforehand

> **Design-system DoR:** the visual source of truth for Sprint 4 is Haldi
> (`design_handoff_one_by_two/`, ADR-0024). The Groups UI is **not built yet**, so it
> is authored **directly in Haldi** (there is no built screen to convert). Every story
> builds on the Haldi token + component foundation delivered in Sprint 3
> (`docs/sprint-zero/sprint-3-plan.md`, DC-01–DC-03) and reuses the Sprint 3 shared
> component library; the two Groups-specific components — the group segmented tab bar
> and the stacked-avatar cluster — are authored here in Sprint 4 on top of that
> foundation, per `docs/audits/design-conversion/02-conversion-checklist.md`. No story
> opens until the Sprint 3 foundation is on `main`. The backend artefacts below
> (Firestore schema, security rules, extension points) are **unchanged**.

| Artefact | Path |
|---|---|
| Design system: Haldi (per ADR-0024 + the new Sprint 3 component library) | `design_handoff_one_by_two/README.md` |
| Haldi screens — Groups flow (authored directly in Haldi) | `design_handoff_one_by_two/` screens 14 (Groups list), 15 (Create group — name, type, optional cover), 18 (Group members — admin badge; remove only at zero balance), 19 (Leave / delete group — zero-balance guards), 20 (Group history) |
| Haldi screen — Group detail ★ (Expenses / Balances / Activity) | `design_handoff_one_by_two/` screen 16 — the **Balances** tab shows each member's simplified net plus the minimum set of payments to clear the whole group (for example "You pay Rahul ₹1,620"), and **never** a who-owes-who web (Invariant 2) |
| Haldi screen — Invite members | `design_handoff_one_by_two/` screen 17 — 7-day, admin-revocable invite link handed off to the **OS system share sheet only**, with +91 entry and multi-select contacts; no per-app buttons (Invariant 3) |
| Haldi screen — Settle up ★ | `design_handoff_one_by_two/` screen 23 — one pre-filled suggested payment (recipient + amount from `simplifiedBalances`), editable amount, disabled "Pay via UPI" slot ("Coming soon"); never a debt graph (Invariant 2) |
| Haldi screen — Settlement history | `design_handoff_one_by_two/` screen 24 — sent/received with direction icon + sign, per friend and per group; amounts via `formatInrFromPaise()` (FR-SE-08) |
| Haldi screen — View / edit / delete expense | `design_handoff_one_by_two/` screen 22 — creator-only edit form; delete confirm explains balance impact (FR-EX-06 / FR-EX-07) |
| Firestore schema (groups, settlements collections) | `docs/design/07-technical/firestore-schema.md` |
| Firestore security rules (settlement write constraints) | `docs/design/07-technical/firestore-security-rules.md` |
| Architecture extension points | `docs/design/03-architecture/extension-points.md` |

### Demo at Sprint End

A user creates a group, invites members via share-sheet link, adds a group expense with an unequal split, and sees per-member simplified balances on the group detail screen. One member settles up via the pre-filled Settle Up UI; the balance updates in real time. The user edits a prior expense; the edit is recorded in the activity feed and balances recompute. Settlement history is viewable per friend and per group. The admin removes a zero-balance member and subsequently deletes the group once all balances are zero.

### Dependencies and Notes

1. FR-EX-02 (expense in group context) is exercised here against the group infrastructure. The FR was delivered in sprint 2 for the friend context; sprint 4 validates and extends it to groups.
2. FR-EX-07 writes to the activity feed structure that FR-AC-01 (sprint 5) will formally surface in the Activity tab. In sprint 4, activity entries are written to Firestore but not yet displayed in a dedicated tab; they appear within the group detail view (FR-GR-04).
3. FR-SE-06 depends on FR-SE-04 (sprint 2) for atomic recomputation.

---

## Sprint 5: Notifications, Activity, Dashboard

**Goal:** Deliver the home dashboard as the primary entry surface, the activity feed as the chronological event log, push notifications via FCM, deep-linking from notifications and activity items, and the system share-sheet integration with deep-link URLs.

### Stories

| ID | Title | Priority | SP | Responsible Agents |
|---|---|---|---|---|
| FR-AC-01 | Activity tab with chronological event feed | P0 | 5 | Flutter Dev, QA |
| FR-AC-02 | Deep-link from activity item to relevant screen | P0 | 3 | Flutter Dev, QA |
| FR-AC-03 | Push notifications via FCM for expenses, settlements, reminders | P0 | 5 | Functions Dev, Flutter Dev, QA |
| FR-AC-05 | Notification tap deep-links to relevant screen (incl. cold start) | P0 | 3 | Flutter Dev, QA |
| FR-HD-01 | Overall net simplified balance as primary element | P0 | 3 | Flutter Dev, QA |
| FR-HD-02 | Top 5 friends/groups by balance with quick Settle Up | P0 | 3 | Flutter Dev, QA |
| FR-HD-04 | Persistent FAB for adding expense from any tab | P0 | 2 | Flutter Dev, QA |
| FR-SH-01 | All outbound sharing via system share sheet only | P0 | 2 | Flutter Dev, QA |
| FR-SH-02 | Shared messages include deep link and store fallback URL | P0 | 2 | Flutter Dev, QA |
| | **Total** | | **28** | |

### Extension-Point Obligations

- **ARCH-EXT-05 (notification channel expansion):** the Cloud Functions notification module must use a strategy or dispatcher pattern (`docs/design/03-architecture/extension-points.md`, ARCH-EXT-05). Each trigger calls a `sendNotification(userId, payload)` function; the channel is resolved internally. This ensures adding new channels in v1.1 is additive.
- **ARCH-EXT-04 (locale on user documents):** Cloud Functions composing notification body text should read the `locale` field from the recipient's user document and select a string template, even though only `'en-IN'` exists in v1.0.

### Design Artefacts Required Beforehand

> **Design-system DoR:** the visual source of truth for Sprint 5 is Haldi
> (`design_handoff_one_by_two/`, ADR-0024). Home dashboard (6) and Activity feed (25)
> carry their Haldi conversion from Sprint 3; Sprint 5 lands their feature behaviour on
> those converted Haldi surfaces and the Sprint 3 shared component library (skeleton
> loaders, balance pill, empty-state scaffold, donut + 6-category legend). Every story
> builds on the Sprint 3 Haldi token + component foundation
> (`docs/sprint-zero/sprint-3-plan.md`); no story opens until that foundation is on
> `main`. The technical / IA artefacts below (notifications design, telemetry plan,
> user journeys, Cloud Functions catalogue) are **unchanged**.

| Artefact | Path |
|---|---|
| Design system: Haldi (per ADR-0024 + the new Sprint 3 component library) | `design_handoff_one_by_two/README.md` |
| Haldi screen — Home dashboard ★ | `design_handoff_one_by_two/` screen 6 — net simplified-balance hero, top balances with quick Settle, monthly-spend donut + 6-category legend, persistent FAB, 5-tab nav (light + dark) |
| Haldi screen — Add-expense context picker | `design_handoff_one_by_two/` screen 8 — FAB → search + Groups/Friends sections → opens the add sheet (FR-HD-04) |
| Haldi screen — Activity feed ★ | `design_handoff_one_by_two/` screen 25 — chronological expenses / settlements / reminders / group changes; rows deep-link to detail (light + dark) |
| Haldi screen — Push notifications and deep links | `design_handoff_one_by_two/` screen 26 — lock-screen banners; tap deep-links to the relevant screen, including cold start (FR-AC-05) |
| Notifications technical design | `docs/design/07-technical/notifications.md` |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` |
| Information architecture — user journeys | `docs/design/01-information-architecture/user-journeys.md` |
| Cloud Functions catalogue (notification triggers) | `docs/design/07-technical/cloud-functions-catalogue.md` |

### Demo at Sprint End

The home dashboard displays the user's overall net simplified balance and the top 5 friends/groups by outstanding balance, each with a Settle Up shortcut. The persistent FAB allows adding an expense from any tab. The Activity tab shows a chronological feed of expenses, settlements, and edits. Tapping an activity item deep-links to the relevant expense or settlement screen. A push notification arrives when another user adds an expense; tapping the notification (including on cold start) navigates to the correct screen. Outbound share messages include a deep link with a store fallback URL. All sharing uses the system share sheet exclusively (Invariant 3; SRS section 3.4).

---

## Sprint 6: Polish, Support, Offline, Search

**Goal:** Complete all remaining P0 and P1 functional requirements — profile extras, contact support, offline caching and sync, search and filters, receipt attachment, payment reminders, account deletion, and the monthly spend chart — to reach feature-complete status.

### Stories

| ID | Title | Priority | SP | Responsible Agents |
|---|---|---|---|---|
| FR-PR-02 | Update phone number via re-verification OTP | P1 | 3 | Flutter Dev, QA |
| FR-PR-03 | Set notification preferences per category | P1 | 2 | Flutter Dev, QA |
| FR-PR-04 | View list of friends and groups from profile | P0 | 2 | Flutter Dev, QA |
| FR-PR-05 | Contact Support via mailto with pre-filled fields | P0 | 2 | Flutter Dev, QA |
| FR-SH-03 | Contact Support mailto with Remote Config support address | P0 | 2 | Flutter Dev, QA |
| FR-SH-04 | Fallback dialog with copy button when no mail client | P1 | 1 | Flutter Dev, QA |
| FR-OF-01 | View cached expenses, friends, groups, balances offline | P0 | 3 | Flutter Dev, QA |
| FR-OF-02 | Queue expense/settlement writes offline; sync on reconnect | P1 | 5 | Flutter Dev, Functions Dev, QA |
| FR-OF-03 | Last-write-wins conflict resolution with user notification | P1 | 3 | Flutter Dev, Functions Dev, QA |
| FR-SR-01 | Search expenses by description, amount, category, member | P1 | 3 | Flutter Dev, QA |
| FR-SR-02 | Filter expenses by date range, group, category | P1 | 3 | Flutter Dev, QA |
| FR-EX-05 | Attach receipt image (camera/gallery) to expense | P1 | 3 | Flutter Dev, QA |
| FR-SE-09 | Send payment reminder (push, 1 per friend per 24h) | P1 | 3 | Functions Dev, Flutter Dev, QA |
| FR-AU-09 | Account deletion with data anonymisation | P1 | 5 | Functions Dev, Flutter Dev, QA |
| FR-FR-05 | Delete friend when balance is zero | P1 | 2 | Flutter Dev, QA |
| FR-HD-03 | Current-month spend summary with category chart | P1 | 5 | Flutter Dev, Designer, QA |
| FR-AC-04 | Notifications respect per-category preferences | P1 | 2 | Functions Dev, QA |
| | **Total** | | **49** | |

### Priority Breakdown

| Priority | Stories | SP |
|---|---|---|
| P0 | FR-PR-04, FR-PR-05, FR-SH-03, FR-OF-01 | 9 |
| P1 | All remaining 13 stories | 40 |
| **Total** | **17** | **49** |

### Design Artefacts Required Beforehand

> **Design-system DoR:** the visual source of truth for Sprint 6 is Haldi
> (`design_handoff_one_by_two/`, ADR-0024). The Profile & support surfaces (27–30) carry
> their Haldi conversion from Sprint 3; Sprint 6 lands the remaining P0/P1 behaviour on
> those converted Haldi surfaces and the Sprint 3 shared component library (offline /
> pending-sync banner, empty-state scaffold, category chip). Every story builds on the
> Sprint 3 Haldi token + component foundation (`docs/sprint-zero/sprint-3-plan.md`); no
> story opens until that foundation is on `main`. The **change-phone OTP re-verification
> (FR-PR-02) Haldi design landed** (Phase3g, 2026-06-25); it is converted in Sprint 3
> (DC-10), and its FR-PR-02 behaviour lands here on the converted surface
> (`docs/audits/design-conversion/01-coverage-gap.md` §C/§D). The technical artefacts
> below (offline-and-sync, error/empty-state taxonomy, Cloud Functions catalogue,
> accessibility spec) are **unchanged**.

| Artefact | Path |
|---|---|
| Design system: Haldi (per ADR-0024 + the new Sprint 3 component library) | `design_handoff_one_by_two/README.md` |
| Haldi screens — Profile & support | `design_handoff_one_by_two/` screens 27 (Profile view + edit — name + photo; +91 locked), 28 (Notification preferences — per-category toggles + disabled "Language" slot), 29 (Contact support — mail client pre-filled + copy-email fallback), 30 (Delete account — anonymise to "Former member", 30-day removal) |
| Haldi screen — Search & filters | `design_handoff_one_by_two/` screen 7 — focused field, date / group / category filters, recent searches → category-icon result rows (FR-SR-01 / FR-SR-02) |
| Haldi screen — Monthly-spend chart | `design_handoff_one_by_two/` screen 6 — current-month spend donut + 6-category legend (FR-HD-03) |
| Haldi screen — Receipt attachment | `design_handoff_one_by_two/` screen 21 (step 3) + 22 — receipt thumbnail / fullscreen viewer (FR-EX-05) |
| Change-phone OTP re-verification | `design_handoff_one_by_two/` **Phase3g** (Change Phone — added 2026-06-25): security-gated two-OTP flow (re-auth → new-phone → success) + "sync pending → Try again" recovery, masked, +91-only. Converted in Sprint 3 (DC-10); FR-PR-02 behaviour lands here on the converted surface (`docs/audits/design-conversion/01-coverage-gap.md`) |
| Offline and sync technical design | `docs/design/07-technical/offline-and-sync.md` |
| Error and empty state taxonomy | `docs/design/07-technical/error-and-empty-state-taxonomy.md` |
| Cloud Functions catalogue (account deletion, reminders) | `docs/design/07-technical/cloud-functions-catalogue.md` |
| Accessibility specification | `docs/design/07-technical/accessibility-spec.md` |

### Demo at Sprint End

Full application walkthrough covering all feature areas. Aeroplane mode is enabled to demonstrate offline cached data viewing; an expense is queued offline and syncs on reconnect. The Contact Support flow opens the device mail client with pre-filled diagnostic fields (or shows the fallback copy dialog on devices without a mail client). Search finds an expense by description; filters narrow results by date range and category. A receipt photo is attached to an expense. A payment reminder push notification is sent (rate-limited to one per friend per 24 hours). Account deletion is triggered and the user's data is anonymised. The monthly spend chart displays category breakdown for the current month.

### Descope Risk

Sprint 6 carries all 16 P1 items (40 SP). If velocity data from sprints 1 through 5 indicates that 49 SP exceeds sustainable capacity, the following P1 items are candidates for deferral to a fast-follow release, in descending order of descope eligibility:

| Descope Order | ID | Title | SP | Rationale |
|---|---|---|---|---|
| 1 | FR-HD-03 | Monthly spend chart | 5 | Informational only; no transactional impact |
| 2 | FR-SR-01 | Search expenses | 3 | Useful but not blocking core flows |
| 3 | FR-SR-02 | Filter expenses | 3 | Useful but not blocking core flows |
| 4 | FR-OF-03 | Last-write-wins conflict resolution | 3 | Can ship offline read (FR-OF-01, P0) without write sync initially |
| 5 | FR-OF-02 | Offline write queue | 5 | Depends on FR-OF-03; descoped together |
| 6 | FR-EX-05 | Receipt attachment | 3 | Enhancement to expense entry; not required for core split-and-settle |

Items 1 through 6 total 22 SP. Descoping all six would reduce sprint 6 to 27 SP (9 SP P0 + 18 SP remaining P1), a manageable load.

---

## Sprint 7: QA, Performance, Release Prep

**Goal:** Achieve release-candidate quality through comprehensive QA, performance profiling against NFR targets, accessibility audit, dark mode polish, and store listing preparation, culminating in a TestFlight and Play Internal build ready for alpha distribution (SRS section 11.1, phase 1).

### Activities

| Activity | Description | Responsible Agents |
|---|---|---|
| Bug fixes | Address all P0 and P1 defects from sprint 6 QA and any carry-over items | Flutter Dev, Functions Dev |
| Regression testing | Full test suite execution across all feature areas; canonical simplified-debts test cases must pass on the release commit (SRS section 11.2) | QA |
| Performance profiling | Validate against NFR targets (SRS section 5): cold start < 3 s, screen transitions < 300 ms, Firestore reads per screen load within budget | Flutter Dev, DevOps |
| Accessibility audit | VoiceOver (iOS) and TalkBack (Android) walkthroughs of all primary flows; remediate blockers per `docs/design/07-technical/accessibility-spec.md` | Flutter Dev, Designer, QA |
| Dark mode polish | Verify all screens render correctly in dark mode; fix contrast and token issues per `docs/design/02-design-system/tokens.md` | Flutter Dev, Designer |
| Release pipeline finalisation | Validate `.github/workflows/release.yml`; confirm signing, versioning, and artefact upload | DevOps |
| Store listing preparation | App icon, screenshots, description, age rating, data-safety form for Play Console and App Store Connect under the brand name **One By Two** (SRS section 11.2) | Designer, PM |
| Privacy and legal | Privacy policy and terms of service live and linked from the app; support email configured in Remote Config (SRS section 11.2) | PM |
| Hotfix and rollback runbooks | DevOps runbooks for hotfix, rollback, and incident response committed to the repository (SRS section 11.2) | DevOps |
| Telemetry review | Confirm all telemetry events from `docs/design/07-technical/telemetry-plan.md` fire correctly; review Crashlytics, Analytics, and Performance Monitoring dashboards | QA, DevOps |

### Launch Readiness Checklist (SRS section 11.2)

- [ ] All P0 functional requirements implemented and tested.
- [ ] All NFR targets met or formally accepted as known limitations.
- [ ] Privacy policy, terms of service, support email live and linked from the app.
- [ ] Play Console and App Store Connect listings complete.
- [ ] Firebase production project hardened: App Check enforced, Firestore rules deployed, indexes deployed, Cloud Functions deployed, billing alerts configured.
- [ ] Crashlytics, Analytics, and Performance Monitoring enabled and dashboards reviewed.
- [ ] DevOps runbooks committed.
- [ ] Simplified-debts canonical test cases pass in CI on the release commit.

### Demo at Sprint End

Release candidate build distributed via TestFlight (iOS) and Play Internal Testing track (Android). Full application walkthrough demonstrating all P0 features end to end. Performance metrics presented against NFR targets. Accessibility audit findings and remediations reviewed. Store listing screenshots and metadata presented for stakeholder approval.

---

## Backlog Reconciliation

### All 62 FRs Allocated

| Epic | FRs | Sprint(s) | Backlog SP | Notes |
|---|---|---|---|---|
| 1 — Authentication | FR-AU-01 to FR-AU-08 | 1 | 18 | Sprint-1-plan refined to 25 SP |
| 1 — Authentication | FR-AU-09 | 6 | 5 | P1 |
| 2 — Profile | FR-PR-01 | 1 | 3 | Sprint-1-plan refined to 5 SP |
| 2 — Profile | FR-PR-02 to FR-PR-05 | 6 | 9 | FR-PR-02, FR-PR-03 are P1 |
| 3 — Friends | FR-FR-01 to FR-FR-04 | 2 | 12 | All P0 |
| 3 — Friends | FR-FR-05 | 6 | 2 | P1 |
| 4 — Groups | FR-GR-01 to FR-GR-07 | 4 | 20 | All P0 |
| 5 — Expenses | FR-EX-01 to FR-EX-04, FR-EX-08, FR-EX-09 | 2 | 17 | All P0 |
| 5 — Expenses | FR-EX-06, FR-EX-07 | 4 | 7 | All P0 |
| 5 — Expenses | FR-EX-05 | 6 | 3 | P1 |
| 6 — Settlements | FR-SE-01 to FR-SE-04 | 2 | 21 | All P0 |
| 6 — Settlements | FR-SE-05 to FR-SE-08 | 4 | 11 | All P0 |
| 6 — Settlements | FR-SE-09 | 6 | 3 | P1 |
| 7 — Activity | FR-AC-01 to FR-AC-03, FR-AC-05 | 5 | 16 | All P0 |
| 7 — Activity | FR-AC-04 | 6 | 2 | P1 |
| 8 — Dashboard | FR-HD-01, FR-HD-02, FR-HD-04 | 5 | 8 | All P0 |
| 8 — Dashboard | FR-HD-03 | 6 | 5 | P1 |
| 9 — Search | FR-SR-01, FR-SR-02 | 6 | 6 | Both P1 |
| 10 — Offline | FR-OF-01 | 6 | 3 | P0 |
| 10 — Offline | FR-OF-02, FR-OF-03 | 6 | 8 | Both P1 |
| 11 — Sharing | FR-SH-01, FR-SH-02 | 5 | 4 | Both P0 |
| 11 — Sharing | FR-SH-03 | 6 | 2 | P0 |
| 11 — Sharing | FR-SH-04 | 6 | 1 | P1 |

**Total backlog SP accounted:** 186 (matches `docs/sprint-zero/backlog.md` summary).

### P0 Completion by Sprint

| Sprint | P0 SP Delivered | Cumulative P0 SP | Percentage of P0 Total (146 SP) |
|---|---|---|---|
| 1 | 30 (refined from 21) | 30 | 21% |
| 2 | 50 | 80 | 55% |
| 4 | 38 | 118 | 81% |
| 5 | 28 | 146 | 100% |
| 6 | 0 new P0 (9 SP P0 items remaining) | — | — |

**Correction:** sprint 6 contains 4 P0 items totalling 9 SP (FR-PR-04, FR-PR-05, FR-SH-03, FR-OF-01). Including these, the P0 completion curve is:

| Sprint | P0 SP Delivered | Cumulative P0 SP | Percentage |
|---|---|---|---|
| 1 | 30 | 30 | 21% |
| 2 | 47 | 77 | 53% |
| 4 | 38 | 115 | 79% |
| 5 | 22 | 137 | 94% |
| 6 | 9 | 146 | 100% |

All 46 P0 items are delivered by end of sprint 6. All 16 P1 items are scheduled in sprint 6 but are descope-eligible per the descope table above. (Sprint 3 — Design Conversion — delivers no functional requirement, so it carries no P0 SP; the P0-completion curve advances from Sprint 2 directly to Sprint 4.)

### P1 Items at Risk of Fast-Follow Deferral

Per SRS section 11, P1 items may be descoped to a fast-follow release if timeline pressure demands it. The following items are ordered by descope priority (most expendable first):

| Order | ID | Title | SP | Epic |
|---|---|---|---|---|
| 1 | FR-HD-03 | Monthly spend chart | 5 | Dashboard |
| 2 | FR-SR-01 | Search expenses | 3 | Search |
| 3 | FR-SR-02 | Filter expenses | 3 | Search |
| 4 | FR-OF-03 | Last-write-wins conflict resolution | 3 | Offline |
| 5 | FR-OF-02 | Offline write queue | 5 | Offline |
| 6 | FR-EX-05 | Receipt attachment | 3 | Expenses |
| 7 | FR-AC-04 | Notification preferences filtering | 2 | Activity |
| 8 | FR-PR-03 | Set notification preferences | 2 | Profile |
| 9 | FR-SE-09 | Payment reminders | 3 | Settlements |
| 10 | FR-FR-05 | Delete friend | 2 | Friends |
| 11 | FR-SH-04 | No-mail-client fallback dialog | 1 | Sharing |
| 12 | FR-PR-02 | Update phone number | 3 | Profile |
| 13 | FR-AU-09 | Account deletion | 5 | Authentication |

Items 12 and 13 (FR-PR-02 and FR-AU-09) are the least desirable to descope: phone number update affects user identity, and account deletion has DPDP compliance implications (SRS section 12.1). These should only be deferred as a last resort, and if FR-AU-09 is deferred, a manual account-deletion process via support email must be documented as a launch-readiness requirement.

Note: FR-AC-04 depends on FR-PR-03; if FR-PR-03 is descoped, FR-AC-04 must also be descoped. Similarly, FR-OF-03 depends on FR-OF-02; they are descoped as a pair.

---

## Cross-Sprint Dependency Graph

```
Sprint 1                Sprint 2                Sprint 4                Sprint 5                Sprint 6
---------               ---------               ---------               ---------               ---------
INFRA-01 ──────────────> all stories
FR-AU-07 ──────────────> FR-FR-01, FR-EX-01     FR-GR-01                FR-AC-01                FR-OF-01
                         FR-SE-01
FUNC-01 ───────────────> FR-SE-02
FR-AU-06 (user doc) ───> FR-PR-04 (sprint 6)
                         FR-SE-02 ──> FR-SE-03 ──> FR-SE-04
                                                   FR-SE-04 ──> FR-SE-06
                                                   FR-SE-04 ──────────────────────────> FR-OF-02
                         FR-SE-01 ──────────────> FR-SE-05, FR-SE-07
                         FR-EX-01 ──────────────> FR-EX-06 ──────────────────────────> FR-EX-05
                                                   FR-EX-06 ──> FR-EX-07
                         FR-FR-01 ──────────────> FR-GR-01
                                                                         FR-AC-03 ──> FR-AC-04
                                                                                      FR-SE-09
                                                                         FR-SH-01 ──> FR-SH-03
```

---

## References

| Document | Path |
|---|---|
| Software Requirements Specification v1.1 | `docs/OneByTwo_Requirements_Spec.md` |
| Product Backlog | `docs/sprint-zero/backlog.md` |
| Sprint 1 Plan | `docs/sprint-zero/sprint-1-plan.md` |
| Architecture Extension Points | `docs/design/03-architecture/extension-points.md` |
| Firestore Schema | `docs/design/07-technical/firestore-schema.md` |
| Cloud Functions Catalogue | `docs/design/07-technical/cloud-functions-catalogue.md` |
| Simplified-Debts Algorithm | `docs/design/07-technical/simplified-debts-algorithm.md` |
| Non-Negotiable Invariants | `.github/shared/invariants.md` |