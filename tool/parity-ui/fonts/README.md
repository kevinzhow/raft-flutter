# Space Grotesk / Space Mono for the raft-ui specimen reference

`raft-ui.css` is the exact Google Fonts response for the URL that
`@botiverse/raft-ui/fonts.css` imports (`manifest.json` -> `cssUrl`), fetched
with the pinned Playwright Chromium user agent; `files/` are the woff2 files it
references, sha256-pinned in `manifest.json`. `tool/parity-ui/run fonts`
verifies the cache (and that raft-ui still imports the same URL);
`--refresh` re-downloads it (review the diff). `capture.mjs` serves the cache
for that URL and fails on any other external request, so captures never depend
on the network. Space Grotesk (Florian Karsten) and Space Mono (Colophon
Foundry) are SIL OFL 1.1 fonts.
