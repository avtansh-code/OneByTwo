> **Split notice:** This parent story has been split into two sub-stories for
> implementation purposes:
>
> - **FR-FR-01 (UI):** `FR-FR-01-contact-picker-ui.md` — Contact picker UI (PR #31)
> - **FR-FR-01 (Matching):** `FR-FR-01-matching-and-friendship.md` — User lookup and friendship creation (PR #32)
>
> This file is retained as the parent story for traceability. The sub-stories
> are the implementation-ready artefacts.

---

# FR-FR-01: Add Friend by Contact Picker or +91 Number

> Implementation-ready user story for starting the add-friend flow from either
> the device contact picker or manual +91 phone-number entry.

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

## Priority

**P0 — Must have**

## Story Points

3

## User Story

As a **signed-in user**,
I want to **add a friend by picking a contact or entering a +91 mobile number manually**,
so that **I can start a friendship flow without leaving the app**.

## Preconditions

1. User is authenticated and has completed profile setup.
2. The Friends tab and Add Friend entry point are available.
3. For the contacts path, Android declares `READ_CONTACTS` and iOS declares
   `NSContactsUsageDescription`.
4. The app is connected to the single configured Firebase project; pre-merge
   validation runs against the Firebase Emulator Suite.

---

## Acceptance Criteria

### AC-1 — Add Friend from contact picker (happy path)

> Given I open the Add Friend screen and grant contact access
> When I select a contact with a valid Indian mobile number
> Then the app normalises the selected number to the canonical `+91XXXXXXXXXX`
> format
> And the add-friend flow proceeds without requiring me to re-type the number
> And `contact_permission_granted` fires if the permission was granted in-session

### AC-2 — Add Friend by manual number entry (happy path)

> Given I am on the manual entry path on the Add Friend screen
> When I enter a valid 10-digit Indian mobile number after the fixed `+91`
> prefix and tap Add Friend
> Then the app starts the friend lookup flow for that canonical phone number
> And `friend_search_started` fires

### AC-3 (Negative) — Invalid phone number is blocked

> Given I am on the manual entry path
> When I enter fewer than 10 digits, non-numeric characters, an invalid Indian
> mobile prefix, or a non-`+91` number
> Then I see an inline validation error
> And the add action does not start lookup
> And no Firestore write occurs

### AC-4 (Negative) — Contact permission denied or revoked

> Given I deny contact access, or have previously denied it in system settings
> When I try to use the contact-picker path
> Then the app shows a fallback state explaining that contact access is needed
> for the contact list
> And manual `+91` number entry remains available
> And I can re-request permission or open system settings
> And `contact_permission_denied` fires

### AC-5 (Negative) — Self and duplicate entries are rejected

> Given I enter my own phone number or a number that already belongs to an
> existing friendship
> When I attempt to continue
> Then the app shows an inline error explaining the problem
> And the flow does not create a duplicate or invalid friend request

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `add_friend_screen_viewed` | `entry_path` (`contacts` / `manual`) | Add Friend screen becomes visible |
| `friend_search_started` | — | User starts a friend lookup from manual entry or contact selection |
| `contact_permission_granted` | — | User grants contact access on the Add Friend screen |
| `contact_permission_denied` | — | User denies or revokes contact access |

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No money is entered, stored, or displayed in this story. |
| 2 | `simplifiedBalances` server-maintained | N/A. This story does not read or write balance projections. |
| 3 | System share sheet only | N/A here. Invite handoff is covered by FR-FR-02. |
| 4 | Single Firebase project | Applicable. The flow must use the single production Firebase configuration, with pre-merge verification on the Emulator Suite only. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing.
- [ ] Integration tests passing against Firebase Emulator Suite.
- [ ] QA reviewed and verified acceptance criteria (including negative cases).
- [ ] Telemetry events in place and firing correctly.
- [ ] Accessibility verified (semantic labels, screen-reader, focus order).
- [ ] Dark mode checked (WCAG AA contrast ratios).
- [ ] Invariant compliance confirmed (all four).
- [ ] Documentation updated (if applicable).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) — N/A, no monetary values.
- [ ] No client writes to `simplifiedBalances` (invariant 2) — N/A.
- [ ] Uses system share sheet only (invariant 3) — N/A in this story.
- [ ] Single Firebase project (invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/09-12-friends.md` (SCR-10) |
| Wireframe | `docs/design/04-wireframes/friends-flow.md` (section 2, Add Friend) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`friendships/{friendshipId}`) |
| State management | `docs/design/07-technical/state-management.md` (section 2.3, friends feature) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (section 1.4, friends events) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Add Friend screen UI, contact picker integration, manual phone validation, Riverpod wiring |
| Architect | Permission boundary review, Firestore access constraints, invariant compliance review |
| QA | Permission-state testing, negative-case verification, emulator-backed integration coverage |
| Designer | Copy review, empty/error states, accessibility sign-off |

---

## Technical Notes

- **Firestore collection:** this story prepares input for the `friendships/{friendshipId}` flow but does not require any client write to `simplifiedBalances`; friendship creation outcomes are completed by FR-FR-02.
- **Providers:** `addFriendNotifierProvider` owns contact selection, manual entry, validation, and lookup initiation; `friendsRepositoryProvider` supplies lookup helpers.
- **Telemetry events:** `add_friend_screen_viewed`, `friend_search_started`, `contact_permission_granted`, and `contact_permission_denied` are the minimum analytics events for this story.
- **Platform permissions:** the contacts path requires `READ_CONTACTS` on Android and `NSContactsUsageDescription` on iOS; denial must never block manual `+91` entry.
