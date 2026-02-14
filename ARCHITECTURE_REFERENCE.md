# OneByTwo - Architecture Reference Card

Quick reference for the Clean Architecture implementation in OneByTwo.

## 📁 Project Structure

```
lib/
├── core/               # Shared infrastructure (all layers)
│   ├── config/        # Environment configuration
│   ├── constants/     # App constants
│   ├── error/         # Exception & Result types
│   ├── l10n/          # Localization (ARB files)
│   ├── router/        # GoRouter configuration
│   ├── theme/         # Theme, colors, typography
│   ├── utils/         # Utilities & extensions
│   └── widgets/       # Reusable widgets
│
├── domain/            # Business logic (PURE DART)
│   ├── entities/      # Business objects (immutable)
│   ├── repositories/  # Repository interfaces
│   ├── usecases/      # Use cases (business rules)
│   └── value_objects/ # Value objects (Amount, etc.)
│
├── data/              # Data sources & persistence
│   ├── local/dao/     # sqflite operations
│   ├── remote/firestore/ # Firestore operations
│   ├── models/        # DTOs with JSON serialization
│   ├── mappers/       # Entity ↔ Model conversion
│   ├── repositories/  # Repository implementations
│   └── sync/          # Offline-first sync engine
│
└── presentation/      # UI & state management
    ├── providers/     # Riverpod providers
    └── features/      # Feature modules
        ├── auth/      # Authentication
        ├── home/      # Dashboard
        ├── groups/    # Group management
        ├── expenses/  # Expense tracking
        ├── settlements/ # Settlements
        └── profile/   # User profile
```

## 🔑 Key Components

### Result Type
```dart
// Repository returns Result<T>
Future<Result<User>> getUser(String id);

// Handle with pattern matching
switch (result) {
  case Success(:final data):
    // Use data
  case Failure(:final exception):
    // Handle error
}
```

### Exception Hierarchy
```dart
AppException (base)
├── NetworkException      // Network errors
├── DatabaseException     // Local DB errors
├── FirestoreException    // Firestore errors
├── AuthException         // Auth errors
├── ValidationException   // Business validation
├── CacheException        // Cache/storage errors
└── UnknownException      // Unexpected errors
```

### Riverpod Providers
```dart
// Use @riverpod for code generation
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  FutureOr<State> build() { /* initial state */ }
  
  Future<void> doSomething() async { /* logic */ }
}

// In widget
final state = ref.watch(myNotifierProvider);
```

### Money Handling
```dart
// Always use paise (int)
const amount = 10050; // ₹100.50

// Use Amount value object
final price = Amount.fromRupees(100.50);
final paise = price.inPaise; // 10050
```

## 🛠 Common Commands

```bash
# Dependencies
flutter pub get

# Analysis
flutter analyze

# Tests
flutter test

# Format
dart format lib/ test/

# Code Generation (when fixed)
dart run build_runner build --delete-conflicting-outputs

# Run app
flutter run --dart-define=ENV=dev

# Build release
flutter build apk --release --dart-define=ENV=prod
```

## 📊 Conventions

### Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables: `camelCase`
- Constants: `camelCase` or `SCREAMING_SNAKE_CASE`
- Private: `_prefixWithUnderscore`

### Imports
```dart
// Relative imports for lib/
import '../domain/entities/user.dart';

// Package imports for external
import 'package:flutter/material.dart';

// Order: dart, flutter, packages, relative
```

### Code Style
- Always use `const` where possible
- Add trailing commas for better formatting
- Use named parameters for 3+ params
- Prefer immutable classes with `@immutable`
- Use `@freezed` for data classes

### State Management
- Use `@riverpod` (not manual providers)
- Use `ConsumerWidget` over `Consumer`
- `ref.watch()` in build method
- `ref.read()` in callbacks/methods

## 🔄 Offline-First Pattern

### Write Operations
1. Save to local sqflite
2. Update local balances
3. Enqueue to sync queue
4. Return success immediately
5. Sync to Firestore async

### Read Operations
1. Return Stream from local DB
2. Firestore listeners → local DB
3. Local changes → Stream updates

## 📝 Creating a Feature

1. Domain entity (`domain/entities/`)
2. Repository interface (`domain/repositories/`)
3. Use cases (`domain/usecases/`)
4. Data model with freezed (`data/models/`)
5. Mapper (`data/mappers/`)
6. Local DAO (`data/local/dao/`)
7. Firestore source (`data/remote/firestore/`)
8. Repository impl (`data/repositories/`)
9. Riverpod providers (`presentation/providers/`)
10. UI screens/widgets (`presentation/features/`)

## 🐛 Troubleshooting

**Build runner fails?**  
→ Analyzer version incompatibility. Manually create `.g.dart` files.

**Import errors?**  
→ Use relative imports for `lib/`, package imports for external.

**Firebase not initialized?**  
→ Complete S1-02 Firebase setup task first.

## 📚 References

- Architecture: `docs/architecture/README.md`
- Database: `docs/architecture/02_DATABASE_SCHEMA.md`
- Quick Start: `QUICKSTART.md`
- Riverpod: https://riverpod.dev/
- Flutter: https://flutter.dev/docs

---

**Version:** 1.0.0  
**Last Updated:** Task S1-03  
**Status:** Architecture scaffolding complete ✓
