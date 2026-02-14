---
applyTo: ".github/workflows/**/*.yml,.github/workflows/**/*.yaml"
---

# CI Workflow Instructions

- Use GitHub Actions with Ubuntu latest runners for all jobs
- Flutter version must be pinned (use `subosito/flutter-action` with specific version)
- Node.js version must be pinned for Cloud Functions jobs (use `actions/setup-node` with v20)
- Cache Flutter pub dependencies (`actions/cache` with `~/.pub-cache` key)
- Cache npm dependencies for Cloud Functions (`actions/cache` with `functions/node_modules`)
- Run `flutter analyze` before `flutter test` — fail fast on lint errors
- Run `flutter test --coverage` and upload coverage report as artifact
- Build Android with `flutter build appbundle` (AAB, not APK for Play Store)
- Build iOS with `flutter build ipa --no-codesign` in CI (signing in Fastlane)
- Firebase deploy jobs must use service account credentials (stored as GitHub secrets)
- Never commit secrets — use `${{ secrets.* }}` for all credentials
- Use `concurrency` groups to cancel redundant runs on the same branch
- Separate workflows: `ci.yml` (PR checks), `deploy-staging.yml` (merge to main), `release.yml` (tag push)
