---
applyTo: "test/**/*_test.dart,integration_test/**/*_test.dart"
---

# Test Code Instructions

- Use AAA pattern: Arrange, Act, Assert
- Use descriptive test names that explain the scenario being tested
- Group related tests with `group()`
- Always verify money invariants: `sum(splits) == totalAmount`, all amounts >= 0
- Mock external dependencies (repositories, data sources) — never call real Firebase in unit tests
- Use in-memory sqflite (`inMemoryDatabasePath`) for DAO tests
- Test both happy path AND error/edge cases
- For widget tests, wrap with `ProviderScope` and `MaterialApp`
- Never test implementation details — test observable behavior
- Use `setUp` and `tearDown` for common initialization/cleanup
