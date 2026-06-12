# app

Application-shell layer. Holds the cross-cutting `ThemeData` for the
whole app.

## Implemented scope

- `theme.dart` — `AppTheme`, a static holder exposing `AppTheme.light`
  and `AppTheme.dark` `ThemeData`. The colour, typography, corner-radius
  and spacing values are the semantic design tokens from
  `docs/design/02-design-system/tokens.md`. Headings use Plus Jakarta
  Sans and body text uses Inter (via `google_fonts`).

`MaterialApp` itself is constructed in `lib/main.dart` (`OneBytwoApp`),
which wires `AppTheme.light` / `AppTheme.dark`, the auth-gated `home`
widget, and the `NotificationsLifecycleHost` builder. There is no
router package in v1.0 — navigation is the auth-state `switch` in
`OneBytwoApp.build` plus imperative `Navigator` / `MaterialPageRoute`
pushes from individual screens (the `IndexedStack` tab shell lives in
`lib/features/shell/`).

## Layout

```
app/
  theme.dart    # AppTheme.light / AppTheme.dark from design tokens
```

## Hand-off boundaries

- **Out:** design tokens are owned by the Designer
  (`docs/design/02-design-system/`); this file is the Flutter
  translation of those tokens.
- **In:** consumed by `lib/main.dart` and, transitively, every screen
  via `Theme.of(context)`.
