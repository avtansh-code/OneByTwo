---
name: add-github-actions-job
description: >
  Use when a new job needs to be added to an existing GitHub Actions workflow, or
  an existing job needs modification.
---

# Add GitHub Actions Job

## When to use

When a new CI/CD job needs to be added to `.github/workflows/pr.yml` or
`release.yml`, or an existing job needs modification (e.g., adding a test step,
updating a tool version, adding an artifact upload).

## When NOT to use

- When the task is about local git hooks (modify `lefthook.yml` directly).
- When the task is about Firebase Emulator setup only (use `setup-emulator-suite`).

## Inputs

1. **Workflow file** — which workflow to modify (`pr.yml` or `release.yml`).
2. **Job purpose** — what the job should do.
3. **Dependencies** — which other jobs this job depends on (`needs:`).
4. **Secrets required** — which GitHub secrets the job needs (reference SRS
   section 9.3).

## Procedure

1. Read SRS section 9.2 (pipeline design) and section 9.4 (production safety
   controls).
2. Read `.github/shared/invariants.md`.
3. Read the existing workflow file.
4. Add the job following these conventions (match the existing jobs in
   `pr.yml`/`release.yml`):
   a. **Job naming:** a kebab-case job key (e.g. `flutter-checks`) plus a
      human-readable `name:` (e.g. `Flutter Lint & Test`).
   b. **Runner:** `ubuntu-latest` unless an iOS build is required, then `macos-15`.
   c. **Checkout:** always use `actions/checkout@v4`.
   d. **Tool setup:** use the same actions and versions as the existing jobs:
      - `subosito/flutter-action@v2` with `channel: stable` and `cache: true`
        (Flutter is pinned to the `stable` channel via fvm — currently 3.44.2).
      - `actions/setup-node@v4` with `node-version: '22'` (matches the Cloud
        Functions `nodejs22` runtime).
      - `actions/setup-java@v4` with `distribution: temurin` — `java-version: '17'`
        for Android builds, `'21'` for the emulator integration job.
   e. **Caching:** rely on `flutter-action`'s `cache: true` for the pub cache and
      `setup-node`'s `cache: 'npm'` with
      `cache-dependency-path: functions/package-lock.json`.
   f. **Secrets:** reference by name only (`${{ secrets.SECRET_NAME }}`). Never
      hardcode values. Restore base64 Firebase config secrets with `base64 -d` on
      Ubuntu runners and `base64 -D` on macOS runners (e.g.
      `GOOGLE_SERVICES_JSON_BASE64`, `GOOGLE_SERVICE_INFO_PLIST_BASE64`).
   g. **Firebase CLI:** every `firebase` invocation must pass `--project` — use
      `--project demo-onebytwo` for emulator-only CI (`emulators:exec`) and
      `--project onebytwo-avtanshgupta` for production deploys. The
      `block-second-firebase-project` hook fails the edit otherwise.
   h. **Environment:** for production deployments, use GitHub Environments with
      manual approval (`production-firebase`, `production-ios`,
      `production-android`).
   i. **Artifacts:** upload coverage reports and build outputs with
      `actions/upload-artifact@v4`.
   j. **TODO markers:** use `# TODO(devops):` for steps that require secrets or
      signing configuration not yet available.
5. Ensure the job does not introduce a second Firebase project (invariant 4).
6. Ensure coverage thresholds are enforced per `.github/shared/test-strategy.md`.

## Output format

YAML job block ready to be inserted into the target workflow file.

## Validation checks

- [ ] Job uses `actions/checkout@v4`.
- [ ] Node is `'22'`; iOS jobs run on `macos-15`; JDK is temurin (17 for builds, 21 for the integration job).
- [ ] Secrets are referenced by name, not hardcoded.
- [ ] Every `firebase` CLI call passes `--project` (`demo-onebytwo` for emulators, `onebytwo-avtanshgupta` for deploy).
- [ ] GitHub Environments used for production deployments.
- [ ] No second Firebase project ID introduced.
- [ ] Caching is configured for dependencies.
- [ ] TODO markers reference SRS secret names where applicable.
- [ ] Job is idempotent (safe to re-run).

## Examples

### Positive example

**Input:** "Add an ESLint job for Cloud Functions to the PR workflow."

**Output:**
```yaml
  lint-functions:
    name: Lint Cloud Functions
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: functions
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: functions/package-lock.json
      - run: npm ci
      - run: npm run lint
```

### Negative example (should refuse)

**Input:** "Add a job that deploys to a staging Firebase project."

**Response:** Refused. SRS section 9.1 states there is exactly one Firebase project
(production). All non-production testing uses the Emulator Suite. This violates
invariant 4. If you need pre-merge validation, add a job that runs tests against
the Firebase Emulator Suite instead.
