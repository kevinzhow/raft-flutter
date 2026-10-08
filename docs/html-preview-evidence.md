# Native HTML attachment preview

The source is `raft-source` 26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6. Web `attachmentPreviewSurfaces.tsx` and `SandboxedPreviewFrame.tsx` use a sandboxed iframe with `allow-scripts` and no same-origin privilege. The mounted attachment HTML endpoint supplies the sandbox policy even when its URL is opened directly.

The Flutter attachment viewer shows a static, selectable, themed document. It preserves headings, emphasis, links and tables. It removes scripts, inline styles, executable elements, event handlers and resource-loading attributes. Images appear as text placeholders, including their supplied alternate text; the native renderer does not fetch uploaded HTML image references. Static processing is bounded to 2 MiB and 4,000 elements. Oversized or unsupported documents retain the download and explicit browser actions.

“Open interactive preview in browser” is a separate, explicit action. It obtains a fresh attachment capability through authenticated `GET /attachments/:id/html-preview-url`, accepts only the same-origin `/api/attachments/:id/html-preview` route and expected query fields, verifies the response CSP, and opens that server endpoint. It never opens the ordinary signed-download URL as HTML. Redirects are disabled. The required sandbox contains only `allow-scripts`, together with `default-src`, `connect-src`, `object-src`, `base-uri`, `form-action` and `worker-src` set to `'none'`.

Links from native static HTML pass the source parent-link policy: absolute HTTPS, no credentials, token parameters, IP literals, private-network names or Raft application/API hosts. Rejected links remain unavailable. No embedded scripts are executed by Flutter or by verification tools.

Pending transfers and modal content are canceled or cleared when message visibility or the active authority is lost. Temporary response bytes are zeroed after parsing. HTML capabilities and document content are not persisted. Once the user opens the external browser, its document lifetime belongs to that browser; closing or revoking the Flutter viewer cannot erase content already loaded there.

中文说明：应用内显示静态 HTML，保留标题、文字、链接和表格，图片以文字占位。脚本和图片可通过用户明确选择的浏览器交互预览查看，该预览使用服务端受限沙箱。应用内撤权会关闭预览并取消加载；已打开的外部浏览器页面由浏览器管理。

## Verification

- Five pure widget tests cover hostile element/resource removal, size/complexity bounds and actual callbacks at phone width across Brutal light, Elegant light and Elegant dark.
- Five app tests cover attachment URL/CSP restrictions, source external-link policy, bounded loading and byte clearing, late revocation, and fresh validation before an explicit interactive action. The external opener is replaced with a recorded callback in these tests; they do not claim OS browser launch proof.
- Actual SDK Widget Preview browser interactions cover all three themes. They activate the accessible parent-owned link and interactive-preview callbacks, verify script exclusion and image placeholders, and capture the rendered document. The same report proves spreadsheet sheet changes, accessible cell content, play/pause controls and actual keyboard changes to seek and volume for the new document/media components. This is control behavior, not native media decoding proof.
- Report: agent workspace `reports/raft-reference/html/preview-interactions.json`, six assertion-bound screenshots and a clean console log. The SDK transparent semantics layer intercepts ordinary pointer events, so activation uses rendered DOM semantics and browser keyboard.
- `integration_test/html_preview_flow.dart` uploads an owned HTML fixture, sends it through the real attachment API, opens the native viewer, asserts visible heading/image-placeholder/browser action, captures `linux-html-native-preview`, and closes it. Its whole Linux/Android execution is owned by the serial native suite; this document does not promote helper existence into a platform pass.

The HTML rendering dependency is the platform-neutral [flutter_widget_from_html_core](https://pub.dev/packages/flutter_widget_from_html_core), preceded by the app's stricter sanitizer. Media, PDF and structured previews have separate platform evidence in the attachment report.
