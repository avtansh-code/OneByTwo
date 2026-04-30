# Hooks

This directory contains lifecycle hook scripts for the OneByTwo agentic workspace.
Hooks are registered in `hooks.json` and execute automatically at specific points
in the agent lifecycle.

## Registry

All hooks are defined in `hooks.json` using the Claude Code hook schema. The
registry maps lifecycle events to scripts.

## Hook Events

### PreToolUse

Runs **before** an Edit or Write tool call is executed. If the script exits
non-zero, the tool call is blocked and the error message is shown to the agent.

| Script | Purpose | Invariant |
|---|---|---|
| `pre-tool-use/block-simplified-balances-write.sh` | Prevents client-side writes to `simplifiedBalances` in files under `lib/`. | 2 — server-maintained, client-read-only (SRS 4.6, 7.3, 7.5) |
| `pre-tool-use/block-platform-share-targets.sh` | Prevents imports of platform-specific share packages (WhatsApp, Telegram, etc.). | 3 — system share sheet only (SRS 3.4, 4.11, 12.2) |
| `pre-tool-use/block-second-firebase-project.sh` | Prevents introduction of staging/dev Firebase project IDs in config files. | 4 — single Firebase project (SRS 3.4, 9.1) |

### PostToolUse

Runs **after** an Edit or Write tool call completes successfully. Used for
auto-formatting.

| Script | Purpose |
|---|---|
| `post-tool-use/dart-format.sh` | Runs `dart format --fix` on edited `.dart` files. |
| `post-tool-use/eslint-fix.sh` | Runs `npx eslint --fix` on edited `.ts`/`.js` files under `functions/`. |

### UserPromptSubmit

Runs when a user prompt is submitted, before the agent processes it. Used to
inject context.

| Script | Purpose |
|---|---|
| `user-prompt-submit/load-srs-context.sh` | Prints a context reminder with the SRS path, the four invariants, and pointers to shared context files. |

### Stop

Runs when the agent session ends. Used for session wrap-up.

| Script | Purpose |
|---|---|
| `stop/summarise-changes.sh` | Prints a summary of all file changes (staged, unstaged, untracked) made during the session. |

## Compatibility

All scripts are POSIX-compatible (`#!/bin/sh`) and run on both macOS and Linux.
They use only standard utilities (`grep`, `sed`, `cat`, `printf`, `git`).

## Disabling Hooks for Debugging

To temporarily disable a hook:

1. **Single hook:** remove or comment out its entry in `hooks.json`.
2. **All hooks:** rename `hooks.json` to `hooks.json.disabled`.
3. **Specific event:** remove the entire event key from `hooks.json`.

Remember to restore `hooks.json` after debugging.

## Adding New Hooks

1. Create the script under the appropriate event directory.
2. Make it executable: `chmod +x .github/hooks/<event>/<script>.sh`.
3. Add an entry to `hooks.json` with the correct matcher and command path.
4. Update this README with the script's purpose and any invariant it enforces.
