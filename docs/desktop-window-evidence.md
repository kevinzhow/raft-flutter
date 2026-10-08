# Desktop workspace window behavior

The pinned Web source distinguishes active browser fallback from an optional native-host extension. `serverSwitcherNavigation.ts` handles workspace middle-click: a negotiated `window.openServer` host opens or focuses a server window; other hosts open a public workspace route in another browser tab. `desktopServerWindow.ts` requires both an advertised extension and a completed handshake. `desktop-contract/src/ipc.ts` explicitly calls `window.openServer` optional, while `capabilities.ts` reserves future session-handle IPC.

The source intentionally removed thread/task “open in new tab” entrypoints on 2026-09-10. `openPanelInNewTab.ts` retains builders for a standalone route and tests, but says no UI imports the module. Those removed actions are not reintroduced by this client.

On Linux, Flutter's workspace switcher provides “Open workspace in browser” and the corresponding middle-click action only when `RAFT_FRONTEND_ORIGIN` explicitly identifies the Web frontend and `RAFT_ORIGIN` matches the connected API origin. HTTP frontend origins are limited to localhost; remote frontends require HTTPS. Frontend origins must have no credentials, route, query or fragment. An absent or invalid binding hides the action. API origins are not guessed to serve the Web client: the local test API and Web frontend use different ports.

Opening reads fresh `/servers` membership, uses the returned workspace slug and constructs the public `/s/:slug` route. It never forwards native access or refresh tokens. A changed principal, generation, active workspace or role cancels a pending open. Browser authentication and the resulting browser tab belong to the browser. The operation does not switch the native workspace.

Three tests cover the explicit origin binding and rejected configurations, fresh slug selection without a session URL, and a late membership response after a role change. These tests record the opener callback; actual OS browser launch for this optional configured action is not yet part of the whole native suite.

The current Linux runner uses one Flutter engine and a single-instance command-line forwarding path. Independent authenticated native workspace windows, duplicate-window focusing, and a cross-engine session broker are not implemented or verified. The public snapshot supplies contracts and frontend negotiation, rather than a native broker implementation. The browser fallback therefore does not establish independent native-window parity.

中文说明：只有配置了与当前 API 对应的真实 Web 地址，Linux 工作空间菜单才显示浏览器入口。它使用公开的工作空间页面地址，不传递应用登录凭据。浏览器需要使用自己的登录状态；独立的原生多窗口与跨窗口会话协调仍是明确的能力边界。
