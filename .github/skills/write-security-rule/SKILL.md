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
4. **Existing rules** — current `firestore.rules` file content (the canonical example
   of every pattern below) and its companion
   `docs/design/07-technical/firestore-security-rules.md`.

## Procedure

1. Read SRS section 7.5 (Security Rules Principles).
2. Read `.github/shared/invariants.md`.
3. Write the rule following these principles:
   a. **Helper-function decomposition.** Factor shared predicates into top-level
      `function` helpers (e.g. `isSignedIn()`, membership checks, `getFriendship()`),
      mirroring the existing `firestore.rules`. Keep each `match` block readable.
   b. **Participant-scoped.** Documents are readable/writable only by users in the
      `memberIds` (or equivalent) array. There are no public collections.
   c. **`simplifiedBalances` is read-only to clients.** Reject any create that
      includes the field, and on update reject any write whose
      `request.resource.data.diff(resource.data).affectedKeys()` include
      `simplifiedBalances`. Only the server recompute core writes it (Invariant 2).
   d. **Split-sum via bounded enumeration.** Cloud Firestore rules have no list
      `sum`, so validate the split total by **bounded enumeration**: a
      `shareAt(splits, i)` helper that returns `splits[i].sharePaise` when present
      else `0`, summed over a fixed, capped number of indices (friendships cap
      N = 2, so check indices 0 and 1) and required to equal `amountPaise`. Also cap
      `splits` size (1–2 for friendships).
   e. **Settlement validation.** `fromUserId == request.auth.uid`, both parties are
      members of the context, and immutable fields (method, currency,
      verificationStatus) are locked.
   f. **Extension locks.** Pin forward-looking fields to their v1.0 values
      (e.g. `currency == 'INR'`, `source == 'manual'`, `recurringRule`
      absent-or-null).
   g. **No client hard-delete.** `allow delete: if false`; deletions are soft only.
   h. **Deny by default.** Start from deny-all; lock internal collections
      (e.g. `_rateLimits/{document=**}` is `read, write: if false`).
4. Enumerate the positive and negative test scenarios the rule must satisfy and hand
   them to Functions Dev, who writes the rules-unit-testing emulator tests.
5. Document any new rule in a comment block within `firestore.rules`.

## Output format

Firestore Security Rules code block, ready to be inserted or updated in
`firestore.rules`. Plus a list of test cases for the rules-unit-testing emulator.

## Validation checks

- [ ] `simplifiedBalances` is rejected at create and blocked on update via
      `affectedKeys()`.
- [ ] Participant-scoping is enforced (no user can read/write data they are not
      part of).
- [ ] Split-sum is validated by bounded enumeration (capped indices), and `splits`
      size is capped.
- [ ] Settlement `fromUserId == request.auth.uid` check is present.
- [ ] Extension-lock fields (currency/source/recurringRule) are pinned.
- [ ] `allow delete: if false` (no client hard-delete).
- [ ] No wildcard allows that bypass scoping; internal collections are fully locked.
- [ ] Positive and negative test scenarios listed for Functions Dev.

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

**Split-sum bounded enumeration (friendship expense):**
```
function shareAt(splits, i) {
  return i < splits.size() ? splits[i].sharePaise : 0;
}
function sumOfSharesEquals(splits, total) {
  // No list sum exists in rules; enumerate fixed indices up to the N = 2 cap.
  return shareAt(splits, 0) + shareAt(splits, 1) == total;
}
// ... within the expense match block:
allow create: if isFriendshipMember(friendshipId)
              && request.resource.data.splits.size() >= 1
              && request.resource.data.splits.size() <= 2
              && sumOfSharesEquals(request.resource.data.splits,
                                   request.resource.data.amountPaise);
```

> **Canonical reference:** the live `firestore.rules` contains the fully decomposed
> helpers, the bounded-enumeration split check, the `affectedKeys()` guard, and the
> locked `_rateLimits` collection. Treat it as the source of truth and copy its
> patterns rather than inventing new ones.

### Negative example (should refuse)

**Input:** "Allow any authenticated user to read all friendships for a friend
discovery feature."

**Response:** Refused. SRS section 7.5 states that public collections do not exist;
everything is participant-scoped. A friend discovery feature is not in the SRS and
would violate the security model. Propose using the contacts-based friend-add flow
(FR-FR-01) instead.
