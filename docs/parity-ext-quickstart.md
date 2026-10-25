# Parity extension: agent quickstart

One page for adding or fixing a surface in the extension suite
(`tool/parity-ext/run`; background in docs/parity.md "Extension suite").

## Add a surface

1. **React host** `tool/parity-ext/host/<Area>Cases.tsx`: expose
   `function parityExt<Area>Element()` returning the element for your case ids,
   otherwise `null`. Fixture data: `import x from "virtual:parity-ext/<name>"`
   (= `tool/parity-ext/fixtures/<name>.json`). `tool/parity-ext-web.mjs` appends every host file.
2. **Builder** `tool/parity-ext/build-<area>.py`: replace your `components.<area>.*`
   cases in the manifest at `manifest_path()` (`from builders import manifest_path`; copy
   `build-notification-card.py`). It may also write `fixtures/<name>.json`. The manifest
   (`build/parity-ext/cases.json`) is generated every run and never committed.
3. **No registration**: every `build-*.py` is discovered automatically (`build-cases.py` first, then by an optional
   top-level `ORDER = n` constant in the builder, default 1000, then by file name). Add `ORDER = n` only if your
   builder must run before or after another one (it reads/amends the manifest); no shared file is edited.
4. **Flutter**: `apps/raft_flutter/test/parity/cases/ext_<area>.dart` with a public top-level
   `final Map<String, ParityCase> ext<Area>Cases = {...}` keyed like the case's `androidCaseHint`. That is the whole
   registration: `tool/parity_case_map.py` (run by `tool/flutter`, `tool/parity`, `tool/parity-ext/run`) merges every such
   map into the git-ignored `case_map.g.dart`; never edit `case_map.dart`. Use a unique map name and unique case ids
   (a duplicate id throws at startup). Reasons for ids without a widget go in a `Map<String, ParityUncovered> ext<Area>Uncovered`.
   Crop with `capture.androidKey` (a `ValueKey` in the widget); interactions with `capture.androidInteractions`.

## Levels and looks

Every case belongs to a level (frame / page / component, `tool/parity-ext/levels.py`: add your surface there) and renders in
three looks. Cases name their old theme (`brutal`, `elegant`, `elegant-dark`); on the Web all three light names are the one Raft
page and `elegant-dark` is its dark mode, so the Raft look reads one light and one dark name per case. Slice runs:
`tool/parity-ext/run regress --level page --theme raft --mode light` (docs/parity.md "Visual suite levels and looks").
A new whole-window page case belongs in an existing family when the route is already there (e.g. `build-members-pages.py`
`window.*`); a new family needs a `host/<Area>Cases.tsx`, a builder and `cases/ext_<area>.dart` as above.

## Run only your cases

```bash
export PARITY_EXT_WEB_PORT=4xxx        # unique per agent; the default 4396 collides
tool/parity-ext/run run --cases 'components.<area>.*'   # comma list / globs; --refresh-react to recapture
```

Results: `build/parity-ext/summary.md` (per-case table, per-area table) and `site/index.html`.

## Done criterion

**Geometry pass** for every case of your area: `summary.md` column "non-text" >= 99.5%
(similarity after counting pixels classified as text glyph anti-aliasing as matching;
`tool/parity-ext/analyze-diffs.py --cases <glob> --viz DIR` shows where the rest is, as
fill / hairline / corner / offset / text / other). The official 96% "exact" pass is reported next
to it and is not the target. **Never iterate on text anti-aliasing** (text bucket); fix layout,
colour, spacing, borders, radii, and glyph positions that move by whole pixels.

## React cache

Captures are cached across worktrees in `/home/kevinzhow/github/raft-flutter-wt/.parity-cache/react/<key>.png`
(`PARITY_EXT_CACHE` overrides). Key = raft-source commit, the case JSON without Flutter-only
fields, the fixtures and host `.tsx` that render it, `parity-ext-web.mjs`, the spec patches and
render flags. Edit a host/fixture/case and only its cases recapture; Flutter edits never do.
`--refresh-react` ignores and overwrites the entries. Each entry has a `.key.json` listing its inputs.

## Theme sampling

brutal-light (the default theme) runs every case. elegant-light and elegant-dark run 1-2 cases per surface
(`components.<area>.<surface>`): the first case in builder order plus one dense case (name with a density word such as
`long`, `many`, `mixed`, `gallery`, `filled`, `full`, `rich`, `multi`, `batch`, else the last case of the surface);
rule and word list in `tool/parity-ext/sampling.py`. Write your builder so the surface's FIRST case is its default
variant. `--cases` globs only see the sampled manifest; set `PARITY_EXT_ALL_THEMES=1` to run an elegant case that
sampling dropped (`PARITY_EXT_ALL_DARK=1` keeps every elegant-dark case; elegant-light stays sampled).

## Extreme-theme check

Finds what the Raft look paints without reading the theme pack (docs/theme-contract.md section 8, "User theme"). Flutter
only, no Web capture, **not part of the gate**; run it under `taskset` / `nice` on a shared machine.

```bash
export PARITY_RAFT_SOURCE=<raft-source checkout>   # fixtures and the official case list
tool/parity-ext/run extreme --plan-only            # the Raft cases it would render (regress plan, light + dark)
tool/parity-ext/run extreme --level page --mode light --cases 'components.settings.*' --out /tmp/<you>/extreme
tool/parity-ext/run extreme --out /mnt/data/tmp/<you>/extreme --shards 2 --jobs 2   # everything; resumes
```

How it works (`tool/parity-ext/extreme.py`, differ in `extreme_diff.py`, tests `tool/tests/test_extreme_diff.py`):

1. `tool/parity-ext/extreme_pack.py` generates the test-only user pack
   `apps/raft_flutter/test/parity/fixtures/extreme.theme.json` (`extends: raft`; every colour role and palette entry a loud
   value per family, every geometry token moved, radii 40, strokes 0, type slots +8, fonts the pinned mono, shadows none).
   Names come from `contract_names.g.dart`, so a new role cannot be skipped; `--check` and `packages/raft_theme/test/extreme_pack_test.dart`
   keep it current. The harness loads it through `RaftThemePack.parse`, the path every user pack takes (override `extreme-case`, like `raft-case`).
2. With `PARITY_PAINT_OPS=1` the harness captures the whole viewport and writes `<case>.ops.json` beside the PNG: a second paint of
   the render tree into a recording canvas (`apps/raft_flutter/test/support/paint_ops.dart`) with each drawing call, its bounds,
   colour, radii, stroke and the render object / widget (`--track-widget-creation` file:line) that painted it. Each case is rendered
   in Raft, Raft with the extreme pack, and (as evidence) the normal Elegant and Brutal packs.
3. The differ lists pixel regions identical in the Raft and extreme renders (glyph interiors, images, vector art and the test harness are
   ignored) and maps each to the widget that painted it, and lists paint ops whose colour / radius / stroke / font size / family / shadow did
   not move. Entries are ranked by widget class and source file; each is classed a (the same widget paints a different value in
   Elegant or Brutal: likely defect), b (identical in all looks: possible shared form, contract 3.3) or c (no evidence).

Output: `<out>/report/extreme-theme-report.md` and `.json`, `<out>/report/shots/` (side-by-sides of the worst cases). Keep the report out of the
repo (the branch `cindy/extreme-theme-shots` holds one run). `--force-render` / `--force-analysis` redo steps; `--analyze-only` and `--report-only`
reuse earlier renders.

## Page inventory

The page inventory lists every Web page / modal / state and which have a brutal-light case (official id or extension id)
or none. It is **generated on demand and not committed**:

```bash
python3 tool/parity-ext/inventory.py --write build/parity-ext/page-inventory.md   # or --stdout
python3 tool/parity-ext/inventory.py --check                                      # validate rows / id globs only
```

Rows in `tool/parity-ext/inventory.py` hold Web page metadata, the *expected* case-id globs per platform (`d=`, `p=`,
official `off=`) and the excluded / verify marks. ok / partial / MISSING / web-only is **computed** from the case ids that
exist in the built manifests and the Flutter `noFlutterSurface` flags (read from a parity-ext run's
`visual-testing-results/android-case-map.json`), so adding cases for a listed page edits nothing. Only a **new Web page**
needs a new row (or a MISSING row gets the glob of the ids you now built); never write a status. `--check` fails on
malformed globs and on globs matching the other platform's cases, not on documents.

## Rules

- No full-suite runs (`run run` without `--cases`) and no `tool/check-project` per task; the lead runs them per batch.
- Run your cases once per change, read the output once. No polling or sleep loops; no sub-agents.
- Do not publish; do not touch the raft-source checkout; do not commit `build/`.

## Scoring against the P2 (a57b9dab) baseline

`tool/p2-score.mjs` compares a fresh capture against the pre-theme baseline images
with the **official** metric, not a lookalike: it calls the same
`pixelPerfectSimilarity` / `rgbSimilarity` arithmetic as
`raft-source/packages/visual-testing/src/sharp-image-overlay.mjs`, so a number here
means the same thing as a number in the parity report.

```bash
node tool/p2-score.mjs <baseline-android-dir> <current-android-dir> out.json
```

Both directories hold `<case>.png` plus `<case>.metadata.json`; the comparison box is
the baseline's own `crop.rect`. The table it writes is the "never drops" reference for
each migration batch — keep it outside the repository.

Why it exists: the parity run measures a case against the React reference, while
Elegant and Brutal are supposed to match the *pre-theme Flutter* build. Those are
different references, so this scores the Flutter-vs-Flutter pair directly.

`tool/tests/test_p2_score.py` pins the property that makes the numbers trustworthy: an
image scored against itself must be exactly 100%, and a mutated copy must score below
it. Both skip when the baseline data is not on the machine.
