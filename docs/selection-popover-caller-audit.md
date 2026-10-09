# SelectionPopover default and caller surfaces

This repair keeps the product default separate from the actual explicit caller
in the original visual case. `RaftSelectionPopover.surfaceStyle` accepts the
resolved Card surface after a caller's CSS recipe composition. A null value
uses the Source SelectionPopover default. Both paths render the same live search
TextField, option controls and semantics; a white surface in the official dark
case is an intentional Source caller override.

## Pinned authority

Source commit: `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`.
Installed `raft-ui` version: `0.5.27`.

- [SelectionPopover.tsx117–176](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/ui/SelectionPopover.tsx#L117)
  supplies a theme panel, muted border and small shadow by default. The default removes the underlying Card border-color utility before
  applying its actual product classes; retaining `border-line-strong` would
  override Brutal literal black through CSS order. Card retains
  its Elegant rounded corners and dark transparent-border rule. The header,
  search band and option list are actual children of that Card.
- [The actual visual caller](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/visual-testing/VisualTestingCases.tsx#L3105)
  replaces the whole SelectionPopover `className` with
  `w-full overflow-hidden border-2 border-black bg-white shadow-brutal`.
  It leaves Card's surviving radius, dark border rule and shadow utilities.
- The installed `dist/index.mjs` Card recipe and its actual class-merging
  evaluator establish which utilities survive. Chromium computed styles,
  using the frozen font CSS and WOFF2 bytes, independently confirm the result.
  A separate private fixture-host probe omits only that caller `className` to
  render the real default component. It does not replace any official fixture,
  reference image or Source file.

Measured surface contract:

| Surface | Brutal light | Elegant light | Elegant dark |
| --- | --- | --- | --- |
| Default background | white | layer-panel / white | layer-panel |
| Default border | 2px black | 1px line-muted | 1px transparent |
| Default radius | 0px | 8px | 8px |
| Default shadow | product brutal, 4px offset | theme small | theme small, including inset layers |
| Explicit caller background | white | white | white |
| Explicit caller border | 2px black | 2px black | 2px transparent |
| Explicit caller radius | 0px | 8px | 8px |
| Explicit caller shadow | surviving Card medium | surviving Card extra-small | surviving Card extra-small with inset layers |

The SDK paints these resolved surfaces with `RaftRecipeBox`. CSS overflow clips
children at the inner rounded padding box; a transparent dark border still
occupies its actual layout width. The caller maps the original four labels,
checked/disabled states and search value unchanged.

## Search line geometry and input behavior

The Source search Input is inline in its inherited text line. The official
caller's ancestor is `font-display`: Hanken Grotesk in Brutal and Inter in
Elegant, at 16px/24px. Its Input uses Geist Mono at 12px/16px, 8px horizontal and
4px vertical padding, and the actual recipe border. Chromium measures a 28px
Input in a 45px Brutal search band, and a 26px Input in a 44px Elegant band. The
latter includes 1px of real inline baseline expansion. Using theme `font-sans`
(Geist) as the anonymous parent line would suppress that expansion.

The SDK reuses `RaftCssInlineBox` with the resolved inherited Card text style.
It does not add a theme-specific positional correction. With the actual caller
and four 36px options, measured outer heights are 225px Brutal and 224px Elegant;
the default's 1px Elegant border gives 222px instead.

A newly mounted real TextField must acquire focus even when the trigger already
owns focus. A popup-owned focus scope admits its HTML-equivalent autofocus, and
`TraversalEdgeBehavior.parentScope` lets Tab leave the last option. The scope is
stable during recipe/theme changes and disposes when its owner removes the
popup. Dismissal remains owned by the parent, as in Source: `dismissLayerProps`
is a marker, not a close handler. The interactive Preview demonstrates a parent
that closes on Escape or outside press and restores trigger focus.

Usage: resolve the real Card recipe through `package:raft_ui/recipes.dart`,
compose the caller's final CSS properties and surviving targets/classes into a
`RaftSlotStyle`, then pass it as `surfaceStyle`. The three-theme interactive
example is [selection_popover_previews.dart](../packages/raft_ui/lib/selection_popover_previews.dart).
Its literal white/black/2px overrides belong to the explicit Source caller;
they do not change the default's theme tokens.

## Validation and retained limits

The new SDK tests load real bundled fonts and check all three themes: default
versus caller surface and line geometry; actual EditableText identity, focus,
IME composition and keyboard selection across surface/theme changes; pointer
hit coordinates; Tab leaving the popup; checked/disabled semantics; actual
Clear and option callbacks; owner Escape/outside close, trigger focus and
keyboard reopen. These are mounted component/Preview checks, not product-page
or native-platform receipts.

Selected official probes use the frozen original React PNGs from Root's
`86309ef` matrix. All 12 cached React PNGs in the surrounding four-case,
three-theme sample were rehashed against their immutable receipt. Only the
three SelectionPopover states are freshly captured in this batch. Android is
the parity provider name: these are Linux Flutter widget captures with
`TargetPlatform.android`, not device Android tests.

| Official selected case | Original 86309ef | Prior 769c320 | This repair |
| --- | ---: | ---: | ---: |
| Brutal light | 98.958% | 98.958% | 98.958% |
| Elegant light | 85.182% | 84.469% | 98.822% |
| Elegant dark | 62.802% | 62.802% | 96.289% |

All three exceed the original >96% threshold. The strict >99% threshold remains
unmet. No Source web product, official ID/content, React image, font/AA setting,
metric, threshold or general Markdown behavior changed. This selected result
does not establish a new full 297/402 total, consumer routing/dismissal parity,
or native-platform proof.

Private evidence under the Composer worktree `.local/`:

- `selection-caller-baseline-byte-receipt.json`: all 12 frozen React byte hashes.
- `selection-source-geometry-fonts.json` and
  `selection-default-source-geometry-fonts.json`: actual caller and separately
  derived default Chromium DOM/style measurements with frozen fonts.
- `selection-source-baselines.json`: read-only actual Chromium font baseline
  probe; `selection-flutter-metrics.log` retains the Geist/Inter diagnosis.
- `selection-caller-candidate1-dark/` and `candidate2-dark/`: retained 88.99%
  intermediate DIFF; inherited-font correction is not hidden by that result.
- `selection-caller-validated-{brutal,light,dark}/`: final selected captures and
  official raw-size Sharp metrics; earlier final/candidate receipts remain.
- `selection-caller-validated.log`: 34 targeted checks, including the existing
  three-theme shared transition and resolved-radius regressions.
- `selection-caller-sdk-analyze-final.log`, `selection-caller-app-analyze.log`
  and `selection-caller-ds-audit.log`: analysis and design-system audit. Intermediate
  visual differences, the original default-border assertion failure, and
  initial test-authoring receipts remain private.
