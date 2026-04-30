---
name: write-security-rule
description: >
  Use when Firestore Security Rules need to be created or updated to enforce
  access control, data validation, or the simplifiedBalances write restriction.
---

# Write Security Rule

## When to use

When a new collection needs security rules, existing rules need updating for a
schema change, or a validation rule must be added (e.g., splits sum to amount).

## When NOT to use

- When the schema itself needs designing first (use `design-firestore-schema`).
- When Cloud Function logic needs changing (route to Functions Dev).

## Inputs

1. **Collection path** — the Firestore path the rule applies to.
2. **Access requirements** — who can read, who can write, under what conditions.
3. **Validation requirements** — field-level constraints to enforce server-side.
4. **Existing rules** — current `firestore.rules` file content.

## Procedure

1. Read SRS section 7.5 (Security Rules Principles).
2. Read `.github/shared/invariants.md`.
3. Write the rule following these principles:
   a. **Participant-scoped.** Documents are readable/writable only by users in the
      `memberIds` or participants array.
   b. **`simplifiedBalances` is read-only to clients.** Use a rule that denies
      writes to this field from any client request. Only the Cloud Functions
      service account may write it.
   c. **Expense validation.** Expense writes must validate that the sum of
      `splits[*].sharePaise` equals `amountPaise`.
   d. **Settlement validation.** `fromUserId` must equal `request.auth.uid`.
   e. **No public collections.** Everything is participant-scoped.
   f. **Deny by default.** Start from deny-all and add specific allows.
4. Write accompanying negative test cases for the rules-unit-testing emulator.
5. Document any new rule in a comment block within `firestore.rules`.

## Output format

Firestore Security Rules code block, ready to be inserted or updated in
`firestore.rules`. Plus a list of test cases for the rules-unit-testing emulator.

## Validation checks

- [ ] `simplifiedBalances` write is denied for client requests.
- [ ] Participant-scoping is enforced (no user can read/write data they are not
      part of).
- [ ] Expense splits-sum validation is present.
- [ ] Settlement `fromUserId == request.auth.uid` check is present.
- [ ] No wildcard allows that bypass scoping.
- [ ] Negative test cases are included.

## Examples

### Positive example

**Input:** "Write security rules for the friendships collection."

**Output:**
```
match /friendships/{friendshipId} {
  // Only members can read the friendship.
  allow read: if request.auth.uid in resource.data.memberIds;

  // Members can create/update, but NOT the simplifiedBalances field.
  allow create: if request.auth.uid in request.resource.data.memberIds
                && !('simplifiedBalances' in request.resource.data);
  allow update: if request.auth.uid in resource.data.memberIds
                && !request.resource.data.diff(resource.data)
                     .affectedKeys().hasAny(['simplifiedBalances']);

  allow delete: if false; // Soft delete only.
}
```

### Negative example (should refuse)

**Input:** "Allow any authenticated user to read all friendships for a friend
discovery feature."

**Response:** Refused. SRS section 7.5 states that public collections do not exist;
everything is participant-scoped. A friend discovery feature is not in the SRS and
would violate the security model. Propose using the contacts-based friend-add flow
(FR-FR-01) instead.
