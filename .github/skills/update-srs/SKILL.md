---
name: update-srs
description: >
  Use when the Software Requirements Specification needs a proposed update due to
  a scope change, resolved ambiguity, or new requirement.
---

# Update SRS

## When to use

When a change to the SRS is needed — a new requirement, a scope clarification, a
resolved ambiguity, or a correction. SRS changes follow a proposal-and-review
process; they are never applied unilaterally. The current approved baseline is
`docs/OneByTwo_Requirements_Spec.md` version 1.1, as pointed to by
`.github/shared/srs-pointer.md`.

## When NOT to use

- When writing a user story from an existing SRS requirement (use `new-user-story`).
- When the change is an ADR (update `.github/shared/decision-log.md` directly).
- When the request is to edit the SRS directly without an approved proposal.
  Refuse direct edits and provide a proposal instead.

## Inputs

1. **Section to update** — which SRS section is affected.
2. **Proposed change** — the specific text to add, modify, or remove.
3. **Rationale** — why the change is needed.
4. **Requestor** — which agent or user is proposing the change.
5. **Evidence** — repo paths, existing stories, workflow files, or ADRs that
   show why the proposal is needed.

## Procedure

1. Read `.github/shared/srs-pointer.md` and the current SRS at
   `docs/OneByTwo_Requirements_Spec.md`. Do not edit the SRS while drafting.
2. Read `.github/shared/invariants.md` — the change must not violate any
   invariant.
3. Verify the request against current repo evidence, such as
   `.github/ISSUE_TEMPLATE/user_story.md`, `docs/sprint-zero/stories/*.md`,
   `.github/workflows/release.yml`, feature folders, Firestore rules, and ADRs.
4. Draft the proposed change:
   a. Show the current text (if modifying) and the proposed replacement.
   b. For new requirements, assign an ID following the existing convention
      (FR-XX-NN) and a priority (P0 / P1 / P2).
   c. For scope changes, update section 12.3 (out-of-scope list) accordingly.
5. Assess impact:
   a. Which agents are affected by this change?
   b. Which existing user stories need updating?
   c. Does this change require a new ADR?
   d. Which tests, security rules, workflows, or release notes may need updates?
6. Present the proposal for review. The SRS change requires approval from:
   a. PM (scope ownership).
   b. Architect (technical feasibility).
7. Do not apply the SRS edit unless the user explicitly asks for the approved
   change to be implemented. Until then, the output is a proposal only and the
   SRS remains version 1.1.

## Output format

A change proposal document with:

1. Section affected.
2. Current text or current baseline summary.
3. Proposed text.
4. Rationale.
5. Repo evidence.
6. Impact assessment.
7. Required approvers.
8. Refusal notes if the request violates an invariant or approved scope.

## Validation checks

- [ ] Change does not violate any invariant.
- [ ] New requirements have proper IDs and priorities.
- [ ] Impact assessment identifies affected agents and stories.
- [ ] Proposal is presented for review, not applied unilaterally.
- [ ] `docs/OneByTwo_Requirements_Spec.md` is not edited during proposal
      drafting.
- [ ] SRS version remains 1.1 unless an approved edit is explicitly requested.

## Examples

### Positive example

**Input:** "Propose an SRS clarification for receipt image compression before upload."

**Output:**
```
## SRS Change Proposal

### Section: 4.5 Expense Management

**Current:** FR-EX-05 — Users shall be able to attach a receipt image to an
expense (camera or gallery), stored in Firebase Storage.

**Proposed:** FR-EX-05 — Users shall be able to attach a receipt image to an
expense (camera or gallery). Images shall be compressed to a maximum of 1 MB
before upload and stored in Firebase Storage.

**New requirement:** FR-EX-10 — Receipt images shall be compressed client-side
to a maximum file size of 1 MB before upload. Priority: P1.

**Rationale:** Reduces storage costs and improves upload speed on slow networks.
**Repo evidence:** Receipt upload is an expenses feature; pre-merge testing uses
the Firebase Emulator Suite; money and currency invariants are unaffected.
**Impact:** Flutter Dev (image compression), QA (new test case), Architect
(Storage rule impact review).
**Approvers:** PM, Architect.
```

### Negative example (should refuse)

**Input:** "Update the SRS to allow multiple currencies."

**Response:** Refused. Multi-currency support is listed in SRS section 1.3 as out
of scope for v1.0. This would also violate invariant 1 (INR paise only). Propose
this for a future version if needed.
