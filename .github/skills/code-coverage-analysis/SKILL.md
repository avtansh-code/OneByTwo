---
name: code-coverage-analysis
description: "Guide for analyzing code coverage, finding gaps, and improving test coverage for Flutter and TypeScript code."
---

# Code Coverage Analysis

## Generate Coverage

### Flutter

```bash
# Run tests with coverage enabled
flutter test --coverage

# View summary
lcov --summary coverage/lcov.info

# Generate HTML report for visual inspection
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### TypeScript (Cloud Functions)

```bash
cd functions && npm test -- --coverage
# Report is generated at functions/coverage/
```

---

## Coverage Targets

| Layer | Path Pattern | Target |
|-------|-------------|--------|
| Domain entities | `lib/domain/entities/` | 95–100% |
| Split algorithms | `lib/core/utils/` | 95–100% |
| Use cases | `lib/domain/usecases/` | 90% |
| Repositories | `lib/data/repositories/` | 80% |
| Data sources | `lib/data/remote/` | 80% |
| Models & mappers | `lib/data/models/` | 85% |
| Widgets / screens | `lib/presentation/` | 70% |
| Cloud Functions | `functions/src/` | 85% |
| **Overall** | **all** | **80%** |

---

## Finding Uncovered Code

### Summary Report

```bash
# Show per-file coverage summary
lcov --list coverage/lcov.info

# Find files with coverage below 80%
lcov --list coverage/lcov.info | awk 'NR > 2 && $NF+0 < 80 {print $1, $NF}'
```

### Specific File Inspection

```bash
# Find uncovered lines in a specific file
lcov --list coverage/lcov.info | grep "expense"

# Detailed line-by-line coverage (in HTML report)
open coverage/html/lib/domain/usecases/add_expense_use_case.dart.gcov.html
```

### Find Completely Untested Files

```bash
# Files with 0% coverage
lcov --list coverage/lcov.info | awk '$NF == "0.0%" {print $1}'

# Dart files with no corresponding test file
find lib -name '*.dart' | while read f; do
  test_file="test/${f#lib/}"
  test_file="${test_file%.dart}_test.dart"
  [ ! -f "$test_file" ] && echo "MISSING TEST: $f"
done
```

---

## Exclude Generated Files

Generated code inflates coverage metrics and should be excluded:

```bash
lcov --remove coverage/lcov.info \
  '*.g.dart' \
  '*.freezed.dart' \
  '*.gen.dart' \
  '*.gr.dart' \
  '*.config.dart' \
  'lib/generated/*' \
  'lib/l10n/*' \
  -o coverage/lcov_filtered.info
```

Use the filtered file for all subsequent analysis:

```bash
lcov --summary coverage/lcov_filtered.info
genhtml coverage/lcov_filtered.info -o coverage/html_filtered
```

---

## CI Coverage Gate Script

Add this to your CI pipeline to enforce minimum coverage:

```bash
#!/bin/bash
set -euo pipefail

# Generate filtered coverage
flutter test --coverage
lcov --remove coverage/lcov.info \
  '*.g.dart' '*.freezed.dart' '*.gen.dart' \
  -o coverage/lcov_filtered.info --quiet

# Extract line coverage percentage
COVERAGE=$(lcov --summary coverage/lcov_filtered.info 2>&1 \
  | grep "lines" \
  | awk '{print $2}' \
  | tr -d '%')

THRESHOLD=80

if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
  echo "❌ Coverage $COVERAGE% is below ${THRESHOLD}% threshold"
  exit 1
fi

echo "✅ Coverage: $COVERAGE%"
```

---

## Per-Layer Coverage Enforcement

For stricter enforcement, check coverage per layer:

```bash
#!/bin/bash
set -euo pipefail

check_layer_coverage() {
  local layer_name="$1"
  local pattern="$2"
  local threshold="$3"

  local coverage=$(lcov --extract coverage/lcov_filtered.info "$pattern" 2>/dev/null \
    | lcov --summary /dev/stdin 2>&1 \
    | grep "lines" \
    | awk '{print $2}' \
    | tr -d '%')

  if [ -z "$coverage" ]; then
    echo "⚠️  $layer_name: No coverage data found"
    return 0
  fi

  if (( $(echo "$coverage < $threshold" | bc -l) )); then
    echo "❌ $layer_name: $coverage% < ${threshold}% threshold"
    return 1
  fi
  echo "✅ $layer_name: $coverage%"
}

FAILED=0
check_layer_coverage "Domain"       "*/domain/*"       95 || FAILED=1
check_layer_coverage "Core Utils"   "*/core/utils/*"   95 || FAILED=1
check_layer_coverage "Use Cases"    "*/usecases/*"     90 || FAILED=1
check_layer_coverage "Repositories" "*/repositories/*" 80 || FAILED=1
check_layer_coverage "Presentation" "*/presentation/*" 70 || FAILED=1

exit $FAILED
```

---

## Strategy for Improving Coverage

### Priority Order

1. **Domain entities & split algorithms** (highest value)
   - Every branch in split logic must be covered
   - Test edge cases: 0 participants, 1 participant, large numbers, remainder distribution

2. **Use cases** (business logic)
   - Test success and failure paths
   - Test validation logic
   - Test with mocked repositories

3. **Repository implementations** (data flow)
   - Test mapping from models to entities and back
   - Test error handling (network errors, parse errors)
   - Test offline/cache behavior

4. **Widgets** (user interactions)
   - Test form validation and submission
   - Test navigation flows
   - Test loading and error states

### Quick Wins

- Add tests for all `fromJson` / `toJson` methods
- Add tests for all `copyWith` methods
- Add tests for all extension methods
- Add tests for all validators

### What NOT to Test

- Generated code (`*.g.dart`, `*.freezed.dart`)
- Trivial getters/setters with no logic
- Framework code (GoRouter config, theme data)
- `main()` function

---

## Coverage Analysis Checklist

- [ ] Generated filtered coverage report (excluding `*.g.dart`, `*.freezed.dart`)
- [ ] Overall coverage ≥ 80%
- [ ] Domain layer ≥ 95%
- [ ] Split algorithms ≥ 95% with all edge cases
- [ ] No completely untested files in `domain/` or `core/`
- [ ] All use cases have success and failure path tests
- [ ] Coverage trend is stable or improving (no regressions)
