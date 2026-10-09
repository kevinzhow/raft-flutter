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
