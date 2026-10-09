# Shared rail primary-color audit

Pinned Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` uses AppRailRoot `bg-primary`. Installed raft-ui `dist/styles.css:105` maps this Tailwind alias to `--primary-400`, whose foundation ramp is `oklch(0.883 0.162 91.89)`. The generated recipe independently resolves it to `primary400` (`recipe_utilities.g.dart`, `_v118`).

The Flutter rail incorrectly used `primaryFill`, an authored Button component role resolving the product hex yellow `#FFD440`. That Button role remains correct for its separate callers. The actual rail uses `#FFD441`. The change selects the existing primary-400 token only in the shared rail recipe; it does not alter colors, generators, Source rendering, screenshots or acceptance thresholds.

## Diagnosis before the fix

Nine original full-frame pairs were inspected: channel chat, Activity Inbox and Language settings, in all three themes. They are from `.local/cody-full-desktop-39448e9/region-report/frames/`, bound to immutable Source PNGs and actual Linux captures. The shared Source coordinates are used without any alignment or cropping in official comparison.

| Source page | Brutal rail exact pixels | Elegant light | Elegant dark |
| --- | ---: | ---: | ---: |
| Channel chat | 3.629% | 95.866% | 93.384% |
| Activity Inbox | 3.121% | 96.129% | 93.694% |
| Language settings | 4.141% | 95.797% | 93.667% |

Blank rail background samples at viewport `(2,100)` are Source/Flutter `(255,212,65)/(255,212,64)` in Brutal, `(248,248,247)` on both light Elegant sides, and `(13,13,11)` on both dark Elegant sides. The channel Brutal Source rail contains 45,081 pixels of the first color; Flutter contains 45,452 of the second. This explains why almost the entire Brutal rail fails exact equality despite a small average color delta. It does not explain every control difference.

Geometry already matches the Source border box: rail64px Brutal and56px Elegant; tall navigation buttons40px; x11 Brutal except Activity x11.5 with its actual1px divider; x8 Elegant. The fix does not change widths, spacing, avatar, attention, selected-state or shadow behavior. Remaining discrepancies are preserved.

## Verification

The existing real shared-rail widget test now reads painted RGBA at the blank background sample in all three themes, alongside existing pointer/keyboard, geometry and state-retention checks. It failed before the product change with blue64 instead of65; the first interrupted asynchronous raster attempt is retained separately. Final focused checks and fresh actual Linux captures are recorded in a new run. Old failures are never relabeled.

Full-frame acceptance remains separate from regional diagnosis. The next published report includes all five actual Source regions and explicit absent-region denominators, together with unchanged 402-item whole-frame criteria and fresh engineering/product-flow evidence.
