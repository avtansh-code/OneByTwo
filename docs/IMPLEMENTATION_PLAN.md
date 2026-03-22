# OneByTwo — Implementation Master Plan

## Problem Statement

Build "One By Two" — an offline-first, ad-free expense splitting app for the Indian market using Flutter + Firebase. The project is greenfield (only docs exist; no code yet). Comprehensive architecture docs, database schema, algorithms, UI/UX specs, and security requirements are already defined in `/docs/`.

The implementation will be executed by an AI agent team operating in multiple roles (Architect, Dev, QA, DevOps, Lead). This plan defines the agent team, workflow, and strategy using **Option A: Vertical Slice** (selected).

---

## Code Quality Standards (Enforced at Every Sprint)

Every task, every sprint, every agent must enforce these quality gates. Code is not "done" until all gates pass.

### 1. Clean Code Principles

- **Single Responsibility:** Every class/function does one thing well
- **DRY:** No duplicated logic; extract shared utilities/mixins/extensions
- **SOLID:** Follow all five principles — especially Dependency Inversion (program to interfaces)
- **Naming:** Descriptive, consistent names following Dart conventions (`lowerCamelCase` for variables/functions, `UpperCamelCase` for types, `_privatePrefix` for private members)
- **Small Functions:** Max 30-40 lines per function; extract helper methods
- **No Magic Numbers:** All constants defined in `core/constants/`
- **No Dead Code:** Remove unused imports, variables, functions immediately
- **Immutability:** Use `final` everywhere possible; freezed entities are immutable by design

### 2. Architecture Compliance

- **Layer Isolation:** Domain layer has ZERO imports from data or presentation layers
- **Dependency Direction:** Presentation → Domain ← Data (domain never depends outward)
- **Repository Pattern:** All data access through repository interfaces defined in domain layer
- **Provider Hierarchy:** Riverpod providers follow the dependency graph (no circular deps)
- **Feature-First:** Each feature is self-contained within its folder; shared code goes to `core/`

### 3. Error Handling (Complete Coverage)

- **Result Pattern:** Every repository method returns `Result<T>` (Success or Failure)
- **AsyncValue:** Every UI state uses Riverpod's `AsyncValue<T>` (loading, data, error)
- **No Unhandled Exceptions:** Every `.when()` has `error:` handler; every `try` has `catch`
- **User-Facing Messages:** All errors display friendly messages via localization (never raw exception text)
- **Retry Logic:** Network errors show retry button; offline writes queue automatically
- **Graceful Degradation:** If a feature fails, the rest of the app continues working

### 4. Testing Requirements (Non-Negotiable)

| Layer | Coverage Target | Test Type |
|-------|----------------|-----------|
| Domain entities & algorithms | **95-100%** | Unit tests |
| Use cases | **90%+** | Unit tests (mocked repos) |
| Repositories | **80%+** | Unit tests (mocked data sources) |
| Data sources / Models | **80%+** | Unit tests |
| Widgets / Screens | **70%+** | Widget tests |
| Cloud Functions | **85%+** | Unit tests |
| Firestore Security Rules | **100% of rule paths** | Rules unit tests |
| Critical user journeys | **100%** | Integration tests |

**Testing Rules:**

- **Test-Adjacent:** Tests written in the same sprint as the feature (not deferred)
- **AAA Pattern:** Arrange → Act → Assert in every test
- **Descriptive Names:** `test('should return error when split amounts do not sum to total')`
- **Edge Cases Required:** Zero amounts, single participant, max group size, offline state, empty lists
- **Money Invariants:** Every split test verifies `sum(splits) == total` and all amounts are `int` (paise)
- **Negative Testing:** Test error paths, not just happy paths (invalid input, network failure, auth expired)
- **No Test Skipping:** `skip:` is never used; fix or remove broken tests

### 5. Code Review Checklist (Every PR)

**Critical (Auto-Reject if violated):**

- [ ] No floating-point money (`double` used for amounts)
- [ ] Split amounts sum ≠ total (off by even 1 paisa)
- [ ] Missing authentication checks in Cloud Functions
- [ ] Firestore security rule gaps (uncovered collection paths)
- [ ] Hard deletes instead of soft deletes
- [ ] Domain layer importing Flutter/Firebase packages
- [ ] Secrets, API keys, or credentials in code

**Important (Must fix before merge):**

- [ ] Missing error handling (uncaught exceptions, no error UI)
- [ ] Firestore listener not properly disposed
- [ ] Missing sync status indicator on user-created data
- [ ] Cloud Function without input validation
- [ ] Missing localization (hardcoded English strings)
- [ ] Missing Semantics for accessibility
- [ ] Unused imports or dead code

**Best Practices (Should fix):**

- [ ] Functions > 40 lines without extraction
- [ ] Missing dartdoc on public APIs
- [ ] Inconsistent naming conventions
- [ ] Missing `const` constructors where possible
- [ ] Widget rebuilds that could be optimized

### 6. Code Formatting & Linting

- **Formatter:** `dart format` with default line length (80 chars)
- **Analyzer:** `flutter analyze` must report ZERO issues (errors, warnings, or info)
- **Linting Rules:** `flutter_lints` + custom rules in `analysis_options.yaml`:
  - `prefer_const_constructors: true`
  - `prefer_final_locals: true`
  - `avoid_print: true` (use AppLogger)
  - `prefer_single_quotes: true`
  - `sort_constructors_first: true`
  - `unawaited_futures: true`
- **CI Enforcement:** `flutter analyze` and `dart format --set-exit-if-changed` run in CI; PRs fail on violations

### 7. Documentation Standards

- **Public API:** Every public class, method, and field has a dartdoc comment (`///`)
- **Complex Logic:** Inline comments explaining *why*, not *what*
- **Architecture Docs:** Updated when schema, API, or flow changes
- **CHANGELOG.md:** Updated every sprint with conventional commit summaries
- **README.md:** Project README with setup instructions, architecture overview, contribution guide

### 8. Git & Commit Standards

- **Conventional Commits:** `feat(expenses): add percentage split algorithm`
- **Atomic Commits:** One logical change per commit (not "fix everything")
- **Branch Strategy:** `feature/{sprint}-{task}` branches, merge via PR
- **No Force Push:** on main/develop branches
- **Co-authored-by:** Copilot trailer on all AI-generated commits

### 9. Performance Baselines (Validated in Sprint 8, Monitored Always)

- Cold start: < 2 seconds
- Expense save (local): < 500ms
- Balance recalculation: < 1 second (up to 50 members)
- Smooth scrolling: 60fps with 10,000+ expenses
- App size: < 30MB (release APK)
- Memory: No leaks; stable under extended use

### 10. Offline-First Quality Checks

- Every write operation works offline (queued in Firestore SDK cache)
- Every screen renders from cache when offline
- Sync status indicators shown on all user-created content
- Conflict resolution UI exists for concurrent offline edits
- Connectivity banner displayed when offline
- Manual sync trigger available

### 11. Automated CI/CD Pipelines & Quality Gates

All quality checks are **automated in GitHub Actions**. No code merges to `main` or `develop` without passing ALL gates.

#### Pipeline 1: PR Quality Gate (`ci-pr.yml`) — Runs on every Pull Request

```yaml

# Triggered on: pull_request → main, develop
# Must pass for PR to be mergeable (branch protection rule)

Jobs:
  ┌─────────────────────────────────────────────────────────────────┐
  │ Job 1: analyze-and-format (Flutter)                             │
  │  ├─ flutter pub get                                             │
  │  ├─ dart format --set-exit-if-changed .                        │ ← FAILS if unformatted code
  │  ├─ flutter analyze --fatal-infos                               │ ← FAILS on ANY lint issue (even info)
  │  ├─ dart run custom_lint (if configured)                        │ ← Custom rules (money handling, imports)
  │  └─ dart doc --validate                                         │ ← FAILS if public API missing dartdoc
  │                                                                 │
  │ Job 2: test-and-coverage (Flutter)                              │
  │  ├─ flutter test --coverage                                     │
  │  ├─ lcov-summary: Extract coverage % per folder                 │
  │  ├─ Coverage Gate:                                              │
  │  │   ├─ lib/domain/  ≥ 95% → FAIL if below                     │
  │  │   ├─ lib/domain/usecases/ ≥ 90% → FAIL if below             │
  │  │   ├─ lib/data/ ≥ 80% → FAIL if below                        │
  │  │   └─ Overall ≥ 80% → FAIL if below                          │
  │  ├─ Post coverage report as PR comment (delta vs main)          │
  │  └─ FAIL if coverage decreased vs main branch                   │
  │                                                                 │
  │ Job 3: security-scan (Flutter)                                  │
  │  ├─ dart pub audit → FAIL on known vulnerabilities              │ ← Dependency vulnerability scan
  │  ├─ Secret scan (gitleaks/trufflehog)                           │ ← FAIL if secrets found in code
  │  ├─ Check: no http:// URLs (only https://)                      │
  │  ├─ Check: no print() calls (must use AppLogger)                │
  │  └─ Check: no double used for money (grep pattern scan)         │ ← Custom regex: amount/paise/rupee with double
  │                                                                 │
  │ Job 4: architecture-compliance (Flutter)                        │
  │  ├─ Layer dependency check:                                     │
  │  │   ├─ Scan lib/domain/ → FAIL if imports from data/present.  │
  │  │   ├─ Scan lib/data/ → FAIL if imports from presentation/    │
  │  │   └─ Verify no circular provider dependencies                │
  │  ├─ Check: all entities use freezed (@freezed annotation)       │
  │  ├─ Check: all models use json_serializable                     │
  │  └─ Check: all providers use riverpod codegen (@riverpod)       │
  │                                                                 │
  │ Job 5: cloud-functions-check (TypeScript)                       │
  │  ├─ cd functions/ && npm ci                                     │
  │  ├─ npm run lint (ESLint --max-warnings 0)                      │ ← FAIL on any lint warning
  │  ├─ npm run build (tsc --noEmit)                                │ ← Type-check
  │  ├─ npm test -- --coverage                                      │
  │  ├─ Coverage gate: ≥ 85%                                        │
  │  └─ Check: all callable functions have auth + input validation  │
  │                                                                 │
  │ Job 6: firestore-rules-test                                     │
  │  ├─ firebase emulators:exec --only firestore "npm test"         │
  │  ├─ Run @firebase/rules-unit-testing suite                      │
  │  ├─ Coverage: 100% of collection paths tested                   │
  │  └─ Both positive (allow) AND negative (deny) tests required    │
  │                                                                 │
  │ Job 7: build-check                                              │
  │  ├─ flutter build apk --release --analyze-size                  │ ← FAIL if > 30MB
  │  ├─ flutter build appbundle --release                           │
  │  ├─ flutter build ios --release --no-codesign                   │
  │  └─ Post build size as PR comment                               │
  └─────────────────────────────────────────────────────────────────┘

  ALL 7 jobs must pass. PR cannot be merged with any failure.
```

#### Pipeline 2: Nightly Quality Scan (`ci-nightly.yml`) — Runs daily at 02:00 UTC

```yaml

# Deeper checks that are too slow for every PR

Jobs:
  ┌─────────────────────────────────────────────────────────────────┐
  │ Job 1: integration-tests                                        │
  │  ├─ flutter test integration_test/ (Firebase emulator)          │
  │  ├─ Full user journey: register → group → expense → settle      │
  │  ├─ Offline scenario: add expense offline → reconnect → verify  │
  │  └─ NOTIFY on failure (Slack/email)                             │
  │                                                                 │
  │ Job 2: performance-benchmarks                                   │
  │  ├─ flutter drive --profile (performance profiling)             │
  │  ├─ Measure: cold start time                                    │
  │  ├─ Measure: scroll performance (frame times)                   │
  │  ├─ Measure: expense save latency                               │
  │  ├─ Compare with baseline stored in repo                        │
  │  └─ ALERT if any metric regressed > 10%                         │
  │                                                                 │
  │ Job 3: dependency-audit                                         │
  │  ├─ dart pub outdated → report outdated deps                    │
  │  ├─ dart pub audit → scan for vulnerabilities                   │
  │  ├─ npm audit (Cloud Functions)                                 │
  │  └─ Create issue if critical vulnerabilities found              │
  │                                                                 │
  │ Job 4: code-quality-metrics                                     │
  │  ├─ Cyclomatic complexity analysis (dart_code_metrics)          │
  │  ├─ ALERT if any function complexity > 20                       │
  │  ├─ Lines of code per file (ALERT if > 300)                     │
  │  ├─ Number of parameters per function (ALERT if > 5)            │
  │  └─ Duplicate code detection                                    │
  │                                                                 │
  │ Job 5: security-deep-scan                                       │
  │  ├─ OWASP dependency check                                      │
  │  ├─ Firestore rules completeness audit                          │
  │  ├─ Scan for PII in logs (phone, email patterns)                │
  │  ├─ Verify certificate pinning config                           │
  │  └─ Verify no debug flags in release builds                     │
  └─────────────────────────────────────────────────────────────────┘
```

#### Pipeline 3: Release Pipeline (`ci-release.yml`) — Triggered on version tag

```yaml

# Triggered on: push tag v*.*.*

Jobs:
  ┌─────────────────────────────────────────────────────────────────┐
  │ Job 1: full-quality-gate                                        │
  │  ├─ Run ALL PR quality checks (pipeline 1)                      │
  │  ├─ Run ALL nightly checks (pipeline 2)                         │
  │  └─ ALL must pass before build proceeds                         │
  │                                                                 │
  │ Job 2: build-release-artifacts                                  │
  │  ├─ flutter build appbundle --release --obfuscate               │
  │  │   --split-debug-info=build/debug-info                        │
  │  ├─ flutter build ipa --release --export-options-plist=...      │
  │  ├─ Upload debug symbols to Crashlytics                         │
  │  └─ Archive build artifacts                                     │
  │                                                                 │
  │ Job 3: deploy-backend                                           │
  │  ├─ firebase deploy --only functions (to production)             │
  │  ├─ firebase deploy --only firestore:rules                      │
  │  ├─ firebase deploy --only firestore:indexes                    │
  │  ├─ firebase deploy --only storage                              │
  │  └─ Smoke test Cloud Functions post-deploy                      │
  │                                                                 │
  │ Job 4: deploy-mobile                                            │
  │  ├─ Fastlane: Upload AAB to Google Play (internal track)        │
  │  ├─ Fastlane: Upload IPA to TestFlight                          │
  │  └─ Create GitHub Release with changelog                        │
  │                                                                 │
  │ Job 5: post-release-verify                                      │
  │  ├─ Verify Firebase Functions responding (health check)          │
  │  ├─ Verify Crashlytics receiving events                         │
  │  ├─ Verify Analytics streaming                                  │
  │  └─ Tag release as verified in GitHub                           │
  └─────────────────────────────────────────────────────────────────┘
```

#### Custom Lint Rules (Automated in CI)

The following custom checks are implemented as scripts or custom_lint rules and enforced in Pipeline 1:

```bash
MONEY SAFETY CHECKS:
  ├─ grep -r "double.*amount\|double.*paise\|double.*rupee\|double.*balance\|double.*total" lib/
  │   → FAIL if any match (money must be int)
  ├─ grep -r "\.toDouble().*amount\|\.toDouble().*paise" lib/
  │   → FAIL if converting money to double
  └─ Verify: all amount fields in freezed entities are `int` type

ARCHITECTURE CHECKS:
  ├─ grep -r "import.*package:flutter\|import.*package:cloud_firestore\|import.*package:firebase" lib/domain/
  │   → FAIL if domain imports Flutter/Firebase
  ├─ grep -r "import.*presentation/" lib/data/
  │   → FAIL if data layer imports presentation
  └─ Verify: all repository implementations are in lib/data/repositories/

SECURITY CHECKS:
  ├─ grep -rn "print(" lib/ (excluding test/)
  │   → FAIL (must use AppLogger, not print)
  ├─ grep -rn "http://" lib/ (excluding test fixtures)
  │   → FAIL (must use https://)
  ├─ gitleaks detect --source . --verbose
  │   → FAIL if secrets/keys found
  └─ Verify: no API keys or credentials in source files

OFFLINE-FIRST CHECKS:
  ├─ All Firestore write operations use WriteBatch or Transaction
  ├─ All Firestore reads use snapshots() streams (not get() one-shots)
  └─ Verify: metadata.hasPendingWrites used for sync indicators

LOCALIZATION CHECKS:
  ├─ grep -rn "Text(" lib/ | grep -v "AppLocalizations\|l10n\|test"
  │   → WARN on hardcoded string literals in Text() widgets
  └─ Verify: app_en.arb and app_hi.arb have matching keys
```

#### Branch Protection Rules (GitHub Settings)

```text
Branch: main, develop
  ├─ Require pull request before merging
  ├─ Require at least 1 approval (Code Reviewer agent)
  ├─ Require status checks to pass:
  │   ├─ analyze-and-format ✓
  │   ├─ test-and-coverage ✓
  │   ├─ security-scan ✓
  │   ├─ architecture-compliance ✓
  │   ├─ cloud-functions-check ✓
  │   ├─ firestore-rules-test ✓
  │   └─ build-check ✓
  ├─ Require branches to be up to date before merging
  ├─ Require linear history (no merge commits)
  └─ Do not allow force pushes
```

---

## AI Agent Team Design

### Agent Roles & Responsibilities

| # | Agent Role | Mode | Responsibilities | Maps to Copilot Agent |
|---|-----------|------|-------------------|----------------------|
| 1 | **🏗️ Architect** | Planning & Review | Define project scaffolding, enforce Clean Architecture layers, review structural decisions, approve PRs that change architecture | `code-reviewer` + manual oversight |
| 2 | **🔧 Flutter Dev** | Development | Implement Flutter features end-to-end (entity → DAO → repo → provider → screen), write production Dart code | `flutter-dev` |
| 3 | **☁️ Firebase Dev** | Development | Write Cloud Functions (TypeScript), Firestore triggers, security rules, storage rules | `firebase-backend` |
| 4 | **🧪 QA / Test Writer** | Quality Assurance | Write unit/widget/integration tests, validate split invariants, test offline scenarios, verify coverage targets | `test-writer` |
| 5 | **👁️ Code Reviewer** | Review Gate | Review all code for bugs, security gaps, architecture violations, money handling errors, missing offline handling | `code-reviewer` |
| 6 | **🚀 DevOps** | Infrastructure | Set up CI/CD (GitHub Actions), Firebase project config, Fastlane, app signing, deployment pipelines | `ci-debugger` (extended) |
| 7 | **🐛 Bug Fixer** | Debugging | Diagnose and fix issues found by QA or CI, write regression tests | `bug-fixer` |
| 8 | **♿ Accessibility** | Compliance | Audit screens for WCAG 2.1 AA, add Semantics, test with screen readers | `accessibility` |
| 9 | **⚡ Perf Optimizer** | Optimization | Profile cold start, scroll perf, memory, app size; optimize hot paths | `performance-optimizer` |
| 10 | **📝 Doc Writer** | Documentation | Maintain architecture docs, generate dartdoc, write changelogs | `doc-writer` |
| 11 | **📊 Tech Lead** | Orchestration | Coordinates agents, manages sprint backlog, resolves blockers, makes scope decisions | Human + Copilot CLI |

### Agent Interaction Model

```text
                    ┌──────────────┐
                    │  Tech Lead   │ ← Orchestrator (human + Copilot CLI)
                    └──────┬───────┘
                           │ assigns tasks
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │  Architect  │ │   DevOps    │ │  Doc Writer  │
    └──────┬──────┘ └──────┬──────┘ └─────────────┘
           │               │
           │ designs       │ CI/CD
           ▼               ▼
    ┌─────────────────────────────┐
    │     Development Pool        │
    │  ┌──────────┐ ┌──────────┐  │
    │  │Flutter Dev│ │Firebase  │  │
    │  │          │ │   Dev    │  │
    │  └──────────┘ └──────────┘  │
    └──────────────┬──────────────┘
                   │ submits code
                   ▼
    ┌─────────────────────────────┐
    │      Quality Gate           │
    │  ┌──────────┐ ┌──────────┐  │
    │  │QA/Tester │ │Code      │  │
    │  │          │ │Reviewer  │  │
    │  └──────────┘ └──────────┘  │
    └──────────────┬──────────────┘
                   │ approved
                   ▼
    ┌─────────────────────────────┐
    │    Specialist Pool          │
    │  ┌────────┐┌────────┐┌───┐  │
    │  │Bug Fix ││A11y    ││Perf│  │
    │  └────────┘└────────┘└───┘  │
    └─────────────────────────────┘
```

### Per-Task Workflow (Every Feature)

```text

1. Tech Lead    → Creates task with acceptance criteria
2. Architect    → Reviews design, approves approach (for structural tasks)
3. Flutter Dev  → Implements domain + data + presentation layers

   Firebase Dev → Implements Cloud Functions + security rules (parallel)

4. QA/Tester   → Writes tests, runs coverage analysis
5. Code Reviewer→ Reviews for bugs, security, architecture compliance
6. Bug Fixer   → Fixes any issues found in review/testing
7. DevOps      → Ensures CI passes, handles deployment
8. Doc Writer  → Updates relevant documentation

```

---

## Option A: Vertical Slice Strategy (Recommended)

**Philosophy:** Build complete features end-to-end, one at a time. Each slice is a shippable increment.

**Pros:** Always have a working app; early feedback; clear progress; easier to demo.
**Cons:** Some refactoring as shared infrastructure evolves; cross-cutting concerns addressed incrementally.

### Sprint 0 — Foundation (Infrastructure)

**Agents:** Architect, DevOps, Flutter Dev, Firebase Dev

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S0-01 | Flutter project scaffold | Architect + Flutter Dev | `flutter create`, pubspec.yaml with all dependencies (riverpod, go_router, freezed, firebase_core, cloud_firestore, firebase_auth, etc.), set up folder structure per 03_CLASS_DIAGRAMS.md |
| S0-02 | Firebase project setup | DevOps + Firebase Dev | Create Firebase project, configure asia-south1, enable Auth (phone), Firestore, Storage, Functions, FCM, Analytics, Crashlytics |
| S0-03 | Core layer implementation | Flutter Dev | Error types (AppException hierarchy), Result\<T\>, constants, extensions (date, num paise↔rupees, string), validators, ID generator |
| S0-04 | Theme & Design System | Flutter Dev | AppTheme (light/dark), AppColors (Material 3 + custom extensions), AppTypography, AmountFormatter, all design system widgets (LoadingIndicator, ErrorDisplay, EmptyState, AmountDisplay, BalanceDisplay) |
| S0-05 | Logging system | Flutter Dev | AppLogger with multi-output (console, file, Crashlytics), PII sanitizer, JSON Lines format, ring buffer |
| S0-06 | Router setup | Flutter Dev | GoRouter configuration with auth redirect, route definitions, deep link setup |
| S0-07 | Connectivity service | Flutter Dev | Network state monitoring, offline banner widget, ConnectivityBadge |
| S0-08 | CI/CD pipeline — PR gate | DevOps | GitHub Actions `ci-pr.yml`: 7-job pipeline (analyze, test+coverage, security scan, architecture compliance, Cloud Functions check, Firestore rules test, build check). Branch protection rules on main/develop requiring all 7 jobs to pass. |
| S0-08b | CI/CD pipeline — Nightly | DevOps | GitHub Actions `ci-nightly.yml`: 5-job pipeline (integration tests, performance benchmarks, dependency audit, code quality metrics, security deep scan). Slack/email alerts on failure. |
| S0-08c | CI/CD pipeline — Release | DevOps | GitHub Actions `ci-release.yml`: 5-job pipeline (full quality gate, build artifacts, deploy backend, deploy mobile via Fastlane, post-release verify). Triggered on version tags. |
| S0-08d | Custom lint scripts | DevOps + Architect | Shell scripts for money safety checks (no double for amounts), architecture compliance (domain isolation), security checks (no print, no http, no secrets), offline-first checks, localization checks. Integrated into `ci-pr.yml`. |
| S0-08e | analysis_options.yaml | Architect | Strict lint configuration: flutter_lints + prefer_const_constructors, prefer_final_locals, avoid_print, prefer_single_quotes, unawaited_futures, etc. |
| S0-09 | Firebase Functions scaffold | Firebase Dev | TypeScript project setup, ESLint, deploy scripts, emulator config |
| S0-10 | Firestore security rules (base) | Firebase Dev | Base rules for users, groups, friends collections |
| S0-11 | Localization setup | Flutter Dev | flutter_localizations, app_en.arb, app_hi.arb, gen-l10n pipeline |
| S0-12 | Tests for core layer | QA | Unit tests for AmountFormatter, validators, extensions, Result type, ID generator |

**Exit Criteria:** `flutter run` shows themed splash screen, CI pipeline green (all 7 PR gate jobs passing), Firebase connected, all core utils tested, branch protection rules active, nightly pipeline scheduled, custom lint scripts running.

### Sprint 1 — Authentication

**Agents:** Flutter Dev, Firebase Dev, QA, Code Reviewer

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S1-01 | Auth domain layer | Flutter Dev | User entity (freezed), AuthRepository interface, auth use cases (sendOtp, verifyOtp, signOut, deleteAccount) |
| S1-02 | Auth data layer | Flutter Dev | FirebaseAuthSource, UserFirestoreSource, UserModel (json_serializable), UserMapper, AuthRepositoryImpl |
| S1-03 | Auth providers | Flutter Dev | authStateProvider, currentUserProvider, sendOtpProvider, verifyOtpProvider (Riverpod codegen) |
| S1-04 | Welcome screen | Flutter Dev | Logo, app name, tagline, "Get Started" button per UI_DESIGN.md |
| S1-05 | Phone input screen | Flutter Dev | Country code (+91), phone input, "Send OTP" button, validation |
| S1-06 | OTP verification screen | Flutter Dev | 6-digit Pinput, auto-read (Android), resend timer, verify flow |
| S1-07 | Profile setup screen | Flutter Dev | Name, email (optional), avatar picker, save to Firestore |
| S1-08 | Auth flow integration | Flutter Dev | GoRouter auth redirect, splash → auth check → welcome/home |
| S1-09 | onUserCreated Cloud Function | Firebase Dev | Initialize userGroups collection, send welcome notification |
| S1-10 | Auth security rules | Firebase Dev | Users collection: self-read, self-write only |
| S1-11 | Auth tests | QA | Unit tests for use cases, widget tests for all 4 screens, integration test for full auth flow |
| S1-12 | Auth code review | Code Reviewer | Review for security, token handling, PII protection |

**Exit Criteria:** User can register via phone OTP, profile saved to Firestore, auth state persisted, all tests passing.

### Sprint 2 — Groups (Core)

**Agents:** Flutter Dev, Firebase Dev, QA, Code Reviewer

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S2-01 | Group domain layer | Flutter Dev | Group, GroupMember entities (freezed), GroupRepository interface, use cases (createGroup, getGroups, getGroupDetail, addMember, removeMember, archiveGroup) |
| S2-02 | Group data layer | Flutter Dev | GroupFirestoreSource, GroupMemberFirestoreSource, GroupModel, GroupMemberModel, mappers, GroupRepositoryImpl |
| S2-03 | Group providers | Flutter Dev | userGroupsProvider, groupDetailProvider, groupMembersProvider, createGroupProvider |
| S2-04 | Home dashboard screen | Flutter Dev | Balance summary card, Groups tab, Friends tab (placeholder), Recent Activity (placeholder), FAB |
| S2-05 | Group list on dashboard | Flutter Dev | Groups tab with ListTile (avatar, name, balance summary, chevron), pinned first, sorted by recent |
| S2-06 | Create group screen | Flutter Dev | Name input, category picker, create flow, navigate to group detail |
| S2-07 | Group detail screen | Flutter Dev | SliverAppBar, TabBar (Expenses/Balances/Settle Up), member list, settings |
| S2-08 | Group settings screen | Flutter Dev | Edit name/category, archive group, member management |
| S2-09 | Invite system | Firebase Dev | generateInviteLink, joinGroupViaInvite Cloud Functions, invite code generation/validation |
| S2-10 | Group triggers | Firebase Dev | onMemberJoined, onMemberLeft → update memberCount, log activity, update userGroups |
| S2-11 | Group security rules | Firebase Dev | Group-level member access, owner/admin permissions |
| S2-12 | Group tests | QA | Entity tests, repository tests, provider tests, widget tests, invite flow tests |

**Exit Criteria:** User can create groups, invite members, view group details, archive groups. All offline-capable.

### Sprint 3 — Expenses (All Split Types)

**Agents:** Flutter Dev, Firebase Dev, QA, Code Reviewer

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S3-01 | Expense domain layer | Flutter Dev | Expense, ExpensePayer, ExpenseSplit, ExpenseItem entities, ExpenseRepository interface, split calculation algorithms (equal, exact, percentage, shares), use cases |
| S3-02 | Expense data layer | Flutter Dev | ExpenseFirestoreSource (CRUD + subcollections), ExpenseModel, SplitModel, PayerModel, mappers, ExpenseRepositoryImpl with WriteBatch for atomicity |
| S3-03 | Split algorithms | Flutter Dev | Implement all 5 split types with Largest Remainder Method for rounding, validation (sum = total) |
| S3-04 | Expense providers | Flutter Dev | groupExpensesProvider, expenseDetailProvider, addExpenseProvider, editExpenseProvider |
| S3-05 | Add expense screen | Flutter Dev | Amount input, description, payer selector, participant selector, split type picker, category grid, date picker, notes |
| S3-06 | Split options modal | Flutter Dev | Tabs: Equal / Unequal / Percentage / Shares with live validation ("₹X remaining") |
| S3-07 | Expense list (group) | Flutter Dev | Grouped by date (sticky headers), expense items with category icon, amount (color-coded), "Paid by [Name]" |
| S3-08 | Expense detail screen | Flutter Dev | Full details, split breakdown, edit/delete with 30s undo (soft delete), audit history |
| S3-09 | onExpenseCreated trigger | Firebase Dev | Recalculate pairwise balances, update group summary, log activity, send push notifications |
| S3-10 | onExpenseUpdated trigger | Firebase Dev | Recalculate balances, log changes, send push |
| S3-11 | onExpenseDeleted trigger | Firebase Dev | Recalculate balances on soft delete, log deletion, send push |
| S3-12 | Expense security rules | Firebase Dev | Group members can CRUD expenses, validate amount > 0, splits sum check |
| S3-13 | Split algorithm tests | QA | Exhaustive tests for all 5 split types, edge cases (1 paise remainder, single person, zero amounts), invariant checks |
| S3-14 | Expense flow tests | QA | Widget tests for add/edit/list/detail screens, integration test for full expense lifecycle |

**Exit Criteria:** User can add/edit/delete expenses with all split types. Balances recalculate via Cloud Functions. Offline writes queue and sync.

### Sprint 4 — Balances & Settlements

**Agents:** Flutter Dev, Firebase Dev, QA, Code Reviewer

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S4-01 | Balance domain layer | Flutter Dev | Balance entity, BalanceRepository interface, use cases (getGroupBalances, getMyBalance) |
| S4-02 | Balance data layer | Flutter Dev | BalanceFirestoreSource (read-only from client), BalanceModel, mapper, BalanceRepositoryImpl (stream listeners) |
| S4-03 | Debt simplification algorithm | Flutter Dev + Firebase Dev | Implement net-balance approach (creditors/debtors matching), simplifyDebts Cloud Function |
| S4-04 | Settlement domain layer | Flutter Dev | Settlement entity, SettlementRepository interface, use cases (recordSettlement, settleAll) |
| S4-05 | Settlement data layer | Flutter Dev | SettlementFirestoreSource, SettlementModel, SettlementRepositoryImpl with WriteBatch |
| S4-06 | Balance display (group detail) | Flutter Dev | Pairwise balance matrix, "Who owes whom" list with arrows + amounts, color-coded |
| S4-07 | Settle Up screen | Flutter Dev | Suggested settlements from debt simplification, manual amount entry, confirmation dialog |
| S4-08 | Settle All flow | Flutter Dev + Firebase Dev | settleAll Cloud Function to record all suggested settlements atomically |
| S4-09 | Balance summary card (home) | Flutter Dev | "You owe" (red) / "You are owed" (green) aggregated across all groups + friends |
| S4-10 | Settlement triggers | Firebase Dev | onSettlementCreated → update balances, log activity, send push |
| S4-11 | Balance/settlement tests | QA | Debt simplification algorithm tests, settlement recording tests, balance aggregation tests |

**Exit Criteria:** Balances display correctly per group, debt simplification works, users can record settlements. Home shows overall balance.

### Sprint 5 — Friends & 1:1 Expenses

**Agents:** Flutter Dev, Firebase Dev, QA, Code Reviewer

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S5-01 | Friend domain layer | Flutter Dev | FriendPair entity, FriendRepository interface, use cases (addFriend, getFriends, getFriendDetail) |
| S5-02 | Friend data layer | Flutter Dev | FriendFirestoreSource, FriendModel, mapper, FriendRepositoryImpl. Canonical pair ID: min(a,b)_max(a,b) |
| S5-03 | Friend providers | Flutter Dev | userFriendsProvider, friendDetailProvider, addFriendProvider, friendBalanceProvider |
| S5-04 | Friends tab on dashboard | Flutter Dev | Friends list with avatar, name, running balance (color-coded), sorted by recent activity |
| S5-05 | Add friend flow | Flutter Dev + Firebase Dev | Search users by phone/name, addFriend Cloud Function (create pair + userFriends entries) |
| S5-06 | Friend detail screen | Flutter Dev | Net balance (single scalar), 1:1 expense list, settle up button, activity log |
| S5-07 | Add expense (friend context) | Flutter Dev | Reuse add expense screen with friend context, all split types, 2-person only |
| S5-08 | Friend settlement | Flutter Dev + Firebase Dev | settleFriend Cloud Function, record settlement in friend pair |
| S5-09 | Friend expense triggers | Firebase Dev | onFriendExpenseCreated/Updated/Deleted → recalculate 1:1 balance, log activity, send push |
| S5-10 | Friend settlement trigger | Firebase Dev | onFriendSettlementCreated → update balance, log activity, send push |
| S5-11 | Friend security rules | Firebase Dev | Pair members only for read/write, balance read-only from client |
| S5-12 | Friend flow tests | QA | All friend features, 1:1 balance calculation, canonical ID ordering |

**Exit Criteria:** Full friends feature working — add friend, 1:1 expenses, balance tracking, settlements. Both group and friend flows complete.

### Sprint 6 — Notifications & Activity Feed

**Agents:** Flutter Dev, Firebase Dev, QA, Code Reviewer

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S6-01 | Notification domain + data | Flutter Dev | Notification entity, NotificationRepository, FirestoreSource for users/{uid}/notifications |
| S6-02 | FCM setup (client) | Flutter Dev | Request permissions, get/refresh FCM token, save to user doc, foreground/background handling |
| S6-03 | Push notification triggers | Firebase Dev | Expand all existing triggers to include FCM fan-out (get members → check prefs → send multicast → handle stale tokens) |
| S6-04 | In-app notification center | Flutter Dev | Notification list screen, read/unread state, tap to navigate to relevant screen |
| S6-05 | Activity feed | Flutter Dev | Activity entity, ActivityRepository, chronological feed across all groups/friends |
| S6-06 | Activity tab (bottom nav) | Flutter Dev | Timeline view with icons by type (expense added, settlement, member joined, etc.) |
| S6-07 | Notification/activity tests | QA | Push handling tests, notification center tests, activity feed tests |

**Exit Criteria:** Push notifications delivered for all key events, in-app notification center works, activity feed shows all actions.

### Sprint 7 — Search, Filters & Analytics

**Agents:** Flutter Dev, QA, Code Reviewer

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S7-01 | Global search | Flutter Dev | Search across expenses, groups, people. SearchRepository, search screen with results |
| S7-02 | Expense filters | Flutter Dev | Filter by date range, category, payer, group, amount range |
| S7-03 | Analytics domain + data | Flutter Dev | AnalyticsRepository, compute category breakdown, monthly trends, group comparison |
| S7-04 | Analytics screens | Flutter Dev | Category breakdown chart, monthly trends chart, group comparison |
| S7-05 | Analytics tab (bottom nav) | Flutter Dev | Charts using fl_chart or similar, date range selector |
| S7-06 | Search/analytics tests | QA | Search result accuracy, filter combinations, chart data correctness |

**Exit Criteria:** Users can search globally, filter expenses, view spending analytics with charts.

### Sprint 8 — Polish, Performance & Accessibility

**Agents:** Perf Optimizer, Accessibility, Bug Fixer, QA

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S8-01 | Cold start optimization | Perf Optimizer | Profile with Flutter DevTools, target < 2s, deferred loading, lazy initialization |
| S8-02 | Scroll performance | Perf Optimizer | ListView.builder optimization for 10,000+ expenses, const widgets, image caching |
| S8-03 | App size optimization | Perf Optimizer | R8/ProGuard, tree shaking, --split-debug-info, --obfuscate, target < 30MB |
| S8-04 | Memory leak audit | Perf Optimizer | Dispose controllers, cancel stream subscriptions, Firestore listener cleanup |
| S8-05 | Accessibility audit | Accessibility | WCAG 2.1 AA compliance, Semantics labels, focus traversal, dynamic text (2.0x), contrast ratios |
| S8-06 | Offline UX polish | Bug Fixer | Ensure all screens handle offline gracefully, sync indicators, conflict resolution UI |
| S8-07 | Error handling audit | Bug Fixer | Ensure all error paths show user-friendly messages, retry options |
| S8-08 | E2E integration tests | QA | Full user journey tests (register → create group → add expense → settle → verify) |
| S8-09 | Security audit | Code Reviewer | Firestore rules coverage, Cloud Functions validation, token handling, PII protection |

**Exit Criteria:** App meets all NFR targets (cold start < 2s, smooth scroll, < 30MB, WCAG AA). All edge cases handled. Zero lint warnings. Coverage targets met across all layers.

### Sprint 9 — Release Preparation

**Agents:** DevOps, Doc Writer, QA, Tech Lead

| Task ID | Task | Agent | Description |
|---------|------|-------|-------------|
| S9-01 | Release CI/CD | DevOps | Fastlane setup for Android (Play Store AAB) + iOS (App Store), signing configs, 3 flavors (dev/staging/prod) |
| S9-02 | Firebase deployment | DevOps | Deploy Cloud Functions, security rules, indexes to production |
| S9-03 | App store assets | DevOps + Doc Writer | Screenshots, app description, privacy policy, terms of service |
| S9-04 | Changelog & release notes | Doc Writer | CHANGELOG.md, version tagging, release notes for stores |
| S9-05 | Final regression testing | QA | Full regression suite on real devices (Android + iOS), offline scenarios |
| S9-06 | Production readiness review | Tech Lead + Code Reviewer | Final checklist: security rules tested, no debug flags, crashlytics enabled, analytics working |

**Exit Criteria:** App published to Play Store and App Store. CI/CD pipeline for future releases working. All quality gates passed.

---

## Sprint Completion Checklist (Applied to EVERY Sprint)

Before a sprint is marked "done", ALL of the following must be true:

```bash
CODE QUALITY:
[ ] `flutter analyze --fatal-infos` reports ZERO issues
[ ] `dart format --set-exit-if-changed .` produces no changes
[ ] All new code has dartdoc comments on public APIs
[ ] No magic numbers, no dead code, no unused imports
[ ] All money handling uses int (paise) — no double anywhere
[ ] All split algorithms verify sum(splits) == total

TESTING:
[ ] Unit test coverage meets or exceeds layer targets
[ ] All error paths have test cases (negative testing)
[ ] All edge cases tested (zero, single, max, empty, offline)
[ ] No skipped tests (`skip:` not used anywhere)

ARCHITECTURE:
[ ] Domain layer has zero imports from data/presentation/Flutter/Firebase
[ ] Data layer has zero imports from presentation layer
[ ] All entities use freezed, all models use json_serializable
[ ] All providers use Riverpod codegen (@riverpod)

SECURITY:
[ ] No secrets, API keys, or credentials in source code
[ ] No print() calls (AppLogger only)
[ ] No http:// URLs (https:// only)
[ ] Cloud Functions validate all inputs and check auth
[ ] Firestore security rules cover all new collection paths

OFFLINE & UX:
[ ] All new features work offline (verified manually)
[ ] Sync status indicators shown on new user-created content
[ ] All error paths show user-friendly messages with retry
[ ] All user-facing strings use localization (ARB files)
[ ] All new screens have Semantics labels for accessibility

CI/CD:
[ ] All 7 PR pipeline jobs pass (analyze, test, security, arch, functions, rules, build)
[ ] Coverage did not decrease vs main branch
[ ] Build size did not increase above 30MB threshold
[ ] Code review completed with all critical + important checks passing
[ ] No regressions in existing functionality

DOCS:
[ ] CHANGELOG.md updated with sprint changes
[ ] Architecture docs updated if schema/API/flow changed
```

---

## Agent Execution Protocol (Quality-First)

### For Each Task

```text

1. TECH LEAD assigns task → provides task ID, description, acceptance criteria, relevant doc sections

2. DEV AGENT (Flutter Dev or Firebase Dev):

   a. Read relevant architecture docs (entity schemas, UI specs, algorithms)
   b. Implement code following Clean Architecture layers:

      - Domain first (entities, interfaces, use cases) — pure Dart, no imports from data/presentation
      - Data second (models, mappers, sources, repo impls) — depends only on domain
      - Presentation last (providers, screens, widgets) — depends on domain + data

   c. Write dartdoc on ALL public APIs
   d. Ensure no magic numbers, no dead code, no hardcoded strings
   e. Run `dart format .` to format all code
   f. Run `flutter analyze` — must be ZERO issues
   g. Run existing tests to ensure no regressions
   h. Commit with conventional commit format

3. QA AGENT (mandatory, same sprint):

   a. Write unit tests for domain entities, algorithms, use cases (target 95%)
   b. Write unit tests for repositories and data sources (target 80%)
   c. Write widget tests for new screens/components (target 70%)
   d. Test ALL edge cases: zero amounts, single participant, offline, empty lists, max sizes
   e. Test ALL error paths: network failure, invalid input, auth expired, conflict
   f. Verify money invariants: sum(splits) == total, all amounts are int (paise)
   g. Run `flutter test --coverage` and verify targets met
   h. Report coverage gaps with specific line numbers

4. REVIEWER AGENT (mandatory quality gate):

   CRITICAL CHECKS (auto-reject if found):
   a. NO floating-point money (double used for amounts)
   b. Split sums always equal total (off by even 1 paisa → reject)
   c. Auth checks present in ALL Cloud Functions
   d. Security rules cover ALL collection paths
   e. NO hard deletes (must be soft delete with isDeleted flag)
   f. Domain layer has ZERO imports from Flutter/Firebase
   g. NO secrets/credentials in source code

   IMPORTANT CHECKS (must fix before merge):
   h. Every async operation has error handling
   i. All Firestore listeners properly disposed
   j. Sync status indicators on user-created content
   k. Cloud Functions validate ALL inputs
   l. All user-facing strings use localization (no hardcoded English)
   m. Semantics labels for accessibility
   n. No unused imports or dead code

   APPROVAL: Only approve when ALL critical + important checks pass.

5. BUG FIXER AGENT (if issues found):

   a. Fix all issues from code review
   b. Add regression tests for each fix
   c. Re-run full test suite
   d. Re-submit for review

6. DEVOPS AGENT:

   a. Verify CI passes (analyze + test + build)
   b. Deploy Cloud Functions if changed
   c. Update security rules if changed
   d. Verify deployment succeeded
```

### Agent Prompting Template

```text
Role: {agent_role}
Sprint: {sprint_id}
Task: {task_id} — {task_title}
Context: Read docs/{relevant_doc}.md for specifications.
Architecture: Follow Clean Architecture (domain → data → presentation).

Quality Rules (MANDATORY):

  - All money in paise (int), NEVER use double for money
  - Offline-first: All writes through Firestore SDK; all reads from cache-first streams
  - Soft deletes with 30s undo (isDeleted flag, never hard delete)
  - freezed for entities (immutable), json_serializable for DTO models
  - Riverpod codegen for providers (@riverpod annotation)
  - Result\<T\> pattern for all repository returns
  - AsyncValue<T> for all UI state
  - Every public API has /// dartdoc comment
  - Every error path has user-friendly handling
  - No hardcoded strings — use ARB localization
  - No magic numbers — use constants
  - No dead code — remove unused imports/variables
  - `flutter analyze` must report ZERO issues
  - `dart format` must produce no changes

Acceptance Criteria:
  {criteria_list}

Definition of Done:

  1. Code compiles without errors or warnings
  2. `flutter analyze` → 0 issues
  3. All new code has dartdoc comments
  4. Unit tests written and passing (coverage targets met)
  5. Error paths tested (negative test cases)
  6. Money invariants verified (sum == total, int only)
  7. Works offline (verified)
  8. Code review passed (all critical + important checks)

```

---

## Key Technical Decisions (Pre-Resolved by Docs)

| Decision | Resolution | Doc Reference |
|----------|-----------|---------------|
| State management | Riverpod 2.x with codegen | ADR-01 |
| Database | Cloud Firestore (sole DB) | ADR-02 |
| Architecture | Clean Architecture (3 layers) | ADR-03 |
| Cloud Functions | TypeScript on Node.js, 2nd gen | ADR-04 |
| Region | asia-south1 (Mumbai) | ADR-05 |
| Navigation | GoRouter | ADR-06 |
| Min versions | iOS 17+, Android 15+ (API 35+) | ADR-07 |
| Dual context | Groups + Friends separate collections | ADR-08 |
| Money | Integer paise, never floating point | REQUIREMENTS / ALGORITHMS |
| Offline | Firestore SDK cache, no separate local DB | SYNC_ARCHITECTURE |
| Auth | Firebase Auth, phone OTP only | SECURITY |
| Split types | Equal, Exact, Percentage, Shares, Itemized | ALGORITHMS |

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Firestore offline cache limitations | Balance sync may lag | Test thoroughly with airplane mode; add manual sync trigger |
| Split rounding errors | Financial inaccuracies | Exhaustive testing of Largest Remainder Method; invariant checks in CI |
| Cloud Function cold starts | Slow balance recalculation | Keep functions warm; use asia-south1 for low latency |
| Complex state management | UI inconsistencies | Riverpod's AsyncValue handles loading/error/data consistently |
| Security rules complexity | Data leaks | 100% rule path testing; security audit sprint |
| App size bloat | Poor install rates | R8/ProGuard, tree shaking, deferred imports; target < 30MB |

---

## Notes

- All 10 Copilot custom agents and 17 skills are pre-defined in `docs/COPILOT_SETUP.md`
- Path-specific instructions auto-apply when editing matching file patterns
- The docs are comprehensive enough that agents can be prompted with just doc references
- Phase 1 (MVP) covers Sprints 0-9; Phase 2 and Phase 3 features are backlog items
