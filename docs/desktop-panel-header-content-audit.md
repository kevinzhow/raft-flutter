# Shared desktop PanelHeaderContent flow

The shared Flutter channel and detail headers now consume the real PanelHeaderContent recipe direction and spacing. Elegant desktop titles and metadata form a baseline-aligned row; Brutal and narrow Elegant headers remain columns. One Flex layout owner changes direction in place, and channel metadata uses the existing CSS line-box widget. Font tokens, generated recipes, caller actions, renderer and comparator are unchanged.

## Actual Source authority

Pinned Source is `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, with installed raft-ui0.5.27. The actual [PanelHeader.tsx composition](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/ui/PanelHeader.tsx#L219) has PanelHeading/PanelTitle followed by a real PanelMeta child. Both [ChatPanel.tsx1363](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/message/ChatPanel.tsx#L1363) and [HumanDetailPanel.tsx295](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/member/HumanDetailPanel.tsx#L295) mount this composition. The generated recipe already contains desktop row/8px-gap declarations, and its real `has:>data-slot=panel-meta` state changes alignment to baseline.

Actual browser DOM at1280×800/DPR1 confirms:

| Contract | Brutal | Elegant light/dark |
| --- | --- | --- |
| HeaderContent direction | column | row |
| Title/meta alignment | same left edge | shared baseline; 8px horizontal gap |
| Title face/size/weight/line box | Hanken Grotesk16/700/20px | Inter17/500/21.25px |
| Title tracking | normal | −0.425px |
| Meta face/size/line box | Geist Mono12/16px | Geist12/12px |

Channel Source title/meta begin at x376/x436.15625 in Elegant; Human profile begins at x376/x453.625. The Flutter consumers previously stacked these pairs at x376. Readback of their actual Linux RichText styles confirms the existing fonts, weights, tracking and declared line heights already match Source. This repair therefore changes content layout and existing line-box consumption, with no font substitution or pixel offset.

Source's exact outer header decoration differs by caller: channel has a bottom border while profile does not. Existing caller chrome/back-button differences and raster/text-rendering differences are retained outside this bounded shared-content change.

## Frozen paired native evidence

The Source baseline PNGs are copied byte-for-byte from Root `.local/cody-full-desktop-a00dbe1/visual-testing-results/react`. Fresh diagnostic Source DOM/PNGs are stored separately and never promoted. Before and after are private actual Linux/Xvfb renders of WorkspaceController/WorkspaceView using the same immutable desktop fixture and unchanged navigation flow. Read-only RichText probes record real style/geometry alongside the captures; their temporary harness additions were restored before this commit. Root build output, fixture backend and emulator were not used.

The unmodified pinned Source visual-testing CLI, desktop manifest and comparator give:

| Actual screen | Before similarity | After similarity | Result |
| --- | ---: | ---: | --- |
| Channel Brutal | 91.325195% | 91.325195% | DIFFERENT; native PNG unchanged |
| Channel Elegant light | 89.339648% | 89.341699% | DIFFERENT |
| Channel Elegant dark | 89.354199% | 89.356348% | DIFFERENT |
| Human Brutal | 87.638965% | 87.638965% | DIFFERENT; native PNG unchanged |
| Human Elegant light | 93.016504% | 93.083984% | DIFFERENT |
| Human Elegant dark | 87.445313% | 87.447559% | DIFFERENT |

Actual native metadata places Elegant channel description at x436.143848 and Human metadata at x453.613670, following each measured title advance plus the resolved8px gap. Both Brutal PNGs remain byte-identical. All six residual differences are preserved; there is no claim of whole105/297 acceptance or full authenticated native replay.

Private evidence under `.local/desktop-header-audit/` contains `comparison.json`, `frozen-source-receipt.json`, `native-measurements.json`, before/after raw PNGs/provider metadata/official diff, source channel/Human/Agent DOM observations, process logs and original failing receipts. `capture-receipt.json` binds the input files and probe boundary.

## Focused validation

- 28 SDK tests pass: actual three-theme/narrow/desktop shared header geometry, alphabetic baselines, real caller action input, constrained titles, retained title render owner and editable action focus/selection through theme changes, plus existing menu and black-flash transition regressions.
- 34 application profile typography and actual shell/sidebar/footer tests pass.
- Six actual private Linux captures complete and are compared with unchanged frozen Source bytes.
- SDK/application analysis is clean; design-system audit reports no baseline growth; `git diff --check` is clean.
- The existing narrow interactive Preview remains available, and a three-theme desktop Preview exercises both real shared header consumers and their actions.

The prior failing geometry receipt and a test-measurement API failure remain archived. The latter was corrected to use Flutter's supported dry-baseline readback; expected Source geometry and behavior were not relaxed. General Markdown wrapping remains outside this repair.
