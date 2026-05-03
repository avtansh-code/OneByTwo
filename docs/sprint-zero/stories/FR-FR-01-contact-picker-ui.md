# FR-FR-01 (UI): Contact Picker for Add-Friend Flow

> Sub-story of FR-FR-01. Covers the contact picker UI delivered in PR #31.

---

## SRS Requirement ID(s)

FR-FR-01 (SRS section 4.3)

## Relevant SRS Sections

- Section 4.3 — Friends (1-to-1)
- Section 5.6 — Accessibility
- Section 5.10 — Observability
- Section 6.4 — Loading, empty, and error states
- Section 7.3 — Key architectural decisions
- Section 9.1 — Environments and local testing

## Architecture Decision Reference

ADR-0013 — Contact Matching Strategy (Local Intersection). This story implements
the contact picker side of the ADR-0013 contract. The picker exposes only the
selected contact's data to the calling controller:

```
selectedContact: { displayName: String, phoneNumbers: List<String> }
```

Phone numbers are E.164 normalised (e.g. `+91XXXXXXXXXX`). The full contact
list never crosses the picker boundary; only the single selected contact does.

## Priority

**P0 — Must have**

## Story Points

3

## User Story

As a **signed-in user**,
I want to **pick a contact from my device's contact list**,
so that **I can start the add-friend flow without typing a phone number**.

## Preconditions

1. User is authenticated and has completed profile setup.
2. The Friends tab and Add Friend entry point are available.
3. Android declares `READ_CONTACTS` and iOS declares
   `NSContactsUsageDescription`.
4. The app is connected to the single configured Firebase project; pre-merge
   validation runs against the Firebase Emulator Suite (Invariant 4).

---

## Acceptance Criteria

### AC-1 — Permission prompt on first use

> Given the user is on the Friends list screen and taps "Add friend"
> When the contact-picker permission has not yet been granted
> Then the platform's permission prompt appears

### AC-2 — Contact list on permission granted

> Given the user grants contact permission
> When the picker opens
> Then the user's contacts are listed alphabetically with name and phone number
> visible

### AC-3 (Negative) — Permission denied screen

> Given the user denies contact permission
> When the picker opens
> Then a permission-denied screen appears with the copy "Contact access helps
> you find friends already on One By Two." (per SCR-10 state 4) and a button to
> open the OS settings

### AC-4 — Search and filter

> Given the picker is open
> When the user types in the search field
> Then the contact list filters in real time on name and phone number

### AC-5 — Contact selection hand-off

> Given the picker is open
> When the user taps a contact
> Then the controller exposes the selected contact's data via the hand-off
> callback (per ADR-0013's contract:
> `{ displayName: String, phoneNumbers: List<String> }` in E.164 format)
> And the callback is a stub that logs `friend_contact_selected` to telemetry
> and pops the picker

### AC-6 (Negative) — Multiple phone numbers

> Given a contact has multiple phone numbers
> When the user selects them
> Then the user is prompted to choose which number to use

### AC-7 (Negative) — Zero contacts

> Given the user has zero contacts
> When the picker opens
> Then a clear empty-state appears with the title "No contacts found" and the
> subtitle "You can enter a number manually." (per SCR-10 state 3)

### AC-8 (Negative) — Large contact list

> Given the device has more than 1,000 contacts
> When the picker opens
> Then the list virtualises smoothly with no jank

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No money is entered, stored, or displayed in this story. |
| 2 | `simplifiedBalances` server-maintained | N/A. This story does not read or write balance projections. |
| 3 | System share sheet only | N/A for this PR. Applies to PR #32 invite flow. |
| 4 | Single Firebase project | Applicable. Integration tests use the emulator wrapper. |

### PII / Privacy (ADR-0013, pii-handling.md)

**APPLIES.** Contact data is held only in device memory per ADR-0013:

- No Firestore writes of contact data.
- No Analytics event parameters containing PII.
- No Crashlytics breadcrumbs containing contact data.
- Contact data is scoped to the picker route controller; on dismissal the
  controller is disposed and the data falls out of memory.
- Enforcement via `docs/design/07-technical/pii-handling.md` and
  `pii_leak_test.dart`.

---

## Telemetry Events

| Event Name | Parameters | Trigger |
|---|---|---|
| `friend_add_button_tapped` | none | User taps "Add friend" on Friends list |
| `friend_contact_permission_prompted` | none | Permission prompt shown |
| `friend_contact_permission_granted` | none | User grants permission |
| `friend_contact_permission_denied` | none | User denies permission |
| `friend_contact_picker_opened` | none | Picker opens with contacts |
| `friend_contact_search_used` | none (NO search term -- PII) | User types in search |
| `friend_contact_selected` | none (NO phone/name -- PII; only count or hash) | User selects a contact |
| `friend_contact_picker_dismissed_without_selection` | none | User dismisses without selecting |

All events comply with pii-handling.md section 2.4: event names are acceptable;
parameters containing names or phone numbers are forbidden.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/09-12-friends.md` (SCR-10) |
| Wireframe | `docs/design/04-wireframes/friends-flow.md` (section 2, Add Friend) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`friendships/{friendshipId}`) |
| State management | `docs/design/07-technical/state-management.md` (section 2.3, friends feature) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (section 1.4, friends events) |
| PII handling | `docs/design/07-technical/pii-handling.md` |

## Screen-Spec-Driven Copy

All error state, empty state, and permission-denied state copy is lifted
verbatim from the screen spec at `docs/design/06-screen-specs/09-12-friends.md`
SCR-10:

| State | Title | Subtitle |
|---|---|---|
| Empty (no contacts) | "No contacts found" | "You can enter a number manually." |
| Contact Permission Denied | (fallback UI) | "Contact access helps you find friends already on One By Two." |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing.
- [ ] Integration tests passing against Firebase Emulator Suite.
- [ ] QA reviewed and verified acceptance criteria (including negative cases).
- [ ] Telemetry events in place and firing correctly.
- [ ] PII-leak test (`pii_leak_test.dart`) passing.
- [ ] Accessibility verified (semantic labels, screen-reader, focus order).
- [ ] Dark mode checked (WCAG AA contrast ratios).
- [ ] Invariant compliance confirmed (all four).
- [ ] Documentation updated (if applicable).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) -- N/A, no monetary values.
- [ ] No client writes to `simplifiedBalances` (invariant 2) -- N/A.
- [ ] Uses system share sheet only (invariant 3) -- N/A in this PR.
- [ ] Single Firebase project (invariant 4) -- compliant, production only.
- [ ] PII stays on-device (ADR-0013) -- compliant, no PII leaves the picker boundary.

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Contact picker UI, permission handling, search/filter, Riverpod wiring, hand-off callback stub |
| Architect | Permission boundary review, ADR-0013 contract compliance, invariant compliance review |
| QA | Permission-state testing, negative-case verification, PII-leak test, emulator-backed integration coverage |
| Designer | Copy review, empty/error states, accessibility sign-off |

---

## Technical Notes

- **Providers:** `contactPickerNotifierProvider` owns contact loading, search,
  and selection; scoped to the picker route lifecycle per ADR-0013.
- **Hand-off:** the selected contact callback is a stub in this PR. PR #32 will
  replace the stub with the matching and friendship-creation logic.
- **Platform permissions:** the contacts path requires `READ_CONTACTS` on
  Android and `NSContactsUsageDescription` on iOS; denial must show the
  permission-denied fallback UI per SCR-10 state 4.
- **Telemetry events:** all events are PII-safe per pii-handling.md. No contact
  names, phone numbers, or search terms appear in any event parameter.

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
| Matching and friendship (PR #32) | `docs/sprint-zero/stories/FR-FR-01-matching-and-friendship.md` |
