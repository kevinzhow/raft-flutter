import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'channel_side_web_preview.dart';

/// What the preview's WebView does with a navigation request.
enum WebPreviewNavigation { stay, browser, refuse }

/// The frame's navigation rules (Web `WEB_PREVIEW_SANDBOX`: scripts, forms and
/// popups allowed, never top navigation, nothing but http(s)):
/// - A main-frame https address stays in the preview. A link inside the page
///   is the page's own business, as in Web's sandboxed frame.
/// - A main-frame http address is mixed content in Web (blocked); here it opens
///   in the system browser instead of showing nothing.
/// - Any other scheme (`intent:`, `mailto:`, a custom protocol, `file:`) is
///   refused: the page can't start another app or read local files.
/// - A frame inside the page (an embed) loads as it asks to.
///
/// The WebView API reports a popup (`target=_blank`, `window.open`) as one more
/// main-frame navigation of the same view, so a popup shows in the preview
/// like any link; it can't be told from a link click and sent to the browser.
WebPreviewNavigation webPreviewNavigation(
  String url, {
  required bool isMainFrame,
}) {
  if (!isMainFrame) return WebPreviewNavigation.stay;
  if (url == 'about:blank') return WebPreviewNavigation.stay;
  return switch (Uri.tryParse(url)?.scheme) {
    'https' => WebPreviewNavigation.stay,
    'http' => WebPreviewNavigation.browser,
    _ => WebPreviewNavigation.refuse,
  };
}

Future<void> _launchInBrowser(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// The page beside the conversation (Web `WebPreviewPanel`): the host as the
/// title with the rest of the address muted, then its actions (Open in
/// browser, Phone width / Desktop width, Refresh, Close), the page, and one
/// quiet line at the foot: a site that refuses to be shown blanks, which the
/// app can't detect, so the way out is always on screen. An http:// page is
/// never shown: an empty state says so and opens the browser.
///
/// The WebView runs the page's JavaScript (almost every site needs it) but has
/// no JavaScript channel and no way to reach Raft: the page learns nothing
/// about the app and can't call it.
///
/// [covering]: on a phone the page covers the conversation as a page of its
/// own; Back closes it and there is no width to pick (Web `covering`).
class WebPreviewPanel extends StatelessWidget {
  const WebPreviewPanel({
    super.key,
    required this.store,
    required this.page,
    this.covering = false,
    this.openExternal = _launchInBrowser,
  });

  final WebPreviewStore store;
  final WebPreviewPage page;
  final bool covering;

  /// Opens an address in the system browser.
  final FutureOr<void> Function(String url) openExternal;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, store.platform.voiceOverState]),
    builder: (context, _) {
      final t = RaftTokens.of(context);
      final parts = webPreviewAddressParts(page.url);
      final framed = canFrameWebPreview(page.url);
      final showsHere = framed && store.platform.frames;
      void open() => unawaited(Future.sync(() => openExternal(page.url)));
      final toWidth = store.width == WebPreviewWidth.desktop
          ? WebPreviewWidth.phone
          : WebPreviewWidth.desktop;
      final widthLabel = raftText(
        context,
        toWidth == WebPreviewWidth.phone ? 'Phone width' : 'Desktop width',
      );
      final openLabel = raftText(context, 'Open in browser');
      final refreshLabel = raftText(context, 'Refresh');
      final closeLabel = raftText(context, 'Close');
      Widget panel = Semantics(
        container: true,
        // Web `aria-label` of the panel: its head and page stay their own
        // nodes under it.
        explicitChildNodes: true,
        label: raftFormat(context, 'Web preview: {host}', {'host': parts.host}),
        child: ColoredBox(
          key: const ValueKey('web-preview'),
          color: t.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftPanelHeaderBar(
                key: const ValueKey('web-preview-header'),
                title: parts.host,
                subtitle: parts.rest.isEmpty ? null : parts.rest,
                onBack: covering ? store.close : null,
                backKey: const ValueKey('web-preview-back'),
                backTooltip: closeLabel,
                actions: [
                  RaftPanelAction(
                    key: const ValueKey('web-preview-open-tab'),
                    glyph: RaftGlyph.arrowUpRight,
                    tooltip: openLabel,
                    onPressed: open,
                    minHitExtent: RaftMetrics.touchTarget,
                  ),
                  if (showsHere && !covering)
                    RaftPanelAction(
                      key: const ValueKey('web-preview-width'),
                      glyph: toWidth == WebPreviewWidth.phone
                          ? RaftGlyph.smartphone
                          : RaftGlyph.monitor,
                      tooltip: widthLabel,
                      onPressed: () => store.setWidth(toWidth),
                      minHitExtent: RaftMetrics.touchTarget,
                    ),
                  if (showsHere)
                    RaftPanelAction(
                      key: const ValueKey('web-preview-refresh'),
                      glyph: RaftGlyph.refreshCw,
                      tooltip: refreshLabel,
                      onPressed: store.reload,
                      minHitExtent: RaftMetrics.touchTarget,
                    ),
                  if (!covering)
                    RaftPanelAction(
                      key: const ValueKey('web-preview-close'),
                      glyph: RaftGlyph.x,
                      tooltip: closeLabel,
                      onPressed: store.close,
                      minHitExtent: RaftMetrics.touchTarget,
                    ),
                ],
              ),
              Expanded(
                child: showsHere
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _SiteFrame(
                              key: ValueKey('${page.url}#${store.reloads}'),
                              url: page.url,
                              phoneWidth:
                                  !covering &&
                                  store.width == WebPreviewWidth.phone,
                              openExternal: openExternal,
                            ),
                          ),
                          _NotShowingLine(onOpen: open),
                        ],
                      )
                    : Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(RaftSpace.x6),
                          child: framed
                              // https, but this device can't show it now
                              // (macOS with VoiceOver on).
                              ? RaftEmptyState(
                                  key: const ValueKey('web-preview-browser'),
                                  glyph: RaftGlyph.arrowUpRight,
                                  title: parts.host,
                                  detail: '',
                                  action: _OpenButton(
                                    keyName: 'web-preview-browser-open',
                                    label: openLabel,
                                    onPressed: open,
                                  ),
                                )
                              : RaftEmptyState(
                                  key: const ValueKey('web-preview-insecure'),
                                  glyph: RaftGlyph.shieldAlert,
                                  titleHeading: true,
                                  title: raftText(
                                    context,
                                    'This page can’t be shown here',
                                  ),
                                  detail: raftText(
                                    context,
                                    'It uses http://, which isn’t secure, so it can’t be shown inside Raft.',
                                  ),
                                  action: _OpenButton(
                                    keyName: 'web-preview-insecure-open',
                                    label: openLabel,
                                    onPressed: open,
                                  ),
                                ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
      // Esc closes it from inside the panel (Web `handleKeyDown`); focus moves
      // in when a page opens, as Web's `panelRef.focus()`.
      panel = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): store.close,
        },
        child: Focus(autofocus: true, child: panel),
      );
      // On a phone the system Back closes the page covering the chat (Web
      // `usePhoneHistoryEntry`).
      return covering
          ? RaftBackDismiss(onDismiss: store.close, child: panel)
          : panel;
    },
  );
}

class _OpenButton extends StatelessWidget {
  const _OpenButton({
    required this.keyName,
    required this.label,
    required this.onPressed,
  });
  final String keyName, label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => RaftButton(
    key: ValueKey(keyName),
    label: label,
    uiVariant: RaftButtonVariant.standard,
    uiSize: RaftButtonSize.md,
    onPressed: onPressed,
  );
}

/// `webPreview.notShowing`: "Page not showing? Open in new tab".
class _NotShowingLine extends StatelessWidget {
  const _NotShowingLine({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = t.scale(t.typeSlot('caption'), color: t.ui.foregroundMuted);
    return Container(
      key: const ValueKey('web-preview-hint'),
      // Web `px-(--column-margin) py-1.5`.
      // ignore: raft_lints/off_grid_spacing -- Web py-1.5 is 6px.
      // ds-allow: Web py-1.5, 6px, between the 4px and 8px steps
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x4,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.ui.lineSeam)),
      ),
      child: Text.rich(
        TextSpan(
          children: raftRichText(
            context,
            'Page not showing? <link>Open in new tab</link>',
            {
              'link': (inner) => WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: RaftTextLink(
                  key: const ValueKey('web-preview-hint-open'),
                  label: inner,
                  variant: RaftTextLinkVariant.muted,
                  scale: null,
                  textStyle: style,
                  onPressed: onOpen,
                ),
              ),
            },
          ),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// The WebView of one page load. A Refresh or another address mounts it again
/// (the panel keys it by address and [WebPreviewStore.reloads]).
class _SiteFrame extends StatefulWidget {
  const _SiteFrame({
    super.key,
    required this.url,
    required this.phoneWidth,
    required this.openExternal,
  });
  final String url;
  final bool phoneWidth;
  final FutureOr<void> Function(String url) openExternal;

  @override
  State<_SiteFrame> createState() => _SiteFrameState();
}

class _SiteFrameState extends State<_SiteFrame> {
  final controller = WebViewController();
  bool started = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    // JavaScript on (sites need it); no JavaScript channel is ever added.
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          switch (webPreviewNavigation(
            request.url,
            isMainFrame: request.isMainFrame,
          )) {
            case WebPreviewNavigation.stay:
              return NavigationDecision.navigate;
            case WebPreviewNavigation.browser:
              unawaited(Future.sync(() => widget.openExternal(request.url)));
              return NavigationDecision.prevent;
            case WebPreviewNavigation.refuse:
              return NavigationDecision.prevent;
          }
        },
      ),
    );
    if (!mounted) return;
    await controller.loadRequest(Uri.parse(widget.url));
    if (mounted) setState(() => started = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final frame = started
        ? WebViewWidget(controller: controller)
        : const SizedBox.expand();
    if (!widget.phoneWidth) return frame;
    // Phone width: a 390px page centred on a quiet surface (Web `py-4`,
    // `rounded-[6px]`, hairline border).
    return ColoredBox(
      key: const ValueKey('web-preview-phone'),
      color: t.ui.fillMuted,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: RaftSpace.x4),
        child: Center(
          child: Container(
            width: webPreviewPhoneWidth,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: t.ui.layerCard,
              // ignore: raft_lints/off_grid_spacing -- Web rounded-[6px].
              // ds-allow: Web rounded-[6px] of the phone-width frame, no token
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              border: Border.all(color: t.ui.lineHairline),
            ),
            child: frame,
          ),
        ),
      ),
    );
  }
}
