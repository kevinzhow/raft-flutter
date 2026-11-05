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
- `dispose`: cancels evaluation/loading, disconnects signals, destroys the GTK
  view and releases the ephemeral context. Dart retires event handling first.

Native `event` messages report loading progress, document completion and a
sanitized failure. URLs and browser errors are not printed to application logs.

The first prototype supports rectangular clips and translation-only geometry.
Unsupported geometry hides the native widget. It also hides when Flutter
retires the route, widget or foreground state. A caller must keep `visible`
false while loading or displaying an error and while a canonical Flutter
overlay covers the pane: GTK airspace is not automatically occluded by Flutter
OverlayEntries. Do not remove that fence merely because a route test passes.

## Delivery boundary

The initial prototype cancels every navigation except the first exact,
nonredirected GET initiated by the host. WebKitGTK 2.52's navigation action has
no target-frame accessor, so it must not report invented `isMainFrame` data.
External links and native region capture/flash are follow-up adapter work, not
claims established by these protocol and geometry tests. The planned native
WebExtension uses a private script world and verified native main-frame/trusted
input information, with no exported page API and one bounded navigation
decision; unknown, replayed, expired and scripted actions remain denied.

An AppImage must use a coherent system GTK/GLib/WebKit/media dependency set.
Loading this system widget alongside a separately bundled GTK/GLib closure is
unsupported; changing a library path after those libraries load cannot repair
that ABI mixture. Runtime acceptance must cover the actual package, X11 and
Wayland, scaling, focus/input, canonical overlays, region comments and close.
