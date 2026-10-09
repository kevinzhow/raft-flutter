# CSS recipe corner overlap

The pinned raft-ui 0.5.27 recipes resolve Elegant Badge and human Avatar
`rounded-full` to Chrome's maximum finite float,
`3.4028234663852886e+38px`. The generator preserves that value in
`recipe_utilities.g.dart`; `tool/recipes/lib/css-value.mjs:548` explains its
`calc(infinity * 1px)` origin. The theme and generated CSS lengths were correct.
Passing this radius directly to the renderer produced square corners because
its single-precision radius arithmetic overflowed.

`RaftRecipeDecoration` reduces overlapping corners against the actual border
box with Dart's double-precision `RRect.scaleRadii()` before painting, clipping,
or hit testing. This preserves relative corner proportions and respects caller
size overrides. Generated values, color resolution, animation interpolation,
and ordinary opacity remain unchanged. Recipe boxes, inset layers and outer
shadows use the same actual-size geometry. Existing custom premultiplied color
and shadow interpolation remains in `RaftCssBoxDecoration`.

Private before/after captures use the same Flutter commit 1147ffa, with only
this SDK patch restored or applied. All six selected React PNG hashes equal
the frozen 297-case matrix's corresponding hashes. The aggregate Source
receipt hashes differ because concurrent private process evidence changed
the Source testing directory; the compared React bytes are identical.

| Original case | Theme | Before pixel similarity | After | Acceptance |
| --- | --- | ---: | ---: | --- |
| Badge states | Brutal light | 98.3237% | 98.3237% | PASS |
| Badge states | Elegant light | 96.5138% | 97.6626% | PASS |
| Badge states | Elegant dark | 96.6056% | 97.7516% | PASS |
| Agent profile | Brutal light | 96.6827% | 96.6827% | PASS |
| Agent profile | Elegant light | 81.5903% | 81.6177% | DIFF |
| Agent profile | Elegant dark | 81.3530% | 81.3445% | DIFF |

Brutal Flutter PNGs are byte-identical before and after. Both Elegant Agent
profile cases remain DIFF; the dark aggregate score decreases by 0.0085
percentage points. This patch fixes a measured shared radius defect and does
not claim the remaining Agent profile layout, typography or colors are aligned.
Original IDs, thresholds, React baselines and Source product code were unchanged.

Evidence remains private in `.local/css-radius-before/` and
`.local/css-radius-after/`. These are Linux host Flutter widget captures with
the Android provider, not native Linux or Android application evidence.
Focused SDK verification covers generated Badge and Avatar painting, clipping,
hit geometry in all three themes, unequal CSS corners, finite radii, existing
black-flash transitions, decoration overrides and generated recipe contracts.
The final selected SDK run passed 73 tests, with one existing generator-output
test skipped because its optional build artifact was absent; the checked-in
recipe parity test passed. SDK analysis reported no issues.
The root integration run owns the full matrix and native regression checks.
