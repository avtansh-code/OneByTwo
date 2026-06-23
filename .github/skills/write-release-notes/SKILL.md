---
name: write-release-notes
description: >
  Use when release notes need to be drafted for a tagged version, summarising
  changes for users and stakeholders.
---

# Write Release Notes

## When to use

When a release tag (`v*.*.*`) is being released and notes need to be drafted for
the GitHub Release and app store listings. The current release workflow is
`.github/workflows/release.yml`: it documents the `v*.*.*` tag trigger, currently
runs through `workflow_dispatch` with a `tag` input, and creates a GitHub Release
after test guard, Firebase deploy, Android build, and iOS build jobs.

## When NOT to use

- When the release has not been signed off by QA.
- When the task is writing internal documentation (just edit directly).

## Inputs

1. **Git tag** — the version being released (e.g., `v1.0.0`).
2. **Commit range** — commits since the last tag.
3. **User stories completed** — list of GitHub Issues closed in this release,
   sourced from the release's sprint milestone (see
   `.github/shared/milestone-tracking.md`).
4. **Known issues** — any open S3/S4 bugs shipping in this release.
5. **Workflow evidence** — the relevant `.github/workflows/release.yml` run or
   release branch/tag context.

## Procedure

1. Read `.github/workflows/release.yml` before drafting. Confirm the tag name
   follows `v*.*.*`; if using the current workflow manually, confirm the
   `workflow_dispatch` `tag` input.
2. Collect commits since the previous tag using `git log`, matching the workflow's
   generated-notes behaviour (`git log --pretty=format:"- %s (%h)"` between the
   previous tag and the release tag, or the most recent 50 commits when no
   previous tag is available).
3. Group changes by Conventional Commit type:
   a. **New features** (`feat`): user-facing capabilities added.
   b. **Bug fixes** (`fix`): issues resolved.
   c. **Improvements** (`refactor`, `chore`): non-user-facing but noteworthy.
4. For each feature or fix:
   a. Write a one-line summary in plain language (no technical jargon).
   b. Reference the user story, issue, or PR number only when it exists in the
      supplied release evidence. Do not invent references.
5. Cover only implemented repo features: activity, auth, expenses, friends,
   notifications, profile, reminders, settlements, and shell. State that Groups
   UI is planned only if it is relevant to a known issue or deferred scope.
6. Add a "Known issues" section if any S3/S4 bugs are shipping.
7. Add a "Breaking changes" section if any exist.
8. Write in British English, no emojis, no marketing copy.
9. Keep the tone informative and concise.
10. Confirm the release's sprint milestone is closed once the notes are published,
    per `.github/shared/milestone-tracking.md`.

## Output format

Markdown text suitable for a GitHub Release body and adaptable for app store
"What's New" sections. The GitHub Release body may include a concise "Changes"
section compatible with the workflow-generated commit-subject format.

## Validation checks

- [ ] All `feat` commits are represented.
- [ ] All `fix` commits are represented.
- [ ] Breaking changes are called out.
- [ ] Known issues are listed.
- [ ] British English throughout.
- [ ] No emojis or marketing copy.
- [ ] Issue/story/PR references are included only when present in release
      evidence.
- [ ] The release tag follows `v*.*.*`.
- [ ] The notes do not claim Groups client UI has shipped unless the repo shows
      that it has.

## Examples

### Positive example

**Input:** Tag `v1.0.0`, first release.

**Output:**
```markdown
## v1.0.0

### New features

- Phone-number authentication with OTP verification (+91 only).
- Add and split friendship expenses with integer paise storage and INR display.
  (include issue or PR references only when present in the release evidence)
- Simplified balances are recomputed by Cloud Functions and read by the client.
- Record settlements, send reminders, and track settlement history for supported
  contexts.
- Activity feed with real-time updates.
- Profile and notification preference screens.

### Known issues

- Offline expense sync may take up to 10 seconds after reconnection on slow
  networks. (reference the tracked S3 issue only when present in the release
  evidence)
```

### Negative example (should refuse)

**Input:** "Write release notes for the UPI payment feature."

**Response:** Refused. UPI integration is listed in SRS section 12.3 as out of
scope for v1.0. Release notes can only cover features that have been implemented
and signed off.
