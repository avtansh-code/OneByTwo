You are the One By Two orchestrator agent. The agentic workspace under .github/ is configured and smoke-tested. Sprint-zero artefacts exist in docs/sprint-zero/. We are now entering the DESIGN PHASE — the bridge between the SRS and active development.

The output of this entire session is documentation only. You will produce no Flutter, Dart, TypeScript, or Cloud Functions source code. If at any point you feel the urge to write a real .dart or .ts file, stop — that belongs to sprint 1.

The full SRS is attached as `OneByTwo_Requirements_Spec.md`. Re-read `.github/copilot-instructions.md`, `.github/shared/invariants.md`, and `.github/shared/handoffs.md` before starting. Treat the four invariants (integer paise; client-read-only `simplifiedBalances`; system share sheet only; single Firebase project) as design constraints to be honoured by every artefact you produce.

────────────────────────────────────────
TARGET AUDIENCE & FUTURE-PROOFING
────────────────────────────────────────

Every artefact in this phase must:
  - Be readable by every agent role (PM, architect, flutter-dev, functions-dev, qa, devops, designer).
  - Be written in British English (matches the SRS).
  - Avoid emojis and marketing language.
  - Cite the SRS section or ADR it implements wherever applicable.
  - Identify v1.1 extension points where UPI deep-link payments, Hindi/multi-language localisation, and recurring expenses (per SRS §12.3) will plug in WITHOUT refactoring v1.0. An "extension point" is a named seam in the design — a variant slot in the schema, a strategy in the code, an empty card in the UI — not a feature that gets built now.

────────────────────────────────────────
EXECUTION PROTOCOL
────────────────────────────────────────

Work in eight phases. After EACH phase, list every file produced (with full path and a one-line summary) and STOP. Wait for me to type "proceed" before starting the next phase. Do not generate files belonging to a later phase before I confirm.

If at any phase boundary I say "redo," produce the same phase again with the feedback I provide. Do not move forward until I confirm.

If you find ambiguities in the SRS or sprint-zero documents that materially affect the design, list them at the start of each phase and propose resolutions before proceeding.

All output goes under `docs/design/` unless explicitly directed otherwise.

════════════════════════════════════════
PHASE 1 — INFORMATION ARCHITECTURE & NAVIGATION
════════════════════════════════════════
Owner: pm + designer.

Produce:

1.1  `docs/design/01-information-architecture/site-map.md`
     - Hierarchical map of every screen in v1.0.
     - Tab-level structure (Home, Friends, Groups, Activity, Profile).
     - Modal vs push navigation calls for each screen transition.
     - Deep-link URL scheme covering every notification destination per FR-AC-05.

1.2  `docs/design/01-information-architecture/navigation-flow.md`
     - Mermaid flowchart of the entire navigation graph.
     - Marked entry points (cold start, push notification, share-sheet invite link, deep link from an external messaging app).
     - Marked exit points (sign out, account deletion).

1.3  `docs/design/01-information-architecture/user-journeys.md`
     - Step-by-step happy paths for the twelve critical journeys from SRS §10.2, each as a numbered list of screens visited.
     - For each journey, the SRS requirements it exercises.

1.4  `docs/design/01-information-architecture/extension-points.md`
     - Named seams in the IA where v1.1 features dock. At minimum:
        IA-EXT-01: Settle-up flow has a slot for UPI deep-link option (currently absent in v1.0).
        IA-EXT-02: Expense add flow has a slot for "make this recurring" toggle (currently absent in v1.0).
        IA-EXT-03: Profile screen has a "Language" row that is hidden in v1.0 but routable.
     - For each, describe what changes when v1.1 lands, and what stays untouched.

════════════════════════════════════════
PHASE 2 — DESIGN SYSTEM
════════════════════════════════════════
Owner: designer + flutter-dev (consulting).

Produce:

2.1  `docs/design/02-design-system/tokens.md`
     - Full design token table: colour (light + dark), typography scale, spacing scale (4-pt grid), corner radii, elevation, motion (durations + curves), iconography rules.
     - Tokens MUST be expressed both as semantic names (e.g., `color.surface.primary`) and concrete values (e.g., `#FFFFFF` / `#121212`). The semantic-name layer is what code references; the concrete layer is what the designer changes.
     - Cite SRS §6.2 as the starting point but expand it into the full system.

2.2  `docs/design/02-design-system/components.md`
     - Catalogue of every reusable component v1.0 needs: AppBar, BottomNav, FAB, ListTile variants, EmptyState, ErrorState, SkeletonLoader, BalancePill, AmountInput, OTPInput, ContactPicker, GroupAvatar, CategoryChip, SettleUpCard, ActivityRow, RupeeText.
     - For each: visual description, props/inputs, states (default, hover/pressed, disabled, loading, error), accessibility behaviour, and the SRS/UX requirements it satisfies.

2.3  `docs/design/02-design-system/typography-and-formatting.md`
     - The Indian-numbering-system formatting rules for ₹ (FR-EX-09): worked examples for ₹0, ₹50, ₹500, ₹5,000, ₹50,000, ₹5,00,000, ₹50,00,000, ₹5,00,00,000.
     - Date and time formatting in IST regardless of device locale (SRS §5.9).
     - Phone number display format for +91 numbers.
     - Negative balance formatting and colour usage.

2.4  `docs/design/02-design-system/motion-and-interaction.md`
     - Standard transitions: page push/pop, modal sheet, FAB scale, list item swipe, OTP auto-advance.
     - Haptic feedback rules (success on settle, error on validation failure, light tap on FAB).
     - Loading patterns: skeleton-first, then spinner only as fallback after 1.5s (SRS §6.4).

2.5  `docs/design/02-design-system/extension-points.md`
     - Where v1.1 introduces new tokens (Hindi font fallback stack), new components (RecurrenceChip, UpiAppLogoRow), or new motion patterns. v1.0 design system must not preclude any of these.

════════════════════════════════════════
PHASE 3 — SYSTEM ARCHITECTURE
════════════════════════════════════════
Owner: architect.

Produce:

3.1  `docs/design/03-architecture/c4-system-context.md`
     - Mermaid C4 system-context diagram. Actors: end user, group member, support reader of inbound mailto. External systems: Firebase, Apple Push, Google FCM, App Store, Play Store, system share sheet, default mail client.

3.2  `docs/design/03-architecture/c4-container.md`
     - Mermaid C4 container diagram. Containers: Flutter app (iOS), Flutter app (Android), Cloud Firestore, Cloud Functions, Cloud Storage, Firebase Auth, Firebase Cloud Messaging, Firebase Crashlytics, Firebase Analytics, Firebase Remote Config, Firebase App Check.

3.3  `docs/design/03-architecture/c4-component.md`
     - Mermaid C4 component diagram for the Flutter app, broken down by feature module per SRS §13.1.
     - Same for the Cloud Functions container, broken down by trigger type and function name.

3.4  `docs/design/03-architecture/data-flow.md`
     - Sequence diagrams in Mermaid for the four most important flows:
        Phone OTP login (Auth + RemoteConfig + Firestore user-doc creation).
        Add expense in a group (Firestore write + Cloud Function recompute + FCM fan-out).
        Record settlement (similar fan-out pattern).
        Account deletion (Cloud Function orchestration with anonymisation).

3.5  `docs/design/03-architecture/deployment-topology.md`
     - Single-Firebase-project topology with regions called out (Firestore region, Functions in `asia-south1`, Storage region, Auth global).
     - Network diagram including App Check, TLS, and the production-only environment.

3.6  `docs/design/03-architecture/non-functional-design.md`
     - How each NFR from SRS §5 is satisfied by the architecture: caching strategy for performance, sharded patterns for scalability, transaction boundaries for reliability, App Check + Rules + paise for security, structured logging for observability.

3.7  `docs/design/03-architecture/extension-points.md`
     - Architectural seams for v1.1: a `settlementMethod` discriminator on settlement documents (currently always 'manual'); a `currency` field on expenses and settlements (currently always 'INR'); a `recurringRule` optional sub-document on expenses (currently always null); a locale field on user documents (currently always 'en-IN').

════════════════════════════════════════
PHASE 4 — UI WIREFRAMES (LO-FI)
════════════════════════════════════════
Owner: designer + pm.

Produce ONE markdown file per major flow under `docs/design/04-wireframes/`. Use Mermaid `flowchart` and ASCII boxes for screen layouts. Each file covers one flow end-to-end:

4.1  `04-wireframes/auth-flow.md` — splash → +91 entry → OTP → profile setup → home.
4.2  `04-wireframes/home-dashboard.md` — empty state, populated state, loading skeleton, error state.
4.3  `04-wireframes/friends-flow.md` — list, add friend (contact picker + manual entry + share-sheet invite path), friend detail, history, delete with non-zero-balance guard.
4.4  `04-wireframes/groups-flow.md` — list, create group, invite via share sheet, group detail, member admin, leave group, delete group.
4.5  `04-wireframes/expense-flow.md` — add expense, all five split methods, edit, delete, receipt attach.
4.6  `04-wireframes/settle-up-flow.md` — entry from balance pill, simplified-debts suggestion, record settlement, history.
4.7  `04-wireframes/activity-feed.md` — chronological list, deep-link tap-through.
4.8  `04-wireframes/profile-and-support.md` — view, edit, notification prefs, contact support (with no-mail-client fallback per FR-SH-04), delete account.
4.9  `04-wireframes/notifications-and-deeplinks.md` — push permission prompt, notification delivery, cold-start deep link, foreground notification banner.

Each file ends with an "Extension points" section listing where v1.1 docks.

════════════════════════════════════════
PHASE 5 — UI HI-FI MOCKUPS (HERO SCREENS ONLY)
════════════════════════════════════════
Owner: designer.

Produce eight self-contained HTML files under `docs/design/05-mockups/`. Each is a single .html with inline CSS, no JavaScript framework, no external assets except Google Fonts and inline SVG icons. Use the design tokens from Phase 2 verbatim — DO NOT invent new values. The eight hero screens:

5.1  `05-mockups/01-splash-and-onboarding.html`
5.2  `05-mockups/02-phone-and-otp.html`
5.3  `05-mockups/03-home-dashboard.html` (populated state, light + dark side by side)
5.4  `05-mockups/04-add-expense-bottom-sheet.html`
5.5  `05-mockups/05-group-detail.html`
5.6  `05-mockups/06-settle-up.html`
5.7  `05-mockups/07-activity-feed.html`
5.8  `05-mockups/08-profile-with-support.html`

Each mockup must render correctly at iPhone 12 viewport (390×844) and a typical Android viewport (412×892). Include a comment block at the top of every HTML file linking to the SRS requirements satisfied and the wireframe file from Phase 4.

Also produce `05-mockups/README.md` indexing the eight files with screenshots-as-description (textual). Note that hi-fi mockups are produced ONLY for these eight hero screens — every other screen is covered by wireframes (Phase 4) and specs (Phase 6).

════════════════════════════════════════
PHASE 6 — SCREEN SPECIFICATIONS (FULL v1.0)
════════════════════════════════════════
Owner: designer + pm + qa.

Produce one detailed spec per screen under `docs/design/06-screen-specs/`, named `XX-screen-name.md`. Cover EVERY screen in v1.0 (roughly 25 screens total — count them from Phase 1 site-map). Each spec must include:

  - Screen ID (matches the site-map).
  - Purpose in one sentence.
  - SRS requirements satisfied (FR-XX-NN list).
  - Reachable from / leads to (navigation in/out).
  - Components used (from Phase 2 catalogue).
  - All states: default, loading (skeleton), empty, error, populated, offline.
  - Inputs and validation rules with exact error messages.
  - Telemetry events fired on this screen.
  - Accessibility specifics: semantic labels for every interactive element, focus order, screen-reader announcement on state change.
  - Edge cases identified by QA (at least three per screen).
  - Open questions for the architect to resolve before implementation.

Index file: `06-screen-specs/README.md` listing every spec with its SRS coverage.

════════════════════════════════════════
PHASE 7 — TECHNICAL DESIGN
════════════════════════════════════════
Owner: architect + functions-dev + flutter-dev.

Produce:

7.1  `docs/design/07-technical/firestore-schema.md`
     - Final document for every collection and subcollection from SRS §7.2, with field-by-field types, allowed values, defaults, and indexed fields.
     - Composite indexes required (group expenses by date desc, user activity, friendship lookup).
     - Storage layout: path conventions for receipts and avatars; lifecycle rules.

7.2  `docs/design/07-technical/firestore-security-rules.md`
     - Rule outline (NOT final code) per collection, in plain English with example assertions.
     - Each rule cites the SRS or ADR it enforces.
     - Hard line on `simplifiedBalances`: clients can read; only the cloud-functions service account can write. Negative test cases included.

7.3  `docs/design/07-technical/cloud-functions-catalogue.md`
     - Every Cloud Function v1.0 needs, with: trigger type, input contract, output contract, idempotency strategy, error semantics, retry policy, region pinning to `asia-south1`.
     - At minimum: `recomputeSimplifiedBalances`, `onExpenseWrite`, `onSettlementWrite`, `onUserDelete`, `acceptGroupInvite`, `revokeGroupInvite`, `sendReminderNotification`.

7.4  `docs/design/07-technical/simplified-debts-algorithm.md`
     - The reference algorithm from SRS §7.4, expanded with at least six worked examples covering: empty, single member, balanced, cyclic-to-zero, three-person trip, five-person flat-share. Each example shows inputs, intermediate steps, and the deterministic output.
     - Determinism rule (tie-break by ascending userId) re-stated and exemplified.
     - Performance budget: ≤500 ms P95 for groups up to 50 members.

7.5  `docs/design/07-technical/state-management.md`
     - Riverpod 2.x provider tree for the whole app: which providers are app-scoped vs feature-scoped vs screen-scoped.
     - Naming conventions, file locations, and disposal rules.
     - How offline cache is exposed through providers (FR-OF-01).

7.6  `docs/design/07-technical/offline-and-sync.md`
     - Local cache strategy (Firestore SDK persistent cache + any app-level layering).
     - Pending-write queue model for offline expense and settlement creation (FR-OF-02).
     - Conflict resolution flow with user-visible notification (FR-OF-03).

7.7  `docs/design/07-technical/notifications.md`
     - FCM token lifecycle (acquisition, refresh, multi-device per SRS §7.2 user doc).
     - Notification payload schema; foreground vs background handling on each platform.
     - Deep-link map: every notification type → destination screen.
     - Permission prompt timing (post-onboarding, not at app launch).

7.8  `docs/design/07-technical/telemetry-plan.md`
     - Every Firebase Analytics event for v1.0, with exact event name, required parameters, types, and the SRS or screen-spec section that triggered its addition.
     - Build on SRS §5.10 list and expand: error_shown, retry_tapped, deep_link_opened, share_invite_sent, settle_up_opened_from_<source>, etc.
     - Dashboards to build (funnels: signup, add-first-expense, first-settlement; cohorts).

7.9  `docs/design/07-technical/error-and-empty-state-taxonomy.md`
     - Every error state across the app, mapped to: user-visible copy, telemetry event, retry strategy, escalation to support.
     - Every empty state with copy and primary call-to-action.

7.10 `docs/design/07-technical/accessibility-spec.md`
     - WCAG 2.1 AA requirements per SRS §5.6 expanded into concrete implementation guidance per component.
     - VoiceOver and TalkBack walkthroughs for the five most critical flows.
     - Dynamic type behaviour, focus management on screen change, semantic labelling rules.

7.11 `docs/design/07-technical/test-design.md`
     - Mapping of every screen and every Cloud Function to widget tests, integration tests, and emulator-based tests.
     - Coverage plan that meets SRS §5.7 thresholds.
     - The simplified-debts canonical test matrix (six cases minimum) called out as a required CI gate.

7.12 `docs/design/07-technical/extension-points-register.md`
     - Master register of every v1.1 extension point identified across phases 1–7. One row per seam, with: name, location (file/component/document field), what stays in v1.0, what changes when v1.1 lands, and the v1.1 feature it unlocks (UPI / Hindi / recurring).

════════════════════════════════════════
PHASE 8 — SEQUENCED SPRINT PLAN
════════════════════════════════════════
Owner: pm + architect.

Produce:

8.1  `docs/design/08-plan/sprint-sequence.md`
     - All v1.0 work broken into sprints (assume two-week sprints, team capacity TBD by stakeholder).
     - Each sprint has a theme, a goal statement, the user stories included with FR-XX-NN references, the design artefacts that must exist beforehand (always already produced in this phase), and the demo at the end.
     - Sprint 1 should match what is already in `docs/sprint-zero/sprint-1-plan.md` — reconcile any drift.

8.2  `docs/design/08-plan/dependencies-and-critical-path.md`
     - DAG (Mermaid) of inter-story dependencies across v1.0.
     - Critical path called out explicitly: anything that blocks login blocks everything; the simplified-debts function must exist as a stub before any feature using balances.

8.3  `docs/design/08-plan/risks-revisited.md`
     - Re-walk SRS §12.1 and the sprint-zero risk register. After completing the design phase, are there new risks visible? Are mitigations now stronger?

8.4  `docs/design/08-plan/definition-of-ready.md` and `definition-of-done.md`
     - DoR for stories entering a sprint: design artefacts exist, ACs written, dependencies cleared, telemetry events identified.
     - DoD for stories leaving a sprint: code merged, tests passing, coverage thresholds met, telemetry firing, accessibility verified, screen spec updated if scope shifted.

8.5  `docs/design/08-plan/handover-to-development.md`
     - Final summary handing this design package to the dev team. One page, signed off by pm + architect + qa + devops + designer (text sign-off, named).

════════════════════════════════════════
END-OF-SESSION OUTPUT
════════════════════════════════════════

By the end of Phase 8, `docs/design/` contains roughly twenty-five to thirty markdown and HTML files. The very last thing you produce is `docs/design/README.md` — a one-page index with links to every artefact, grouped by phase.

Begin with Phase 1.