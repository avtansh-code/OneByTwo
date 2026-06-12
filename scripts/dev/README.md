# Developer Scripts

Scripts in `scripts/dev/` automate common local development tasks. They are
POSIX-compatible (`#!/bin/sh`) unless otherwise noted and should be run from the
repository root.

---

## Emulator Wrapper — `start-emulators.sh`

**Always use `scripts/dev/start-emulators.sh`, never raw
`firebase emulators:start`.**

### Rationale

Invariant #4 mandates a single Firebase project with no staging or development
projects. The Flutter app's Firebase configuration references the production
project ID (`onebytwo-avtanshgupta`), so the Emulator Suite must be started with
that same project ID for the Emulator UI to display Firestore documents
correctly. During Sprint 1 testing we discovered that omitting `--project` (or
using a mismatched ID) causes the Emulator UI to show an empty database even
though documents exist. The wrapper script reads the project ID from `.firebaserc`
via `jq` and enforces this constraint automatically, removing a class of
"works on my machine" issues.

### What it does

1. Reads the project ID from `.firebaserc` (`.projects.default`) via `jq`.
2. Rejects a `demo-*` ID found in `.firebaserc` (Invariant #4 expects the
   production ID there). To run fully-offline emulators against a demo project,
   pass `--project demo-*` explicitly and the script prints a warning instead of
   failing.
3. Auto-imports `firebase-export/` when that directory exists (override with
   `--import=<path>`).
4. Builds Cloud Functions (`cd functions && npm run build`) before launch so the
   Functions emulator loads the compiled trigger bundle from `functions/lib/`.
5. Starts the `auth,firestore,functions,storage` emulators. The Emulator UI is
   enabled in `firebase.json` and comes up alongside them.

### Emulator ports (from `firebase.json`)

| Emulator | Port |
|---|---|
| Auth | 9099 |
| Firestore | 8181 |
| Functions | 5001 |
| Storage | 9199 |
| Emulator UI | 4000 |

`singleProjectMode` is `true`, and the Cloud Functions runtime is `nodejs22`.

### Usage

```sh
# Basic start (project ID read from .firebaserc, seed data auto-imported if
# firebase-export/ directory exists)
./scripts/dev/start-emulators.sh

# With an explicit import path
./scripts/dev/start-emulators.sh --import=./my-seed-data

# With an explicit demo-* project override (prints a warning)
./scripts/dev/start-emulators.sh --project demo-onebytwo

# Forward additional flags to firebase emulators:start
./scripts/dev/start-emulators.sh --export-on-exit=./firebase-export
```

### Dependencies

- **jq** — required for reading `.firebaserc`. Install via
  `brew install jq` (macOS) or `apt-get install jq` (Linux).
- **Firebase CLI** — `npm install -g firebase-tools`.
- **Node.js 22** — matches the Cloud Functions runtime (`nodejs22` in
  `firebase.json`); used to build and run functions under the emulator.

---

## Seed Script — `seed-emulator.ts`

Placeholder script for populating the Firebase Emulator Suite with test data
during local development. Currently empty; seed functions will be added alongside
the first feature PR (FR-AU-01).

```sh
npx ts-node scripts/dev/seed-emulator.ts
```
