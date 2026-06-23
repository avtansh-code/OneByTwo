# Milestone Tracking

This file defines how sprint membership is tracked on GitHub and how milestones are
kept in sync as pull requests merge. Every agent that creates an issue, reviews a
pull request, or runs a release must read this file.

Reference: SRS section 2.1 (Working Agreement Between Agents); the rolling-roadmap
reconciliation convention in `docs/sprint-zero/next-three-prs.md`.

---

## Mechanism: GitHub Milestones, not labels

Sprint membership is tracked with **GitHub Milestones**, one per sprint, plus a
single post-launch bucket. An issue belongs to exactly one milestone — its single,
unambiguous owning sprint. Do **not** reintroduce per-sprint labels; the legacy
`sprint-2-chore` label is historical (closed issues only).

| Milestone | Theme |
|---|---|
| `Sprint 3` | Groups and Settlements |
| `Sprint 4` | Notifications, Activity, Dashboard |
| `Sprint 5` | Polish, Support, Offline, Search |
| `Sprint 6` | QA, Performance, Release Prep (v1.0 release candidate) |
| `Post-v1.0` | Deferred beyond the v1.0 release; post-launch enhancements and optimisations |

Sprint themes are authoritative in `docs/design/08-plan/sprint-sequence.md`.
`Post-v1.0` is reserved for work a source explicitly places outside v1.0 (for
example an issue body stating the work is "none of which are in v1.0"); never force
such work into a numbered sprint.

Completed sprints retain a **closed** milestone as a historical record — for
example `Sprint 2` (Friends and Core Expenses), closed at 100% with its 13 closed
issues linked once the Sprint-2 PR set merged. Sprint 1 was delivered PR-first with
no tracked issues, so it has no milestone to populate.

## Rule: assign every issue to a milestone at creation

When an issue is created or triaged it must be assigned to a milestone in the same
action — no issue is left unmilestoned.

- **User stories** (`new-user-story`): assign to the sprint that owns the
  requirement per `sprint-sequence.md`. The current next active sprint is
  `Sprint 3`.
- **Bugs** (`triage-bug`): assign by SLA — S1/S2 to the current active sprint
  (same-day / 3-day fix), S3 to the next sprint, S4 to `Post-v1.0` unless a sprint
  is already committed.
- **Chores / follow-ups**: assign to the sprint stated in the planning docs; if a
  source explicitly defers beyond release, use `Post-v1.0`.
- Record the milestone choice and its one-line rationale as an issue comment so the
  decision is auditable.

## Rule: reconcile the milestone with each passing PR

A pull request that carries `Closes #NN` lines moves those issues to `closed` on
merge, which advances the owning milestone's progress automatically. With **each
passing (merged) PR**, the reviewer/merger must, as part of the standard
rolling-roadmap reconciliation:

1. **Verify** every issue the PR closes carries the correct sprint milestone
   *before* merge (an unmilestoned closed issue is a tracking defect).
2. **Re-home** any issue whose scope was re-scoped by the PR (for example a partial
   close that defers a remainder) to the milestone matching its new target sprint,
   and comment the reason.
3. **Close the milestone** when the PR closes the last open issue in a sprint
   milestone, and confirm the next sprint's milestone is open and populated.
4. **Reconcile the roadmap docs** (`docs/sprint-zero/next-three-prs.md`,
   `docs/sprint-zero/sprint-2-plan.md` and successors) in the same PR, so the
   milestone state and the written roadmap never drift.

## Commands (reference)

Milestones are managed with `gh` (DevOps/QA Bash scope). Create via the API, assign
by title:

```sh
# Create a milestone
gh api repos/{owner}/{repo}/milestones -f title="Sprint 3" -f state="open" \
  -f description="Groups and Settlements"

# Assign an issue to a milestone (by title)
gh issue edit <issue-number> --milestone "Sprint 3"

# Close a completed sprint milestone
gh api repos/{owner}/{repo}/milestones/<milestone-number> -X PATCH -f state="closed"

# Audit: any open issue with no milestone is a tracking defect
gh issue list --state open --json number,title,milestone \
  --jq '.[] | select(.milestone == null) | "#\(.number) \(.title)"'
```

## Ownership

| Action | Owner |
|---|---|
| Milestone exists for each active + next sprint, and `Post-v1.0` | PM |
| Issue assigned to a milestone at creation/triage | PM (stories), QA (bugs) |
| Milestone verified/reconciled on PR merge | QA (review) with the merging agent |
| Sprint milestone closed at sprint end; release scope sourced from it | DevOps (close), PM (release notes) |

No issue ships unmilestoned; no milestone state diverges from the roadmap docs.
