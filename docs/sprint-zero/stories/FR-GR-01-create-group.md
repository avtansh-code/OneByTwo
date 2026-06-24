# FR-GR-01: Create Group (name, type, optional cover photo)

> Implementation-ready user story for creating a new group with a name, a type
> from the allow-list, and an optional cover photo. The caller becomes the group
> admin and first member; the `groups/{groupId}` document is created WITHOUT
> `simplifiedBalances` (Invariant 2).

---

## SRS Requirement ID(s)

FR-GR-01 (SRS section 4.4 — Groups)

## Relevant SRS Sections

- Section 4.4 — Groups
- Section 5.6 — Accessibility
- Section 5.10 — Observability
- Section 6.3 item 7 — Core screen: Groups list and Group detail
- Section 6.4 — Loading, empty, and error states
- Section 7.3 — Key architectural decisions (Invariant 2)
- Section 7.5 — Security rules
- Section 13.2 — Story format (this document)

## Priority

**P0 — Must have**

## Story Points

3

## User Story

As a **signed-in user**,
I want to **create a group with a name, a type, and an optional cover photo**,
so that **I can start splitting shared expenses with a set of people under one
named context where I am the admin**.

## Preconditions

1. User is authenticated (Firebase Phone Auth, +91 only) and can reach the
   Groups tab.
2. The Groups feature scaffold under `lib/features/groups/` is currently a stub
   (see `lib/features/groups/README.md`); this story builds the first client UI
   and data layer for the feature.
3. The `groups/{groupId}` schema and create rule already exist in
   `firestore.rules` (`isValidGroupCreate`) and
   `docs/design/07-technical/firestore-schema.md`; the client must produce a
   document those rules accept.
4. `simplifiedBalances` is server-maintained (Invariant 2) and has no group
   trigger in v1.0, so it is simply absent at create.
5. The app uses the single configured Firebase project; pre-merge verification
   runs against the Firebase Emulator Suite.

---

## Acceptance Criteria

### AC-1 — Valid create with name and type

> Given I am on the Create Group screen (SCR-14) with a name of 1–100 characters
> (the SCR-14 field caps input at 50) and a type selected from `Trip`, `Home`,
> `Couple`, or `Other`
> When I tap `Create Group`
> Then a `groups/{groupId}` document is created with `name` (trimmed), `type` in
> the allow-list (`trip` / `home` / `couple` / `other`), `memberIds` containing
> my UID, and `adminId` equal to my UID
> And I am navigated to the Group Detail screen (SCR-15) for the new `groupId`
> And the success snackbar reads `Group created`
> And `group_created` fires with `type` and `has_cover_photo`

### AC-2 — Caller becomes admin and first member

> Given I successfully create a group
> When the document is written
> Then `adminId == my UID` and my UID is present in `memberIds`
> And `createdAt == updatedAt == request.time`
> And I hold admin privileges on the new group (the SCR-15 Settings tab exposes
> the admin-only actions defined for SCR-17 / SCR-18)

### AC-3 — Optional cover photo uploads to Storage

> Given I select a JPEG or PNG cover photo of 5 MB or less before creating
> When the create succeeds
> Then the image is uploaded to Cloud Storage, `coverPhotoUrl` on the group
> document is set to the returned download URL, and `group_photo_uploaded` fires
> with `file_size_bytes`
> And `group_created` carries `has_cover_photo: true`
>
> Given I create a group without a cover photo
> When the create succeeds
> Then `coverPhotoUrl` is `null` (or absent) and `group_created` carries
> `has_cover_photo: false`

### AC-4 — Group document carries NO `simplifiedBalances` at create (Invariant 2)

> Given a create request is constructed
> When the payload is sent to Firestore
> Then it does NOT include a `simplifiedBalances` field
> And the create rule (`isValidGroupCreate`) accepts the document
> And `simplifiedBalances` is later populated only by the server-side recompute
> path, never by the client

### AC-5 (Negative) — Empty or whitespace-only name is rejected

> Given the name field is empty or contains only whitespace
> When I attempt to create the group
> Then the Create button stays disabled, or on a submit attempt an inline error
> reads `Group name is required`
> And no `groups/{groupId}` document is written
> And the validation is client-side, so no Firestore request is made

### AC-6 (Negative / Invariant 2) — A malformed or non-admin create is rejected by rules

> Given a create request that either includes a `simplifiedBalances` field, OR
> sets `adminId` to a UID other than the caller, OR omits the caller from
> `memberIds`, OR carries a `name` outside 1–100 characters or a `type` not in
> the allow-list
> When the request reaches Firestore Security Rules
> Then the write is rejected server-side
> And the Create flow surfaces the error snackbar `Could not create group. Try
> again.` with the form preserved
> And `create_group_failed` fires with `error_code`

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `create_group_started` | — | Create Group screen first becomes visible |
| `group_created` | `type: string`, `has_cover_photo: bool` | Group document successfully created |
| `create_group_failed` | `error_code: string` | Create request fails (rules rejection or network) |
| `group_photo_uploaded` | `file_size_bytes: int` | Cover photo successfully uploaded to Storage |

Per ADR-0013 and audit finding SR8, no raw `groupId` or `memberId` may appear in
analytics parameters; if a correlation id is ever required it must be hashed
(`group_id_hash`) via the canonical `hashId` helper. The PII-clean telemetry-plan
parameters above supersede the `{groupId, ...}` payload sketched in the SCR-14
draft.

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A — the create flow stores no monetary value. Group balances arrive later (FR-GR-04 plus server triggers) as integer paise. |
| 2 | `simplifiedBalances` server-maintained | Applicable — the create payload must omit `simplifiedBalances`; the field is initialised and maintained only by the server. |
| 3 | System share sheet only | N/A — creation does not initiate outbound sharing. |
| 4 | Single Firebase project | Applicable — writes target the single production project; pre-merge verification uses the Emulator Suite. |

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
- [ ] No client writes to `simplifiedBalances` (Invariant 2) — required; the
      field is absent at create and never written by the client.
- [ ] Uses system share sheet only (Invariant 3) — N/A in this story.
- [ ] Single Firebase project (Invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/13-18-groups.md` (SCR-14) |
| Wireframe | `docs/design/04-wireframes/groups-flow.md` (Create Group) |
| Mockup | `docs/design/05-mockups/05-group-detail.html` (group context) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`groups/{groupId}`) |
| Firestore rules | `firestore.rules` (`isValidGroupCreate`) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (FR-GR-01 / SCR-14 group events) |
| State management | `docs/design/07-technical/state-management.md` (groups feature — to be added) |
| Readiness audit | `docs/audits/sprint-2/05-sprint-3-readiness.md` (SR1, SR6) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Create Group UI (SCR-14), groups feature scaffold, repository create path, cover-photo upload, navigation to SCR-15 |
| Architect | Confirm the create payload satisfies `isValidGroupCreate`; Invariant 2 review (no `simplifiedBalances` at create) |
| QA | Valid and invalid create paths, rules-rejection negative cases, cover-photo upload, emulator-backed sign-off |
| Designer | SCR-14 form layout, type selector, cover-photo affordance, accessibility and dark-mode sign-off |

---

## Technical Notes

- **Feature-first scaffold.** Build `lib/features/groups/{application,data,domain,presentation}`
  per the feature README; the create path is the correct first build step.
- **Honour the existing create contract.** The client must produce a document
  accepted by `isValidGroupCreate` (name 1–100, `type` in the allow-list,
  `memberIds` is a list containing the caller, `adminId == caller`,
  `createdAt == updatedAt == request.time`, `simplifiedBalances` absent). The
  schema and rules remain owned by the Architect.
- **Cover photo.** `coverPhotoUrl` stores the Storage download URL only; the
  Storage path convention and Storage rules are owned by the Architect /
  Functions Dev (follow the established receipts pattern).
- **Name limits.** SCR-14 caps the input field at 50 characters; the rules
  enforce 1–100 as defence-in-depth. Trim leading and trailing whitespace before
  submit.
- **Telemetry discipline.** Follow the telemetry plan exactly (SR8 anti-drift);
  no raw `groupId` / `memberId` in parameters (ADR-0013).
- **Navigation.** `go_router` is not required for FR-GR-01 — imperative
  navigation to SCR-15 on success is sufficient. The `go_router`-vs-imperative
  decision is deferred to FR-GR-02 / FR-GR-04 (audit SR7).
