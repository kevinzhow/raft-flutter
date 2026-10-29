# Page coverage and alignment

Visual parity is measured against the real Web client, rendered from a raft-source checkout, using raft-source's own visual-testing tool. Flutter plugs in as a provider and the official CLI does the diff and scoring.

Requirements (the scripts have maintainer-machine defaults that you must override): a read-only raft-source checkout (`PARITY_RAFT_SOURCE`), a text file listing absolute paths of Node 24 and pnpm binaries (`PARITY_TOOLCHAIN_PATHS`; `tool/raft-stack` can create one), and for publishing a reports directory (`PARITY_REPORTS_ROOT`) and base URL (`PARITY_BASE_URL`). The raft-source checkout is never edited.

## Official suite: `tool/parity`

```sh
tool/parity run [--cases <id|glob>[,...]] [--refresh-react] [--shards N]
tool/parity summary
tool/parity publish [--no-verify]
```

`run` captures the Web side (cached unless `--refresh-react`), captures Flutter through `apps/raft_flutter/test/parity`, runs the official diff and site generation, and writes everything to `build/parity/` (`PARITY_OUT`), including `summary.json`. It covers the official 99 phone cases. Details and history: [parity](parity.md).

## Extension suite: `tool/parity-ext/run`

The extension suite adds cases for pages the official set lacks (ids `components.<area>.*`, several hundred brutal-light cases).

```sh
export PARITY_EXT_WEB_PORT=4xxx                       # unique per run; default 4396
tool/parity-ext/run run --cases 'components.<area>.*' # comma list / globs; --refresh-react to recapture
tool/parity-ext/run summary
```

- Cases are generated on every run by the automatically discovered `tool/parity-ext/build-*.py` builders into `build/parity-ext/cases.json` (never committed); Flutter-side cases live in `apps/raft_flutter/test/parity/cases/`. Adding or fixing a surface: [extension quickstart](parity-ext-quickstart.md).
- Theme sampling: `brutal-light` (the default theme) runs every case; `elegant-light` and `elegant-dark` run one or two cases per surface (rule in `tool/parity-ext/sampling.py`). `--cases` only sees the sampled set; `PARITY_EXT_ALL_THEMES=1` runs everything, `PARITY_EXT_ALL_DARK=1` keeps every elegant-dark case.
- Web captures are cached across worktrees (`PARITY_EXT_CACHE` overrides the location) and recaptured only when their inputs change.
- Output goes to `build/parity-ext/` (`PARITY_EXT_OUT`): `summary.md` (per-case and per-area tables) and `site/index.html`.

## What "pass" means

- **Official pass**: the official diff status is `same`, `pass` or `basic-pass` (pixel-perfect similarity above 96%); "strict" pass is above 99%.
- **Geometry pass** (the extension suite's target): the "non-text" similarity in `summary.md` is at least 99.5%, counting pixels classified as text glyph anti-aliasing as matching. `tool/parity-ext/analyze-diffs.py --cases <glob> --viz DIR` shows where the remaining difference is (fill, hairline, corner, offset, text, other).
- Text anti-aliasing differences between Chromium and Skia are ignored; fix layout, color, spacing, borders, radii and whole-pixel glyph positions instead.
- A case existing means coverage, not that Flutter passes it.

## Page inventory

The page inventory (every Web page, modal and state with desktop/phone coverage `ok`, `partial`, `web-only`, `MISSING`, `n/a`, `excluded`, and a priority) is generated on demand, not committed: `python3 tool/parity-ext/inventory.py --write build/parity-ext/page-inventory.md` (add `--case-map build/parity-ext/visual-testing-results/android-case-map.json` or run after a parity-ext run to see `web-only` pages). The rows in `tool/parity-ext/inventory.py` hold only Web page metadata and the expected case ids; every status is computed from the case ids that exist in the built manifests and the `noFlutterSurface` flags, so branches that add cases never edit it. `python3 tool/parity-ext/inventory.py --check` validates the rows and id globs.

## Alignment audit

`tool/alignment-audit.py` compares strong vertical edges and text start columns between the Web and Flutter captures of each case and reports offsets in CSS px:

```sh
tool/alignment-audit.py run --root build/parity --root build/parity-ext [--cases GLOB] [--out DIR]
tool/alignment-audit.py show --root build/parity-ext --case <id> --out overlay.png
tool/alignment-audit.py overlays --out DIR     # overlays of every flagged case
tool/alignment-audit.py selftest
```

`--root` is a parity output directory. Results go to `--out` (default `.local/alignment/audit`) and never into the root. An offset within 0.75 CSS px counts as aligned; up to 12 px is reported as an offset; beyond that is a layout difference. A near-miss pass flags mixed insets and tells you whether the Web page has them too.

## Where reports land

`build/parity/` and `build/parity-ext/` locally. `tool/parity publish` and `tool/parity-ext/run publish` copy the site into `$PARITY_REPORTS_ROOT/raft_flutter_parity/<stamp>` (extension: `raft_flutter_parity_ext/`) with a `latest` link and, unless `--no-verify`, check the served URLs. Do not publish from a task branch; the lead publishes per batch. Functional evidence reports go through `tool/publish-report`.
