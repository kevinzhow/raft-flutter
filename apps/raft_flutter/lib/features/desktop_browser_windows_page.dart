import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'channel_side_web_preview.dart';
import 'desktop_browser_native_page.dart';
import 'desktop_browser_panel.dart';
import 'desktop_browser_session.dart';
import 'desktop_browser_tabs.dart';

bool allowsWindowsBrowserNavigation(
  String? address,
  Set<String> raftHosts, {
  required bool mainFrame,
}) {
  final local = address?.toLowerCase();
  return webPreviewTarget(address, raftHosts) != null ||
      !mainFrame &&
          (local == 'about:blank' ||
              local == 'about:srcdoc' ||
              local?.startsWith('blob:') == true ||
              local?.startsWith('data:') == true);
}

class WindowsBrowserDownloads {
  final _clock = Stopwatch()..start();
  ({Duration at, Uri? direct})? _click;
  Uri? _navigation;

  void clicked(String address, Set<String> raftHosts) {
    _navigation = null;
    _click = (at: _clock.elapsed, direct: _target(address, raftHosts));
  }

  void navigate(NavigationAction action, Set<String> raftHosts) {
    if (!action.isForMainFrame) return;
    final target = _target(action.request.url?.toString(), raftHosts);
    final click = _recentClick;
    _click = null;
    if (action.navigationType != NavigationType.LINK_ACTIVATED) {
      _navigation = null;
    } else if (action.isRedirect == true) {
      if (_navigation != null) _navigation = target;
    } else {
      _navigation =
          click != null && (click.direct == null || click.direct == target)
          ? target
          : null;
    }
  }

  Uri? consume(DownloadStartRequest request, Set<String> raftHosts) {
    final target = _target(request.url.toString(), raftHosts);
    if (target == null || target != (_navigation ?? _recentClick?.direct)) {
      return null;
    }
    clear();
    return target;
  }

  void clear() {
    _click = null;
    _navigation = null;
  }

  ({Duration at, Uri? direct})? get _recentClick {
    final click = _click;
    return click != null &&
            _clock.elapsed - click.at <= const Duration(seconds: 1)
        ? click
        : null;
  }

  static Uri? _target(String? address, Set<String> raftHosts) =>
      webPreviewTarget(address, raftHosts)?.removeFragment();
}

const _downloadBinding = 'raftBrowserDownloadClick';
const _downloadWorld = 'raftBrowserDownloads';
const _downloadScript =
    '''
  if (window === window.top) {
    window.addEventListener('click', event => {
      if (!event.isTrusted || event.defaultPrevented) return;
      const path = event.composedPath();
      const editable = node => node?.isContentEditable ||
          node instanceof HTMLInputElement &&
            !['button', 'submit', 'image', 'reset'].includes(node.type) ||
          node instanceof HTMLTextAreaElement ||
          node instanceof HTMLSelectElement;
      if (path.some(editable) ||
          event.detail === 0 && editable(document.activeElement)) return;
      const link = path.find(node => node instanceof HTMLAnchorElement &&
          node.hasAttribute('download'));
      globalThis.$_downloadBinding(link ? link.href : '');
    }, true);
  }
''';

class DesktopBrowserWindowsPage extends StatefulWidget {
  const DesktopBrowserWindowsPage({
    super.key,
    required this.tab,
    required this.visible,
    required this.parked,
    required this.raftHosts,
    required this.events,
    required this.profile,
  });

  final DesktopBrowserTab tab;
  final bool visible, parked;
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
  bool _needsRenderer = false;
  Uri? _retryUrl;
  final _downloads = WindowsBrowserDownloads();
  bool _requestedDocument = false;
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
            useOnDownloadStart: true,
            handleAcceleratorKeyPressed: true,
            isInspectable: false,
            allowModalDialogs: false,
          ),
          onWebViewCreated: (controller) =>
              unawaited(_attach(controller as PlatformInAppWebViewController)),
          shouldOverrideUrlLoading: (_, action) {
            final url = action.request.url?.toString();
            final popup = _popupLoads.remove(url);
            if (popup != null) {
              popup.cancel();
              return NavigationActionPolicy.CANCEL;
            }
            final mainFrame = action.isForMainFrame;
            if (!allowsWindowsBrowserNavigation(
                  url,
                  widget.raftHosts,
                  mainFrame: mainFrame,
                ) &&
                !(!_requestedDocument && url == 'about:blank')) {
              return NavigationActionPolicy.CANCEL;
            }
            if (widget.visible) _downloads.navigate(action, widget.raftHosts);
            return NavigationActionPolicy.ALLOW;
          },
          onLaunchingExternalUriScheme: (_, _) =>
              LaunchingExternalUriSchemeResponse(cancel: true),
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
          onLoadStart: (_, _) {
            _retryUrl = null;
            if (_failed && mounted) setState(() => _failed = false);
            _navigationChanged(loading: true);
          },
          onLoadStop: (_, _) {
            _downloads.clear();
            _navigationChanged(loading: false);
          },
          onTitleChanged: (_, _) => _navigationChanged(),
          onUpdateVisitedHistory: (_, _, _) => _navigationChanged(),
          onReceivedError: (_, request, error) {
            if (request.isForMainFrame == true &&
                error.type !=
                    WebResourceErrorType
                        .FRAME_LOAD_INTERRUPTED_BY_POLICY_CHANGE &&
                error.type != WebResourceErrorType.CANCELLED) {
              _retryUrl = webPreviewTarget(
                request.url.toString(),
                widget.raftHosts,
              );
              _fail();
            }
          },
          onProcessFailed: (_, detail) {
            if (detail.kind == ProcessFailedKind.BROWSER_PROCESS_EXITED) {
              widget.profile.invalidate(environment);
              _needsRenderer = true;
              _fail();
            } else if (detail.kind == ProcessFailedKind.RENDER_PROCESS_EXITED) {
              _fail();
            }
          },
          onAcceleratorKeyPressed: (_, key) {
            if (!mounted ||
                !widget.visible ||
                key.keyEventKind != 0 ||
                key.physicalKeyStatus?.wasKeyDown == true) {
              return;
            }
            if (key.virtualKey == 0x57) widget.events.closeTab();
          },
          onPermissionRequest: (_, request) => PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.DENY,
          ),
          onReceivedServerTrustAuthRequest: (_, _) => ServerTrustAuthResponse(
            action: ServerTrustAuthResponseAction.CANCEL,
          ),
          onDownloadStarting: (_, request) {
            final url = _downloads.consume(request, widget.raftHosts);
            if (mounted && widget.visible && url != null) {
              widget.events.openExternal(url);
            }
            return DownloadStartResponse(
              handled: true,
              action: DownloadStartResponseAction.CANCEL,
            );
          },
        ),
      );
      setState(() => _renderer = renderer);
    } catch (_) {
      _fail();
    }
  }

  Future<void> _attach(PlatformInAppWebViewController controller) async {
    if (!mounted) return;
    _controller = controller;
    _syncMedia();
    widget.events.history((
      back: () => _navigate(controller.goBack),
      forward: () => _navigate(controller.goForward),
      reload: () {
        final retryUrl = _retryUrl;
        if (_needsRenderer || retryUrl == null) {
          _navigate(controller.reload);
        } else {
          _load(retryUrl);
        }
      },
    ));
    try {
      await controller.addDevToolsProtocolEventListener(
        eventName: 'Runtime.bindingCalled',
        callback: (data) {
          if (data case {'name': _downloadBinding, 'payload': final String url}
              when mounted &&
                  widget.visible &&
                  identical(_controller, controller)) {
            _downloads.clicked(url, widget.raftHosts);
          }
        },
      );
      await controller.callDevToolsProtocolMethod(methodName: 'Runtime.enable');
      await controller.callDevToolsProtocolMethod(methodName: 'Page.enable');
      await controller.callDevToolsProtocolMethod(
        methodName: 'Runtime.addBinding',
        parameters: {
          'name': _downloadBinding,
          'executionContextName': _downloadWorld,
        },
      );
      await controller.callDevToolsProtocolMethod(
        methodName: 'Page.addScriptToEvaluateOnNewDocument',
        parameters: {'source': _downloadScript, 'worldName': _downloadWorld},
      );
    } catch (_) {}
    if (mounted && identical(_controller, controller)) {
      _load(_retryUrl ?? widget.tab.url!);
    }
  }

  void _navigationChanged({bool? loading}) {
    _loading = loading ?? _loading;
    final ticket = ++_sample;
    final controller = _controller;
    if (controller == null || !mounted || _failed) return;
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

  void _syncMedia() {
    final controller = _controller;
    if (controller == null) return;
    final channel = MethodChannel(
      'com.pichillilorenzo/flutter_inappwebview_${controller.getViewId()}',
    );
    unawaited(
      channel
          .invokeMethod<void>('setSettings', {
            'settings': {'raftBrowserMuted': widget.parked},
          })
          .catchError((Object _) {}),
    );
  }

  void _navigate(Future<void> Function() command) {
    _downloads.clear();
    ++_sample;
    if (_needsRenderer) {
      _needsRenderer = false;
      _controller = null;
      _renderer?.dispose();
      setState(() {
        _renderer = null;
        _failed = false;
      });
      unawaited(_start());
      return;
    }
    if (_failed) {
      setState(() => _failed = false);
    }
    _run(command);
  }

  void _fail() {
    if (!mounted || _failed) return;
    ++_sample;
    _loading = false;
    setState(() => _failed = true);
    final page = widget.tab.page;
    final target = _retryUrl;
    widget.events.state((
      url: target ?? page.url,
      title: target == null || target == page.url ? page.title : '',
      back: page.back,
      forward: page.forward,
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
    _retryUrl = url;
    _requestedDocument = true;
    _navigate(
      () => controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(url.toString())),
      ),
    );
  }

  @override
  void didUpdateWidget(DesktopBrowserWindowsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible) _downloads.clear();
    if (widget.parked != oldWidget.parked) _syncMedia();
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
        Offstage(
          key: ObjectKey(renderer),
          offstage: _failed,
          child: renderer.build(context),
        ),
      if (_failed)
        BrowserRendererFailure(
          url: widget.tab.url!,
          openExternal: widget.events.openExternal,
        ),
    ],
  );
}
