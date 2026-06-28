You are the OneByTwo orchestrator agent. **Sprint 3 (Design Conversion — the "Direction A — Haldi" visual system, `design_handoff_one_by_two/`) is COMPLETE and closed**: DC-01..DC-13 merged, the golden-test harness + `golden-a11y-checks` gate are live (PR #140/#141), and the two trailing Sprint-3 issues — #110 (production deploy-drift; now a nightly rules/indexes/storage deploy pipeline) and #128 (foundation §4.1 reconciliation; ADR-0025) — merged as PR #142. The Sprint-3 milestone has zero open items.

────────────────────────────────────
THE GOAL OF THIS SESSION
────────────────────────────────────

Run the **Sprint 3 retro as a design-fidelity VALIDATION**: systematically verify the implemented Flutter app against the **authoritative design handoff in `design_handoff_one_by_two/`** (high-fidelity per its README — "Match the tokens exactly"), find **every** divergence, and remediate them. The headline, non-negotiable theme of this pass is the **single-line-fit rule** the product owner has called out: **components the handoff renders on one line must fit on one line in the app, adjusting (scaling) their text down to fit — never wrapping to a second line and never truncating money.**

This is a VALIDATION + remediation pass. It adds no new features and changes no behaviour, controller, callable, trigger, rule, schema, or telemetry. It corrects visual/layout fidelity only and re-proves it with goldens.

────────────────────────────────────
THE SOURCE OF TRUTH (read first; it overrides prior assumptions)
────────────────────────────────────

`design_handoff_one_by_two/` — high-fidelity HTML design references (NOT code to copy; recreate the look/behaviour with the codebase's Flutter primitives). Validate **every** screen against its reference:

- `screens/Phase1 - Foundations.dc.html` — tokens, type ramp, radii, shadows, motion, the AA/AAA contrast table.
- `screens/Phase2 - Components.dc.html` — the **full component library** (pills, avatars, chips, list tiles, buttons, inputs, sheets, banners, skeletons, donut, brand) in all states, light + dark. **This is the canonical spec for every shared widget.**
- `screens/Phase3a - Auth.dc.html`, `Phase3b - Home.dc.html`, `Phase3c - Friends.dc.html`, `Phase3e - Expenses.dc.html`, `Phase3f - Profile.dc.html`, `Phase3g - Change Phone.dc.html` — the converted flows (Auth, Home, Friends, Expenses, Settlements live inside these), each light + dark, every state.
- `screens/Phase3d - Groups.dc.html`, `Phase4 - Marketing.dc.html` — **out of scope** (Groups is Sprint 4; Marketing is not in the app).
- `screens/One By Two - Index & Acceptance.dc.html`, `Prototype - *.dc.html` — the screen inventory + acceptance checklist + click-through.
- `README.md` — fidelity statement + the master token table (background/surface/surfaceVariant/primary/onPrimary/balance trio/text tiers/outline/link, light → dark).

Cross-reference (do not contradict): `docs/audits/design-conversion/03-foundation-plan.md` (§3 type ramp, §4.1 widget map), `04-qa-test-strategy.md` (§A goldens, §B contrast, §C dynamic-type), `.github/shared/decision-log.md` (ADR-0024 Haldi, ADR-0025 §4.1 reconciliation), and the live golden harness `test/golden/golden_harness.dart` + `test/golden/flutter_test_config.dart`.

────────────────────────────────────
LOAD-BEARING ITEM 1 — THE SINGLE-LINE-FIT STANDARD (the product-owner directive)
────────────────────────────────────

Every element the handoff draws on a **single line** — anything with `white-space:nowrap`, every `inline-flex` pill/chip, every amount/balance figure, every row title/subtitle that the reference keeps to one line — **must render on one line in the app and SCALE its text down to fit** when the available width is tight (narrow devices, large dynamic type, long names/amounts). It must **never wrap to a second line** and **money must never be truncated/ellipsized** (an ellipsised rupee value is a defect — the digits must stay legible by shrinking, not clipping).

- The canonical Flutter pattern is `FittedBox(fit: BoxFit.scaleDown)` around the one-line content, with the inner `Text` set `maxLines: 1, softWrap: false`. For prose that MAY ellipsise (a display name, not money), `maxLines: 1` + `TextOverflow.ellipsis` is acceptable; for **money/amounts, use scale-down, never ellipsis**.
- Reconcile with the existing 2.0× dynamic-type policy (`04` §C / DC-12): where a dense row already reflows to a stacked layout at extreme scales, keep that reflow, but within any given line the content still scales-to-fit rather than wrapping. The scale-to-fit must not regress the `a11y-dynamic-type` gate.
- Audit EVERY one-line component, not just the pill: the balance pill, the category/filter chips, list-tile titles + balance, the net-balance hero amount, the settle-up amount, activity-row amounts, the amount-input field, summary cards, segment labels, button labels. Fix every one the handoff keeps to a single line.

────────────────────────────────────
LOAD-BEARING ITEM 2 — THE DIAGNOSED PILL FINDING (the exemplar; already root-caused)
────────────────────────────────────

`OBTBalancePill` (`lib/core/widgets/indicators/obt_balance_pill.dart`) **diverges from the handoff** and is the reported 2-line bug. The handoff (`Phase2 - Components` `pill()`, and every Home/Friends row in `Phase3b`/`Phase3c`) defines the pill as:

> `<span style="display:inline-flex;align-items:center;gap:5px;...;white-space:nowrap;font-family:'Bricolage Grotesque';font-weight:700;font-size:13px;">[icon] [amount]</span>`
> i.e. **`[directional-icon] [₹amount]` on ONE line, nowrap, 13px Bricolage 700, tinted background + hue.** Zero state = `[check] Settled`.
> The directional **LABEL** ("owes you" / "you are owed" / "you owe") is the **row SUBTITLE** under the name (`text-tertiary`, ~11.5px) — **never inside the pill**.

The Flutter implementation instead **embeds the label inside the pill and stacks label-over-amount (2 lines) by default** (`compact=false`), and wraps with `Flexible` `Text` (no `maxLines`), so it goes 2-line in list rows. **Required remediation (have the Designer + Architect ratify, then implement):**

1. `OBTBalancePill` renders **only `[icon] [amount]`** (zero → `[check] Settled`) inline on **one line**, `maxLines:1` + `softWrap:false`, wrapped in `FittedBox(scaleDown)` so it shrinks to fit and never wraps; Bricolage tabular at the handoff size (~13px). Drop the in-pill label and the stacked `compact=false` form (or keep `compact` as a no-op alias and make one-line the only behaviour).
2. **Move the directional label to the host rows** as the subtitle under the name (`text-tertiary`): `friend_list_tile.dart`, `top_balance_tile.dart`, and any other pill host (`friend_detail_header.dart`, `add_expense_context_picker_sheet.dart`, `friends_list_screen.dart`). Confirm the friend-detail header against `Phase3c` (the friends summary uses tonal "You are owed / You owe" **cards**, not the pill — match that where the handoff does).
3. **Preserve the accessibility trio (QA §B.3): colour + icon + label must all stay VISIBLE** — now colour+icon in the pill and the label as the adjacent subtitle — and the row's `Semantics` label must still read the full "name, owes you, ₹4,250.00". Do not regress the labelled-control or contrast gates.
4. Re-evaluate the host `LayoutBuilder` reflow thresholds (currently sized for the "~187 dp" stacked pill): the new one-line pill is narrower, so the reflow can trigger later — re-tune so the single row holds at typical widths and the scale-to-fit covers the rest.

────────────────────────────────────
LOAD-BEARING ITEM 3 — THE RUPEE-GLYPH (₹-in-Hanken) FINDING (confirmed; systemic)
────────────────────────────────────

A second confirmed, systemic divergence found during the pill pass: **monetary amounts rendered in a Hanken Grotesque text slot show the rupee sign (U+20B9) as a missing-glyph box (tofu)**, because the bundled Hanken static instance has no ₹ glyph (verified with fontTools: Bricolage U+20B9 present = true, Hanken = false). On a real device the ₹ falls back to a mismatched system font; in goldens it renders as tofu. This violates the foundation rule (`docs/audits/design-conversion/03-foundation-plan.md` §3.3 / ADR-0025): **amounts always render in Bricolage Grotesque with tabular figures.**

- **Rule:** every amount `Text` must take an `OBTText.amount*` style (Bricolage tabular — `amount` / `amountPill` / `amountFocal` / `amountHero`), **never** a Hanken `textTheme` slot (`titleLarge` / `titleMedium` / `bodyLarge` / `bodyMedium` / …). For an amount embedded in a sentence, split the figure into a Bricolage span (or give the run a `fontFamilyFallback` that carries ₹) so the rupee never renders from Hanken.
- **Already fixed in the lead PR** (visible in the regenerated baselines): the Friends-list summary band (`friends_list_screen.dart`, the "You are owed" / "You owe" cards) moved from `titleLarge` (Hanken) to `OBTText.amount` at the handoff's 18px.
- **Confirmed remaining sites to audit + fix in the sweep** (each needs its own golden re-baseline): `features/expenses/presentation/steps/step_2_split_and_payer.dart` (the "Total ₹…" summary, `titleMedium`), `core/widgets/sheets/obt_settle_up_sheet.dart` (the "You paid … ₹…" sentence, `bodyMedium`), `features/expenses/presentation/expense_detail_screen.dart` (the participant "gets back / owes ₹…" row), `features/settlements/presentation/settlement_history_screen.dart` (the signed amount), plus any other amount on a Hanken slot the Phase2/Phase3 matrix surfaces. Grep aid: for every `formatInrFromPaise(...)` render, assert the applied style resolves to an `OBTText.amount*` helper.

────────────────────────────────────
LOAD-BEARING ITEM 4 — GOLDENS RE-BASELINE ON UBUNTU
────────────────────────────────────

Every visual fix re-baselines goldens. The harness + the compare gate already exist (DC-13). For each remediation: make the code change, run `flutter test --exclude-tags golden` to fix lockstep widget/contrast tests, then **regenerate baselines on `ubuntu-latest` via the `golden-refresh` `workflow_dispatch` job** (NEVER `--update-goldens` on macOS), download the artifact, **review every changed PNG as an image**, and commit. The `golden-a11y-checks` job must end green against the committed baselines. Add a NEW golden/widget case that pins the **single-line-fit** behaviour: the pill (and other one-line components) rendered in a deliberately narrow box must stay one line and scale down (assert `find.byType(FittedBox)` / one text line / no overflow).

────────────────────────────────────
INVARIANTS (all hold — visual/layout validation only)
────────────────────────────────────

1. **Money = integer paise.** Display-only; `formatInrFromPaise()` stays the sole paise→INR boundary; no `paise / 100`; no `double` money math (the expenses boundary grep forbids the literal `double ` in `lib/features/expenses/**.dart`). Scaling text changes font size, not values.
2. **`simplifiedBalances` server-only.** The pill/tiles READ the projection only; no client write.
3. **System share sheet only.** Untouched.
4. **Single Firebase project.** Untouched (no backend change in this pass).
No `+91` / India-only constraint touched. No controller/callable/trigger/rule/schema/telemetry change.

────────────────────────────────────
METHOD (how to run the validation)
────────────────────────────────────

1. **PM/Designer — build the validation matrix.** Enumerate every shared component (Phase2) and every converted screen+state (Phase3a/b/c/e/f/g) with its handoff reference. For each, the Designer does a side-by-side fidelity check (colour, type family/size/weight, radius, shadow/outline, spacing, icon, **one-line vs wrap**, state coverage) and records PASS / FINDING. Capture findings in a new `docs/audits/sprint-3-retro/01-design-fidelity-validation.md` (mirror the existing audit format).
2. **Architect — rule on each FINDING** that is a token/component/§4.1 contract change (e.g. the pill contract). Record rulings as decision-log notes / §4.1 amendments; route any genuinely new design question, don't silently relax a gate.
3. **Flutter Dev — implement** the ratified fixes (start with the pill + the single-line-fit sweep), updating lockstep widget/contrast/dynamic-type tests.
4. **QA — regenerate goldens on ubuntu**, run the full gate (`flutter test`, `golden-a11y-checks`, `a11y-checks`), and sign off each finding as resolved (golden diff is the intended delta and nothing else moved).
5. **Designer — final spot-check** the regenerated baselines against the handoff.

Prefer ONE focused PR for the pill + single-line-fit sweep (the product-owner priority), and follow-up PRs (or issues) for any larger divergences the audit surfaces; file anything deferred on a tracked issue rather than leaving it silent.

────────────────────────────────────
SCOPE (validate each against its handoff reference)
────────────────────────────────────

- **Foundation:** tokens (the README table), the Bricolage/Hanken type ramp + the amount tiers (16/32/48, ADR-0025), radii, the marigold hero-shadow / dark outline separation, motion/reduced-motion.
- **The 6 reskinned OBT widgets** (Phase2): FAB, bottom nav, amount input, activity row, confirmation dialog, **settle-up card** — and the **balance pill** (the lead finding).
- **The 11 DC-03 components** (Phase2): skeletons, balance pill, category chip, stepper sheet, segmented split control, settle-up sheet, empty state, offline banner, donut+legend, OTP input, brand.
- **The hero/flow screens** (Phase3a/b/c/e/f/g): Auth/onboarding, Home dashboard, Friends list/detail/history, Add-expense (3-step), Settle-up + history, Activity + notifications, Profile/settings, Change-phone — every state, light + dark.
- **Out of scope:** Groups (Sprint 4), Marketing.

────────────────────────────────────
STANDING CAVEATS (carried from DC-01..DC-13 + #128/#110)
────────────────────────────────────

- fvm wrapper may be broken — use the pinned SDK: `export PATH="/Users/avtanshgupta/fvm/versions/stable/bin:$PATH"` then bare `flutter analyze lib test`, `flutter test`, `dart format .`, and bare `git`/`gh`. `very_good_analysis` is strict (≤80-char lines incl. comments, `prefer_const`, `prefer_int_literals`, `avoid_redundant_argument_values`, `directives_ordering`). CI gates on `dart format --set-exit-if-changed .`.
- Goldens are **host-sensitive** — author baselines ONLY via the ubuntu `golden-refresh` job; never commit macOS `--update-goldens` bytes. Multi-tag CI selection uses the boolean-OR selector (`--tags "golden || a11y-contrast || a11y-dynamic-type"`), never repeated `--tags`.
- Don't build `AppTheme.light/.dark` or call `GoogleFonts` at test COLLECTION time. Keep the balance signal = colour + icon + label (never colour alone). `outlineVariant` is unset → use `outline`.
- British English, no emojis, Conventional Commits (single-token scope, ≤72-char ASCII subject), the `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` trailer. Merge needs an OWNER approval; wait out iOS (slowest); commit this prompt with the PR.

────────────────────────────────────
DEFINITION OF DONE
────────────────────────────────────

- A design-fidelity validation report exists (`docs/audits/sprint-3-retro/…`) mapping every Phase2 component + Phase3 screen/state to PASS / FINDING / fixed, against `design_handoff_one_by_two/`.
- **The single-line-fit standard holds app-wide:** the balance pill is the handoff's one-line `[icon][amount]` (label moved to the row subtitle), and every other one-line handoff element fits one line and scales-to-fit — verified by a new pinned golden/widget case and by the regenerated baselines; **no money value wraps or truncates** at narrow widths / 2.0× type.
- **No money renders the rupee as tofu:** every amount figure resolves to a Bricolage `OBTText.amount*` style (never a Hanken `textTheme` slot); the ₹-in-Hanken finding (Item 3) is either fixed app-wide or each remaining site is filed as a tracked issue.
- Accessibility preserved (colour+icon+label trio visible; AA contrast; 2.0× dynamic-type; labelled controls) and all four invariants hold.
- `flutter analyze lib test` clean, `dart format` clean, `flutter test` green (incl. the un-skipped goldens compared against the ubuntu baselines and the `a11y-checks` families), per-feature coverage ≥70% / overall ≥50%.
- Each finding is either fixed in this pass or filed as a tracked issue; the retro report records the disposition.

────────────────────────────────────
BRANCH / PR
────────────────────────────────────

- Branch: `fix/haldi-pill-single-line-fit` (type-prefixed kebab) for the lead PR.
- Conventional Commit, e.g. `fix(widgets): match the handoff one-line balance pill and scale-to-fit`.
- PR body: map the change to the handoff reference (the `Phase2`/`Phase3` pill spec), show the before (2-line stacked) → after (one-line `[icon][amount]` + subtitle label), tick the invariants (all visual-only), note the goldens were regenerated on ubuntu and the a11y trio is preserved, and link the retro validation report. Begin by delegating to the **Designer** (fidelity matrix + the pill ruling vs the handoff), then the **Architect** (the pill contract + §4.1 amendment), then **Flutter Dev** (implement the pill + the single-line-fit sweep) with **QA** (regenerate goldens on ubuntu + sign-off), sequencing to a single green PR.

FAILURE / REFUSAL: if any change would weaken an invariant or the SRS, refuse and quote it. Determinism is non-negotiable — never commit macOS golden bytes. Convert no Groups screen (Sprint 4). Do not edit `docs/OneByTwo_Requirements_Spec.md`.
