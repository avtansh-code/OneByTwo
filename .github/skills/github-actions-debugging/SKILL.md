---
name: github-actions-debugging
description: Guide for debugging failing GitHub Actions workflows in the One By Two app. Use this when asked to debug CI/CD failures, build errors, or deployment issues.
---

To debug failing GitHub Actions workflows, follow this process using the GitHub MCP Server tools:

1. **List recent workflow runs** using `list_workflow_runs` to find the failing run and its ID.

2. **Get failed job logs** using `get_job_logs` with `failed_only: true` and `return_content: true` to read the actual failure output.

3. **Categorize the failure** based on the job name and error output:

   - **`flutter-analyze` job:** Dart analysis warnings or errors. Look for the specific file and warning. Fix the Dart code.
   - **`flutter-test` job:** Unit or widget test failure. Read the test name and assertion failure. Fix the test or the code it tests.
   - **`flutter-build-android` job:** Android build failure. Check `build.gradle`, SDK versions, ProGuard rules, signing config.
   - **`flutter-build-ios` job:** iOS build failure. Check Xcode project settings, provisioning profiles, CocoaPods, minimum deployment target (must be iOS 17).
   - **`firebase-deploy-functions` job:** Cloud Functions deployment failure. Check TypeScript compilation errors in `functions/src/`.
   - **`firebase-deploy-rules` job:** Firestore or Storage rules syntax error. Validate rules locally with `firebase emulators:exec`.
   - **`integration-test` job:** Integration test failure. Check Firebase Emulator logs and test output.

4. **Check the triggering commit** to see what changed — the failure is almost always in recently modified files.

5. **Reproduce locally** before pushing a fix:
   - `flutter analyze` for lint issues
   - `flutter test` for test failures
   - `cd functions && npm run build` for Cloud Functions
   - `firebase emulators:exec --only firestore 'npm test'` for rules tests

6. **Fix the issue** with the minimal change needed.

7. **Verify the fix** passes locally before pushing.
