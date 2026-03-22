---
applyTo: "**/*.rules"
---

# Firestore and Storage Security Rules Instructions

## General Principles

- Deny by default. Explicitly allow only what's needed.
- Every collection MUST have explicit rules (no wildcards that grant broad access).
- Read and write rules are separate — don't combine.

## Firestore Rules Structure

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    function isGroupMember(groupId) {
      return exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid))
        && get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.isActive == true;
    }

    function isFriendPairMember(friendPairId) {
      let doc = get(/databases/$(database)/documents/friends/$(friendPairId));
      return request.auth.uid == doc.data.userA || request.auth.uid == doc.data.userB;
    }

    // Users: self-only access
    match /users/{userId} { ... }

    // Groups: member-only access
    match /groups/{groupId} { ... }

    // Friends: pair-member-only access
    match /friends/{friendPairId} { ... }

    // Invites: public read, Cloud Functions write
    match /invites/{inviteCode} { ... }
  }
}
```

## Access Control Rules

- `users/{uid}`: Read/write by self only
- `groups/{gid}`: Read by members, write by admin+
- `groups/{gid}/expenses`: Read by members, write by members, soft-delete by owner/admin
- `groups/{gid}/balances`: Read by members, write DENIED (Cloud Functions only)
- `groups/{gid}/activity`: Read by members, write DENIED (Cloud Functions only)
- `friends/{fid}`: Read/write by pair members only
- `friends/{fid}/balance`: Read by pair, write DENIED (Cloud Functions only)
- `invites/{code}`: Public read (for validation), write DENIED (Cloud Functions only)

## Validation in Rules

- Amounts must be positive integers
- Required fields must exist
- String lengths within limits
- Timestamps are valid

## Testing Requirement

- EVERY rule path must have both positive (allow) and negative (deny) tests.
- Use `@firebase/rules-unit-testing` with Firebase Emulator.
- See the `firestore-rules-testing` skill for test patterns.
