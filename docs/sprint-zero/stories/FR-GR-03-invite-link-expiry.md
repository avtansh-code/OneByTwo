# FR-GR-03: Invite-link 7-day Expiry and Admin Revocation

> Implementation-ready user story for the lifecycle guards on a group invite
> link: it expires 7 days after creation and the admin can revoke it at any time.
> Both guards MUST be enforced server-side (Firestore rules reading the invite
> token's `expiresAt` / `revoked`, or a callable), never UI-only.

---

## SRS Requirement ID(s)

FR-GR-03 (SRS section 4.4 — Groups). Related: FR-GR-02 (invite paths), FR-SH-01
(system share sheet — Invariant 3).

## Relevant SRS Sections

- Section 4.4 — Groups
- Section 4.11 — Sharing & Support
- Section 5.10 — Observability
- Section 6.4 — Loading, empty, and error states
- Section 7.5 — Security rules
- Section 12 — Risks, assumptions, resolved decisions
- Section 13.2 — Story format (this document)

## Priority

**P0 — Must have**

## Story Points

3

## User Story

As a **group admin**,
I want **invite links to expire after 7 days and to be revocable on demand,
enforced on the server**,
so that **a leaked or stale link cannot be used to join my group after it should
no longer work**.

## Preconditions

1. FR-GR-02 has shipped: the share-link path mints invite tokens via the SR4
   model.
2. The **invite-token model (audit SR4)** carries at least `token`, `groupId`,
   `createdBy`, `expiresAt`, and `revoked`, and is owned and drafted by the
   Architect in this PR. This story relies on those fields; it does not define
   new ones.
3. Cloud Functions are region-pinned to `asia-south1`; any callable used for
   enforcement runs there.
4. The app uses the single configured Firebase project; pre-merge verification
   (rules tests and any callable tests) runs against the Firebase Emulator Suite.

---

## Acceptance Criteria

### AC-1 — A link older than 7 days is rejected (server-side)

> Given an invite token whose `expiresAt` is in the past (more than 7 days after
> creation)
> When someone attempts to join the group using that token
> Then the server rejects the join — via Firestore Security Rules reading
> `expiresAt` and/or the invite callable — and no member is added
> And the rejection is enforced server-side, not by hiding the UI
> And the joiner sees a graceful `This invite link has expired.` message

### AC-2 — Admin revocation invalidates a link

> Given I am the group admin viewing an active link on SCR-16
> When I confirm `Revoke Link`
> Then the invite token is marked `revoked` on the server and the active-link
> section disappears
> And `invite_link_revoked` fires
> And the success snackbar reads `Invite link revoked`

### AC-3 (Negative) — A revoked or expired token cannot add a member

> Given a token that is `revoked == true` OR past `expiresAt`
> When a join is attempted with that token, including a crafted request that
> bypasses the UI
> Then the server refuses to add the joiner to `memberIds` and returns a
> permission / expired error
> And `memberIds` is unchanged
> And no client-side bypass is possible because the guard lives in the rules or
> callable, not the UI

### AC-4 (Negative) — Non-admin cannot revoke

> Given a non-admin member, or a non-member, attempts to revoke the link
> When the request reaches the server
> Then it is rejected server-side and the link remains active
> And if a race ever renders the control, the client shows `Only the group admin
> can revoke the invite link.`

### AC-5 — Expiry window is exactly 7 days and server-set

> Given a new invite token is minted (FR-GR-02)
> When it is created
> Then `expiresAt` is set by the server to creation time plus 7 days, and the
> client cannot set or extend it
> And the active-link UI shows `Link active. Expires: [dd MMM yyyy]`

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `invite_link_revoked` | — | Admin revokes an active link |

`invite_link_shared` belongs to FR-GR-02. A join-attempt-rejected event
(expired / revoked) is not enumerated in the telemetry plan and would live on the
future deep-link / join handler (Sprint 4); server-side rejections are observable
via Cloud Function logs. No raw `groupId` / `memberId` may appear in any
analytics parameter (ADR-0013).

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A — this story handles link lifecycle, not money. |
| 2 | `simplifiedBalances` server-maintained | N/A — no balance writes on this path. |
| 3 | System share sheet only | Applicable (indirect) — governs the lifecycle of the link shared via the system share sheet in FR-GR-02; introduces no app-specific targeting. |
| 4 | Single Firebase project | Applicable — enforcement runs in the single project's rules / `asia-south1` callables; emulator-backed tests. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing.
- [ ] Integration tests passing against Firebase Emulator Suite (rules and/or
      callable, covering expired and revoked tokens).
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
- [ ] Uses system share sheet only (Invariant 3) — applicable; the governed link
      is the share-sheet artefact from FR-GR-02, with no app-specific targeting.
- [ ] Single Firebase project (Invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/13-18-groups.md` (SCR-16 — link active / revoke states) |
| Wireframe | `docs/design/04-wireframes/groups-flow.md` (Invite Members) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`groups`; invite-token model pending SR4) |
| Firestore rules | `firestore.rules` (group rules plus forthcoming invite rules — Architect, SR4 / SR5) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (`invite_link_revoked`) |
| Risk register | `docs/design/08-plan/risks-revisited.md` (R-18 invite-link security — added in this PR) |
| Readiness audit | `docs/audits/sprint-2/05-sprint-3-readiness.md` (SR4, SR9) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Revoke UI and confirmation, expired / revoked join-failure messaging, active-link expiry display |
| Architect | Invite-token model and the server-side expiry / revocation mechanism decision (rules vs callable) plus ADR (SR4) |
| Functions Dev | Server-side enforcement (callable and/or rules) for expiry, revocation, and join validation |
| QA | Expired-token, revoked-token, and non-admin-revoke negatives; emulator-backed rules / callable tests |
| Designer | Link-active / expired / revoked states, invite-link card (audit SR3), accessibility |

---

## Technical Notes

- **Server-side enforcement is mandatory.** Both the 7-day expiry and admin
  revocation must be enforced by Firestore Security Rules reading the token's
  `expiresAt` / `revoked`, or by a Cloud callable, so a crafted request cannot
  bypass the UI. The rules-vs-callable decision is the Architect's (audit SR4 /
  SR5) and should be made before this story starts. See risk **R-18** in
  `docs/design/08-plan/risks-revisited.md` (added in this PR).
- **Three properties close the threat.** Token unguessability, the 7-day expiry,
  and admin revocation together defend against a leaked link (R-18).
- **Consume the SR4 model.** The invite-token fields (`token`, `groupId`,
  `createdBy`, `expiresAt`, `revoked`) are owned by the Architect (SR4); this
  story consumes them and must not redefine them.
- **Region.** `asia-south1` pinning applies to any callable used for enforcement.
- **Scope boundary.** The cold-start join / deep-link resolution (opening the app
  from the link) is Sprint 4 infrastructure; this story governs the server-side
  validity guards that any join path must satisfy.
