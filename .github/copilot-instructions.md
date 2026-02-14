# One By Two — Copilot Instructions

## Project Overview

One By Two is a mobile-first expense-splitting app built with **Flutter (Dart)** frontend and **Firebase** backend, targeting **iOS 17+** and **Android 15+ (API 35+)**. India-only market, all amounts in ₹ (Indian Rupees).

## Architecture

- **Pattern:** Clean Architecture with 3 layers — Presentation, Domain, Data
- **State Management:** Riverpod (v2+ with code generation)
- **Navigation:** GoRouter (declarative, type-safe)
- **Local Database:** sqflite with SQLCipher encryption (UI's source of truth)
- **Cloud Database:** Cloud Firestore (asia-south1, real-time sync)
- **Cloud Functions:** TypeScript / Node.js (2nd gen)
- **Auth:** Firebase Auth (Phone/OTP only)
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **File Storage:** Firebase Cloud Storage (receipts, avatars)

## Key Architecture Rules

1. **Offline-first:** Local sqflite is the source of truth for the UI. All writes go local first, then sync to Firestore via a queue.
2. **Amount storage:** All monetary amounts are stored as **integers in paise** (1 ₹ = 100 paise). Never use floating-point for money. Display conversion: `amount / 100`.
3. **Split calculations:** Use integer arithmetic with Largest Remainder Method for distributing remainders. The sum of splits must always equal the expense total exactly.
4. **Sync status:** Every syncable entity has a `sync_status` field: `synced`, `pending`, or `conflict`.
5. **Soft deletes:** Expenses and settlements use `is_deleted` flag, never hard-delete.
6. **Balance pair keys:** Use canonical ordering `min(userA, userB)_max(userA, userB)` for deterministic balance pair IDs. This applies to both group balance pairs AND friend pair IDs.
7. **Version field:** All mutable entities have an integer `version` field for optimistic concurrency control.
8. **Dual context (group + friend):** Expenses and settlements can belong to either a **group** (`context_type = 'group'`) or a **friend pair** (`context_type = 'friend'`). The `group_id` and `friend_pair_id` fields are mutually exclusive — one must be non-null, the other null. In Firestore, groups use `groups/{groupId}/expenses/` and friends use `friends/{friendPairId}/expenses/`.
9. **1:1 friend balance:** Friend balances are a single scalar (not a matrix). No debt simplification needed for 2 people. The `friends` table has a `balance` column (positive = userA owes userB).

## Project Structure

```
lib/
├── core/          # Shared infrastructure (theme, router, utils, widgets, l10n)
├── data/          # Data layer (local DAOs, Firestore sources, models, mappers, repositories, sync)
├── domain/        # Domain layer (entities, repository interfaces, use cases, value objects) — pure Dart, no framework deps
├── presentation/  # Presentation layer (providers, feature screens & widgets)
functions/
├── src/           # Cloud Functions (callable/, triggers/, scheduled/, services/, models/, utils/)
```

## Coding Conventions

- Use `freezed` + `json_serializable` for immutable data models
- Use Riverpod `@riverpod` annotations with code generation
- Use `Result<T>` pattern (Success/Failure) at repository boundaries
- Use `AsyncValue<T>` for UI state via Riverpod
- All user-facing strings must be externalized in ARB files (English + Hindi)
- All Dart files follow `dart analyze` with zero warnings
- Cloud Functions use strict TypeScript with ESLint

## Logging Conventions

- Use `AppLogger.instance` (singleton) for all logging — never use `print()` or `debugPrint()` directly
- Every class defines `static const _tag = 'Layer.Component'` (e.g., `Repo.Expense`, `Sync.Queue`, `UC.AddExpense`)
- Log levels: `verbose` (SQL traces), `debug` (state changes), `info` (business events), `warning` (recoverable), `error` (failures), `fatal` (unrecoverable)
- Always include entity IDs in log data (`expenseId`, `groupId`, `userId`) for traceability
- Log duration (`durationMs`) for all async operations
- **Never log PII:** phone numbers, emails, user names, OTP codes, auth tokens, or user-entered text
- PII sanitizer auto-strips patterns, but avoid passing PII in the first place
- Logs go to: debug console (dev), local JSON files with 5MB rotation (all envs), Crashlytics (warning+ in prod)
- Cloud Functions use `firebase-functions/v2` logger with structured data

## Testing Conventions

- Unit tests: 80%+ coverage on domain layer
- Widget tests: All core UI components
- Integration tests: Firebase Emulator Suite for Firestore rules and Cloud Functions
- Test file naming: `*_test.dart` for Dart, `*.test.ts` for TypeScript
- Use `flutter_test` for Dart tests, `jest` or `mocha` for Cloud Functions

## Documentation

- Architecture docs are in `docs/architecture/`
- Requirements are in `docs/REQUIREMENTS.md`
- Algorithms reference is in `docs/architecture/10_ALGORITHMS.md`
