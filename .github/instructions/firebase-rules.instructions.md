---
applyTo: "**/*.rules,**/firestore.rules,**/storage.rules"
---

# Firebase Security Rules Instructions

- Every Firestore collection must have explicit security rules — no open access
- Users can only read groups they are members of (check `groups/{gid}/members/{uid}` exists)
- Balances and activity logs are read-only for clients (only Cloud Functions can write)
- Invites collection is read-only for clients (managed by Cloud Functions)
- All Cloud Storage uploads must be images (`contentType.matches('image/.*')`) with size limits (avatars: 5MB, receipts: 10MB)
- Test every rule with both positive (allowed) AND negative (denied) test cases
- Use helper functions (`isSignedIn()`, `isGroupMember()`, `isGroupAdmin()`) for readability
- Never allow hard-delete of expenses or settlements (soft delete only via `isDeleted` field update)
