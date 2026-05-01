# FUNC-01: Simplified Debts Stub — recomputeSimplifiedBalances

> Implementation-ready user story for the `recomputeSimplifiedBalances` Cloud
> Function. Covers the pure simplified-debts algorithm, Firestore transaction
> write of `simplifiedBalances`, input validation, error semantics, security
> rules enforcement, and structured logging.

---

## SRS Requirement ID(s)

FUNC-01 (SRS sections 4.6, 7.3, 7.4, 7.5)

## Priority

**P0 — Must have**

## Story Points

8

## User Story

As a **system operator**,
I want the `recomputeSimplifiedBalances` Cloud Function to be **fully
implemented, tested, and deployed**
so that **when expenses and settlements are added in future PRs, the function
can compute correct simplified balances immediately**.

## Preconditions

1. Functions project skeleton deployed (healthcheck verified).
2. Firestore rules baseline in place.
3. Algorithm specification complete with 6 worked examples.

---

## Acceptance Criteria

### Scenario 1 — Empty input returns empty transfers

> Given a group or friendship context with zero expenses and zero settlements
> When `recomputeSimplifiedBalances` is invoked
> Then the function returns an empty transfers array and writes an empty
> `simplifiedBalances` map

### Scenario 2 — Three-person canonical case produces correct transfers

> Given a friendship or group with three members where member A paid 60000 paise
> split equally
> When `recomputeSimplifiedBalances` is invoked
> Then two transfers are returned: B->A 20000 paise and C->A 20000 paise
> And `simplifiedBalances` matches the canonical three-person worked example

### Scenario 3 — Five-person canonical case produces correct transfers

> Given a group with five members and the canonical flat-share expenses (rent
> 5000000, groceries 300000, electricity 200000)
> When `recomputeSimplifiedBalances` is invoked
> Then four transfers are returned matching the canonical five-person worked
> example exactly
> And transfer count is 4 (the minimum for this configuration)

### Scenario 4 (Negative) — Malformed input returns typed error

> Given a request with missing `contextId`
> When `recomputeSimplifiedBalances` is invoked
> Then an `INVALID_INPUT` typed error is returned (not a generic 500)
> And the error is logged as `simplified_debts_compute_failed` with no PII

### Scenario 5 (Negative) — Unknown contextType returns typed error

> Given a request with `contextType` set to an invalid value (e.g., "team")
> When `recomputeSimplifiedBalances` is invoked
> Then an `INVALID_INPUT` typed error is returned

### Scenario 6 (Negative) — Non-existent context returns typed error

> Given a request referencing a contextId that does not exist in Firestore
> When `recomputeSimplifiedBalances` is invoked
> Then a `CONTEXT_NOT_FOUND` typed error is returned

### Scenario 7 — Client cannot write simplifiedBalances

> Given an authenticated client
> When the client attempts to write to `simplifiedBalances` on a friendship or
> group document
> Then the write is denied by Firestore Security Rules

### Scenario 8 — Idempotent invocation

> Given a context with known expenses
> When `recomputeSimplifiedBalances` is invoked twice in succession
> Then both invocations produce identical `simplifiedBalances` output

---

## Canonical Test Matrix (6 Integration Tests)

The following six cases from the algorithm specification must each be covered by
an integration test running against the Firebase Emulator Suite. 100% branch
coverage of this matrix is required (DoD section 2).

| # | Case | Description |
|---|---|---|
| 1 | Empty | No expenses — returns empty transfers |
| 2 | Single member | Self-paid expense — net zero, no transfers |
| 3 | Perfectly balanced | All members' nets are zero — no transfers |
| 4 | Cyclic to zero | Three-person cycle that nets to zero — no transfers |
| 5 | Three-person trip | A pays 60000, equal split — 2 transfers |
| 6 | Five-person flat-share | Rent + groceries + electricity — 4 transfers |

---

## Telemetry Events

Server-side structured logging (Cloud Logging, NOT Firebase Analytics).

| Event name | Trigger | Parameters |
|---|---|---|
| `simplified_debts_compute_started` | Function invocation begins | contextType, contextId, memberCount |
| `simplified_debts_compute_completed` | Function invocation succeeds | elapsedMs, transferCount |
| `simplified_debts_compute_failed` | Function invocation fails | errorCode (no PII) |

Logs are structured JSON, viewable in Cloud Logging, alertable on error rate
per SRS section 5.10.

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | **APPLIES.** The algorithm operates exclusively on integer paise; never on doubles or rupees. Verified by unit tests that pass and assert paise-typed values throughout. |
| 2 | `simplifiedBalances` server-maintained | **APPLIES.** This function is the AUTHOR of `simplifiedBalances`. The Firestore rules deployed in this PR forbid all client writes to this field. Verified by both unit tests of the rules and a negative integration test (Scenario 7) that attempts a client write and expects rejection. |
| 3 | System share sheet only | **N/A.** No sharing in this story. |
| 4 | Single Firebase project | **APPLIES.** Function is deployed only to the production project, in `asia-south1`. Verified by inspecting `firebase.json` and the deploy log. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit tests written and passing for all algorithm logic.
- [ ] Integration tests passing against Firebase Emulator Suite (all 6 canonical cases).
- [ ] 100% branch coverage of the canonical test matrix.
- [ ] QA reviewed and verified acceptance criteria (including negative cases).
- [ ] Telemetry events in place and firing correctly (structured logging).
- [ ] Firestore Security Rules deny client writes to `simplifiedBalances`.
- [ ] Invariant compliance confirmed (all four assessed).
- [ ] Documentation updated (if applicable).
- [ ] No open S1 or S2 bugs.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Algorithm specification | `docs/design/07-technical/simplified-debts-algorithm.md` |
| Cloud Functions catalogue | `docs/design/07-technical/cloud-functions-catalogue.md` (section 1) |
| Error codes catalogue | `docs/design/07-technical/cloud-functions-error-codes.md` |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` |
| Firestore security rules outline | `docs/design/07-technical/firestore-security-rules.md` |

---

## Implementation Notes

- For this PR, `recomputeSimplifiedBalances` is deployed as an **HTTPS callable**
  for tests and manual verification only. It is NOT yet wired as a Firestore
  trigger on expense or settlement writes — that wiring is a later PR.
- The pure algorithm function is in `functions/src/simplified-debts/algorithm.ts`.
  It is independently unit-testable with no Firebase dependency.
- The function boundary handler is in `functions/src/simplified-debts/function.ts`.
  It wraps the algorithm with input validation, Firestore reads/writes, error
  mapping, and structured logging.
- The module index at `functions/src/simplified-debts/index.ts` exports the
  callable and wires it into `functions/src/index.ts`.
- Determinism is guaranteed: ties in net balances are broken by ascending
  `userId` (lexicographic string comparison) per SRS section 7.4.
- The function is idempotent: re-running with the same expense and settlement
  state produces identical output (Scenario 8).
- All monetary values are integer paise. No floats, no rupee conversion.
- Error semantics use typed error codes per
  `docs/design/07-technical/cloud-functions-error-codes.md`.
- No partial writes: the Firestore transaction is atomic.
