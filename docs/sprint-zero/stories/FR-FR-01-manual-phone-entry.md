# FR-FR-01: Manual Phone Number Entry for Friend Add

> Sub-story of FR-FR-01. Covers the "Enter Number" tab (Path B) on the Add
> Friend screen, delivered in PR #34. The contact picker path (Path A) was
> delivered in PR #31; the downstream matching and friendship creation logic
> was delivered in PR #32.

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

- **ADR-0013** — Contact Matching Strategy (Local Intersection). Manual entry
  bypasses the contact picker entirely; the user-supplied number is normalised
  to E.164 and bridged into the same `SelectedContact` contract consumed by
  `MatchAndInviteController` (PR #32).

## Priority

**P0 — Must have**

## Story Points

2

## User Story

As a **signed-in user on the Add Friend screen**,
I want to **type a 10-digit Indian mobile number manually**,
so that **I can add friends without granting contact permission or when the
friend is not in my contacts**.

## Preconditions

1. User is authenticated and on the Add Friend screen (SCR-10).
2. The phone validator (`lib/core/validators.dart`) and
   `IndianPhoneInputFormatter` are available.
3. The `MatchAndInviteController` from PR #32 handles all downstream matching,
   friendship creation, and invite flows.

---

## Acceptance Criteria

### AC-1 — Segmented control entry point

> Given the user navigates to the Add Friend screen (SCR-10)
> When the screen loads
> Then a segmented control is visible with "From Contacts" (selected by default)
> and "Enter Number" tabs
> And tapping "Enter Number" reveals a phone number input with locked +91 prefix

### AC-2 — Valid number submission (happy path)

> Given the user is on the "Enter Number" tab
> And has entered a valid 10-digit number (starts with 6-9)
> When they tap "Add Friend"
> Then the normalised E.164 number (+91XXXXXXXXXX) is passed to
> MatchAndInviteController.performLookup
> And the downstream matching flow proceeds identically to the contact picker
> path (FR-FR-01 Path A)

### AC-3 — Self-add guard

> Given the user enters their own phone number
> When they tap "Add Friend"
> Then the self-add guard in MatchAndInviteController triggers
> And the user sees the same error UI as in the contact picker path

### AC-4 (Negative) — Invalid input validation

> Given the user enters an invalid number (fewer than 10 digits, non-numeric,
> or does not start with 6-9)
> When the input is incomplete
> Then the "Add Friend" button remains disabled
> And when they somehow submit invalid input, an inline validation error appears
> per the screen spec

### AC-5 (Negative) — Lookup failure

> Given the user enters a valid number
> When the Cloud Function lookup fails
> Then the same error UI from the contact picker path appears (via
> MatchAndInviteController)

### AC-6 — Permission-denied fallback

> Given the user has denied contact permission
> When the Add Friend screen shows the permission-denied state
> Then a manual phone entry field with +91 prefix is available as a fallback
> And the user can add friends by typing a number even without contact access

### AC-7 — No PII in telemetry

> Given the user enters a phone number and submits
> When telemetry events fire
> Then no phone number, contact name, or other PII appears in event parameters

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `add_friend_screen_viewed` | `entry_path: "contacts"` (the segmented control defaults to "From Contacts") | Screen becomes visible |
| `add_friend_tab_switched` | `tab: "contacts"` \| `"manual"`, optional `source: "permission_denied"` when reached via the Type-a-number-instead fallback | User taps a different segmented-control tab, or the fallback link in the permission-denied view |
| `friend_manual_entry_opened` | None (no PII) | The manual-entry tab becomes the active tab (either via tab switch or the permission-denied fallback) |
| `friend_manual_entry_submitted` | None (no PII) | User taps Add Friend with valid input |
| `friend_manual_entry_validation_failed` | `error_code: "empty"` \| `"non_numeric"` \| `"too_short"` \| `"too_long"` \| `"invalid_start_digit"` \| `"invalid_number"` (no PII; classified by `_classifyError` in the tab widget) | Validation fails on submit |

Downstream events from PR #32 (`friend_added`, `friend_invite_sent`, etc.)
fire from the shared controller.

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No monetary values are created or displayed in this story. |
| 2 | `simplifiedBalances` server-maintained | Applies indirectly via friendship creation path — same protections as FR-FR-01 Path A. |
| 3 | System share sheet only | Applies via the no-match invite path — same path as FR-FR-01 Path A. |
| 4 | Single Firebase project | Applicable. The flow uses the single production Firebase configuration, with pre-merge verification on the Emulator Suite only. |

### PII / Privacy (ADR-0013, pii-handling.md)

**APPLIES.** The manually entered phone number is PII:

- No Analytics event parameters containing PII.
- No Crashlytics breadcrumbs containing phone numbers.
- No client-side logs (`debugPrint`, `log`, `print`) containing phone numbers.
- Enforcement via `docs/design/07-technical/pii-handling.md` and
  `pii_leak_test.dart`.

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

- [ ] Money values are integer paise (invariant 1) — N/A, no monetary values.
- [ ] No client writes to `simplifiedBalances` (invariant 2) — applies via shared downstream path.
- [ ] Uses system share sheet only (invariant 3) — applies via shared invite path.
- [ ] Single Firebase project (invariant 4) — compliant, production only.
- [ ] PII stays off-server and out of telemetry (ADR-0013) — compliant, no PII leaves the device.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/09-12-friends.md` (SCR-10, Path B) |
| Wireframe | `docs/design/04-wireframes/friends-flow.md` (section 2, Add Friend) |
| PII handling | `docs/design/07-technical/pii-handling.md` |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (section 1.4, friends events) |
| State management | `docs/design/07-technical/state-management.md` (section 2.3, friends feature) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | ManualPhoneEntryTab widget, AddFriendScreen segmented control, PermissionDeniedView fallback |
| Architect | Entry-point shape confirmation, validator reuse verification |
| QA | Widget tests, boundary-contract test, smoke matrix |
| Designer | Visual review against SCR-10 wireframe |

---

## Technical Notes

- **Validator reuse:** `validateIndianMobile()` from `lib/core/validators.dart`
  — no new validator is introduced.
- **Input formatter reuse:** `IndianPhoneInputFormatter` from
  `lib/features/auth/presentation/widgets/` — the same formatter used on the
  auth screens.
- **Controller reuse:** `MatchAndInviteController` from PR #32 handles all
  downstream states (lookup, match, invite, self-add guard, error).
- **SelectedContact bridge:** Manual entry creates
  `SelectedContact(displayName: phoneNumber, phoneNumbers: ['+91$digits'])` to
  bridge into the existing controller interface. This avoids a parallel code
  path for the downstream flow.
- **Segmented control:** the Add Friend screen uses a `SegmentedButton`
  (Material 3) to switch between "From Contacts" and "Enter Number". The
  default selection is "From Contacts".
- **Permission-denied fallback:** when the user has denied contact permission,
  the permission-denied state includes the manual entry field directly,
  ensuring the user is never blocked from adding friends.

---

## Cross-references

| Artefact | Location |
|---|---|
| Parent user story | `docs/sprint-zero/stories/FR-FR-01-add-friend.md` |
| Contact picker UI (PR #31) | `docs/sprint-zero/stories/FR-FR-01-contact-picker-ui.md` |
| Matching and friendship (PR #32) | `docs/sprint-zero/stories/FR-FR-01-matching-and-friendship.md` |
| Link or invite (PR #32) | `docs/sprint-zero/stories/FR-FR-02-link-or-invite-friend.md` |
| ADR-0013 (contact matching strategy) | `.github/shared/decision-log.md` |
| PII handling reference | `docs/design/07-technical/pii-handling.md` |

---

## Architect Notes

### Entry-point shape

**Option 3 — Segmented control within SCR-10**, combined with **Option 1 —
permission-denied fallback**.

The screen spec (SCR-10) mandates a segmented control at the top of the Add
Friend screen with two segments: "From Contacts" (Path A, default) and "Enter
Number" (Path B). This PR implements Path B.

Additionally, State 4 (Permission Denied) includes a manual phone entry field
as a fallback, ensuring the user is never completely blocked from adding
friends when contact permission is denied.

### Validator reuse

`validateIndianMobile()` at `lib/core/validators.dart` is the ONLY validator.
It is already in a shared location (`lib/core/`) and requires no relocation.
Do NOT write a new validator or a friends-specific wrapper.

`IndianPhoneInputFormatter` at
`lib/features/auth/presentation/widgets/india_phone_input_formatter.dart` is
reused for input formatting. It is currently in the auth feature folder. A
future chore may relocate it to `lib/core/widgets/` but that is NOT in scope
for this PR — importing across features is acceptable per the conventions doc.

### Controller reuse

The `MatchAndInviteController.performLookup(dynamic contact)` method accepts
a `SelectedContact`. The manual entry path creates:

```dart
SelectedContact(
  displayName: '+91$digits',
  phoneNumbers: ['+91$digits'],
)
```

This bridges manual entry into the existing controller without subclassing,
forking, or adding new methods. The `displayName` is set to the phone number
since there is no contact name available for manual entry.

The `MatchAndInviteNoMatch` state uses `contactDisplayName` for the invite
prompt. For manual entry, this will display the phone number
(e.g. "+919876543210 is not on One By Two yet."), which is acceptable per
the screen spec.

### No new ADR required

This PR is pure pattern reuse. The segmented control is a UI concern; the
matching architecture (ADR-0013, ADR-0014) is unchanged.

### Coverage threshold

`lib/features/friends/presentation/widgets/manual_phone_entry_tab.dart` and
the refactored `AddFriendScreen` are subject to the >= 70% per-feature
coverage gate. Plan tests accordingly.

### Navigation wiring

`FriendsListScreen._onAddFriendTapped` currently pushes `ContactPickerScreen`.
If the class is renamed to `AddFriendScreen`, update this import. The route
structure does not change.
