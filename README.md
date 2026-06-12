# One By Two

> Split it. Settle it. Simple.

One By Two is an India-focused expense-sharing mobile application for iOS and Android,
built with Flutter and backed by Google Firebase. It helps friends, flatmates,
families, and groups track shared expenses and settle balances using Simplified
Debts as the sole debt mechanism.

## Key Facts

| | |
|---|---|
| **Platform** | iOS and Android (Flutter 3.44.2, `stable` channel via fvm) |
| **Backend** | Google Firebase (single production project, `onebytwo-avtanshgupta`) |
| **Target market** | India (INR only, +91 phone numbers) |
| **State management** | Riverpod 2.x |
| **Cloud Functions** | Node 22, TypeScript, region `asia-south1` |
| **CI/CD** | GitHub Actions |

## Invariants

These constraints are non-negotiable across the entire codebase:

1. **Money is integer paise** — all amounts stored as `int` (1 INR = 100 paise).
2. **`simplifiedBalances` is server-only** — written by Cloud Functions, read-only
   for clients.
3. **System share sheet only** — no platform-specific share targets.
4. **Single Firebase project** — Emulator Suite for all non-production testing.

## Repository Structure

```
lib/                     Flutter application code (feature-first layout)
  app/                   App-level wiring (theme)
  core/                  Shared building blocks (formatters, connectivity,
                         routing, services, telemetry, widgets)
  features/              One folder per feature, each with application/, data/,
                         domain/, presentation/ and a README.md:
                           activity, auth, expenses, friends, notifications,
                           profile, reminders, settlements, shell
                         (groups exists server-side only — see below)
functions/               Cloud Functions (TypeScript, Node 22)
ios/, android/           Platform shells
docs/                    SRS and project documentation
.github/
  agents/                AI agent definitions
  skills/                Reusable skill procedures
  hooks/                 Lifecycle hook scripts
  shared/                Cross-cutting context (invariants, glossary, ADRs)
  workflows/             CI/CD pipelines
  ISSUE_TEMPLATE/        Bug report, feature request, user story templates
  PULL_REQUEST_TEMPLATE.md
  CODEOWNERS
  copilot-instructions.md
lefthook.yml             Local git hooks
```

> **Groups:** the Firestore `groups` collection schema and security rules exist
> server-side, but there is no Flutter client feature for groups yet.
> `lib/features/groups/` contains documentation only — see its README.

## Getting Started

### Prerequisites

- [fvm](https://fvm.app/) (Flutter Version Management) — the repo pins Flutter
  3.44.2 on the `stable` channel via `.fvmrc`; run `fvm install` to fetch it
- Node.js 22 (matches the Cloud Functions runtime)
- Firebase CLI (`npm install -g firebase-tools`)
- Lefthook (`brew install lefthook` or `npm install -g lefthook`)

### Local Development

```sh
# Install Flutter dependencies (fvm-pinned SDK)
fvm flutter pub get

# Install Cloud Functions dependencies
cd functions && npm ci && cd ..

# Start Firebase Emulator Suite (reads project ID from .firebaserc)
./scripts/dev/start-emulators.sh

# Run the app (pointing to emulators in debug mode)
fvm flutter run

# Install git hooks
lefthook install
```

> **Note:** The wrapper reads the project ID from `.firebaserc` and enforces
> Invariant #4 (single Firebase project). See `scripts/dev/README.md` for details.

### Running Tests

```sh
# Flutter unit and widget tests
fvm flutter test

# Cloud Functions tests
cd functions && npm test

# Integration tests against emulators (tests live under test/integration/)
firebase emulators:exec --only auth,firestore,functions,storage \
  "fvm flutter test test/integration/"
```

## Documentation

- **SRS:** [`docs/OneByTwo_Requirements_Spec.md`](docs/OneByTwo_Requirements_Spec.md)
- **Agents:** [`.github/agents/README.md`](.github/agents/README.md)
- **Skills:** [`.github/skills/README.md`](.github/skills/README.md)
- **Hooks:** [`.github/hooks/README.md`](.github/hooks/README.md)
- **Invariants:** [`.github/shared/invariants.md`](.github/shared/invariants.md)
- **ADRs:** [`.github/shared/decision-log.md`](.github/shared/decision-log.md)
- **Coding Standards:** [`.github/shared/coding-standards.md`](.github/shared/coding-standards.md)
- **Test Strategy:** [`.github/shared/test-strategy.md`](.github/shared/test-strategy.md)

## Contributing

1. Create a feature branch: `feat/<scope>` or `fix/<scope>`.
2. Follow [Conventional Commits](https://www.conventionalcommits.org/) for all
   commit messages.
3. Open a pull request against `main` — the PR template will guide you through
   the invariant and testing checklist.
4. All merges require passing CI and at least one approving review.

## Licence

See [LICENSE](LICENSE).