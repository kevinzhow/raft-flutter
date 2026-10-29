# Production raft-ui fonts for the React parity baseline

`raft-ui.css` is the exact Google Fonts response for raft-ui's `fonts.css`
import (`manifest.json` → `cssUrl`), fetched with the pinned Playwright
Chromium user agent; `files/` are every woff2 it references. `manifest.json`
pins URL → file → sha256. `tool/parity fonts` verifies the cache;
`tool/parity fonts --refresh` re-downloads it (review the diff). The fonts are
SIL OFL 1.1 (license texts: `SpaceGrotesk-OFL.txt` and `SpaceMono-OFL.txt` beside this file).

`tool/parity run` serves this cache to the React provider instead of the
upstream spec's offline Space Grotesk / Space Mono subsets — see docs/parity.md
"Baseline fonts". (Web v1.21.23 / raft-ui 0.7.0 imports Space Grotesk and Space
Mono; v1.21.12 imported Geist, Geist Mono, Hanken Grotesk and Inter.)

`derive_inter.py` documents how the Flutter `Inter.ttf` is derived so it
renders exactly what Google serves (wght axis only, opsz pinned at 14).
