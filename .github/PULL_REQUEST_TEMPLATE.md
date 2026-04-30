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
