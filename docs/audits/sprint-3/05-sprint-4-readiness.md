# Phase 5 — Sprint 4 (Groups) Pre-Flight Readiness

**Owner:** PM (lead) + Architect + Designer
**Scope:** confirm the Sprint 4 Groups epic (13 open issues) can start **on the Haldi system**.
These are checks, not changes.
**Status:** **READY.** Every gap is already tracked as a Sprint-4 issue; nothing in this retro
blocks the epic, and the Phase-1/2 fidelity fixes make the Haldi base clean for Groups.

---

## 5.1 Design readiness for Groups

Groups (`Phase3d`) was deferred from DC-03, so the **group Haldi components do not exist in code
yet** — they must be built **Haldi-native** as Sprint 4 PR #1, never reskinned later. The handoff
`design_handoff_one_by_two/screens/Phase3d - Groups.dc.html` exists (319 lines) as the reference.

**Missing components to build first (Sprint 4 PR #1):**

- group list tile (the Groups list)
- member row (group detail members tab)
- invite-link card (FR-GR-02/03)
- group settle-up surfaces (group-context settle-up)
- group tab bar (group detail tabs — the deferred DC-03 component)

This gap is already tracked: **#79** ("Add group component-catalogue entries: member row +
invite-link card") and the foundation-plan's deferred group tab bar. **PASS — tracked.**

---

## 5.2 Story Definition-of-Ready

The first three Groups stories have **story files** under `docs/sprint-zero/stories/` and map to
open Sprint-4 issues:

| Story | File | Issue |
|---|---|---|
| FR-GR-01 Create group | `FR-GR-01-create-group.md` | #92 |
| FR-GR-02 Invite members | `FR-GR-02-invite-members.md` | #93 |
| FR-GR-03 Invite-link expiry/revocation | `FR-GR-03-invite-link-expiry.md` | #94 |

(FR-SE-05/06/08 and FR-EX-06/07 story files also exist for the settlement/expense-in-group
scope.) `sprint-4-kickoff-readiness.md` exists and records the green light, the five-phase audit
resolution, the Bucket A/B/C disposition, and the first three queued PRs. **PASS** — though the
readiness doc predates this retro and is updated in Phase 8 to fold in the retro's resolution.

---

## 5.3 Backend contracts already in place

The Groups backend was specified in earlier sprints and is **intact**:

- **ADR-0021** (shared `recomputeAndWrite` core with three entry points), **ADR-0022**
  (server-maintained projections are client-read-only), **ADR-0023** (group invite tokens; 7-day
  expiry; admin revocation) are all present in the decision log.
- `firestore.rules` already has a `match /groups/{groupId}` block (line 325). Completing the
  group update/delete rules + the zero-balance-guard enforcement decision + negative tests is
  tracked in **#78**; splitting the rules file before Groups inflates it is **#81**.

Sprint 4 needs only the **Flutter feature + group security-rule activation + the group component
set** — **no new backend ADR is blocked.** (The recompute core, invite-token model, and
projection invariant are reused as-is.) **PASS — tracked.**

---

## 5.4 Telemetry and risk

- **Telemetry:** the Groups events are enumerated in `telemetry-plan.md` — `group_created`
  (`type`, `has_cover_photo`), `groups_list_viewed` (`group_count`), `group_tile_tapped`
  (`group_type`), `create_group_*`, `group_detail_viewed` (`group_type`, `member_count`),
  `group_tab_switched`, `group_expense_tapped`. They carry only enums / counts / bools — **no raw
  group or member identifier** — consistent with the plan's "hash-and-emit, never raw"
  PII convention (§3 / line 303). **PASS.**
- **Risk register** (`docs/sprint-zero/risk-register.md`) carries the Groups risks: **R-04**
  (hot group-balance documents → Firestore throttling; transaction + sharded-counter mitigation),
  **R-06** (simplified-debts algorithm correctness; 100% canonical-matrix branch coverage),
  **R-09** (Firebase Dynamic Links sunset → group invite deep-linking; App/Universal Links
  migration), and **R-03** (integer-paise / Invariant 1). The invite-link expiry/revocation is
  governed by ADR-0023; the remove/leave/delete zero-balance guards are tracked in #78. **PASS.**

---

## Dispositions

| Bucket | Items |
|---|---|
| — | All of Phase 5 is **PASS / tracked**. No new Bucket-A/B/C item originates here. |
| Cross-cutting | The Phase-4 HIGH finding (golden + a11y not yet required checks) should be applied **before** Sprint 4 opens so Groups inherits enforced visual/accessibility gates. The kickoff-readiness doc is refreshed in Phase 8. |

**Verdict:** Sprint 4 (Groups) is ready to start on the Haldi system. The first PR is FR-GR-01
(Create group), and it must build the group Haldi components (§5.1) first — Groups is built
Haldi-native, not reskinned later.
