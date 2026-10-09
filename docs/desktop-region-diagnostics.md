# Desktop Source-region diagnostics

This tool supplements the desktop report with five Source-defined regions. It
does not change the official 402-case input, baseline PNGs, comparison thresholds,
anti-alias handling or whole-frame acceptance. The official whole-frame JSON is
copied byte-for-byte into the separate diagnostic report.

## Measurement contract

The reference is Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`:
[MainLayout.tsx:1223–1227](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L1223),
[MainLayout.tsx:2430–2474](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L2430),
and [PanelHeader.tsx:178–242](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/ui/PanelHeader.tsx#L178).

| Region | Read-only DOM ownership |
| --- | --- |
| Rail | `workspace-left-rail` |
| Sidebar | `sidebar-root`; absent on routes with no such mounted sidebar |
| Header | One visible `panel-header` at the main frame's top/content width, after its declared ancestor CSS border/padding insets |
| Body | The entire measured main frame below that header, including tabs/composer; the full main frame when no top-level header exists |
| Right panel | `thread-side-column` or `workspace-secondary-sidebar`; absent when neither is mounted |

Every candidate retains its actual DOM rectangle and visibility. Multiple
visible candidates produce `ambiguous`; mounted invisible candidates produce
`hidden`; no mounted candidate produces `absent`. Missing captures remain
`unmeasured`. None receives a score or credit as a pixel pass. Header ownership
uses declared CSS insets, not a positional tolerance: Activity and Settings
place their headers inside real attached Panel borders. The body is a documented frame
remainder, not a text/content crop or a score-selected subsection.

The same Source rectangle applies to both original PNGs. Flutter's own probe
rectangle cannot move its comparison box. Pixel centers in half-open DOM boxes
determine raster membership at the recorded DPR, keeping adjacent fractional
regions disjoint. Out-of-bounds boxes are withheld, not clipped. Unequal image
sizes, mismatched case/theme/viewport/fixture/reference or changed existing Web
probe geometry withhold the region metrics. Original images are never resized,
aligned, normalized or modified. Overlays remain present in the pixels, including
when they cover the underlying rail or body.
The report also lists covered, unassigned and overlapping pixels for every
case. Border pixels outside these layout boxes remain in the whole-frame
comparison; there is no regional aggregate acceptance that can hide them.

Region metrics retain raw RGBA exact similarity, mean absolute delta and the
existing report's delta-greater-than-24 diagnostic. The displayed **region >96%**
count is separate from official acceptance; `formalAccepted` is always false.
Its denominator is the actual eligible measured population, alongside the total
105 cases and each absent/hidden/ambiguous/unmeasured/blocked count. It cannot be
added to the whole-frame pass count. Raw RGBA diagnostics also retain alpha;
they do not reproduce the official comparator's white-flattening operation.

## Use

Use a private, already authorized Source runtime and fresh diagnostic output:

```bash
node tool/desktop-parity/capture-web.mjs \
  --base http://127.0.0.1:15411 \
  --out .local/regions-source-observation \
  --regions-out .local/regions-dom

python3 tool/desktop-parity/analyze-regions.py \
  --results /absolute/path/to/frozen/visual-testing-results \
  --previous-results /absolute/path/to/older/visual-testing-results \
  --measurements .local/regions-dom \
  --out .local/regions-report
```

The optional capture argument records real mounted coordinates using the
existing desktop routes/steps/fixtures. With no argument, the existing capture
path is unchanged. Fresh observation PNGs stay separate from frozen baselines.
The analyzer refuses an existing output directory. Open `index.html` for full
original frames with identical Source region outlines, or read `regions.json`
for coordinates, candidate state, input hashes and admission errors. The copies
and embedded PNG bytes are verified against their original hashes. Official
entries are shown only with matching original input hashes; a stale entry is
explicitly labeled instead of being silently reused.

`--previous-results` is optional. When supplied, the report keeps every manifest
case and all verified official whole-frame regressions, even a one-pixel loss.
Previous/current Source PNG bytes must match before regional change is admitted.
Each change lists the regional similarity delta and its contribution in
percentage points of the original whole frame. Unassigned layout border pixels
are retained separately. These contributions locate the changed pixels; they
do not identify which code change caused them or establish design correctness.
Original previous/current JSON, PNGs, metadata and available batch input receipts
are copied with hashes. Whole-frame status is never reclassified.

Run the focused guard tests with:

```bash
python3 -m unittest discover -s tool/desktop-parity -p test_analyze_regions.py -v
```

The guard suite covers wrong provider-specific boxes, missing/hidden/ambiguous
regions, size and identity mismatches, later DOM geometry drift, out-of-bounds
boxes, the final raster pixel/alpha, fractional region boundaries and unchanged
asset bytes. It does not substitute for the real Source DOM capture.
It also checks previous/current Source-byte binding, stale official input hashes,
unassigned-pixel contribution and retention of tiny full-frame regressions.

## Measured desktop snapshot

Private evidence is `.local/desktop-region-audit/`. The complete current input is
Root `cody-full-desktop-aa0e44b`, product `aa0e44bded98aa3328024973f98475aa96662185`; previous input is `cody-full-desktop-db50083`. The two unmodified official JSONs
and their input receipts are bound to copied PNG hashes in the diagnostic report.
All 105 cases were admitted; Source PNGs matched byte-for-byte across db50083,
a00dbe1 and aa0e44b. Tracked Source product files still matched the pinned commit
(688 files). This task ran no Flutter native flow and changed no product code.

The original whole-frame result remains **2/105**. Mean similarity changed from
**79.332610% to 81.185031%**: **95 improved, 10 regressed**, all retained. The
opaque captures happen to have the same raw exact score as their existing
official entries; the diagnostic tool does not replace that comparator.

| Region | Eligible / total | Absent | Independent region >96% / eligible |
| --- | ---: | ---: | ---: |
| rail | 105/105 | 0 | 7/105 |
| sidebar | 87/105 | 18 | 0/87 |
| header | 99/105 | 6 | 29/99 |
| body | 105/105 | 0 | 27/105 |
| rightPanel | 6/105 | 99 | 0/6 |

Hidden, ambiguous, unmeasured and blocked counts are all zero for this capture.
The six absent headers are Members index and Computers index in each theme.
Missing sidebars/right panels retain their absent state and have no pixel score.
The full JSON preserves every case-specific rectangle and DOM candidate.

An initial full 105-page observation incorrectly excluded attached-Panel headers
when their real left border inset differed from the main frame. Its raw records
are retained. A separate 30-page observation of all Activity/Settings variants
recorded the actual ancestor CSS insets; the final map uses those 30 records plus
75 unchanged initial records. No raster score selected a box. A further six-page
Language/Billing observation recorded computed colors; its rectangles match the
final map exactly. The first report-browser receipt had an incorrect SVG intrinsic
size, also retained; the corrected report loads all nine checked original-frame
SVGs at 1280×800 without browser errors.

Coverage has no overlapping pixels: 75 cases cover the whole raster, 20 leave
56 border pixels unassigned, nine leave 124, and one leaves 62. These pixels
remain measured separately and in the whole-frame result. Regional contributions
plus unassigned contributions reconstruct each of the 105 full-frame changes.

### Every full-frame regression

All table values are **percentage points of the original whole frame**, not
changes in a region's own percentage. `—` means that Source has no eligible region.
Unassigned border contributions of +0.005469 on the five light Settings rows
are retained in JSON; they account for the small difference between column sums
and the whole-frame delta.

| Case | Whole frame | Rail | Sidebar | Header | Body |
| --- | ---: | ---: | ---: | ---: | ---: |
| activity.inbox.brutal | -0.034570 | -0.034570 | — | +0.000000 | +0.000000 |
| settings.language.elegant-light | -2.841211 | +0.007910 | +1.951172 | -4.898242 | +0.092480 |
| settings.language.elegant-dark | -2.540234 | +0.008301 | +1.942383 | -4.800977 | +0.310059 |
| settings.notifications.elegant-light | -0.317480 | +0.007910 | +1.933398 | -4.936621 | +2.672363 |
| settings.billing.elegant-light | -2.837207 | +0.007910 | +1.973926 | -4.943164 | +0.118652 |
| settings.billing.elegant-dark | -2.767480 | +0.008301 | +1.954492 | -4.845996 | +0.115723 |
| settings.administration.elegant-light | -3.341797 | +0.007910 | +1.968262 | -4.927051 | -0.396387 |
| settings.administration.elegant-dark | -3.628516 | +0.008301 | +1.932324 | -4.830859 | -0.738281 |
| settings.applications.elegant-light | -2.772461 | +0.007910 | +1.966016 | -4.940430 | +0.188574 |
| settings.applications.elegant-dark | -3.600098 | +0.008301 | +1.947656 | -4.843164 | -0.712891 |

The Activity Brutal loss is entirely in the rail; its measured header/body are
unchanged. Nine Elegant Settings regressions have a large header loss, partially
offset by improved sidebar pixels. Administration both themes and Applications
dark also lose body pixels; their body defects must remain separate.

### Confirmed Settings composition omission

Actual Source
[SettingsPanel.tsx:7913](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/settings/SettingsPanel.tsx#L7913)
places the header in `Panel bg-layer-canvas-muted`, while its content div uses
`bg-layer-panel`. The observed Elegant header background is transparent and
inherits the parent fill. Whole measured header histograms on Language and Billing
confirm Source/previous Flutter dominant RGBA **[248,248,247,255]** in light and
**[13,13,11,255]** in dark. Current Flutter instead paints **[255,255,255,255]**
and **[36,36,34,255]**. Brutal remains white in all three inputs.

At aa0e44b, `RaftSettingsPanelFrame` uses `t.panel` for both header and content
backgrounds. This omits the parent muted fill after removing the obsolete outer
Settings header. The old header-region score benefited from a matching muted fill
behind an incorrectly composed outer header; it did not prove the old structure
correct. This diagnostic records the verified omission without reverting the
Source structure or changing product code. It does not fully explain the separate
body losses or the Activity rail loss.

### Confirmed Activity caller and retained body provenance

Actual Source footer SVGs are 18×18 for all four Brutal controls. In Elegant,
Bell remains 18×18; Help, workspace mode and Settings render at 16×16 despite
their `size={18}` props, because AppRailItem's descendant recipe overrides them.
The current actual mounted WorkspaceView has these same icon sizes. A larger
looking raster does not establish a new icon-size defect.

Activity supplies a distinct left rail contract:
[MainLayout.tsx:2278](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L2278)
passes `thinDivider={isActivityRoute}`;
[LeftRail.tsx:563](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/LeftRail.tsx#L563)
applies `theme-brutal:!border-r`. Its observed Brutal footer buttons start at
x=11.5 and SVGs at x=22.5. Current WorkspaceView starts them at x=11 and x=22:
the shared rail reserves its generic 2px border without this 1px caller override.
Changing the rail from DecoratedBox to a border-reserving Container exposed that
omission. Elegant coordinates and footer icon sizes agree in the three-theme
mounted diagnostic; this is geometry evidence, not raster acceptance.

The retained Activity whole-frame loss is **354** matching pixels of 1,024,000:
Bell −9, Help +1, workspace −24, Settings −21, and the rest of the Source rail
−301. These additional button boxes came from actual DOM controls, not a
similarity search. They do not change the five-region denominator. The matching
pixel arithmetic does not prove that the thin-divider omission causes every
one of those changed pixels.

For Administration and Applications, the old/current app files
`admin_views.dart`, `integrations_views.dart`, `workspace_settings.dart`,
`settings_page.dart`, and `management_support.dart` have identical Git blobs.
The preserved native frames show the same old management title, Refresh control
and form rows moving up after removing the obsolete 56px outer Settings header.
Actual Source Administration instead starts with Owners & Admins, System
channels, Pending invites and Invite links. These missing cards and the extra
generic management title predate the composition correction. Their body losses
remain recorded as failures, rather than being relabeled as improvements.

The integration owner separately verified the retained overlapping body strip
on Administration light/dark and Applications dark: all 676,992 corresponding
RGBA pixels are identical after accounting for that 56px parent relocation.
The newly visible bottom 56px has no previous counterpart. This causal audit is
preserved at Root `.local/cody-settings-body-shift-audit.json`; the region tool
does not shift images or use that strip to replace the official whole-frame
score. No new body-code mutation was identified in these three regressions.

Additional private evidence: `footer-style-measurements/`,
`activity-rail-footer-decomposition.json`, the three
`current-footer-*.json` mounted measurements, and
`current-footer-geometry-rerun.log`. The first private geometry probe had two
duplicate-widget finder errors; its original log is retained. The corrected
probe identifies actual Elements and records all three themes without errors.

Artifacts: `report-aa0e44b/index.html`, `report-aa0e44b/regions.json`,
`diagnostic-input-audit.json`, `measurement-selection.json`,
`settings-header-composition.json` (actual DOM CSS and complete header histograms),
`source-product-readback.json`, and `report-final-browser-check.json`. The 13
region-tool guard tests and two existing whole-frame tests pass; syntax checks
are clean. No public report was published by this task.
