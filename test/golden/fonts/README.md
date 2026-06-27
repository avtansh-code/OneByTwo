# Bundled Haldi fonts (golden tests only)

These font files exist solely so the golden-test harness renders the real Haldi
type ramp deterministically and offline. They are **not** app assets and are not
shipped in the application bundle — the app continues to obtain the same families
through `google_fonts` at runtime (see `lib/app/theme.dart`).

## Files

| File | Family | Provenance |
|---|---|---|
| `BricolageGrotesque-Regular.ttf` | Bricolage Grotesque | static Regular instance, `fonts.gstatic.com` (SHA-256 `2d910251…2a2b016`, 82168 bytes) |
| `HankenGrotesk-Regular.ttf` | Hanken Grotesk | static Regular instance, `fonts.gstatic.com` (SHA-256 `956414e5…b3babf12`, 57224 bytes) |
| `BricolageGrotesque-OFL.txt` | Bricolage Grotesque | SIL Open Font License 1.1 |
| `HankenGrotesk-OFL.txt` | Hanken Grotesk | SIL Open Font License 1.1 |

Both families are licensed under the SIL Open Font License 1.1, which permits
bundling and redistribution provided the licence text travels with the font — the
two `*-OFL.txt` files satisfy that.

## Why these exact bytes

`google_fonts` validates a fetched face against an expected length + SHA-256 hash
before registering it. These are the exact files the pinned `google_fonts`
(6.3.3) requests for the two families' `Regular` weight, so the harness's offline
mock (`test/golden/golden_harness.dart`) can serve them and `google_fonts` accepts
them. The heavier weights the theme uses are synthesised from the Regular master,
exactly as in the running app. If `google_fonts` is upgraded its expected hashes
change and the font load fails loudly (a golden diff), prompting a refresh of
these files and the hash map in the harness.
