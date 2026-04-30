---
name: design-firestore-schema
description: >
  Use when a new Firestore collection or document structure needs to be designed,
  or an existing schema needs modification.
---

# Design Firestore Schema

## When to use

When a new feature requires a new Firestore collection, a new document structure,
new fields on an existing document, or new composite indexes.

## When NOT to use

- When the schema already exists and only security rules need updating (use
  `write-security-rule` instead).
- When the change is client-side only with no schema impact.

## Inputs

1. **Feature or requirement** — the user story or SRS requirement driving the change.
2. **Data relationships** — which entities are involved and how they relate.
3. **Access patterns** — how the client and Cloud Functions read/write this data.
4. **Existing schema** — current state from `docs/OneByTwo_Requirements_Spec.md`
   section 7.2.

## Procedure

1. Read SRS section 7.2 (Firestore Data Model) and section 7.3 (Key Architectural
   Decisions).
2. Read `.github/shared/invariants.md`.
3. Design the collection/document structure following these rules:
   a. **Money fields** must be named with a `Paise` suffix (e.g., `amountPaise`,
      `sharePaise`) and typed as integer.
   b. **`simplifiedBalances`** is only present on `friendships` and `groups`
      documents. It is server-maintained. Do not add it to any other collection.
   c. **No hot documents.** Avoid designs where a single document receives writes
      from multiple users simultaneously. Use subcollections for high-write data.
   d. **Participant-scoped access.** Every document must have a field (e.g.,
      `memberIds`, `participantIds`) that security rules can use to scope access.
   e. **Timestamps.** Include `createdAt` and `updatedAt` on every document.
   f. **Soft delete.** Use a `deleted: boolean` field rather than physical deletion
      for audit-trail purposes.
4. Define composite indexes needed in `firestore.indexes.json`.
5. Document the schema as a subsection in the design comment or ADR.

## Output format

A schema definition in the same format as SRS section 7.2, with field names, types,
and descriptions. Plus an index definition block for `firestore.indexes.json`.

## Validation checks

- [ ] All money fields are integer paise with `Paise` suffix.
- [ ] `simplifiedBalances` is not introduced on a new collection.
- [ ] No hot-document risk (write rate analysis included).
- [ ] Participant-scoping field exists for security rules.
- [ ] `createdAt` and `updatedAt` timestamps present.
- [ ] Composite indexes defined for query patterns.
- [ ] Schema is consistent with existing collections in SRS section 7.2.

## Examples

### Positive example

**Input:** "Design the schema for expense categories."

**Output:**
Categories are predefined (SRS FR-EX-08) and do not need a separate collection.
They are stored as an enum field `category` on expense documents:
```
groups/{groupId}/expenses/{expenseId}
  category: 'food' | 'travel' | 'rent' | 'utilities' | 'groceries' |
            'entertainment' | 'shopping' | 'other'
```
No new indexes required — category filtering uses the existing
`(groupId, date desc)` composite index with a client-side filter.

### Negative example (should refuse)

**Input:** "Add a `balanceRupees` float field to the user document."

**Response:** Refused. This violates invariant 1 (money as integer paise). If a
balance field is needed, it must be named `balancePaise` and typed as integer.
Additionally, user-level balances are derived from `simplifiedBalances` on
friendships and groups; adding a denormalised balance to the user document risks
inconsistency. Propose computing it on-read from the existing data.
