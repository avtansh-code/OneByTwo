# FR-GR-02: Invite Members via picker, phone, or share-sheet link

> Implementation-ready user story for adding members to a group through three
> paths — contact picker, manual +91 phone entry, and a shareable invite link
> surfaced ONLY through the system share sheet (Invariant 3). Creating a link
> mints an invite token (the SR4 model, owned by the Architect).

---

## SRS Requirement ID(s)

FR-GR-02 (SRS section 4.4 — Groups), FR-SH-01 (SRS section 4.11 — system share
sheet; Invariant 3), FR-SH-02 (SRS section 4.11 — shared message includes deep
link and store-fallback URL)

## Relevant SRS Sections

- Section 3.4 — Constraints (system share sheet; single Firebase project)
- Section 4.4 — Groups
- Section 4.11 — Sharing & Support
- Section 5.6 — Accessibility
- Section 5.10 — Observability
- Section 6.3 item 7 — Core screen: Groups list and Group detail
- Section 6.4 — Loading, empty, and error states
- Section 7.5 — Security rules
- Section 12.2 — Sharing scope (Invariant 3)
- Section 13.2 — Story format (this document)

## Priority

**P0 — Must have**

## Story Points

3

## User Story

As a **group admin (or a member with invite permission)**,
I want to **invite people to my group via the contact picker, a +91 phone
number, or a shareable link through the system share sheet**,
so that **the right people can join the group regardless of whether they are
already One By Two users**.

## Preconditions

1. User is authenticated and is a member of the group `groupId` (revocation in
   FR-GR-03 additionally requires the admin).
2. FR-GR-01 has shipped: the group exists with `memberIds` and `adminId`.
3. The **invite-token model (audit SR4)** — a server-owned token document
   carrying at least `token`, `groupId`, `createdBy`, `expiresAt`, and
   `revoked` — is being drafted by the Architect in this same boundary-cleanup
   PR (SR4 plus a forthcoming invite-token ADR). This story consumes that model
   at a high level and does NOT define its own schema.
4. The system share sheet (Invariant 3) is the only outbound sharing surface; no
   app-specific deep links or messaging-app packages.
5. The app uses the single configured Firebase project; pre-merge verification
   runs against the Firebase Emulator Suite.

---

## Acceptance Criteria

### AC-1 — Invite via contact picker

> Given I am on Invite Members (SCR-16) and tap `Select from contacts`
> When I pick a contact whose number is not already a member
> Then an invite is sent for that number (existing One By Two users are handled
> per the matching rules; non-users receive a share-sheet invite)
> And `invite_sent_contact` fires with `is_existing_user`
> And the success snackbar reads `[Name or number] invited to [Group name]`

### AC-2 — Invite via manual +91 phone entry

> Given I enter a 10-digit Indian mobile number starting 6, 7, 8, or 9 in the
> locked-`+91` input (the FR-AU-02 pattern)
> When I tap `Invite`
> Then an invite is sent for that number
> And `invite_sent_phone` fires with `is_existing_user`
> And the phone field clears and the screen remains open for further invites

### AC-3 — Invite via shareable link through the system share sheet (Invariant 3)

> Given I tap `Share Invite Link`
> When the app needs a link it mints (or reuses an active) invite token via the
> server (the SR4 model) and opens the OS share sheet with a message containing
> the invite deep link and the store-fallback URL (FR-SH-02)
> Then the link is surfaced ONLY through the system share sheet — no app-specific
> targeting or messaging-app packages (Invariant 3)
> And `invite_link_shared` fires
> And the destination app is entirely the user's OS-presented choice

### AC-4 (Negative) — Non-member / non-admin cannot create an invite or revoke a link

> Given a user who is not a member of the group (or, for revocation, not the
> admin) attempts to create an invite token or revoke the active link
> When the request reaches the server (Firestore Security Rules and/or the
> invite callable)
> Then it is rejected server-side, not merely hidden in the UI
> And the client surfaces `Could not send invite. Try again.`, or for revocation
> `Only the group admin can revoke the invite link.`
> And no invite token is minted and no member is added

### AC-5 (Negative) — Already-a-member and self-invite are blocked

> Given I try to invite a number that already belongs to a current group member,
> or my own number
> When I submit
> Then no duplicate invitation is sent and an info snackbar reads `This person is
> already a member of [Group name].`, or `You are already a member of this
> group.`
> And the contact picker excludes current member numbers via `excludeNumbers`

### AC-6 — Invite-token creation is server-minted and time-boxed

> Given the share-link path mints an invite token
> When the token is created
> Then it is created via the server-owned invite-token model (SR4) with a
> server-set `expiresAt` (7 days — enforced in FR-GR-03) and `revoked: false`
> And the client never fabricates a token or extends its validity locally

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `invite_members_viewed` | — | Invite Members screen first becomes visible |
| `invite_contact_picker_opened` | — | User taps `Select from contacts` |
| `invite_sent_contact` | `is_existing_user: bool` | Invite sent via the contact picker |
| `invite_sent_phone` | `is_existing_user: bool` | Invite sent via manual phone entry |
| `invite_link_shared` | — | System share sheet opened with the invite link |

The invite-accept / join-side event (a `group_member_added`-style signal) is not
yet enumerated in the telemetry plan; per audit SR8 it must be confirmed before
the join flow ships (Sprint 4 deep-link infrastructure). No raw `groupId` /
`memberId` may appear in any analytics parameter (ADR-0013).

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A — invites carry no monetary value. |
| 2 | `simplifiedBalances` server-maintained | N/A for the invite-send flow; a member joining later triggers the server recompute, which is server-owned. |
| 3 | System share sheet only | Applicable — the invite link must be surfaced exclusively through the OS share sheet; no app-specific deep links or packages. |
| 4 | Single Firebase project | Applicable — writes and any callable target the single production project; emulator-backed pre-merge. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing.
- [ ] Integration tests passing against Firebase Emulator Suite.
- [ ] QA reviewed and verified acceptance criteria (including the negative cases).
- [ ] Telemetry events in place and firing correctly.
- [ ] Accessibility verified (semantic labels, screen-reader, focus order).
- [ ] Dark mode checked (WCAG AA contrast ratios).
- [ ] Invariant compliance confirmed (all four).
- [ ] Documentation updated (if applicable).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (Invariant 1) — N/A in this story.
- [ ] No client writes to `simplifiedBalances` (Invariant 2) — N/A in this story.
- [ ] Uses system share sheet only (Invariant 3) — required; the invite link goes
      through the OS share sheet only, with no app-specific targeting.
- [ ] Single Firebase project (Invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/13-18-groups.md` (SCR-16) |
| Wireframe | `docs/design/04-wireframes/groups-flow.md` (Invite Members) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`groups`; invite-token model pending SR4) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (SCR-16 invite events) |
| Decision log | `.github/shared/decision-log.md` (system-share-sheet decision; forthcoming invite-token ADR per SR4) |
| Invariants | `.github/shared/invariants.md` (Invariant 3) |
| Readiness audit | `docs/audits/sprint-2/05-sprint-3-readiness.md` (SR4, SR7) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | SCR-16 UI (three paths), contact-picker and phone-input reuse, system share-sheet invocation, client calls to the invite-token surface |
| Architect | Invite-token model (SR4) plus rules/callable outline and ADR; Invariant 3 review; `go_router` scope decision (SR7) |
| Functions Dev | Server-side invite-token minting and validation (with the Architect) |
| QA | All three paths, negative cases (non-member, duplicate, self-invite), emulator-backed rules tests |
| Designer | Invite-link card and member-row components (audit SR3), accessibility, dark mode |

---

## Technical Notes

- **Reuse existing inputs.** Use `OBTContactPicker` and `OBTPhoneInput`, and the
  +91 validation pattern from FR-AU-02. The contact picker passes
  `excludeNumbers: currentMemberPhones`.
- **Consume, do not redefine, the invite-token model.** The invite-token schema,
  rules, and minting/validation mechanism are owned by the Architect / Functions
  Dev (audit SR4) and drafted in this boundary-cleanup PR. Reference it at a high
  level (`token`, `groupId`, `createdBy`, `expiresAt`, `revoked`) and do not
  invent a conflicting schema.
- **Invariant 3.** The share path must use the system share sheet only (via
  `share_plus`); no WhatsApp / Telegram targeting or packages.
- **Routing.** The invite and members screens and the universal-link
  `/invite/group/:inviteToken` flow are route-based, so the
  `go_router`-vs-imperative decision should be made before this story starts
  (audit SR7).
- **Scope boundary.** The join / accept side (resolving an invite link into
  membership, including cold start) depends on Sprint 4 deep-link infrastructure.
  This story covers minting, sharing, and the in-app invite paths — not link
  resolution.
