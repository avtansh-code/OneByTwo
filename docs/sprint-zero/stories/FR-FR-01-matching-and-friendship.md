# FR-FR-01 (Matching): User Lookup and Friendship Creation

> Sub-story of FR-FR-01. Covers user lookup and friendship creation delivered in
> PR #32. This story will be refined at PR #32 kickoff.

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

ADR-0013 — Contact Matching Strategy (Local Intersection). This story consumes
the hand-off contract established by the UI half (PR #31):

```
selectedContact: { displayName: String, phoneNumbers: List<String> }
```

Matching is performed by a single Firestore read against the `users` collection,
querying by `phoneNumber`. Contact data never leaves the device in bulk.

## Priority

**P0 — Must have**

## Story Points

2

## User Story

As a **signed-in user**,
I want **the app to look up the selected contact and either create a friendship
or let me invite them**,
so that **I can add friends regardless of whether they already use One By Two**.

## Preconditions

1. User is authenticated and has completed profile setup.
2. The contact picker (PR #31) is merged and the hand-off callback is available.
3. The `users` collection is queryable by `phoneNumber` (established in PR #9).
4. The `friendships/{friendshipId}` schema is defined per the Firestore schema doc.

---

## Acceptance Criteria

### AC-1 — Existing user matched and friendship created (happy path)

> Given the user selects a contact whose phone number matches a registered
> One By Two user
> When the matching query completes
> Then a `friendships` document is created linking the two users
> And the user is navigated to SCR-11 (Friend Detail)
> And `friend_added` fires with `target_is_existing_user: true`

### AC-2 — Non-user contact triggers invite flow

> Given the user selects a contact whose phone number does not match any
> registered user
> When the matching query completes
> Then an invite confirmation dialog appears (per SCR-10 state 2)
> And on confirmation, the system share sheet opens (Invariant 3)
> And `friend_invite_sent` fires

### AC-3 (Negative) — Self-add rejected

> Given the user selects a contact whose phone number is their own
> When the matching query completes
> Then an inline error "You cannot add yourself as a friend." appears
> And no friendship document is created

### AC-4 (Negative) — Duplicate friendship rejected

> Given the user selects a contact who is already a friend
> When the matching query completes
> Then an inline error "You are already friends with [Display name]." appears
> And no duplicate friendship document is created

### AC-5 (Negative) — Share sheet dismissed without sharing

> Given the invite share sheet is open
> When the user dismisses it without selecting a channel
> Then the app returns to the Add Friend screen with no confirmation
> And the contact is not marked as invited

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No money in this story. |
| 2 | `simplifiedBalances` server-maintained | N/A. Friendship creation does not write to `simplifiedBalances`. |
| 3 | System share sheet only | **Applicable.** The invite flow must use the system share sheet exclusively. |
| 4 | Single Firebase project | Applicable. Integration tests use the emulator wrapper. |

---

## Telemetry Events

| Event Name | Parameters | Trigger |
|---|---|---|
| `friend_added` | `method: "contacts"`, `target_is_existing_user: bool` | Friendship document created |
| `friend_invite_sent` | `method: "contacts"` | System share sheet opened for invite |
| `friend_add_self_rejected` | none | Self-add attempt blocked |
| `friend_add_duplicate_rejected` | none | Duplicate friendship attempt blocked |

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
- [ ] QA reviewed and verified acceptance criteria (including negative cases).
- [ ] Telemetry events in place and firing correctly.
- [ ] Invariant 3 compliance verified (system share sheet only).
- [ ] Accessibility verified.
- [ ] Documentation updated (if applicable).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) -- N/A, no monetary values.
- [ ] No client writes to `simplifiedBalances` (invariant 2) -- N/A.
- [ ] Uses system share sheet only (invariant 3) -- compliant, invite uses system share sheet.
- [ ] Single Firebase project (invariant 4) -- compliant, production only.

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Matching logic, friendship document creation, invite flow, Riverpod wiring |
| Functions Dev | Review of any Cloud Function implications (friendship triggers) |
| Architect | Schema review, security rules for `friendships`, invariant compliance |
| QA | Matching scenarios, duplicate/self-add rejection, share sheet testing |

---

## Refinement Note

This story is intentionally lighter than the UI half. It will be refined at
PR #32 kickoff with:

- Detailed Firestore security rules for `friendships` document creation.
- Manual +91 entry path ACs (currently in the parent story but not yet split).
- Edge cases around network failures during the matching query.
- Invite message template copy from the screen spec.
