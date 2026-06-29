# Design Reference

- **Authoritative path:** `design_handoff_one_by_two/screens/*.dc.html`
- **Catalogue:** `design_handoff_one_by_two/README.md` (tokens) + 30 screens
- **Decision:** ADR-0024 (`.github/shared/decision-log.md`) adopts this Haldi
  visual system app-wide; the superseded `docs/design/02-design-system/*` palette
  is historical only.
- **Fidelity:** high-fidelity, pixel-exact. The `.dc.html` references are the
  single source of truth for layout, copy, components, and placement — match
  them exactly, not just the colour/type tokens.
- **Status:** the shipped Flutter theme (`lib/app/theme.dart`) and shared
  widgets implement these tokens; new/changed screens must reproduce the
  matching `.dc.html` screen, not merely apply the theme.

## How to use

- Find the screen by its numbered label (e.g. "21 · Step 1", "27 · Profile",
  "28 · Notifications"); the `.dc.html` `.set` / `.av` / `.tg` classes define
  exact spacing, radii, and icon sizes.
- Render colour only via `formatInrFromPaise` for money and OBTColors tokens —
  never hard-code hex (boundary-contract grep tests enforce this on converted
  surfaces).

## Token summary (Haldi)

| Token | Light | Dark |
|---|---|---|
| primary (marigold) | `#E0922E` | `#EAA24A` |
| onPrimary (ink, not white) | `#2A211B` | `#1A1510` |
| secondary (terracotta) | `#C75D3C` | `#E07A55` |
| success / balancePositive | `#0F7D6B` | `#34C0A4` |
| danger / balanceNegative | `#BC4030` | `#F2856B` |
| background | `#FBF6EE` | `#1A1510` |
| Typography | Bricolage Grotesque (headings/amounts) + Hanken Grotesk (body) |

> Balance trio is always colour + icon + label (never colour alone):
> owed = success + `arrow_upward`; owe = danger + `arrow_downward`;
> settled = balanceZero + `check`.
