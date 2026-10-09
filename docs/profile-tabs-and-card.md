# Profile tab artwork and legacy card shadows

Source remains Web `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`,
raft-ui 0.5.27. The original case IDs, thresholds and all 99 React PNGs are
unchanged. Markdown wrapping and calibration review remain paused.

The profile Chat tab now uses the actual raft-ui `ChatIcon` artwork
(`dist/index.mjs:18975`), preserving its 18-unit SVG viewBox and filled dots.
The generic tab recipe resolves its dimensions and colour. CSS stroke widths
are read as numeric dimensions instead of parsing `2.5px` as a bare number;
the pinned Source DOM reports 14px icons with Brutal 2.5px stroke. Elegant
uses the generated 1.5px stroke. `RaftPanelTab.custom` permits source artwork
without substituting a Lucide glyph.

The product `.card-brutal` composition (`web/src/index.css:656,709`) now uses
the existing CSS recipe painter. It retains both Elegant dark inset shadow
layers, which the old plain BoxDecoration omitted. Brutal keeps the product's
literal shadow colour. Every theme uses the same widget path, preserving the
live text field state, selection and draft during theme changes.

SDK preview: `packages/raft_ui/lib/member_profile_previews.dart` exposes the
actual tab strip and card in all three supported themes. Focused checks passed
13 SDK tests and 34 application tests; analysis found no issues. The seven new
tests cover source tab SVG dimensions/stroke, tap/hover stability, live field
state through theme changes, keyboard/mouse/accessibility button activation,
and the omitted dark inset layers. Existing avatar close, busy-save, dirty
draft and permission/account guards remain passing.

Frozen input:
`306c4246681dcb05cbe0b4afeaf63ba5df2c302117c631b99c374d118b6c60e2`.

| Selected original case | Pixel similarity | Result |
| --- | ---: | --- |
| Card, Brutal | 98.072% | Pass |
| Card, Elegant | 93.168% | Different |
| Agent profile | 96.683% | Pass |
| Agent lifecycle menu | 96.385% | Pass |
| Avatar editor | 94.945% | Different |

These five selected original captures have three passes, two differences and
no capture errors. They are a partial check, not a new complete 99-case result.
The independent three-theme matrix captured nine pairs: two pass and seven
remain different. Its receipt confirms unchanged input and Source checkout.
The avatar modal and its grid coordinates were not changed. Background profile
typography, Elegant surfaces and the light card's shadow raster remain
unaccepted; no page-specific text offsets were added. Linux and Android full
application runs were not performed by this parallel task.

Raw evidence in the `cody-parallel-members` worktree:

- `.local/members-final/`: five final original pairs and official metrics.
- `.local/members-three-themes-final/`: nine actual theme pairs and receipt.
- `.local/source-members-measure2/geometry.json`: actual Source DOM readback.
- `.local/members-native-measure.log`: native widget geometry readback.
- `.local/members-ui-tests-final2.log`, `.local/members-app-tests-final.log`,
  `.local/members-analyze-final.log`: focused checks.
- `.local/members-before/`, `.local/members-card1/`: retained earlier captures,
  including the rejected fixture typography experiment.

The typography experiment lowered the Elegant card score; its fixture edits
were removed. Early test-authoring and measurement failures remain in their
separate logs. Final results above come from the frozen input only.
