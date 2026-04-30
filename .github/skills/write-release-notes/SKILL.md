---
name: write-release-notes
description: >
  Use when release notes need to be drafted for a tagged version, summarising
  changes for users and stakeholders.
---

# Write Release Notes

## When to use

When a Git tag (`v*.*.*`) has been created and release notes need to be drafted
for the GitHub Release and app store listings.

## When NOT to use

- When the release has not been signed off by QA.
- When the task is writing internal documentation (just edit directly).

## Inputs

1. **Git tag** — the version being released (e.g., `v1.0.0`).
2. **Commit range** — commits since the last tag.
3. **User stories completed** — list of GitHub Issues closed in this release.
4. **Known issues** — any open S3/S4 bugs shipping in this release.

## Procedure

1. Collect all commits since the previous tag using `git log`.
2. Group changes by Conventional Commit type:
   a. **New features** (`feat`): user-facing capabilities added.
   b. **Bug fixes** (`fix`): issues resolved.
   c. **Improvements** (`refactor`, `chore`): non-user-facing but noteworthy.
3. For each feature or fix:
   a. Write a one-line summary in plain language (no technical jargon).
   b. Reference the user story or issue number.
4. Add a "Known issues" section if any S3/S4 bugs are shipping.
5. Add a "Breaking changes" section if any exist.
6. Write in British English, no emojis, no marketing copy.
7. Keep the tone informative and concise.

## Output format

Markdown text suitable for a GitHub Release body and adaptable for app store
"What's New" sections.

## Validation checks

- [ ] All `feat` commits are represented.
- [ ] All `fix` commits are represented.
- [ ] Breaking changes are called out.
- [ ] Known issues are listed.
- [ ] British English throughout.
- [ ] No emojis or marketing copy.
- [ ] Issue/story references are included.

## Examples

### Positive example

**Input:** Tag `v1.0.0`, first release.

**Output:**
```markdown
## v1.0.0

### New Features

- Phone-number authentication with OTP verification (+91 only). (#1)
- Add and split expenses equally, by amount, percentage, shares, or exact
  amounts. (#5, #6)
- Simplified Debts: balances are automatically minimised so you see the fewest
  possible transfers. (#10)
- Record settlements and track history per friend and group. (#12)
- Activity feed with real-time updates. (#15)
- Contact Support via email with pre-filled diagnostics. (#18)

### Known Issues

- Offline expense sync may take up to 10 seconds after reconnection on slow
  networks. (#42, S3)
```

### Negative example (should refuse)

**Input:** "Write release notes for the UPI payment feature."

**Response:** Refused. UPI integration is listed in SRS section 12.3 as out of
scope for v1.0. Release notes can only cover features that have been implemented
and signed off.
