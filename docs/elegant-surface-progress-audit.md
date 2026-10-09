# Elegant surface, progress and input audit

This bounded SDK batch starts at `86309efc70c378b69603d7de481eb66efe349aac`. It corrects three Source contracts and preserves the unresolved visual cases. It does not complete Elegant parity or add product-page/native verification.

## Source contracts

Authority is pinned raft-source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, its installed raft-ui 0.5.27, and the frozen original-case three-theme capture at `.local/cody-full-three-themes-86309ef/matrix-results.json` in the main checkout. That completed receipt identifies Source content hash `b68f51e81a81ae40cf71b4f3cc5e5a43c9f9c1e6abad2b911f801a2a3e85e4f8` and the existing Android text-render adapter. Candidate probes read byte-identical cached React PNGs; they do not regenerate Source baselines or claim a new Source checkout fingerprint.

- [SurfaceListItem.tsx](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/ui/SurfaceListItem.tsx) passes state-dependent classes to the actual Card recipe. A selected surface replaces the default shadow with `shadow-raft-sm`. The Card's `dark:border-transparent` remains in the merged class list. Actual mounted CSS gives Elegant surfaces a 1px border and 8px corners. Previously Flutter used the recipe's 0.5px border, manually overrode its dark transparent color, and replaced only outer shadows while retaining the default inset. Elegant surfaces now resolve the complete class cascade, including all selected/hover shadow layers. Brutal keeps its established decoration.
- [ProgressBar.tsx](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/ui/ProgressBar.tsx) uses Progress/Track/Indicator from raft-ui. Installed `dist/index.mjs:11943–12092` defines local progress variables, a dark indicator inset highlight plus two colored outer shadows, and visible overflow for dark determinate tracks. Flutter previously painted only a flat indicator and always clipped it. Both child slots now resolve inherited root variables and use the common recipe painter; dark determinate overflow exposes the glow.
- [SelectionPopover.tsx](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/ui/SelectionPopover.tsx) mounts an autofocus Input. Actual Chromium readback matches both `:focus` and `:focus-visible`; the installed input recipe defines its Elegant focus ring. RaftTextInput previously supplied only focus. It now supplies both states while keeping the same real TextField, selection, controller and composing range.

The existing Flutter Surface fixture also incorrectly replaced Source's literal `text-black` / `text-black/50` child markup with theme ink. Only those two fixture colors were corrected. Product text defaults, fixture IDs, Source markup, React bytes, thresholds and capture dimensions are unchanged. No shared color-fit, AA, Markdown or acceptance changes were made.

The private read-only CSS and real raft-ui class-merge audit is preserved in `.local/elegant-source-computed.json`, `.local/elegant-card-classes.json` and `.local/source-controls-css-cascade-final.log`. The temporary host used port 15411 and was stopped after the audit.

## Selected original-case measurements

Each number is the official Sharp script's pixel-perfect percentage using the frozen React bytes and the existing Flutter widget capture with provider `android`. This is not an Android device run. These are 12 selected pairs, not a full 297/402 run.

| Original case | Brutal before → candidate | Elegant light before → candidate | Elegant dark before → candidate |
| --- | --- | --- | --- |
| SurfaceListItem | 97.045 → 98.466 | 89.491 → 95.940 | 81.933 → 92.460 |
| AvatarListRow | 98.174 → 98.174 | 86.603 → 93.947 | 78.241 → 89.962 |
| ProgressBar | 98.503 → 98.503 | 98.420 → 98.448 | 93.263 → 94.531 |
| SelectionPopover | 98.958 → 98.958 | 85.182 → 84.469 | 62.802 → 62.802 |

Selected mean: 89.051% → 92.222%. Passing pairs under the unchanged `>96%` rule remain **5/12**. All previous passing selected pairs remain passing. Elegant SurfaceListItem at 95.940% remains DIFF; none of the retained failures is relabeled. SelectionPopover light declines 0.713 percentage points and remains DIFF: the Source-correct input ring is now drawn inside its still-incorrect caller chrome. Its separate fixture replaces the whole Card className with white fill, 2px black border and `shadow-brutal`, while Flutter currently renders the default popover. That caller composition must be repaired separately.

Candidate directories under the private composer checkout:

- `.local/elegant-controls-final-{brutal,light,dark}/`: Flutter captures, per-case official metrics and side-by-side images.
- `.local/elegant-controls-before-{brutal,light,dark}/`: same probe against frozen 863.
- `.local/elegant-controls-cache/baseline-byte-receipt.json`: all 12 frozen React SHA-256 values, each copy verified byte-for-byte.
- `.local/elegant-controls-comparison.json`: exact unrounded before/candidate values.

## Checks and limits

`elegant_surface_progress_test.dart` provides nine actual SDK component checks across the three supported themes: surface width/radius/transparency and state behavior, determinate glow/overflow plus value normalization, and editable autofocus rings while preserving keyboard selection, IME composition and live state through theme switching. The final test contract against the original product has 4 passes / 5 failures, preserved in `.local/elegant-controls-original-final-contract.log`; its candidate has nine passes. An earlier test iteration that also asserted internal wrapper count produced 2 passes / 7 failures and remains archived, but is not the final contract.

The focused suite totals **25 passes**, including the existing SelectionPopover keyboard/disabled checks, live search-input checks, all nine three-theme black-flash checks and the radius override paint regression. SDK and app analysis have no issues. The design-system audit remains 727 with no baseline growth. SDK previews show interactive/selected surfaces, determinate progress and a live autofocus field in all three themes.

Remaining failures include shadow/text/avatar raster differences and the SelectionPopover caller composition. Indeterminate Progress remains incomplete: Source defines 1.4s Brutal and 1.6s Elegant keyframes and an Elegant sweep gradient; Flutter still renders a static half-width stripe. The previous comment claiming Source keyframes were absent was corrected. No full matrix, native Linux, Android, background Activity, navigation or platform pipeline was run in this SDK batch; those remain with the integration owner.
