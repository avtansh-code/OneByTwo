# State Management — Riverpod 2.x Provider Design

| Field | Value |
|---|---|
| ADR | ADR-0004 (Riverpod 2.x), ADR-0013 (DI via Riverpod), ADR-0014 (Offline persistence) |
| SRS sections | 5.7 (Maintainability), 7.1 (High-Level Architecture), 7.3 (Key Architectural Decisions), 13.1 (Project Structure) |
| Status | Draft |

> **Implementation status (current code).** This document is being
> reconciled with the shipped client. The key facts that govern everything
> below:
>
> - **No Riverpod code generation is used.** There are zero `@riverpod` /
>   `@Riverpod` annotations and zero `*.g.dart` files in `lib/` or `test/`.
>   Every provider is hand-written with the legacy `flutter_riverpod` 2.x
>   API. The `riverpod_annotation` / `riverpod_generator` / `build_runner`
>   packages appear in `pubspec.yaml` but are unused, and
>   `custom_lint` / `riverpod_lint` are **not** wired into
>   `analysis_options.yaml` (which includes only `very_good_analysis`).
> - **Provider types actually in use:** `Provider<T>` (DI / repositories /
>   services), `StreamProvider<T>` and `StreamProvider.family`,
>   `FutureProvider.family` and `FutureProvider.autoDispose.family`,
>   `StateNotifierProvider` (plain, `.autoDispose`, and
>   `.autoDispose.family`), exactly one `NotifierProvider`, `StateProvider`,
>   and `StateProvider.family`.
> - **Controllers extend `StateNotifier<State>`** in every feature except
>   `NotificationPermissionController`, which extends `Notifier<PermissionState>`.
>   There is no `AsyncNotifier` and no `ChangeNotifier` anywhere.
> - **Groups and Search have no client code.** Sections that previously described
>   their providers are retained only as planned scope and are flagged accordingly.
>   (The Home Dashboard **is** built — see section 2.11.)
>
> The provider inventory in section 2 lists the real declarations
> (file path included). Where an idealised name from an earlier draft does
> not exist, it has been removed or corrected.

---

## 1. Provider Scope Rules

Every provider belongs to exactly one of three scopes. Scope determines lifetime,
disposal behaviour, and where the provider is declared.

| Scope | Lifetime | Disposal | Examples |
|---|---|---|---|
| **App-scoped** | Created at app start; lives until the process terminates. | Never disposed. | Auth state stream, current user id, Firebase SDK handles, analytics service. |
| **Feature-scoped** | Created when the feature's tab or route tree is first accessed. | Kept alive while the parent navigation branch is mounted; disposed when no consumer remains. | Feature-specific repositories, real-time Firestore stream listeners for lists. |
| **Screen-scoped** | Created when a screen or bottom sheet is pushed. | Auto-disposed via the `.autoDispose` modifier when the screen is popped or the sheet is dismissed. | Form state notifiers (phone entry, add expense, OTP verification, settle up). |

**Rationale:** Matching provider lifetime to navigation lifetime prevents stale
state from leaking between screens and avoids unnecessary Firestore listener
costs (SRS section 5.7 — maintainability; NFR-PE-03 — battery and data
efficiency).

### 1.1 Scoped Overrides and `dependencies`

`currentUserIdProvider` is a **scoped root**: its declaration throws unless an
ancestor `ProviderScope` overrides it. `main.dart` performs that override once, per
authenticated arm, inside the authenticated shell's `ProviderScope`
(`currentUserIdProvider.overrideWithValue(uid)`). Every authenticated read therefore
sees a concrete uid, and an unauthenticated tree cannot construct these providers at
all.

Any provider whose value derives from a scoped override must declare a `dependencies`
list so Riverpod can rebuild it under the correct scope. The rule — stated identically
in the `feature-pr-conventions` guide (section 2) and the `review-pull-request`
skill — is:

> A provider that `ref.watch`es a **scoped** provider declares the
> **directly-watched** scoped provider in its own `dependencies` list — **not** a
> transitive root reached through it. Declaring the transitive root instead of the
> direct dependency (or omitting the list) makes Riverpod throw the
> *"... specified a `dependencies` list ..."* assertion on first read.

Worked example (the FR-HD / FR-FR trap):

- `friendsListProvider` watches `currentUserIdProvider` directly, so it declares
  `dependencies: [currentUserIdProvider]`.
- `overallNetBalanceProvider`, `topBalancesProvider`, `monthlySpendBreakdownProvider`
  (FR-HD-01/02/03) and `friendCountProvider` (FR-PR-04) watch `friendsListProvider`,
  **not** `currentUserIdProvider` directly, so each declares
  `dependencies: [friendsListProvider]`. Adding the transitive `currentUserIdProvider`
  here is the common mistake.
- A provider that watches the scoped root itself (for example
  `contactSupportControllerProvider`) declares `dependencies: [currentUserIdProvider]`.
- Global, unscoped providers (for example `homeClockProvider`) are never named in any
  `dependencies` list.

---

## 2. Provider Tree

All providers are hand-written with the legacy `flutter_riverpod` 2.x API
(see the implementation-status note above — there is no code generation).
The toolchain favours explicit declarations over `@riverpod` codegen, so each
provider's type and disposal behaviour is visible at its declaration site.

Provider-type summary (detailed in section 3):

- `Provider<T>` — synchronous dependencies: repositories, services, SDK
  handles, the current user id.
- `StreamProvider<T>` / `StreamProvider.family` — real-time Firestore
  listeners.
- `FutureProvider.family` / `FutureProvider.autoDispose.family` — one-shot
  reads.
- `StateNotifierProvider` (plain, `.autoDispose`, `.autoDispose.family`) —
  controllers extending `StateNotifier<State>`. This is the dominant form.
- `NotifierProvider` — used once (`notificationPermissionControllerProvider`).
- `StateProvider` / `StateProvider.family` — small pieces of mutable state
  (pending deep link, reminder cooldown).

### 2.1 Core / app-level

App-scoped handles. Several live under `lib/features/auth/` because they were
first introduced there; they are nonetheless shared by every feature via DI.

| Provider | Type | Source | Notes |
|---|---|---|---|
| `authStateProvider` | `StreamProvider<AuthState>` | `lib/features/auth/application/auth_state_provider.dart` | Drives the auth gate in `main.dart`; downstream providers that need a `userId` depend on the resolved state. |
| `firebaseAuthProvider` | `Provider<FirebaseAuth>` | `lib/features/auth/application/auth_state_provider.dart` | DI seam; emulator override in tests (ADR-0013). |
| `firebaseFirestoreProvider` | `Provider<FirebaseFirestore>` | `lib/core/providers/firebase_providers.dart` | Injected into all repositories; emulator override in tests. |
| `firebaseStorageProvider` | `Provider<FirebaseStorage>` | `lib/core/providers/firebase_providers.dart` | Used by receipt and avatar upload services. |
| `phoneAuthRepositoryProvider` | `Provider<PhoneAuthRepository>` | `lib/core/providers/phone_auth_provider.dart` | App-scoped DI seam wrapping `FirebasePhoneAuthRepository` (OTP send/verify/resend, plus re-auth for change-phone and account deletion). Consumed by auth, profile, and deletion; overridden with a fake in tests. |
| `analyticsServiceProvider` | `Provider<AnalyticsService>` | `lib/features/auth/application/analytics_provider.dart` | Telemetry wrapper injected into controllers. |
| `currentUserIdProvider` | `Provider<String>` | `lib/features/friends/application/friends_list_provider.dart` | Throws unless overridden; `main.dart` overrides it per authenticated gate arm with the signed-in uid. |
| `connectivityCheckProvider` | `Provider<IsOnline>` | `lib/core/connectivity/connectivity_provider.dart` | One-shot reachability check (`typedef IsOnline = Future<bool> Function()`) read at write time. Not a stream. See `offline-and-sync.md`. |
| `imagePickerServiceProvider` | `Provider<ImagePickerService>` | `lib/core/services/image_picker_service.dart` | Gallery/camera picker used by avatar and receipt flows. |

There is no `remoteConfigProvider`, `themeProvider`, or `connectivityProvider`
stream in the codebase today; theming is resolved statically by `AppTheme`
(see `lib/app/README.md`).

### 2.2 Auth Feature

File location: `lib/features/auth/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `userRepositoryProvider` | `Provider<UserRepository>` | Feature | Reads/writes `users/{uid}` and avatar uploads. Depends on `firebaseFirestoreProvider` and `firebaseStorageProvider`. |
| `phoneEntryControllerProvider` | `StateNotifierProvider<PhoneEntryController, PhoneEntryState>` | Feature (not auto-dispose) | Phone-number input validation (`+91` locked, 10-digit rule), submission state, error feedback. Kept alive across the OTP round-trip. |
| `otpEntryControllerProvider` | `StateNotifierProvider.autoDispose.family<OtpEntryController, OtpEntryState, …>` | Screen | 6-digit OTP field, resend cooldown timer, verification state (FR-AU-05). Auto-disposes on navigation away. |
| `profileSetupControllerProvider` | `StateNotifierProvider.autoDispose<ProfileSetupController, ProfileSetupState>` | Screen | Display name and optional photo for first-login onboarding (FR-AU-06). Auto-disposes when setup completes. |

`authStateProvider`, `firebaseAuthProvider`, and `analyticsServiceProvider` also live
in this feature but are app-scoped (listed in 2.1). The Firebase SDK handles
(`firebaseFirestoreProvider`, `firebaseStorageProvider`) and
`phoneAuthRepositoryProvider` were relocated to `lib/core/providers/` and are listed in
2.1; the `PhoneAuthRepository` *class* still lives under `lib/features/auth/data/`.

### 2.3 Friends Feature

File location: `lib/features/friends/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `friendshipRepositoryProvider` | `Provider<FriendshipRepository>` | Feature | Reads on the `friendships` collection. Depends on `firebaseFirestoreProvider`. |
| `matchingRepositoryProvider` | `Provider<MatchingRepository>` | Feature | Wraps the contact-matching callable; overridden in `main.dart`. |
| `contactServiceProvider` | `Provider<ContactService>` | Feature | Device contact-book access (behind permission). |
| `shareServiceProvider` | `Provider<ShareServiceBase>` | Feature | System share sheet wrapper (`share_plus`); Invariant 3 — no app-specific targets. |
| `friendsListProvider` | `StreamProvider<List<FriendListItem>>` | Feature | Real-time listener on friendships containing the current user, projected to list items with net balance from `simplifiedBalances`. |
| `friendDetailProvider` | `StreamProvider.family<FriendDetailState, FriendDetailArgs>` | Feature | Composes the friendship doc and its expenses for one friendship. |
| `userProfileProvider` | `FutureProvider.family<UserModel?, String>` | Screen | One-shot lookup of a counterparty profile by uid. |
| `contactPermissionControllerProvider` | `StateNotifierProvider<ContactPermissionController, ContactPermissionState>` | Feature | Contacts permission priming and status. |
| `contactPickerControllerProvider` | `StateNotifierProvider<ContactPickerController, ContactPickerState>` | Feature | Contact selection / search state. |
| `matchAndInviteControllerProvider` | `StateNotifierProvider<MatchAndInviteController, MatchAndInviteState>` | Feature | Existing-user match vs. invite-via-share-sheet (FR-FR-01/02, Invariant 3). Declared `UnimplementedError` and overridden at the call site. |

### 2.4 Groups Feature (not implemented in client)

File location: `lib/features/groups/` — **no Dart code exists** (see
`lib/features/groups/README.md`). The Firestore `groups` collection schema and
security rules exist server-side, but there are no Riverpod providers, screens,
or repositories for groups in the client today. The Groups tab in the shell
renders a `GroupsListPlaceholder` from `lib/features/shell/`.

The providers below are **planned scope** and do not yet exist:

| Provider (planned) | Type | Notes |
|---|---|---|
| `groupsRepositoryProvider` | `Provider<GroupsRepository>` | CRUD on `groups` collection. |
| `groupsListProvider` | `StreamProvider<List<…>>` | Groups containing the current user. |
| `groupDetailProvider` | `StreamProvider.family` | Single group document. |
| `createGroupControllerProvider` | `StateNotifierProvider.autoDispose` | Group creation form (FR-GR-01). |
| `inviteMemberControllerProvider` | `StateNotifierProvider.autoDispose` | Member invite (FR-GR-02/03). |
| `groupSettingsControllerProvider` | `StateNotifierProvider.autoDispose` | Member removal / leave / delete (FR-GR-05/06/07). |

### 2.5 Expenses Feature

File location: `lib/features/expenses/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `expenseRepositoryProvider` | `Provider<ExpenseRepository>` | Feature | Create/edit/soft-delete on `friendships/{id}/expenses`. Validates that `splits` sum to `amountPaise` before write (Invariant 1). |
| `receiptStorageServiceProvider` | `Provider<ReceiptStorageService>` | Feature | Receipt image upload to Firebase Storage (FR-EX-05). |
| `addExpenseControllerProvider` | `StateNotifierProvider.autoDispose.family<AddExpenseController, AddExpenseState, AddExpenseArgs>` | Screen | Full form state: amount (integer paise), description, date, payer, split method/shares, receipt. **Handles both create and edit** via `AddExpenseArgs.initialExpense` (`isEditMode`) — there is no separate edit provider (FR-EX-01, FR-EX-06). Auto-disposes when the sheet is dismissed. |
| `expenseDetailProvider` | `FutureProvider.autoDispose.family<ExpenseDoc?, ExpenseDetailArgs>` | Screen | One-shot read of a single expense for the detail view. |

### 2.6 Settlements Feature

File location: `lib/features/settlements/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `settlementRepositoryProvider` | `Provider<SettlementRepository>` | Feature | Create + history reads on settlements. Validates `fromUserId == currentUser.uid` server-side (rules). |
| `settleUpControllerProvider` | `StateNotifierProvider.autoDispose.family<SettleUpController, SettleUpState, SettleUpArgs>` | Screen | Pre-fills payer/payee/amount from the net `simplifiedBalances` (FR-SE-05, Invariant 2 — read-only). Manages submission and offline-aware error copy. Auto-disposes. |
| `settlementHistoryProvider` | `StreamProvider.family<List<SettlementDoc>, SettlementHistoryArgs>` | Feature | Real-time listener for a friendship's settlement history, capped at 50 items (FR-SE-08). |

Send Reminder (FR-SE-09) lives in the `reminders` feature (2.10), not here.

### 2.7 Activity Feature

File location: `lib/features/activity/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `activityFeedRepositoryProvider` | `Provider<ActivityFeedRepository>` | Feature | Reads the current user's activity items. |
| `activityFeedProvider` | `StreamProvider<List<ActivityFeedItem>>` | Feature | Real-time listener on the user's activity feed, newest first (FR-AC-01). |

There is no separate `activityDetailProvider`; tapping an item navigates using
the data already in the feed item.

### 2.8 Profile Feature

File location: `lib/features/profile/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `editProfileControllerProvider` | `StateNotifierProvider.autoDispose<EditProfileController, EditProfileState>` | Screen | Display name and photo edits (FR-PR-01); reuses `userRepositoryProvider` and `imagePickerServiceProvider`. Auto-disposes. |
| `changePhoneControllerProvider` | `StateNotifierProvider.autoDispose<ChangePhoneController, ChangePhoneState>` | Screen | Change-phone re-verification (FR-PR-02): a two-OTP state machine — `reauthenticate` the current number, then verify the new one and write `users/{uid}.phoneNumber`. Reuses `phoneAuthRepositoryProvider` / `userRepositoryProvider`. Auto-disposes. |
| `notificationPreferencesControllerProvider` | `StateNotifierProvider.autoDispose<NotificationPreferencesController, NotificationPreferencesState>` | Screen | Per-category notification preference toggles (FR-PR-03); writes to `users/{uid}` and surfaces the one-shot offline snackbar. Auto-disposes. |
| `friendCountProvider` | `Provider<AsyncValue<int>>` | Feature | The "My Friends" stats count (FR-PR-04): a read-only projection of `friendsListProvider` into `items.length`. Declares `dependencies: [friendsListProvider]` (the directly-watched scoped provider, not the transitive `currentUserIdProvider`; see 1.1). Read-only over `simplifiedBalances` (Invariant 2). |
| `contactSupportControllerProvider` | `Provider<ContactSupportController>` | Feature | Contact Support action (FR-PR-05 / FR-SH-03 / FR-SH-04): builds the diagnostic `mailto:` URI from Remote Config, launches the mail client, or returns a fallback result. Declares `dependencies: [currentUserIdProvider]` (it watches that scoped root; see 1.1). |
| `deleteAccountControllerProvider` | `StateNotifierProvider.autoDispose<DeleteAccountController, DeleteAccountState>` | Screen | Account-deletion flow (FR-AU-09; SCR-28 Part B): the five-step state machine (warning → re-authentication → type-`DELETE` confirm → processing → success). Step B reuses `phoneAuthRepositoryProvider`; the final step calls the `deleteUserAccount` Cloud Function (ADR-0016). Auto-disposes. |

Profile reads/writes go through `userRepositoryProvider` (auth feature); there
is no dedicated `profileRepositoryProvider`. Change-phone (FR-PR-02) **is**
implemented via `changePhoneControllerProvider` (a full two-OTP re-verification state
machine). `ProfileScreen` is the live screen; `ProfilePlaceholderScreen` is an unused
stub.

### 2.9 Notifications Feature

File location: `lib/features/notifications/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `firebaseMessagingProvider` | `Provider<FirebaseMessaging>` | App | DI seam over `FirebaseMessaging.instance`. |
| `fcmTokenServiceProvider` | `Provider<FcmTokenService>` | App | Registers/refreshes the FCM token on `users/{uid}` (FR-AC-04). |
| `permissionMessagingAdapterProvider` | `Provider<PermissionMessagingAdapter>` | App | Adapter over messaging permission APIs. |
| `notificationPermissionControllerProvider` | `NotifierProvider<NotificationPermissionController, PermissionState>` | App | The single `Notifier` in the codebase: permission priming and status. |
| `deepLinkHandlerProvider` | `Provider<DeepLinkHandler>` | App | Resolves a notification payload to a navigation target (FR-AC-05). |
| `pendingDeepLinkProvider` | `StateProvider<NotificationPayload?>` | App | Holds a cold-start/foreground deep-link payload until the shell consumes it. |

### 2.10 Reminders Feature

File location: `lib/features/reminders/`

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `reminderRepositoryProvider` | `Provider<ReminderRepository>` | Feature | Calls the Send Reminder backend (FR-SE-09); overridden in `main.dart`. |
| `sendReminderControllerProvider` | `StateNotifierProvider.autoDispose.family<SendReminderController, SendReminderState, String>` | Screen | Drives the Send Reminder CTA on the receiving-direction settle-up card, keyed by `friendshipId`. Auto-disposes. |
| `reminderCooldownProvider` | `StateProvider.family<DateTime?, String>` | Feature | Per-friendship client-side cooldown timestamp; gates repeat reminders. |

There is no `presentation/` folder in `reminders`; its UI surface is the
receiving-direction variant of `OBTSettleUpCard`, hosted by the `friends`
feature.

### 2.11 Home Dashboard Feature

File location: `lib/features/home/`

The dashboard providers are **read-only projections** that compose
`friendsListProvider` (and, for the spend card, the expense repository); none writes
`simplifiedBalances` (Invariant 2), and every monetary fold stays in integer paise
(Invariant 1).

| Provider | Type | Scope | Notes |
|---|---|---|---|
| `overallNetBalanceProvider` | `Provider<AsyncValue<int>>` | Feature | The user's overall net simplified balance in signed integer paise, folded across every friendship (FR-HD-01). Read-side reducer over `friendsListProvider`; declares `dependencies: [friendsListProvider]` (see 1.1). |
| `topBalancesProvider` | `Provider<AsyncValue<List<FriendListItem>>>` | Feature | The top friendships by absolute balance (zero-excluded, absolute-descending, stable tie-break, capped at 5) for the "Top Balances" section (FR-HD-02). Read-side projection over `friendsListProvider`; declares `dependencies: [friendsListProvider]`. |
| `monthlySpendBreakdownProvider` | `FutureProvider<MonthlySpendBreakdown>` | Screen (one-shot) | Current-month spend grouped by category, folded across all friendships over the IST month window (FR-HD-03). Awaits `friendsListProvider`, fans out per-friendship `expenses` reads, then reduces through the pure `aggregateMonthlySpend`. Declares `dependencies: [friendsListProvider]`. |
| `homeClockProvider` | `Provider<DateTime Function()>` | App (global) | Injectable clock for the FR-HD-03 IST month window (production `DateTime.now`; month-boundary tests inject a fixed instant). Global and unscoped, so it is **not** listed in any provider's `dependencies` (see 1.1). |

The group axis of FR-HD-02/03 is a forward-compatibility stub: these providers fold the
friendship axis only, and the Sprint 3 Groups epic slots a second source into the same
sections without changing their contracts.

---

## 3. Naming Conventions

Provider names follow these rules by convention and code review. Note that
`riverpod_lint` is **not** wired into `analysis_options.yaml`, so these are not
machine-enforced today.

| Provider kind | Suffix | When to use | Example |
|---|---|---|---|
| `StreamProvider` | `Provider` | Real-time Firestore listeners that emit continuous updates. | `friendsListProvider` |
| `FutureProvider` | `Provider` | One-shot asynchronous reads (e.g., a single document read). | `userProfileProvider` |
| `StateNotifier` / `Notifier` | `ControllerProvider` | Mutable state with methods that modify it (form fields, submission actions). Hand-written — no `@riverpod` annotation. | `addExpenseControllerProvider` |
| `Provider` | `Provider` | Pure synchronous dependencies: repository instances, service wrappers, SDK handles. | `firebaseFirestoreProvider` |
| `StateProvider` | `Provider` | Small standalone pieces of mutable state. | `pendingDeepLinkProvider` |
| `.family` | append `.family<…>` | Any provider that requires a runtime parameter (document/context id). | `friendDetailProvider` |

**Additional conventions:**

- Provider variable names use `camelCase` ending in `Provider`.
- Mutable-state controllers are named `…Controller` (PascalCase class) with a
  matching `…ControllerProvider` (e.g., class `AddExpenseController`, provider
  `addExpenseControllerProvider`). The earlier `…Notifier` naming is not used.
- Repository providers are named `{feature}RepositoryProvider` (singular
  feature noun, e.g., `expenseRepositoryProvider`, `settlementRepositoryProvider`).
- No provider should depend on more than one repository directly. If
  cross-feature data is needed, compose at the provider level (e.g.,
  `friendDetailProvider` composes the friendship repository and the expense
  repository) rather than reaching into another feature's controllers.

---

## 4. File Locations

Per SRS section 13.1, providers live within their feature folder. The standard
layout for each feature is the four-layer structure used across `lib/features/`:

```
lib/features/{feature}/
  README.md                          -- feature doc (gold standard: friends)
  application/
    {feature}_provider.dart          -- StreamProvider / FutureProvider declarations
    {x}_controller.dart              -- StateNotifier (+ matching state class)
    {x}_state.dart                   -- immutable state for the controller
    {x}_telemetry.dart               -- event / param name constants
  data/
    {feature}_repository.dart        -- repository class + repositoryProvider
    {x}_service.dart                 -- service wrappers (storage, contacts, …)
  domain/
    {x}_doc.dart                     -- value types / DTOs (strict parsing)
  presentation/
    {screen}_screen.dart
    widgets/
      {widget}.dart
```

Notes on reality:

- The folder is `application/` (not `presentation/providers/`). Stream/Future
  providers and controllers both live under `application/`.
- Domain models are plain Dart value types with strict parsing; the project
  does **not** use Freezed for these.
- The `reminders` feature has no `presentation/` folder; its UI is hosted by
  `friends`.

App-scoped DI seams are collected under `lib/core/providers/`; the remaining
core helpers live where they were introduced:

```
lib/
  core/
    providers/firebase_providers.dart         -- firebaseFirestoreProvider, firebaseStorageProvider
    providers/phone_auth_provider.dart         -- phoneAuthRepositoryProvider
    connectivity/connectivity_provider.dart  -- connectivityCheckProvider (Provider<IsOnline>)
    services/image_picker_service.dart        -- imagePickerServiceProvider
    formatters/inr_formatter.dart             -- formatInrFromPaise (Invariant 1)
  features/auth/
    application/auth_state_provider.dart      -- authStateProvider, firebaseAuthProvider
    application/analytics_provider.dart        -- analyticsServiceProvider
    data/phone_auth_repository.dart            -- PhoneAuthRepository class (provider lives in core/providers)
  features/friends/
    application/friends_list_provider.dart     -- currentUserIdProvider (overridden in main.dart)
```

**Rule:** A feature folder must never import another feature's controllers.
Cross-feature data flows through app-scoped providers (e.g., `currentUserIdProvider`,
the Firebase handles) or shared `lib/core/` providers only. This enforces
module boundaries and prevents circular dependencies (SRS section 5.7).

---

## 5. Disposal Rules

Disposal is controlled by the provider's modifier at its declaration site
(no codegen). Screen-scoped controllers use the `.autoDispose` modifier;
app- and feature-scoped providers are plain (kept alive while a consumer
listens).

| Scope | Disposal strategy | Mechanism |
|---|---|---|
| **App-scoped** | Never disposed. Lives for the process lifetime. | Plain `Provider` / `StreamProvider` / `NotifierProvider` without `.autoDispose`. |
| **Feature-scoped** | Kept alive while at least one widget in the feature's navigation branch is listening. Disposed when the last listener is removed (e.g., the user navigates to a different primary tab and the framework unmounts the subtree). | Plain `StreamProvider` / `StreamProvider.family`. Riverpod's ref-counting disposes the provider when no consumer remains. |
| **Screen-scoped** | Auto-disposed when the screen is popped or the bottom sheet is dismissed. | The `.autoDispose` modifier (e.g., `StateNotifierProvider.autoDispose.family`). |

**Firestore listener lifecycle:** Every `StreamProvider` wraps a Firestore
`snapshots()` stream. When the provider is disposed, the stream subscription is
cancelled automatically by Riverpod, which closes the underlying Firestore
listener. This prevents orphaned listeners from consuming bandwidth and battery
(NFR-PE-03).

**Form state on back-navigation:** Screen-scoped controllers (e.g.,
`addExpenseControllerProvider`, `settleUpControllerProvider`) are disposed when
the user navigates away. If the user returns, the controller is recreated with
default state. This is intentional: partially-filled forms are not persisted
across navigation events. If a future requirement mandates draft persistence, it
should be handled by writing to a local store, not by extending provider
lifetime.

---

## 6. Offline Cache Exposure

Per ADR-0014, Firestore SDK built-in offline persistence is the sole offline
mechanism. No secondary local database (Hive, Isar, SQLite) is introduced.

### 6.1 Read Path (FR-OF-01)

Firestore's `snapshots()` streams — which back every `StreamProvider` in the
provider tree — serve documents from the local cache when the device is offline.
This is the default Firestore behaviour because persistence is enabled by
default on iOS and Android; `lib/main.dart` does not set
`Settings.persistenceEnabled` explicitly (see `offline-and-sync.md`).

From the provider consumer's perspective, offline reads are transparent:

1. `StreamProvider` emits the cached snapshot with
   `SnapshotMetadata.isFromCache == true`.
2. The UI renders the data identically regardless of source.

No provider logic branches on `isFromCache`, and there is **no
`connectivityProvider` stream and no persistent offline banner**. The only
connectivity surface is the one-shot `connectivityCheckProvider`, consumed at
write time (§6.2).

### 6.2 Write Path (FR-OF-02)

When the device is offline, the Firestore SDK queues writes locally and syncs
them when connectivity returns. From the provider layer:

1. Screen-scoped controllers (e.g., `addExpenseControllerProvider`,
   `settleUpControllerProvider`) call repository write methods as normal.
2. The repository calls `collection.add()` or `doc.set()`, which completes
   immediately against the local cache (the returned `Future` resolves promptly).
3. The controller treats the write as successful and dismisses the form.
4. Where a controller reads `connectivityCheckProvider` and infers an offline
   write, it surfaces a one-shot snackbar (e.g., notification preferences:
   "You are offline. Changes will sync when you reconnect."; Settle Up:
   "You're offline. The settlement will be recorded when you reconnect.").
   Not every write path shows such a message.
5. When connectivity returns, the Firestore SDK syncs the queued write to the
   server. The `recomputeSimplifiedBalances` Cloud Function triggers on the
   server-side write event, recomputing balances (Invariant 2).

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

> **Not implemented:** there is no client-side detection of an overridden write
> and no "your edit was superseded" notification. The push-on-override step
> described in earlier drafts does not ship today (see `offline-and-sync.md`
> §4.2).

### 6.4 Cache Size

The Firestore SDK default cache size is retained; `lib/main.dart` does not set
`cacheSizeBytes`. For v1.0 this is sufficient for typical user data volumes. If
analytics indicate cache eviction issues, a future change may set an explicit
`Settings(cacheSizeBytes: …)` or `CACHE_SIZE_UNLIMITED`.

### 6.5 Constraints

- **No client-side balance computation.** Even when offline, the app displays the
  last server-computed `simplifiedBalances`. It does not attempt to derive
  provisional balances from cached expenses. This upholds Invariant 2.
- **No offline-first architecture.** The app is online-first with offline
  tolerance. Features that require a server round-trip (contact matching, Send
  Reminder) surface an error or queued-write message when offline.

---

## 7. Dependency Injection via Riverpod (ADR-0013)

Riverpod is the sole dependency injection mechanism. There is no `get_it`,
`injectable`, or service locator pattern.

### 7.1 Repository Injection

Every repository is exposed as a hand-written `Provider` that depends on the
relevant Firebase SDK provider (no codegen annotation):

```
final friendshipRepositoryProvider = Provider<FriendshipRepository>((ref) {
  return FriendshipRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});
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
| FR-AU-01 .. FR-AU-09 | `authStateProvider`, `phoneEntryControllerProvider`, `otpEntryControllerProvider`, `profileSetupControllerProvider`, `phoneAuthRepositoryProvider`, `userRepositoryProvider`, `deleteAccountControllerProvider` (FR-AU-09) |
| FR-PR-01 .. FR-PR-05 | `editProfileControllerProvider` (FR-PR-01), `changePhoneControllerProvider` (FR-PR-02), `notificationPreferencesControllerProvider` (FR-PR-03), `friendCountProvider` (FR-PR-04), `contactSupportControllerProvider` (FR-PR-05), `userRepositoryProvider` |
| FR-FR-01 .. FR-FR-05 | `friendsListProvider`, `friendDetailProvider`, `userProfileProvider`, `contactPickerControllerProvider`, `matchAndInviteControllerProvider`, `friendshipRepositoryProvider`, `matchingRepositoryProvider`, `shareServiceProvider` |
| FR-GR-01 .. FR-GR-07 | _Not implemented in client (see 2.4)._ |
| FR-EX-01, FR-EX-05, FR-EX-06 | `addExpenseControllerProvider`, `expenseDetailProvider`, `expenseRepositoryProvider`, `receiptStorageServiceProvider` |
| FR-SE-05, FR-SE-08 | `settleUpControllerProvider`, `settlementHistoryProvider`, `settlementRepositoryProvider` |
| FR-SE-09 | `sendReminderControllerProvider`, `reminderRepositoryProvider`, `reminderCooldownProvider` |
| FR-AC-01, FR-AC-02 | `activityFeedProvider`, `activityFeedRepositoryProvider` |
| FR-AC-03 .. FR-AC-05 | `firebaseMessagingProvider`, `fcmTokenServiceProvider`, `notificationPermissionControllerProvider`, `deepLinkHandlerProvider`, `pendingDeepLinkProvider` |
| FR-HD-01 .. FR-HD-03 | `overallNetBalanceProvider` (FR-HD-01), `topBalancesProvider` (FR-HD-02), `monthlySpendBreakdownProvider` + `homeClockProvider` (FR-HD-03); see 2.11 |
| FR-HD-04 | shell nav (`lib/features/shell/`) |
| FR-SR-01, FR-SR-02 | _Not implemented in client (no search feature)._ |
| FR-OF-01 | All `StreamProvider` instances (Firestore cache) |
| FR-OF-02 | Repository write methods + `connectivityCheckProvider` (one-shot) for the offline snackbar |
| FR-OF-03 | Server-side last-write-wins; `StreamProvider` emits authoritative snapshot |
| Invariant 1 | `expenseRepositoryProvider` (paise validation), `addExpenseControllerProvider` |
| Invariant 2 | `simplifiedBalances` read-only in all providers; never written by client |
| Invariant 3 | `matchAndInviteControllerProvider` via `shareServiceProvider` (system share sheet only) |
| Invariant 4 | `firebaseFirestoreProvider` et al. point to the single project; tests override with emulator (ADR-0003) |
