---
applyTo: "lib/**/*.dart"
---

# Dart Production Code Instructions

## Architecture Rules

This project uses Clean Architecture with 3 layers:

- **`lib/domain/`** — Pure Dart only. NO imports from `package:flutter`, `package:cloud_firestore`, `package:firebase_*`, or any file in `lib/data/` or `lib/presentation/`. Contains entities (@freezed), repository interfaces (abstract classes), use cases, and value objects.
- **`lib/data/`** — Can import from `lib/domain/` only. Contains models (@JsonSerializable DTOs), mappers, Firestore data sources, and repository implementations. NEVER import from `lib/presentation/`.
- **`lib/presentation/`** — Can import from both `lib/domain/` and `lib/data/`. Contains Riverpod providers (@riverpod), screens, widgets.
- **`lib/core/`** — Shared utilities (can be imported by any layer). Contains constants, errors, extensions, router, theme, logging, widgets, l10n.

## Code Generation

- **Entities:** Use `@freezed` annotation. File must include `part '{filename}.freezed.dart';`
- **Models:** Use `@JsonSerializable()` annotation. File must include `part '{filename}.g.dart';`
- **Providers:** Use `@riverpod` annotation. File must include `part '{filename}.g.dart';`
- After creating/modifying generated files, run: `dart run build_runner build --delete-conflicting-outputs`

## Money Handling (CRITICAL)

- ALL amounts are `int` representing paise (1 ₹ = 100 paise). ₹100.50 = 10050.
- NEVER use `double` for money, amounts, balances, or any financial calculation.
- Use `~/` (integer division) not `/` (double division) for splitting.
- Always distribute remainder using Largest Remainder Method.
- Use `AmountFormatter` for display formatting. Indian number format: 1,00,000.

## Error Handling

- Repository methods return `Result<T>` (sealed class with `Success<T>` and `Failure` variants).
- Use `try/catch` in repository implementations, wrapping exceptions in `AppException` subclasses.
- Presentation layer uses Riverpod's `AsyncValue<T>` — always handle `.when(data:, loading:, error:)`.
- Never show raw exception text to users. Use localized error messages.

## Offline-First

- All Firestore writes use `WriteBatch` for multi-document atomicity.
- All Firestore reads use `snapshots()` streams (not one-shot `get()`).
- Generate UUID v4 on device for new document IDs (offline-safe).
- Show sync status via `metadata.hasPendingWrites`.

## Soft Deletes

- Never call `.delete()` on Firestore documents.
- Set `isDeleted: true`, `deletedAt: ServerTimestamp`, `deletedBy: userId`.
- Show 30-second undo SnackBar after delete.
- All queries must filter: `where('isDeleted', isEqualTo: false)`.

## Localization

- All user-facing strings must come from ARB files via `AppLocalizations.of(context)` or `context.l10n`.
- Never hardcode English strings in widgets.

## Documentation

- Every public class, method, and field must have a `///` dartdoc comment.
- Comment *why*, not *what* for complex logic.

## Style

- Use `const` constructors wherever possible.
- Use `final` for all local variables.
- Prefer single quotes for strings.
- Import order: dart:, package:, relative (each group alphabetized).
