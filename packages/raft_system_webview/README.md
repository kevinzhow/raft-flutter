# System HTML view

This Linux plugin embeds the operating system's GTK3 WebKitGTK 4.1 widget in
Flutter's GTK window. It does not ship WebKit, JavaScriptCore, browser helpers,
or a browser SDK. Build with `webkit2gtk-4.1 >= 2.40` development headers;
deployment requires the matching distribution runtime and its normal sandbox.

The reviewed embedding basis is `webview_all_linux` 1.4.12 at the full commit
and file hashes in `upstream.json`. `native_host.cc` adapts its pre-realization
overlay and Flutter input-window routing. The copyright and permission notice
are preserved in `LICENSE.upstream`. The broad upstream scripting/download
interface is deliberately not imported into this attachment-only adapter.

## Host protocol 1

`app.raft/system_webview.create` returns a per-preview identifier and positive
protocol, ephemeral-session and sandbox attestations. Failure to isolate
refuses creation. `app.raft/system_webview/<id>` accepts:

- `load({url})`: one host-authorized HTTP(S) document. Its actual response must
  have the attachment's opaque-origin sandbox CSP before execution is allowed.
- `layout({sequence, frame, clip, visible})`: monotonic GTK logical-pixel
  geometry; native painting and input share the clipped rectangle.
- `evaluate({source})` and `currentUri`: host-initiated, bounded result requests.
  There is no object or script-message handler callable by uploaded HTML.
- `inspect`: host readback of live GTK visibility/focus and ephemeral/sandbox state.
- `snapshot`: one bounded host-only visible-region PNG request; layout changes,
  closure and cancellation reject stale results. Maximum 16 Mi pixels, 8192
  pixels per side and 8 MiB PNG; caller owns its private decoded image.
- `dispose`: cancels evaluation/loading/snapshots, disconnects signals, destroys the GTK
  view and releases the ephemeral context. Dart retires event handling first.

Native `event` messages report loading progress, document completion, a
sanitized failure, host-only `focus({focused})` changes and real-input `snapshotDirty` notifications. URLs and browser errors are not printed to application logs.

The view supports rectangular clips and translation-only geometry. Unsupported
geometry hides native pixels and input. A view-local occlusion callback comes
from the SDK's canonical tooltip and popup placement; it never adds page offsets.
A caller supplies a private snapshot as the static background while the native
surface yields to Flutter overlays, and restores the same live controller after
those overlays close. Capture/region drawing uses its own native overlay adapter.

A real press in Flutter's input subtree returns GTK focus to its FlView before
Flutter handles the press. A native sibling keeps normal WebKit focus handling;
its ordered focus event lets the Flutter host clear its previous text focus in
the current view and visible scope. This boundary neither creates pointer events
nor changes key handling.

## Native link authority

The first document is one exact nonredirected host GET. Later navigation is
cancelled unless the system engine reports a real link-click gesture and the
small application WebExtension reports the matching trusted main-frame DOM click
for an empty or `_self` resolved target. Resolved targets include `base[target]`;
named frames, `_parent`, `_top` and unknown targets are denied without a proof.
The extension uses a private ScriptWorld, deletes its temporary private global
after installing its closure, and exports no main-world object, app callback or
UserContentManager message handler. Script, iframe, redirect, POST, replay,
unknown, expired and mismatched actions are refused. A single native decision
may wait at most 500 ms for its matching proof; a proof is usable once within
750 ms. The sandbox deliberately denies popups, so a `_blank` link may produce
no navigation action. Its private-world trusted main-frame click prevents the
default and hands off that exact link once to the app's existing URL policy,
without opening a popup or inventing a navigation action. Every proof includes
the resolved target and a monotonically increasing trusted-click sequence.
An external link is cancelled in the renderer before handoff; the report remains
open. Same-document fragments
may stay inside the renderer. The module lives at
`lib/raft-webview/libraft_system_webview_extension.so`, dynamically linked only
to system libraries and located relative to the loaded application plugin.

An AppImage must use a coherent system GTK/GLib/WebKit/media dependency set.
Loading this system widget alongside a separately bundled GTK/GLib closure is
unsupported; changing a library path after those libraries load cannot repair
that ABI mixture. Runtime acceptance must cover the actual package, X11 and
Wayland, scaling, focus/input, canonical overlays, region comments and close.
