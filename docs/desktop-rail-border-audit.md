# Desktop rail border-box follow-up

The real Brutal rail centers its 40px children inside the 62px content area of a 64px CSS border box. Flutter previously painted the 2px right border without reserving it for layout, placing children at x=12 instead of the measured Source x=11. The shared rail now reserves the resolved border width. Its outer width, callbacks, theme values and footer composition are unchanged. Explicit zero padding retains the same child state owners across theme changes.

## Source contract

Pinned Source is `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`. The actual caller is [LeftRail.tsx567–630](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/LeftRail.tsx#L567), using the installed raft-ui AppRailRoot recipe. At the real 1280×800 DPR1 desktop fixture, DOM evidence measures Brutal rail width64/right-border2 and primary/footer button x11/width40. Both Elegant modes have width56/no border and button x8/width40. No physical-window or font-renderer compensation is applied.

## Private paired Linux evidence

The frozen Source PNGs are copied byte-for-byte from Root `.local/cody-full-desktop-a00dbe1/visual-testing-results/react`. The before native PNGs from the prior private actual Linux capture match Root a00dbe1 byte-for-byte. The candidate was captured by the unchanged `tool/desktop-parity/capture-flutter.sh` against the real WorkspaceController/WorkspaceView, the shared immutable desktop fixture, and a private Linux build/Xvfb process. It uses no shared fixture backend or emulator.

The pinned Source visual-testing CLI and unchanged desktop manifest provide these selected results:

| Actual channel screen | Before similarity | After similarity | Result |
| --- | ---: | ---: | --- |
| Brutal | 91.292285% | 91.325195% | DIFFERENT |
| Elegant light | 89.339648% | 89.339648% | DIFFERENT; native PNG unchanged |
| Elegant dark | 89.354199% | 89.354199% | DIFFERENT; native PNG unchanged |

Native metadata confirms Brutal primary button x12→11, y70/size40 unchanged, and sidebar x64 unchanged. Both Elegant candidate PNGs are byte-identical to their before images. The remaining screen differences are retained; these three captures do not establish acceptance of all105 desktop cases or a full authenticated native workflow.

Private artifacts under `.local/desktop-rail-border/` include `frozen-input-receipt.json`, `comparison.json`, before/after raw PNGs and provider metadata, official diff output, native process log and focused test/analyzer receipts. Fresh diagnostic Source DOM/PNGs remain separate under `.local/desktop-header-audit/source-observation/` and never replace frozen baselines. The original failing Brutal geometry test is retained in `sdk-before.log`.

## Validation

- 33 focused shared SDK tests pass, including measured border-box geometry, real pointer/keyboard paths and retention of the actual Help state owner through three theme transitions.
- 30 actual application shell/sidebar/footer and local Help announcement tests pass.
- Three selected actual Linux captures complete; all frozen Source/fixture inputs and comparator thresholds remain unchanged.
- SDK/application analysis, design-system no-growth check and `git diff --check` are recorded alongside the private artifacts.

Panel header flow/font/line-box differences are a separate read-only investigation; this change does not alter them.
