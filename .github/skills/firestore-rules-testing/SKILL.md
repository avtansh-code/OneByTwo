---
name: firestore-rules-testing
description: Guide for writing and testing Firestore and Cloud Storage security rules for the One By Two app. Use this when asked to write, update, or test Firebase security rules.
---

## Rules Locations

- Firestore rules: `functions/firestore.rules` (or `firestore.rules` at project root)
- Storage rules: `storage.rules` at project root

## Testing Framework

Use `@firebase/rules-unit-testing` with the Firebase Emulator Suite.

```typescript
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'one-by-two-test',
    firestore: {
      rules: fs.readFileSync('firestore.rules', 'utf8'),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});
```

## Test Patterns

### Test authenticated user can read their own profile
```typescript
test('user can read own profile', async () => {
  const userId = 'user123';
  const db = testEnv.authenticatedContext(userId).firestore();
  await assertSucceeds(db.doc(`users/${userId}`).get());
});
```

### Test user cannot read another user's profile details they shouldn't access
```typescript
test('user cannot write another user profile', async () => {
  const db = testEnv.authenticatedContext('user1').firestore();
  await assertFails(db.doc('users/user2').set({ name: 'Hacker' }));
});
```

### Test group member access
```typescript
test('group member can read group expenses', async () => {
  // Setup: add member to group
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('groups/g1/members/user1').set({
      userId: 'user1', role: 'member', isActive: true
    });
  });

  const db = testEnv.authenticatedContext('user1').firestore();
  await assertSucceeds(db.collection('groups/g1/expenses').get());
});
```

### Test non-member cannot access group
```typescript
test('non-member cannot read group expenses', async () => {
  const db = testEnv.authenticatedContext('outsider').firestore();
  await assertFails(db.collection('groups/g1/expenses').get());
});
```

## Required Test Cases

For each collection, test both **positive** (allowed) and **negative** (denied) access:

| Collection | Positive Cases | Negative Cases |
|------------|---------------|----------------|
| `users/{uid}` | Owner reads/writes own doc | Other user writes, unauthenticated read |
| `groups/{gid}` | Member reads, admin updates | Non-member reads, member deletes |
| `groups/{gid}/expenses` | Member creates/reads, member edits | Non-member access, client hard-delete |
| `groups/{gid}/balances` | Member reads | Any client writes (Cloud Functions only) |
| `groups/{gid}/activity` | Member reads | Any client writes |
| `invites/{code}` | Authenticated reads | Any client writes |

## Running Rules Tests

```bash
cd functions
npm test                              # Run all tests
npm test -- --grep "security rules"   # Run only rules tests

# Or with emulator
firebase emulators:exec 'npm test'
```
