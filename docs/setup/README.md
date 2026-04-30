# Setup Documentation

This directory contains all documentation and references for configuring the
One By Two Firebase production project, registering apps with Apple and Google
stores, and wiring CI/CD secrets.

## Run Order

1. **`scripts/firebase/run-all.sh`** — Execute the automated Firebase setup
   scripts (project linking, API enablement, Firestore/Storage creation, Remote
   Config seeding, app registration, service account creation, App Check, smoke
   test).

2. **`firebase-console-checklist.md`** — Complete the manual Firebase Console
   tasks that cannot be automated (Phone Auth config, SMS region whitelist, App
   Check enforcement, Crashlytics, Analytics, FCM APNs key upload).

3. **`app-store-registration.md`** — Register the app in App Store Connect and
   Google Play Console. Create APNs keys, DeviceCheck keys, API keys, upload
   keystores, and Fastlane match repo.

4. **`secrets-manifest.md`** — Cross-reference every GitHub Actions secret with
   its source. Use `scripts/stores/upload-github-secrets.sh` to upload all
   secrets in one step.

5. **`readiness-for-skeleton-pr.md`** — Final checklist confirming everything
   is in place before the skeleton bootstrap PR can be opened.

## File Index

| File | Purpose |
|---|---|
| `00-decisions.md` | Phase 1 — All project-level decisions (project ID, region, identifiers, auth, billing, secrets). Source of truth for all other setup artefacts. |
| `firebase-console-checklist.md` | Phase 3 — Human-runnable Firebase Console tasks with exact navigation paths and "done when" assertions. |
| `app-store-registration.md` | Phase 4 — Apple App Store Connect and Google Play Console registration steps, with credential-to-secret mapping. |
| `secrets-manifest.md` | Phase 5 — Complete table of all 13 GitHub Actions secrets, their sources, formats, and rotation policies. |
| `manual-setup-checklist.md` | Consolidated checklist of all 29 remaining manual tasks, ordered by dependency, with step-by-step instructions and checkboxes. |
| `readiness-for-skeleton-pr.md` | Phase 7 — Pre-skeleton-PR checklist. |

## Related Scripts

| Script | Purpose |
|---|---|
| `scripts/firebase/run-all.sh` | Orchestrator for all Firebase setup scripts (00–10). |
| `scripts/firebase/config.env.example` | Configuration template for setup scripts. |
| `scripts/stores/upload-github-secrets.sh` | Uploads secrets from `.secrets/` to GitHub Actions via `gh`. |
