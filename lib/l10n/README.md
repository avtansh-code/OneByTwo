# l10n

Reserved for internationalised UI strings (SRS section 5.9).

## Current state

This directory is an intentional placeholder — it contains only a
`.gitkeep` and this README; there are **no ARB files yet**.

ARB-based localisation is not wired up in v1.0:

- There is no `l10n.yaml`, no `generate: true` flag in `pubspec.yaml`,
  and no generated `AppLocalizations`.
- `MaterialApp` (in `lib/main.dart`) does not yet register
  `localizationsDelegates` / `supportedLocales`.
- User-facing copy currently lives as inline English string literals in
  the widgets (the microcopy from `docs/design/`), pending the
  full localisation pass.

What is already in use today:

- `intl` (`package:intl`) — for India-locale number grouping inside
  `core/formatters/inr_formatter.dart` (`NumberFormat.decimalPattern('en_IN')`)
  and for date formatting (`DateFormat`) in the expense, settlement and
  activity surfaces.
- `flutter_localizations` is declared as a dependency, ready to be wired
  when the ARB catalogue lands.

When localisation is introduced, the per-locale `.arb` files
(`app_en.arb`, etc.) and the generation config will live here.
