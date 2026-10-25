import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../platform/system_bars.dart';
import 'artifact_link.dart';
import 'human_login.dart';
import 'human_login_scope.dart';
import 'human_login_sheet.dart';

/// Opens an artifact link inside the app: a full-screen page on narrow
/// windows, a full-bleed dialog on wide ones (the same split as attachment
/// previews). Private artifacts offer "Login with Raft", which needs the
/// Raft session only the app holds; the viewer takes that step over natively.
Future<void> openArtifactLink(
  BuildContext context,
  Uri uri, {
  ArtifactWebViewBuilder? webViewBuilder,
  Future<bool> Function(Uri)? openExternal,
}) {
  final page = RaftAdaptiveWorkspace.compactOf(context);
  final api = HumanLoginScope.maybeOf(context);
  Widget viewer(BuildContext context) => ArtifactViewer(
    uri: uri,
    api: api,
    page: page,
    webViewBuilder: webViewBuilder,
    openExternal: openExternal,
    onClose: () => Navigator.of(context).maybePop(),
  );
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push<void>(
    page
        ? RaftPreviewPageRoute<void>(
            settings: const RouteSettings(name: '/artifact'),
            builder: (context) {
              final surface = RaftTokens.of(context).panel;
              // ds-allow: Native route owns keyboard insets and system bars; raft_ui owns the header.
              return Scaffold(
                backgroundColor: surface,
                body: RaftSystemBarSurface(
                  statusBarFallback: surface,
                  child: viewer(context),
                ),
              );
            },
          )
        : RaftFullBleedDialogRoute<void>(context: context, builder: viewer),
  );
}

/// Builds the platform WebView for [controller]. Tests replace it.
typedef ArtifactWebViewBuilder = Widget Function(
  BuildContext context,
  WebViewController controller,
);

Widget _platformWebView(BuildContext context, WebViewController controller) =>
    WebViewWidget(controller: controller);

/// The in-app artifact browser.
///
/// The WebView has no JavaScript channel, no file or content access, and stays
/// on artifact pages: a link to any other site opens in the system browser.
/// Main-frame navigation to the Raft Web app's Login with Raft setup page is
/// cancelled and answered natively (see [HumanLoginSheet]); after the person
/// confirms, the WebView loads the callback with the issued code.
class ArtifactViewer extends StatefulWidget {
  const ArtifactViewer({
    super.key,
    required this.uri,
    required this.api,
    required this.onClose,
    this.page = false,
    this.webViewBuilder,
    this.openExternal,
    this.configure,
  });
  final Uri uri;

  /// The signed-in app's side of Login with Raft; null signed out, which
  /// leaves the sign-in page to the system browser.
  final HumanLoginApi? api;
  final VoidCallback onClose;

  /// Native page (narrow windows) or full-bleed dialog.
  final bool page;
  final ArtifactWebViewBuilder? webViewBuilder;
  final Future<bool> Function(Uri)? openExternal;

  /// Test seam: receives the controller before the first load.
  final void Function(WebViewController controller)? configure;

  @override
  State<ArtifactViewer> createState() => _ArtifactViewerState();
}

class _ArtifactViewerState extends State<ArtifactViewer> {
  late final WebViewController controller;
  late Uri current = widget.uri;

  /// The last page that finished loading: where cancel returns to.
  Uri? lastPage;
  int progress = 0;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared by Retry and by the next page that loads.
  String? loadError;
  bool takingOver = false, closed = false;

  /// Origins the WebView may show: the artifact hosts, plus the callback of a
  /// Login with Raft the person confirmed.
  final trusted = <Uri>[...ArtifactLinks.origins()];
  static const privacyChannel = MethodChannel('app.raft/html-preview-privacy');

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: onNavigationRequest,
          onUrlChange: (change) {
            final url = change.url;
            if (url != null && mounted) onUrl(Uri.tryParse(url));
          },
          onProgress: (percent) {
            if (mounted) setState(() => progress = percent);
          },
          onPageFinished: (url) {
            final uri = Uri.tryParse(url);
            if (!mounted || uri == null) return;
            if (isTakeover(uri)) return;
            setState(() {
              lastPage = uri;
              current = uri;
              loadError = null;
              progress = 100;
            });
          },
          onWebResourceError: (error) {
            if (mounted && (error.isForMainFrame ?? false)) {
              setState(() => loadError = error.description);
            }
          },
        ),
      );
    widget.configure?.call(controller);
    unawaited(start());
  }

  Future<void> start() async {
    // The HTML preview switches the process-wide cookie jar off (its documents
    // run isolated). A signed-in artifact needs its session cookie.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await privacyChannel.invokeMethod<void>('enableCookies');
      } on MissingPluginException {
        // No Android host (tests): nothing to enable.
      } on PlatformException {
        // Cookies stay as they are; the page may ask for sign-in again.
      }
    }
    if (mounted) await controller.loadRequest(widget.uri);
  }

  bool isTakeover(Uri uri) {
    final api = widget.api;
    return api != null && isHumanLoginSetupUri(uri, api.webOrigin);
  }

  bool trustedOrigin(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return false;
    return trusted.any(
      (origin) =>
          origin.scheme.toLowerCase() == scheme &&
          origin.host.toLowerCase() == uri.host.toLowerCase() &&
          _port(origin) == _port(uri),
    );
  }

  static int _port(Uri uri) => uri.hasPort
      ? uri.port
      : uri.scheme.toLowerCase() == 'https'
      ? 443
      : 80;

  FutureOr<NavigationDecision> onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    // The blank page that unloads the document on close must pass: WKWebView
    // asks the delegate about programmatic loads too.
    if (closed) {
      return request.url == 'about:blank'
          ? NavigationDecision.navigate
          : NavigationDecision.prevent;
    }
    if (!request.isMainFrame) return NavigationDecision.navigate;
    if (uri.toString() == widget.uri.toString() || trustedOrigin(uri)) {
      return NavigationDecision.navigate;
    }
    if (isTakeover(uri)) {
      unawaited(takeOver(uri));
      return NavigationDecision.prevent;
    }
    // Any other site: the system browser, as before. Other schemes (intent:,
    // javascript:, file:) are not links at all.
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      unawaited(launch(uri));
    }
    return NavigationDecision.prevent;
  }

  /// Backup for a platform that reports a redirect to the setup page only
  /// after it started loading: stop it and take the page over all the same.
  void onUrl(Uri? uri) {
    if (uri == null || !isTakeover(uri) || takingOver) return;
    unawaited(takeOver(uri));
  }

  Future<bool> launch(Uri uri) => widget.openExternal != null
      ? widget.openExternal!(uri)
      : launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Web `HumanLoginSetupPage`, natively: confirm, authorize with the app's
  /// own session, then load the callback with the code in the WebView.
  Future<void> takeOver(Uri setup) async {
    final api = widget.api;
    if (api == null || takingOver) return;
    takingOver = true;
    try {
      final request = HumanLoginRequest.fromSetupUri(setup);
      final location = await showHumanLoginSheet(
        context,
        api: api,
        request: request,
      );
      if (!mounted) return;
      if (location == null) {
        await returnToSignIn();
      } else {
        // The person approved this callback: it may stay in the WebView.
        trusted.add(Uri.parse(location.origin));
        setState(() => loadError = null);
        await controller.loadRequest(location);
      }
    } finally {
      takingOver = false;
    }
  }

  /// Cancel and failure end on the artifact's sign-in page. A cancelled
  /// navigation leaves it showing; a page already replaced is loaded again.
  Future<void> returnToSignIn() async {
    final back = lastPage;
    if (back == null) return;
    final shown = Uri.tryParse(await controller.currentUrl() ?? '');
    if (shown == null || shown.toString() != back.toString()) {
      await controller.loadRequest(back);
    }
  }

  Future<void> openInBrowser() async {
    final url = current;
    if (url.scheme != 'https' && url.scheme != 'http') return;
    await launch(url);
  }

  Future<void> retry() async {
    setState(() {
      loadError = null;
      progress = 0;
    });
    await controller.loadRequest(lastPage ?? widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final t = RaftTokens.of(context);
    final actions = [
      RaftLightboxIconAction(
        key: const ValueKey('artifact-viewer-open-browser'),
        glyph: RaftGlyph.externalLink,
        label: tr('Open in browser'),
        onPressed: openInBrowser,
      ),
    ];
    final title = current.host.isEmpty ? widget.uri.host : current.host;
    final header = widget.page
        ? RaftPanelHeaderBar(
            title: title,
            onBack: widget.onClose,
            backKey: const ValueKey('artifact-viewer-close'),
            backTooltip: 'Close',
            actions: actions,
          )
        : RaftLightboxHeader(
            title: title,
            borderWidth: 1,
            onClose: widget.onClose,
            closeLabel: 'Close',
            actions: actions,
          );
    final webView = (widget.webViewBuilder ?? _platformWebView)(
      context,
      controller,
    );
    final body = Stack(
      children: [
        Positioned.fill(child: webView),
        if (loadError != null)
          Positioned.fill(
            child: ColoredBox(
              color: t.panel,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(RaftSpace.x6),
                  child: Column(
                    key: const ValueKey('artifact-viewer-error'),
                    mainAxisSize: MainAxisSize.min,
                    spacing: RaftSpace.x3,
                    children: [
                      Text(
                        tr('This page could not be loaded.'),
                        textAlign: TextAlign.center,
                        style: RaftTypography.heading(t, size: 16, line: 22),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: RaftSpace.x3,
                        children: [
                          RaftButton(
                            label: tr('Retry'),
                            tone: RaftButtonRecipeVariant.outline,
                            size: RaftButtonRecipeSize.md,
                            onPressed: retry,
                          ),
                          RaftButton(
                            label: tr('Open in browser'),
                            tone: RaftButtonRecipeVariant.accent,
                            size: RaftButtonRecipeSize.md,
                            onPressed: openInBrowser,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (progress < 100 && loadError == null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: RaftProgressBar(
              key: const ValueKey('artifact-viewer-progress'),
              value: progress.toDouble(),
              size: RaftProgressRecipeSize.sm,
            ),
          ),
      ],
    );
    final content = Column(
      children: [
        header,
        Expanded(child: body),
      ],
    );
    final scoped = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          key: const ValueKey('artifact-viewer'),
          color: t.panel,
          child: content,
        ),
      ),
    );
    // The header sits below the status bar; the page runs to the screen bottom.
    final safe = SafeArea(bottom: false, child: scoped);
    return widget.page
        ? safe
        // ds-allow: full-bleed viewer shell, the same Dialog.fullscreen the attachment preview shell uses (raft_ui)
        : Dialog.fullscreen(backgroundColor: t.panel, child: safe);
  }

  @override
  void dispose() {
    // Unload the page so its scripts and network stop with the viewer.
    closed = true;
    unawaited(
      controller
          .loadRequest(Uri.parse('about:blank'))
          .then<void>((_) {}, onError: (Object _) {}),
    );
    super.dispose();
  }
}
