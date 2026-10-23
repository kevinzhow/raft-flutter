# Desktop title bar

Approved design (Kevin, "D simplified"): the native title bar strip keeps its
height but is painted in the nav rail's colours of the current theme, with a
bottom rule. No title text, no search, no buttons of ours.

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
- Channel `app.raft/titlebar`. Dart to native: `status` (`{height, fullscreen}`),
  `setStyle` (`background`, `foreground`, `rule` as 0xAARRGGBB ints, `ruleWidth`,
  `dark`), macOS `startDragging`, `doubleClick`. Native to Dart (macOS): `state`.
  A bundle without the channel answers "not implemented": the app keeps the
  system title bar and draws no strip.

Phones and foldables are untouched: the status-bar mechanism
(`RaftStatusBarHost`) stays as is and the title bar is only active on
macOS, Linux and Windows. It does not reuse `RaftStatusBarSource`, because the
strip colour is the rail's constant, not the header currently under it.

## Per OS

### macOS (done, not run here)
`macos/Runner/MainFlutterWindow.swift`: `RaftTitleBar` sets
`titlebarAppearsTransparent`, `titleVisibility = .hidden` and
`.fullSizeContentView`, so Flutter fills the window and the traffic lights stay
where the system puts them (vertically centred in the 28 pt bar). It reports
`height = contentView.height - contentLayoutRect.height` (zero in fullscreen)
and `fullscreen`, pushed on resize and on will/did enter/exit fullscreen. The
Dart strip is the drag area: pan start calls `performDrag(with:)` with the
current event; a double tap applies the system's `AppleActionOnDoubleClick`
(Maximize/zoom by default, Minimize, None, and macOS 15's Fill, which fills
the screen's usable area and restores on a second double-click; before macOS
15 only the `AppleMiniaturizeOnDoubleClick` bool exists). `setStyle` also sets
`window.backgroundColor` so a resize shows the strip colour. No new file in the
Xcode project and no toolbar (RemoteSurface adds an NSToolbar for a 52 pt row;
the approved design keeps the standard bar height).

### Linux (done, verified under Xvfb)
Screenshots of the three themes switching live: `.local/desktop-title-bar/linux-*.png`
(capture needs `xvfb-run -s "-screen 0 1920x1200x24 +extension GLX +render -noreset"`
and `RAFT_LINUX_HEADER_BAR=1`; without GLX the window never maps).
`linux/runner/my_application.cc`: the GTK `GtkHeaderBar` (used under GNOME, on
Wayland, or when forced) is coloured through a CSS provider (`headerbar.raft-titlebar`,
also `:backdrop`, so inactive, maximised and tiled states keep the colour), an
empty custom title removes the text, `border-bottom` is the rule, and the window
buttons take the rail foreground colour (the provider is screen-wide but every
rule is scoped to `headerbar.raft-titlebar`; a translucent divider is blended over
the strip first, since CSS gets one opaque colour). GTK keeps the bar's height, dragging,
double-click and hides it in fullscreen. The window is named "Raft" for the task
switcher, and after that by the open conversation (see below). Limit: where the window manager draws the title bar itself (KDE,
Xfce, tiling WMs, non-GNOME X11) the app cannot paint it and the strip is not
shown. `RAFT_LINUX_HEADER_BAR=1` forces the header bar (used for Xvfb
captures); `=0` forces the window manager's bar.

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
Linux already draws its rule in GTK and does not receive an additional one.

## What was reused from RemoteSurface

The Mac recipe (`titlebarAppearsTransparent` + `fullSizeContentView`,
`performDrag(with:)` from `NSApp.currentEvent`, a `startDragging` channel
method), the idea that a Linux GtkHeaderBar is coloured through a CSS provider,
and the DWM-attribute approach for Windows. Not taken: `window_manager`
(an added dependency for what a 100-line channel does; not needed since the
channel already covers colours, drag and double-click), `multiview_desktop`,
the NSToolbar 52 pt row, and merging window controls into the app's own row
(the approved design has none).

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
