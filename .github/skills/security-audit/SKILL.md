---
name: security-audit
description: "Comprehensive security audit checklist covering OWASP Mobile Top 10, PII protection, GDPR compliance, and Firestore security rules for the One By Two app."
---

# Security Audit Guide

## OWASP Mobile Top 10 Checklist

| # | Risk | Status | Implementation |
|---|------|--------|---------------|
| M1 | Improper Credential Usage | ✅ | Firebase Auth manages tokens; stored in `flutter_secure_storage` |
| M2 | Inadequate Supply Chain Security | 🔍 | Audit: `dart pub audit`, `npm audit`. Lock files committed. |
| M3 | Insecure Authentication/Authorization | ✅ | Phone OTP via Firebase Auth; Firestore rules enforce access |
| M4 | Insufficient Input/Output Validation | 🔍 | Cloud Functions validate all inputs; Firestore rules validate schema |
| M5 | Insecure Communication | ✅ | TLS 1.3 everywhere; Firebase SDK handles transport |
| M6 | Inadequate Privacy Controls | ✅ | No 3rd-party tracking; Firebase Analytics only; GDPR compliance |
| M7 | Insufficient Binary Protections | 🔍 | `--obfuscate --split-debug-info`; ProGuard enabled |
| M8 | Security Misconfiguration | 🔍 | Firestore rules tested; no debug in production builds |
| M9 | Insecure Data Storage | ✅ | Firestore encryption at rest; secure storage for tokens |
| M10 | Insufficient Cryptography | ✅ | No custom crypto; Firebase server-side encryption |

**Legend:** ✅ = Implemented and verified | 🔍 = Requires periodic audit

---

## PII Audit Commands

### Find Potential PII in Code

```bash
grep -rn "phone\|email\|password\|token\|secret\|key" lib/ --include="*.dart" | grep -v "test\|mock\|example"
```

### Find Logging of PII

```bash
grep -rn "log\|print\|debug" lib/ --include="*.dart" | grep -i "phone\|email\|token"
```

### Find Hardcoded Secrets

```bash
grep -rn "AIza\|firebase\|api[_-]key\|secret\|password" . --include="*.dart" --include="*.ts" --include="*.json" | grep -v node_modules
```

### PII Classification

| Data | Classification | Can Log? | Can Store Locally? |
|------|---------------|----------|-------------------|
| Phone number | PII | ❌ Never | ❌ Only in secure storage |
| Email address | PII | ❌ Never | ❌ Only in secure storage |
| Display name | PII | ❌ Never | ✅ Encrypted DB |
| User ID | Pseudonymous | ✅ Yes | ✅ Yes |
| Document ID | Non-PII | ✅ Yes | ✅ Yes |
| Amount (paise) | Non-PII | ✅ Yes | ✅ Yes |
| Auth token | Secret | ❌ Never | ❌ Only flutter_secure_storage |
| Firebase API key | Semi-public | ❌ Don't log | ✅ In config files (expected) |

---

## GDPR Compliance Matrix

| Right | Article | Implementation | Status |
|-------|---------|---------------|--------|
| Access | Art. 15 | `exportData` Cloud Function → CSV/PDF | [ ] |
| Erasure | Art. 17 | `deleteAccount` → removes all user data across collections | [ ] |
| Portability | Art. 20 | CSV/PDF export of all expenses/settlements | [ ] |
| Minimization | Art. 5 | Only collect: name, email, phone, avatar | [ ] |
| Consent | Various | Push: explicit opt-in; Contacts: permission dialog; Analytics: legitimate interest | [ ] |
| Notification | Art. 34 | Breach notification process documented | [ ] |

### Data Retention

- **Active accounts:** Data retained while account is active.
- **Deleted accounts:** All PII removed within 30 days. Aggregated/anonymized data may be retained.
- **Logs:** Rotated every 30 days on device; Crashlytics retains for 90 days.
- **Backups:** Firestore PITR (Point-in-Time Recovery) retains for 7 days.

### Account Deletion Flow

The `deleteAccount` Cloud Function must:

1. Delete `users/{uid}` document
2. Remove user from all `groups/{gid}/members/{uid}`
3. Delete `userGroups/{uid}` and all subcollections
4. Delete `userFriends/{uid}` and all subcollections
5. Delete user from all `friends/{fid}` where user is a participant
6. Delete all `notifications/{nid}` for user
7. Delete all `drafts/{did}` for user
8. Revoke all active sessions via Firebase Auth
9. Delete Firebase Auth account
10. Log deletion event (without PII) for audit trail

---

## Firestore Security Rules Audit

| Collection | Read | Write | Create | Delete | Validated |
|-----------|------|-------|--------|--------|-----------|
| `users/{uid}` | self | self | auth | never | [ ] |
| `groups/{gid}` | member | admin+ | auth | never | [ ] |
| `groups/{gid}/members` | member | admin+ | admin+ | admin+ | [ ] |
| `groups/{gid}/expenses` | member | member | member | soft only | [ ] |
| `groups/{gid}/expenses/splits` | member | member | member | member | [ ] |
| `groups/{gid}/expenses/payers` | member | member | member | member | [ ] |
| `groups/{gid}/settlements` | member | member | member | soft only | [ ] |
| `groups/{gid}/balances` | member | CF only | CF only | CF only | [ ] |
| `groups/{gid}/activity` | member | CF only | CF only | CF only | [ ] |
| `friends/{fid}` | pair | pair | CF only | never | [ ] |
| `friends/{fid}/expenses` | pair | pair | pair | soft only | [ ] |
| `friends/{fid}/settlements` | pair | pair | pair | soft only | [ ] |
| `friends/{fid}/balance` | pair | CF only | CF only | CF only | [ ] |
| `invites/{code}` | auth | CF only | CF only | CF only | [ ] |
| `userGroups/{uid}/groups` | self | CF only | CF only | CF only | [ ] |
| `userFriends/{uid}/friends` | self | CF only | CF only | CF only | [ ] |

**Key:**

- `self` = `request.auth.uid == userId`
- `member` = user exists in `groups/{gid}/members`
- `admin+` = member with role `admin` or `owner`
- `pair` = user is one of the two users in the friend pair
- `CF only` = Cloud Functions service account only (deny client writes)
- `soft only` = set `isDeleted: true` instead of actual deletion

---

## Security Scan Commands

### Dependency Audit

```bash
# Dart/Flutter dependencies
dart pub audit

# Cloud Functions dependencies
cd functions && npm audit
```

### Secret Scanning

```bash
# Scan for leaked secrets in git history
gitleaks detect --source . --verbose

# Quick check for common patterns
grep -rn "AKIA\|AIza\|sk_live\|sk_test\|-----BEGIN" . --include="*.dart" --include="*.ts" --include="*.json" --include="*.yaml" | grep -v node_modules | grep -v ".pub-cache"
```

### Debug Code in Release

```bash
# Find debug-only code that should not ship
grep -rn "kDebugMode\|assert(" lib/ --include="*.dart"

# Find print statements (should use AppLogger instead)
grep -rn "print(" lib/ --include="*.dart" | grep -v "// ignore: avoid_print"

# Find TODO/FIXME that may be security-related
grep -rn "TODO\|FIXME\|HACK\|XXX" lib/ --include="*.dart" | grep -i "secur\|auth\|token\|pii\|encrypt"
```

### Build Hardening Verification

```bash
# Verify obfuscation is enabled in release builds
grep -rn "obfuscate\|split-debug-info\|proguard" android/app/build.gradle pubspec.yaml Makefile

# Verify no debug flags in release config
grep -rn "debugShowCheckedModeBanner\|debugPrint" lib/ --include="*.dart"
```

---

## Security Review Checklist for PRs

- [ ] No PII logged (phone, email, name, token)
- [ ] No hardcoded secrets or API keys
- [ ] Firestore security rules updated if new collection/field added
- [ ] Input validation on all user-provided data
- [ ] Error messages don't leak internal details to users
- [ ] New dependencies audited (`dart pub audit`)
- [ ] Amounts validated as non-negative integers (paise)
- [ ] No raw `print()` statements (use `AppLogger`)
- [ ] Sensitive data in `flutter_secure_storage`, not SharedPreferences
