---
name: code-coverage-analysis
description: Guide for analyzing and improving test code coverage in the One By Two app. Use this when asked about code coverage, coverage reports, or finding untested code paths.
---

## Generating Coverage Reports

### Flutter (Dart)

```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Check coverage percentage
lcov --summary coverage/lcov.info
```

### Cloud Functions (TypeScript)

```bash
cd functions
npx jest --coverage
# Report generated in functions/coverage/
```

## Coverage Targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| Domain entities & value objects | 95%+ | Core business logic, must be bulletproof |
| Use cases | 90%+ | Business workflows, critical paths |
| Algorithms (split, debt simplify) | 100% | Money calculations, zero tolerance for bugs |
| Data mappers | 90%+ | Data transformation correctness |
| DAOs | 80%+ | Database operations |
| Repositories | 80%+ | Integration of local + remote |
| Widgets | 70%+ | UI component rendering |
| Providers | 80%+ | State management logic |
| Cloud Functions | 85%+ | Server-side business logic |
| Firestore rules | 100% of rules | Every rule path tested positive + negative |

## Finding Uncovered Code

After generating coverage, analyze the LCOV report to find gaps:

```bash
# List files with coverage below 80%
lcov --summary coverage/lcov.info 2>&1 | grep -E "^\s+\S+.*[0-7][0-9]\.[0-9]%"

# Or parse the lcov.info file
grep -E "^SF:|^LH:|^LF:" coverage/lcov.info | paste - - - | awk -F'[:|]' '{
  file=$2; hit=$4; total=$6;
  pct=(total>0) ? (hit/total*100) : 100;
  if (pct < 80) printf "%5.1f%% %s\n", pct, file
}' | sort -n
```

## Improving Coverage Strategy

1. **Start with algorithms** — They handle money. 100% coverage, no exceptions.
2. **Cover error paths** — Test what happens when DB writes fail, network is down, validation rejects input.
3. **Cover edge cases** — Empty lists, zero amounts, single participant, 100 members.
4. **Cover offline paths** — Save while offline, sync on reconnect, conflict resolution.
5. **Don't chase vanity coverage** — 80% of meaningful code > 100% of trivial code.

## Excluding from Coverage

Some files are legitimately excluded from coverage targets:
- Generated code (`*.g.dart`, `*.freezed.dart`)
- Firebase options (`firebase_options.dart`)
- Main entry point (`main.dart`)
- Route definitions (`app_router.dart`)

Add to `lcov.info` filtering:
```bash
lcov --remove coverage/lcov.info \
  '**/*.g.dart' \
  '**/*.freezed.dart' \
  '**/firebase_options.dart' \
  -o coverage/lcov_filtered.info
```
