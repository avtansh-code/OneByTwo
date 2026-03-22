---
name: pipeline-analysis
description: "CI/CD pipeline health analysis — reading workflow logs, diagnosing flaky tests, build time optimization, caching strategies, failure triage, and pipeline metrics for the One By Two project."
---

# Pipeline Analysis Skill

Proactive CI/CD pipeline health analysis for the **One By Two** Flutter + Firebase app. While the `github-actions-debugging` skill focuses on fixing individual failures, this skill covers pipeline-wide health, optimization, and metrics.

---

## 1. Pipeline Architecture Overview

The project uses three CI/CD pipelines, each serving a different stage of the development lifecycle:

```text
PR Pipeline (ci-pr.yml) ─── 7 jobs ─── Required for merge
    ├── analyze-and-format      Static analysis + dart format check
    ├── test-and-coverage        Unit/widget tests + coverage threshold
    ├── security-scan            Dependency vulnerability scanning
    ├── architecture-compliance  Layer dependency rules enforcement
    ├── cloud-functions-check    Lint, build, and test Cloud Functions
    ├── firestore-rules-test     Security rules unit tests
    └── build-check              Android & iOS debug builds (matrix)

Nightly Pipeline (ci-nightly.yml) ─── 5 jobs ─── Scheduled 02:00 UTC
    ├── integration-tests        Full integration test suite
    ├── performance-benchmarks   Frame timing, startup time, memory
    ├── dependency-audit         Outdated/vulnerable dependency report
    ├── code-quality-metrics     Cyclomatic complexity, tech debt score
    └── security-deep-scan       SAST/DAST deep security analysis

Release Pipeline (ci-release.yml) ─── 5 jobs ─── On version tag (v*)
    ├── full-quality-gate        All PR checks + integration tests
    ├── build-release-artifacts  Signed APK/AAB + IPA
    ├── deploy-backend           Cloud Functions + Firestore rules deploy
    ├── deploy-mobile            Firebase App Distribution / Store upload
    └── post-release-verify      Smoke tests against production
```

### Pipeline Relationships

- **PR Pipeline** is the gatekeeper — all 7 jobs must pass before merge.
- **Nightly Pipeline** catches regressions that the faster PR pipeline skips (integration tests, benchmarks).
- **Release Pipeline** runs the full gauntlet and deploys. It is triggered by `v*` tags (e.g., `v1.2.0`).
- A nightly failure should be triaged within 24 hours. A release failure blocks the release.

---

## 2. Reading Workflow Logs

Use the GitHub MCP tools to systematically investigate pipeline runs.

### Step-by-Step Log Investigation

```text
1. LIST RECENT RUNS — Find the workflow run in question
   ─────────────────────────────────────────────────
   list_workflow_runs(
     owner: "owner",
     repo: "OneByTwo",
     resource_id: "ci-pr.yml",
     workflow_runs_filter: { status: "completed" }
   )
   → Note the run_id of the failed run.

2. LIST JOBS IN THE RUN — See which jobs failed
   ─────────────────────────────────────────────
   list_workflow_jobs(
     owner: "owner",
     repo: "OneByTwo",
     resource_id: "<run_id>"
   )
   → Look for jobs with conclusion: "failure". Note their job_id.

3. GET JOB LOGS — Read the actual failure output
   ─────────────────────────────────────────────
   get_job_logs(
     owner: "owner",
     repo: "OneByTwo",
     job_id: <job_id>,
     return_content: true,
     tail_lines: 300
   )
   → 300 lines is usually enough. Increase to 500 for verbose builds.

4. PARSE THE LOG OUTPUT
   ─────────────────────
   - Search for: "Error:", "FAILED", "✗", "exit code 1", "EXCEPTION"
   - Identify the FIRST failure (ignore cascading failures downstream)
   - Check timestamps between steps for timeout detection
   - Look for "##[error]" annotations (GitHub Actions native errors)
   - Compare with the last successful run if the failure is ambiguous
```

### Quick One-Liner Patterns

```text
# Get logs for all failed jobs in a run at once
get_job_logs(owner, repo, run_id: <run_id>, failed_only: true, return_content: true)

# Check the overall run status and timing
get_workflow_run(owner, repo, resource_id: "<run_id>")

# Get usage/billing info for a run
get_workflow_run_usage(owner, repo, resource_id: "<run_id>")
```

### What to Look For in Logs

| Pattern in Log | Likely Cause |
|---|---|
| `error: Target of URI doesn't exist` | Missing import or generated file |
| `The following assertion was thrown` | Widget test failure |
| `Expected: <X>` / `Actual: <Y>` | Unit test assertion failure |
| `Could not resolve all files for configuration` | Gradle dependency issue |
| `line XX col YY • ...` | Dart analysis warning/error |
| `Function failed on loading user code` | Cloud Functions compilation error |
| `Error: Process completed with exit code 137` | OOM kill (out of memory) |
| `Error: The operation was canceled` | Timeout exceeded |

---

## 3. Failure Triage Workflow

When a pipeline fails, follow this structured triage process:

### STEP 1: CLASSIFY the Failure

```text
Failure Type            │ Category          │ Typical Fix
────────────────────────┼───────────────────┼──────────────────────────────
Compilation error       │ Code bug          │ Dev fix: missing import, type error
Lint/format error       │ Style issue       │ Quick fix: run dart format, fix lint
Test failure            │ Logic bug         │ Fix code or update test expectation
Coverage drop           │ Missing tests     │ Write tests for new/changed code
Security alert          │ Vulnerability     │ Update dependency or apply patch
Build size exceeded     │ Asset/dep bloat   │ Audit assets, tree-shake, split
Timeout                 │ Flaky/slow op     │ Investigate flaky test or optimize
Infra failure           │ CI environment    │ Retry the run
Rules test failure      │ Firestore config  │ Fix security rules logic
Functions build error   │ Backend code      │ Fix TypeScript/Node.js error
```

### STEP 2: DETERMINE Urgency

```text
Context                        │ Urgency           │ Action
───────────────────────────────┼───────────────────┼────────────────────────
Blocks PR merge                │ Fix immediately   │ Author fixes before review
Nightly failure                │ Fix within 24 hrs │ Create issue, assign owner
Flaky (intermittent)           │ Track, fix in sprint │ Log occurrences, batch fix
Infra / transient              │ Retry, ignore if passes │ Re-run workflow
Release pipeline failure       │ Fix immediately   │ Hotfix branch if needed
```

### STEP 3: ASSIGN to the Right Agent

```text
Failure Category         │ Recommended Agent           │ Why
─────────────────────────┼─────────────────────────────┼──────────────────────────
Code / test bug          │ bug-fixer agent             │ Understands app logic
CI config issue          │ ci-debugger agent           │ Knows workflow YAML
Coverage gap             │ test-writer agent           │ Generates targeted tests
Security alert           │ firebase-backend agent      │ Manages dependencies
Performance regression   │ performance-optimizer agent │ Knows benchmarks/profiling
Firestore rules failure  │ firebase-backend agent      │ Owns rules logic
Cloud Functions error    │ firebase-backend agent      │ Owns backend code
Architecture violation   │ architecture-compliance     │ Enforces layer rules
```

---

## 4. Flaky Test Detection & Resolution

### How to Identify Flaky Tests

A test is **flaky** if it produces different results across runs without any code change. Common signals:

- Same test passes on retry without code changes
- Test fails on CI but passes locally (or vice versa)
- Test depends on timing, network, or execution order
- Test uses `DateTime.now()` instead of a mocked clock
- Test uses `Future.delayed` for synchronization instead of proper awaiting
- Test creates shared state (static variables, singletons) without cleanup

### Detection via CI Logs

```bash
# Compare two runs of the same commit — if results differ, flakiness is present
# In GitHub: filter workflow runs by head_sha, compare job outcomes

# Using MCP tools:
# 1. Find runs for the same commit
list_workflow_runs(owner, repo, workflow_runs_filter: { status: "completed" })
# 2. Filter by head_sha in results
# 3. Compare: same commit, different outcomes = flaky
```

### Resolution Checklist

- [ ] **Isolate:** Run the suspected flaky test 50 times in a loop:

  ```bash
  for i in {1..50}; do
    echo "Run $i"
    flutter test test/path/to_suspected_test.dart --reporter compact || echo "FAILED on run $i"
  done
  ```

- [ ] **Identify root cause** — common culprits:
  - **Timing:** Test assumes operation completes in N ms
  - **State leakage:** Previous test leaves global state dirty
  - **Async race condition:** Missing `await`, `pumpAndSettle` not enough
  - **Order dependence:** Test only fails when run after another test
  - **Platform dependence:** Different behavior on macOS vs Linux CI runner

- [ ] **Fix** — apply the right pattern:
  - Use `fakeAsync` and `FakeTimer` instead of real time
  - Ensure every `setUp` has a corresponding `tearDown` that resets state
  - `await tester.pumpAndSettle()` after every async interaction
  - Use `addTearDown()` for cleanup that must happen even on failure
  - Avoid `sleep()` or `Future.delayed()` — use stream-based waiting

- [ ] **Verify:** Run the fix 50 times, confirm **100% pass rate**:

  ```bash
  FAIL=0
  for i in {1..50}; do
    flutter test test/path/to_suspected_test.dart --reporter compact || FAIL=$((FAIL+1))
  done
  echo "Failed $FAIL out of 50 runs"
  # Must be: Failed 0 out of 50 runs
  ```

- [ ] **Monitor:** Add to nightly pipeline watchlist. Track for 1 week before closing the flaky issue.

---

## 5. Build Time Optimization

### Strategies to Keep CI Fast

#### 1. Caching (Biggest Impact)

Cache all dependency and build artifact directories. See Section 7 below for complete YAML snippets.

#### 2. Parallelism

Independent jobs should run in parallel. In the PR pipeline:

```text
┌─────────────────────┐  ┌──────────────┐  ┌──────────────────────┐
│ analyze-and-format  │  │ security-scan│  │ cloud-functions-check│
└─────────┬───────────┘  └──────┬───────┘  └──────────┬───────────┘
          │                     │                      │
          ▼                     ▼                      ▼
┌─────────────────────┐  ┌──────────────────────────┐  ┌──────────────────┐
│ test-and-coverage   │  │ architecture-compliance   │  │ firestore-rules  │
└─────────┬───────────┘  └──────────────────────────┘  └──────────────────┘
          │
          ▼
   ┌─────────────┐
   │ build-check │
   └─────────────┘
```

Jobs without arrows between them run simultaneously.

#### 3. Conditional Runs (Path Filters)

Skip irrelevant jobs when only certain files change:

```yaml
# Skip iOS build if only Cloud Functions changed
on:
  pull_request:
    paths:
      - 'lib/**'
      - 'test/**'
      - 'pubspec.*'
      - 'android/**'
      - 'ios/**'

# Separate workflow for functions-only changes
on:
  pull_request:
    paths:
      - 'functions/**'
```

#### 4. Fail Fast with Job Dependencies

Don't waste CI minutes building if analysis fails:

```yaml
jobs:
  analyze-and-format:
    # runs first, no dependencies

  test-and-coverage:
    needs: [analyze-and-format]
    # only runs if analysis passes

  build-check:
    needs: [analyze-and-format, test-and-coverage]
    # only runs if both pass
```

#### 5. Incremental Build Techniques

- Use `--fatal-infos` with `dart analyze` to fail early on the first issue
- Run only changed test files when possible: `flutter test <changed_files>`
- Use Gradle build cache for Android incremental compilation

### Benchmark Targets

| Job | Target Duration | Notes |
|-----|----------------|-------|
| analyze-and-format | < 2 min | Dart analyze + format check |
| test-and-coverage | < 5 min | All unit/widget tests + lcov |
| security-scan | < 1 min | Dependency vulnerability scan |
| architecture-compliance | < 1 min | Layer rule check (fast) |
| cloud-functions-check | < 3 min | npm install + lint + build + test |
| firestore-rules-test | < 2 min | Emulator start + rules tests |
| build-check (Android) | < 8 min | Debug APK (with Gradle cache) |
| build-check (iOS) | < 10 min | Debug build (with CocoaPods cache) |
| **Total PR pipeline** | **< 15 min** | **All jobs in parallel** |

> **Alert threshold:** If any job exceeds 2× its target, investigate immediately. If the total pipeline exceeds 20 min, it's a blocker.

---

## 6. Pipeline Metrics to Track

### Key Metrics

| Metric | What It Measures | Healthy Target |
|--------|-----------------|----------------|
| **Mean Time to Green** | Avg time from PR open → all checks pass | < 20 min |
| **Failure Rate per Job** | % of runs that fail per job | < 5% per job |
| **Flaky Test Rate** | Tests that flip without code changes | < 1% of test suite |
| **Build Time Trend** | Is the pipeline getting slower over time? | Flat or decreasing |
| **Coverage Trend** | Is code coverage going up or down? | ≥ 80%, trending up |
| **Retry Rate** | How often do developers re-run workflows? | < 10% of runs |
| **Queue Wait Time** | Time spent waiting for a runner | < 2 min |

### How to Gather These Metrics

```text
# Mean Time to Green
Compare workflow run created_at vs updated_at (when it completed successfully).
Filter to runs with conclusion: "success" on the first attempt.

# Failure Rate per Job
For each job type, count failures vs total runs over the past 30 days:
  list_workflow_runs(owner, repo, resource_id: "ci-pr.yml", per_page: 100)
  For each run: list_workflow_jobs → count by name + conclusion

# Flaky Test Rate
Identify tests that fail then pass on re-run of the same commit.
Track via nightly pipeline — if nightly has different results on same code = flaky.

# Build Time Trend
Pull run duration weekly. Plot over time. Investigate any >10% increase.
  get_workflow_run_usage(owner, repo, resource_id: "<run_id>")

# Coverage Trend
Extract coverage % from test-and-coverage job logs over time.
  grep for "Coverage:" or lcov summary lines in job logs.
```

### Red Flags to Watch For

- 🔴 A job that fails >10% of the time → likely flaky or brittle
- 🔴 Build time increasing >30s per week → dependency or test bloat
- 🔴 Coverage dropping on consecutive PRs → enforcement gap
- 🔴 Same test failing across multiple unrelated PRs → infrastructure issue
- 🟡 Retry rate climbing → developer frustration, lost productivity

---

## 7. Caching Strategy YAML

### Flutter Pub Cache

```yaml
- name: Cache pub dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.pub-cache
      .dart_tool/
    key: pub-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}
    restore-keys: |
      pub-${{ runner.os }}-
```

### Gradle Cache (Android Build)

```yaml
- name: Cache Gradle dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
      android/.gradle
    key: gradle-${{ runner.os }}-${{ hashFiles('android/build.gradle', 'android/app/build.gradle', 'android/gradle/wrapper/gradle-wrapper.properties') }}
    restore-keys: |
      gradle-${{ runner.os }}-
```

### CocoaPods Cache (iOS Build)

```yaml
- name: Cache CocoaPods
  uses: actions/cache@v4
  with:
    path: |
      ios/Pods
      ~/Library/Caches/CocoaPods
    key: pods-${{ runner.os }}-${{ hashFiles('ios/Podfile.lock') }}
    restore-keys: |
      pods-${{ runner.os }}-
```

### npm Cache (Cloud Functions)

```yaml
- name: Cache npm dependencies
  uses: actions/cache@v4
  with:
    path: |
      functions/node_modules
      ~/.npm
    key: npm-${{ runner.os }}-${{ hashFiles('functions/package-lock.json') }}
    restore-keys: |
      npm-${{ runner.os }}-
```

### build_runner Output Cache

```yaml
- name: Cache build_runner output
  uses: actions/cache@v4
  with:
    path: |
      .dart_tool/build
      lib/**/*.g.dart
      lib/**/*.freezed.dart
    key: build-runner-${{ runner.os }}-${{ hashFiles('pubspec.lock', 'build.yaml') }}
    restore-keys: |
      build-runner-${{ runner.os }}-
```

### Cache Invalidation Notes

- **pub cache** is keyed on `pubspec.lock` — invalidates when any dependency changes.
- **Gradle cache** is keyed on build files — invalidates when build config or wrapper changes.
- **CocoaPods** is keyed on `Podfile.lock` — invalidates when iOS deps change.
- **npm cache** is keyed on `package-lock.json` — invalidates when functions deps change.
- **build_runner** is keyed on `pubspec.lock` + `build.yaml` — invalidates when code generation config changes.
- All caches use `restore-keys` fallback to get a partial cache hit when the exact key misses.
- GitHub Actions caches expire after 7 days of no access. High-traffic repos rarely hit this limit.

---

## Cross-References

- **Fixing a specific CI failure?** → See [`github-actions-debugging`](../github-actions-debugging/SKILL.md) skill
- **Writing tests to fix coverage drops?** → See [`testing-strategy`](../testing-strategy/SKILL.md) skill
- **Investigating a Firebase backend failure?** → See the `firebase-backend` agent (`.github/agents/firebase-backend.agent.md`)
- **Performance regression in benchmarks?** → See performance optimization patterns in project docs
