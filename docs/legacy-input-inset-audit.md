# Legacy input inset audit

## Actual Source contract

The authority is Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` and its installed CSS. `packages/web/src/index.css:675–678` composes `.input-brutal` from `shadow-raft-xs`, changing to `shadow-raft-sm` on focus. Lines 712–713 override the Brutal root with its hard product shadows. The actual form caller at `packages/web/visual-testing/VisualTestingCases.tsx:2808–2814` uses two ordinary read-only inputs and one explicit `!border-brutal-red ring-2 ring-brutal-red/60` input. Its white caller canvas is unchanged.

A private real Chromium audit at normal zoom, 390×844 and DPR 3 records the actual neutral and focused input styles in `.local/legacy-input-source-states.json`, with six raw Source rasters. Dark neutral shadow-xs includes a 1px white inset at alpha .045. Focus shadow-sm includes two white inset layers at alpha .05 and .03. Brutal inputs are 44px high; Elegant inputs are 42px. Fonts stay Hanken Grotesk and Inter respectively. The Source nodes, generated specified recipes and all official PNGs are unchanged.

## Consumer repair

`RaftTextInput` previously discarded every inset layer when `chrome` was `legacy`. This branch now supplies the actual legacy utility composition to the existing `RaftRecipeBox`, while retaining the explicit product border, padding, hard Brutal outer shadows and invalid ring. The recipe-default input path remains on that same existing shared painter. This commit changes no global renderer, shadow token, color conversion, opacity rule or baseline.

`legacy_input_previews.dart` provides a real editable preview in each theme with invalid and caller-padding controls. `legacy_input_surface_test.dart` covers the actual neutral/focus shadow contract, a DPR3 raster regression for the formerly absent inset band, real mouse/touch input, Japanese IME composition and selection across invalid/theme repaint on each sampled frame, submission, read-only semantics, disabled behavior and the interactive preview. These are component proofs; they add no product-page checklist or native-flow count.

## Frozen selected comparison

The official form case is captured against the same three frozen Source PNGs as the prior full matrix. `.local/legacy-input-comparison.json` verifies their original SHA256 bytes and records exact metrics. The strict >96% threshold, AA and dimensions are unchanged.

| Theme | Pixel similarity before → after | Status |
| --- | --- | --- |
| Brutal light | 97.459960% → 97.455350% | PASS → PASS |
| Elegant light | 98.221906% → 98.215760% | PASS → PASS |
| Elegant dark | 94.994446% → 94.986983% | DIFF → DIFF |

The semantic repair improves 8,316 of the 8,320 previously absent dark top-edge pixels from reference [45,45,43] versus Flutter [36,36,34] to Flutter [46,46,44]. The remaining one-byte compositor difference still fails the unchanged exact-pixel metric. RGB similarity improves 99.804443%→99.831506% in dark; no new selected PASS is claimed. Earlier missing-band and failed compile/test receipts remain preserved instead of being relabeled.

Candidate artifacts are `.local/legacy-input-candidate-{brutal-light,elegant-light,elegant-dark}`. Original evidence is `.local/foundation-validated-dark` and the immutable `.local/foundation-frozen-cache` PNGs. The six raw Source screenshots remain `.local/legacy-input-source[-focus]-*.png`; they are observations, not replacements for accepted baselines.

Final combined validation covers the 13 new legacy checks, nine existing control-transition checks, the override paint regression and four existing field checks: 27 PASS. SDK and application analysis are clean. Logs are `.local/legacy-input-final-sdk3.log`, `.local/legacy-input-final-analyze3.log` and `.local/legacy-input-app-analyze.log`. No application file or DS baseline changed. Full297, desktop105, Linux native and Android native runs remain the parent agent's separate consolidation work.
