# FR-FR-01: Contact Picker UI — Architect Notes

> These notes supplement the FR-FR-01 user story with architectural decisions,
> contract definitions, and testing guidance for the contact-picker surface
> introduced in PR #31. The orchestrator will merge these into the canonical
> story file.

---

## Architect Notes

### 1. Contact-picker package choice

Three Flutter packages were evaluated:

| Package | Maintenance | API quality | Community |
|---|---|---|---|
| `flutter_contacts` | Active; regular releases | Structured `Contact` objects with typed phone numbers; built-in permission request/check methods | Large; good cross-platform parity |
| `contacts_service` | Less maintained; infrequent updates | Adequate but older API surface | Widely used historically |
| `fast_contacts` | Active but narrower focus | Performance-optimised reads | Smaller community; fewer platform-edge-case reports |

**Decision: use `flutter_contacts`** (pin to `^1.1.9+2` or latest stable at
time of implementation).

Rationale (one sentence): `flutter_contacts` provides structured `Contact`
objects with typed phone numbers, built-in permission request/check methods, and
active maintenance — preferred over `contacts_service` (less maintained) and
`fast_contacts` (smaller community).

---

### 2. Permission flow state machine

The contact-picker UI must handle every platform permission state. The full
state machine is:

```
not_determined --> [requestPermission()] --> granted
not_determined --> [requestPermission()] --> denied
not_determined --> [requestPermission()] --> denied_permanently  (Android "don't ask again")

denied        --> [requestPermission()] --> granted              (user changes mind in prompt)
denied        --> [openSettings()]      --> granted              (user enables in Settings)

denied_permanently --> [openSettings()] --> granted              (only path on Android)
```

**Platform differences:**

- **iOS** does not expose a `denied_permanently` state. Once denied, the sole
  recovery path is Settings. The provider should treat iOS `denied` identically
  to `denied_permanently` for CTA purposes (always show "Open Settings").
- **Android** surfaces the "don't ask again" checkbox, which transitions
  permission to `denied_permanently`. The provider must distinguish `denied`
  from `denied_permanently` so the UI can show the correct CTA:
  - `denied` — show "Grant Permission" (re-prompt is still possible).
  - `denied_permanently` — show "Open Settings" (re-prompt will be a no-op).

The controller must expose the current permission state so the UI layer can
render the appropriate empty state, CTA button, and fallback to manual entry.

---

### 3. Controller contract (hand-off to PR #32)

Per **ADR-0013** (Contact Matching Strategy), the contact picker is a
self-contained surface. Only the single selected contact crosses the picker
boundary. The controller contract is:

#### 3.1 Exposed surface

```dart
/// The selected contact, or null if nothing is selected.
SelectedContact? get selectedContact;

/// Clears the current selection.
void clearSelection();
```

#### 3.2 `SelectedContact` shape

```dart
class SelectedContact {
  final String displayName;
  final List<String> phoneNumbers; // E.164 normalised, Indian numbers only
}
```

- `phoneNumbers` contains **only** E.164 normalised Indian mobile numbers
  (`+91XXXXXXXXXX`).
- Non-Indian numbers are filtered out inside the controller; they never appear
  in `selectedContact`.
- The full device contact list is **never** exposed beyond the picker. Only the
  single selected contact crosses the boundary.

#### 3.3 E.164 normalisation rules

Normalisation is performed **inside the controller** before exposure, because
PR #32 will pass these numbers to Firestore queries where canonical format is
required.

| Raw input | Normalised output | Rule |
|---|---|---|
| `9876543210` | `+919876543210` | Bare 10-digit Indian mobile: prepend `+91` |
| `+919876543210` | `+919876543210` | Already prefixed: no change (no double-prefix) |
| `+91 98765 43210` | `+919876543210` | Strip spaces |
| `098-7654-3210` | `+919876543210` | Strip leading zero, hyphens, parentheses; prepend `+91` |
| `(098) 7654 3210` | `+919876543210` | Strip parentheses, spaces, leading zero; prepend `+91` |
| `+447911123456` | *(filtered out)* | Non-Indian number: excluded from `phoneNumbers` |

#### 3.4 What the boundary-contract test asserts

The boundary-contract test (Phase 5, item 6 per ADR-0013) will:

1. Mock the contact-picker return value with a contact containing mixed raw
   formats and non-Indian numbers.
2. Assert that `selectedContact.phoneNumbers` contains only E.164 normalised
   Indian numbers.
3. Assert that the full contact list is not accessible outside the picker
   controller.
4. Assert that `clearSelection()` sets `selectedContact` to null.

---

### 4. Privacy and PII guards

Reference: `docs/design/07-technical/pii-handling.md` (created in PR #31,
linked to ADR-0013).

Key constraints that the implementation must satisfy:

1. **Contact data is scoped to the picker route.** The controller holding the
   contact list is disposed when the picker is dismissed. No reference to the
   full contact list persists beyond the picker lifecycle.

2. **No PII in telemetry or diagnostics.** Contact names, phone numbers, and
   any other PII must never appear in:
   - Crashlytics breadcrumbs.
   - Analytics event parameters.
   - Client-side logs (`debugPrint`, `log`, `print`).
   - Persistent caches (SharedPreferences, Hive, or any on-disk store).

3. **Telemetry event names are acceptable; PII parameters are not.** For
   example, `contact_selected` with no parameters is compliant;
   `contact_selected` with `{'phone': '+919876543210'}` is a blocking defect.

4. **Enforcement:** the PII-leak test at `test/features/friends/pii_leak_test.dart`
   mocks analytics, Crashlytics, and logging providers and asserts that no PII
   appears in any captured output. This test must pass before any PII-touching
   code is merged.

---

### 5. Testing strategy for permission flow

#### 5.1 Test seam

Permission state is OS-level and cannot be perfectly faked in widget tests.
The test seam is a `ContactPermissionProvider` that wraps the package's
permission API. In tests, this provider is overridden with a mock that returns
the desired permission state.

```dart
// Production: delegates to flutter_contacts
final contactPermissionProvider = Provider<ContactPermissionService>((ref) {
  return FlutterContactsPermissionService();
});

// Test: returns whatever state the test specifies
final contactPermissionProvider = Provider<ContactPermissionService>((ref) {
  return MockContactPermissionService(state: PermissionState.denied);
});
```

#### 5.2 Widget tests

Widget tests use the mock provider to exercise all UI states:

- `not_determined` — initial prompt is shown.
- `granted` — contact list is rendered.
- `denied` — fallback state with "Grant Permission" CTA and manual entry path.
- `denied_permanently` — fallback state with "Open Settings" CTA and manual
  entry path.

#### 5.3 Integration tests

- **Android emulator:** permissions can be pre-granted via
  `adb shell pm grant <package> android.permission.READ_CONTACTS`. Use this to
  test the `granted` path end-to-end.
- **iOS simulator:** contact permission granting is limited in automation.
  Document what is and is not testable in the test file header comment.
- **Emulator requirement:** all integration tests use
  `scripts/dev/start-emulators.sh` (never raw `firebase emulators:start`).
  This is per invariant 4 (single Firebase project) and the emulator
  conventions established in PR #30.

---

### 6. Coverage gate posture

- `lib/features/friends/**` is a new feature folder created by this PR.
- The CI coverage gate from PR #30 applies from the moment the folder exists.
- **Target: at least 70% per-folder coverage from this PR's first merge.**
- The gate is a floor, not a target. Design tests for behaviour correctness,
  not coverage numbers. Coverage is a lagging indicator of test quality, not a
  leading one.
- If a code path is genuinely untestable (e.g. platform-specific permission
  prompts that cannot be automated in CI), document the exemption in
  `docs/design/07-technical/coverage-exemptions.md` with architect sign-off
  before merging.

---

### 7. Cross-references

| Artefact | Location |
|---|---|
| ADR-0013 (contact matching strategy) | `.github/shared/decision-log.md` |
| PII handling reference | `docs/design/07-technical/pii-handling.md` |
| Parent user story | `docs/sprint-zero/stories/FR-FR-01-add-friend.md` |
| Link/invite flow (PR #32 hand-off) | `docs/sprint-zero/stories/FR-FR-02-link-or-invite-friend.md` |
