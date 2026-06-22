## Description

<!-- Briefly describe the changes in this PR. Reference the user story or issue. -->

Closes #

## SRS Requirement(s)

<!-- List the SRS requirement IDs covered (e.g., FR-EX-01, FR-SE-03). -->

## Type of Change

- [ ] `feat` — New feature
- [ ] `fix` — Bug fix
- [ ] `refactor` — Code change that neither fixes a bug nor adds a feature
- [ ] `docs` — Documentation only
- [ ] `test` — Adding or fixing tests
- [ ] `chore` — Maintenance, config, or dependency change
- [ ] `ci` — CI/CD pipeline change

## Invariant Checklist

All four invariants must be respected. Tick each to confirm compliance:

- [ ] **Integer paise:** All monetary values use `int` (Dart) or `number`
      (TypeScript) representing paise. No `double`/`float` for money.
- [ ] **`simplifiedBalances` server-only:** No client-side writes to this field.
      Only the `recomputeSimplifiedBalances` Cloud Function may write it.
- [ ] **System share sheet only:** No platform-specific share package imports
      (WhatsApp, Telegram, etc.). Uses `share_plus` or native share API.
- [ ] **Single Firebase project:** No new Firebase project IDs added. No
      staging/dev project references.

## Testing

- [ ] Unit tests added / updated
- [ ] Widget tests added / updated
- [ ] Integration tests added / updated (if applicable)
- [ ] At least one negative test case included
- [ ] Coverage thresholds maintained (>= 70% non-UI, >= 50% overall)
- [ ] Simplified-debts canonical tests still pass (if applicable)

### Coverage (per touched feature / module)

<!--
One line per feature/module this PR touches, using the coverage run the gate uses
(flutter test --coverage / the Functions Istanbul report). Keep it lightweight — a
single before/after percentage per scope, not a full report. Pure docs/design/CI
PRs: write "N/A — no lib/ or functions/ code touched." and delete the table.
-->

| Scope (touched feature / module) | Before | After |
|---|---|---|
|  |  |  |

## Cloud Functions Checklist

<!-- Required only when this PR adds or changes a Cloud Function (functions/src/**). Delete this section if not applicable. -->

- [ ] **Region pinned to `asia-south1`** — no function left region-unset or on `us-central1`
- [ ] **Error codes mapped** — callables throw typed `HttpsError`s; no raw internals leaked to clients
- [ ] **Transactions used** where multi-document consistency is required (not independent get/set)
- [ ] **Idempotent** — triggers / callables tolerate retries and redelivery without double-applying writes

## Quality

- [ ] `dart format` clean (no formatting changes needed)
- [ ] `flutter analyze` clean (no warnings or infos)
- [ ] `npm run lint` clean (Cloud Functions, if applicable)
- [ ] DartDoc / JSDoc on all new public APIs
- [ ] No secrets or credentials in source
- [ ] Commit messages follow Conventional Commits

## Telemetry

- [ ] Analytics events added for new user actions (SRS section 5.10)
- [ ] No PII logged in Crashlytics or Analytics

## Documentation

- [ ] Relevant documentation updated (if applicable)
- [ ] ADR created for architectural decisions (if applicable)

## Screenshots / Recordings

<!-- Attach screenshots or recordings for UI changes. -->
