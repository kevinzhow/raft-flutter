import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/linux_dependencies.dart';
import 'channel_side_web_preview.dart';
import 'desktop_browser_panel.dart';
import 'desktop_browser_tabs.dart';
import 'desktop_browser_windows_page.dart';

class DesktopBrowserNativePage extends StatelessWidget {
  const DesktopBrowserNativePage({
    super.key,
    required this.tab,
    required this.visible,
    required this.events,
    required this.raftHosts,
    required this.windows,
  });

  final DesktopBrowserTab tab;
  final bool visible;
  final DesktopBrowserPageEvents events;
  final Set<String> raftHosts;
  final DesktopBrowserWindowsProfile windows;

  @override
  Widget build(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.windows
      ? DesktopBrowserWindowsPage(
          tab: tab,
          visible: visible,
          raftHosts: raftHosts,
          events: events,
          profile: windows,
        )
      : _SystemBrowserPage(
          tab: tab,
          visible: visible,
          raftHosts: raftHosts,
          events: events,
        );
}

class _SystemBrowserPage extends StatefulWidget {
  const _SystemBrowserPage({
    required this.tab,
    required this.visible,
    required this.raftHosts,
    required this.events,
  });

  final DesktopBrowserTab tab;
  final bool visible;
  final Set<String> raftHosts;
  final DesktopBrowserPageEvents events;

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
      final linux = await SystemWebViewController.createBrowser(
        widget.raftHosts,
      );
      if (!mounted) {
        await linux.dispose();
        return;
      }
      _subscription = linux.events.listen(_event);
      setState(() => _linux = linux);
      widget.events.history((
        back: () => _run(linux.goBack),
        forward: () => _run(linux.goForward),
        reload: () => _run(linux.reload),
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
      back: () => _run(() => channel.invokeMethod<void>('back')),
      forward: () => _run(() => channel.invokeMethod<void>('forward')),
      reload: () => _run(() => channel.invokeMethod<void>('reload')),
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
      case 'browserState':
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
      case 'failed':
        _fail();
    }
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

  void _run(Future<void> Function() command) {
    unawaited(Future<void>.sync(command).catchError((Object _) => _fail()));
  }

  void _load(Uri target) {
    if (webPreviewTarget(target.toString(), widget.raftHosts) == null) {
      _fail();
      return;
    }
    if (_failed) setState(() => _failed = false);
    if (_linux case final linux?) _run(() => linux.load(target));
    if (_appKit case final channel?) {
      _run(() => channel.invokeMethod<void>('load', target.toString()));
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
              creationParams: widget.raftHosts.toList(),
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
    if (_failed) {
      return BrowserRendererFailure(
        url: widget.tab.url!,
        openExternal: widget.events.openExternal,
      );
    }
    if (linux == null) return const SizedBox.expand();
    final occlusion = RaftNativeSurfaceOcclusion.forView(context);
    return SystemWebView(
      controller: linux,
      visible: widget.visible,
      occlusion: occlusion,
      isOccluded: occlusion.overlaps,
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
