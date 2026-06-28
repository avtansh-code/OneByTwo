# Deferred to a Milestone (Bucket B) — Sprint 3 Boundary Sweep

Per `.github/shared/milestone-tracking.md`, each Bucket-B finding from the Sprint-3 audit is
filed as a GitHub issue on the milestone that owns the work (no deprecated labels). The
milestone choice and its one-line rationale are recorded as an issue comment so the decision is
auditable.

| Issue | Title | Milestone | Source | Rationale |
|---|---|---|---|---|
| [#145](https://github.com/avtansh-code/OneByTwo/issues/145) | Require Golden & A11y Checks + Accessibility Gate as PR status checks | **Sprint 4** | `04` §4.4 | The DC-12/DC-13 gates must be enforced before Groups opens, so Groups inherits them. Owner action (repo setting). |
| [#146](https://github.com/avtansh-code/OneByTwo/issues/146) | Verify the nightly backend-sync deploy pipeline runs green | **Sprint 4** | `04` §4.3 | The pipeline guards the rules/indexes Groups will extend; verifying it green is a Sprint-4 pre-flight check. |
| [#147](https://github.com/avtansh-code/OneByTwo/issues/147) | Dependency refresh: `firebase_*` bumps + functions transitive advisories | **Post-v1.0** | `04` §4.2 | No HIGH/CRITICAL, none Sprint-3-introduced; a major `firebase-admin`/`riverpod 3.x` bump is its own project. |

## Notes

- **#145 is the load-bearing one** — it is the Phase-4 HIGH finding and the only Bucket-A *owner
  action* (it cannot be done in a PR, so it is also tracked here as Bucket B for auditability).
  It should be applied before Sprint 4 opens.
- All Bucket-A code/doc fixes shipped in **PR #144**; nothing else from the Sprint-3 audit is
  deferred.
- Bucket-C items (the segmented-split running-total; historical planning-checklist notes) are
  accepted and recorded in `01-design-fidelity-validation.md` §6 and
  `03-documentation-and-decision-drift.md` §3.3 — not filed as issues.
