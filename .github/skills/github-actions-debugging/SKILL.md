---
name: github-actions-debugging
description: "Step-by-step process for diagnosing and fixing CI/CD pipeline failures in GitHub Actions workflows for Flutter and Firebase projects."
---

# GitHub Actions Debugging

## Diagnostic Workflow

Follow these steps in order when a CI/CD pipeline fails.

### Step 1: List Recent Failed Workflow Runs

Use the `list_workflow_runs` MCP tool with `status=failure` to get recent failures:

```text
method: list_workflow_runs
owner: <repo-owner>
repo: OneByTwo
workflow_runs_filter: { status: "completed" }
```

Identify the most recent failed run and note its `run_id`.

### Step 2: Get Failed Job Details

Use `list_workflow_jobs` for the failed run:

```text
method: list_workflow_jobs
owner: <repo-owner>
repo: OneByTwo
resource_id: <run_id>
```

Note the `job_id` of each failed job and its `name` (e.g., `analyze`, `test`, `build-android`).

### Step 3: Fetch Job Logs

Use `get_job_logs` with `return_content=true` and `tail_lines=200`:

```text
owner: <repo-owner>
repo: OneByTwo
job_id: <job_id>
return_content: true
tail_lines: 200
```

### Step 4: Identify Error Pattern

Scan the logs for known error patterns (see Failure Categories below). Search for:

- `Error:` or `error:` lines
- `FAILED` or `FAILURE` markers
- Exit codes ≠ 0
- Stack traces

### Step 5: Map to Failure Category and Apply Fix

Match the error pattern to a category below and apply the corresponding fix.

---

## Failure Categories & Fixes

| Category | Error Pattern | Common Fix |
|----------|--------------|-----------|
| Flutter analyze | `info •` / `warning •` / `error •` | Fix lint issues, update `analysis_options.yaml` |
| Dart format | `Formatting changed` / `Incorrectly formatted` | Run `dart format .` locally and commit |
| Test failures | `Expected: ... Actual: ...` / `Test failed` | Fix assertion, update mock data, check test logic |
| Build (Android) | `Gradle build failed` / `Could not resolve` | Check `minSdk`, `compileSdk`, dependency versions in `android/app/build.gradle` |
| Build (iOS) | `Signing/provisioning` / `Code Sign error` | Check certificates, provisioning profiles, Xcode version |
| Firebase deploy | `Error: Functions deploy` / `Build failed` | Check TypeScript compilation, regions, Node version |
| Coverage | `Coverage below threshold` | Write more tests for uncovered paths |
| Security scan | `Vulnerability found` / `CRITICAL` | Update dependency version, run `npm audit fix` or `dart pub upgrade` |

---

## Local Reproduction Commands

Always reproduce CI failures locally before pushing a fix:

```bash
# Static analysis (mirrors CI analyze step)
flutter analyze --fatal-infos

# Format check (mirrors CI format step)
dart format --set-exit-if-changed .

# Run all tests with coverage (mirrors CI test step)
flutter test --coverage

# Android release build (mirrors CI build step)
flutter build apk --release

# iOS release build
flutter build ios --release --no-codesign

# Cloud Functions lint + build + test
cd functions && npm run lint && npm run build && npm test
```

---

## Common CI Environment Issues

### Java Version Mismatch

Gradle 8.x requires JDK 17. If CI uses JDK 11, builds fail.

**Fix:** Ensure the workflow sets up JDK 17:

```yaml
- uses: actions/setup-java@v4
  with:
    distribution: 'temurin'
    java-version: '17'
```

### Flutter Version Not Pinned

Using `channel: stable` without a version can break builds when Flutter releases a new version.

**Fix:** Pin the Flutter version in the workflow:

```yaml
- uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.24.x'
    channel: 'stable'
    cache: true
```

### Node Version for Cloud Functions

Firebase Cloud Functions require Node 18+. Using an older version causes runtime errors.

**Fix:** Pin Node version:

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'
    cache-dependency-path: functions/package-lock.json
```

### Cache Invalidation

Stale caches cause mysterious failures. Common caches to watch:

| Cache | Invalidation Trigger | Action |
|-------|---------------------|--------|
| Pub cache | `pubspec.lock` changes | Key on `pubspec.lock` hash |
| Gradle cache | `build.gradle` changes | Key on `build.gradle` + `gradle-wrapper.properties` hash |
| npm cache | `package-lock.json` changes | Key on `package-lock.json` hash |
| CocoaPods | `Podfile.lock` changes | Key on `Podfile.lock` hash |

**Fix:** If a cache-related issue is suspected, re-run the workflow with caches disabled or add a cache-busting key:

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.pub-cache
    key: pub-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}-v2  # bump suffix to bust cache
```

---

## Workflow Debugging Checklist

- [ ] Identified the failed workflow run ID
- [ ] Retrieved job logs for each failed job
- [ ] Matched error pattern to failure category
- [ ] Reproduced failure locally
- [ ] Applied fix and verified locally
- [ ] Pushed fix and confirmed CI passes
