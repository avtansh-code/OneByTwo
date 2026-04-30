# C4 Component Diagrams -- OneByTwo

**Document type:** Architecture design -- C4 Level 3 (Component)
**Version:** 1.0
**Last updated:** 2025-01-27

This document provides C4 component-level views for the two primary containers
in the OneByTwo system: the Flutter mobile application and the Cloud Functions
backend. The diagrams use Mermaid syntax and follow the module boundaries
defined in the SRS (sections 5.7, 7.1, 13.1).

---

## 1. Flutter Application Components

The Flutter app follows a feature-first folder layout (SRS section 5.7,
section 13.1). Modules are organised into four tiers: the application shell
(`app/`), shared infrastructure (`core/`, `data/`, `l10n/`), and
domain-specific feature modules under `features/`. Arrows indicate compile-time
dependencies -- a module at the tail depends on the module at the head.

State management uses Riverpod 2.x (ADR-0004, confirmed). Navigation uses
GoRouter (ADR-0007, proposed). Both are wired in the `app/` shell.

```mermaid
graph TD
    subgraph "Flutter Application"
        direction TB

        subgraph "Application Shell"
            APP["app/<br/>---<br/>App shell, GoRouter routing,<br/>ThemeData (Material 3),<br/>Riverpod ProviderScope"]
        end

        subgraph "Feature Modules"
            AUTH["features/auth/<br/>---<br/>Phone entry (+91), OTP verification,<br/>profile setup, sign-out,<br/>account deletion request"]
            FRIENDS["features/friends/<br/>---<br/>Friend list, add friend,<br/>friend detail, balance history"]
            GROUPS["features/groups/<br/>---<br/>Group list, create group,<br/>group detail, invite members,<br/>member management"]
            EXPENSES["features/expenses/<br/>---<br/>Add/edit expense, split methods<br/>(equal, unequal, percentage,<br/>shares, exact), categories,<br/>receipt attachment"]
            SETTLEMENTS["features/settlements/<br/>---<br/>Settle up flow,<br/>settlement history"]
            PROFILE["features/profile/<br/>---<br/>View/edit profile,<br/>notification preferences,<br/>contact support"]
            ACTIVITY["features/activity/<br/>---<br/>Activity feed<br/>(expense, settlement,<br/>group change events)"]
        end

        subgraph "Shared Infrastructure"
            CORE["core/<br/>---<br/>Error handling (Result type),<br/>money utils (paise formatter),<br/>validators (+91 regex),<br/>Dart extensions"]
            DATA["data/<br/>---<br/>Firebase repositories,<br/>DTOs / data models,<br/>Remote Config provider,<br/>Firestore stream wrappers"]
            L10N["l10n/<br/>---<br/>.arb localisation files<br/>(en locale, v1.0)"]
        end
    end

    %% App shell depends on all feature modules for routing
    APP --> AUTH
    APP --> FRIENDS
    APP --> GROUPS
    APP --> EXPENSES
    APP --> SETTLEMENTS
    APP --> PROFILE
    APP --> ACTIVITY
    APP --> CORE
    APP --> DATA
    APP --> L10N

    %% Feature module dependencies on shared infrastructure
    AUTH --> CORE
    AUTH --> DATA
    AUTH --> L10N

    FRIENDS --> CORE
    FRIENDS --> DATA
    FRIENDS --> L10N

    GROUPS --> CORE
    GROUPS --> DATA
    GROUPS --> L10N

    EXPENSES --> CORE
    EXPENSES --> DATA
    EXPENSES --> L10N

    SETTLEMENTS --> CORE
    SETTLEMENTS --> DATA
    SETTLEMENTS --> L10N

    PROFILE --> CORE
    PROFILE --> DATA
    PROFILE --> L10N

    ACTIVITY --> CORE
    ACTIVITY --> DATA
    ACTIVITY --> L10N

    %% Cross-feature dependencies
    EXPENSES --> FRIENDS
    EXPENSES --> GROUPS
    SETTLEMENTS --> FRIENDS
    SETTLEMENTS --> GROUPS

    %% Data layer depends on core utilities
    DATA --> CORE
```

### Key dependency rules

1. **Feature modules never depend on each other**, with two justified
   exceptions: `expenses` and `settlements` reference `friends` and `groups`
   because expense creation and settlement flows require selecting a friend or
   group context (SRS sections 4.5, 4.6). These cross-feature references are
   restricted to shared identifiers and provider reads, not widget imports.

2. **All feature modules depend on `core/`, `data/`, and `l10n/`** for
   shared utilities, repository access, and localised strings respectively.

3. **`data/` depends on `core/`** for error types, money utilities, and
   validators. It does not depend on any feature module.

4. **`l10n/` and `core/` are leaf modules** with no internal dependencies on
   other application modules.

5. **`app/` is the composition root.** It wires the `ProviderScope`, registers
   GoRouter routes that reference feature-module screens, and applies the
   global `ThemeData`. It depends on every other module but no module depends
   on it.

---

## 2. Cloud Functions Components

The Cloud Functions backend (Node.js 20, TypeScript, region `asia-south1`) is
organised by trigger type, with a shared core module for the simplified-debts
algorithm and common utilities (SRS sections 7.1, 7.3, 7.4, 13.1).

```mermaid
graph TD
    subgraph "External Trigger Sources"
        FS_EXP[("Firestore<br/>expenses collection<br/>(write events)")]
        FS_SET[("Firestore<br/>settlements collection<br/>(write events)")]
        FS_USR[("Firestore<br/>users collection<br/>(delete events)")]
        CLIENT["Flutter App<br/>(HTTPS callable)"]
    end

    subgraph "Cloud Functions Container"
        direction TB

        subgraph "Firestore Triggers"
            ON_EXP["onExpenseWrite<br/>---<br/>Triggered on create/update/delete<br/>of expense documents under<br/>groups or friendships.<br/>Invokes recomputeSimplifiedBalances.<br/>Writes activity feed items."]
            ON_SET["onSettlementWrite<br/>---<br/>Triggered on create/update<br/>of settlement documents.<br/>Invokes recomputeSimplifiedBalances.<br/>Writes activity feed items."]
            ON_DEL["onUserDelete<br/>---<br/>Triggered on user document<br/>deletion. Cascades cleanup:<br/>removes from groups, friendships,<br/>FCM tokens. Anonymises<br/>activity references."]
        end

        subgraph "Callable Functions"
            ACCEPT["acceptGroupInvite<br/>---<br/>Validates invite token/link.<br/>Adds caller to group memberIds.<br/>Writes activity feed item."]
            REVOKE["revokeGroupInvite<br/>---<br/>Admin-only. Removes pending<br/>invite. Validates caller<br/>is group admin."]
            REMIND["sendReminderNotification<br/>---<br/>Sends FCM push to debtor.<br/>Rate-limited per sender.<br/>Reads fcmTokens from<br/>user document."]
        end

        subgraph "Core Module"
            DEBTS["simplifiedDebts.ts<br/>---<br/>Pure function.<br/>Net-balance, partition,<br/>greedy matching algorithm.<br/>Deterministic tie-breaking<br/>by ascending userId.<br/>(SRS section 7.4)"]
        end

        subgraph "Shared Utilities"
            TYPES["types.ts<br/>---<br/>Shared TypeScript interfaces:<br/>Expense, Settlement, Split,<br/>SimplifiedBalance, ActivityItem"]
            VALID["validation.ts<br/>---<br/>Input validation helpers:<br/>paise assertions (integer, > 0),<br/>splits-sum check,<br/>memberIds membership check"]
        end
    end

    subgraph "Output Destinations"
        FS_BAL[("Firestore<br/>simplifiedBalances field<br/>on groups / friendships")]
        FS_ACT[("Firestore<br/>activity/{userId}/items")]
        FS_GRP[("Firestore<br/>groups/{groupId}<br/>memberIds")]
        FCM_SVC["Firebase Cloud Messaging"]
    end

    %% Trigger sources to functions
    FS_EXP -->|"onCreate / onUpdate / onDelete"| ON_EXP
    FS_SET -->|"onCreate / onUpdate"| ON_SET
    FS_USR -->|"onDelete"| ON_DEL
    CLIENT -->|"HTTPS callable"| ACCEPT
    CLIENT -->|"HTTPS callable"| REVOKE
    CLIENT -->|"HTTPS callable"| REMIND

    %% Internal dependencies
    ON_EXP --> DEBTS
    ON_EXP --> TYPES
    ON_EXP --> VALID
    ON_SET --> DEBTS
    ON_SET --> TYPES
    ON_SET --> VALID
    ON_DEL --> TYPES
    ACCEPT --> TYPES
    ACCEPT --> VALID
    REVOKE --> TYPES
    REVOKE --> VALID
    REMIND --> TYPES
    DEBTS --> TYPES

    %% Output destinations
    ON_EXP -->|"writes"| FS_BAL
    ON_EXP -->|"writes"| FS_ACT
    ON_SET -->|"writes"| FS_BAL
    ON_SET -->|"writes"| FS_ACT
    ON_DEL -->|"cascades"| FS_GRP
    ON_DEL -->|"writes"| FS_ACT
    ACCEPT -->|"writes"| FS_GRP
    ACCEPT -->|"writes"| FS_ACT
    REMIND -->|"sends"| FCM_SVC
```

### Trigger and data-flow notes

1. **`onExpenseWrite` and `onSettlementWrite`** are the only paths that invoke
   `simplifiedDebts.ts` and write to the `simplifiedBalances` field. This
   enforces Invariant 2 -- clients never write to `simplifiedBalances`
   (SRS sections 4.6, 7.3, 7.5).

2. **`simplifiedDebts.ts` is a pure function** with no Firestore or network
   dependencies. It accepts an array of expenses and settlements, returns a
   list of `{ from, to, amountPaise }` transfers. All monetary values are
   integer paise (Invariant 1). The algorithm is specified in SRS section 7.4
   and must be covered by its own unit-test suite (SRS section 5.7).

3. **`onUserDelete`** handles account deletion cascading. The deletion itself
   is initiated by the client calling Firebase Auth delete, which triggers
   this function. Heavy operations run server-side so the client cannot bypass
   invariants (SRS section 7.3).

4. **`acceptGroupInvite` and `revokeGroupInvite`** are callable functions
   rather than direct Firestore writes because group membership changes
   require server-side validation that the client cannot be trusted to perform
   (SRS section 7.3). Invite link resolution follows ADR-0015 (deep linking
   via Universal Links / App Links rather than deprecated Dynamic Links).

5. **`sendReminderNotification`** is callable rather than triggered because
   the reminder is user-initiated (SRS section 4.7). It reads `fcmTokens`
   from the target user's document and dispatches via Firebase Cloud
   Messaging.

6. **`validation.ts`** provides shared checks used by both triggers and
   callables: paise integrity (integer, greater than zero), splits-sum
   equality with expense amount, and membership verification. These mirror
   the Firestore Security Rules checks but are applied within function
   transactions for defence in depth (SRS section 7.5).

---

## References

| Section | Source |
|---|---|
| High-level architecture | SRS section 7.1 |
| Data model | SRS section 7.2 |
| Key architectural decisions | SRS section 7.3 |
| Simplified-debts algorithm | SRS section 7.4 |
| Security rules principles | SRS section 7.5 |
| Maintainability and feature-first structure | SRS section 5.7 |
| Suggested project structure | SRS section 13.1 |
| State management (Riverpod 2.x) | ADR-0004 |
| Navigation (GoRouter) | ADR-0007 |
| Deep linking (Universal Links / App Links) | ADR-0015 |
