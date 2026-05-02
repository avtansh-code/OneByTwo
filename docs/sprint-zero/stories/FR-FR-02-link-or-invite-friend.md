# FR-FR-02: Link Existing User or Invite via System Share Sheet

> Implementation-ready user story for resolving a validated +91 phone number
> into either an immediate friendship or an invite handoff through the system
> share sheet.

---

## SRS Requirement ID(s)

FR-FR-02 (SRS section 4.3), FR-SH-01 (SRS section 4.11), FR-SH-02 (SRS section 4.11)

## Relevant SRS Sections

- Section 4.3 — Friends (1-to-1)
- Section 4.11 — Sharing & Support
- Section 5.10 — Observability
- Section 6.4 — Loading, empty, and error states
- Section 7.3 — Key architectural decisions
- Section 7.5 — Security rules
- Section 12.2 — Resolved decisions (system share sheet only)

## Priority

**P0 — Must have**

## Story Points

3

## User Story

As a **signed-in user with a validated friend phone number**,
I want the app to **link an existing One By Two user immediately or invite a non-user via the system share sheet**,
so that **I can connect with friends whether or not they have already installed the app**.

## Preconditions

1. FR-FR-01 has produced a valid canonical `+91XXXXXXXXXX` phone number.
2. User is authenticated and can access the Add Friend flow.
3. Share text, deep link, and fallback app-store URLs are available for the invite
   message.
4. The app uses the single configured Firebase project; pre-merge verification
   runs against the Firebase Emulator Suite.

---

## Acceptance Criteria

### AC-1 — Existing user is linked immediately (happy path)

> Given the validated `+91` phone number belongs to an existing One By Two user
> who is not already my friend
> When lookup completes successfully
> Then a `friendships/{friendshipId}` document is created or returned for the two
> users
> And `memberIds` contains exactly the two user IDs in sorted ascending order
> And I see confirmation that the friend has been added
> And `friend_added` fires with the source method and
> `target_is_existing_user: true`

### AC-2 — Non-user invite uses the system share sheet (happy path)

> Given the validated `+91` phone number does not belong to an existing One By
> Two user
> When I choose Invite
> Then the platform system share sheet opens with a pre-filled message
> And the message contains an install deep link and fallback store URL
> And the OS-presented share targets remain the user's choice
> And `friend_invite_sent` fires

### AC-3 (Negative) — Share sheet dismissed without sending

> Given the system share sheet is open for a non-user invite
> When I dismiss it without selecting any share target
> Then the app returns to the Add Friend flow without crashing or hanging
> And no friendship document is created
> And the contact is not shown as linked

### AC-4 (Negative / Invariant 3) — No app-specific channel targeting

> Given the invite flow is triggered
> When the app presents sharing options
> Then it uses only the platform system share sheet
> And it does not deep-link to, pre-select, or import packages for any specific
> messaging app such as WhatsApp or Telegram

### AC-5 (Negative / Invariant 2) — Client cannot write `simplifiedBalances`

> Given an authenticated client attempts to create or update a friendship document
> with a `simplifiedBalances` payload during the link flow
> When the request reaches Firestore Security Rules
> Then the write is rejected
> And the client must rely on the server-maintained balance projection only

### AC-6 (Negative) — Lookup failure is recoverable

> Given I have submitted a valid `+91` number
> When the lookup request fails because of a network or backend error
> Then I see an error state that explains the lookup could not complete
> And I can retry without re-entering the number

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `friend_added` | `method`, `target_is_existing_user` | Friendship is created successfully |
| `friend_invite_sent` | `method` | System share sheet is opened for a non-user invite |

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No monetary values are created or displayed in this story. |
| 2 | `simplifiedBalances` server-maintained | Applicable. Friendship linking must not write `simplifiedBalances`; that field remains server-maintained and client-read-only. |
| 3 | System share sheet only | Applicable. Invites must open the platform share sheet and must not target any specific messaging app. |
| 4 | Single Firebase project | Applicable. Lookup and friendship creation use the single production Firebase project, with emulator-backed pre-merge verification. |

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
- [ ] No client writes to `simplifiedBalances` (invariant 2) — required for friendship creation and updates.
- [ ] Uses system share sheet only (invariant 3) — required for all invite handoff.
- [ ] Single Firebase project (invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/09-12-friends.md` (SCR-10) |
| Wireframe | `docs/design/04-wireframes/friends-flow.md` (section 2, Add Friend and invite prompt) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`friendships/{friendshipId}`) |
| State management | `docs/design/07-technical/state-management.md` (section 2.3, friends feature) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (section 1.4, friends events) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Existing-user lookup, invite dialog, share-sheet handoff, immediate UI refresh |
| Architect | Firestore/security-rule review, invariant 2 and 3 enforcement, share boundary review |
| QA | Existing-user vs non-user coverage, share-sheet dismissal case, emulator-backed rule checks |
| Designer | Invite copy review, dialog UX, accessibility sign-off |

---

## Technical Notes

- **Firestore collection:** successful linking targets `friendships/{friendshipId}` with `memberIds` as a two-item ascending array and `lastActivityAt` maintained for list ordering; clients must not write `simplifiedBalances`.
- **Providers:** `addFriendNotifierProvider` resolves lookup outcomes and share-sheet launch; `friendsRepositoryProvider` performs user lookup and friendship persistence; `friendsListProvider` should reflect successful adds in real time.
- **Telemetry events:** `friend_added` and `friend_invite_sent` are the core analytics events for this story.
- **Share contract:** invite text must use the platform system share sheet only, include the install deep link plus fallback store URL, and avoid any app-specific integrations.
