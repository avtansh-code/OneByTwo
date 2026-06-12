# Hooks

This directory contains lifecycle hook scripts for the One By Two agentic workspace.
Hooks are registered in `hooks.json` and execute automatically at specific points
in the agent lifecycle.

## Registry

All hooks are defined in `hooks.json` using the Claude Code hook schema. The
registry maps lifecycle events to scripts.

## Hook Events

### PreToolUse

Runs **before** an `Edit` or `Write` tool call is executed (matcher `Edit|Write`).
The matched tool's payload — including the target `file_path` and the proposed
content (`new_str`/`content`/`file_text`) — is passed to the script on stdin. If the
script exits non-zero, the tool call is blocked and the error message is shown to the
agent.

| Script | Purpose | Invariant |
|---|---|---|
| `pre-tool-use/block-simplified-balances-write.sh` | Blocks client-side writes to `simplifiedBalances`/`simplified_balances` in files under `lib/` (detected via `.set(`/`.update(`/`.write`/`.batch`/`.commit`/`.runTransaction`); reads are allowed). | 2 — server-maintained, client-read-only (SRS 4.6, 7.3, 7.5) |
| `pre-tool-use/block-platform-share-targets.sh` | Blocks imports of platform-specific share packages (WhatsApp, Telegram, Facebook, Instagram, LINE, Viber, Signal, WeChat) in `.dart`/`.yaml`/`.yml` files. | 3 — system share sheet only (SRS 3.4, 4.11, 12.2) |
| `pre-tool-use/block-second-firebase-project.sh` | Blocks staging/dev project IDs in `.firebaserc`/`firebase.json`, and `firebase` CLI calls (`emulators:start`, `emulators:exec`, `deploy`) that omit a `--project` flag in shell scripts (`*.sh`) and workflow YAML. Excludes the canonical wrapper `scripts/dev/start-emulators.sh`. | 4 — single Firebase project (SRS 3.4, 9.1) |

### PostToolUse

Runs **after** an `Edit` or `Write` tool call completes successfully (matcher
`Edit|Write`). Used for auto-formatting. These scripts no-op silently when the tool,
the target file, or `functions/node_modules` is absent.

| Script | Purpose |
|---|---|
| `post-tool-use/dart-format.sh` | Runs `dart format --fix` on edited `.dart` files (falls back to `flutter format --fix` if `dart` is unavailable). |
| `post-tool-use/eslint-fix.sh` | Runs `npx eslint --fix` on edited `.ts`/`.js` files under `functions/` (walks up to the `functions/` root). |

### UserPromptSubmit

Runs when a user prompt is submitted, before the agent processes it. Used to
inject context.

| Script | Purpose |
|---|---|
| `user-prompt-submit/load-srs-context.sh` | Prints a context reminder: the product summary, the SRS path (`docs/OneByTwo_Requirements_Spec.md`, v1.1), the four invariants, and pointers to `.github/shared/`, `.github/agents/`, and `.github/skills/`. |

### Stop

Runs when the agent session ends. Used for session wrap-up.

| Script | Purpose |
|---|---|
| `stop/summarise-changes.sh` | Prints a summary of all file changes (staged, unstaged, untracked) made during the session. |

## Compatibility

All scripts are POSIX-compatible (`#!/bin/sh`) and run on both macOS and Linux. They
read the tool payload from stdin and write audit lines (`[hook] <name>: ...`) and any
block messages to stderr.

- **PreToolUse** scripts parse the payload with `jq` when it is available and fall
  back to a `grep`/`sed` regex extraction when it is not.
- **PostToolUse** scripts shell out to the relevant formatter — `dart format --fix`
  (or `flutter format --fix`) and `npx eslint --fix` — and no-op silently when the
  tool or file is missing.
- **UserPromptSubmit** and **Stop** scripts use only `cat`, `printf`, and `git`.

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
