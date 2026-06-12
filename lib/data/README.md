# data

Reserved for app-wide, cross-feature data infrastructure.

## Current state

This directory is an intentional placeholder — it contains only a
`.gitkeep` and this README; there is **no Dart code here yet**.

In the current codebase every repository, Firestore data-transfer
object, and collection reference is colocated with the feature that owns
it, under `lib/features/<feature>/data/` (for example
`features/friends/data/friendship_repository.dart`,
`features/expenses/data/expense_repository.dart`,
`features/settlements/data/settlement_repository.dart`). The shared
Firebase dependency-injection providers (`firebaseFirestoreProvider`,
`firebaseAuthProvider`, `firebaseStorageProvider`) live in
`features/auth/data/` and `features/auth/application/`.

If a genuinely cross-feature data concern emerges that does not belong to
any single feature, it would live here. Until then, prefer the
feature-first `data/` folders.
