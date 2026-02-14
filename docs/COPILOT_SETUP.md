# One By Two — Copilot & AI Agent Setup Guide

> **Version:** 2.1  
> **Last Updated:** 2026-02-14

This document describes the GitHub Copilot customization configured for the One By Two project — custom agents, skills, path-specific instructions, and repository-wide instructions — and how to use them effectively during development.

---

## 1. Overview

The project is configured with four layers of Copilot customization:

```
.github/
├── copilot-instructions.md              ← Repository-wide context (always active)
├── agents/                              ← 10 custom agents for specialized tasks
│   ├── flutter-dev.agent.md             ← Feature development (Flutter/Dart)
│   ├── firebase-backend.agent.md        ← Cloud Functions, rules, backend logic
│   ├── code-reviewer.agent.md           ← Code review (read-only, high-signal)
│   ├── test-writer.agent.md             ← Test writing (unit/widget/integration)
│   ├── ci-debugger.agent.md             ← CI/CD pipeline debugging
│   ├── bug-fixer.agent.md               ← Bug diagnosis and fixes
│   ├── accessibility.agent.md           ← WCAG 2.1 AA, screen readers, a11y audit
│   ├── performance-optimizer.agent.md   ← Profiling, cold start, scroll perf, app size
│   ├── doc-writer.agent.md              ← Documentation generation and maintenance
│   └── log-analyzer.agent.md            ← Log analysis, request tracing, debugging
├── skills/                              ← 12 skills auto-loaded when relevant
│   ├── github-actions-debugging/SKILL.md
│   ├── flutter-testing/SKILL.md
│   ├── firestore-rules-testing/SKILL.md
│   ├── code-coverage-analysis/SKILL.md
│   ├── expense-split-validation/SKILL.md
│   ├── offline-sync-debugging/SKILL.md  ← Sync queue, conflicts, listener debugging
│   ├── database-migration/SKILL.md      ← sqflite schema migrations
│   ├── localization/SKILL.md            ← ARB files, i18n, Hindi/English
│   ├── security-audit/SKILL.md          ← OWASP Mobile Top 10, PII, GDPR
│   ├── release-management/SKILL.md      ← Versioning, changelog, Fastlane, stores
│   ├── logging/SKILL.md                 ← Log implementation, PII rules, file rotation
│   └── git-commit-messages/SKILL.md     ← Conventional Commits format, scopes, examples
└── instructions/                        ← 7 path-specific coding instructions
    ├── dart-code.instructions.md        ← lib/**/*.dart
    ├── cloud-functions.instructions.md  ← functions/src/**/*.ts
    ├── test-code.instructions.md        ← test/**/*_test.dart
    ├── firebase-rules.instructions.md   ← **/*.rules
    ├── localization.instructions.md     ← lib/**/l10n/**/*.arb
    ├── ci-workflows.instructions.md     ← .github/workflows/**/*.yml
    └── build-config.instructions.md     ← android/**/*.gradle, ios/**/*.plist, etc.
```

---

## 2. Repository-Wide Instructions

**File:** `.github/copilot-instructions.md`

This file is **automatically included** in every Copilot interaction within the repository. It provides:

- Project overview (Flutter + Firebase, India-only, offline-first)
- Architecture summary (Clean Architecture, Riverpod, GoRouter, sqflite, Firestore)
- Key rules (paise-based amounts, offline-first writes, sync status, soft deletes, version fields)
- Project structure outline (`lib/`, `functions/`)
- Coding conventions (freezed, riverpod codegen, Result pattern, i18n)
- Testing conventions (80%+ coverage, test naming, tooling)

**You don't need to do anything** — these instructions are picked up automatically.

---

## 3. Custom Agents

Custom agents are specialized Copilot profiles tailored for specific development tasks. Each agent has its own system prompt, expertise domain, and tool access.

### How to Use Agents

**In Copilot CLI:**
```bash
# Browse available agents
/agent

# Use a specific agent via command line
copilot --agent=flutter-dev --prompt "Create the Settlement entity and full data layer"

# Or reference in a prompt — Copilot auto-detects the right agent
"Use the firebase-backend agent to write the onExpenseCreated trigger function"
```

**In VS Code Copilot Chat:**
- Click the agent dropdown at the bottom of the Chat panel
- Select the desired agent
- Type your prompt

**On GitHub.com (Copilot Coding Agent):**
- When creating a PR or assigning an issue to Copilot, select the agent from the dropdown

---

### 3.1 `flutter-dev` — Flutter Feature Developer

| Property | Details |
|----------|---------|
| **File** | `.github/agents/flutter-dev.agent.md` |
| **Purpose** | Generate new features, screens, widgets, providers, repositories, entities |
| **Tools** | read, edit, create, search, bash, grep, glob |

**When to use:**
- Creating a new feature end-to-end (entity → DAO → repository → provider → screen)
- Adding a new screen or widget
- Writing Riverpod providers
- Implementing split calculations or balance logic

**Example prompts:**
```
"Create the complete Expense entity and data layer following Clean Architecture"
"Add the Add Expense screen with amount input, payer selector, and equal split"
"Implement the RecurringExpense use case with monthly scheduling"
"Create a BalanceSummaryCard widget that shows owe/owed amounts in red/green"
```

**What it knows:**
- Clean Architecture layer boundaries (domain = pure Dart, no Flutter imports)
- File generation order (entity → interface → use case → model → mapper → DAO → Firestore → repo → provider → screen)
- Paise-based money handling and split algorithms
- Offline-first write pattern (local first → sync queue → Firestore async)
- Riverpod provider graph structure

---

### 3.2 `firebase-backend` — Firebase Backend Developer

| Property | Details |
|----------|---------|
| **File** | `.github/agents/firebase-backend.agent.md` |
| **Purpose** | Write Cloud Functions, Firestore/Storage security rules, server-side logic |
| **Tools** | read, edit, create, search, bash, grep, glob |

**When to use:**
- Writing callable Cloud Functions (e.g., `simplifyDebts`, `generateInvite`)
- Writing Firestore trigger functions (e.g., `onExpenseCreated`)
- Writing scheduled functions (e.g., `processRecurringExpenses`)
- Creating or updating Firestore/Storage security rules
- Implementing balance recalculation or notification fan-out

**Example prompts:**
```
"Write the onExpenseCreated Firestore trigger that recalculates balances and sends notifications"
"Create the generateInviteLink callable function with rate limiting"
"Update Firestore security rules to add the settlements collection access control"
"Write the weekly digest scheduled function"
```

**What it knows:**
- Cloud Functions 2nd gen TypeScript APIs
- Firestore collection hierarchy and document schemas
- Balance recalculation algorithm
- Debt simplification algorithm
- Notification fan-out with FCM
- Rate limiting implementation
- asia-south1 deployment region

---

### 3.3 `code-reviewer` — Code Review Specialist

| Property | Details |
|----------|---------|
| **File** | `.github/agents/code-reviewer.agent.md` |
| **Purpose** | Review code changes for bugs, security issues, architecture violations |
| **Tools** | read, search, bash, grep, glob (read-only — cannot modify code) |

**When to use:**
- Before submitting a PR
- After making significant changes to money/balance logic
- When refactoring sync or offline code
- When modifying security rules

**Example prompts:**
```
"Review the changes in the expense repository for correctness"
"Review the split calculation code for money handling bugs"
"Review the Firestore security rules for the groups collection"
"Review the diff in this branch for any issues"
```

**What it flags (🔴 Critical):**
- Floating-point used for money (must use integer paise)
- Split sums ≠ expense total
- Missing auth checks or security rule gaps
- Offline-first violations (reading from Firestore instead of local DB)
- Hard-deletes instead of soft-deletes
- Domain layer importing Flutter/Firebase

**What it flags (🟡 Important):**
- Missing error handling, null checks
- Firestore listener leaks
- Missing sync_status on new entities
- Cloud Functions without input validation

**What it ignores:**
- Formatting, import ordering, naming style (handled by linters)
- TODOs, FIXMEs (unless they indicate shipped bugs)
- Test coverage gaps (handled by `test-writer` agent)

---

### 3.4 `test-writer` — Testing Specialist

| Property | Details |
|----------|---------|
| **File** | `.github/agents/test-writer.agent.md` |
| **Purpose** | Write unit tests, widget tests, integration tests, and Firestore rules tests |
| **Tools** | read, edit, create, search, bash, grep, glob |

**When to use:**
- After implementing a new feature (write tests for it)
- When coverage is below target
- When a bug is fixed (write a regression test)
- When security rules change (write rules tests)

**Example prompts:**
```
"Write unit tests for the equalSplit and percentageSplit algorithms"
"Write widget tests for the AmountDisplay and BalanceCard widgets"
"Write integration tests for the add expense → balance update flow"
"Write Firestore security rules tests for the expenses collection"
"Find untested code paths in the settlement repository and write tests"
```

**What it knows:**
- Test file structure (`test/` mirrors `lib/`)
- All split algorithm invariants (sum = total, non-negative, fairness)
- AAA pattern (Arrange, Act, Assert)
- Mocking with Mocktail/Mockito
- In-memory sqflite for DAO tests
- Firebase Emulator Suite for integration tests
- Widget testing with ProviderScope

**Coverage targets it enforces:**
| Layer | Target |
|-------|--------|
| Domain entities & algorithms | 95–100% |
| Use cases | 90%+ |
| DAOs & repositories | 80%+ |
| Widgets | 70%+ |
| Cloud Functions | 85%+ |
| Firestore rules | 100% of rule paths |

---

### 3.5 `ci-debugger` — CI/CD Pipeline Debugger

| Property | Details |
|----------|---------|
| **File** | `.github/agents/ci-debugger.agent.md` |
| **Purpose** | Diagnose and fix GitHub Actions workflow failures |
| **Tools** | read, edit, search, bash, grep, glob |

**When to use:**
- A GitHub Actions workflow run failed
- Build is broken on CI but works locally
- Deployment to Firebase or app stores failed
- Test failures only happen in CI

**Example prompts:**
```
"Debug the failing CI build on the main branch"
"The flutter-test job is failing — diagnose and fix"
"Firebase functions deployment failed in the latest run — investigate"
"iOS build is failing with a signing error in CI"
```

**What it does:**
1. Fetches the failing workflow run and job logs via GitHub MCP tools
2. Categorizes the failure (build, lint, test, deploy, dependency)
3. Identifies the root cause from error messages and recent changes
4. Implements the minimal fix
5. Suggests local verification commands before pushing

**Common issues it handles:**

| CI Job | Typical Failures |
|--------|-----------------|
| `flutter-analyze` | Dart lint warnings, missing types |
| `flutter-test` | Test assertion failures, missing mocks |
| `flutter-build-android` | Gradle errors, SDK version, ProGuard |
| `flutter-build-ios` | Signing, provisioning, CocoaPods, min iOS version |
| `firebase-deploy-functions` | TypeScript compilation errors |
| `firebase-deploy-rules` | Security rules syntax errors |

---

### 3.6 `bug-fixer` — Bug Diagnosis & Fix Specialist

| Property | Details |
|----------|---------|
| **File** | `.github/agents/bug-fixer.agent.md` |
| **Purpose** | Diagnose bugs from crash reports, user feedback, or unexpected behavior and implement targeted fixes |
| **Tools** | read, edit, search, bash, grep, glob |

**When to use:**
- User reported a bug
- Crashlytics shows a new crash
- Balance is showing incorrect values
- Sync is stuck or producing duplicates
- UI is not updating after an action

**Example prompts:**
```
"Users report that expense total shows ₹0.01 less than expected after a 3-way split"
"Crashlytics shows a null pointer in ExpenseDetailScreen — diagnose and fix"
"Expenses added offline are not syncing when the app comes back online"
"Balance doesn't update after deleting an expense"
"Guest user data is not appearing after they register with a phone number"
```

**Debugging approach:**
1. Understand the expected vs actual behavior
2. Locate the root cause by tracing the data flow
3. Implement the **smallest possible fix** (no refactoring)
4. Add a regression test
5. Verify offline behavior and sync are preserved

**Bug categories it specializes in:**
- Money/balance bugs (rounding, split sums, canonical pair keys)
- Offline/sync bugs (queue stuck, duplicates, conflicts, stale data)
- UI/state bugs (missing rebuilds, stale closures, navigation)
- Auth/security bugs (token refresh, guest migration, rule rejections)

---

### 3.7 `accessibility` — Accessibility Specialist

| Property | Details |
|----------|---------|
| **File** | `.github/agents/accessibility.agent.md` |
| **Purpose** | Audit, implement, and fix WCAG 2.1 AA compliance, screen reader support, dynamic text, high contrast |
| **Tools** | read, edit, create, search, bash, grep, glob |

**When to use:**
- Implementing screen reader semantics for a screen
- Auditing the app for accessibility issues
- Making widgets work with dynamic text sizing
- Adding high contrast mode support

**Example prompts:**
```
"Audit the Add Expense screen for accessibility issues"
"Add VoiceOver/TalkBack semantics to the AmountDisplay and BalanceCard widgets"
"Verify all touch targets meet the 48dp minimum requirement"
"Make the expense list handle text scale factor 2.0x without overflow"
```

**What it knows:**
- Flutter `Semantics` widget usage patterns
- Focus traversal and navigation for screen readers
- Dynamic text sizing with `textScaleFactor` up to 2.0x
- Color contrast ratios (4.5:1 AA standard)
- Motion/animation accessibility (`disableAnimations`)
- WCAG 2.1 AA requirements mapped to Flutter implementation

---

### 3.8 `performance-optimizer` — Performance Specialist

| Property | Details |
|----------|---------|
| **File** | `.github/agents/performance-optimizer.agent.md` |
| **Purpose** | Profile, diagnose, and fix performance issues — cold start, scroll jank, app size, memory leaks |
| **Tools** | read, edit, search, bash, grep, glob |

**When to use:**
- App cold start exceeds 2 seconds
- Scroll jank in expense lists
- App download size exceeds 30MB
- Memory leaks suspected
- Cloud Functions response times are slow

**Example prompts:**
```
"Profile the app cold start and suggest optimizations to get under 2 seconds"
"The expense list scrolls with jank at 5000+ items — diagnose and fix"
"Analyze the app bundle size and reduce it below 30MB"
"Check for memory leaks in the Firestore listener management"
"Optimize the balance recalculation Cloud Function for groups with 50+ members"
```

**What it knows:**
- Flutter DevTools profiling (timeline, memory, app size)
- `ListView.builder` optimization patterns
- Deferred initialization and lazy loading
- sqflite query optimization (indexes, joins, pagination)
- Cloud Functions cold start minimization
- R8/ProGuard and Dart obfuscation
- Common anti-patterns (missing const, FutureBuilder in build, unkeyed lists)

---

### 3.9 `doc-writer` — Documentation Specialist

| Property | Details |
|----------|---------|
| **File** | `.github/agents/doc-writer.agent.md` |
| **Purpose** | Generate and maintain architecture docs, API reference, dartdoc comments, changelogs |
| **Tools** | read, edit, create, search, bash, grep, glob |

**When to use:**
- A new entity/collection/Cloud Function was added and docs need updating
- Dartdoc comments needed for public APIs
- Changelog needs updating after a sprint
- README needs a refresh after new features ship
- Architecture diagram needs updating

**Example prompts:**
```
"Update the database schema doc to include the new tags collection"
"Add dartdoc comments to all public methods in the expense repository"
"Generate the changelog entry for Sprint 3 features"
"Update the API design doc with the new exportGroupData callable function"
"Add the new nudge notification flow to the page flows diagram"
```

**What it knows:**
- All 10 architecture documents and their structure
- Dartdoc and TSDoc conventions
- Keep a Changelog format
- When each doc should be updated (new entity → schema doc, new route → page flows, etc.)
- ASCII diagram style consistent with existing docs

---

### 3.10 `log-analyzer` — Log Analysis & Debugging Specialist

| Property | Details |
|----------|---------|
| **File** | `.github/agents/log-analyzer.agent.md` |
| **Purpose** | Analyze structured log files, trace request flows across layers, diagnose issues from log output |
| **Tools** | read, edit, create, search, bash, grep, glob |

**When to use:**
- User submitted a bug report with exported logs
- Need to trace an expense flow end-to-end through log entries
- Diagnosing sync failures, performance regressions, or auth issues from log data
- Identifying error patterns or recurring warnings
- Analyzing Cloud Functions logs in Google Cloud Logging

**Example prompts:**
```
"Analyze these exported logs and find why expenses aren't syncing"
"Trace the flow of expense e123 from creation to sync in the log file"
"Find all errors from the last 24 hours and categorize them"
"What's causing the slow cold start — check Boot.* log entries"
"Search the logs for sync conflict patterns"
```

**What it knows:**
- Log file location (`{appDocumentsDir}/logs/app.log` + rotated files)
- JSON Lines format with field abbreviations (`ts`, `lvl`, `tag`, `msg`, `data`, `err`, `stack`)
- Tag conventions per layer (`Boot.*`, `Sync.*`, `Repo.*`, `DAO.*`, `FS.*`, `UI.*`, etc.)
- Common log patterns that indicate specific issues (retry loops, listener gaps, stale data)
- `grep`/`jq` commands for filtering and analyzing structured log files
- Cloud Logging query syntax for Cloud Functions logs

---

## 4. Skills

Skills are sets of instructions and resources that Copilot loads **automatically** when relevant to your prompt. You don't need to invoke them explicitly.

| Skill | Directory | Auto-Triggered When |
|-------|-----------|-------------------|
| **GitHub Actions Debugging** | `.github/skills/github-actions-debugging/` | Debugging CI/CD failures |
| **Flutter Testing** | `.github/skills/flutter-testing/` | Writing any Flutter test |
| **Firestore Rules Testing** | `.github/skills/firestore-rules-testing/` | Writing or testing security rules |
| **Code Coverage Analysis** | `.github/skills/code-coverage-analysis/` | Analyzing or improving test coverage |
| **Expense Split Validation** | `.github/skills/expense-split-validation/` | Implementing or debugging split calculations |
| **Offline Sync Debugging** | `.github/skills/offline-sync-debugging/` | Debugging sync queue, conflicts, listeners |
| **Database Migration** | `.github/skills/database-migration/` | Adding tables, columns, or modifying sqflite schema |
| **Localization** | `.github/skills/localization/` | Working with ARB files, i18n, translations |
| **Security Audit** | `.github/skills/security-audit/` | Auditing security, OWASP, PII, GDPR |
| **Release Management** | `.github/skills/release-management/` | Version bumping, changelogs, store deployment |
| **Logging** | `.github/skills/logging/` | Log implementation, PII rules, file rotation |
| **Git Commit Messages** | `.github/skills/git-commit-messages/` | Conventional Commits format, scopes, examples |

### Skill Details

#### GitHub Actions Debugging
Provides a step-by-step process for diagnosing CI failures using GitHub MCP tools (`list_workflow_runs`, `get_job_logs`). Includes a categorization guide for different failure types and local reproduction commands.

#### Flutter Testing
Contains test structure conventions, unit test and widget test templates, key testing rules (split invariants, offline mocking, in-memory sqflite), and commands for running tests with coverage.

#### Firestore Rules Testing
Provides the `@firebase/rules-unit-testing` setup template, test patterns for positive/negative access checks, a required test cases matrix for every collection, and commands for running rules tests with the emulator.

#### Code Coverage Analysis
Includes commands for generating coverage reports (Flutter + TypeScript), coverage targets per layer, techniques for finding uncovered code, a strategy for improving coverage, and instructions for excluding generated files.

#### Expense Split Validation
Defines the 5 core invariants every split must satisfy, a validation checklist for implementation/review, a Dart testing template for verifying invariants, and references to the full algorithm specs.

#### Offline Sync Debugging
Provides systematic debugging guides for the 5 most common sync issues: data not syncing, remote data not appearing locally, duplicate entries, conflict detection failures, and stale data after reconnect. Includes SQL queries for inspecting the sync queue and key tables.

#### Database Migration
Contains the migration file structure, step-by-step guide for writing new migrations, migration rules (never modify existing migrations, SQLite ALTER limitations), common migration patterns, and migration testing templates.

#### Localization
Covers ARB file format and conventions, ICU message format for plurals, Indian number formatting (1,00,000), l10n.yaml configuration, code generation commands, and testing localized strings with different locales.

#### Security Audit
Provides the complete OWASP Mobile Top 10 checklist mapped to the app, PII audit search commands, GDPR compliance matrix, Firestore security rules audit table, and commands for running security checks.

#### Release Management
Contains the version strategy (SemVer + build number), changelog format (Keep a Changelog), Fastlane configuration templates for Android and iOS, release checklist (pre-release, build, post-release), and CI/CD release workflow setup.

#### Logging
Provides the `AppLogger` usage patterns, tag naming conventions (`Layer.Component`), what to log at each level, PII rules, file rotation configuration, environment-specific log levels, and templates for implementing new `LogOutput` classes and testing log output.

#### Git Commit Messages
Defines the Conventional Commits format (`type(scope): subject`) with a complete type table (feat, fix, refactor, test, docs, perf, ci, build, chore), scope list mapped to app modules, subject writing rules (imperative mood, 72 chars), body/footer conventions, multi-file commit guidelines, and sprint-aligned commit examples.

---

## 5. Path-Specific Instructions

These instructions are automatically applied when Copilot works with files matching specific glob patterns.

| File | Applies To | Key Rules |
|------|-----------|-----------|
| `dart-code.instructions.md` | `lib/**/*.dart` | Clean Architecture layers, freezed models, Riverpod codegen, paise integers, Result pattern, ARB strings |
| `cloud-functions.instructions.md` | `functions/src/**/*.ts` | 2nd gen APIs, strict TypeScript, paise integers, input validation, auth checks, batch writes, rate limiting |
| `test-code.instructions.md` | `test/**/*_test.dart` | AAA pattern, descriptive names, money invariants, mock repos, in-memory DB, error path testing |
| `firebase-rules.instructions.md` | `**/*.rules` | Explicit rules for all collections, member-only access, read-only balances/activity, image-only uploads, positive+negative tests |
| `localization.instructions.md` | `lib/**/l10n/**/*.arb` | English source of truth, ICU message format, typed placeholders, Indian number formatting, `flutter gen-l10n` after edits |
| `ci-workflows.instructions.md` | `.github/workflows/**/*.yml` | Pinned Flutter/Node versions, pub/npm caching, analyze-before-test, AAB for Play Store, secrets management, concurrency groups |
| `build-config.instructions.md` | `android/**/*.gradle`, `ios/**/*.plist`, etc. | minSdk 35, iOS 17.0, R8/ProGuard enabled, 3 build flavors, Firebase config not committed, signing config |

**You don't need to invoke these** — they activate automatically when Copilot reads or writes files matching the glob patterns.

---

## 6. Recommended Workflows

### Building a New Feature

```
1. Use `flutter-dev` agent to generate the full feature stack
   (entity → repo → use case → provider → screen)

2. Use `test-writer` agent to write tests for the new feature

3. Use `code-reviewer` agent to review the implementation

4. Commit and push — if CI fails, use `ci-debugger` agent
```

### Fixing a Bug

```
1. Use `bug-fixer` agent with the bug description / crash log

2. Use `test-writer` agent to add a regression test

3. Use `code-reviewer` agent to verify the fix doesn't break anything
```

### Adding a Cloud Function

```
1. Use `firebase-backend` agent to write the function and update security rules

2. Use `test-writer` agent to write function tests and rules tests

3. Use `code-reviewer` agent to review for security and correctness
```

### Debugging CI Failure

```
1. Use `ci-debugger` agent — it will fetch logs, diagnose, and fix

2. If the fix involves test changes, use `test-writer` agent to help

3. Verify locally before pushing
```

### Improving Code Coverage

```
1. Ask Copilot: "Analyze code coverage and find gaps"
   (auto-loads the code-coverage-analysis skill)

2. Use `test-writer` agent to write tests for uncovered paths

3. Run `flutter test --coverage` to verify improvement
```

### Accessibility Audit & Fix

```
1. Use `accessibility` agent: "Audit the [screen name] for accessibility issues"

2. Fix the flagged issues (semantics, focus, text scaling, contrast)

3. Use `test-writer` agent to write accessibility tests
   (text scale factor 2.0x overflow, semantic labels)
```

### Performance Optimization

```
1. Use `performance-optimizer` agent: "Profile cold start / scroll / app size"

2. Implement the suggested optimizations

3. Use `code-reviewer` agent to verify no regression in functionality
```

### Preparing a Release

```
1. Use `doc-writer` agent to update CHANGELOG.md and architecture docs

2. Auto-loads release-management skill for version bumping and store prep

3. Verify with `ci-debugger` agent if release workflow fails
```

### Adding Localized Strings

```
1. Add new strings to app_en.arb (English source of truth)

2. Add Hindi translations to app_hi.arb
   (auto-loads localization skill and instructions)

3. Run `flutter gen-l10n` to regenerate
```

### Security Review

```
1. Use `code-reviewer` agent for code-level security checks

2. Ask Copilot: "Run a security audit" (auto-loads security-audit skill)

3. Use `firebase-backend` agent to fix any Firestore rules gaps
```

### Database Schema Change

```
1. Use `flutter-dev` agent to create new entity/DAO/repository

2. Auto-loads database-migration skill for writing the migration

3. Use `test-writer` agent to write migration tests (v1→v2 data preservation)
```

---

## 7. Adding New Agents or Skills

### Adding a New Agent

Create a file in `.github/agents/` with the `.agent.md` extension:

```markdown
---
name: my-agent
description: What this agent does and when to use it
tools: ["read", "edit", "create", "search", "bash"]
---

You are a specialist in [domain]. Your responsibilities:
- ...
- ...

## Rules
- ...
```

### Adding a New Skill

Create a directory in `.github/skills/` with a `SKILL.md` file:

```markdown
---
name: my-skill
description: What this skill provides and when Copilot should use it
---

Instructions, templates, and examples for the skill...
```

### Adding Path-Specific Instructions

Create a file in `.github/instructions/` with the `.instructions.md` extension:

```markdown
---
applyTo: "path/glob/pattern/**/*.ext"
---

Instructions that apply to matching files...
```
