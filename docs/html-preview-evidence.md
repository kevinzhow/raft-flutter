# Native HTML attachment preview

## Update 2026-10-12: WebView on Android, iOS and macOS

A real 3.2 MB report (inline base64 JPEGs, a script, external https images) failed with "The HTML preview could not be loaded" on every platform: the viewer downloaded the whole document into Dart, refused it above 2 MiB, and otherwise could only render the static, script-less text. Web has no such cap; it loads the server's isolated `/html-preview` URL straight into a sandboxed iframe.

Android, iOS and macOS now do the same with `webview_flutter` (Android WebView, WKWebView). `HtmlAttachmentPreviewDialog` obtains the capability URL (`GET /attachments/:id/html-preview-url`), validates it with `attachmentHtmlPreviewUri`, verifies the pinned CSP on a fresh request (`AttachmentHtmlLoader.verify`, the WebView cannot read headers), then `loadRequest(url)`. No `loadHtmlString`, no `data:` URL, no size cap. The WebView carries no cookies or tokens for the Raft origin (the capability is the `previewToken` query, the same as Web), exposes no JavaScript channel, disables file/content access on Android, and navigates only to its own URL: `attachmentHtmlNavigation` allows that URL, routes policy-approved https links to the system browser and blocks everything else. The document keeps the server's `sandbox allow-scripts` CSP (opaque origin, no `connect-src`).

Web's sandboxed iframe has an opaque origin: no cookie, storage or cache carry-over, and it dies with the dialog. The native WebViews are not opaque by default, so `attachment_html_webview_data.dart` locks them down: before the first request of a preview and again after it closes, cookies, local storage and caches are cleared. Android additionally switches cookies off for the process (`app.raft/html-preview-privacy` channel: `CookieManager.setAcceptCookie(false)`, cookie jar and `WebStorage` cleared; the app has no other WebView), disables third-party cookies and DOM storage for the instance and clears the cache. iOS/macOS: webview_flutter_wkwebview always uses WKWebView's default (persistent) data store and exposes no non-persistent one, so the default store (used by nothing else in the app) is cleared with `WebKitWebViewCookieManager.clearCookies`, `clearLocalStorage` and `clearCache` before load and after close. Closing loads `about:blank` (the navigation delegate lets exactly that one through after close, since WKWebView consults the delegate for programmatic loads) so scripts, timers and media stop, then purges.

Also fixed: `AttachmentHtmlLoader.dispose` force-closed the app-wide shared attachment `Dio`, so after one HTML preview was closed every later preview (and other attachment fetches on that client) failed with a connection error.

Linux and Windows have no first-party WebView implementation, so they keep the static preview with the cap raised to 16 MiB (`raftStaticHtmlMaxChars`; parsed in a background isolate above 256 KiB) and the explicit "Open interactive preview in browser" action. Every failure now names its reason (too large, not isolated, no access, gone, connection, WebView) and offers Retry (when it can help), Open in browser (when the server's isolation is intact) and Download.

Repro and evidence tool: `integration_test/html_preview_probe_main.dart` against a fake server serving the real endpoints and headers.


The source is `raft-source` 26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6. Web `attachmentPreviewSurfaces.tsx` and `SandboxedPreviewFrame.tsx` use a sandboxed iframe with `allow-scripts` and no same-origin privilege. The mounted attachment HTML endpoint supplies the sandbox policy even when its URL is opened directly.

The Flutter attachment viewer shows a static, selectable, themed document. It preserves headings, emphasis, links and tables. It removes scripts, inline styles, executable elements, event handlers and resource-loading attributes. Images appear as text placeholders, including their supplied alternate text; the native renderer does not fetch uploaded HTML image references. Static processing (Linux/Windows) is bounded to 16 MiB and 4,000 elements. Oversized or unsupported documents retain the download and explicit browser actions.

“Open interactive preview in browser” is a separate, explicit action. It obtains a fresh attachment capability through authenticated `GET /attachments/:id/html-preview-url`, accepts only the same-origin `/api/attachments/:id/html-preview` route and expected query fields, verifies the response CSP, and opens that server endpoint. It never opens the ordinary signed-download URL as HTML. Redirects are disabled. The required sandbox contains only `allow-scripts`, together with `default-src`, `connect-src`, `object-src`, `base-uri`, `form-action` and `worker-src` set to `'none'`.

Links from native static HTML pass the source parent-link policy: absolute HTTPS, no credentials, token parameters, IP literals, private-network names or Raft application/API hosts. Rejected links remain unavailable. No embedded scripts are executed by Flutter or by verification tools.

Pending transfers and modal content are canceled or cleared when message visibility or the active authority is lost. Temporary response bytes are zeroed after parsing. HTML capabilities and document content are not persisted. Once the user opens the external browser, its document lifetime belongs to that browser; closing or revoking the Flutter viewer cannot erase content already loaded there.

中文说明：应用内显示静态 HTML，保留标题、文字、链接和表格，图片以文字占位。脚本和图片可通过用户明确选择的浏览器交互预览查看，该预览使用服务端受限沙箱。应用内撤权会关闭预览并取消加载；已打开的外部浏览器页面由浏览器管理。

## Verification

- Five pure widget tests cover hostile element/resource removal, size/complexity bounds and actual callbacks at phone width across Brutal light, Elegant light and Elegant dark.
- Five app tests cover attachment URL/CSP restrictions, source external-link policy, bounded loading and byte clearing, late revocation, and fresh validation before an explicit interactive action. The external opener is replaced with a recorded callback in these tests; they do not claim OS browser launch proof.
- Actual SDK Widget Preview browser interactions cover all three themes. They activate the accessible parent-owned link and interactive-preview callbacks, verify script exclusion and image placeholders, and capture the rendered document. The same report proves spreadsheet sheet changes, accessible cell content, play/pause controls and actual keyboard changes to seek and volume for the new document/media components. This is control behavior, not native media decoding proof.
- Report: agent workspace `reports/raft-reference/html/preview-interactions.json`, six assertion-bound screenshots and a clean console log. The SDK transparent semantics layer intercepts ordinary pointer events, so activation uses rendered DOM semantics and browser keyboard.
- Linux native run `2026-10-08T00:34:39.455454Z` passed the real owned HTML upload/send/viewer assertions at `00:37:14Z`; its screenshot was visually checked for the heading, Chinese/Japanese text, table, image placeholder and explicit browser action. The same run later failed audio readiness, so its whole-run completion remains false. Android remains pending. The external browser action was present; actual OS browser launch is not established by this checkpoint.

The HTML rendering dependency is the platform-neutral [flutter_widget_from_html_core](https://pub.dev/packages/flutter_widget_from_html_core), preceded by the app's stricter sanitizer. Media, PDF and structured previews have separate platform evidence in the attachment report.
