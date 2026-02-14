# OneByTwo - Quick Start Guide

Welcome to the OneByTwo expense-splitting app! This guide will help you get started with the codebase.

## Prerequisites

- Flutter SDK 3.10.7 or higher
- Dart SDK (comes with Flutter)
- Android Studio / VS Code with Flutter extension
- Git

## Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd OneByTwo
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Verify installation**
   ```bash
   flutter analyze
   flutter test
   ```

## Project Structure

```
lib/
├── core/           # Shared infrastructure
├── domain/         # Business logic (pure Dart)
├── data/           # Data sources & repositories
├── presentation/   # UI & state management
└── main.dart       # App entry point
```

See [docs/architecture/README.md](./docs/architecture/README.md) for detailed architecture.

## Development Workflow

### 1. Creating a New Feature

Follow this order when creating a new feature (e.g., "Expense"):

1. **Domain Entity** (`domain/entities/expense.dart`)
   ```dart
   @freezed
   class Expense with _$Expense {
     const factory Expense({
       required String id,
       required int amount,  // in paise
       // ... other fields
     }) = _Expense;
   }
   ```

2. **Repository Interface** (`domain/repositories/expense_repository.dart`)
   ```dart
   abstract class ExpenseRepository {
     Future<Result<List<Expense>>> getExpenses();
     Future<Result<void>> addExpense(Expense expense);
   }
   ```

3. **Use Case** (`domain/usecases/expense/add_expense.dart`)
   ```dart
   class AddExpense {
     final ExpenseRepository repository;
     
     Future<Result<void>> call(Expense expense) async {
       return repository.addExpense(expense);
     }
   }
   ```

4. **Data Model** (`data/models/expense_model.dart`)
   ```dart
   @freezed
   class ExpenseModel with _$ExpenseModel {
     const factory ExpenseModel({
       required String id,
       required int amount,
       // ... matches entity
     }) = _ExpenseModel;
     
     factory ExpenseModel.fromJson(Map<String, dynamic> json) =>
         _$ExpenseModelFromJson(json);
   }
   ```

5. **Mapper** (`data/mappers/expense_mapper.dart`)
   ```dart
   extension ExpenseMapper on ExpenseModel {
     Expense toEntity() => Expense(/*...*/);
   }
   
   extension ExpenseEntityMapper on Expense {
     ExpenseModel toModel() => ExpenseModel(/*...*/);
   }
   ```

6. **DAO** (`data/local/dao/expense_dao.dart`)
   ```dart
   class ExpenseDao {
     Future<void> insert(ExpenseModel expense) async {
       // sqflite insert
     }
     
     Stream<List<ExpenseModel>> watchAll() {
       // Return stream from local DB
     }
   }
   ```

7. **Firestore Source** (`data/remote/firestore/expense_firestore_source.dart`)
   ```dart
   class ExpenseFirestoreSource {
     Future<void> create(ExpenseModel expense) async {
       // Firestore write
     }
     
     Stream<List<ExpenseModel>> watch() {
       // Firestore listener
     }
   }
   ```

8. **Repository Implementation** (`data/repositories/expense_repository_impl.dart`)
   ```dart
   class ExpenseRepositoryImpl implements ExpenseRepository {
     final ExpenseDao dao;
     final ExpenseFirestoreSource firestore;
     
     @override
     Future<Result<void>> addExpense(Expense expense) async {
       try {
         // 1. Save locally
         await dao.insert(expense.toModel());
         // 2. Queue for sync
         await syncQueue.enqueue(expense);
         // 3. Return success immediately
         return const Success(null);
       } catch (e, stack) {
         return Failure(DatabaseException.insertFailed(e, stack));
       }
     }
   }
   ```

9. **Riverpod Providers** (`presentation/providers/expense_providers.dart`)
   ```dart
   @riverpod
   ExpenseRepository expenseRepository(ExpenseRepositoryRef ref) {
     return ExpenseRepositoryImpl(
       dao: ref.watch(expenseDaoProvider),
       firestore: ref.watch(expenseFirestoreProvider),
     );
   }
   
   @riverpod
   class ExpenseList extends _$ExpenseList {
     @override
     Future<List<Expense>> build() async {
       final repo = ref.watch(expenseRepositoryProvider);
       // Load expenses
     }
   }
   ```

10. **UI Screen** (`presentation/features/expense/screens/expense_list_screen.dart`)
    ```dart
    class ExpenseListScreen extends ConsumerWidget {
      @override
      Widget build(BuildContext context, WidgetRef ref) {
        final expensesAsync = ref.watch(expenseListProvider);
        
        return expensesAsync.when(
          data: (expenses) => ListView(...),
          loading: () => CircularProgressIndicator(),
          error: (err, stack) => ErrorWidget(err),
        );
      }
    }
    ```

### 2. Code Generation

After creating models with `@freezed` or providers with `@riverpod`:

```bash
# Generate code
dart run build_runner build --delete-conflicting-outputs

# Watch for changes (development)
dart run build_runner watch --delete-conflicting-outputs
```

**Note**: Due to current analyzer version incompatibility, build_runner may fail. You can manually create generated files as a temporary workaround.

### 3. Running the App

```bash
# Run on connected device
flutter run

# Run with flavor
flutter run --dart-define=ENV=dev

# Build release
flutter build apk --release --dart-define=ENV=prod
```

## Key Conventions

### Money Handling
- **Always use paise (integer)**: ₹100.50 = 10050 paise
- Never use floating-point for money
- Use the `Amount` value object

### Error Handling
- Use `Result<T>` in repositories
- Use `AsyncValue<T>` in providers
- Catch and wrap all exceptions

### State Management
- Use `@riverpod` code generation (not manual providers)
- Prefer `ConsumerWidget` over `Consumer`
- Use `ref.watch()` in build, `ref.read()` in callbacks

### Code Style
- Always run `flutter analyze` before committing
- Use `const` constructors wherever possible
- Add trailing commas for better formatting
- Use relative imports within `lib/`

## Common Commands

```bash
# Install dependencies
flutter pub get

# Clean build artifacts
flutter clean

# Run tests
flutter test

# Run specific test
flutter test test/domain/entities/expense_test.dart

# Check for outdated packages
flutter pub outdated

# Format code
dart format lib/ test/

# Analyze code
flutter analyze

# Generate code
dart run build_runner build

# Remove generated files
dart run build_runner clean
```

## Troubleshooting

### Build Runner Fails
**Issue**: analyzer version incompatibility  
**Solution**: Manually create the `.g.dart` file or wait for package updates

### Firebase Not Initialized
**Issue**: Firebase methods fail  
**Solution**: Ensure Firebase is initialized in main.dart (task S1-02)

### Import Errors
**Issue**: "Target of URI doesn't exist"  
**Solution**: Use relative imports for files in lib/, package imports for external packages

## Resources

- [Architecture Overview](./docs/architecture/README.md)
- [Database Schema](./docs/architecture/02_DATABASE_SCHEMA.md)
- [Implementation Plan](./docs/architecture/09_IMPLEMENTATION_PLAN.md)
- [Riverpod Documentation](https://riverpod.dev/)
- [Flutter Documentation](https://flutter.dev/docs)

## Getting Help

1. Check the architecture documentation in `docs/architecture/`
2. Review existing implementations for patterns
3. Run `flutter doctor` to check your setup
4. Check the implementation plan for task breakdown

---

**Happy Coding! 🚀**
