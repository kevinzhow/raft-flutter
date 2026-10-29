# Status bar standard

The app draws edge to edge: the system status bar is transparent and the page
paints under it, the way Web draws a header up under the safe-area top. This
document is the one rule for that behaviour on every layout (phone, foldable,
tablet, desktop). The mechanism lives in `packages/raft_ui/lib/src/status_bar.dart`.

## The rule

For each vertical column under the status bar, the band over that column is
the colour of the column's topmost visible surface:

1. its page header, when it has one flush with the top, else
2. the column's background (the page body, the sidebar, the rail, a panel).

Vertical column dividers continue up through the band. The status bar icon
brightness follows the resolved colour (luminance), never the layout. A modal
scrim dims the band like the rest of the window.

A phone is one column. A foldable, tablet or desktop window is two to five:
rail, navigation column (sidebar, settings navigation, Members / Computers
list), content, thread panel, profile panel. Columns are not special cased:
the same widgets publish the same way on every layout.

## Mechanism

- `RaftStatusBarHost` (one per route that owns the top of the window; nested
  hosts collapse into the outermost) paints a strip of the top inset height
  above its child and owns a registry.
- `RaftStatusBarSource(color, border?)` wraps a widget that paints a column
  surface or a header. At paint time the strip draws, in paint order (a parent before its
  descendants, an earlier sibling before a later one; never by render depth,
  so a column an opaque later one covers, like the conversation under a
  folded profile panel, cannot win), every
  visible source flush with the top of the window over its own horizontal
  extent, with its `border` (left and right sides) continuing the divider.
  Sources add no layout or paint of their own.
- A transparent header publishes transparent; the surface it sits on
  (`RaftConversationSurface`, `RaftPanelTextScope`, the page body container,
  `RaftMountedSidebarFrame`, `RaftSettingsPanelFrame`, ...) publishes its colour.
  Nothing publishes per layout: a widget that is a column surface or a header
  wraps itself in a source, whatever the width.
- `RaftStatusBarSource(overlay: true)` is a modal scrim (`RaftModalBackdrop`):
  composited last, over every column.
- A modal that is its own route (a lightbox, a preview) sits above the page's
  host, so it hosts its own transparent strip: `RaftFullBleedDialogRoute`. An
  inline overlay above the workspace (the wide task modal) wraps itself in a
  transparent `RaftStatusBarHost` the same way.
- Hosts only paint on Android and iOS with a top inset. Desktop and Web have
  no inset, so nothing is painted.

## Adding a page or panel

- A new page header that paints its own background: wrap it in
  `RaftStatusBarSource(color: <its fill>)`.
- A new page or panel body that sits under a transparent header: wrap the
  body surface in `RaftStatusBarSource(color: <its fill>, border: <left edge>)`.
- Do not paint the status bar from a page, and do not branch on layout.

## Audit

`apps/raft_flutter/test/statusbar_standard_test.dart` renders every route of
the statusbar audit page list plus every `NavigationRegistry` section and
settings page, at 390x844, 816x900 and 1280x800 in brutal, elegant-light and
elegant-dark (simulated 40dp inset). For each column it samples the band at the
column centre and on its divider and asserts it equals the pixel just below the
inset. `RAFT_STATUSBAR_STANDARD_DIR=<dir>` writes the top 120dp of each render
(`<dir>/<size>/<theme>/<page>.png`) for contact sheets (`tool/statusbar-sheet.py`).
`statusbar_audit_test.dart` keeps the phone page-by-page checks (icon contrast,
headerless pages) and the breakpoint resize checks.

## Header heights

Web `h-panel-header` is `--shell-header-height`: 56 px Elegant, 62 px Brutal,
48 px when the viewport is 600 px tall or less (measured in the React parity
captures at 1280x800: sidebar header border rows 55 / 60). The width does not
matter, so a foldable at ~816 dp is the same. The Flutter shell header
(`RaftLayoutMetrics.shellHeaderHeight`), the content column header, the sidebar
header and the member detail header measure 56 / 62 / 48 at 816 and 1280 dp:
none is taller than Web.
