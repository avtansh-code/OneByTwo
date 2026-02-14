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

### 4.2 Logging & Debugging

Logging is a **first-class architectural concern**. The app uses a centralized, multi-output logging system that writes to the debug console AND persistent local log files with automatic rotation.

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOGGING ARCHITECTURE                          │
│                                                                  │
│  Application Code (all layers)                                  │
│       │                                                          │
│       ▼                                                          │
│  ┌──────────────────────┐                                       │
│  │   AppLogger          │  Singleton, initialized at bootstrap   │
│  │   (core/logging/)    │                                       │
│  └──────────┬───────────┘                                       │
│             │                                                    │
│     ┌───────┼──────────┬──────────────────┐                     │
│     ▼       ▼          ▼                  ▼                     │
│  ┌──────┐ ┌────────┐ ┌─────────────┐ ┌────────────┐           │
│  │Debug │ │ File   │ │ Crashlytics │ │ In-Memory  │           │
│  │Print │ │ Writer │ │ Reporter    │ │ Ring Buffer│           │
│  │Output│ │        │ │ (prod only) │ │ (UI viewer)│           │
│  └──────┘ └───┬────┘ └─────────────┘ └────────────┘           │
│               │                                                  │
│               ▼                                                  │
│  ┌──────────────────────────────────────────────────────┐       │
│  │  Log File Rotation                                    │       │
│  │  • Max file size: 5 MB per file                      │       │
│  │  • Max files: 3 (current + 2 rotated)                │       │
│  │  • Max total: 15 MB on disk                          │       │
│  │  • Location: app documents dir / logs/               │       │
│  │  • Format: JSON lines (structured, parseable)        │       │
│  │  • Naming: app.log, app.1.log, app.2.log             │       │
│  │  • Rotation trigger: on write when size > 5 MB       │       │
│  │  • Old logs auto-deleted on rotation                 │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Log Levels

| Level     | When to Use                                              | Destinations                 | Example                                             |
| --------- | -------------------------------------------------------- | ---------------------------- | --------------------------------------------------- |
| `verbose` | Ultra-detailed tracing (SQL queries, provider rebuilds)  | Console only (dev)           | `SQL: SELECT * FROM expenses WHERE group_id = 'g1'` |
| `debug`   | Developer-useful context (state changes, cache hits)     | Console + File               | `SyncEngine: processing queue item expense:e123`    |
| `info`    | Key business events (user actions, milestones)           | Console + File               | `Expense created: id=e123 group=g1 amount=5000`     |
| `warning` | Recoverable issues (retry, fallback, degraded)           | Console + File + Crashlytics | `SyncQueue: retry 3/5 for expense:e123`             |
| `error`   | Failures requiring attention (unhandled, data loss risk) | Console + File + Crashlytics | `BalanceRecalc failed: group=g1 error=timeout`      |
| `fatal`   | Unrecoverable crash (app cannot continue)                | Console + File + Crashlytics | `Database corruption detected: onebytwo.db`         |

#### Level Configuration by Environment

| Environment    | Min Console Level | Min File Level | Crashlytics   |
| -------------- | ----------------- | -------------- | ------------- |
| **Dev**        | `verbose`         | `debug`        | Off           |
| **Staging**    | `debug`           | `debug`        | On (warning+) |
| **Production** | None (disabled)   | `info`         | On (warning+) |

#### Structured Log Format (File Output)

```json
{
  "ts": "2026-02-14T15:30:00.123Z",
  "level": "info",
  "tag": "SyncEngine",
  "message": "Queue item processed successfully",
  "data": {
    "entityType": "expense",
    "entityId": "e123",
    "operation": "create",
    "durationMs": 245
  }
}
```

#### PII Protection

- **NEVER log:** Phone numbers, email addresses, OTP codes, auth tokens, user names
- **Safe to log:** Entity IDs, group IDs, amounts, categories, timestamps, error codes
- **PII Sanitizer:** All log messages pass through a sanitizer that redacts patterns matching phone numbers (`\d{10}`), emails (`*@*.*`), and tokens (`eyJ*`)

#### What Gets Logged (by Layer)

| Layer                        | Events Logged                                                                                                                                                                           |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Data / Sync**              | Sync queue operations (enqueue, process, retry, fail, conflict), Firestore listener lifecycle (start, data, error, dispose), sqflite query timing (if > 100ms), receipt upload progress |
| **Data / Repository**        | Repository method calls with entity IDs, offline-first flow (local save, sync enqueue), errors with context                                                                             |
| **Domain / Use Cases**       | Business operation start/end with duration, validation failures, split calculation inputs/outputs                                                                                       |
| **Presentation / Providers** | State transitions (loading → data → error), user actions (navigate, tap, submit)                                                                                                        |
| **Core / Network**           | Connectivity changes (online/offline), Cloud Function calls with latency                                                                                                                |
| **Core / Auth**              | Login/logout events (no credentials), token refresh, session expiry                                                                                                                     |
| **Core / Bootstrap**         | Init step durations, total cold start time, migration execution                                                                                                                         |

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

| Component              | Technology                 | Version/Notes                                                   |
| ---------------------- | -------------------------- | --------------------------------------------------------------- |
| **Language**           | Dart                       | Latest stable                                                   |
| **Framework**          | Flutter                    | Latest stable                                                   |
| **State Management**   | Riverpod                   | v2+ with code generation                                        |
| **Navigation**         | GoRouter                   | Declarative, deep-link support                                  |
| **Local DB**           | sqflite                    | SQL-based, offline-first primary store                          |
| **Settings Store**     | shared_preferences         | Key-value for app config                                        |
| **Cloud DB**           | Cloud Firestore            | asia-south1, real-time sync                                     |
| **Auth**               | Firebase Auth              | Phone/OTP only                                                  |
| **Cloud Functions**    | TypeScript / Node.js       | v2 (2nd gen)                                                    |
| **File Storage**       | Cloud Storage for Firebase | Receipts, avatars, covers                                       |
| **Push Notifications** | FCM                        | Via Cloud Functions triggers                                    |
| **Analytics**          | Firebase Analytics         | First-party only                                                |
| **Crash Reporting**    | Firebase Crashlytics       | All environments                                                |
| **Logging**            | Custom AppLogger           | Multi-output: console + file + Crashlytics, size-based rotation |
| **Feature Flags**      | Firebase Remote Config     | Gradual rollouts                                                |
| **CI/CD**              | GitHub Actions             | Lint, test, build, deploy                                       |
| **Min iOS**            | 17.0                       | —                                                               |
| **Min Android**        | 15 (API 35)                | —                                                               |
