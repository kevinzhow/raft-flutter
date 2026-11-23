import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/linux_dependencies.dart';
import 'channel_side_web_preview.dart';
import 'desktop_browser_panel.dart';
import 'desktop_browser_session.dart';
import 'desktop_browser_tabs.dart';
import 'desktop_browser_windows_page.dart';

class DesktopBrowserNativePage extends StatelessWidget {
  const DesktopBrowserNativePage({
    super.key,
    required this.tab,
    required this.visible,
    required this.events,
    required this.raftHosts,
    required this.session,
  });

  final DesktopBrowserTab tab;
  final bool visible;
  final DesktopBrowserPageEvents events;
  final Set<String> raftHosts;
  final DesktopBrowserSession session;

  @override
  Widget build(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.windows
      ? DesktopBrowserWindowsPage(
          tab: tab,
          visible: visible,
          raftHosts: raftHosts,
          events: events,
          profile: session.windows,
        )
      : _SystemBrowserPage(
          tab: tab,
          visible: visible,
          raftHosts: raftHosts,
          events: events,
          session: session,
        );
}

class _SystemBrowserPage extends StatefulWidget {
  const _SystemBrowserPage({
    required this.tab,
    required this.visible,
    required this.raftHosts,
    required this.events,
    required this.session,
  });

  final DesktopBrowserTab tab;
  final bool visible;
  final Set<String> raftHosts;
  final DesktopBrowserPageEvents events;
  final DesktopBrowserSession session;

  @override
  State<_SystemBrowserPage> createState() => _SystemBrowserPageState();
}

class _SystemBrowserPageState extends State<_SystemBrowserPage> {
  bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;
  SystemWebViewController? _linux;
  StreamSubscription<Map<Object?, Object?>>? _subscription;
  MethodChannel? _appKit;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (!_mac) unawaited(_startLinux());
  }

  Future<void> _startLinux() async {
    try {
      await LinuxDependencies.instance.ensure(LinuxDependency.webkit);
      if (!mounted) return;
      final linux = await widget.session.openLinux(widget.raftHosts);
      if (!mounted) {
        await linux.dispose();
        return;
      }
      _subscription = linux.events.listen(_event);
      setState(() => _linux = linux);
      widget.events.history((
        back: () => _navigate(linux.goBack),
        forward: () => _navigate(linux.goForward),
        reload: () => _navigate(linux.reload),
      ));
      _load(widget.tab.url!);
    } catch (_) {
      _fail();
    }
  }

  void _startMac(int id) {
    if (!mounted) return;
    final channel = _appKit = MethodChannel('app.raft/desktop_browser/$id');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'event' && call.arguments is Map) {
        _event(Map<Object?, Object?>.from(call.arguments as Map));
      }
    });
    widget.events.history((
      back: () => _navigate(() => channel.invokeMethod<void>('back')),
      forward: () => _navigate(() => channel.invokeMethod<void>('forward')),
      reload: () => _navigate(() => channel.invokeMethod<void>('reload')),
    ));
    _load(widget.tab.url!);
  }

  void _event(Map<Object?, Object?> fields) {
    if (!mounted) return;
    final rawUrl = fields['url'];
    final url = rawUrl is String
        ? webPreviewTarget(rawUrl, widget.raftHosts)
        : null;
    switch (fields['type']) {
      case 'browserState' when !_failed:
        widget.events.state((
          url: url,
          title: fields['title'] is String ? fields['title'] as String : '',
          back: fields['back'] == true,
          forward: fields['forward'] == true,
          loading: fields['loading'] == true,
        ));
      case 'openExternal' when url != null && widget.visible:
        widget.events.openExternal(url);
      case 'closeTab' when widget.visible:
        widget.events.closeTab();
      case 'closePanel' when widget.visible:
        widget.events.closePanel();
      case 'navigationStarted':
        if (_failed) setState(() => _failed = false);
      case 'failed':
        _fail(url);
    }
  }

  void _fail([Uri? target]) {
    if (!mounted || _failed) return;
    setState(() => _failed = true);
    final page = widget.tab.page;
    widget.events.state((
      url: target ?? page.url,
      title: target == null || target == page.url ? page.title : '',
      back: page.back,
      forward: page.forward,
      loading: false,
    ));
  }

  void _navigate(Future<void> Function() command) {
    if (_failed) setState(() => _failed = false);
    unawaited(Future<void>.sync(command).catchError((Object _) => _fail()));
  }

  void _load(Uri target) {
    if (webPreviewTarget(target.toString(), widget.raftHosts) == null) {
      _fail();
      return;
    }
    if (_linux case final linux?) _navigate(() => linux.load(target));
    if (_appKit case final channel?) {
      _navigate(() => channel.invokeMethod<void>('load', target.toString()));
    }
  }

  @override
  void didUpdateWidget(_SystemBrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab.navigation == oldWidget.tab.navigation) return;
    final target = widget.tab.requested;
    if (target != null) _load(target);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    final linux = _linux;
    if (linux != null) {
      unawaited(linux.dispose().catchError((Object _) {}));
    }
    _appKit?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mac) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _failed,
            child: AppKitView(
              viewType: 'app.raft/desktop_browser',
              onPlatformViewCreated: _startMac,
              creationParams: widget.session.macArguments(widget.raftHosts),
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ),
          if (_failed)
            BrowserRendererFailure(
              url: widget.tab.url!,
              openExternal: widget.events.openExternal,
            ),
        ],
      );
    }
    final linux = _linux;
    final occlusion = RaftNativeSurfaceOcclusion.forView(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (linux != null)
          SystemWebView(
            controller: linux,
            visible: widget.visible && !_failed,
            occlusion: occlusion,
            isOccluded: occlusion.overlaps,
          ),
        if (_failed)
          BrowserRendererFailure(
            url: widget.tab.url!,
            openExternal: widget.events.openExternal,
          ),
      ],
    );
  }
}

class BrowserRendererFailure extends StatelessWidget {
  const BrowserRendererFailure({
    super.key,
    required this.url,
    required this.openExternal,
  });

  final Uri url;
  final ValueChanged<Uri> openExternal;

  @override
  Widget build(BuildContext context) => RaftEmptyState(
    glyph: RaftGlyph.globe,
    title: raftText(context, 'This page can’t be shown here'),
    action: RaftButton(
      label: raftText(context, 'Open in browser'),
      uiVariant: RaftButtonVariant.outline,
      onPressed: () => openExternal(url),
    ),
  );
}
