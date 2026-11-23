import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import '../platform/attachment_html_desktop_environment.dart';
import 'channel_side_web_preview.dart';
import 'desktop_browser_native_page.dart';
import 'desktop_browser_panel.dart';
import 'desktop_browser_tabs.dart';

class DesktopBrowserWindowsProfile {
  Future<DesktopHtmlEnvironment>? _environment;

  Future<DesktopHtmlEnvironment> open() =>
      _environment ??= DesktopHtmlEnvironment.create(TargetPlatform.windows);

  void dispose() {
    final environment = _environment;
    if (environment != null) {
      unawaited(
        environment
            .then((created) => created.dispose())
            .catchError((Object _) {}),
      );
    }
  }
}

class DesktopBrowserWindowsPage extends StatefulWidget {
  const DesktopBrowserWindowsPage({
    super.key,
    required this.tab,
    required this.visible,
    required this.raftHosts,
    required this.events,
    required this.profile,
  });

  final DesktopBrowserTab tab;
  final bool visible;
  final Set<String> raftHosts;
  final DesktopBrowserPageEvents events;
  final DesktopBrowserWindowsProfile profile;

  @override
  State<DesktopBrowserWindowsPage> createState() =>
      _DesktopBrowserWindowsPageState();
}

class _DesktopBrowserWindowsPageState extends State<DesktopBrowserWindowsPage> {
  PlatformInAppWebViewWidget? _renderer;
  PlatformInAppWebViewController? _controller;
  final _popupLoads = <String, Timer>{};
  bool _failed = false, _loading = true;
  int _sample = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final environment = await widget.profile.open();
      if (!mounted) return;
      final renderer = PlatformInAppWebViewWidget(
        PlatformInAppWebViewWidgetCreationParams(
          controllerFromPlatform: (controller) => controller,
          webViewEnvironment: environment.platform,
          initialSettings: InAppWebViewSettings(
            incognito: true,
            javaScriptBridgeEnabled: false,
            javaScriptBridgeOriginAllowList: const {},
            pluginScriptsOriginAllowList: const {},
            allowFileAccess: false,
            allowFileAccessFromFileURLs: false,
            allowUniversalAccessFromFileURLs: false,
            javaScriptCanOpenWindowsAutomatically: false,
            mediaPlaybackRequiresUserGesture: true,
            useShouldOverrideUrlLoading: true,
            isInspectable: false,
            allowModalDialogs: false,
          ),
          onWebViewCreated: (controller) =>
              _attach(controller as PlatformInAppWebViewController),
          shouldOverrideUrlLoading: (_, action) {
            final url = action.request.url?.toString();
            final popup = _popupLoads.remove(url);
            if (popup != null) {
              popup.cancel();
              return NavigationActionPolicy.CANCEL;
            }
            if (url == 'about:blank' ||
                webPreviewTarget(url, widget.raftHosts) != null) {
              return NavigationActionPolicy.ALLOW;
            }
            return NavigationActionPolicy.CANCEL;
          },
          onCreateWindow: (_, action) {
            final raw = action.request.url?.toString();
            final url = webPreviewTarget(raw, widget.raftHosts);
            if (raw != null && (url != null || raw == 'about:blank')) {
              _popupLoads.remove(raw)?.cancel();
              _popupLoads[raw] = Timer(
                const Duration(seconds: 2),
                () => _popupLoads.remove(raw),
              );
            }
            if (mounted &&
                widget.visible &&
                url != null &&
                action.hasGesture == true) {
              widget.events.openExternal(url);
            }
            return false;
          },
          onLoadStart: (_, _) => _navigationChanged(loading: true),
          onLoadStop: (_, _) => _navigationChanged(loading: false),
          onTitleChanged: (_, _) => _navigationChanged(),
          onUpdateVisitedHistory: (_, _, _) => _navigationChanged(),
          onReceivedError: (_, request, _) {
            if (request.isForMainFrame == true) {
              _navigationChanged(loading: false);
            }
          },
          onPermissionRequest: (_, request) => PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.DENY,
          ),
          onReceivedServerTrustAuthRequest: (_, _) => ServerTrustAuthResponse(
            action: ServerTrustAuthResponseAction.CANCEL,
          ),
          onDownloadStarting: (_, _) => DownloadStartResponse(
            handled: true,
            action: DownloadStartResponseAction.CANCEL,
          ),
        ),
      );
      setState(() => _renderer = renderer);
    } catch (_) {
      _fail();
    }
  }

  void _attach(PlatformInAppWebViewController controller) {
    if (!mounted) return;
    _controller = controller;
    widget.events.history((
      back: () => _run(controller.goBack),
      forward: () => _run(controller.goForward),
      reload: () => _run(controller.reload),
    ));
    _load(widget.tab.url!);
  }

  void _navigationChanged({bool? loading}) {
    _loading = loading ?? _loading;
    final ticket = ++_sample;
    final controller = _controller;
    if (controller == null || !mounted) return;
    _run(() async {
      final (url, title, back, forward) = await (
        controller.getUrl(),
        controller.getTitle(),
        controller.canGoBack(),
        controller.canGoForward(),
      ).wait;
      if (!mounted || ticket != _sample) return;
      widget.events.state((
        url: webPreviewTarget(url?.toString(), widget.raftHosts),
        title: title ?? '',
        back: back,
        forward: forward,
        loading: _loading,
      ));
    });
  }

  void _run(Future<void> Function() command) {
    unawaited(Future<void>.sync(command).catchError((Object _) => _fail()));
  }

  void _fail() {
    if (!mounted || _failed) return;
    setState(() => _failed = true);
    widget.events.state((
      url: null,
      title: '',
      back: false,
      forward: false,
      loading: false,
    ));
  }

  void _load(Uri target) {
    final controller = _controller;
    if (controller == null) return;
    final url = webPreviewTarget(target.toString(), widget.raftHosts);
    if (url == null) {
      _fail();
      return;
    }
    ++_sample;
    if (_failed) setState(() => _failed = false);
    _run(
      () => controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(url.toString())),
      ),
    );
  }

  @override
  void didUpdateWidget(DesktopBrowserWindowsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab.navigation == oldWidget.tab.navigation) return;
    if (widget.tab.requested case final target?) _load(target);
  }

  @override
  void dispose() {
    for (final pending in _popupLoads.values) {
      pending.cancel();
    }
    _renderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_renderer case final renderer?)
        Offstage(offstage: _failed, child: renderer.build(context)),
      if (_failed)
        BrowserRendererFailure(
          url: widget.tab.url!,
          openExternal: widget.events.openExternal,
        ),
    ],
  );
}
