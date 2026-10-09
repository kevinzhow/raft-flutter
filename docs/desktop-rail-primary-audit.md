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

## Fresh actual Linux result

Product `45a873fd41dac89a3a58a493da167e97980694e5`, input hash `c7d7b2456da14a045dfed274c1d1a703ea622ebf1166fc3b922438689c8145ef`. All105 actual Linux captures completed; all105 frozen Source PNGs remain byte-identical, fixture and Source rendering hashes unchanged. The current regional report admits and binds all105 pairs to the unchanged official full-frame output.

- Official desktop2/105 →10/105; full-frame mean82.0414% →83.4845%. Of105 frames,37 improve,1 worsens and67 are identical.
- Mean rail exact equality64.1212% →93.3595%. All35 Brutal rails improve: their mean3.9235% →91.6383%. Both Elegant rail sets are byte-identical to the previous version. The rail diagnostic count remains7/105 above96%; no Brutal rail reaches96% yet.
- The representative channel Brutal rail3.629% →91.590%; its entire remaining page is byte-identical to the previous capture. The channel rail still has4,306 mismatching pixels, including1,902 where Source literal black is Flutter foreground-strong (1,598 on the root divider). The server avatar and unread/control rendering remain separate visible gaps. The fix addresses only the identified background role.

| Actual Source region | Above96% diagnostic | Absent among105 |
| --- | ---: | ---: |
| Rail | 7/105 | 0 |
| Sidebar | 0/87 | 18 |
| Header | 35/99 | 6 |
| Body | 27/105 | 0 |
| Right panel | 0/6 | 99 |

### Every remaining capture change is retained

The single declining frame is `chat.thread-open.elegant-dark`: exactly40 native pixels at x904–905/y706–725 change to the composer cursor color. It loses29 previously matching pixels (−0.002832 percentage points), while every other pixel and the whole rail are unchanged. Source capture hides the cursor; this desktop native harness does not. The original failing pair remains in official results without a mask or correction.

The3 Saved frames also differ outside the rail only in the third row age:110→111 days. Its timestamp is2026-06-21T09:12Z; resourceRelativeTime uses nearest-day rounding and the desktop fixture does not inject its optional clock, so the threshold is2026-10-09T21:12Z. These old/new captures straddle that time. The3 channel-loading frames have small differences within the existing animated sidebar loading rows. Neither of these changes is credited as a product improvement from the rail fix. All source/current/previous images and differences are retained.

Private diagnosis files under `.local/cody-rail-primary-diagnosis/` preserve the9 original pair hashes/colors,105 before/after pixel counts, residual color decomposition and out-of-rail changes. The first regional invocation used the capture parent rather than its visual-testing-results directory and admitted zero cases; it is retained under region-report-wrong-input. The corrected invocation admits all105. No failed or unmeasured result was rewritten into a pass.

Engineering2676 PASS/3 existing SKIP,75 host tests and all-project analysis PASS;15 separate region-tool guards PASS. The58 mapped suites regenerate the checklist as21/49, leaving K10 partial. These tests do not substitute for complete Linux/Android authenticated flows.

## Fresh complete-product attempts

Both attempts used the same45a product/input hash and have fresh run witnesses. Both fail and remain independent of the successful screenshot capture:

- Linux run2026-10-09T21:25:06.990230Z, ended21:27:36Z:34 collected checkpoints; the existing Agents navigation helper still seeks a conversation sidebar while the actual desktop Members directory owns the page. The failure is No element at revealSidebar456/section600/fleetFlow1917. Peak RisingWave cgroup charge1,729,449,984 bytes; no observed OOM.
- Android run2026-10-09T21:28:52.367265Z, ended21:30:17Z:18 collected checkpoints; the existing task-history finder still matches more than one widget at ensureVisible1474. The later failing stage is not included in those18 collected captures. The duplicate-owner/hit-ready diagnosis and collection timing remain outstanding.

These are the same unresolved full-product failures retained from39448e9. This color correction does not establish complete authenticated-flow acceptance on either platform.
