# SRS Change Proposal — Ratify the "Direction A — Haldi" Visual System into §6.2 and §6.3

| Field | Value |
|---|---|
| Proposal ID | SRS-PROP-HALDI-001 |
| Requestor | Orchestrator / Designer (Design Conversion planning, new Sprint 3) |
| Author | PM |
| Date | 2026-06-25 |
| Target SRS | `docs/OneByTwo_Requirements_Spec.md` (currently version 1.1) |
| Skill | `update-srs` (proposal-and-review; never applied unilaterally) |
| Status | **Proposal only — NOT applied. The SRS remains version 1.1 until an approved edit is explicitly requested.** |

This proposal ratifies the high-fidelity visual system **"Direction A — Haldi"** (delivered at
`design_handoff_one_by_two/`, adopted by ADR-0024) into the SRS. It updates two subsections —
**§6.2 Visual System** and **§6.3 Core Screens**. It creates no new functional requirement,
changes no invariant, and changes no scope boundary. §6.1 (Design Philosophy), §6.4 (Empty,
Error & Loading States), and §6.5 (Microcopy Tone) remain valid as written and are unaffected.

---

## 1. Section(s) affected

- **§6.2 Visual System** — the design-token table (colour, typography, corner radius, elevation, motion).
- **§6.3 Core Screens** — the canonical screen catalogue.

---

## 2. Current text / baseline

### 2a. §6.2 Visual System (current, verbatim)

| Token | Value | Usage |
|---|---|---|
| Primary | Indigo Blue (`#1F4E79` / `#2E86AB` accent) | Primary actions, highlights, balance positives |
| Secondary | Saffron / Marigold (`#F4A261`) | Secondary highlights, India-flavoured accents |
| Success | Emerald (`#2A9D8F`) | "You are owed", positive states |
| Danger | Coral Red (`#E76F51`) | "You owe", destructive actions |
| Surface | Pure white / `#121212` in dark mode | Cards, sheets |
| Typography | Inter or Plus Jakarta Sans (Latin); fallback to system | All UI text |
| Corner radius | 16 dp / 24 dp on cards and sheets | Soft, modern feel |
| Elevation | Subtle shadows, layered surfaces | Depth without heaviness |
| Motion | 200–300 ms ease-in-out transitions; spring physics on FAB | Delightful but quiet |

### 2b. §6.3 Core Screens (current, verbatim — 11 entries)

1. Splash & Onboarding (3 illustrated slides)
2. Phone-number entry (locked +91 prefix)
3. OTP verification
4. Profile setup (name, photo)
5. Home dashboard (simplified balance, top friends/groups, FAB to add expense)
6. Friends list & Friend detail
7. Groups list & Group detail
8. Add / Edit expense (multi-step bottom sheet)
9. Settle Up flow (driven by simplified-debts suggestion)
10. Activity feed
11. Profile & Settings (incl. Contact Support)

---

## 3. Proposed text

### 3a. §6.2 Visual System (proposed replacement)

> Source of truth: `design_handoff_one_by_two/README.md`. All tokens are stated light / dark.
> Money remains integer paise (Invariant 1); only the rupee display is designed.

| Token | Value (light / dark) | Usage |
|---|---|---|
| Primary | Marigold `#E0922E` / `#EAA24A` (pressed `#C77F22` / `#D08F3C`) | Brand; FAB, primary buttons, highlights |
| On-primary | **Ink `#2A211B` (light) / `#1A1510` (dark) — NOT white** | Text/icons on marigold (AA 5.6:1 on marigold) |
| Secondary | Terracotta `#C75D3C` / `#E07A55` | Secondary accents |
| Success / balance-positive | `#0F7D6B` / `#34C0A4` | "You are owed", confirm — paired with `arrow_upward` + label |
| Danger / balance-negative | `#BC4030` / `#F2856B` | "You owe", errors, destructive — paired with `arrow_downward` + label |
| Balance-zero | `#6F6557` / `#A99C8C` | "Settled up" (neutral) — paired with `check` + label |
| Background | `#FBF6EE` / `#1A1510` | App canvas |
| Surface | `#FFFFFF` / `#241D16` | Cards, sheets, rows |
| Surface-variant | `#FFF6E6` / `#2E2620` | Tonal fills, hero card, chips |
| Text (primary / secondary / tertiary) | `#2A211B` · `#6F6557` · `#776E64` (light) / `#F3EBDD` · `#B9AE9D` · `#9C8E7C` (dark) | Headings & amounts / body / meta |
| Outline / divider | `#E7DDCD` / `#3A322A` | Borders, hairlines |
| Typography | **Bricolage Grotesque** (display/headings; amounts always Bricolage with **tabular figures**) + **Hanken Grotesk** (text/UI), via `google_fonts` | All UI text |
| Corner radius | Cards 16–22, sheets 26–28 (top), buttons 14–16, chips/inputs 12–14, pills 18–19 / 999 | Soft, warm feel |
| Elevation | Soft warm shadows (rows `0 1px 3px rgba(42,33,27,.05)`; hero `0 12px 30px -12px rgba(224,146,46,.3)`); dark mode uses 1px outline borders, not shadows | Depth without hard borders |
| Motion | 200–300 ms ease-in-out; bottom-sheet spring + grabber; FAB press spring; respects reduced-motion (instant cross-fades) | Delightful but quiet |

Supporting rules:
- **Balance signal = colour + icon + label, never colour alone** (the single most important signal).
- **8-hue, colour-blind-safe expense-category palette** (≥ 3:1 on surface; chips at ~10% opacity).
- **Accessibility:** WCAG 2.1 AA (≥ 4.5:1 body, ≥ 3:1 large/UI); dynamic type to 2.0× without
  clipping. Verified pairings: ink `#2A211B` on background `#FBF6EE` = 13.9:1 (AAA); ink on
  marigold `#E0922E` = 5.6:1 (AA); positive `#0F7D6B` on white = 4.6:1; negative `#BC4030` on
  white = 5.1:1; dark text `#F3EBDD` on `#1A1510` = 14.2:1.

### 3b. §6.3 Core Screens (proposed replacement)

> The canonical screen catalogue is now the **30-screen Haldi set** (plus the FR-PR-02 change-phone flow, Phase3g) at `design_handoff_one_by_two/`
> (grouped by flow below). Each screen has, where relevant, four states — populated, empty
> (friendly + CTA), loading (skeleton, not spinners), error (Retry + Contact support). Hero
> screens (★) ship light **and** dark.

**Auth & onboarding:** 1. Splash · 2. Onboarding (3 slides) · 3. Phone entry (+91 locked) · 4. OTP (6-box) · 5. Profile setup
**Home & search:** 6. Home dashboard ★ · 7. Search · 8. Add-expense context picker
**Friends:** 9. Friends list ★ · 10. Add friend (lookup branches) · 11. Friend detail · 12. Friend history · 13. Remove friend
**Groups:** 14. Groups list · 15. Create group · 16. Group detail (Expenses/Balances/Activity) ★ · 17. Invite members · 18. Group members · 19. Leave / delete group · 20. Group history
**Expenses:** 21. Add expense — 3-step bottom sheet ★ · 22. View expense (detail) + edit/delete
**Settle up & settlements:** 23. Settle up ★ · 24. Settlement history (+ reminder compose)
**Activity & notifications:** 25. Activity feed ★ · 26. Push notifications
**Profile & settings:** 27. Profile view + edit · 28. Notification preferences · 29. Contact support · 30. Delete account · **Change Phone (Phase3g — FR-PR-02 re-verification; added after the initial 30)**

Plus **global overlays** (design once, reuse): add-expense sheet, settle-up sheet, delete
confirmations, sign-out confirmation, offline banner, snackbars/toasts.

**Count reconciliation:** the previous 11-entry list collapsed multi-screen flows (e.g. "Friends
list & Friend detail", "Groups list & Group detail", "Profile & Settings"). The Haldi catalogue
expands these into discrete screens and adds states the prior list left implicit (search, friend/
group history, remove/leave/delete confirmations, view-expense detail, push-notification surface,
contact support, delete account), giving **30 screens**; a 31st — the FR-PR-02 change-phone
re-verification flow — was added as **Phase3g** on 2026-06-25. No screen from the prior list is
removed; each maps forward into the Haldi set.

---

## 4. Rationale

The implemented client encodes the **current** §6.2 baseline in `lib/app/theme.dart` (Indigo
`#1F4E79`/`#2E86AB`, Saffron `#F4A261`, Emerald `#2A9D8F`, Coral `#E76F51`, white `onPrimary`;
Plus Jakarta Sans + Inter). The new Sprint 3 (Design Conversion) migrates the app to the Haldi
system. If the SRS is not updated, the code, the design handoff, and ADR-0024 will all diverge
from the SRS — and the SRS is the single source of truth. Per the PM working agreement, design-vs-
SRS conflicts are resolved **in the SRS's favour by proposing this update**, not by silently
following the handoff. This proposal ratifies ADR-0024 into the requirements baseline so §6.2/§6.3
match the design, the ADR, and the post-conversion code.

---

## 5. Repo evidence

- `design_handoff_one_by_two/README.md` — the authoritative Haldi token set, typography, formatting
  rules (which restate all four invariants), and the 30-screen catalogue.
- `lib/app/theme.dart` — `AppTheme.light`/`.dark` currently encode the §6.2 baseline this proposal
  supersedes: `_lightPrimary = #1F4E79`, `_lightPrimaryVariant = #2E86AB`, `_lightSecondary =
  #F4A261`, `_lightSuccess = #2A9D8F`, `_lightDanger = #E76F51`, `_lightOnPrimary = #FFFFFF`;
  heading `GoogleFonts.plusJakartaSans()`, body `GoogleFonts.inter()`.
- **ADR-0024** (`.github/shared/decision-log.md`) — the Haldi adoption decision (latest existing
  ADR is ADR-0023; ADR-0024 is the adoption record, authored by the Architect).
- `docs/audits/design-conversion/` — the Design Conversion planning pack (framing, coverage-gap,
  conversion checklist, foundation plan, QA strategy, and `sprint-3-plan.md`).
- `.github/shared/invariants.md` — the four invariants, which the Haldi handoff restates and this
  proposal re-affirms.

---

## 6. Impact assessment

**a) Affected agents**
- **Designer** — owns conformance to the Haldi handoff; authors the coverage-gap and conversion checklist.
- **Flutter Dev** — implements the token + type foundation in `lib/app/theme.dart`, reskins shared
  components in `lib/core/widgets/**`, converts feature screens. (PM writes no code.)
- **Architect** — ADR-0024 feasibility; the token/type/component foundation plan; the golden/contrast harness design.
- **QA** — golden / contrast / dynamic-type verification strategy.

**b) Affected stories**
- Every **Sprint-3 (Design Conversion)** conversion story takes the updated §6.2/§6.3 as its acceptance baseline.
- **All downstream stories' DoR** (Sprint 4 Groups onward) update to build on the Haldi token/
  component foundation rather than the superseded Indigo system. In particular the not-yet-built
  Groups screens (**FR-GR-01..07**) must be authored against Haldi screens 14–20, and the existing
  Groups artefacts cited by the Sprint 4 kickoff (screen spec SCR-14, wireframe, mockup) reconcile
  to Haldi during conversion.

**c) New ADR** — yes: this proposal depends on **ADR-0024** (Haldi adoption). The SRS ratification
should not merge ahead of ADR-0024.

**d) Tests / rules / workflows**
- **Tests** — golden / visual-regression baselines re-captured against Haldi; contrast assertions
  (ink on marigold 5.6:1 AA; ink on background 13.9:1 AAA; positive 4.6:1; negative 5.1:1); dynamic
  type to 2.0× without clipping.
- **Security rules, Cloud Functions, Firestore schema/indexes, CI/CD** — **no change required** by
  this text. The adoption is visual/UX only; the data layer is untouched.

---

## 7. Required approvers

- **PM** — scope ownership.
- **Architect** — technical feasibility.

---

## 8. Refusal notes (invariant + scope check)

This proposal violates **no** invariant — it re-affirms all four — and requests **no** SRS §12.3 out-of-scope feature.

- **Invariant 1 (money is integer paise):** RE-AFFIRMED. Haldi: "Store integer paise internally; only the rupee display is designed." No floats; INR-only; Indian numbering; tabular figures are display-only.
- **Invariant 2 (`simplifiedBalances` server-written, client-read-only):** RE-AFFIRMED. Haldi: "Simplified debts only … Never render a raw who-paid-whom debt graph." Balance surfaces read the projection; they never write it.
- **Invariant 3 (OS system share sheet only):** RE-AFFIRMED. Haldi: invites "hand off to the OS system share sheet only. No WhatsApp/SMS/any-single-app buttons."
- **Invariant 4 (single Firebase project):** RE-AFFIRMED. No project, environment, or emulator change; pre-merge testing stays on the Firebase Emulator Suite.
- **Scope (SRS §12.3 Future / Out-of-Scope):** IN SCOPE. No UPI integration, no recurring expenses, no language localisation are built; the Haldi design keeps those exactly as three **disabled** "Coming soon" slots (Settle Up → "Pay via UPI"; Add Expense Step 3 → "Make recurring"; Profile → Notifications → "Language"), preserving the §12.3 boundary. INR-only and +91-only are retained.
- **No direct SRS edit:** this is a proposal only. `docs/OneByTwo_Requirements_Spec.md` is **NOT** modified by this document; the SRS remains **version 1.1** until an approved edit is explicitly requested.

---

## 9. Addendum (2026-06-26) — Onboarding (Haldi screen 2) has no dedicated FR id

Logged during **Sprint 3 (Design Conversion) PR #5 — DC-04 (#116)**, which **built
the onboarding flow net-new** in Haldi (screen 2: three slides, Skip / "Get
started", Terms & Privacy links, first-launch "seen" gating via `shared_preferences`).
Onboarding is required by the SRS but carries **no dedicated FR-XX-NN id**:

- **§6.3 Core Screens** lists "Splash & Onboarding (3 illustrated slides)" as screen
  1 of the current catalogue (this proposal's §3b keeps it as Haldi screen 2).
- **§10.2 Critical User Journeys**, must-pass journey 1 (≈ line 593): "First-time
  user: onboarding → phone OTP → profile setup → home dashboard."
- **§5.5 Privacy & Compliance** (≈ line 317): "A privacy policy and terms of service
  shall be linked from the onboarding screen and the profile."

**Proposed action:** fold an **onboarding FR formalisation** into this Haldi proposal
(a later revision) — or a dedicated `update-srs` follow-up if it grows — so the built
screen 2 rests on an explicit requirement id rather than only the §6.3 catalogue entry
plus the §5.5 / §10.2 obligations above. This is a **tracked note, not a blocker**:
DC-04 ships against the existing SRS text. The present proposal still creates **no new
FR** (it ratifies the §6.2 / §6.3 design sections only); this addendum merely records
the gap for the next SRS revision. `docs/OneByTwo_Requirements_Spec.md` is **not**
edited and the SRS remains **version 1.1**.

---

## Validation checklist (update-srs skill)

- [x] Change does not violate any invariant (re-affirms all four).
- [x] No new FR-XX-NN is created; §6.2/§6.3 are descriptive design sections, modified in place.
- [x] Impact assessment identifies affected agents and stories.
- [x] Presented for review, not applied unilaterally.
- [x] `docs/OneByTwo_Requirements_Spec.md` not edited during drafting.
- [x] SRS version remains 1.1.
