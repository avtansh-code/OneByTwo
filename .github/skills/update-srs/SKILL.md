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
process; they are never applied unilaterally.

## When NOT to use

- When writing a user story from an existing SRS requirement (use `new-user-story`).
- When the change is an ADR (update `.github/shared/decision-log.md` directly).

## Inputs

1. **Section to update** — which SRS section is affected.
2. **Proposed change** — the specific text to add, modify, or remove.
3. **Rationale** — why the change is needed.
4. **Requestor** — which agent or user is proposing the change.

## Procedure

1. Read the current SRS at `docs/OneByTwo_Requirements_Spec.md`.
2. Read `.github/shared/invariants.md` — the change must not violate any invariant.
3. Draft the proposed change:
   a. Show the current text (if modifying) and the proposed replacement.
   b. For new requirements, assign an ID following the existing convention
      (FR-XX-NN) and a priority (P0 / P1 / P2).
   c. For scope changes, update section 12.3 (out-of-scope list) accordingly.
4. Assess impact:
   a. Which agents are affected by this change?
   b. Which existing user stories need updating?
   c. Does this change require a new ADR?
5. Present the proposal for review. The SRS change requires approval from:
   a. PM (scope ownership).
   b. Architect (technical feasibility).
6. Once approved, apply the change and increment the document version in section
   13.3.

## Output format

A change proposal document with: current text, proposed text, rationale, impact
assessment, and required approvers.

## Validation checks

- [ ] Change does not violate any invariant.
- [ ] New requirements have proper IDs and priorities.
- [ ] Impact assessment identifies affected agents and stories.
- [ ] Document version is incremented.
- [ ] Proposal is presented for review, not applied unilaterally.

## Examples

### Positive example

**Input:** "Add a requirement for receipt image compression before upload."

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
**Impact:** Flutter Dev (image compression), QA (new test case).
**Approvers:** PM, Architect.
```

### Negative example (should refuse)

**Input:** "Update the SRS to allow multiple currencies."

**Response:** Refused. Multi-currency support is listed in SRS section 1.3 as out
of scope for v1.0. This would also violate invariant 1 (INR paise only). Propose
this for a future version if needed.
