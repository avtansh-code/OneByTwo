# FR-FR-01 (Matching): User Lookup and Friendship Creation

> Sub-story of FR-FR-01. Covers user lookup via Cloud Function gateway and
> friendship creation delivered in PR #32.

---

## SRS Requirement ID(s)

FR-FR-01 (SRS section 4.3)

## Relevant SRS Sections

- Section 4.3 — Friends (1-to-1)
- Section 4.11 — Sharing (Invariant 3 — system share sheet)
- Section 5.10 — Observability
- Section 6.4 — Loading, empty, and error states
- Section 7.3 — Key architectural decisions
- Section 9.1 — Environments and local testing

## Architecture Decision Reference

- **ADR-0013** — Contact Matching Strategy (Local Intersection). Establishes that
  contacts are intersected locally; no bulk upload of phone numbers to the server.
- **ADR-0014** — Cloud Function Gateway (`lookupUserByPhoneNumber`). Matching is
  performed via a callable Cloud Function `lookupUserByPhoneNumber` rather than a
  direct Firestore query against the `users` collection. The function accepts a
  single E.164 phone number and returns either the matched user's public profile
  or a not-found result.

This story consumes the handoff contract established by the UI half (PR #31):

```
selectedContact: { displayName: String, phoneNumbers: List<String> }
```

Phone numbers are E.164 normalised by the contact picker controller. Contact data
never leaves the device in bulk; only the selected contact's phone number is sent
to the Cloud Function for lookup.

## Priority

**P0 — Must have**

## Story Points

3

## User Story

As a **signed-in user**,
I want **the app to look up the selected contact via a Cloud Function and either
create a friendship or let me invite them**,
so that **I can add friends regardless of whether they already use One By Two**.

## Preconditions

1. User is authenticated and has completed profile setup.
2. The contact picker (PR #31) is merged and the handoff callback is available.
3. The callable Cloud Function `lookupUserByPhoneNumber` is deployed and accessible
   (ADR-0014).
4. The `friendships/{friendshipId}` schema is defined per the Firestore schema doc.

---

## Acceptance Criteria

### AC-1 — Lookup and loading indicator

> Given the user has selected a contact via the picker (PR #31 flow)
> When the matching flow runs
> Then the app calls the `lookupUserByPhoneNumber` Cloud Function (per ADR-0014)
> And a loading indicator is displayed until the function returns

### AC-2 — Existing user matched, friendship created (happy path)

> Given the contact is matched as an existing One By Two user
> When the lookup function returns the matched user's profile
> Then the app shows a confirmation card with the matched user's display name and
> photo, and an "Add as friend" CTA
> When the user taps "Add as friend"
> Then a `friendships/{friendshipId}` document is created with both users in
> `memberIds` and the friendship balance initialised to zero (integer paise)
> And the screen navigates to SCR-11 (Friend Detail)

### AC-3 — Non-user contact triggers invite flow

> Given the contact is NOT a One By Two user
> When the lookup function returns a not-found result
> Then the app shows an "invite" card with the contact's display name and a
> "Send invite" CTA
> When the user taps "Send invite"
> Then the system share sheet opens (Invariant 3)

### AC-4 (Negative) — Self-add rejected

> Given the user selects a contact whose phone number matches their own
> authenticated phone number
> When the matching flow begins
> Then the app blocks the action with an inline error "You cannot add yourself
> as a friend." BEFORE calling the lookup function
> And no network request is made

### AC-5 (Negative) — Duplicate friendship rejected

> Given the user selects a contact with whom they already have a friendship
> When the match is returned
> Then the app does NOT create a duplicate friendship document
> And the app navigates to the existing friendship on SCR-11

### AC-6 (Negative) — Lookup failure

> Given the lookup function fails due to a network error or function error
> When the error response is received
> Then the app shows an error state with a "Retry" option
> And friendship creation does NOT proceed

### AC-7 (Negative) — Rate-limited

> Given the lookup function rate-limits the user (HTTP 429 or equivalent)
> When the rate-limit response is received
> Then the app shows a "Please try again later" message
> And no retry is automatically attempted

### AC-8 (Negative) — Share sheet dismissed without sharing

> Given the invite share sheet is open
> When the user dismisses it without selecting a channel
> Then the app returns to the Add Friend screen with no confirmation
> And the contact is not marked as invited

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No money writes in this story. Friendship balance is initialised to zero (integer paise). |
| 2 | `simplifiedBalances` server-maintained | PARTIAL. The `friendships` document contains a `simplifiedBalances` field, initialised by the Cloud Function (not written by the client). Verify server-set on creation and client-read-only thereafter. |
| 3 | System share sheet only | **APPLIES.** The invite path must use the system share sheet exclusively. No app-specific share targets. |
| 4 | Single Firebase project | APPLIES. Integration tests use the emulator wrapper. |

**PII handling:** APPLIES. Phone numbers cross the network ONLY to the Cloud
Function, ONLY in E.164 form, and are never stored server-side except in hashed
audit logs.

---

## Telemetry Events

| Event Name | Parameters | Trigger |
|---|---|---|
| `friend_lookup_started` | hashed phone number identifier (NOT raw) | Lookup function called |
| `friend_lookup_matched` | matched userId hash (NOT raw display name or phone) | Match found |
| `friend_lookup_unmatched` | none | No match found |
| `friend_lookup_failed` | error code | Lookup function error |
| `friend_lookup_rate_limited` | none | Rate limit hit |
| `friend_invite_share_sheet_opened` | none | Share sheet opened for invite |
| `friend_added` | friendshipId hash | Friendship document created |
| `friend_add_blocked_self` | none | Self-add attempt blocked |
| `friend_add_blocked_duplicate` | none | Duplicate friendship blocked |

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/09-12-friends.md` (SCR-10, SCR-11) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`friendships/{friendshipId}`) |
| PII handling | `docs/design/07-technical/pii-handling.md` |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing.
- [ ] Integration tests passing against Firebase Emulator Suite.
- [ ] QA reviewed and verified acceptance criteria (including all negative cases).
- [ ] Telemetry events in place and firing correctly (no raw PII in event parameters).
- [ ] Invariant 2 compliance verified (`simplifiedBalances` server-set, client-read-only).
- [ ] Invariant 3 compliance verified (system share sheet only).
- [ ] Accessibility verified.
- [ ] Documentation updated (if applicable).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) — N/A, balance initialised to zero paise.
- [ ] No client writes to `simplifiedBalances` (invariant 2) — compliant, field initialised by Cloud Function.
- [ ] Uses system share sheet only (invariant 3) — compliant, invite uses system share sheet.
- [ ] Single Firebase project (invariant 4) — compliant, tests use emulator suite.

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Functions Dev | Cloud Function `lookupUserByPhoneNumber` implementation and tests |
| Flutter Dev | Matching repository, friendship repository, controller, UI, telemetry |
| Architect | Security rules updates, schema review, invariant compliance |
| QA | All matching scenarios, rules tests, PII-leak tests |
