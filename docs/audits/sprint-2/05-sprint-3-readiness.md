# Phase 5 — Sprint 3 Pre-Flight Readiness

**Date:** 2026-06-24
**Lead:** PM
**Consulting:** Architect, Designer

Method: read the Sprint-3 scope (`sprint-sequence.md` §"Sprint 3"), the DoR
(`definition-of-ready-and-done.md`), and verified the FR-GR-01 supporting artefacts —
story files, screen spec (`06-screen-specs/13-18-groups.md`), wireframes
(`groups-flow.md`, `settle-up-flow.md`), mockups (`05-group-detail.html`,
`06-settle-up.html`), components (`02-design-system/components.md`), schema + rules
(`firestore-schema.md`, `firestore-security-rules.md`, `firestore.rules`), telemetry
(`telemetry-plan.md`), risks (`risks-revisited.md`), and the `go_router` candidate
(`next-three-prs.md`). Sprint 3 = 13 stories / 38 SP; the first three are **FR-GR-01
(Create group, 3 SP), FR-GR-02 (Invite members, 3 SP), FR-GR-03 (Invite-link expiry +
revocation, 3 SP).**

**Verdict:** Sprint 3 is **mostly ready** — the schema core, telemetry, and all four
design artefacts exist with good fidelity — but **FR-GR-01 cannot enter the sprint
until its story is written (SR1)**, and three design prerequisites (invite-token model,
zero-balance-guard enforcement, risk entries) must be resolved before the dependent
stories FR-GR-02..07.

---

## 5.1 Scope Clarity and DoR Compliance

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| SR1 | `docs/sprint-zero/stories/` (0 `FR-GR-*` files); `definition-of-ready-and-done.md:15-28` | **No story file exists for any Sprint-3 Groups story.** The DoR requires an SRS-13.2 story (Title, Story, Preconditions, ≥3 Given/When/Then incl. ≥1 negative, DoD reference, FR ID). FR-GR-01 (the identified first Sprint-3 PR) has none, so it is **not DoR-compliant and cannot enter the sprint.** Mirrors the Sprint-1 SR1 blocker. | **High** | **Fix now** — write the first three stories (FR-GR-01/02/03) before Sprint 3 opens; backfill FR-GR-04..07 + the group-context FR-SE/FR-EX extensions as the sprint proceeds. | PM |
| SR2 | `06-screen-specs/13-18-groups.md` (SCR-13..18, 636 ln); `04-wireframes/{groups-flow,settle-up-flow}.md`; `05-mockups/{05-group-detail,06-settle-up}.html` | **All four design artefacts exist with good fidelity.** The screen spec fully covers SCR-13 (List), SCR-14 (Create), SCR-15 (Detail), SCR-16 (Invite), SCR-17 (Members), SCR-18 (Delete) with states, copy, navigation, and real-time behaviours (member-removed / group-deleted listeners). The remaining "Open Questions" are normal design refinements, not gaps. | — | None (PASS) — fidelity confirmed | — |

---

## 5.2 Design Artefacts (Component Catalogue)

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| SR3 | `02-design-system/components.md:371` (OBTGroupAvatar #10), `:606` (OBTGroupListTile #17), `:472-498` (settle-up card) | **Group list-tile, group avatar, and settle-up card exist; member-row and invite-link-card do not.** SCR-17 (Manage Members) needs a member-row component and SCR-16 (Invite) needs an invite-link card; neither is in the catalogue. Not an FR-GR-01 blocker (Create group reuses the list tile + form inputs). | Medium | Backlog (before FR-GR-02/FR-GR-04) — add member-row + invite-link-card entries, or confirm they reuse existing list-tile patterns. | Designer |

---

## 5.3 Technical Readiness

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| SR6 | `firestore-schema.md:93-127` (groups/{groupId}); `firestore.rules:325-372` (isValidGroupCreate); `lib/features/groups/` (.gitkeep + README) | **The groups/{groupId} core schema + create rule are complete, and the feature is correctly a stub.** name/type/coverPhotoUrl/memberIds/adminId present; `simplifiedBalances` server-maintained + absent-at-create (Invariant 2); the settlement extension-point obligations are already enforced by the context-aware Sprint-2 settlement rules. The empty `lib/features/groups/` confirms the feature-first scaffold is the correct first build step. | — | None (PASS) | — |
| SR4 | `firestore-schema.md` (no invites collection/fields); `firestore.rules` (no invite match block); `telemetry-plan.md:173` (`invite_link_shared/revoked`); `risks-revisited.md:242` (`/invite/group/:inviteToken`) | **No invite-token data model exists.** FR-GR-02/03 (invite via link, 7-day expiry, admin revocation) reference an `inviteToken` in telemetry and the deep-link map, but there is no schema (token, groupId, createdBy, `expiresAt`, `revoked`) and no rules for it. FR-GR-02/03 are blind without it (FR-GR-01 is not blocked). | **High** | **Fix now (design)** — Architect drafts the invite-token schema + a rules/expiry/revocation outline (and an ADR) in the cleanup PR so FR-GR-02/03 have a target; full implementation is Sprint 3. | Architect |
| SR5 | `firestore-security-rules.md:145-155`; `firestore.rules:360-372` (groups update/delete) | **Group security rules are incomplete and the zero-balance-guard enforcement is undecided.** `memberIds` is **not locked on group update** (no admin-only membership guard for FR-GR-05 remove-member), `delete: if false` (no zero-balance-guarded delete for FR-GR-07), and there are no invite rules. Crucially, **how** the zero-balance guards (remove/leave/delete) are enforced **server-side** (Firestore rules reading `simplifiedBalances`, vs a callable Cloud Function) is an open architectural decision — and they must not be UI-only. Overlaps Phase-4 R2 (forward groups rules untested). | Medium | Backlog (Sprint 3) — Architect makes the zero-balance-enforcement decision (rules vs callable) early, before FR-GR-05/06/07; add the admin-only membership guard and the delete rule with the chosen mechanism, plus negative tests. | Architect + Functions Dev |
| SR7 | `next-three-prs.md` (`go_router` migration, Sprint 3); `06-screen-specs/13-18-groups.md:256-258` (`/groups/:groupId/invite`, `/members`); `risks-revisited.md:242` (`/invite/group/:inviteToken`) | **`go_router` decision: deferrable for FR-GR-01, needed before FR-GR-02/04.** FR-GR-01 navigates imperatively to SCR-15 on success (no deep link). The invite/members screens and the universal-link `/invite/group/:inviteToken` flow are route-based, so the go_router-vs-imperative call should be made before FR-GR-02 (invite) and FR-GR-04 (deep-linkable detail). Not a first-PR blocker. | Low | Backlog — Architect decides go_router scope at Sprint-3 kickoff; FR-GR-01 proceeds either way. | Architect |

---

## 5.4 Telemetry Readiness

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| SR8 | `telemetry-plan.md:41,157-181` (26 `group_*` events) | **Groups telemetry is well-enumerated and PII-clean as planned.** `group_created`, `create_group_started/failed`, `group_photo_uploaded`, `group_detail_viewed`, `group_members_viewed`, `group_member_removed`/`_remove_blocked`, `invite_link_shared`/`_revoked`, `group_left`, `group_deleted`, `group_settle_up_tapped` are present; params are counts/types/error_codes (no raw IDs). Minor: an explicit `group_member_added` (invite-accept side) is not obvious. **Risk to manage:** Phase-1 (T6/T8) showed shipped telemetry diverged from the plan — the groups implementation must follow the plan precisely and hash any `groupId`/`memberId` via the `hashFriendshipId` pattern. | Low | Backlog — confirm `group_member_added`; apply the Phase-3 SK2 review-skill checks during Sprint-3 PRs to prevent telemetry drift. | Architect |

---

## 5.5 Risk Register

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| SR9 | `risks-revisited.md:24,116-136` (R-04 hot documents); `:242-259` (invite deep-link/universal-links, CUJ-11) | **Scalability is covered, but two Groups-specific risks are missing.** R-04 (hot documents on group balances) is OPEN with strengthened mitigation, and the SC4 100+/1000-member algorithm test (#76) de-risks the algorithm layer. However there is **no explicit risk for (a) invite-link expiry/revocation/unguessability security**, and **(b) the zero-balance guards being enforced only in the UI rather than server-side** (the only "zero-balance" mention is the account-deletion/DPDP context). | Medium | Fix now (cheap) — add the invite-link-security and the zero-balance-guard-server-enforcement risks to `risks-revisited.md` (with mitigations pointing at SR4/SR5). | PM + Architect |

---

## Summary

| Sub-part | High | Medium | Low | PASS/None |
|---|---|---|---|---|
| 5.1 Scope/DoR | 1 (SR1) | 0 | 0 | SR2 |
| 5.2 Components | 0 | 1 (SR3) | 0 | — |
| 5.3 Technical | 1 (SR4) | 1 (SR5) | 1 (SR7) | SR6 |
| 5.4 Telemetry | 0 | 0 | 1 (SR8) | — |
| 5.5 Risks | 0 | 1 (SR9) | 0 | — |
| **Total** | **2** | **3** | **2** | 2 PASS |

### Preliminary Triage (Phase 6 finalises)

- **Fix now:** SR1 (write FR-GR-01/02/03 stories — the one hard blocker on Sprint-3
  start), SR4 (Architect drafts the invite-token schema + rules/expiry/revocation outline
  + ADR so FR-GR-02/03 are not blind), SR9 (add the two Groups risks).
- **Backlog (Sprint 3):** SR3 (member-row + invite-link-card components), SR5 (group
  rules completion + the zero-balance-enforcement decision and tests), SR7 (go_router
  scope decision at kickoff), SR8 (confirm `group_member_added`; hold telemetry to plan).
- **Accept:** SR2, SR6 (design artefacts and the groups schema/scaffold are ready).

> Headline: **FR-GR-01 (Create group) is one story-file away from ready** — the schema,
> create rule, screen spec, wireframe, mockup, and telemetry all exist. The dependent
> stories (FR-GR-02..07) have genuine design prerequisites — an **invite-token model**
> and a **server-side zero-balance-guard decision** — that should be resolved before
> they start, not first-PR blockers. The multi-party scalability risk is already tracked
> and de-risked at the algorithm layer by the #76 SC4 test.
