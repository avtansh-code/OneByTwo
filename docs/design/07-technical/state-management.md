# State Management — Riverpod 2.x Provider Design

| Field | Value |
|---|---|
| ADR | ADR-0004 (Riverpod 2.x), ADR-0013 (DI via Riverpod), ADR-0014 (Offline persistence) |
| SRS sections | 5.7 (Maintainability), 7.1 (High-Level Architecture), 7.3 (Key Architectural Decisions), 13.1 (Project Structure) |
| Status | Draft |

---

## 1. Provider Scope Rules

Every provider belongs to exactly one of three scopes. Scope determines lifetime,
disposal behaviour, and where the provider is declared.

| Scope | Lifetime | Disposal | Examples |
|---|---|---|---|
| **App-scoped** | Created at app start; lives until the process terminates. | Never disposed. | Auth state, current user document, Remote Config values, theme preference. |
| **Feature-scoped** | Created when the feature's tab or route tree is first accessed. | Kept alive while the parent navigation branch is mounted; auto-disposed when the branch is removed from the widget tree. | Feature-specific repositories, real-time Firestore stream listeners for lists. |
| **Screen-scoped** | Created when a screen or bottom sheet is pushed. | Auto-disposed (`@riverpod`, which defaults to `keepAlive: false`) when the screen is popped or the sheet is dismissed. | Form state notifiers (phone entry, add expense, OTP verification). |

**Rationale:** Matching provider lifetime to navigation lifetime prevents stale
state from leaking between screens and avoids unnecessary Firestore listener
costs (SRS section 5.7 — maintainability; NFR-PE-03 — battery and data
efficiency).

---

## 2. Provider Tree

All providers use Riverpod code generation (`riverpod_generator`, package
`riverpod_annotation`) unless a manual declaration is necessary for legacy
interoperability. This aligns with the ADR-0004 recommendation to use code-gen
for reduced boilerplate (SRS section 5.7).

Naming convention summary (detailed in section 3):

- `StreamProvider` — real-time Firestore listeners.
- `FutureProvider` — one-shot reads.
- `Notifier` / `AsyncNotifier` (code-gen `@riverpod`) — mutable state.
- `Provider` — pure synchronous dependencies (repositories, services, formatters).
- `.family` — parameterised variants.

### 2.1 Core / App-level

These providers are declared in `lib/app/` or `lib/core/` and are app-scoped
(`keepAlive: true`).

| Provider | Type | Source | Notes |
|---|---|---|---|
| `authStateProvider` | `StreamProvider<User?>` | `FirebaseAuth.instance.authStateChanges()` | Drives the auth gate; all downstream providers that need a `userId` depend on this. |
| `currentUserProvider` | `StreamProvider<UserModel>` | Real-time listener on `users/{userId}` doc. | Rebuilds whenever the user document changes (display name, photo, notification prefs). Depends on `authStateProvider` for the `userId`. |
| `firebaseFirestoreProvider` | `Provider<FirebaseFirestore>` | `FirebaseFirestore.instance` | Injected into all repositories; enables emulator override in tests (ADR-0003, ADR-0013). |
| `firebaseAuthProvider` | `Provider<FirebaseAuth>` | `FirebaseAuth.instance` | Same DI rationale. |
| `firebaseStorageProvider` | `Provider<FirebaseStorage>` | `FirebaseStorage.instance` | Used by receipt and avatar upload repositories. |
| `remoteConfigProvider` | `FutureProvider<RemoteConfig>` | `FirebaseRemoteConfig.instance` with `fetchAndActivate()`. | Exposes feature flags and the support email address (ADR-0006). Fetched once at app start; value cached for the session. |
| `themeProvider` | `NotifierProvider<ThemeNotifier, ThemeMode>` | Local preference (shared preferences or equivalent). | Exposes `ThemeMode.light`, `ThemeMode.dark`, or `ThemeMode.system`. App-scoped; persists across sessions. |
| `connectivityProvider` | `StreamProvider<ConnectivityStatus>` | Platform connectivity stream. | Exposes online/offline status for the offline banner (FR-OF-01). |

### 2.2 Auth Feature

File location: `lib/features/auth/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `authRepositoryProvider` | `Provider<AuthRepository>` | Feature | Wraps `FirebaseAuth` sign-in, OTP send/verify, sign-out, account deletion trigger. Depends on `firebaseAuthProvider`. |
| `phoneEntryControllerProvider` | `@riverpod AsyncNotifier` | Screen | Manages phone number input validation (`+91` prefix locked, 10-digit regex — ADR-0016), submission state, and error feedback. Auto-disposes when the phone entry screen is popped. |
| `otpEntryControllerProvider` | `@riverpod AsyncNotifier` | Screen | Manages the 6-digit OTP field, auto-read (Android SMS Retriever), retry cooldown timer (30 s, max 3 per 10 min — FR-AU-05), and verification state. Auto-disposes on navigation away. |
| `profileSetupControllerProvider` | `@riverpod AsyncNotifier` | Screen | Manages display name input and optional photo upload for first-login onboarding (FR-AU-06). Auto-disposes when setup completes. |

### 2.3 Friends Feature

File location: `lib/features/friends/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `friendsRepositoryProvider` | `Provider<FriendsRepository>` | Feature | CRUD operations on `friendships` collection. Depends on `firebaseFirestoreProvider`. |
| `friendsListProvider` | `StreamProvider<List<FriendshipModel>>` | Feature | Real-time listener on friendships where `memberIds` contains the current user. Sorted by `lastActivityAt` descending (index: `memberIds, lastActivityAt desc` — SRS section 7.3). |
| `friendDetailProvider` | `StreamProvider<FriendshipModel>.family(String friendshipId)` | Feature | Single-document real-time listener on `friendships/{friendshipId}`. Parameterised by friendship ID. |
| `friendExpensesProvider` | `StreamProvider<List<ExpenseModel>>.family(String friendshipId)` | Feature | Real-time listener on `friendships/{friendshipId}/expenses` where `deleted != true`, ordered by `date` descending. |
| `friendSettlementsProvider` | `StreamProvider<List<SettlementModel>>.family(String friendshipId)` | Feature | Real-time listener on settlements filtered by friendship context. |
| `addFriendNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Manages contact selection, manual phone entry, existing-user lookup, and invite-via-share-sheet flow (FR-FR-01, FR-FR-02, Invariant 3). Auto-disposes. |

### 2.4 Groups Feature

File location: `lib/features/groups/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `groupsRepositoryProvider` | `Provider<GroupsRepository>` | Feature | CRUD on `groups` collection. Depends on `firebaseFirestoreProvider`. |
| `groupsListProvider` | `StreamProvider<List<GroupModel>>` | Feature | Real-time listener on groups where `memberIds` contains the current user, ordered by `updatedAt` descending. |
| `groupDetailProvider` | `StreamProvider<GroupModel>.family(String groupId)` | Feature | Single-document listener on `groups/{groupId}`. |
| `groupExpensesProvider` | `StreamProvider<List<ExpenseModel>>.family(String groupId)` | Feature | Real-time listener on `groups/{groupId}/expenses` where `deleted != true`, ordered by `date` descending. |
| `groupSettlementsProvider` | `StreamProvider<List<SettlementModel>>.family(String groupId)` | Feature | Settlements filtered by group context. |
| `createGroupNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Form state for group creation (name, type, cover photo — FR-GR-01). Auto-disposes. |
| `inviteMemberNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Manages contact selection, phone entry, and invite-link generation (FR-GR-02, FR-GR-03). Auto-disposes. |
| `groupSettingsNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Member removal (FR-GR-05), leave group (FR-GR-06), delete group (FR-GR-07) — all gated on zero-balance preconditions. Auto-disposes. |

### 2.5 Expenses Feature

File location: `lib/features/expenses/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `expensesRepositoryProvider` | `Provider<ExpensesRepository>` | Feature | Write operations on `friendships/{id}/expenses` and `groups/{id}/expenses`. Validates that `splits` sum to `amountPaise` before write (Invariant 1, FR-EX-04). |
| `addExpenseNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Full form state: amount (integer paise), description, date, category (FR-EX-08), payer, split method and per-member shares (FR-EX-03), receipt attachment (FR-EX-05). Validates split totals client-side. Auto-disposes when the add-expense sheet is dismissed. |
| `editExpenseNotifierProvider` | `@riverpod AsyncNotifier.family(String expenseId)` | Screen | Pre-populated from the existing expense document. Same validation rules as add. Auto-disposes. |
| `expenseCategoryProvider` | `Provider<List<ExpenseCategory>>` | App | Static list of predefined categories with icons (FR-EX-08). Pure data; no Firestore dependency. |

### 2.6 Settlements Feature

File location: `lib/features/settlements/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `settlementsRepositoryProvider` | `Provider<SettlementsRepository>` | Feature | Write operations on `settlements` collection. Validates `fromUserId == currentUser.uid` (SRS section 7.5). |
| `settleUpNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Pre-fills recipient and amount from `simplifiedBalances` (FR-SE-05, Invariant 2 — read-only). Manages date picker, optional note, and submission state. Auto-disposes. |
| `settlementHistoryProvider` | `StreamProvider<List<SettlementModel>>.family(String contextId)` | Feature | Real-time listener on settlements filtered by friendship or group context (FR-SE-08). |
| `reminderNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Sends a payment reminder notification; enforces 24-hour rate limit client-side with server-side validation (FR-SE-09). Auto-disposes. |

### 2.7 Activity Feature

File location: `lib/features/activity/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `activityRepositoryProvider` | `Provider<ActivityRepository>` | Feature | Reads from `activity/{userId}/items`. |
| `activityFeedProvider` | `StreamProvider<List<ActivityItemModel>>` | Feature | Real-time listener on `activity/{userId}/items` ordered by `createdAt` descending (FR-AC-01). Paginated via Firestore cursor. |
| `activityDetailProvider` | `FutureProvider.family(String itemId)` | Screen | One-shot read for a single activity item when navigating from a notification deep link (FR-AC-02, FR-AC-05). |

### 2.8 Profile Feature

File location: `lib/features/profile/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `profileRepositoryProvider` | `Provider<ProfileRepository>` | Feature | Reads/writes on `users/{userId}`. Depends on `firebaseFirestoreProvider` and `firebaseStorageProvider` (for avatar upload). |
| `editProfileNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Manages display name and photo edits (FR-PR-01). Auto-disposes. |
| `changePhoneNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Re-verification flow for phone number update (FR-PR-02). Auto-disposes. |
| `notificationPrefsNotifierProvider` | `@riverpod AsyncNotifier` | Screen | Manages per-category notification preference toggles (FR-PR-03). Auto-disposes. |
| `contactSupportProvider` | `Provider<ContactSupportService>` | Feature | Reads support email from `remoteConfigProvider`; constructs the `mailto:` URI with diagnostic context (ADR-0006, FR-PR-05). |

### 2.9 Home Dashboard

File location: `lib/features/home/` (aggregates data from friends and groups providers)

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `netBalanceProvider` | `Provider<int>` | Feature | Derives the user's overall net simplified balance in paise from `friendsListProvider` and `groupsListProvider` (FR-HD-01). Pure computation; no direct Firestore call. |
| `topBalancesProvider` | `Provider<List<BalanceSummary>>` | Feature | Top 5 friends/groups by absolute simplified balance (FR-HD-02). Derived from the same stream providers. |
| `monthlySpendProvider` | `FutureProvider<MonthlySpendSummary>` | Feature | Aggregates current-month expenses by category for the chart (FR-HD-03). One-shot query with date range filter. |

### 2.10 Search and Filters

File location: `lib/features/search/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `searchNotifierProvider` | `@riverpod Notifier` | Screen | Manages the search query string, active filters (date range, group, category), and debounced result computation (FR-SR-01, FR-SR-02). Operates against the local Firestore cache (FR-OF-01). Auto-disposes. |
| `searchResultsProvider` | `Provider<List<SearchResult>>` | Screen | Derived from `searchNotifierProvider` state; executes the Firestore query with applied filters. |

---

## 3. Naming Conventions

All provider names follow these rules, enforced by lint rules and code review.

| Provider kind | Suffix | When to use | Example |
|---|---|---|---|
| `StreamProvider` | `Provider` | Real-time Firestore listeners that emit continuous updates. | `friendsListProvider` |
| `FutureProvider` | `Provider` | One-shot asynchronous reads (e.g., Remote Config fetch, single document read from a notification deep link). | `remoteConfigProvider` |
| `Notifier` / `AsyncNotifier` | `NotifierProvider` | Mutable state with methods that modify it (form fields, submission actions). Always use `@riverpod` code-gen annotation. | `addExpenseNotifierProvider` |
| `Provider` | `Provider` | Pure synchronous dependencies: repository instances, service wrappers, derived computations with no side effects. | `firebaseFirestoreProvider` |
| `.family` | append `.family(Type param)` | Any provider that requires a runtime parameter (document ID, context ID). | `groupDetailProvider.family(String groupId)` |

**Additional conventions:**

- Provider variable names use `camelCase` ending in `Provider`.
- The generated provider is referenced by its variable name; the annotated class
  uses the same root name in `PascalCase` (e.g., class `AddExpenseNotifier`,
  provider `addExpenseNotifierProvider`).
- Repository providers are named `{feature}RepositoryProvider`.
- No provider should depend on more than one repository directly. If cross-feature
  data is needed, compose at the provider level (e.g., `netBalanceProvider` reads
  from `friendsListProvider` and `groupsListProvider`, not from their repositories).

---

## 4. File Locations

Per SRS section 13.1, providers live within their feature folder. The standard
layout for each feature is:

```
lib/features/{feature}/
  data/
    {feature}_repository.dart        -- Repository class + repositoryProvider
    models/
      {feature}_model.dart           -- Freezed data classes / DTOs
  presentation/
    providers/
      {feature}_providers.dart       -- StreamProviders, FutureProviders for the feature
      {notifier}_notifier.dart       -- One file per screen-scoped notifier
    screens/
      {screen}_screen.dart
    widgets/
      {widget}.dart
```

App-scoped and core providers are located outside the feature tree:

```
lib/
  app/
    providers/
      auth_state_provider.dart
      theme_provider.dart
      remote_config_provider.dart
      connectivity_provider.dart
  core/
    providers/
      firebase_providers.dart        -- firebaseFirestoreProvider, firebaseAuthProvider, etc.
    money/
      money_formatter.dart           -- Paise-to-rupees conversion (Invariant 1)
    errors/
      result.dart                    -- Result<T, E> sealed class (ADR-0009)
```

**Rule:** A feature folder must never import a provider from another feature's
`presentation/providers/` directory. Cross-feature data flows through app-scoped
or core providers only. This enforces module boundaries and prevents circular
dependencies (SRS section 5.7).

---

## 5. Disposal Rules

Riverpod code-gen (`@riverpod`) defaults to auto-dispose. Providers that must
outlive a single screen explicitly set `keepAlive: true`.

| Scope | Disposal strategy | Mechanism |
|---|---|---|
| **App-scoped** | Never disposed. Lives for the process lifetime. | `@Riverpod(keepAlive: true)` or manual `Provider` / `StreamProvider` without auto-dispose. |
| **Feature-scoped** | Kept alive while at least one widget in the feature's navigation branch is listening. Disposed when the last listener is removed (e.g., user navigates to a different primary tab and the framework unmounts the feature subtree). | `@Riverpod(keepAlive: true)` on stream providers within the feature. The framework's ref-counting ensures disposal when no consumer remains. |
| **Screen-scoped** | Auto-disposed when the screen is popped from the navigator or the bottom sheet is dismissed. | Default `@riverpod` annotation (auto-dispose). No explicit `keepAlive`. |

**Firestore listener lifecycle:** Every `StreamProvider` wraps a Firestore
`snapshots()` stream. When the provider is disposed, the stream subscription is
cancelled automatically by Riverpod, which closes the underlying Firestore
listener. This prevents orphaned listeners from consuming bandwidth and battery
(NFR-PE-03).

**Form state on back-navigation:** Screen-scoped notifiers (e.g.,
`addExpenseNotifierProvider`) are disposed when the user navigates away. If the
user returns, the notifier is recreated with default state. This is intentional:
partially-filled forms are not persisted across navigation events. If a future
requirement mandates draft persistence, it should be handled by writing to a
local store, not by extending provider lifetime.

---

## 6. Offline Cache Exposure

Per ADR-0014, Firestore SDK built-in offline persistence is the sole offline
mechanism. No secondary local database (Hive, Isar, SQLite) is introduced.

### 6.1 Read Path (FR-OF-01)

Firestore's `snapshots()` streams — which back every `StreamProvider` in the
provider tree — serve documents from the local cache when the device is offline.
This is the default Firestore behaviour when persistence is enabled
(`settings.persistenceEnabled = true`, set once at app initialisation).

From the provider consumer's perspective, offline reads are transparent:

1. `StreamProvider` emits the cached snapshot with
   `SnapshotMetadata.isFromCache == true`.
2. The UI renders the data identically regardless of source.
3. The `connectivityProvider` drives a non-blocking offline banner at the top of
   list screens ("You are offline. Showing cached data.") so the user understands
   the data may be stale.

No provider logic branches on `isFromCache`. The banner is the sole user-facing
indicator.

### 6.2 Write Path (FR-OF-02)

When the device is offline, Firestore SDK queues writes locally and syncs them
when connectivity returns. From the provider layer:

1. Screen-scoped notifiers (e.g., `addExpenseNotifierProvider`,
   `settleUpNotifierProvider`) call repository write methods as normal.
2. The repository calls `collection.add()` or `doc.set()`, which completes
   immediately against the local cache (the returned `Future` resolves promptly).
3. The notifier treats the write as successful and dismisses the form.
4. An `OBTSnackbar` with type `info` is shown if `connectivityProvider` indicates
   offline status: "You are offline. This expense will sync when you are back
   online."
5. When connectivity returns, the Firestore SDK syncs the queued write to the
   server. The `recomputeSimplifiedBalances` Cloud Function triggers on the
   server-side write event, recomputing balances (Invariant 2, FR-SE-04).

### 6.3 Conflict Resolution (FR-OF-03)

Firestore uses last-write-wins semantics for conflicting offline edits. The
provider layer does not implement custom conflict resolution. The flow is:

1. Two devices edit the same document while offline.
2. Both sync when connectivity returns; the server accepts the last write by
   timestamp.
3. The `recomputeSimplifiedBalances` Cloud Function runs after each sync,
   producing a consistent `simplifiedBalances` result.
4. The losing device's `StreamProvider` emits the server-authoritative snapshot,
   updating the UI.
5. If the local write was overridden, a Cloud Function sends a push notification
   to the affected user (FR-AC-03) informing them that their edit was superseded.
   The `activityFeedProvider` picks up the corresponding activity item.

### 6.4 Cache Size

Firestore SDK default cache size (40 MB on mobile) is retained. For v1.0, this
is sufficient for typical user data volumes. If analytics indicate cache eviction
issues, a future ADR may increase the limit or introduce selective cache
management.

### 6.5 Constraints

- **No client-side balance computation.** Even when offline, the app displays the
  last server-computed `simplifiedBalances`. It does not attempt to derive
  provisional balances from cached expenses. This upholds Invariant 2.
- **No offline-first architecture.** The app is online-first with offline
  tolerance. Features that require server-side logic (group invite acceptance,
  account deletion) are disabled when offline and display an appropriate message.

---

## 7. Dependency Injection via Riverpod (ADR-0013)

Riverpod is the sole dependency injection mechanism. There is no `get_it`,
`injectable`, or service locator pattern.

### 7.1 Repository Injection

Every repository is exposed as a `Provider` that depends on the relevant Firebase
SDK provider:

```
@Riverpod(keepAlive: true)
FriendsRepository friendsRepository(Ref ref) {
  return FriendsRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
}
```

This allows tests to override `firebaseFirestoreProvider` with a fake or emulator
instance without changing repository code.

### 7.2 Testing Overrides

In widget and integration tests, providers are overridden at the
`ProviderScope` level:

```
ProviderScope(
  overrides: [
    firebaseFirestoreProvider.overrideWithValue(fakeFirestore),
    firebaseAuthProvider.overrideWithValue(fakeAuth),
  ],
  child: const MyApp(),
)
```

This is the standard Riverpod testing pattern and eliminates the need for a
separate test DI configuration (ADR-0013).

---

## 8. Traceability Matrix

| SRS Requirement | Provider(s) |
|---|---|
| FR-AU-01 .. FR-AU-09 | `authStateProvider`, `phoneEntryControllerProvider`, `otpEntryControllerProvider`, `profileSetupControllerProvider`, `authRepositoryProvider` |
| FR-PR-01 .. FR-PR-05 | `currentUserProvider`, `editProfileNotifierProvider`, `changePhoneNotifierProvider`, `notificationPrefsNotifierProvider`, `contactSupportProvider` |
| FR-FR-01 .. FR-FR-05 | `friendsListProvider`, `friendDetailProvider`, `friendExpensesProvider`, `friendSettlementsProvider`, `addFriendNotifierProvider` |
| FR-GR-01 .. FR-GR-07 | `groupsListProvider`, `groupDetailProvider`, `groupExpensesProvider`, `groupSettlementsProvider`, `createGroupNotifierProvider`, `inviteMemberNotifierProvider`, `groupSettingsNotifierProvider` |
| FR-EX-01 .. FR-EX-09 | `addExpenseNotifierProvider`, `editExpenseNotifierProvider`, `expenseCategoryProvider`, `expensesRepositoryProvider` |
| FR-SE-01 .. FR-SE-09 | `settleUpNotifierProvider`, `settlementHistoryProvider`, `reminderNotifierProvider`, `settlementsRepositoryProvider` |
| FR-AC-01 .. FR-AC-05 | `activityFeedProvider`, `activityDetailProvider` |
| FR-HD-01 .. FR-HD-04 | `netBalanceProvider`, `topBalancesProvider`, `monthlySpendProvider` |
| FR-SR-01, FR-SR-02 | `searchNotifierProvider`, `searchResultsProvider` |
| FR-OF-01 | All `StreamProvider` instances (Firestore cache), `connectivityProvider` |
| FR-OF-02 | Repository write methods + `connectivityProvider` for snackbar |
| FR-OF-03 | Server-side last-write-wins; `StreamProvider` emits authoritative snapshot |
| Invariant 1 | `expensesRepositoryProvider` (paise validation), `addExpenseNotifierProvider` |
| Invariant 2 | `simplifiedBalances` read-only in all providers; never written by client |
| Invariant 3 | `addFriendNotifierProvider`, `inviteMemberNotifierProvider` (system share sheet only) |
| Invariant 4 | `firebaseFirestoreProvider` et al. point to the single production project; tests override with emulator (ADR-0003) |
