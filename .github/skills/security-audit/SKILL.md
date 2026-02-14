---
name: security-audit
description: Guide for auditing security in the One By Two app — OWASP Mobile Top 10, SQLCipher encryption, PII handling, Firebase security rules, data-at-rest/in-transit encryption, and GDPR compliance.
---

## Security Architecture

The app implements a 6-layer security model. See `docs/architecture/08_SECURITY.md` for full details.

## OWASP Mobile Top 10 Checklist

### M1 — Improper Platform Usage
- [ ] Firebase Auth tokens stored securely (Flutter Secure Storage / Keychain / Keystore)
- [ ] No sensitive data in `SharedPreferences` (use `flutter_secure_storage`)
- [ ] App transport security enforced (iOS ATS, Android network_security_config)
- [ ] Deep links validated (GoRouter path matching, no open redirects)

### M2 — Insecure Data Storage
- [ ] sqflite database encrypted with SQLCipher
- [ ] SQLCipher key stored in Keychain (iOS) / Keystore (Android), NOT in app code
- [ ] No PII in log output (`logger` configured to redact phone/email)
- [ ] Receipt images stored in app-private directory (not external storage)
- [ ] Clipboard cleared after copying sensitive data (OTP, settlement amounts)

### M3 — Insecure Communication
- [ ] All network calls use HTTPS (TLS 1.3)
- [ ] Certificate pinning enabled for Firebase endpoints
- [ ] No HTTP cleartext traffic allowed (enforced via platform config)

### M4 — Insecure Authentication
- [ ] Firebase Auth Phone/OTP is the only auth method
- [ ] OTP rate limiting via Firebase (5 attempts per phone per hour)
- [ ] Auth token refresh handled automatically by Firebase SDK
- [ ] Session timeout after extended inactivity (configurable)
- [ ] Biometric/PIN lock (P1) uses local authentication package

### M5 — Insufficient Cryptography
- [ ] SQLCipher uses AES-256 for local database encryption
- [ ] No custom crypto implementations (use platform-provided)
- [ ] Encryption key rotation strategy documented

### M6 — Insecure Authorization
- [ ] Firestore security rules enforce group membership for all reads
- [ ] Group roles (Owner/Admin/Member) checked in Cloud Functions
- [ ] Balances and activity logs are client-read-only (Cloud Functions write)
- [ ] Users cannot access other users' profile details beyond name/avatar

### M7 — Client Code Quality
- [ ] `flutter analyze` passes with zero warnings
- [ ] No hardcoded secrets, API keys, or credentials in source
- [ ] Firebase config files (`google-services.json`, `GoogleService-Info.plist`) in `.gitignore`
- [ ] ProGuard/R8 enabled for release builds (code obfuscation)
- [ ] `--obfuscate --split-debug-info` flags used for release builds

### M8 — Code Tampering
- [ ] App signing verified (Play App Signing, Apple code signing)
- [ ] Root/jailbreak detection (optional, P2)
- [ ] Integrity checks on critical local data (balance checksums)

### M9 — Reverse Engineering
- [ ] Code obfuscation enabled (Dart `--obfuscate`)
- [ ] No business logic secrets in client code (debt simplification runs server-side too)
- [ ] API keys restricted via Firebase project settings

### M10 — Extraneous Functionality
- [ ] No debug endpoints in production
- [ ] No test accounts or backdoors
- [ ] Logging level set to `warning` in production builds
- [ ] Firebase Emulator connection disabled in production

## PII Audit

Search for potential PII leaks:

```bash
# Check for phone numbers in logs
grep -rn "print\|log\|debugPrint\|Logger" lib/ | grep -i "phone\|mobile\|number\|email"

# Check for PII in Firestore writes (should be in designated fields only)
grep -rn "phone\|email\|name" lib/data/ | grep -i "log\|print\|debug"

# Check SharedPreferences usage (should only store non-sensitive prefs)
grep -rn "SharedPreferences\|getSharedPreferences" lib/
```

## GDPR/Data Privacy Compliance

| Requirement | Implementation |
|-------------|---------------|
| Right to access | Export user data via Cloud Function `exportUserData` |
| Right to deletion | Account deletion removes all user data (UM-06) |
| Data minimization | Only collect name, email, phone (mandatory); avatar (optional) |
| Consent | Privacy policy shown at registration |
| Data portability | CSV/PDF export of expense data (AN-05) |
| No third-party tracking | Firebase Analytics only (first-party, SP-05) |

## Firestore Security Rules Audit

Verify every collection has rules:

| Collection | Read | Write | Delete |
|------------|------|-------|--------|
| `users/{uid}` | Owner only | Owner only | Cloud Functions only |
| `groups/{gid}` | Members only | Members (create), Admin (update) | Cloud Functions only |
| `groups/{gid}/members` | Members only | Cloud Functions only | Cloud Functions only |
| `groups/{gid}/expenses` | Members only | Members (create/update) | Soft-delete only |
| `groups/{gid}/settlements` | Members only | Members (create) | Soft-delete only |
| `groups/{gid}/balances` | Members only | Cloud Functions only | Cloud Functions only |
| `groups/{gid}/activity` | Members only | Cloud Functions only | Never |
| `invites/{code}` | Authenticated users | Cloud Functions only | Cloud Functions only |

## Running Security Checks

```bash
# Dart analysis (includes security-related lints)
flutter analyze

# Check for hardcoded secrets
grep -rn "password\|secret\|api_key\|apiKey\|private_key" lib/ functions/

# Check Firebase config not committed
git ls-files | grep -E "google-services\.json|GoogleService-Info\.plist"

# Test Firestore rules
cd functions && npm test -- --grep "security"
```

## Reference

- Security architecture: `docs/architecture/08_SECURITY.md`
- Firestore rules: `docs/architecture/05_API_DESIGN.md` (Section 4)
- Requirements: `docs/REQUIREMENTS.md` (Section 5.3)
