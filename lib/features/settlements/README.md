# Settlements

Feature-folder that owns the "settle up" surfaces: settlement creation
(FR-SE-08, future PR #43), settlement history (FR-FR-04 timeline read
path, PR #42), and payment reminders (FR-SE-09, separate later PR).

## Implemented scope

### Read path (PR #42)

PR #42 ships the read-only scaffolding required by the FR-FR-04 Friend
Detail screen:

- `domain/settlement_doc.dart` — immutable value type for a
  `settlements/{settlementId}` document. The `fromFirestore` factory
  applies strict type and shape validation:
  - Missing required field → returns `null` and fires `onParseFailure`.
  - Wrong type (e.g., `amountPaise` as `String` / `double`) → same.
  - Non-positive `amountPaise` (Invariant 1) → same.
  - Soft-deleted docs (`deleted == true`) still parse — the repository
    layer filters them out at the next layer.
- `data/settlement_repository.dart` — abstract `SettlementStore`,
  `FirestoreSettlementStore` (production), `SettlementRepository`
  wrapper, `settlementRepositoryProvider`. Mirrors the
  `FriendshipStore` (PR #35) and `ExpenseStore` (PR #38) patterns so
  tests inject a `FakeSettlementStore` (no `fake_cloud_firestore`
  dependency in `pubspec.yaml`).
- `SettlementRepository.watchByContext({contextType, contextId})` is
  the canonical read entry point. Soft-deleted entries are excluded
  from the projected list.

### Write path (deferred to FR-SE-08 / PR #43)

The settle-up bottom sheet, `SettlementRepository.createSettlement`,
and the `OBTSettleUpCard` affordance on `FriendDetailScreen` are all
deferred to PR #43. The position for the card is reserved on the
Friend Detail screen between the header and the timeline, but no card
renders until FR-SE-08 ships.

## Layout

```
data/
  settlement_repository.dart       # abstract store + Firestore impl + repo
domain/
  settlement_doc.dart              # strict-parsing immutable value type
```

## Invariants honoured

- **Invariant 1 (integer paise):** `amountPaise` is always `int`;
  `fromFirestore` rejects non-positive values and any non-`int`
  payload.
- **Invariant 2 parallel (ARCH-EXT-06 — `verificationStatus`
  server-maintained):** the field is exposed read-only on
  `SettlementDoc`; clients cannot write to it. The repository never
  writes to settlements (until FR-SE-08).
- **Invariant 3 (system share sheet only):** N/A.
- **Invariant 4 (single Firebase project):** every read goes through
  the single production project; pre-merge verification runs against
  the Firebase Emulator Suite.

## Hand-off boundaries

- **Out (read):** `SettlementRepository.watchByContext` powers the
  Friend Detail timeline (`lib/features/friends/`). FR-SE-08 / PR #43
  will extend this with `createSettlement` and an `OBTSettleUpCard`
  affordance on `FriendDetailScreen`.
- **Out (write):** `simplifiedBalances` on the friendship / group
  context is written exclusively by the `recomputeSimplifiedBalances`
  Cloud Function. The `onSettlementWrite` trigger
  (`functions/src/triggers/on-settlement-write/`) is the server-side
  consumer of settlement writes.
- **In (rules):** Firestore Security Rules on the `settlements/`
  collection were ratified in PR #37 and require
  `fromUserId == request.auth.uid` on create;
  `verificationStatus` is service-account-write-only.

## Firestore composite index

The settlements composite index in `firestore.indexes.json` was
extended in PR #42 from `(contextType ASC, contextId ASC)` to
`(contextType ASC, contextId ASC, date DESC)` so the canonical query
`where contextType + where contextId + orderBy date desc` runs without
`FAILED_PRECONDITION`. The extension matches the schema doc
(`docs/design/07-technical/firestore-schema.md` §Composite Indexes —
"Settlements by Context and Date"). DevOps deploys the updated index
before any release.
