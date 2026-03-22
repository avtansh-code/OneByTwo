# OneByTwo Architecture

This document provides a quick reference for the Clean Architecture implementation in the OneByTwo app.

## Architecture Overview

The app follows **Clean Architecture** with three distinct layers:

### 1. Domain Layer (`lib/domain/`)
Pure Dart code with no Flutter or Firebase dependencies.

- **`entities/`** - Core business objects (immutable with freezed)
- **`repositories/`** - Abstract repository interfaces
- **`usecases/`** - Business logic use cases
- **`value_objects/`** - Value objects (e.g., Amount, PhoneNumber)

### 2. Data Layer (`lib/data/`)
Handles data persistence and external services.

- **`remote/firestore/`** - Firestore data sources (reads, writes, real-time listeners)
- **`models/`** - Data transfer objects (DTO) with JSON serialization
- **`mappers/`** - Convert between entities ↔ models
- **`repositories/`** - Repository implementations (delegates to Firestore data sources)

### 3. Presentation Layer (`lib/presentation/`)
UI and state management.

- **`providers/`** - Riverpod providers (state management)
- **`features/`** - Feature-based UI organization
  - `auth/` - Authentication screens
  - `home/` - Home dashboard
  - `groups/` - Group management
  - `expenses/` - Expense tracking
  - `settlements/` - Settlement flows
  - `profile/` - User profile

### Core (`lib/core/`)
Shared infrastructure across all layers.

- **`config/`** - App configuration, environment settings
- **`constants/`** - App-wide constants
- **`error/`** - Exception classes and Result type
- **`router/`** - GoRouter navigation configuration
- **`theme/`** - Theme, colors, typography
- **`utils/`** - Utility functions, extensions
- **`widgets/`** - Reusable UI components

## Key Patterns

### Result Type
All repository methods return `Result<T>`:

```dart
Future<Result<User>> getUser(String id) async {
  try {
    final user = await firestoreDataSource.getUser(id);
    return Success(user);
  } catch (e, stack) {
    return Failure(DatabaseException.queryFailed(e, stack));
  }
}
```

### Riverpod Providers
Use `@riverpod` code generation:

```dart
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  Future<User?> build() async {
    // Load initial state
    return null;
  }
  
  Future<void> updateUser(User user) async {
    // Update logic
  }
}
```

### Firestore-Backed with Offline Persistence
Every write operation:
1. Save to Firestore (cached locally by SDK when offline)
2. Return success immediately
3. SDK syncs to cloud automatically when connectivity is restored

Every read operation:
1. Return Stream from Firestore (reads from cache when offline)
2. Firestore snapshot listeners push real-time updates to UI

## Dependencies

- **State Management**: Riverpod v2+ with code generation
- **Navigation**: GoRouter with type-safe routes
- **Database**: Cloud Firestore (with offline persistence)
- **Cloud**: Firebase (Auth, Firestore, Analytics, Crashlytics)
- **Code Generation**: freezed, json_serializable, riverpod_generator

## Conventions

- ✅ Use `freezed` for immutable models and entities
- ✅ Use `@riverpod` annotations (not manual Provider creation)
- ✅ Wrap errors in `Result<T>` at repository layer
- ✅ Use `AsyncValue<T>` for provider state
- ✅ All strings externalized in ARB files
- ✅ Prefer `const` constructors wherever possible
- ✅ Use named parameters for functions with > 2 parameters
- ✅ Follow Dart analysis rules with zero warnings

## Money Handling

- All amounts in **paise** (integer): ₹100.50 = 10050 paise
- Use the `Amount` value object for all monetary operations
- Split calculations use integer arithmetic
- Sum of splits MUST always equal expense total

## Dual Context (Group + Friend)

Expenses and settlements support:
- **Group context**: `context_type = 'group'`, `group_id` non-null
- **Friend context**: `context_type = 'friend'`, `friend_pair_id` non-null

Both contexts support all split types: equal, exact, percentage, shares, and itemized.

## References

- [01_ARCHITECTURE_OVERVIEW.md](./01_ARCHITECTURE_OVERVIEW.md) - Detailed architecture
- [02_DATABASE_SCHEMA.md](./02_DATABASE_SCHEMA.md) - Database schema
- [03_CLASS_DIAGRAMS.md](./03_CLASS_DIAGRAMS.md) - Class diagrams
- [10_ALGORITHMS.md](./10_ALGORITHMS.md) - Split algorithms

---

**Status**: Architecture scaffolding complete ✓  
**Last Updated**: Task S1-03
