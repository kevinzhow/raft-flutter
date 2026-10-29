# System and manual HTTP proxy

One mechanism for every network path: ask `SystemProxy` (packages/raft_client/lib/src/proxy/system_proxy.dart)
which proxy a URL should use. Scope: **HTTP proxies only** (CONNECT for https/wss), optional Basic
credentials for a manual proxy. SOCKS entries are ignored (treated as DIRECT) and reported so Settings
can say "SOCKS 不支持，已直连".

## Decision order

1. Settings > Resources > Network (native only):
   * **No proxy** -> `DIRECT`.
   * **Manual** -> `PROXY [user:pass@]host:port` for every host except the no-proxy list (host, `.suffix`,
     `*.glob`, CIDR, `host:port`, `<local>`).
   * **Use system proxy** (default) -> next step.
2. `http_proxy` / `https_proxy` / `no_proxy` (either case) when set, parsed by `HttpClient.findProxyFromEnvironment`.
3. The OS configuration (table below).
4. Loopback (`localhost`, `127/8`, `::1`) is never proxied in any mode.

`findProxy` is synchronous. The OS is queried asynchronously into a cache:

* `SystemProxySnapshot`: the URL-independent configuration (static per-scheme proxies, bypass list, PAC
  URL / auto-detect flag). Reloaded at start-up, on app resume, on a platform change signal (Android
  `PROXY_CHANGE`) and, lazily, when a request finds it older than 60 s. No timers.
* PAC / auto-detect: per `scheme://host:port` answers in a cache, filled by the platform resolver in the
  background (only the origin is passed to the OS/PAC script, never the path or query of a signed URL).
  A cold miss answers from the static part of the configuration (or DIRECT) and fills the cache; stale
  entries are served once more and refreshed. `ready(uri)` makes the **first** request to a host wait at most
  750 ms for the PAC answer (Dio interceptor / WebSocket connector); static configurations never wait.
* A failing or slow native query keeps the last good snapshot; nothing throws into a request.

## Wiring

| Path | Hook |
| --- | --- |
| API (`RaftClient.http`, Dio) | `createProxiedDio` -> `IOHttpClientAdapter(createHttpClient: SystemProxy.createHttpClient)` + `ProxyReadyInterceptor` |
| Realtime (socket_io_client 3.1.6, websocket transport) | `OptionBuilder.setWebSocketConnector(proxiedWebSocketConnector)` (`applyProxyTransport`) -> `dart:io WebSocket.connect(customClient:)`; no fork needed |
| Attachments (`AttachmentHttp`) | `createProxiedDio(..., configure:)` |
| Report-issue upload | `createProxiedDio` |
| Avatars (CachedNetworkImage -> `http` -> `HttpClient()`), `NetworkImage`, any package | `HttpOverrides.global = ProxyHttpOverrides` installed by `startSystemProxy` |
| Background worker isolate | `startSystemProxy` in `runBackgroundInbox`; the native bridge is not registered in worker engines, so saved manual/direct + environment apply there, not the OS proxy |
| Video/audio streaming (Android/iOS/macOS: `video_player`; Windows/Linux: media_kit/mpv) | The player opens the attachment's signed URL itself ([media playback](media-playback.md)). **Windows/Linux (mpv)**: `http-proxy` is set as a runtime property from `SystemProxy.findProxyForClient(url)` (`NativeAttachmentPlayer.httpProxyFor`; credentials of a manual proxy included, never in argv or logs); for DIRECT, `stream-lavf-o=http_proxy=` is set too, because mpv drops an empty `http-proxy` and FFmpeg would otherwise use the `http_proxy` environment variable (for https as well), and the protocol whitelist is the fixed `file, http, https, tcp, tls, crypto`; `proxy_hook_guard_test` pins both. **Android/iOS/macOS**: ExoPlayer (`HttpURLConnection`) and AVPlayer follow the **OS** proxy only. Settings > Network *Manual* and *No proxy* are not applied to streamed media there; this is a known limitation of `video_player` (it takes no proxy option) until a plugin extension exists. The explicit Download action still goes through the proxy-aware Dio. A player that cannot reach or authenticate to its proxy reports "Cannot reach the proxy host:port" / "The proxy host:port needs a username and password" with a Network settings action (host:port only; [failure classes](media-playback.md#failure-classes-and-messages)) |
| iOS share extension (URLSession), url_launcher, WebView | follow the system already |

The `avoid_unproxied_network_client` lint (`tool/raft_lints`, run by `tool/raft-lints`) fails on a new `HttpClient()`,
`Dio()`, `IOHttpClientAdapter()`, `WebSocket.connect()`, `io.io()`, `HttpClient.findProxyFromEnvironment` or `http.Client()` in any `lib/`
without a `// ignore: raft_lints/avoid_unproxied_network_client -- <reason>` at the site.

## Per-platform OS query

| Platform | Mechanism | Where |
| --- | --- | --- |
| macOS, iOS | `CFNetworkCopySystemProxySettings` (static + PAC URL + exceptions), `CFNetworkCopyProxiesForURL` per URL, PAC via `CFNetworkExecuteProxyAutoConfigurationURL` (5 s timeout). WPAD auto-discovery is reported but not executed. | `macos/Runner/MainFlutterWindow.swift`, `ios/Runner/RaftSharingBridge.swift` (`RaftSystemProxy`, channel `app.raft/system-proxy`) |
| Windows | `WinHttpGetIEProxyConfigForCurrentUser` (static, bypass, auto-detect, PAC URL) and `WinHttpGetProxyForUrl` (WPAD/PAC) through `dart:ffi`, each in a short-lived isolate | `windows_proxy.dart` |
| Android | JVM `http(s).proxyHost/proxyPort/nonProxyHosts` (kept in step with Settings / managed proxy / PAC by the framework), `ProxySelector.getDefault().select(uri)`; `PROXY_CHANGE` broadcast tells Dart to re-read | `NativeProxyBridge.kt` |
| Linux | GNOME `gsettings list-recursively org.gnome.system.proxy` (none/manual/auto), then KDE `~/.config/kioslaverc` `[Proxy Settings]` (ProxyType 0-4, httpProxy/httpsProxy/socksProxy, NoProxyFor, Proxy Config Script); PAC/WPAD through libproxy (`libproxy.so.1`, `dlopen`, optional) | `linux_proxy.dart` |

## Manual proxy credentials

* Password lives in secure storage (`raft.proxy.password`, Android `resetOnError: false`), everything else in
  SharedPreferences. The page never reads the password back into a field; a blank field keeps it.
* dart:io only sends **preemptive** Basic credentials, and for HTTPS tunnels only via `PROXY user:pass@host:port`
  in the `findProxy` string (a 407 on CONNECT is not retried). The SDK splits that string on `;`, on the first `:`
  and on the last `@`, and trims it. Hence: a username cannot contain `:`, username/password cannot contain `;`
  or start/end with whitespace. The form refuses these with a message. `:`, `@` and `/` inside a password are fine.
* The password is never logged: `ProxySettings.toString`, `ProxyStatus` and exceptions carry none (test:
  `system_proxy_integration_test.dart`). It is sent only as `Proxy-Authorization` to the proxy. OS/system
  and environment proxies carry no app-managed credentials.

## Tests

* `packages/raft_client/test/proxy_parsing_test.dart`: PAC result parsing, bypass matching, snapshot rules, WinHTTP
  strings, GNOME/KDE parsing, SOCKS ignored, settings limits, real gsettings/libproxy smoke on Linux.
* `packages/raft_client/test/system_proxy_integration_test.dart`: local HTTP/CONNECT proxy (`test/support/test_proxy.dart`)
  with Basic auth: API Dio, HTTPS tunnel, Socket.IO websocket handshake, system snapshot, environment override,
  direct/loopback, bypass list, 407 on wrong/missing password, cache + fallback + bounded `ready`, no password in logs.
* `apps/raft_flutter/test/network_settings_test.dart`: persistence (prefs vs secure storage), validation, status text
  (en/zh, SOCKS-only), test-connection.
* `tool/raft_lints` (`avoid_unproxied_network_client`) and `apps/raft_flutter/test/proxy_hook_guard_test.dart` (hook wiring): the guard above.
* On device: `integration_test/proxy_probe_main.dart` + `packages/raft_client/test/device_proxy_host_test.dart`.

## Not verified here (checklists)

macOS/iOS (CodexMac): `xcodebuild` the Runner (the Swift is parse-checked only); set a manual HTTP proxy in System
Settings > Network > Proxies (and a PAC URL, and SOCKS-only) and open Settings > Network; confirm the status text,
that API/attachment/realtime requests reach the proxy (Charles/mitmproxy), and that PAC resolution returns within 5 s.

Windows (Kevin): `flutter build windows`; set Settings > Network & Internet > Proxy (manual, script address,
automatically detect); the status line must follow within a minute or after refocusing the app; check a corporate PAC.
The FFI structs follow winhttp.h (`WINHTTP_CURRENT_USER_IE_PROXY_CONFIG`, `WINHTTP_AUTOPROXY_OPTIONS`, `WINHTTP_PROXY_INFO`).
