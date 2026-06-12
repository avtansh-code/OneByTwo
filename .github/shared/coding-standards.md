# Coding Standards

These standards apply to all code in the One By Two repository. Every agent and every
skill must follow them. Reference: SRS section 5.7.

---

## Dart (Flutter)

### Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) conventions.
- Use `very_good_analysis` as the lint ruleset (`analysis_options.yaml`).
- Maximum line length: 80 characters (enforced by `dart format`).
- Null safety: always enabled; no `// ignore` for null-safety warnings without a
  code-review-approved justification.

### Naming

- Classes: `UpperCamelCase`.
- Variables, functions, parameters: `lowerCamelCase`.
- Constants: `lowerCamelCase` (Dart convention, not SCREAMING_SNAKE).
- File names: `snake_case.dart`.
- Feature folders: `snake_case` matching the feature name.

### Documentation

- All public APIs must have DartDoc comments (`///`).
- Use `@param` and `@returns` sparingly; prefer self-documenting signatures.
- Widget classes: document the widget's purpose and any required parameters.

### Money

- All monetary values are `int` representing paise. Never use `double` for money.
- Conversion to display rupees (two decimal places, Indian numbering system) happens
  exclusively in the UI layer via `formatInrFromPaise` in
  `lib/core/formatters/inr_formatter.dart`.

### State management

- Riverpod 2.x is the state management solution (ADR-0004).
- Providers live in the feature folder they serve
  (`lib/features/<feature>/application/`).

### Imports

- Use relative imports within a feature folder.
- Use package imports (`package:onebytwo/...`) for cross-feature references.
- Sort imports: dart, package, relative — separated by blank lines.

---

## TypeScript (Cloud Functions)

### Style

- Follow the [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html).
- ESLint with the recommended config; auto-fixed on save and in CI.
- Strict mode enabled in `tsconfig.json` (`"strict": true`).

### Naming

- Interfaces and types: `UpperCamelCase`.
- Functions and variables: `camelCase`.
- Constants: `UPPER_SNAKE_CASE` for true compile-time constants only.
- File names: `kebab-case.ts` or lowercase single words (e.g., `function.ts`,
  `algorithm.ts`, `id-hash.ts`, `send-reminder-notification.ts`).

### Documentation

- All exported functions must have JSDoc comments.
- Cloud Function entry points must document: trigger type, expected input, output,
  and error conditions.

### Money

- All monetary values are `number` representing integer paise. Never use floats.
- The simplified-debts algorithm (`functions/src/simplified-debts/algorithm.ts`) is a
  pure function with no side effects; only `recomputeAndWrite` in
  `functions/src/simplified-debts/function.ts` writes the result to
  `simplifiedBalances`.

### Region

- All Cloud Functions are region-pinned to `asia-south1` (Mumbai).

---

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/) strictly.

### Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

### Types

| Type | When to use |
|---|---|
| `feat` | A new feature visible to end users or agents. |
| `fix` | A bug fix. |
| `chore` | Maintenance, dependency bumps, config changes. |
| `docs` | Documentation only. |
| `test` | Adding or fixing tests. |
| `refactor` | Code change that neither fixes a bug nor adds a feature. |
| `ci` | CI/CD pipeline changes. |
| `build` | Build system or external dependency changes. |

### Rules

- **Subject line:** imperative mood, lowercase, no trailing full stop, max 72
  characters.
- **Scope:** the feature area or module affected (e.g., `auth`, `expenses`,
  `simplified-debts`, `ci`).
- **Breaking changes:** append `!` after the type/scope and include a
  `BREAKING CHANGE:` footer.
- **Referencing issues:** use `Closes #<number>` or `Refs #<number>` in the footer.

### Examples

```
feat(expenses): add unequal split validation

Validate that split amounts sum exactly to the expense total in paise
before saving. Display an inline error when there is a discrepancy.

Closes #42
```

```
fix(simplified-debts): correct tie-breaking order

Sort tied creditors/debtors by ascending userId to ensure deterministic
output across all clients.

Refs #58
```

---

## General

- No secrets or credentials in source. Use GitHub Actions secrets and Firebase
  Remote Config.
- No `TODO` comments without an associated issue number or agent role tag
  (e.g., `// TODO(flutter-dev): handle offline retry #31`).
- Prefer composition over inheritance.
- Keep functions short and single-purpose.
