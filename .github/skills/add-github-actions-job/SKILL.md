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
4. Add the job following these conventions:
   a. **Runner:** `ubuntu-latest` unless iOS build requires `macos-latest`.
   b. **Checkout:** always use `actions/checkout@v4`.
   c. **Tool setup:** use official actions (`actions/setup-node@v4`,
      `subosito/flutter-action@v2`).
   d. **Caching:** cache `pub` and `npm` dependencies.
   e. **Secrets:** reference by name only (`${{ secrets.SECRET_NAME }}`). Never
      hardcode values.
   f. **Environment:** for production deployments, use GitHub Environments with
      manual approval (`production-firebase`, `production-ios`,
      `production-android`).
   g. **Artifacts:** upload coverage reports and build outputs as workflow
      artifacts.
   h. **TODO markers:** use `# TODO(devops):` for steps that require secrets or
      signing configuration not yet available.
5. Ensure the job does not introduce a second Firebase project (invariant 4).
6. Ensure coverage thresholds are enforced per `.github/shared/test-strategy.md`.

## Output format

YAML job block ready to be inserted into the target workflow file.

## Validation checks

- [ ] Job uses `actions/checkout@v4`.
- [ ] Secrets are referenced by name, not hardcoded.
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
          node-version: '20'
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
