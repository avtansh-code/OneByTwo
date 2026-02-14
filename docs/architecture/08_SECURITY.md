# One By Two — Security Architecture

> **Version:** 1.0  
> **Last Updated:** 2026-02-14

---

## 1. Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY ARCHITECTURE                         │
│                                                                  │
│  Layer 1: Device Security                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ • Biometric / PIN app lock (optional, user-enabled)       │  │
│  │ • Local DB encryption (sqflite_sqlcipher)                 │  │
│  │ • Secure storage for tokens (flutter_secure_storage)      │  │
│  │ • Certificate pinning for Firebase connections            │  │
│  │ • No data in app screenshots (FLAG_SECURE on Android,     │  │
│  │   hidden content on iOS app switcher)                     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Layer 2: Transport Security                                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ • TLS 1.3 for all network communication                   │  │
│  │ • Firebase SDK handles TLS natively                       │  │
│  │ • No HTTP fallback (HTTPS only)                           │  │
│  │ • HSTS for web app                                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Layer 3: Authentication                                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ • Firebase Auth (phone/OTP only)                          │  │
│  │ • Short-lived ID tokens (1 hour, auto-refreshed)          │  │
│  │ • Refresh tokens stored in secure storage                 │  │
│  │ • Session invalidation on account deletion                │  │
│  │ • Rate limiting on OTP requests (5 per 15 min per phone)  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Layer 4: Authorization (Firestore Security Rules)              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ • Document-level access control                           │  │
│  │ • Role-based permissions (owner > admin > member)         │  │
│  │ • Users can only read groups they belong to               │  │
│  │ • Users can only modify their own profile                 │  │
│  │ • Balances & activity logs are read-only (written by CF)  │  │
│  │ • See 05_API_DESIGN.md for full rules                     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Layer 5: Data Validation (Cloud Functions)                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ • Server-side validation on all callable functions        │  │
│  │ • Amount must be positive integer                         │  │
│  │ • Splits must sum to expense amount                       │  │
│  │ • User must be group member to write expenses             │  │
│  │ • Rate limiting on sensitive operations                   │  │
│  │ • Input sanitization (XSS prevention for text fields)     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Layer 6: Privacy                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ • No third-party analytics/tracking SDKs                  │  │
│  │ • Firebase Analytics only (first-party, Google)           │  │
│  │ • No ad networks, no data brokers                         │  │
│  │ • Minimal data collection (only what's needed)            │  │
│  │ • Full account deletion (GDPR Article 17)                 │  │
│  │ • Data export on request (GDPR Article 20)                │  │
│  │ • Privacy policy linked in app                            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Local Database Encryption

```
Implementation: sqflite_sqlcipher (SQLCipher for sqflite)

Key management:
  1. On first app launch:
     - Generate 256-bit AES key
     - Store in flutter_secure_storage
       (iOS: Keychain, Android: EncryptedSharedPreferences / Keystore)
  2. On every DB open:
     - Retrieve key from secure storage
     - Pass to SQLCipher as PRAGMA key

If user enables biometric lock:
  - Key access requires biometric authentication
  - Adds another layer before DB can be decrypted

Threat model:
  - Device stolen while locked → DB encrypted, key in Keychain/Keystore
  - Device stolen while unlocked → biometric lock prevents app access
  - Rooted/jailbroken device → Keystore still provides protection
    (best effort — can't guarantee security on compromised devices)
```

---

## 3. GDPR & Data Privacy Compliance

```
┌─────────────────────────────────────────────────────────────────┐
│              GDPR COMPLIANCE CHECKLIST                            │
│                                                                  │
│  Right to Access (Art. 15):                                     │
│  ✓ Export all user data via exportData Cloud Function            │
│  ✓ Data returned in CSV/PDF format                              │
│                                                                  │
│  Right to Erasure (Art. 17):                                    │
│  ✓ deleteAccount Cloud Function removes:                        │
│    - users/{uid} document                                       │
│    - All userGroups/{uid} documents                              │
│    - User's FCM tokens                                          │
│    - User's notifications                                       │
│    - User's drafts                                              │
│    - Avatar from Cloud Storage                                  │
│    - Firebase Auth account                                      │
│  ✓ In groups: user is anonymized ("Deleted User") not removed   │
│    - Expenses/settlements kept for group integrity              │
│    - User name replaced with "Deleted User"                     │
│                                                                  │
│  Right to Portability (Art. 20):                                │
│  ✓ CSV/PDF export includes all user expenses and settlements    │
│                                                                  │
│  Data Minimization (Art. 5):                                    │
│  ✓ Only collect: name, email, phone, avatar                    │
│  ✓ No location tracking, no device fingerprinting              │
│  ✓ No third-party data sharing                                 │
│                                                                  │
│  Consent:                                                       │
│  ✓ Push notifications: explicit opt-in                         │
│  ✓ Contact access: explicit permission request                 │
│  ✓ Analytics: first-party only, no opt-out needed (legitimate  │
│    interest for app improvement)                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Sensitive Data Handling

| Data | Storage | Encryption | Notes |
|------|---------|------------|-------|
| Phone number | Firestore + local DB | At rest (SQLCipher) + in transit (TLS) | Used for auth only |
| Email | Firestore + local DB | At rest + in transit | Used for account recovery |
| OTP codes | Firebase Auth (server) | Never stored locally | Auto-expire in 5 min |
| Firebase tokens | flutter_secure_storage | Keychain / Keystore | Short-lived, auto-refresh |
| Expense amounts | Firestore + local DB | At rest + in transit | Integer paise |
| Receipt images | Cloud Storage + local | At rest + in transit | Max 10MB, image/* only |
| PIN hash | flutter_secure_storage | Keychain / Keystore | Bcrypt hash, never plain text |

---

## 5. OWASP Mobile Top 10 Coverage

| # | Risk | Mitigation |
|---|------|-----------|
| M1 | Improper credential usage | Firebase Auth manages credentials; tokens in secure storage |
| M2 | Inadequate supply chain security | Dart pub dependencies audited; lockfile committed |
| M3 | Insecure authentication | Phone OTP via Firebase Auth; no custom auth implementation |
| M4 | Insufficient input/output validation | Cloud Functions validate all inputs; Firestore rules enforce schema |
| M5 | Insecure communication | TLS 1.3 everywhere; Firebase SDK handles transport |
| M6 | Inadequate privacy controls | GDPR compliance; minimal data collection; no 3rd-party sharing |
| M7 | Insufficient binary protections | Obfuscation enabled (--obfuscate --split-debug-info); ProGuard on Android |
| M8 | Security misconfiguration | Firebase security rules tested in CI; no debug flags in production |
| M9 | Insecure data storage | SQLCipher encryption; secure storage for secrets |
| M10 | Insufficient cryptography | AES-256 for local DB; TLS 1.3 for transport; no custom crypto |
