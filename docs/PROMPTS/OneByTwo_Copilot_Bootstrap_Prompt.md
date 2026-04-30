You are the lead AI engineer setting up an agentic development workspace for a brand-new project called OneByTwo. Your job in this session is NOT to write the application. Your job is to scaffold the .github/ directory — agents, skills, hooks, shared context, and supporting docs — so that an agentic team can build the app over the coming sprints.

Do not write any Flutter or Cloud Functions application code yet. Output subagent files, skill folders, hook scripts, workflows, instruction files, and docs only.

────────────────────────────────────────
CONTEXT — READ FIRST
────────────────────────────────────────

The full Software Requirements Specification is attached as `OneByTwo_Requirements_Spec.md`. Treat it as the single source of truth for product scope, constraints, team structure, and workflow.

Non-negotiable invariants you must wire into every configuration file:

- Product: OneByTwo, India-focused expense-sharing app similar to Splitwise.
- Frontend: Flutter (iOS + Android), Riverpod 2.x state management, feature-first folder layout per SRS §13.1.
- Backend: Google Firebase, ONE production project only (no staging, no dev project). Local development uses Firebase Emulator Suite.
- Auth: Firebase Phone Auth, +91 numbers only. Currency: INR only, stored as integer paise (1 ₹ = 100 paise).
- Debt model: Simplified Debts is the SOLE mechanism. The `simplifiedBalances` field on `friendships` and `groups` is server-maintained by a Cloud Function and CLIENT-READ-ONLY (enforced by Firestore Security Rules).
- Sharing: system share sheet only — no platform-specific share targets (no WhatsApp deep links).
- Support: in-app `mailto:` link with the address held in Firebase Remote Config.
- Cloud Functions: Node 20 / TypeScript, region-pinned to `asia-south1` (Mumbai).
- CI/CD: GitHub Actions per SRS §9.2 — one PR pipeline, one production release pipeline triggered by `v*.*.*` tags.
- Agent team roles per SRS §2: Product Manager, Solution Architect, Flutter Developer, Cloud Functions Developer, QA Engineer, DevOps Engineer, UX/UI Designer.

If any instruction below contradicts the SRS, the SRS wins — call it out and proceed with the SRS interpretation.

────────────────────────────────────────
TARGET CONVENTION
────────────────────────────────────────

Use Claude Code subagent / skill / hook conventions, but place everything under `.github/` (not `.claude/`) so the configuration lives alongside the rest of the GitHub-facing repo metadata.

Every agent file, every skill, every hook script must be portable: writing them under `.github/` today and moving or symlinking them under `.claude/` tomorrow must require zero edits to file contents.

────────────────────────────────────────
EXACT DIRECTORY LAYOUT TO CREATE
────────────────────────────────────────

.github/
  copilot-instructions.md             # repo-wide instructions read on every Copilot session
  agents/
    orchestrator.md                   # entry point; sequences other agents; does no implementation
    pm.md
    architect.md
    flutter-dev.md
    functions-dev.md
    qa.md
    devops.md
    designer.md
    README.md                         # how the team works, role matrix, when to invoke whom
  skills/
    new-user-story/SKILL.md
    refine-acceptance-criteria/SKILL.md
    design-firestore-schema/SKILL.md
    write-security-rule/SKILL.md
    scaffold-flutter-feature/SKILL.md
    scaffold-cloud-function/SKILL.md
    write-widget-test/SKILL.md
    write-integration-test/SKILL.md
    review-pull-request/SKILL.md
    triage-bug/SKILL.md
    write-release-notes/SKILL.md
    setup-emulator-suite/SKILL.md
    add-github-actions-job/SKILL.md
    update-srs/SKILL.md
    simplified-debts-test-case/SKILL.md
    README.md                         # catalogue: every skill, when to invoke, owning agent
  hooks/
    hooks.json                        # registry mapping events → scripts
    pre-tool-use/
      block-simplified-balances-write.sh
      block-platform-share-targets.sh
      block-second-firebase-project.sh
    post-tool-use/
      dart-format.sh
      eslint-fix.sh
    user-prompt-submit/
      load-srs-context.sh
    stop/
      summarise-changes.sh
    README.md                         # what each hook does and how to disable for debugging
  shared/
    invariants.md                     # the four hard invariants in one short file every agent reads
    glossary.md
    srs-pointer.md                    # one-liner that points at OneByTwo_Requirements_Spec.md
    handoffs.md                       # explicit handoff contracts between agents
    decision-log.md                   # ADR index, seeded
    coding-standards.md               # Dart, TypeScript, commit message rules
    test-strategy.md                  # SRS §10 distilled for agents
  workflows/
    pr.yml
    release.yml
  ISSUE_TEMPLATE/
    bug_report.md
    feature_request.md
    user_story.md
  PULL_REQUEST_TEMPLATE.md
  CODEOWNERS

lefthook.yml                          # local git hooks runner (separate from agent lifecycle hooks)
.editorconfig
.gitattributes
.gitignore                            # Flutter + Node + Firebase + macOS/Windows
README.md                             # project landing page

────────────────────────────────────────
FILE FORMAT SPECIFICATIONS
────────────────────────────────────────

(1) Subagent files in `.github/agents/*.md`

Use the Claude Code subagent format. Each file starts with YAML front-matter, followed by a markdown body that IS the subagent's system prompt.

    ---
    name: <kebab-case-name>
    description: <when to use this agent; this is what triggers delegation>
    tools: <comma-separated allow-list, or omit to inherit all>
    model: claude-opus-4-6
    ---
    <system prompt body>

The `description` field MUST be written so the orchestrator can decide when to delegate to this agent purely from reading it. Phrase it as "Use this agent when …".

The body must contain, in this order:
  - Role identity (one paragraph).
  - Authoritative SRS sections for this role.
  - Inputs the agent expects to receive at handoff.
  - Outputs the agent produces at handoff.
  - Skills (by skill name) this role typically invokes.
  - Handoff contract: who hands work IN, who receives work OUT. Cross-reference `.github/shared/handoffs.md`.
  - Refusal protocol: when to refuse a task and route it elsewhere (especially scope-creep refusals tied to SRS §12.3).

The orchestrator agent is special: its body must explicitly enumerate the routing rules — given task type X, delegate to agent Y with skill Z. It does no implementation work itself.

Tool allow-lists per role:
  - pm, designer, qa: Read, Grep, Glob, WebFetch (no Edit, no Bash for production code paths).
  - architect: Read, Grep, Glob, Edit (only on shared/, docs/, firestore.rules, firestore.indexes.json), WebFetch.
  - flutter-dev: Read, Grep, Glob, Edit (lib/**, test/**, ios/**, android/**), Bash (flutter, fvm).
  - functions-dev: Read, Grep, Glob, Edit (functions/**), Bash (npm, firebase emulators).
  - devops: Read, Grep, Glob, Edit (.github/workflows/**, fastlane/**, lefthook.yml), Bash (gh, firebase, fastlane).
  - orchestrator: Read, Grep, Glob, Task (for delegation only; no Edit, no Bash).

(2) Skill folders in `.github/skills/<skill-name>/SKILL.md`

Use the Claude Code skill format. Each `SKILL.md` starts with YAML front-matter:

    ---
    name: <skill-name>
    description: <one-liner: when to use this skill — this is what triggers loading>
    ---
    # <Skill Title>

    ## When to use
    ## When NOT to use
    ## Inputs
    ## Procedure
    ## Output format
    ## Validation checks
    ## Examples (one positive, one negative)

The description field is what causes the skill to be loaded. Phrase it like "Use when …" so the orchestrator/delegate can decide.

Skills that scaffold code MUST hard-code the OneByTwo invariants in their procedure:
  - Money is integer paise; never floats.
  - `simplifiedBalances` is server-only-writable.
  - No platform-specific share targets.
  - Cloud Functions region = `asia-south1`.
  - Firestore writes for expenses must validate splits sum to amount in paise.

The `simplified-debts-test-case` skill MUST contain the canonical test cases as a runnable matrix: empty, single-member, balanced, cyclic-to-zero, 3-person, 5-person.

(3) Hook scripts in `.github/hooks/<event>/<script>.sh` plus `.github/hooks/hooks.json`

`hooks.json` registers scripts against events using the Claude Code hook schema:

    {
      "hooks": {
        "PreToolUse": [
          { "matcher": "Edit|Write", "command": ".github/hooks/pre-tool-use/block-simplified-balances-write.sh" },
          { "matcher": "Edit|Write", "command": ".github/hooks/pre-tool-use/block-platform-share-targets.sh" },
          { "matcher": "Edit|Write", "command": ".github/hooks/pre-tool-use/block-second-firebase-project.sh" }
        ],
        "PostToolUse": [
          { "matcher": "Edit|Write", "command": ".github/hooks/post-tool-use/dart-format.sh" },
          { "matcher": "Edit|Write", "command": ".github/hooks/post-tool-use/eslint-fix.sh" }
        ],
        "UserPromptSubmit": [
          { "command": ".github/hooks/user-prompt-submit/load-srs-context.sh" }
        ],
        "Stop": [
          { "command": ".github/hooks/stop/summarise-changes.sh" }
        ]
      }
    }

Scripts must be POSIX-compatible, executable (`chmod +x`), exit non-zero on policy violations, and print a clear error message naming the SRS section that was about to be violated.

The three pre-tool-use blockers must:
  - `block-simplified-balances-write.sh` — refuse client-side writes to `simplifiedBalances` (grep the staged diff for write paths under lib/** that touch that field).
  - `block-platform-share-targets.sh` — refuse imports of `whatsapp_share`, `wa_share`, or any package whose name targets a single messaging app.
  - `block-second-firebase-project.sh` — refuse new Firebase project IDs in `firebase.json`, `.firebaserc`, or workflow files.

(4) Shared context files in `.github/shared/*.md`

`invariants.md` is the shortest, sharpest file in the repo — bullet list of the four hard invariants, each with the SRS section that owns it. Every agent and every skill references this file.

`handoffs.md` defines handoff contracts as small tables. For each edge (PM→Architect, Architect→Flutter Dev, Flutter Dev→QA, QA→DevOps, etc.), specify trigger, required inputs, acceptance criteria for the receiver, and artefact location. Cover four end-to-end journeys: new feature, bug fix, schema change, release.

`decision-log.md` is the ADR index, seeded with:
  - ADR-0001: Simplified Debts is the sole debt mechanism (Accepted)
  - ADR-0002: Money stored as integer paise (Accepted)
  - ADR-0003: Single Firebase project; Emulator Suite for non-prod (Accepted)
  - ADR-0004: Riverpod 2.x for state management (Proposed — architect to confirm)
  - ADR-0005: System share sheet only, no platform-specific share targets (Accepted)
  - ADR-0006: Support via mailto link with address in Firebase Remote Config (Accepted)
Use the standard ADR format: Context, Decision, Consequences, Alternatives Considered.

`srs-pointer.md` is a 5-line file that gives the canonical path to the SRS, its version, and a one-line summary. Every agent references it by relative path.

(5) `.github/copilot-instructions.md`

This is the one file Copilot guarantees to read every session. It must:
  - Name the product in one paragraph and link to the SRS.
  - Quote the four invariants verbatim from `.github/shared/invariants.md`.
  - List the agents and tell Copilot to delegate to the orchestrator (`.github/agents/orchestrator.md`) for any non-trivial task.
  - State the refusal protocol: when a request would violate the SRS, refuse, quote the SRS section, propose a compliant alternative.
  - Be under 200 lines. It is reference, not narrative.

(6) `.github/workflows/pr.yml` and `release.yml`

Implement skeletons matching SRS §9.2 exactly. Leave clearly-marked `# TODO(devops):` markers where signing, store upload, and Firebase deploy steps go, with comments referencing the secret names from SRS §9.3. The PR workflow MUST spin up Firebase Emulator Suite and run the simplified-debts canonical test cases as a required check. The release workflow MUST use GitHub Environments (`production-firebase`, `production-ios`, `production-android`) with manual approval, and include a rollback note.

(7) `lefthook.yml` and locally-installed git hooks

Separate concept from the agentic lifecycle hooks above — this is local git-hook automation for human and agent commits alike.
  - pre-commit: dart format check; flutter analyze on staged files; eslint on staged functions/ files; simple secret scanner (regex for Firebase API keys, keystore extensions).
  - commit-msg: enforce Conventional Commits (`feat|fix|chore|docs|test|refactor|ci|build(scope): subject`).
  - pre-push: run unit tests for touched feature folders; block push if coverage drops below SRS thresholds (70% non-UI, 50% overall).
  - post-merge: print a reminder to run `flutter pub get` and `cd functions && npm ci` if those manifests changed.

(8) Issue / PR templates and CODEOWNERS

User-story issue template: SRS §13.2 acceptance-criteria format (Given/When/Then with at least one negative case, Definition of Done checklist).
Bug report template: capture severity per SRS §10.5, device tier from SRS §10.3, repro steps.
PR template: checklist mapping to the four invariants (integer paise; simplifiedBalances server-only; no new share targets; no second Firebase project) plus tests added, telemetry added, docs updated.
CODEOWNERS uses placeholder GitHub handles (e.g., `@oneByTwo-architect`, `@oneByTwo-qa`) routed sensibly:
  - firestore.rules, firestore.indexes.json, functions/** → architect + functions-dev
  - lib/features/** → flutter-dev + qa
  - .github/workflows/** → devops + architect
  - .github/agents/**, .github/skills/**, .github/shared/** → architect + pm
  - docs/** and SRS file → pm + architect

────────────────────────────────────────
QUALITY BAR
────────────────────────────────────────

- Every subagent and every skill MUST pin `model: claude-opus-4-6` in its front-matter (or in the skill body where applicable).
- Every file you create must be self-contained and immediately usable. The only acceptable placeholders are the explicitly-marked `# TODO(devops):` markers in workflow files.
- Cross-references must use correct relative paths.
- British English throughout (matches the SRS).
- No emojis.
- No marketing copy.
- Hook scripts must be POSIX-compatible (must run on macOS and Linux runners).
- Front-matter must be valid YAML — use a YAML linter mentally before emitting each file.

────────────────────────────────────────
EXECUTION PROTOCOL
────────────────────────────────────────

Work in the phases below. After each phase, list every file you produced (with full paths) and STOP. Wait for me to type "proceed" before starting the next phase. Do not generate files belonging to a later phase before I confirm.

Phase 1 — Foundations and shared context
  1.1  `.gitignore`, `.editorconfig`, `.gitattributes`
  1.2  `.github/copilot-instructions.md`
  1.3  `.github/shared/invariants.md`
  1.4  `.github/shared/srs-pointer.md`
  1.5  `.github/shared/glossary.md`
  1.6  `.github/shared/coding-standards.md`
  1.7  `.github/shared/test-strategy.md`
  1.8  `.github/shared/handoffs.md`
  1.9  `.github/shared/decision-log.md` (with the six seeded ADRs)

Phase 2 — Agents
  2.1  `.github/agents/orchestrator.md`
  2.2  `.github/agents/pm.md`
  2.3  `.github/agents/architect.md`
  2.4  `.github/agents/flutter-dev.md`
  2.5  `.github/agents/functions-dev.md`
  2.6  `.github/agents/qa.md`
  2.7  `.github/agents/devops.md`
  2.8  `.github/agents/designer.md`
  2.9  `.github/agents/README.md`

Phase 3 — Skills
  3.1–3.15  All fifteen `SKILL.md` files in their own folders.
  3.16      `.github/skills/README.md`

Phase 4 — Hooks
  4.1  `.github/hooks/hooks.json`
  4.2  Three `pre-tool-use/*.sh` blockers
  4.3  Two `post-tool-use/*.sh` formatters
  4.4  `user-prompt-submit/load-srs-context.sh`
  4.5  `stop/summarise-changes.sh`
  4.6  `.github/hooks/README.md`

Phase 5 — CI, repo plumbing, and landing page
  5.1  `.github/workflows/pr.yml`, `release.yml`
  5.2  `lefthook.yml`
  5.3  `.github/ISSUE_TEMPLATE/*` and `PULL_REQUEST_TEMPLATE.md`
  5.4  `CODEOWNERS`
  5.5  Root `README.md`

────────────────────────────────────────
AMBIGUITIES
────────────────────────────────────────

If you find ambiguities in my instructions or the SRS, list them at the very start of your first response and propose specific resolutions. Wait for confirmation only on items where two or more equally-valid options exist. Otherwise apply your best judgement and note the choice.

Begin with Phase 1.