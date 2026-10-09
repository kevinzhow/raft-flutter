# Desktop regression repair

The complete `db50083` → `aa0e44b` comparison retained all ten regressions:
nine Elegant Settings frames and Brutal Activity. The original full-frame
threshold, 105 cases, Source PNGs and official scores stay unchanged.

## Confirmed causes

SettingsPanel.tsx:7913 gives its Panel `bg-layer-canvas-muted`; its content
div separately owns `bg-layer-panel`. The generated Elegant PanelHeader
recipe is transparent on desktop and explicitly has no bottom border.
`RaftSettingsPanelFrame` incorrectly provided the content color to both areas.
Removing the obsolete outer Settings header exposed that omission. The real
Source/old header dominant RGB values are `[248,248,247]` in light and
`[13,13,11]` in dark; the new erroneous values were `[255,255,255]` and
`[36,36,34]`. The shared frame now gives the header its actual inherited
surface and the content its own Material surface. A first ColoredBox attempt
exposed Material ListTile ink assertions; that failed attempt is retained.

MainLayout.tsx:2280 passes `thinDivider={isActivityRoute}` into LeftRail.
LeftRail.tsx:563 overrides Brutal's right border to one pixel on this route.
Flutter omitted that caller override. Actual Source Activity footer buttons
are x11.5/w40, with 18px SVGs at x22.5; the mounted Flutter buttons were x11,
with the same sizes but SVGs at x22. Correctly reserving the border therefore
requires the real route-specific border width. The shared rail exposes this
variant, WorkspaceView supplies it from the actual Activity location, and
the existing interactive SDK rail preview exercises it. No screenshot offset
or incorrect smaller icon is used as a repair.

The Activity loss was **354** matching pixels in a 1,024,000-pixel frame;
the header/body were identical between captures. It was not 442 pixels.
The footer boxes accounted for net -53; the rest of the rail for -301.

Administration light/dark and Applications dark also lost body pixels.
Their old management widgets and product files were unchanged. For all three,
the old raster `[x296:1280,y112:800]` exactly equals the new raster
`[x296:1280,y56:744]`: **676,992 pixels, zero differences** in each.
The obsolete outer header was removed, moving the same incorrect old body up
56px to Source's actual content start. The newly visible bottom 56px has no
old counterpart and is explicitly excluded from this diagnostic comparison.
The original whole-frame scores are neither shifted nor normalized.

Those bodies still differ substantially from Source: Administration needs its
Owners & Admins / System channels / Pending invites / Invite links cards;
Applications needs the real marketplace and tab structure. Language/translation
and Billing bodies are also incomplete. A fixed shared header does not complete
these pages or justify rolling back their correct placement.

## Verification and retained failures

- Exact final Settings test inputs: 8 passed / 10 failed on the old frame;
  18 actual-page three-theme paint tests pass after the repair. They explicitly
  require the correct tab title, including actual Applications and Notifications.
  The first compilation, wrong tab fixture and ColoredBox failures are retained.
- Activity: 2 passed / 1 failed on the old rail, with the real 31 vs31.5px
  discrepancy; all three actual WorkspaceView route transitions now pass.
  The initial incorrect expectation that Chat returns Home is retained separately;
  the corrected test asserts its real remembered channel route.
- 36 related mounted checks and18 SDK regressions pass. Analysis and actual
  Linux screenshot replay are recorded separately; no native-flow or whole-page
  PASS follows from these widget assertions.

Private immutable inputs include `.local/cody-desktop-regressions-aa0e44b.json`,
`.local/cody-settings-body-shift-audit.json`,
`.local/cody-settings-surface-before-exact.log`,
`.local/cody-activity-divider-before.log`,
`.local/cody-desktop-regression-repair-mounted.log`, and
`.local/cody-desktop-regression-repair-sdk.log`. Independent Source DOM and
original-region observations remain in the separate desktop-region report.

## Current full native failures

Product commit6078ce2 / SourceHash
`e070a51abcdc7d8c3d76a9e6657f1106f7430c1e2336b2982cb33de7d4ea3561`
actually ran on Linux and Android. Linux failed after32 checkpoints while
waiting for an obsolete ListTile in the real desktop member directory; Android
failed after18 checkpoints returning through Search's own PanelAction Back.
Both fresh receipts, logs and original failures remain intact.

The native replay now clicks the actual desktop human directory row, opens the
profile's Edit role action and performs the existing role mutation. Mobile
return also admits the actual resource-owned PanelAction. Backend role readback,
timeouts and real pointer readiness remain required. These are harness route
repairs; they do not certify Source's inline role editor pixels or a complete
native run before a fresh replay finishes.

## Actual Linux repair replay

The separate18-case replay used product443c7d6 / SourceHash
`72f6992511f2452f6ca757130772cf9e19b7803b5bc86f4519104eea546202c5`.
All18 real Linux captures finished. All18 frozen Source PNG hashes, the product
commit and SourceHash stayed unchanged. The unchanged official comparator
reports1/18, with17 differences; this partial diagnostic does not replace
105 desktop or402 full-matrix acceptance.

All nine regressed Elegant Settings cases improved4.97–5.05 percentage points
againstAA, and all nine are now above theirdb50083 score. Brutal Activity
improved0.00605 points againstAA, but remains0.02852 points belowdb50083;
its original failure remains. The actual mounted route proves the1px Source
divider and31.5px control center, rather than the old2px/31px combination.
Remaining rail pixels and the incorrect Activity body are not certified.
Whole-frame changes include incidental gains/losses from previously incorrect
positions; correcting the Source border does not guarantee an old score.

Each new frame is independently bound to original Source DOM regions in
`.local/cody-desktop-regression-repair-preflight/region-report-v2`. All18
admissions succeed after copying the exact existing Source metadata; the first
report with18 unmeasured cases from absent metadata is retained. The original
10 causes are audited and the two new shell defects are repaired.

| Original regression | db50083 | aa0e44b | repaired |
|---|---:|---:|---:|
| activity.inbox.brutal | 91.77285% | 91.73828% | 91.74434% |
| settings.language.elegant-light | 86.32686% | 83.48564% | 88.47695% |
| settings.language.elegant-dark | 79.15137% | 76.61113% | 81.58350% |
| settings.notifications.elegant-light | 90.67412% | 90.35664% | 95.39844% |
| settings.billing.elegant-light | 81.14346% | 78.30625% | 83.35029% |
| settings.billing.elegant-dark | 78.14561% | 75.37812% | 80.40273% |
| settings.administration.elegant-light | 83.48389% | 80.14209% | 85.17324% |
| settings.administration.elegant-dark | 74.08828% | 70.45977% | 75.47236% |
| settings.applications.elegant-light | 90.70742% | 87.93496% | 92.98115% |
| settings.applications.elegant-dark | 81.86299% | 78.26289% | 83.29033% |

## Complete current desktop comparison

Product39448e9 captures all105 actual Linux cases against the byte-identical
Source baseline. Official acceptance remains2/105. Mean exact similarity is
82.04139%, compared withAA's81.18503%;19 improve,84 are unchanged and two
regress. Both new regressions contain only a2×20-pixel blinking thread-composer
caret: Brutal x902–903/y698–717 loses30 matches, Elegant light
x904–905/y706–725 loses29. All other pixels in both frames are byte-identical
toAA. This is a capture inconsistency: Source's existing capture hides carets,
as does the99-case Flutter harness, but the native desktop capture does not.
The original official failures are retained; no masking, score normalization,
Source capture change or recalibrated acceptance is applied. This explains
the two tiny losses without claiming a new layout or page regression.

The current105-region report admits every case with the same actual Source
geometry, compares withAA and retains unassigned pixels and overlays. Its
regional diagnostic counts are separate from the402 whole-frame decision.

## Current full native results after integration

Both actual runs bind to39448e9 / the current product SourceHash. Linux
collected34 checkpoints and passed the real directory/profile role mutation,
including backend role readback. It then fails in the older `section("agents")`
helper, which tries to scroll a conversation sidebar that is absent while the
real Members directory is open. Its peak RisingWave charge was1,564,319,744
bytes; OOM remained zero. The original failure and all34 collected frames are
retained; no full-flow PASS is claimed. The desktop directory's create-agent
entry requires a separate actual-pointer check before deciding between a
navigation-helper repair and a missing product action.

Android emulator5580 collected18 fresh checkpoints, then failed while
opening task history: the unscoped `task-properties-history` finder matched
more than one element before `ensureVisible`. Its run never reached the
previous Search Back wait, so the Back helper repair remains unproved on this
device. Eighteen is the collected evidence count, not a claim that every later
device screenshot was retrieved before the integration runner removed the APK.
The original failure remains; the next check must identify the actual painted,
hit-ready history control before changing either the test or the product.

Current engineering verification passes2676 project tests with3 existing
skips,75 host checks and full analysis. These checks are separate from the two
failed native flows and the official138/402 whole-frame result.
