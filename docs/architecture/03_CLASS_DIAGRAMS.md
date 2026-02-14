# One By Two — Class Diagrams & Module Architecture

> **Version:** 1.0  
> **Last Updated:** 2026-02-14

---

## 1. Project Structure (Feature-First)

```
lib/
├── main.dart                         # App entry point
├── app.dart                          # MaterialApp + GoRouter setup
├── bootstrap.dart                    # Initialization (DI, DB, Firebase)
│
├── core/                             # Shared infrastructure
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── firestore_paths.dart
│   │   └── category_constants.dart
│   ├── errors/
│   │   ├── app_exception.dart
│   │   └── failure.dart
│   ├── extensions/
│   │   ├── date_extensions.dart
│   │   ├── num_extensions.dart       # paise ↔ rupees conversion
│   │   └── string_extensions.dart
│   ├── network/
│   │   └── connectivity_service.dart
│   ├── logging/                       # Centralized logging system
│   │   ├── app_logger.dart            # Singleton logger, multi-output dispatch
│   │   ├── log_entry.dart             # Structured log entry model
│   │   ├── log_level.dart             # Log level enum (verbose..fatal)
│   │   ├── log_output.dart            # LogOutput interface
│   │   ├── outputs/
│   │   │   ├── console_output.dart    # Debug console (colored, dev only)
│   │   │   ├── file_output.dart       # JSON lines to disk with rotation
│   │   │   ├── crashlytics_output.dart # Forward warning+ to Crashlytics
│   │   │   └── ring_buffer_output.dart # In-memory buffer for debug viewer
│   │   ├── log_file_rotator.dart      # Size-based rotation (5MB × 3 files)
│   │   ├── pii_sanitizer.dart         # Strip phone/email/tokens from messages
│   │   └── debug_viewer/              # In-app log viewer (dev/staging only)
│   │       ├── debug_log_screen.dart
│   │       └── debug_log_entry_widget.dart
│   ├── router/
│   │   ├── app_router.dart
│   │   └── route_names.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   └── app_typography.dart
│   ├── utils/
│   │   ├── amount_utils.dart         # Split calculations, rounding
│   │   ├── debt_simplifier.dart      # Debt minimization algorithm
│   │   ├── id_generator.dart
│   │   └── validators.dart
│   ├── widgets/                      # Shared widgets
│   │   ├── amount_display.dart
│   │   ├── avatar_widget.dart
│   │   ├── empty_state.dart
│   │   ├── error_widget.dart
│   │   ├── loading_widget.dart
│   │   └── sync_status_badge.dart
│   └── l10n/                         # Internationalization
│       ├── app_en.arb
│       └── app_hi.arb
│
├── data/                              # Data layer
│   ├── local/
│   │   ├── database/
│   │   │   ├── app_database.dart      # sqflite initialization & migrations
│   │   │   └── migration/
│   │   │       ├── migration_v1.dart
│   │   │       └── migration_runner.dart
│   │   ├── dao/                       # Data Access Objects
│   │   │   ├── user_dao.dart
│   │   │   ├── group_dao.dart
│   │   │   ├── expense_dao.dart
│   │   │   ├── settlement_dao.dart
│   │   │   ├── balance_dao.dart
│   │   │   ├── activity_dao.dart
│   │   │   ├── notification_dao.dart
│   │   │   ├── sync_queue_dao.dart
│   │   │   └── draft_dao.dart
│   │   └── preferences/
│   │       └── app_preferences.dart
│   │
│   ├── remote/
│   │   ├── firestore/
│   │   │   ├── user_firestore_source.dart
│   │   │   ├── group_firestore_source.dart
│   │   │   ├── expense_firestore_source.dart
│   │   │   ├── settlement_firestore_source.dart
│   │   │   └── invite_firestore_source.dart
│   │   ├── cloud_functions/
│   │   │   ├── functions_client.dart
│   │   │   ├── debt_simplification_fn.dart
│   │   │   └── export_fn.dart
│   │   ├── storage/
│   │   │   └── file_storage_source.dart
│   │   └── auth/
│   │       └── firebase_auth_source.dart
│   │
│   ├── models/                        # Data transfer objects
│   │   ├── user_model.dart
│   │   ├── group_model.dart
│   │   ├── expense_model.dart
│   │   ├── expense_payer_model.dart
│   │   ├── expense_split_model.dart
│   │   ├── expense_item_model.dart
│   │   ├── settlement_model.dart
│   │   ├── balance_model.dart
│   │   ├── activity_model.dart
│   │   ├── notification_model.dart
│   │   └── sync_queue_model.dart
│   │
│   ├── mappers/                       # Entity ↔ Model mappers
│   │   ├── user_mapper.dart
│   │   ├── group_mapper.dart
│   │   ├── expense_mapper.dart
│   │   └── settlement_mapper.dart
│   │
│   ├── repositories/                  # Repository implementations
│   │   ├── auth_repository_impl.dart
│   │   ├── user_repository_impl.dart
│   │   ├── group_repository_impl.dart
│   │   ├── expense_repository_impl.dart
│   │   ├── settlement_repository_impl.dart
│   │   ├── balance_repository_impl.dart
│   │   ├── notification_repository_impl.dart
│   │   └── analytics_repository_impl.dart
│   │
│   └── sync/                          # Sync engine
│       ├── sync_engine.dart
│       ├── sync_worker.dart
│       ├── conflict_resolver.dart
│       └── sync_status_notifier.dart
│
├── domain/                            # Domain layer (pure Dart)
│   ├── entities/
│   │   ├── user.dart
│   │   ├── group.dart
│   │   ├── group_member.dart
│   │   ├── expense.dart
│   │   ├── expense_payer.dart
│   │   ├── expense_split.dart
│   │   ├── expense_item.dart
│   │   ├── settlement.dart
│   │   ├── balance.dart
│   │   ├── activity.dart
│   │   └── notification.dart
│   │
│   ├── repositories/                  # Repository interfaces
│   │   ├── auth_repository.dart
│   │   ├── user_repository.dart
│   │   ├── group_repository.dart
│   │   ├── expense_repository.dart
│   │   ├── settlement_repository.dart
│   │   ├── balance_repository.dart
│   │   ├── notification_repository.dart
│   │   └── analytics_repository.dart
│   │
│   ├── usecases/
│   │   ├── auth/
│   │   │   ├── send_otp.dart
│   │   │   ├── verify_otp.dart
│   │   │   ├── sign_out.dart
│   │   │   └── delete_account.dart
│   │   ├── user/
│   │   │   ├── get_current_user.dart
│   │   │   ├── update_profile.dart
│   │   │   └── search_contacts.dart
│   │   ├── group/
│   │   │   ├── create_group.dart
│   │   │   ├── get_groups.dart
│   │   │   ├── get_group_detail.dart
│   │   │   ├── add_member.dart
│   │   │   ├── remove_member.dart
│   │   │   ├── archive_group.dart
│   │   │   ├── generate_invite_link.dart
│   │   │   └── join_via_invite.dart
│   │   ├── expense/
│   │   │   ├── add_expense.dart
│   │   │   ├── edit_expense.dart
│   │   │   ├── delete_expense.dart
│   │   │   ├── get_group_expenses.dart
│   │   │   ├── get_expense_detail.dart
│   │   │   ├── duplicate_expense.dart
│   │   │   ├── save_draft.dart
│   │   │   └── calculate_splits.dart
│   │   ├── settlement/
│   │   │   ├── record_settlement.dart
│   │   │   ├── get_settlements.dart
│   │   │   └── generate_settle_plan.dart
│   │   ├── balance/
│   │   │   ├── get_group_balances.dart
│   │   │   ├── get_overall_balance.dart
│   │   │   └── recalculate_balances.dart
│   │   └── analytics/
│   │       ├── get_category_breakdown.dart
│   │       ├── get_monthly_trend.dart
│   │       └── get_group_summary.dart
│   │
│   └── value_objects/
│       ├── amount.dart                # Value object wrapping paise
│       ├── phone_number.dart
│       ├── email_address.dart
│       └── split_config.dart
│
├── presentation/                      # Presentation layer
│   ├── providers/                     # Riverpod providers
│   │   ├── auth_providers.dart
│   │   ├── user_providers.dart
│   │   ├── group_providers.dart
│   │   ├── expense_providers.dart
│   │   ├── settlement_providers.dart
│   │   ├── balance_providers.dart
│   │   ├── notification_providers.dart
│   │   ├── analytics_providers.dart
│   │   ├── connectivity_provider.dart
│   │   └── sync_providers.dart
│   │
│   └── features/                      # Feature modules
│       ├── auth/
│       │   ├── screens/
│       │   │   ├── welcome_screen.dart
│       │   │   ├── phone_input_screen.dart
│       │   │   ├── otp_verification_screen.dart
│       │   │   └── profile_setup_screen.dart
│       │   └── widgets/
│       │       ├── otp_input_field.dart
│       │       └── phone_input_field.dart
│       │
│       ├── home/
│       │   ├── screens/
│       │   │   └── home_screen.dart
│       │   └── widgets/
│       │       ├── balance_summary_card.dart
│       │       ├── group_list_tile.dart
│       │       ├── recent_activity_list.dart
│       │       └── quick_add_fab.dart
│       │
│       ├── group/
│       │   ├── screens/
│       │   │   ├── group_detail_screen.dart
│       │   │   ├── create_group_screen.dart
│       │   │   ├── group_settings_screen.dart
│       │   │   └── member_management_screen.dart
│       │   └── widgets/
│       │       ├── expense_list_tile.dart
│       │       ├── member_balance_card.dart
│       │       └── group_header.dart
│       │
│       ├── expense/
│       │   ├── screens/
│       │   │   ├── add_expense_screen.dart
│       │   │   ├── expense_detail_screen.dart
│       │   │   ├── split_selection_screen.dart
│       │   │   └── itemized_split_screen.dart
│       │   └── widgets/
│       │       ├── amount_input.dart
│       │       ├── category_picker.dart
│       │       ├── payer_selector.dart
│       │       ├── participant_selector.dart
│       │       ├── split_preview.dart
│       │       └── receipt_attachment.dart
│       │
│       ├── settlement/
│       │   ├── screens/
│       │   │   ├── settle_up_screen.dart
│       │   │   └── settlement_detail_screen.dart
│       │   └── widgets/
│       │       ├── settlement_card.dart
│       │       └── suggested_settlement.dart
│       │
│       ├── activity/
│       │   ├── screens/
│       │   │   └── activity_feed_screen.dart
│       │   └── widgets/
│       │       └── activity_tile.dart
│       │
│       ├── analytics/
│       │   ├── screens/
│       │   │   └── analytics_screen.dart
│       │   └── widgets/
│       │       ├── category_pie_chart.dart
│       │       ├── monthly_trend_chart.dart
│       │       └── group_summary_card.dart
│       │
│       ├── search/
│       │   ├── screens/
│       │   │   └── search_screen.dart
│       │   └── widgets/
│       │       └── search_result_tile.dart
│       │
│       ├── notifications/
│       │   ├── screens/
│       │   │   └── notification_center_screen.dart
│       │   └── widgets/
│       │       └── notification_tile.dart
│       │
│       └── settings/
│           ├── screens/
│           │   ├── settings_screen.dart
│           │   ├── profile_edit_screen.dart
│           │   └── notification_prefs_screen.dart
│           └── widgets/
│               └── settings_tile.dart
│
└── firebase_options.dart              # Generated by FlutterFire CLI
```

---

## 2. Core Class Diagrams

### 2.1 Domain Entities

```
┌────────────────────────────────────────────────────────────────────┐
│                        DOMAIN ENTITIES                             │
│                                                                    │
│  ┌───────────────┐                                                │
│  │     User      │                                                │
│  │───────────────│                                                │
│  │ + id: String  │                                                │
│  │ + name: String│                                                │
│  │ + email: String                                                │
│  │ + phone: String                                                │
│  │ + avatarUrl: String?                                           │
│  │ + language: AppLocale                                          │
│  │ + createdAt: DateTime                                          │
│  └───────────────┘                                                │
│                                                                    │
│  ┌────────────────────┐      ┌──────────────────────┐             │
│  │      Group         │      │    GroupMember        │             │
│  │────────────────────│      │──────────────────────│             │
│  │ + id: String       │──┐   │ + userId: String     │             │
│  │ + name: String     │  └──<│ + groupId: String    │             │
│  │ + category: GroupCat│     │ + name: String       │             │
│  │ + coverPhotoUrl: ?  │     │ + role: MemberRole   │             │
│  │ + createdBy: String │     │ + isGuest: bool      │             │
│  │ + isArchived: bool  │     │ + joinedAt: DateTime │             │
│  │ + defaultSplit: Type│     │ + isActive: bool     │             │
│  │ + memberCount: int  │     └──────────────────────┘             │
│  │ + isPinned: bool    │                                          │
│  │ + myBalance: Amount │                                          │
│  └────────────────────┘                                           │
│                                                                    │
│  ┌────────────────────────┐                                       │
│  │       Expense          │                                       │
│  │────────────────────────│                                       │
│  │ + id: String           │                                       │
│  │ + groupId: String?     │                                       │
│  │ + description: String  │                                       │
│  │ + amount: Amount       │        ┌──────────────────┐           │
│  │ + date: DateTime       │───────>│  ExpensePayer    │           │
│  │ + category: ExpenseCat │        │──────────────────│           │
│  │ + splitType: SplitType │        │ + userId: String │           │
│  │ + notes: String?       │        │ + amountPaid: Amt│           │
│  │ + payers: List<Payer>  │        └──────────────────┘           │
│  │ + splits: List<Split>  │                                       │
│  │ + items: List<Item>?   │        ┌──────────────────┐           │
│  │ + attachments: List<>  │───────>│  ExpenseSplit    │           │
│  │ + createdBy: String    │        │──────────────────│           │
│  │ + isDeleted: bool      │        │ + userId: String │           │
│  │ + isRecurring: bool    │        │ + amountOwed: Amt│           │
│  │ + recurringRule: Rule? │        │ + percentage: ?  │           │
│  │ + version: int         │        │ + shares: double?│           │
│  │ + syncStatus: SyncStat │        └──────────────────┘           │
│  └────────────────────────┘                                       │
│                                     ┌──────────────────┐          │
│  ┌────────────────────────┐         │  ExpenseItem     │          │
│  │     Settlement         │         │──────────────────│          │
│  │────────────────────────│         │ + name: String   │          │
│  │ + id: String           │         │ + amount: Amount │          │
│  │ + groupId: String      │         │ + assignedTo: [] │          │
│  │ + fromUserId: String   │         └──────────────────┘          │
│  │ + toUserId: String     │                                       │
│  │ + amount: Amount       │        ┌──────────────────────┐       │
│  │ + date: DateTime       │        │     Balance          │       │
│  │ + notes: String?       │        │──────────────────────│       │
│  │ + version: int         │        │ + groupId: String    │       │
│  │ + syncStatus: SyncStat │        │ + userAId: String    │       │
│  └────────────────────────┘        │ + userBId: String    │       │
│                                    │ + amount: Amount     │       │
│                                    └──────────────────────┘       │
│                                                                    │
│  ┌──────── ENUMS ─────────────────────────────────────────────┐   │
│  │                                                             │   │
│  │  SplitType: equal | exact | percentage | shares | itemized │   │
│  │  MemberRole: owner | admin | member                        │   │
│  │  GroupCategory: trip | home | couple | event | other        │   │
│  │  ExpenseCategory: food | transport | groceries | rent |    │   │
│  │    entertainment | utilities | shopping | health | travel | │   │
│  │    other                                                    │   │
│  │  SyncStatus: synced | pending | conflict                   │   │
│  │  AppLocale: en | hi                                        │   │
│  └─────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

### 2.2 Value Objects

```
┌───────────────────────────────────────────────────────────┐
│                    VALUE OBJECTS                           │
│                                                           │
│  ┌────────────────────────┐                               │
│  │        Amount          │  Immutable value object        │
│  │────────────────────────│  wrapping monetary amounts     │
│  │ - _paise: int          │                               │
│  │────────────────────────│                               │
│  │ + Amount.fromPaise(int)│                               │
│  │ + Amount.fromRupees(d) │                               │
│  │ + paise: int           │                               │
│  │ + rupees: double       │                               │
│  │ + display: String      │  "₹1,234.56"                 │
│  │ + isZero: bool         │                               │
│  │ + isPositive: bool     │                               │
│  │ + operator +(Amount)   │                               │
│  │ + operator -(Amount)   │                               │
│  │ + splitEqual(int n)    │  Returns List<Amount>         │
│  └────────────────────────┘                               │
│                                                           │
│  ┌────────────────────────┐  ┌─────────────────────────┐  │
│  │    PhoneNumber         │  │    EmailAddress          │  │
│  │────────────────────────│  │─────────────────────────│  │
│  │ - _value: String       │  │ - _value: String        │  │
│  │────────────────────────│  │─────────────────────────│  │
│  │ + validate(): bool     │  │ + validate(): bool      │  │
│  │ + formatted: String    │  │ + value: String         │  │
│  │ + countryCode: String  │  └─────────────────────────┘  │
│  └────────────────────────┘                               │
│                                                           │
│  ┌────────────────────────────────┐                       │
│  │       SplitConfig              │                       │
│  │────────────────────────────────│                       │
│  │ + type: SplitType              │                       │
│  │ + participants: List<String>   │                       │
│  │ + amounts: Map<String, Amount>?│  for exact split     │
│  │ + percentages: Map<String, d>? │  for % split         │
│  │ + shares: Map<String, double>? │  for shares split    │
│  │ + items: List<ExpenseItem>?    │  for itemized split  │
│  │────────────────────────────────│                       │
│  │ + calculateSplits(): List<>    │                       │
│  │ + validate(): bool             │                       │
│  │ + totalAssigned: Amount        │                       │
│  │ + remainder: Amount            │                       │
│  └────────────────────────────────┘                       │
└───────────────────────────────────────────────────────────┘
```

### 2.3 Repository Interfaces (Domain Layer)

```
┌────────────────────────────────────────────────────────────────────┐
│                   REPOSITORY INTERFACES                            │
│                                                                    │
│  ┌──────────────────────────────┐                                 │
│  │      AuthRepository          │                                 │
│  │  <<abstract>>                │                                 │
│  │──────────────────────────────│                                 │
│  │ + sendOtp(phone): Future<R>  │                                 │
│  │ + verifyOtp(id, code): F<R>  │                                 │
│  │ + signOut(): Future<void>    │                                 │
│  │ + deleteAccount(): Future<R> │                                 │
│  │ + currentUser: Stream<User?> │                                 │
│  │ + isAuthenticated: bool      │                                 │
│  └──────────────────────────────┘                                 │
│                                                                    │
│  ┌──────────────────────────────────────────┐                     │
│  │      GroupRepository                      │                     │
│  │  <<abstract>>                             │                     │
│  │──────────────────────────────────────────│                     │
│  │ + createGroup(Group): Future<Result<G>>   │                     │
│  │ + getGroups(): Stream<List<Group>>        │                     │
│  │ + getGroupById(id): Future<Result<G>>     │                     │
│  │ + updateGroup(Group): Future<Result<G>>   │                     │
│  │ + archiveGroup(id): Future<Result<void>>  │                     │
│  │ + addMember(gid, Member): Future<R>       │                     │
│  │ + removeMember(gid, uid): Future<R>       │                     │
│  │ + getMembers(gid): Stream<List<Member>>   │                     │
│  │ + generateInvite(gid): Future<R<String>>  │                     │
│  │ + joinViaInvite(code): Future<R<Group>>   │                     │
│  │ + pinGroup(gid, pinned): Future<R<void>>  │                     │
│  └──────────────────────────────────────────┘                     │
│                                                                    │
│  ┌──────────────────────────────────────────────────┐             │
│  │      ExpenseRepository                            │             │
│  │  <<abstract>>                                     │             │
│  │──────────────────────────────────────────────────│             │
│  │ + addExpense(Expense): Future<Result<Expense>>    │             │
│  │ + updateExpense(Expense): Future<Result<Expense>> │             │
│  │ + deleteExpense(id): Future<Result<void>>         │             │
│  │ + undoDelete(id): Future<Result<void>>            │             │
│  │ + getExpenses(gid, {filters}): Stream<List<Exp>>  │             │
│  │ + getExpenseById(id): Future<Result<Expense>>     │             │
│  │ + duplicateExpense(id): Future<Result<Expense>>   │             │
│  │ + saveDraft(draft): Future<Result<void>>          │             │
│  │ + getDraft(gid): Future<Result<Draft?>>           │             │
│  │ + searchExpenses(query): Future<R<List<Exp>>>     │             │
│  └──────────────────────────────────────────────────┘             │
│                                                                    │
│  ┌──────────────────────────────────────────────────┐             │
│  │      SettlementRepository                         │             │
│  │  <<abstract>>                                     │             │
│  │──────────────────────────────────────────────────│             │
│  │ + recordSettlement(Sttl): Future<Result<Sttl>>    │             │
│  │ + getSettlements(gid): Stream<List<Settlement>>   │             │
│  │ + deleteSettlement(id): Future<Result<void>>      │             │
│  │ + generateSettlePlan(gid): Future<R<List<Sttl>>>  │             │
│  └──────────────────────────────────────────────────┘             │
│                                                                    │
│  ┌──────────────────────────────────────────────────┐             │
│  │      BalanceRepository                            │             │
│  │  <<abstract>>                                     │             │
│  │──────────────────────────────────────────────────│             │
│  │ + getGroupBalances(gid): Stream<List<Balance>>    │             │
│  │ + getOverallBalance(): Stream<Amount>             │             │
│  │ + recalculate(gid): Future<Result<void>>          │             │
│  │ + getSimplifiedDebts(gid): Future<R<List<Debt>>>  │             │
│  └──────────────────────────────────────────────────┘             │
│                                                                    │
│  ┌──────────────────────────────────────────────────┐             │
│  │      AnalyticsRepository                          │             │
│  │  <<abstract>>                                     │             │
│  │──────────────────────────────────────────────────│             │
│  │ + getCategoryBreakdown(gid?, range): Future<R<>>  │             │
│  │ + getMonthlyTrend(gid?, months): Future<R<>>      │             │
│  │ + getGroupSummary(gid): Future<R<Summary>>        │             │
│  │ + exportData(format): Future<R<File>>              │             │
│  └──────────────────────────────────────────────────┘             │
└────────────────────────────────────────────────────────────────────┘
```

### 2.4 Data Layer — Repository Implementation Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│              REPOSITORY IMPLEMENTATION PATTERN                   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          ExpenseRepositoryImpl                            │   │
│  │  implements ExpenseRepository                             │   │
│  │──────────────────────────────────────────────────────────│   │
│  │ - _expenseDao: ExpenseDao          (local sqflite)        │   │
│  │ - _firestoreSource: ExpenseFS      (remote Firestore)     │   │
│  │ - _syncQueue: SyncQueueDao         (pending sync ops)     │   │
│  │ - _connectivity: ConnectivitySvc   (network state)        │   │
│  │──────────────────────────────────────────────────────────│   │
│  │                                                            │   │
│  │  addExpense(expense):                                      │   │
│  │    1. Validate expense data                                │   │
│  │    2. Save to local sqflite (sync_status = 'pending')      │   │
│  │    3. Recalculate local balances                           │   │
│  │    4. Log to local activity                                │   │
│  │    5. Enqueue sync operation                               │   │
│  │    6. If online → trigger immediate sync                   │   │
│  │    7. Return success (from local data)                     │   │
│  │                                                            │   │
│  │  getExpenses(gid):                                         │   │
│  │    1. Return Stream from local sqflite                     │   │
│  │    2. Firestore listener updates local DB in background    │   │
│  │    3. Local DB changes re-emit via Stream                  │   │
│  │                                                            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌───────── DATA FLOW ─────────────────────────────────────┐    │
│  │                                                          │    │
│  │  UI ──reads──> Provider ──reads──> Repository            │    │
│  │                                       │                  │    │
│  │                                  ┌────┴────┐             │    │
│  │                                  │         │             │    │
│  │                              Local DAO  Firestore        │    │
│  │                              (sqflite)  (listener)       │    │
│  │                                  │         │             │    │
│  │                                  └────┬────┘             │    │
│  │                                       │                  │    │
│  │  UI <──stream── Provider <──stream── Repository          │    │
│  │                                                          │    │
│  └──────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.5 Sync Engine

```
┌────────────────────────────────────────────────────────────────┐
│                      SYNC ENGINE                               │
│                                                                │
│  ┌────────────────────────────────┐                           │
│  │         SyncEngine             │                           │
│  │────────────────────────────────│                           │
│  │ - _syncQueue: SyncQueueDao     │                           │
│  │ - _connectivity: ConnSvc       │                           │
│  │ - _workers: Map<String, Worker>│                           │
│  │────────────────────────────────│                           │
│  │ + initialize(): void           │  Start listeners          │
│  │ + syncNow(): Future<void>      │  Manual trigger           │
│  │ + enqueue(SyncOp): Future<>    │  Add to queue             │
│  │ + status: Stream<SyncState>    │  syncing|synced|error     │
│  │ + pendingCount: Stream<int>    │  Unsynced item count      │
│  └──────────┬─────────────────────┘                           │
│             │                                                  │
│             │ delegates to                                     │
│             │                                                  │
│  ┌──────────▼─────────────────────┐                           │
│  │         SyncWorker             │  Per-entity-type worker    │
│  │────────────────────────────────│                           │
│  │ + processQueue(): Future<void> │                           │
│  │ + pushToFirestore(op): Future  │                           │
│  │ + pullFromFirestore(): Future  │                           │
│  │ + resolveConflict(local,       │                           │
│  │     remote): Resolution        │                           │
│  └────────────────────────────────┘                           │
│                                                                │
│  ┌────────────────────────────────┐                           │
│  │      ConflictResolver          │                           │
│  │────────────────────────────────│                           │
│  │ + resolve(local, remote):      │                           │
│  │     ConflictResolution         │                           │
│  │                                │                           │
│  │  Strategy:                     │                           │
│  │  1. Compare versions           │                           │
│  │  2. Last-write-wins for most   │                           │
│  │  3. Amount conflicts → notify  │                           │
│  │     user for manual resolution │                           │
│  │  4. Delete always wins         │                           │
│  └────────────────────────────────┘                           │
└────────────────────────────────────────────────────────────────┘
```

---

## 3. Provider Architecture (Riverpod)

```
┌────────────────────────────────────────────────────────────────────┐
│                    RIVERPOD PROVIDER GRAPH                         │
│                                                                    │
│  ── Infrastructure Providers ──────────────────────────────────── │
│  │                                                                │
│  │  firebaseAuthProvider ─────► FirebaseAuth instance             │
│  │  firestoreProvider ────────► FirebaseFirestore instance         │
│  │  storageProvider ──────────► FirebaseStorage instance           │
│  │  databaseProvider ─────────► sqflite Database instance          │
│  │  connectivityProvider ─────► ConnectivityService                │
│  │                                                                │
│  ── Data Source Providers ─────────────────────────────────────── │
│  │                                                                │
│  │  userDaoProvider ──────────► UserDao(database)                  │
│  │  groupDaoProvider ─────────► GroupDao(database)                 │
│  │  expenseDaoProvider ───────► ExpenseDao(database)               │
│  │  syncQueueDaoProvider ─────► SyncQueueDao(database)             │
│  │  userFirestoreProvider ────► UserFirestoreSource(firestore)     │
│  │  groupFirestoreProvider ───► GroupFirestoreSource(firestore)    │
│  │  expenseFirestoreProvider ─► ExpenseFirestoreSource(firestore)  │
│  │                                                                │
│  ── Repository Providers ──────────────────────────────────────── │
│  │                                                                │
│  │  authRepoProvider ────────► AuthRepositoryImpl(auth, dao, fs)   │
│  │  groupRepoProvider ───────► GroupRepositoryImpl(dao, fs, sync)   │
│  │  expenseRepoProvider ─────► ExpenseRepositoryImpl(dao, fs, sync)│
│  │  settlementRepoProvider ──► SettlementRepoImpl(dao, fs, sync)   │
│  │  balanceRepoProvider ─────► BalanceRepositoryImpl(dao)          │
│  │                                                                │
│  ── Use Case Providers ────────────────────────────────────────── │
│  │                                                                │
│  │  addExpenseProvider ──────► AddExpense(expenseRepo, balanceRepo)│
│  │  getGroupsProvider ───────► GetGroups(groupRepo)                │
│  │  getBalancesProvider ─────► GetGroupBalances(balanceRepo)       │
│  │  settlePlanProvider ──────► GenerateSettlePlan(settlementRepo)  │
│  │                                                                │
│  ── State Providers (UI-facing) ───────────────────────────────── │
│  │                                                                │
│  │  authStateProvider ──────► StreamProvider<User?>                │
│  │  groupListProvider ──────► StreamProvider<List<Group>>          │
│  │  groupDetailProvider(id) ► FamilyProvider<Group>                │
│  │  expenseListProvider(gid)► StreamProvider<List<Expense>>        │
│  │  balanceProvider(gid) ───► StreamProvider<List<Balance>>        │
│  │  overallBalanceProvider ─► StreamProvider<Amount>               │
│  │  syncStatusProvider ─────► StreamProvider<SyncState>            │
│  │  notificationProvider ───► StreamProvider<List<Notification>>   │
│  │                                                                │
│  ── Action Providers (mutations) ──────────────────────────────── │
│  │                                                                │
│  │  addExpenseAction ───────► FutureProvider.family<void, Expense> │
│  │  deleteExpenseAction ────► FutureProvider.family<void, String>  │
│  │  recordSettlementAction ─► FutureProvider.family<void, Settle>  │
│  │  createGroupAction ──────► FutureProvider.family<Group, Group>  │
│  │                                                                │
└────────────────────────────────────────────────────────────────────┘
```

---

## 4. Debt Simplification Algorithm — Class Design

```
┌────────────────────────────────────────────────────────────────┐
│                 DEBT SIMPLIFICATION                            │
│                                                                │
│  ┌──────────────────────────────────────┐                     │
│  │        DebtSimplifier               │                     │
│  │──────────────────────────────────────│                     │
│  │ + simplify(                         │                     │
│  │     balances: List<Balance>,        │                     │
│  │     members: List<String>           │                     │
│  │   ): List<SuggestedSettlement>      │                     │
│  │──────────────────────────────────────│                     │
│  │ - _calculateNetBalances(            │                     │
│  │     balances): Map<String, int>     │  Step 1: Net each   │
│  │ - _splitCreditorsDebtors(           │                     │
│  │     nets): (List, List)             │  Step 2: Partition  │
│  │ - _matchGreedy(                     │                     │
│  │     creditors, debtors):            │  Step 3: Match      │
│  │     List<SuggestedSettlement>       │    largest pairs     │
│  └──────────────────────────────────────┘                     │
│                                                                │
│  ┌──────────────────────────────────────┐                     │
│  │     SuggestedSettlement             │                     │
│  │──────────────────────────────────────│                     │
│  │ + fromUserId: String                │                     │
│  │ + fromUserName: String              │                     │
│  │ + toUserId: String                  │                     │
│  │ + toUserName: String                │                     │
│  │ + amount: Amount                    │                     │
│  └──────────────────────────────────────┘                     │
│                                                                │
│  Algorithm complexity: O(n log n) where n = members           │
│  Uses greedy matching with priority queue (max-heap)           │
└────────────────────────────────────────────────────────────────┘
```
