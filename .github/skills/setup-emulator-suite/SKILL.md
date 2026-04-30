---
name: setup-emulator-suite
description: >
  Use when the Firebase Emulator Suite needs to be configured for local
  development or CI, including Auth, Firestore, Functions, and Storage emulators.
---

# Setup Emulator Suite

## When to use

When the Firebase Emulator Suite needs initial configuration, when a new emulator
needs to be added, or when CI needs emulator setup for integration tests.

## When NOT to use

- When the emulators are already configured and the task is about writing tests
  (use `write-integration-test` instead).
- When the task is about the production Firebase project (route to DevOps for
  deployment).

## Inputs

1. **Emulators required** — which emulators to enable (Auth, Firestore, Functions,
   Storage).
2. **Context** — local development, CI pipeline, or both.
3. **Port configuration** — desired ports (or use defaults).

## Procedure

1. Read SRS section 8.1 (Local Development Stack) and section 9.1 (Environment
   Reality: single production project, emulators for everything else).
2. Read `.github/shared/invariants.md` (especially invariant 4: single Firebase
   project).
3. Configure `firebase.json` with the emulator block:
   ```json
   {
     "emulators": {
       "auth": { "port": 9099 },
       "firestore": { "port": 8080 },
       "functions": { "port": 5001 },
       "storage": { "port": 9199 },
       "ui": { "enabled": true, "port": 4000 }
     }
   }
   ```
4. Ensure the Flutter app has a debug-mode flag that points Firebase SDKs to
   emulator hosts:
   - iOS Simulator: `localhost`
   - Android Emulator: `10.0.2.2`
5. For CI, add a step that installs the Firebase CLI, runs
   `firebase emulators:exec --only auth,firestore,functions,storage "<test command>"`,
   and tears down automatically.
6. Verify that no production project credentials are needed for emulator-only runs.
7. Add seed data scripts if needed under `functions/src/__tests__/seed/`.

## Output format

Updated `firebase.json` emulator configuration and, if for CI, the relevant
workflow step YAML.

## Validation checks

- [ ] All required emulators are enabled.
- [ ] Ports do not conflict with common development services.
- [ ] Flutter debug-mode emulator host configuration is documented.
- [ ] CI step uses `firebase emulators:exec` (not long-running `emulators:start`).
- [ ] No production credentials are required for emulator runs.
- [ ] No second Firebase project ID is introduced (invariant 4).

## Examples

### Positive example

**Input:** "Set up emulators for local development with Auth, Firestore, and
Functions."

**Output:** Updated `firebase.json` with emulator ports, added a
`scripts/start-emulators.sh` convenience script, documented the Flutter
`useEmulator()` calls for debug mode.

### Negative example (should refuse)

**Input:** "Set up a staging Firebase project for pre-production testing."

**Response:** Refused. SRS section 9.1 states there is exactly one Firebase project
(production). All non-production testing uses the Firebase Emulator Suite. This
violates invariant 4.
