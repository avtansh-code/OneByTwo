# One By Two — Copilot Repository Instructions

> **Automatically included in every GitHub Copilot interaction for this repository.**

---

## 1. Project Overview

| Field | Value |
|-------|-------|
| **App Name** | One By Two (1/2) |
| **Purpose** | Expense splitting app for the Indian market |
| **Platform** | Flutter (Dart) — single codebase for Android + iOS |
| **Backend** | Firebase (Cloud Firestore, Auth, Cloud Functions, Cloud Storage, FCM, Analytics, Crashlytics) |
| **Region** | `asia-south1` (Mumbai) for all Firebase services |
| **Currency** | Indian Rupees (₹) only — no multi-currency support |
| **Offline-First** | Firestore SDK's built-in cache is the sole local persistence layer (no SQLite, no Hive) |
| **Minimum Targets** | Android 15+ (API 35+), iOS 17+ |

---

## 2. Architecture

### Clean Architecture — 3 Layers

```text
┌─────────────────────────────────────────────────────┐
│  Presentation Layer  (lib/presentation/)            │
│  Screens · Widgets · Riverpod Providers (@riverpod) │
├─────────────────────────────────────────────────────┤
│  Domain Layer  (lib/domain/)                        │
│  Entities (freezed) · Repository Interfaces ·       │
│  Use Cases · Value Objects                          │
│  ⚠ PURE DART ONLY — zero Flutter/Firebase imports   │
├─────────────────────────────────────────────────────┤
│  Data Layer  (lib/data/)                            │
│  Models (json_serializable DTOs) · Mappers ·        │
│  Firestore Data Sources · Cloud Functions Client ·  │
│  Repository Implementations                         │
│  Imports domain layer only.                         │
├─────────────────────────────────────────────────────┤
│  Core  (lib/core/)                                  │
│  Constants · Errors (AppException, Result<T>) ·     │
│  Extensions · Router (GoRouter) · Theme · Logging · │
│  Shared Widgets · l10n                              │
└─────────────────────────────────────────────────────┘
```

**Import rules:**

- **Domain** → imports nothing outside itself (pure Dart).
- **Data** → imports domain only.
- **Presentation** → imports domain and data.
- **Core** → importable by all layers.

### Key Technology Choices

| Concern | Choice |
|---------|--------|
| State Management | Riverpod 2.x with code generation (`@riverpod` annotation) |
| Navigation | GoRouter with type-safe routes, auth redirect, deep links |
| Code Generation | `freezed` (entities), `json_serializable` (DTOs), `riverpod_generator` (providers) |
| Dependency Injection | Riverpod providers serve as DI — no GetIt, no service locator |

---

## 3. Feature-First Project Structure

### Flutter App (`lib/`)

```text
lib/
├── main.dart
├── app.dart                          # MaterialApp + GoRouter
├── bootstrap.dart                    # DI, Firebase init
├── core/
│   ├── constants/                    # app_constants, firestore_paths, category_constants
│   ├── errors/                       # app_exception.dart, failure.dart, result.dart
│   ├── extensions/                   # date_extensions, num_extensions (paise↔rupees), string_extensions
│   ├── network/                      # connectivity_service.dart
│   ├── logging/                      # app_logger.dart, log_entry.dart, outputs/
│   ├── router/                       # app_router.dart, route_names.dart
│   ├── theme/                        # app_theme.dart, app_colors.dart, app_typography.dart
│   ├── utils/                        # amount_utils, debt_simplifier, id_generator, validators
│   ├── widgets/                      # amount_display, avatar_widget, empty_state, error_widget
│   └── l10n/                         # app_en.arb, app_hi.arb
├── data/
│   ├── remote/firestore/             # *_firestore_source.dart (8+ sources)
│   ├── remote/cloud_functions/       # functions_client.dart
│   ├── remote/storage/               # file_storage_source.dart
│   ├── remote/auth/                  # firebase_auth_source.dart
│   ├── models/                       # *_model.dart (DTOs with json_serializable)
│   ├── mappers/                      # *_mapper.dart (entity ↔ model)
│   └── repositories/                 # *_repository_impl.dart
├── domain/
│   ├── entities/                     # User, Group, Expense, Balance, Settlement, FriendPair, etc.
│   ├── repositories/                 # Abstract repository interfaces
│   ├── usecases/                     # Business logic orchestration
│   └── value_objects/                # Amount, PhoneNumber, etc.
└── presentation/
    ├── providers/                    # Riverpod state providers
    └── features/                     # auth/, home/, groups/, expenses/, friends/, settlements/, etc.
```

### Cloud Functions (`functions/`)

```text
functions/
├── src/
│   ├── triggers/                     # Firestore trigger functions
│   ├── callable/                     # HTTPS callable functions
│   ├── scheduled/                    # Scheduled functions
│   ├── utils/                        # Shared utilities
│   └── index.ts                      # Export all functions
├── test/                             # Function tests
├── package.json
└── tsconfig.json
```

---

## 4. Critical Rules (MUST FOLLOW)

### 4.1 Money Handling 💰

> **This is the single most important domain rule. Violating it creates real financial bugs.**

- **ALL amounts are stored as integers in paise** (1 ₹ = 100 paise). Example: ₹100.50 → `10050`.
- **NEVER use `double` for money calculations.** Always `int`.
- **Indian number formatting:** `1,00,000` (not `100,000`). Use `AmountFormatter`.
- **Rupee symbol:** Always prefix displayed amounts with `₹`.
- **Split algorithms** must guarantee: `sum(splits) == totalAmount` (exact, no rounding loss).
- Use the **Largest Remainder Method** for distributing remainders when a split is not evenly divisible.

```dart
// ✅ CORRECT
final int totalPaise = 10050; // ₹100.50

// ❌ WRONG — never do this
final double total = 100.50;
```

### 4.2 Offline-First 📡

- **All writes go through Firestore SDK** (which handles offline queuing automatically).
- **Use `WriteBatch` for atomic multi-document writes** (e.g., expense + payers + splits).
- **Use `snapshots()` streams for reads** (not one-shot `get()`) — enables real-time updates + offline cache.
- **Generate UUIDs on device** for new document IDs (offline-safe, never rely on server-generated IDs).
- **Show sync status** on all user-created content:
  - `✓` synced
  - `↑` pending
  - `⚠` conflict
- **Use `metadata.hasPendingWrites`** from Firestore snapshots for sync indicators.

### 4.3 Soft Deletes 🗑️

- **Never hard-delete documents.** Set `isDeleted: true` + `deletedAt` + `deletedBy`.
- **30-second undo window** after delete (show `SnackBar` with "Undo" action).
- **Filter every query:** Always include `.where('isDeleted', isEqualTo: false)`.

### 4.4 Version Fields (Optimistic Concurrency) 🔒

- Every mutable document has a `version: int` field.
- Increment `version` on every update.
- Cloud Functions check `version` before applying changes.

### 4.5 Error Handling ⚠️

- Repositories return `Result<T>` — a sealed class with `Success<T>` and `Failure` variants.
- Use cases expose results via Riverpod's `AsyncValue<T>`.
- UI **always** handles loading, data, and error states via `.when()`.
- User-facing error messages come from localization (never raw exception text).

```dart
// Repository
Future<Result<Expense>> getExpense(String id);

// Provider (via @riverpod)
// UI
ref.watch(expenseProvider(id)).when(
  data: (expense) => ExpenseCard(expense),
  loading: () => const LoadingSpinner(),
  error: (err, stack) => ErrorWidget(message: context.l10n.genericError),
);
```

### 4.6 Entities & Models 🧱

| Concern | Location | Annotation | Rules |
|---------|----------|------------|-------|
| **Entity** | `domain/entities/` | `@freezed` | Immutable, pure Dart only, no `toJson`/`fromJson` |
| **Model (DTO)** | `data/models/` | `@JsonSerializable()` | Handles Firestore serialization |
| **Mapper** | `data/mappers/` | Plain class | Converts entity ↔ model. Never place conversion logic on entities. |

### 4.7 Providers (Riverpod) 🔌

- Use the `@riverpod` annotation (code generation), **not** manual `Provider()`.
- `StreamProvider` for Firestore listeners (real-time data).
- `FutureProvider` for one-shot operations.
- `AsyncNotifierProvider` for stateful mutations (add/edit/delete).

```dart
@riverpod
Stream<List<Expense>> groupExpenses(GroupExpensesRef ref, String groupId) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchGroupExpenses(groupId);
}
```

### 4.8 Localization 🌐

- **English** (`app_en.arb`) is the source of truth.
- **Hindi** (`app_hi.arb`) must have matching keys.
- Use **ICU message format** for plurals and selects.
- Run `flutter gen-l10n` after editing ARB files.
- Access via `AppLocalizations.of(context)` or `context.l10n` extension.

---

## 5. Firestore Collection Hierarchy

```text
firestore-root/
├── users/{userId}                    # User profile
│   ├── notifications/{notificationId}
│   └── drafts/{draftId}
├── groups/{groupId}                  # Group metadata
│   ├── members/{userId}              # Group membership
│   ├── expenses/{expenseId}          # Group expenses
│   │   ├── splits/{splitId}          # Per-person split
│   │   ├── payers/{payerId}          # Who paid
│   │   └── items/{itemId}            # Itemized items
│   ├── settlements/{settlementId}
│   ├── balances/{balancePairId}      # Pairwise balances (Cloud Functions managed)
│   └── activity/{activityId}
├── friends/{friendPairId}            # Canonical ID: min(a,b)_max(a,b)
│   ├── expenses/{expenseId}
│   ├── settlements/{settlementId}
│   ├── balance/{balanceDocId}        # Single scalar (Cloud Functions managed)
│   └── activity/{activityId}
├── invites/{inviteCode}
├── userGroups/{userId}/groups/{groupId}
└── userFriends/{userId}/friends/{friendUserId}
```

### Key Conventions

- **Friend pair IDs** are canonical: `min(userId_a, userId_b)_max(userId_a, userId_b)`.
- **Balance documents** are written exclusively by Cloud Functions (never by the client).
- **Activity documents** are append-only audit logs.
- All collections used in queries **must** have composite indexes defined in `firestore.indexes.json`.

---

## 6. Testing Conventions

| Aspect | Convention |
|--------|-----------|
| **File location** | `test/` mirrors `lib/` structure |
| **Naming** | `{file_name}_test.dart` |
| **Pattern** | AAA — Arrange → Act → Assert |
| **Test names** | Descriptive: `'should distribute remainder to first participant when amount is not evenly divisible'` |
| **Mocking** | `mocktail` for repository mocks |

### Coverage Targets

| Layer | Target |
|-------|--------|
| Domain (entities, value objects) | 95% |
| Use cases | 90% |
| Repositories / Data sources | 80% |
| Widgets | 70% |
| Cloud Functions | 85% |
| Firestore security rules | 100% |

### Money Invariants (mandatory in every split test)

```dart
// Every split test MUST assert both:
expect(splits.fold<int>(0, (sum, s) => sum + s.amountPaise), equals(totalPaise));
expect(splits.every((s) => s.amountPaise is int), isTrue);
```

### Commands

```bash
flutter test                              # Run all tests
flutter test --coverage                   # With coverage report
flutter test test/specific_test.dart      # Single file
```

---

## 7. Key Dependencies

### Flutter (pubspec.yaml)

```yaml
# State management
flutter_riverpod: ^2.x
riverpod_annotation: ^2.x

# Code generation (dev_dependencies)
build_runner:
freezed:
freezed_annotation: ^2.x
json_annotation: ^4.x
json_serializable:
riverpod_generator:

# Firebase
firebase_core: ^3.x
cloud_firestore: ^5.x
firebase_auth: ^5.x
firebase_storage: ^3.x
firebase_messaging: ^15.x
firebase_analytics: ^11.x
firebase_crashlytics: ^4.x

# Navigation
go_router: ^14.x

# UI / l10n
flutter_localizations: (sdk)
intl: ^0.19.x

# Utilities
uuid: ^4.x
connectivity_plus: ^6.x
```

### Cloud Functions (package.json)

- TypeScript with `firebase-functions` v2
- Node.js 20+
- Deployed to `asia-south1`

---

## 8. Commit Convention

### Format

```text
type(scope): subject
```

### Types

`feat` · `fix` · `refactor` · `test` · `docs` · `perf` · `ci` · `build` · `chore`

### Scopes

`auth` · `groups` · `expenses` · `friends` · `settlements` · `balances` · `notifications` · `analytics` · `search` · `core` · `theme` · `l10n` · `firebase` · `ci`

### Rules

- **Subject:** imperative mood, lowercase, no period, ≤ 72 characters.
- **Co-authored-by:** Include the Copilot trailer on all AI-generated commits:

```text
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

### Examples

```text
feat(expenses): add largest remainder split algorithm
fix(balances): use int paise instead of double for balance calc
test(settlements): add debt simplification edge-case tests
docs(core): update copilot repository instructions
```

---

## 9. Git Workflow (PR-Only)

**All code changes MUST go through Pull Requests. Direct pushes to `main` and `develop` are prohibited.**

- **Branch from:** `develop` (features, fixes, tests, docs) or `main` (hotfixes only)
- **Branch naming:** `{type}/{sprint}-{task}-{description}` (e.g., `feature/S3-01-expense-domain`)
- **PR target:** `develop` (features) or `main` (hotfixes + releases)
- **Merge strategy:** Squash merge (PR title becomes commit message)
- **Required checks:** All 7 CI jobs must pass + 1 approval
- **After merge:** Delete source branch

```bash
# Standard workflow
git checkout develop && git pull
git checkout -b feature/S3-01-expense-domain
# ... work and commit ...
git push -u origin feature/S3-01-expense-domain
gh pr create --title "feat(expenses): add domain layer" --base develop
# Wait for CI + review, then merge via GitHub
```

Never use `git push origin main` or `git push origin develop` directly.

---

## Quick Reference — Do's and Don'ts

| ✅ Do | ❌ Don't |
|-------|---------|
| Store money as `int` paise | Use `double` for money |
| Use `@freezed` for entities | Put `toJson`/`fromJson` on entities |
| Use `@riverpod` codegen | Write manual `Provider()` |
| Use `snapshots()` streams | Use one-shot `get()` for UI reads |
| Soft-delete with `isDeleted` flag | Hard-delete documents |
| Generate IDs client-side (UUID) | Rely on Firestore auto-IDs for offline |
| Return `Result<T>` from repos | Throw exceptions from repos |
| Format amounts as ₹1,00,000 | Format amounts as ₹100,000 |
| Include `version` field on docs | Skip optimistic concurrency |
| Filter `isDeleted == false` | Forget soft-delete filter in queries |
