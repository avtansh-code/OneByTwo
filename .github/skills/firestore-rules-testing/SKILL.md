---
name: firestore-rules-testing
description: "Guide for testing Firestore security rules using @firebase/rules-unit-testing. Includes setup, test patterns, and required test matrix for all collections."
---

# Firestore Security Rules Testing

## Setup

```typescript
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { doc, getDoc, setDoc, deleteDoc, collection, getDocs } from 'firebase/firestore';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'one-by-two-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});
```

---

## Test Patterns

### Authenticated User Context

```typescript
const aliceDb = testEnv.authenticatedContext('alice').firestore();
```

### Unauthenticated Context

```typescript
const unauthDb = testEnv.unauthenticatedContext().firestore();
```

### Seeding Test Data

Always seed data with security rules disabled to set up preconditions:

```typescript
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  // Add alice as a group member
  await setDoc(doc(db, 'groups/g1'), {
    name: 'Trip to Goa',
    createdBy: 'alice',
    createdAt: new Date(),
  });
  await setDoc(doc(db, 'groups/g1/members/alice'), {
    userId: 'alice',
    isActive: true,
    role: 'admin',
    joinedAt: new Date(),
  });
});
```

### Positive Test (should succeed)

```typescript
test('group member can read group expenses', async () => {
  // Seed: add alice as group member
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'groups/g1/members/alice'), {
      userId: 'alice',
      isActive: true,
      role: 'member',
    });
    await setDoc(doc(db, 'groups/g1/expenses/e1'), {
      description: 'Dinner',
      totalAmountPaise: 10000,
      createdBy: 'alice',
    });
  });

  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(getDocs(collection(aliceDb, 'groups/g1/expenses')));
});
```

### Negative Test (should fail)

```typescript
test('non-member cannot read group expenses', async () => {
  // Seed: add alice as member, but bob is NOT a member
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'groups/g1/members/alice'), {
      userId: 'alice',
      isActive: true,
      role: 'member',
    });
  });

  const bobDb = testEnv.authenticatedContext('bob').firestore();
  await assertFails(getDocs(collection(bobDb, 'groups/g1/expenses')));
});
```

### Unauthenticated Access Test

```typescript
test('unauthenticated user cannot read any group data', async () => {
  const unauthDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(unauthDb, 'groups/g1')));
  await assertFails(getDocs(collection(unauthDb, 'groups/g1/expenses')));
});
```

---

## Required Test Matrix

Every collection must have tests for each access pattern. ✅ = should succeed, ❌ = should fail.

| Collection | Read (member) | Read (non-member) | Write (member) | Write (non-member) | Write (owner/admin) | Notes |
|-----------|:---:|:---:|:---:|:---:|:---:|-------|
| `users/{uid}` | ✅ self | ❌ other | ✅ self | ❌ other | N/A | Self-only read/write |
| `groups/{gid}` | ✅ | ❌ | ✅ admin+ | ❌ | ✅ | Owner/admin can edit group settings |
| `groups/{gid}/members` | ✅ | ❌ | ✅ admin+ | ❌ | ✅ | Admin can add/remove members |
| `groups/{gid}/expenses` | ✅ | ❌ | ✅ | ❌ | ✅ delete | Any member can add; owner/admin can delete |
| `groups/{gid}/balances` | ✅ | ❌ | ❌ all | ❌ | ❌ | Cloud Functions only (no client writes) |
| `groups/{gid}/activity` | ✅ | ❌ | ❌ all | ❌ | ❌ | Cloud Functions only (no client writes) |
| `friends/{fid}` | ✅ pair | ❌ other | ✅ pair | ❌ | N/A | Only the two friend users can access |
| `friends/{fid}/balance` | ✅ pair | ❌ | ❌ all | ❌ | N/A | Cloud Functions only |
| `invites/{code}` | ✅ public | ✅ | ❌ all | ❌ | N/A | Cloud Functions only (read-only for clients) |

### Test Matrix Implementation

```typescript
describe('Security Rules', () => {
  // --- users/{uid} ---
  describe('users collection', () => {
    test('user can read own profile', async () => {
      await seedUser('alice');
      const aliceDb = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(getDoc(doc(aliceDb, 'users/alice')));
    });

    test('user cannot read another user profile', async () => {
      await seedUser('alice');
      const bobDb = testEnv.authenticatedContext('bob').firestore();
      await assertFails(getDoc(doc(bobDb, 'users/alice')));
    });

    test('user can write own profile', async () => {
      const aliceDb = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(setDoc(doc(aliceDb, 'users/alice'), { name: 'Alice' }));
    });

    test('user cannot write another user profile', async () => {
      const bobDb = testEnv.authenticatedContext('bob').firestore();
      await assertFails(setDoc(doc(bobDb, 'users/alice'), { name: 'Hacked' }));
    });

    test('unauthenticated cannot read user profile', async () => {
      await seedUser('alice');
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(unauthDb, 'users/alice')));
    });
  });

  // --- groups/{gid}/expenses ---
  describe('group expenses', () => {
    test('member can create expense', async () => {
      await seedGroupWithMember('g1', 'alice', 'member');
      const aliceDb = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(
        setDoc(doc(aliceDb, 'groups/g1/expenses/e1'), {
          description: 'Lunch',
          totalAmountPaise: 5000,
          createdBy: 'alice',
        })
      );
    });

    test('non-member cannot create expense', async () => {
      await seedGroupWithMember('g1', 'alice', 'member');
      const bobDb = testEnv.authenticatedContext('bob').firestore();
      await assertFails(
        setDoc(doc(bobDb, 'groups/g1/expenses/e1'), {
          description: 'Lunch',
          totalAmountPaise: 5000,
          createdBy: 'bob',
        })
      );
    });
  });

  // --- groups/{gid}/balances (Cloud Functions only) ---
  describe('group balances', () => {
    test('member can read balances', async () => {
      await seedGroupWithMember('g1', 'alice', 'member');
      await seedBalance('g1', 'alice', 5000);
      const aliceDb = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(getDocs(collection(aliceDb, 'groups/g1/balances')));
    });

    test('no client can write balances', async () => {
      await seedGroupWithMember('g1', 'alice', 'admin');
      const aliceDb = testEnv.authenticatedContext('alice').firestore();
      await assertFails(
        setDoc(doc(aliceDb, 'groups/g1/balances/alice'), { amount: 9999 })
      );
    });
  });
});
```

---

## Helper Functions

```typescript
async function seedUser(uid: string) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${uid}`), {
      name: uid,
      email: `${uid}@example.com`,
      createdAt: new Date(),
    });
  });
}

async function seedGroupWithMember(groupId: string, uid: string, role: string) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `groups/${groupId}`), {
      name: 'Test Group',
      createdBy: uid,
      createdAt: new Date(),
    });
    await setDoc(doc(db, `groups/${groupId}/members/${uid}`), {
      userId: uid,
      isActive: true,
      role: role,
      joinedAt: new Date(),
    });
  });
}

async function seedBalance(groupId: string, uid: string, amountPaise: number) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `groups/${groupId}/balances/${uid}`), {
      userId: uid,
      amountPaise: amountPaise,
      updatedAt: new Date(),
    });
  });
}
```

---

## Running Tests

```bash
# Start the Firestore emulator and run tests
cd functions
firebase emulators:exec --only firestore "npm test -- --grep 'security rules'"

# Run all rules tests specifically
firebase emulators:exec --only firestore "npx jest --testPathPattern='rules'"

# Run with verbose output for debugging
firebase emulators:exec --only firestore "npx jest --verbose --testPathPattern='rules'"
```

---

## Security Rules Testing Checklist

- [ ] All collections in the matrix have both positive and negative tests
- [ ] Unauthenticated access is denied for all protected collections
- [ ] Self-only collections (`users/{uid}`) enforce `request.auth.uid == uid`
- [ ] Group membership is verified for all group sub-collections
- [ ] Cloud Functions-only collections reject all client writes
- [ ] Admin/owner role escalation is tested (member cannot perform admin actions)
- [ ] Friend pair access is verified (only the two users in the friendship)
- [ ] Invite codes are publicly readable but not writable by clients
- [ ] Data validation rules are tested (required fields, correct types)
- [ ] Tests run against the actual `firestore.rules` file (not a copy)
