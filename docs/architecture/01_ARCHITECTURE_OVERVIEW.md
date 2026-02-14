# One By Two — System Architecture Overview

> **Version:** 1.0  
> **Last Updated:** 2026-02-14  
> **Status:** Draft

---

## 1. Architecture Philosophy

One By Two follows an **offline-first, event-driven** architecture. The system is designed around these principles:

1. **Offline-First**: Local database is the primary data source. Cloud sync is secondary.
2. **Single Source of Truth**: Local sqflite DB drives all UI; Firestore is the sync/backup layer.
3. **Event-Driven Reactivity**: All state flows unidirectionally from data sources → repositories → state → UI.
4. **Separation of Concerns**: Clean Architecture layers — Presentation, Domain, Data.
5. **Firebase-Native**: Leverage Firebase managed services to minimize custom infrastructure.

---

## 2. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLIENT (Flutter App)                            │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │  Presentation │  │    Domain    │  │     Data     │  │   Core     │  │
│  │    Layer      │  │    Layer     │  │    Layer     │  │  Services  │  │
│  │              │  │              │  │              │  │            │  │
│  │ • Screens    │  │ • Entities   │  │ • Repos      │  │ • DI       │  │
│  │ • Widgets    │──│ • Use Cases  │──│ • Data Srcs  │  │ • Logging  │  │
│  │ • State Mgmt │  │ • Repo Iface │  │ • Models     │  │ • Config   │  │
│  │   (Riverpod) │  │              │  │ • Mappers    │  │ • Router   │  │
│  └──────────────┘  └──────────────┘  └──────┬───────┘  └────────────┘  │
│                                             │                           │
│                          ┌──────────────────┼──────────────────┐        │
│                          │                  │                  │        │
│                   ┌──────▼──────┐    ┌──────▼──────┐   ┌──────▼──────┐ │
│                   │   sqflite   │    │  Firestore  │   │   Cloud     │ │
│                   │  (Local DB) │    │  SDK Cache  │   │  Storage    │ │
│                   │  PRIMARY    │    │  + Listeners│   │  (Receipts) │ │
│                   └──────┬──────┘    └──────┬──────┘   └──────┬──────┘ │
│                          │                  │                  │        │
└──────────────────────────┼──────────────────┼──────────────────┼────────┘
                           │                  │                  │
                     ══════╪══════════════════╪══════════════════╪═══════
                     NETWORK BOUNDARY         │                  │
                     ══════╪══════════════════╪══════════════════╪═══════
                           │                  │                  │
┌──────────────────────────┼──────────────────┼──────────────────┼────────┐
│                    FIREBASE BACKEND          │                  │        │
│                          │                  │                  │        │
│  ┌───────────────────────▼──────────────────▼──────────────────▼─────┐  │
│  │                     Firebase Services                             │  │
│  │                                                                   │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │  │
│  │  │  Firebase    │  │   Cloud     │  │   Cloud     │              │  │
│  │  │  Auth        │  │  Firestore  │  │  Storage    │              │  │
│  │  │  (OTP)       │  │  (Database) │  │  (Files)    │              │  │
│  │  └─────────────┘  └──────┬──────┘  └─────────────┘              │  │
│  │                          │                                        │  │
│  │  ┌─────────────┐  ┌─────▼───────┐  ┌─────────────┐              │  │
│  │  │   FCM        │  │   Cloud     │  │  Remote     │              │  │
│  │  │  (Push)      │  │  Functions  │  │  Config     │              │  │
│  │  │              │  │ (Triggers & │  │  (Flags)    │              │  │
│  │  └─────────────┘  │  Callable)  │  └─────────────┘              │  │
│  │                    └─────────────┘                                │  │
│  │  ┌─────────────┐  ┌─────────────┐                                │  │
│  │  │ Crashlytics │  │  Analytics  │                                │  │
│  │  │             │  │ (1st party) │                                │  │
│  │  └─────────────┘  └─────────────┘                                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Architecture Decisions Record (ADR)

### ADR-01: State Management — Riverpod

**Decision:** Use Riverpod (v2+) for state management.

**Rationale:**
- Compile-time safety with code generation
- Built-in dependency injection (no separate DI framework needed)
- Excellent testability — providers can be easily overridden in tests
- Supports async state natively (AsyncValue)
- No BuildContext dependency for accessing state
- Active community, well-maintained, production-ready

### ADR-02: Local Database — sqflite + shared_preferences

**Decision:** Use sqflite as the primary local database, shared_preferences for app settings.

**Rationale:**
- sqflite provides full SQL query capability essential for complex joins (expenses + splits + members)
- Relational model maps naturally to the expense data structure
- Better indexing for search and filter operations across 10,000+ expenses
- Well-tested, stable package with broad Flutter support
- shared_preferences for simple key-value settings (theme, language, etc.)

### ADR-03: Flutter Architecture — Clean Architecture

**Decision:** Follow Clean Architecture with 3 layers: Presentation, Domain, Data.

**Rationale:**
- Clear separation of concerns enables parallel development
- Domain layer has zero framework dependencies → highly testable
- Repository pattern abstracts data sources (local vs remote)
- Use cases encapsulate business logic independently of UI

### ADR-04: Cloud Functions Runtime — TypeScript (Node.js)

**Decision:** Use TypeScript on Node.js for all Cloud Functions.

**Rationale:**
- First-class Firebase SDK support
- Best documentation and community examples
- Type safety with TypeScript reduces runtime errors
- Shared type definitions possible between functions
- Fastest cold start among Cloud Functions runtimes

### ADR-05: Firestore Region — asia-south1 (Mumbai)

**Decision:** Deploy all Firebase services in asia-south1 (Mumbai).

**Rationale:**
- Lowest latency for Indian user base (target market)
- Data residency within India
- Compliance with potential data localization requirements

### ADR-06: Navigation — GoRouter

**Decision:** Use GoRouter for declarative, type-safe routing.

**Rationale:**
- Deep link support (needed for group invite links)
- Type-safe route parameters
- Declarative routing pattern aligns with Riverpod
- Redirect guards for auth state
- Official Flutter team recommendation

### ADR-07: Minimum Platform Versions — iOS 17+ / Android 15+

**Decision:** Target iOS 17.0+ and Android 15 (API 35+).

**Rationale:**
- User requirement — targets latest OS versions
- Enables use of latest platform APIs and Flutter features
- Reduces backward-compatibility burden
- Aligns with modern device capabilities (biometrics, notifications)

---

## 4. Cross-Cutting Concerns

### 4.1 Error Handling Strategy

```
┌──────────────────────────────────────────────┐
│              Error Hierarchy                  │
│                                              │
│  AppException (base)                         │
│  ├── NetworkException                        │
│  │   ├── NoInternetException                 │
│  │   └── TimeoutException                    │
│  ├── AuthException                           │
│  │   ├── OtpExpiredException                 │
│  │   ├── SessionExpiredException             │
│  │   └── UnauthorizedException               │
│  ├── DataException                           │
│  │   ├── NotFoundException                   │
│  │   ├── ConflictException                   │
│  │   └── ValidationException                 │
│  ├── StorageException                        │
│  │   ├── LocalDbException                    │
│  │   └── FileUploadException                 │
│  └── SyncException                           │
│      ├── SyncConflictException               │
│      └── SyncTimeoutException                │
└──────────────────────────────────────────────┘
```

- All errors wrapped in typed `Result<T>` (Success/Failure) at the repository layer
- Use cases return `AsyncValue<T>` via Riverpod
- UI displays contextual error messages with retry actions
- Crashlytics captures unhandled exceptions automatically

### 4.2 Logging

- Use `logger` package with structured log levels (verbose, debug, info, warning, error)
- Log all sync operations, API calls, and state transitions in debug mode
- Production: only warning + error level → Crashlytics
- Never log PII (phone numbers, emails) even in debug

### 4.3 Dependency Injection

- Riverpod providers serve as the DI container
- All dependencies registered as providers (repositories, data sources, use cases)
- Environment-specific overrides via ProviderScope (test vs prod)

### 4.4 Internationalization (i18n)

- Flutter `intl` package with ARB files
- Supported locales: `en` (English), `hi` (Hindi)
- All user-facing strings externalized
- Currency always ₹ (Indian Rupee) — no locale-dependent formatting

---

## 5. Deployment Architecture

```
┌─────────────────────────────────────┐
│        CI/CD Pipeline               │
│                                     │
│  GitHub Actions                     │
│  ├── Lint & Analyze                 │
│  ├── Unit Tests                     │
│  ├── Widget Tests                   │
│  ├── Integration Tests              │
│  │   (Firebase Emulator Suite)      │
│  ├── Build APK / IPA                │
│  ├── Deploy Cloud Functions         │
│  ├── Deploy Firestore Rules         │
│  └── Publish to Stores              │
│      ├── Google Play (Internal →    │
│      │   Closed Beta → Production)  │
│      └── TestFlight → App Store     │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│        Environments                 │
│                                     │
│  ┌──────────┐  ┌──────────┐        │
│  │   Dev    │  │ Staging  │        │
│  │ Firebase │  │ Firebase │        │
│  │ Project  │  │ Project  │        │
│  └──────────┘  └──────────┘        │
│  ┌──────────┐                       │
│  │   Prod   │                       │
│  │ Firebase │                       │
│  │ Project  │                       │
│  └──────────┘                       │
└─────────────────────────────────────┘
```

- **3 Firebase projects**: dev, staging, production
- **Flavor/scheme-based builds**: dev, staging, prod via Flutter flavors
- **Feature flags**: Firebase Remote Config for gradual rollouts
- **Crash monitoring**: Crashlytics in all environments
- **Security rules**: Deployed via CI, tested with Firebase Emulator Suite

---

## 6. Technology Stack Summary

| Component | Technology | Version/Notes |
|-----------|-----------|---------------|
| **Language** | Dart | Latest stable |
| **Framework** | Flutter | Latest stable |
| **State Management** | Riverpod | v2+ with code generation |
| **Navigation** | GoRouter | Declarative, deep-link support |
| **Local DB** | sqflite | SQL-based, offline-first primary store |
| **Settings Store** | shared_preferences | Key-value for app config |
| **Cloud DB** | Cloud Firestore | asia-south1, real-time sync |
| **Auth** | Firebase Auth | Phone/OTP only |
| **Cloud Functions** | TypeScript / Node.js | v2 (2nd gen) |
| **File Storage** | Cloud Storage for Firebase | Receipts, avatars, covers |
| **Push Notifications** | FCM | Via Cloud Functions triggers |
| **Analytics** | Firebase Analytics | First-party only |
| **Crash Reporting** | Firebase Crashlytics | All environments |
| **Feature Flags** | Firebase Remote Config | Gradual rollouts |
| **CI/CD** | GitHub Actions | Lint, test, build, deploy |
| **Min iOS** | 17.0 | — |
| **Min Android** | 15 (API 35) | — |
