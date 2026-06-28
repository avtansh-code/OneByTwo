# Phase 3 — Documentation and Decision Drift

**Owner:** Architect (lead) + PM + Designer (consulting)
**Scope:** visual-layer docs vs the Haldi handoff; decision-log currency; the planning pack
vs delivery; convention back-ports. Backend/data docs are checked for drift but not re-planned.
**Status:** all findings are Bucket-A doc fixes, applied in this branch.

---

## 3.1 Visual-layer docs vs the handoff

**Finding (fixed):** ADR-0024 (item 2) declared the visual-layer docs superseded by the Haldi
handoff, but **none of them carried a supersession marker** — and `tokens.md` still presents the
old Indigo/Saffron palette under a "Canonical reference: SRS section 6.2" header, exactly the
"silently contradicts what shipped" trap. A Sprint-4 agent opening `docs/design/README.md` (the
package index, also unmarked) or `tokens.md`/`components.md`/`typography-and-formatting.md` would
build against the stale visual system.

**Remediation:** a `> [!WARNING]` supersession banner was prepended to all **21** superseded
visual `.md` files (the four `02-design-system` foundation docs, all of `04-wireframes/*`, all of
`06-screen-specs/*`, `05-mockups/README.md`), each pointing to the Haldi handoff + ADR-0024. The
package index `docs/design/README.md` received a **scoped** banner that marks the visual artefacts
superseded while explicitly preserving the backend/data artefacts as authoritative.

**Backend/data docs — UNCHANGED (verified):** `docs/design/03-architecture/*` and
`07-technical/{firestore-schema, firestore-security-rules, cloud-functions-catalogue,
telemetry-plan, state-management}` carry **no** Haldi/Bricolage/marigold reference — the
conversion did not drift them (ADR-0024 item 3). They are not re-planned here. (`02-design-system/
extension-points.md` is not in ADR-0024's superseded list and is left unmarked — it is a feature
extension-point doc, not a visual spec.)

| Location | Finding | Severity | Action |
|---|---|---|---|
| `docs/design/README.md` + 21 superseded visual docs | no "superseded by Haldi" marker (would mislead Sprint 4) | High | **Fix now** — add supersession banners |
| `docs/design/03-architecture/*`, `07-technical/*` | none — no Haldi drift | — | PASS (unchanged) |

---

## 3.2 Decision-log currency

ADR-0024 (Haldi adoption) and ADR-0025 (§4.1 reconciliation) were re-read against what shipped
(`OBTText` amount tiers, the marigold/ink palette, the settle-up `BoxDecoration` separation, the
activity-row colour discipline) — **accurate, no correction needed.**

**Finding (fixed):** design decisions made implicitly across the DC PRs and the #143 follow-up
were not written down as contracts. Back-ported as **ADR-0026 — Sprint-3 Retro: Money-Glyph,
Single-Line-Fit, and Golden-Fixture Contracts**, which ratifies:

1. Amounts render in Bricolage; the `OBTText.rupeeAware` helper fixes ₹-in-Hanken sentences
   (operationalises §3.3 / ADR-0025).
2. The single-line-fit standard (`FittedBox` scale-to-fit; money never wraps/truncates),
   generalising the #143 one-line balance-pill contract (`[icon] [amount]`; label as subtitle)
   app-wide.
3. Golden fixtures render the intended state (`Stream Function()` builders + the
   `expectGoldenState` guard; ubuntu-only authoring).

No data/rule/function/trigger/schema/telemetry contract moves — these are display/test
conventions, so no invariant or backend ADR is touched.

---

## 3.3 The planning pack vs delivery

`docs/audits/design-conversion/` (the plan) reconciles cleanly with what shipped:

- **`02-conversion-checklist.md`** — every screen row carries a "Status — done (DC-0x / PR #…)"
  with branch names for Auth (DC-04), Home (DC-05), Friends (DC-06), Expenses (DC-07),
  Settlements (DC-08), Activity (DC-09), Profile (DC-10), dark parity (DC-11), a11y re-verified
  (DC-12), goldens authored (DC-13). The conversion is complete.
- **`03-foundation-plan.md` §4.1** — the six-widget reskin map and the three amount tiers shipped
  as ADR-0025 records; §3.3 (amounts in Bricolage tabular) is the rule this retro reinforces.
- **`01-coverage-gap.md`** — closed; the converted heroes and DC-03 components are covered by the
  golden + a11y tiers.
- **Component split** — 11 DC-03 components were built; the **group** components (group list item,
  member row, invite-link card, group settle-up) were correctly **deferred to Sprint 4** (Groups /
  Phase3d is out of scope), consistent with the planned 11-vs-(11+groups) split.

**Minor (accepted, Bucket C):** a few planning-time annotations in `02-conversion-checklist.md`
(e.g. the balance-pill row's "~80% built; needs the icon") are now historical — the pill shipped
and #143 finalised it. These are planning-doc snapshots, not live specs; left as-is rather than
rewriting the historical checklist.

---

## 3.4 Conventions and standards (back-ports)

The canonical Sprint-3 patterns are now written down (single source of truth, no doc-vs-doc
duplication):

- **`.github/shared/coding-standards.md`** — the **Money** section gained the
  "amounts render in Bricolage / never a Hanken slot / `rupeeAware` for sentences" and
  "money never wraps or truncates (`FittedBox` scale-to-fit)" rules; a new **"Visual fidelity and
  golden tests (Haldi)"** subsection codifies the Haldi-canonical rule, ubuntu-only golden
  authoring, and the fresh-stream + `expectGoldenState` fixture rule.
- **`docs/patterns/feature-pr-conventions.md`** — a concise golden/visual note added to the test
  layers, **pointing to** coding-standards + ADR-0026 rather than duplicating them.
- **`.github/shared/decision-log.md`** — ADR-0026 (above).

| Location | Finding | Severity | Action |
|---|---|---|---|
| `coding-standards.md` / `feature-pr-conventions.md` | Sprint-3 money/golden/single-line patterns uncodified | Medium | **Fix now** — back-port |
| `decision-log.md` | implicit DC/#143 decisions not ratified | Medium | **Fix now** — ADR-0026 |

---

## Dispositions

| Bucket | Items |
|---|---|
| **A — fix now** | Supersession banners (22 files); ADR-0026; coding-standards + feature-pr-conventions back-ports. All doc-only; land in the cleanup PR. |
| **C — accept + document** | Historical planning-time notes in `02-conversion-checklist.md` (left as a snapshot). |

No Bucket-B items from Phase 3. **Verification:** markdown banners render as GitHub alerts; no
backend/data doc was edited; `docs/OneByTwo_Requirements_Spec.md` untouched.
