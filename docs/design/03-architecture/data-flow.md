# Data Flow Diagrams

This document captures sequence diagrams for the four most critical data flows in
OneByTwo. Each diagram is rendered via Mermaid and annotated with the invariants
and SRS sections it enforces.

References:

- SRS: `docs/OneByTwo_Requirements_Spec.md` (version 1.1)
- Invariants: `.github/shared/invariants.md`
- Decision log: `.github/shared/decision-log.md`

---

## Flow 1 — Phone OTP Login

**Relevant requirements:** FR-AU-01 through FR-AU-07 (SRS section 4.1).
**Relevant decisions:** ADR-0003 (single Firebase project), ADR-0004 (Riverpod).

```mermaid
sequenceDiagram
    participant U as User
    participant App as Flutter App
    participant Auth as Firebase Auth
    participant RC as Remote Config
    participant FS as Firestore

    U->>App: Enter +91 XXXXXXXXXX
    Note over App: Validate 10-digit Indian mobile number (FR-AU-02)

    App->>Auth: verifyPhoneNumber(+91XXXXXXXXXX)
    Auth-->>U: SMS with 6-digit OTP (FR-AU-03)

    U->>App: Enter OTP (auto-read on Android via SMS Retriever, FR-AU-04)
    App->>Auth: signInWithCredential(smsCode)
    Auth-->>App: UserCredential (uid, phone)
    Note over App: Session persisted locally — auto-login on next launch (FR-AU-07)

    App->>FS: GET users/{userId}
    alt New user (document does not exist)
        App->>U: Navigate to Profile Setup screen
        U->>App: Enter displayName, optional photo
        App->>FS: SET users/{userId} { phoneNumber, displayName, photoUrl, createdAt }
        Note over App: FR-AU-06 — first-login profile prompt
    else Existing user
        FS-->>App: User document
        App->>RC: fetchAndActivate()
        RC-->>App: Config values (feature flags, support email)
        App->>U: Navigate to Home dashboard
    end

    App->>FS: UPDATE users/{userId}.fcmTokens (array union)
    Note over App: FCM token registered for push notifications (SRS section 4.7)
```

### Invariants enforced

- **Invariant 4 (single Firebase project):** The app authenticates against the
  sole production Firebase project. All pre-merge testing uses the Emulator Suite
  (ADR-0003, SRS section 9.1).
- Phone number is restricted to `+91` prefix — no multi-country auth paths exist
  (SRS section 3.4).

---

## Flow 2 — Add Expense in a Group

**Relevant requirements:** FR-EX-01 through FR-EX-07 (SRS section 4.5),
FR-SE-03, FR-SE-04 (SRS section 4.6).
**Relevant decisions:** ADR-0001 (simplified debts is the sole mechanism),
ADR-0002 (money as integer paise).

```mermaid
sequenceDiagram
    participant U as User
    participant App as Flutter App
    participant FS as Firestore
    participant CF as Cloud Function<br/>(recomputeSimplifiedBalances)
    participant FCM as Firebase Cloud Messaging

    U->>App: Fill expense form (amount, payer, splits, category)
    Note over App: Validate splits sum to amountPaise exactly (FR-EX-04).<br/>All values are integer paise — Invariant 1 (ADR-0002).

    App->>FS: CREATE groups/{groupId}/expenses/{expenseId}<br/>{ amountPaise, payerId, splits, splitMethod, ... }
    Note over FS: Security Rules validate splits sum == amountPaise<br/>and that request.auth.uid is a group member (SRS section 7.5).

    FS-->>CF: onExpenseWrite trigger fires
    Note over CF: Runs in asia-south1 (Mumbai) — SRS section 3.4.

    CF->>FS: Transaction BEGIN
    CF->>FS: READ all non-deleted expenses for groups/{groupId}
    CF->>FS: READ all settlements for groups/{groupId}

    Note over CF: Run simplified-debts algorithm (SRS section 7.4):<br/>1. Compute net paise per member.<br/>2. Partition into creditors and debtors.<br/>3. Greedy pairing largest-to-largest.<br/>4. Ties broken by ascending userId for determinism.

    CF->>FS: WRITE groups/{groupId}.simplifiedBalances<br/>(within same transaction)
    Note over CF: Cloud Function writes simplifiedBalances,<br/>NOT the client — Invariant 2 (ADR-0001, SRS section 7.3).

    CF->>FS: Transaction COMMIT
    Note over CF: Atomic recomputation — FR-SE-04.

    CF->>FS: WRITE activity/{userId}/items for each participant (FR-EX-07)

    CF->>FCM: Send push notifications to affected group members
    FCM-->>U: Push notification received

    FS-->>App: Real-time listener receives updated simplifiedBalances
    Note over App: All connected clients see new balances immediately (FR-SE-06).
```

### Invariants enforced

- **Invariant 1 (money is integer paise):** `amountPaise` and every `sharePaise`
  value are integers. No floats cross any boundary — client, Firestore, or Cloud
  Function (ADR-0002, SRS section 7.3).
- **Invariant 2 (simplifiedBalances is server-maintained):** The client writes
  the expense document only. The `simplifiedBalances` field is written exclusively
  by the `recomputeSimplifiedBalances` Cloud Function inside a Firestore
  transaction. Security Rules block client writes to that field (SRS sections 4.6,
  7.3, 7.5).
- Split-sum validation is enforced at two layers: client-side before save
  (FR-EX-04) and server-side via Security Rules (SRS section 7.5).

---

## Flow 3 — Record Settlement

**Relevant requirements:** FR-SE-05 through FR-SE-08 (SRS section 4.6).
**Relevant decisions:** ADR-0001 (simplified debts is the sole mechanism),
ADR-0002 (money as integer paise).

```mermaid
sequenceDiagram
    participant U as User
    participant App as Flutter App
    participant FS as Firestore
    participant CF as Cloud Function<br/>(recomputeSimplifiedBalances)
    participant FCM as Firebase Cloud Messaging

    U->>App: Tap "Settle Up" on a non-zero balance (FR-SE-07)
    App->>FS: READ simplifiedBalances for context (group or friendship)
    FS-->>App: Current simplified debts

    Note over App: Pre-fill recipient (toUserId) and amount<br/>from the simplified-debts suggestion (FR-SE-05).

    U->>App: Confirm or adjust amount, add optional note
    Note over App: Amount is integer paise — Invariant 1 (ADR-0002).

    App->>FS: CREATE settlements/{settlementId}<br/>{ fromUserId, toUserId, amountPaise,<br/>  contextType, contextId, date, note }
    Note over FS: Security Rules validate fromUserId == request.auth.uid<br/>(SRS section 7.5).

    FS-->>CF: onSettlementWrite trigger fires

    CF->>FS: Transaction BEGIN
    CF->>FS: READ all non-deleted expenses for context
    CF->>FS: READ all settlements for context

    Note over CF: Run simplified-debts algorithm (SRS section 7.4).<br/>Settlement amounts reduce net balances.

    CF->>FS: WRITE simplifiedBalances on context document<br/>(within same transaction)
    Note over CF: Cloud Function writes simplifiedBalances,<br/>NOT the client — Invariant 2 (ADR-0001).

    CF->>FS: Transaction COMMIT

    CF->>FS: WRITE activity items for both parties

    CF->>FCM: Send push notification to counterparty
    FCM-->>U: Push notification received

    FS-->>App: Real-time listener receives updated simplifiedBalances
    Note over App: Both users see updated balances immediately (FR-SE-06).
```

### Invariants enforced

- **Invariant 1 (money is integer paise):** The settlement `amountPaise` is an
  integer. The pre-filled suggestion is read directly from `simplifiedBalances`,
  which is itself computed using integer arithmetic (ADR-0002).
- **Invariant 2 (simplifiedBalances is server-maintained):** Identical to Flow 2.
  The client creates a settlement document; the Cloud Function recomputes
  `simplifiedBalances` atomically (FR-SE-04, SRS section 7.3).
- **Security Rules:** `fromUserId` must equal `request.auth.uid`, preventing a
  user from recording a payment on behalf of someone else (SRS section 7.5).

---

## Flow 4 — Account Deletion

**Relevant requirements:** FR-AU-09 (SRS section 4.1), SRS section 5.5
(30-day SLA, DPDP compliance).
**Relevant decisions:** ADR-0003 (single Firebase project).

```mermaid
sequenceDiagram
    participant U as User
    participant App as Flutter App
    participant CF as Cloud Function<br/>(onUserDelete)
    participant FS as Firestore
    participant Auth as Firebase Auth
    participant ST as Cloud Storage

    U->>App: Navigate to Profile, tap "Delete Account"
    App->>U: Confirmation dialog with irreversibility warning

    U->>App: Confirm deletion
    App->>CF: CALL onUserDelete({ userId })
    Note over CF: Auth state verified server-side via Firebase Admin SDK<br/>(SRS section 5.4).

    CF->>FS: READ all friendships where memberIds contains userId
    CF->>FS: READ all groups where memberIds contains userId

    loop For each shared group
        CF->>FS: Anonymise user references in group expenses and activity<br/>(replace displayName with "Deleted User", clear photoUrl)
        CF->>FS: Remove userId from groups/{groupId}.memberIds
        CF->>FS: Recompute simplifiedBalances excluding deleted user
        Note over CF: simplifiedBalances updated server-side — Invariant 2.
    end

    loop For each friendship
        CF->>FS: Anonymise user references in friendship expenses and activity
        CF->>FS: DELETE friendships/{friendshipId} (or mark inactive)
    end

    CF->>FS: DELETE users/{userId} (personal data: name, phone, FCM tokens)
    Note over CF: Personal data removed — DPDP compliance (SRS section 5.5).

    CF->>ST: DELETE avatar image at users/{userId}/avatar
    Note over ST: Receipt images in shared contexts are retained<br/>(they belong to the expense, not the deleted user).

    CF->>Auth: deleteUser(userId)
    Note over Auth: Firebase Auth record removed.<br/>Phone number freed for potential re-registration.

    CF-->>App: Deletion acknowledged
    App->>U: Clear local session, navigate to login screen

    Note over CF: Full deletion completes within 30-day SLA (SRS section 5.5).<br/>Heavy operations may be batched asynchronously<br/>but personal data removal is prioritised.
```

### Invariants enforced

- **Invariant 2 (simplifiedBalances is server-maintained):** When a user is
  removed from groups, the Cloud Function recomputes `simplifiedBalances` to
  reflect the removal. The client never touches this field.
- **Invariant 4 (single Firebase project):** Deletion operates against the sole
  production project. Auth record, Firestore documents, and Storage objects all
  reside in the same project (ADR-0003).
- **Security (SRS section 5.4):** The Cloud Function verifies authentication
  server-side via the Admin SDK. PII is never logged to Crashlytics or Analytics.
- **Privacy (SRS section 5.5):** All personal data (phone number, display name,
  photo, FCM tokens) is deleted or anonymised within 30 days. Shared financial
  records (expenses, settlements) are anonymised but retained for audit integrity,
  consistent with the soft-delete principle (SRS section 7.3).

---

## Cross-cutting notes

1. **Offline support (SRS section 4.10):** Flows 1 (login) and 4 (deletion)
   require network connectivity. Flows 2 and 3 benefit from Firestore's offline
   queue — the client write lands locally and syncs when connectivity resumes. The
   Cloud Function trigger fires only after the write reaches the server, so
   `simplifiedBalances` updates are not available offline.

2. **App Check (SRS section 5.4):** All Firestore, Storage, and Cloud Function
   requests are gated by App Check (Play Integrity on Android, DeviceCheck on
   iOS). This is not shown in the diagrams for clarity but applies to every
   client-to-backend arrow.

3. **Region:** All Cloud Functions execute in `asia-south1` (Mumbai) to minimise
   latency for the India-focused user base (SRS section 3.4).

4. **Determinism (SRS section 7.4):** The simplified-debts algorithm breaks ties
   by ascending `userId`, guaranteeing that any two executions over the same
   input produce identical output. This is critical because ADR-0001 establishes
   simplified debts as the sole debt mechanism — there is no fallback view.
