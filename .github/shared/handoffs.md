# Handoffs

This file defines the explicit handoff contracts between agents. Every agent must
read this file before accepting or producing work.

Reference: SRS section 2.1 (Working Agreement Between Agents).

---

## Edge Definitions

Each handoff specifies: the trigger, the required inputs the receiver expects, the
acceptance criteria for the handoff to be considered valid, and where the artefact
lives.

### PM to Architect

| Field | Value |
|---|---|
| Trigger | PM completes a user story with acceptance criteria. |
| Required inputs | User story in SRS section 13.2 format (title, story, preconditions, Given/When/Then acceptance criteria with at least one negative case, Definition of Done checklist). |
| Acceptance criteria | Story is unambiguous, references the relevant SRS functional requirement ID(s), and has been added to the backlog issue tracker. |
| Artefact location | GitHub Issue using the `user_story` template. |

### Architect to Flutter Dev

| Field | Value |
|---|---|
| Trigger | Architect approves the technical design for a user story or schema change. |
| Required inputs | ADR (if a new decision was made), Firestore schema snippet, security rule changes (if any), API contract or Cloud Function interface the client will call, and the target feature folder path. |
| Acceptance criteria | Design is consistent with invariants (see `invariants.md`), references the relevant SRS section(s), and specifies which Riverpod providers or models are affected. |
| Artefact location | Comment on the GitHub Issue or a linked ADR in `decision-log.md`. |

### Architect to Functions Dev

| Field | Value |
|---|---|
| Trigger | Architect approves a Cloud Function design or schema change. |
| Required inputs | Function signature, trigger type (HTTP / Firestore trigger / callable), input/output types, Firestore paths affected, and the invariants the function must enforce. |
| Acceptance criteria | Design pins the function to `asia-south1`, specifies idempotency behaviour, and includes the canonical test cases for simplified-debts changes. |
| Artefact location | Comment on the GitHub Issue or a linked ADR. |

### Flutter Dev to QA

| Field | Value |
|---|---|
| Trigger | Flutter Dev opens a pull request for a feature or fix. |
| Required inputs | PR with passing CI, unit and widget tests added, description mapping changes to the relevant SRS requirement(s) and invariants checklist. |
| Acceptance criteria | All PR template checkboxes are ticked, no new lint warnings, coverage thresholds are met. |
| Artefact location | GitHub Pull Request. |

### Functions Dev to QA

| Field | Value |
|---|---|
| Trigger | Functions Dev opens a pull request for a Cloud Function change. |
| Required inputs | PR with passing CI (including emulator-based integration tests), unit tests covering edge cases, JSDoc on all exported functions. |
| Acceptance criteria | Simplified-debts canonical test matrix passes, function is region-pinned to `asia-south1`, no client-writable paths to `simplifiedBalances`. |
| Artefact location | GitHub Pull Request. |

### QA to DevOps

| Field | Value |
|---|---|
| Trigger | QA signs off a release candidate after running the full test plan. |
| Required inputs | QA sign-off comment on the release issue, list of critical user journeys passed, device matrix coverage, bug severity report (no open S1/S2). |
| Acceptance criteria | All P0 functional requirements pass, coverage thresholds are met, no open S1 or S2 bugs. |
| Artefact location | Comment on the release issue. |

### DevOps to QA (post-deploy)

| Field | Value |
|---|---|
| Trigger | DevOps completes a production deployment. |
| Required inputs | Deployment artefact links, Cloud Functions deployment log, release tag, release notes draft. |
| Acceptance criteria | Smoke tests pass on production, Crashlytics shows no new crash clusters, release notes are accurate. |
| Artefact location | GitHub Release and deployment logs. |

---

## End-to-End Journeys

The following journeys trace a piece of work from inception to production.

### 1. New Feature

```
PM (user story) --> Architect (technical design + ADR)
                        |
             +----------+----------+
             |                     |
      Flutter Dev (UI)     Functions Dev (backend)
             |                     |
             +----------+----------+
                        |
                    QA (test + sign-off)
                        |
                    DevOps (release)
```

1. PM writes user story from SRS requirement. Hands off to Architect.
2. Architect produces technical design, schema changes, ADR if needed. Hands off to
   Flutter Dev and/or Functions Dev (in parallel if independent).
3. Developers implement, write tests, open PRs. Hand off to QA.
4. QA reviews PRs, runs integration tests, signs off. Hands off to DevOps.
5. DevOps merges, tags, and runs the release pipeline.

### 2. Bug Fix

```
QA (bug report) --> Architect (triage + assign)
                        |
             Developer (fix + tests)
                        |
                    QA (verify fix)
                        |
                    DevOps (hotfix release if S1)
```

1. QA files a bug report using the `bug_report` template with severity.
2. Architect triages: confirms severity, identifies root cause area, assigns to the
   appropriate developer.
3. Developer fixes, adds regression tests, opens PR. Hands off to QA.
4. QA verifies the fix against the original repro steps and any related test cases.
5. If S1, DevOps runs a hotfix release immediately.

### 3. Schema Change

```
Architect (schema design + ADR) --> Functions Dev (migration + rules)
                                        |
                                    Flutter Dev (client update)
                                        |
                                    QA (integration test)
                                        |
                                    DevOps (deploy rules first, then client)
```

1. Architect designs the schema change, writes an ADR, updates security rules draft.
2. Functions Dev implements any required Cloud Function changes and updates
   `firestore.rules` and `firestore.indexes.json`.
3. Flutter Dev updates client code to work with the new schema.
4. QA runs integration tests against the emulator with the new schema.
5. DevOps deploys Firestore rules and indexes **before** the client update ships.

### 4. Release

```
PM (release scope) --> QA (full test pass)
                           |
                       DevOps (tag + pipeline)
                           |
                       QA (production smoke test)
                           |
                       PM (release notes)
```

1. PM confirms the release scope and that all user stories are complete.
2. QA runs the full test plan against the release candidate, signs off.
3. DevOps tags the commit (`v*.*.*`), triggering the release pipeline.
4. Pipeline deploys Firebase backend, builds signed apps, uploads to stores.
5. QA runs production smoke tests after deployment.
6. PM publishes release notes.
