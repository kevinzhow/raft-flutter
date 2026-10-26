# Desktop title bar

The desktop workspace uses the shared global toolbar in the native titlebar
area (Kevin, #raft-flutter:7050ed6f). The macOS host keeps the real traffic
lights and exposes their measured leading inset and native drag/double-click
actions through `DesktopTitleBarScope`. The shared toolbar owns its controls,
theme and empty drag regions. `DesktopTitleBar(integrated: true,
integratedHeight: 48)` removes the former empty strip; fullscreen releases the
traffic-light inset while retaining the shared toolbar. The shared composition
must explicitly enable this mode while its toolbar is present. Linux uses the
same 48 px row with Flutter caption controls; GTK retains window management,
resize borders and shadows. A capability flag keeps older runners compatible.

On macOS, sign-in, workspace selection and narrow windows keep a 48 pt brand
row, including in fullscreen. The native traffic lights start at x=16, y=17
with the system's 23 pt spacing, matching Raft Desktop 1.21.33. Content begins
at x=80. The host configures this frame before Flutter starts. Auth pages use
`RaftAuthHeaderScope` to omit their second brand header; their native-only
server URL action remains available in the page footer.

The reference desktop app limits windows to 960 pt; Flutter continues to
support narrower layouts with the same window frame. Window double-clicks
continue to follow the user's macOS Zoom/Fill/Minimize/None preference.

| Theme | Strip | Rule |
|---|---|---|
| Brutal | rail yellow (`primary-400`) | 2 px black |
| Elegant light | rail canvas (`layer-canvas-muted`) | 1 px `line-muted` |
| Elegant dark | rail dark canvas | 1 px dark `line-muted` |

All three come from `RaftTitleBarRecipe` (raft_ui), which reads `RaftRailRecipe`,
so the strip can never drift from the rail and follows live theme changes.

## Pieces

- `packages/raft_ui/lib/src/desktop_title_bar.dart` - `RaftTitleBarRecipe`,
  `RaftDesktopTitleStrip` (the empty strip and its drag area) and
  `RaftDesktopTitleBar` (strip above the content; shrinks the `MediaQuery`
  size so rail/sidebar metrics see the real viewport; draws nothing when the
  height is 0 or the window is fullscreen).
- `apps/raft_flutter/lib/platform/desktop_title_bar.dart` -
  `DesktopTitleBarController` (channel `app.raft/titlebar`) and the
  `DesktopTitleBar` wrapper installed in `MaterialApp.builder` (below the
  theme). Mode per platform: macOS `strip`, Linux `native`, Windows
  `nativeWithRule`, others none.
- Channel `app.raft/titlebar`: `status` reads window state and `setIntegrated`
  reports whether a workspace row is present. `setStyle` carries `background`,
  `foreground`, `rule`, `ruleWidth` and `dark`. `setTitle` changes the OS title;
  `startDragging` and `doubleClick` forward empty-region gestures.
- State includes `height`, `fullscreen`, `leadingInset`, and optional
  `customControls`, `maximized`, `active`, `buttonLayout`. Runners push `state`
  when their native window state changes. Without `customControls: true`, Dart
  keeps the runner's original native caption behavior.
- Custom captions use `minimize`, `toggleMaximize`, `close`. After layout, Dart
  sends `setCaptionButtonRects` with `{minimize, maximize, close}` entries of
  `{x, y, width, height}` in Flutter logical coordinates. Hidden controls send
  an empty map. Windows can use these bounds for native caption hit testing;
  Linux uses ordinary GTK/Flutter pointer dispatch.
- `desktop_caption_controls.dart` owns ordering, geometry, semantics and shared
  interaction through `RaftInteractive`. Linux circles and
  `desktop_windows_caption_surface.dart` keep platform paint separate.
  Native caption dimensions are fixed platform geometry; their colors come
  from the active theme. Unknown older channel methods retain native controls.

The macOS runner also accepts `setIntegrated` with `{enabled, height}` and
returns its current state. State adds `integrated` and `leadingInset`; the
latter is the native buttons' actual trailing edge plus their gutter, not a
fixed width. The host temporarily installs a transparent compact toolbar so
the original AppKit buttons fit in the shared row, retaining their native
targets and accessibility. The Mac Dart host keeps native integration enabled on every page. The shared
row replaces the standalone branding while a workspace toolbar is present. Only empty regions forward drag or double-click;
the shared row's buttons must handle their own pointer events.

Phones and foldables are untouched: the status-bar mechanism
(`RaftStatusBarHost`) stays as is and the title bar is only active on
macOS, Linux and Windows. It does not reuse `RaftStatusBarSource`, because the
strip colour is the rail's constant, not the header currently under it.

## Per OS

### macOS
`macos/Runner/MainFlutterWindow.swift`: `RaftTitleBar` sets
`titlebarAppearsTransparent`, `titleVisibility = .hidden` and
`.fullSizeContentView`, so Flutter fills the window and the traffic lights stay
at the same 16/17 inset on every page. The 48 pt shared or standalone row
occupies that area. It reports
`height = contentView.height - contentLayoutRect.height` (zero in fullscreen)
and `fullscreen`, pushed on resize and on will/did enter/exit fullscreen. The
Dart strip is the drag area: pan start calls `performDrag(with:)` with the
current event; a double tap applies the system's `AppleActionOnDoubleClick`
(Maximize/zoom by default, Minimize, None, and macOS 15's Fill, which fills
the screen's usable area and restores on a second double-click; before macOS
15 only the `AppleMiniaturizeOnDoubleClick` bool exists). `setStyle` also sets
`window.backgroundColor` so a resize shows the strip colour. The transparent compact toolbar only sizes the native control container; it
is hidden before entering fullscreen so it cannot obscure Flutter content.

### Shared global actions

Wide native desktop workspaces mount the 48 px shared toolbar for every theme.
The shared row is mounted while a workspace and desktop layout are available.
On Mac, a standalone brand row keeps the same 48 pt frame at other widths
or outside the workspace. Browser
visibility still follows `shell.browserTopBar`; the native navigation entry
points are a host feature rather than a theme choice.

The row reuses the workspace menu, search anchor, working-agent summary and
notification centre. Native Back, Forward and History use the workspace's
existing observed history, without appending entries. History actions validate
the original account/server authority and destination before dispatch; channel
and thread destinations restore their existing message projections. At widths
below 1000 px, Back and Forward move into the History menu to leave room for
native window controls. The search remains centred on the full window.

On Linux, only empty areas forward moving and the configured
`gtk-titlebar-double-click` action. `DesktopWindowActions` captures the initiating
button, root coordinates and timestamp before Flutter dispatch, then calls
`gtk_window_begin_move_drag`. Before that handoff it delivers the matching
release to the app view: Flutter 3.47 otherwise retains a pressed button when
the window manager consumes its real release. This completes the Flutter
gesture without releasing the physical button used by the window manager.
Fullscreen suppresses maximize/minimize double-click actions.

### Linux

Every desktop environment uses one 48 px application row by default, following
[Raft Desktop 1.21.33](https://github.com/botiverse/desktop/releases/tag/v1.21.33).
`linux/runner/desktop_caption_bar.h` installs an empty zero-height GTK titlebar.
This suppresses the extra caption while retaining GTK's client-side resize
border and shadow. A non-composited desktop can draw its normal solid resize
border around the Flutter viewport; it is separate from the 48 px row.

Wide workspaces put global actions in that row. Login, workspace selection and
narrow windows use a branded row and the same caption targets; `RaftAuthHeaderScope`
omits duplicate page headers. `KeyedSubtree` keeps the Router and accepted
workspace content when moving between these structures. Fullscreen keeps the
shared actions or brand row, hides caption targets, and releases their insets.

Linux controls are 24 px circles centred in 37 by 48 px targets, with a 4 px
outer gutter. They use the current titlebar foreground and theme-derived fills,
including inactive and hover states. `maximized` changes the restore glyph.
The shared row measures its trailing actions before reserving symmetric side
regions; at constrained widths search shrinks while retaining its window centre.
The caption targets do not overlap workspace actions, working agents or notifications.

Configuration is read when the window is created:

| Variable | Behavior |
|---|---|
| `RAFT_LINUX_HEADER_BAR=0` | Restore the ordinary GTK/system caption. |
| `RAFT_LINUX_HEADER_BAR=1` or unset | Use the single application row on every desktop. |
| `RAFT_LINUX_CAPTION_LAYOUT` | `left:right` lists of `minimize`, `maximize`, `close`; default `:minimize,maximize,close`. |

For example, `close,minimize:maximize` places close and minimize on the left.
Unknown and repeated names are ignored; an invalid or empty layout uses the
default so a usable caption remains. This is an application override, not a
change to desktop button-layout preferences.

The runner emits native fullscreen, maximized and active changes. Explicit
caption actions call GTK minimize, maximize/unmaximize and normal close, keeping
the usual window lifecycle. `setStyle.dark` updates this process's
`gtk-application-prefer-dark-theme`, so GTK resize borders and native dialogs
follow application appearance. It does not write system or desktop preferences.
The runner preserves the separate Dart UI thread and existing rendering settings.

### Window title (all three)
The strip shows no text, but the OS window has a name (task switcher, window
list, Mission Control, screen readers). The app sends it through the same
channel: `setTitle` with `{title}` (`platform/window_title.dart`,
`DesktopTitleBarController.setTitle`; repeated identical titles are dropped).
Web's document title is the model: `#channel | Workspace | Raft`,
`#channel - Thread | Workspace | Raft` while a thread is open, `Workspace | Raft`
on any other page and `Raft` outside a workspace. The runners set it with
`gtk_window_set_title`, `NSWindow.title` and `SetWindowTextW`. The macOS and
Windows handlers are not compiled on the Linux machine that wrote them.

### Windows
`windows/runner/flutter_window.cpp`: `DwmSetWindowAttribute` with
`DWMWA_CAPTION_COLOR` (35) and `DWMWA_TEXT_COLOR` (36, set to the caption colour
so the bar shows no text) plus `DWMWA_USE_IMMERSIVE_DARK_MODE` (20) for the
caption button glyphs. These need Windows 11 (build 22000+); on Windows 10 they
are rejected and the system caption stays. DWM has no caption bottom rule
(only a whole-window border colour), so Flutter draws the rule at the top of
the client area. It reuses `RaftDesktopTitleBar` with the strip height equal to
`RaftTitleBarRecipe.ruleWidth`: 2 logical pixels in Brutal and 1 in Elegant.
The same recipe supplies the colour and blends the translucent dark divider
over the rail background. Content and its `MediaQuery` start below the rule;
live theme changes update it. This rule has no drag or double-click handlers:
the caption's height, buttons, dragging, double-click and resizing stay native.
The Dart side also supports a runner opting into custom caption controls; that
runner must first extend the client frame and implement the native actions and
hit rectangles. Until then this existing DWM caption remains in use. Linux
paints its rule with its shared or standalone Flutter row.

## What was reused from RemoteSurface

The Mac recipe (`titlebarAppearsTransparent` + `fullSizeContentView`,
`performDrag(with:)` from `NSApp.currentEvent`, a `startDragging` channel
method), the idea that a Linux GtkHeaderBar is coloured through a CSS provider,
and the DWM-attribute approach for Windows. Not taken: `window_manager`
(an added dependency for what a 100-line channel does; not needed since the
channel already covers colours, drag and double-click), `multiview_desktop`,
the NSToolbar 52 pt row. The current single-row design shares the Flutter
caption structure while keeping each platform's window management native.

## Mac verification checklist (CodexMac)

Build and run `apps/raft_flutter` on macOS (`tool/flutter run -d macos`), then:

1. Strip: the top bar is the rail colour with no title text. Brutal: yellow with
   a 2 px black rule at its bottom; Elegant light: rail canvas with a 1 px
   divider; Elegant dark: dark rail canvas with a 1 px dark divider. Compare
   with `/tmp/titlebar-D-themes.png` (mockup) if available.
2. Traffic lights: top-left, vertically centred in the strip, all three work
   (close, minimise, zoom/fullscreen). Content (rail, sidebar, conversation)
   starts exactly below the rule; nothing is hidden under the bar. The rail's
   first item is not shifted compared with a build without this change by more
   than the bar height.
3. Live theme: Settings > Appearance, switch Brutal / Elegant / light / dark /
   system; the strip colour and rule change with the rail immediately, no flash.
4. Drag: press and drag on the empty strip moves the window (also from a
   cold window with the app inactive). Drag on the rail or content does not.
5. Double-click on the strip: zooms by default. Change System Settings >
   Desktop & Dock > "Double-click a window's title bar to" to Fill, Minimize and
   None and confirm each is followed (Fill: a second double-click restores).
6. Fullscreen (green button or Ctrl-Cmd-F): no empty coloured strip; the content
   fills the screen; moving the pointer to the top shows the system bar over the
   content. Leaving fullscreen restores the strip with no gap or double strip.
7. Window states: zoomed/resized (strip resizes with the window), inactive window
   (strip colour unchanged, traffic lights grey), minimise and restore.
8. Report the logged `height` value (add a temporary `debugPrint` in
   `DesktopTitleBarController._receive` if needed): 28 expected on macOS 14/15;
   anything else is fine as long as the traffic lights stay centred.
