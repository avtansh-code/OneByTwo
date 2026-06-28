# One By Two v1.0 — Design Package

> [!WARNING]
> **Visual layer superseded by the Haldi system (ADR-0024).** As of Sprint 3, the
> **visual** artefacts in this package — `02-design-system/{tokens, components,
> typography-and-formatting, motion-and-interaction}`, `04-wireframes/*`,
> `05-mockups/*`, `06-screen-specs/*` — are **historical reference only**; the
> canonical visual source of truth is the Haldi handoff (`design_handoff_one_by_two/`).
> The **backend/data** artefacts — `03-architecture/*` and
> `07-technical/{firestore-schema, firestore-security-rules,
> cloud-functions-catalogue, telemetry-plan, state-management}` — **remain
> authoritative** and are unchanged by the conversion (ADR-0024 item 3). Build new
> visual work against the Haldi handoff, not the superseded files above.

> **Status:** Complete — ready for development handover
> **SRS baseline:** v1.1 (`docs/OneByTwo_Requirements_Spec.md`)
> **Sprint-zero artefacts:** `docs/sprint-zero/`
> **Total artefacts:** 58 files across 8 phases

---

## Phase 1 — Information Architecture and Navigation

| File | Summary |
|------|---------|
| [`01-information-architecture/site-map.md`](01-information-architecture/site-map.md) | Hierarchical screen map (27 screens), tab structure, navigation types, deep-link URL scheme |
| [`01-information-architecture/navigation-flow.md`](01-information-architecture/navigation-flow.md) | Mermaid navigation graph with entry/exit points and auth guard logic |
| [`01-information-architecture/user-journeys.md`](01-information-architecture/user-journeys.md) | Step-by-step happy paths for all 12 critical user journeys (SRS section 10.2) |
| [`01-information-architecture/extension-points.md`](01-information-architecture/extension-points.md) | 6 IA extension points for v1.1 features |

## Phase 2 — Design System

| File | Summary |
|------|---------|
| [`02-design-system/tokens.md`](02-design-system/tokens.md) | Colour (light + dark), typography scale, spacing grid, corner radii, elevation, motion, iconography |
| [`02-design-system/components.md`](02-design-system/components.md) | 25-component catalogue with props, states, accessibility, SRS refs |
| [`02-design-system/typography-and-formatting.md`](02-design-system/typography-and-formatting.md) | INR Indian numbering, IST dates, phone display, negative balance formatting, microcopy |
| [`02-design-system/motion-and-interaction.md`](02-design-system/motion-and-interaction.md) | Transitions, haptics, skeleton-first loading, OTP auto-advance, reduced motion |
| [`02-design-system/extension-points.md`](02-design-system/extension-points.md) | 6 design system seams for v1.1 |

## Phase 3 — System Architecture

| File | Summary |
|------|---------|
| [`03-architecture/c4-system-context.md`](03-architecture/c4-system-context.md) | C4 Level 1 — actors and external systems |
| [`03-architecture/c4-container.md`](03-architecture/c4-container.md) | C4 Level 2 — Firebase service containers and protocols |
| [`03-architecture/c4-component.md`](03-architecture/c4-component.md) | C4 Level 3 — Flutter modules and Cloud Functions components |
| [`03-architecture/data-flow.md`](03-architecture/data-flow.md) | Sequence diagrams: login, add expense, settlement, account deletion |
| [`03-architecture/deployment-topology.md`](03-architecture/deployment-topology.md) | Single-project topology, regions, pipeline, safety controls |
| [`03-architecture/non-functional-design.md`](03-architecture/non-functional-design.md) | How each NFR from SRS section 5 is architecturally satisfied |
| [`03-architecture/extension-points.md`](03-architecture/extension-points.md) | 7 architectural seams with schema field defaults |

## Phase 4 — UI Wireframes (Lo-Fi)

| File | Summary |
|------|---------|
| [`04-wireframes/auth-flow.md`](04-wireframes/auth-flow.md) | Splash, onboarding, phone entry, OTP, profile setup |
| [`04-wireframes/home-dashboard.md`](04-wireframes/home-dashboard.md) | Empty, populated, skeleton, error, offline states |
| [`04-wireframes/friends-flow.md`](04-wireframes/friends-flow.md) | List, add friend, detail, history, delete guard |
| [`04-wireframes/groups-flow.md`](04-wireframes/groups-flow.md) | List, create, invite, detail, members, leave, delete |
| [`04-wireframes/expense-flow.md`](04-wireframes/expense-flow.md) | Multi-step bottom sheet, all 5 split methods, edit, delete, receipt |
| [`04-wireframes/settle-up-flow.md`](04-wireframes/settle-up-flow.md) | Entry points, suggestion, record, confirmation, history |
| [`04-wireframes/activity-feed.md`](04-wireframes/activity-feed.md) | Chronological event list with deep-link tap-through |
| [`04-wireframes/profile-and-support.md`](04-wireframes/profile-and-support.md) | View, edit, prefs, contact support, sign out, account deletion |
| [`04-wireframes/notifications-and-deeplinks.md`](04-wireframes/notifications-and-deeplinks.md) | Permission, delivery, cold-start deep link, invite resolution |

## Phase 5 — Hi-Fi Mockups (Hero Screens)

| File | Summary |
|------|---------|
| [`05-mockups/README.md`](05-mockups/README.md) | Index with token compliance and viewing instructions |
| [`05-mockups/01-splash-and-onboarding.html`](05-mockups/01-splash-and-onboarding.html) | Splash screen and onboarding slide |
| [`05-mockups/02-phone-and-otp.html`](05-mockups/02-phone-and-otp.html) | Phone entry (+91) and OTP verification |
| [`05-mockups/03-home-dashboard.html`](05-mockups/03-home-dashboard.html) | Home dashboard populated (light + dark) |
| [`05-mockups/04-add-expense-bottom-sheet.html`](05-mockups/04-add-expense-bottom-sheet.html) | Add expense multi-step bottom sheet |
| [`05-mockups/05-group-detail.html`](05-mockups/05-group-detail.html) | Group detail with balances and expenses |
| [`05-mockups/06-settle-up.html`](05-mockups/06-settle-up.html) | Settle up with simplified-debts suggestion |
| [`05-mockups/07-activity-feed.html`](05-mockups/07-activity-feed.html) | Activity feed with chronological events |
| [`05-mockups/08-profile-with-support.html`](05-mockups/08-profile-with-support.html) | Profile with Contact Support |

## Phase 6 — Screen Specifications

| File | Summary |
|------|---------|
| [`06-screen-specs/README.md`](06-screen-specs/README.md) | Index with SRS coverage mapping |
| [`06-screen-specs/01-05-auth-and-profile-setup.md`](06-screen-specs/01-05-auth-and-profile-setup.md) | SCR-01 to SCR-05: Splash, Onboarding, Phone, OTP, Profile Setup |
| [`06-screen-specs/06-08-home-and-search.md`](06-screen-specs/06-08-home-and-search.md) | SCR-06 to SCR-08: Home Dashboard, Search, FAB Entry |
| [`06-screen-specs/09-12-friends.md`](06-screen-specs/09-12-friends.md) | SCR-09 to SCR-12: Friends List, Add Friend, Detail, Delete |
| [`06-screen-specs/13-18-groups.md`](06-screen-specs/13-18-groups.md) | SCR-13 to SCR-18: Groups List, Create, Detail, Invite, Members, Delete/Leave |
| [`06-screen-specs/19-22-expenses.md`](06-screen-specs/19-22-expenses.md) | SCR-19 to SCR-22: Add Expense (3 steps), Edit/Delete |
| [`06-screen-specs/23-28-settle-activity-profile.md`](06-screen-specs/23-28-settle-activity-profile.md) | SCR-23 to SCR-28: Settle Up, History, Activity, Profile, Prefs, Support/Deletion |

## Phase 7 — Technical Design

| File | Summary |
|------|---------|
| [`07-technical/firestore-schema.md`](07-technical/firestore-schema.md) | 7 collections, field-by-field types, 8 composite indexes, storage layout |
| [`07-technical/firestore-security-rules.md`](07-technical/firestore-security-rules.md) | Rule outline per collection, 5 negative test cases |
| [`07-technical/cloud-functions-catalogue.md`](07-technical/cloud-functions-catalogue.md) | 7 Cloud Functions with triggers, contracts, idempotency |
| [`07-technical/simplified-debts-algorithm.md`](07-technical/simplified-debts-algorithm.md) | Reference algorithm, 6 worked examples, determinism rule |
| [`07-technical/state-management.md`](07-technical/state-management.md) | Riverpod provider tree, scoping, naming, disposal, offline |
| [`07-technical/offline-and-sync.md`](07-technical/offline-and-sync.md) | Firestore cache, pending writes, conflict resolution |
| [`07-technical/notifications.md`](07-technical/notifications.md) | FCM lifecycle, 6 payload schemas, deep-link map |
| [`07-technical/telemetry-plan.md`](07-technical/telemetry-plan.md) | ~150 analytics events, privacy rules, 6 dashboards |
| [`07-technical/error-and-empty-state-taxonomy.md`](07-technical/error-and-empty-state-taxonomy.md) | Every error/empty/loading state with copy and actions |
| [`07-technical/accessibility-spec.md`](07-technical/accessibility-spec.md) | WCAG 2.1 AA, 5 screen-reader walkthroughs, dynamic type |
| [`07-technical/test-design.md`](07-technical/test-design.md) | Test pyramid for 28 screens + 7 functions, 12 CUJ integration tests |
| [`07-technical/extension-points-register.md`](07-technical/extension-points-register.md) | Master register of 20 extension points grouped by 8 v1.1 features |

## Phase 8 — Sequenced Sprint Plan

| File | Summary |
|------|---------|
| [`08-plan/sprint-sequence.md`](08-plan/sprint-sequence.md) | 6 sprints with stories, demos, and design prereqs |
| [`08-plan/dependencies-and-critical-path.md`](08-plan/dependencies-and-critical-path.md) | Mermaid DAG, critical path, parallel work streams |
| [`08-plan/risks-revisited.md`](08-plan/risks-revisited.md) | Post-design risk assessment with mitigation confidence |
| [`08-plan/definition-of-ready-and-done.md`](08-plan/definition-of-ready-and-done.md) | DoR (9 items) and DoD (9 items) for sprint stories |
| [`08-plan/handover-to-development.md`](08-plan/handover-to-development.md) | Formal sign-off from all agent roles |
