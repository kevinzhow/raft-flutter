import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_html_linux_geometry.dart';
import 'attachment_html_webview_events.dart';

/// The GTK3 system renderer owns the native widget and ephemeral context. The
/// SDK owns all layout, comment and overlay recipes; uploaded HTML owns neither.
class LinuxAttachmentHtmlWebView extends StatefulWidget {
  const LinuxAttachmentHtmlWebView({
    super.key,
    required this.uri,
    required this.events,
    this.controllerFactory = SystemWebViewController.create,
    this.onControllerCreated,
    this.onDisposed,
  });
  final Uri uri;
  final AttachmentHtmlWebViewEvents events;
  @visibleForTesting
  final Future<SystemWebViewController> Function() controllerFactory;
  @visibleForTesting
  final void Function(SystemWebViewController)? onControllerCreated;
  @visibleForTesting
  final VoidCallback? onDisposed;
  @override
  State<LinuxAttachmentHtmlWebView> createState() => _LinuxHtmlState();
}

class _LinuxHtmlState extends State<LinuxAttachmentHtmlWebView> {
  SystemWebViewController? controller;
  LinuxAttachmentHtmlGeometryController? geometry;
  StreamSubscription<Map<Object?, Object?>>? subscription;
  bool loaded = false, closed = false, failed = false;
  int generation = 0, updateRevision = 0;

  bool current(int ticket) => mounted && !closed && generation == ticket;

  @override
  void initState() {
    super.initState();
    unawaited(start());
  }

  Future<void> start() async {
    final ticket = ++generation;
    loaded = false;
    failed = false;
    try {
      final created = await widget.controllerFactory();
      if (!current(ticket)) {
        await created.dispose();
        return;
      }
      controller = created;
      geometry = LinuxAttachmentHtmlGeometryController(
        uri: widget.uri,
        system: created,
        allowed: () => current(ticket) && loaded && !failed && !created.closed,
      );
      subscription = created.events.listen((event) {
        if (!current(ticket)) return;
        switch (event['type']) {
          case 'loaded':
            if (loaded || failed) return;
            setState(() => loaded = true);
            widget.events.onGeometryReady?.call(geometry!);
            widget.events.onLoaded();
          case 'failed':
            fail(ticket);
          case 'progress':
            final percent = event['percent'];
            if (!loaded && !failed && percent is int) {
              widget.events.onProgress?.call(percent.clamp(0, 100));
            }
          case 'navigation':
            // Only the native trusted main-frame link fence can emit this.
            final url = event['url'];
            if (loaded && !failed && url is String && url.length <= 8192) {
              widget.events.onNavigation(url);
            }
        }
      });
      widget.onControllerCreated?.call(created);
      setState(() {});
      await created.load(widget.uri);
    } catch (_) {
      fail(ticket);
    }
  }

  void fail(int ticket) {
    if (!current(ticket) || failed) return;
    setState(() {
      loaded = false;
      failed = true;
    });
    widget.events.onFailed('the system preview could not be isolated');
  }

  Future<void> retire() async {
    generation++;
    loaded = false;
    final onDisposed = widget.onDisposed;
    final old = controller;
    controller = null;
    geometry?.dispose();
    geometry = null;
    // Cancel stream delivery synchronously, but never delay the native stop
    // behind asynchronous subscription bookkeeping. Controller disposal closes
    // the stream after its actual native dispose request completes.
    unawaited(subscription?.cancel());
    subscription = null;
    if (old == null) return;
    try {
      await old.dispose();
      onDisposed?.call();
    } catch (_) {
      // Native teardown errors must not resurrect a retired document or leak
      // signed preview URLs through the global application error surface.
    }
  }

  @override
  void didUpdateWidget(LinuxAttachmentHtmlWebView old) {
    super.didUpdateWidget(old);
    if (old.uri != widget.uri ||
        old.controllerFactory != widget.controllerFactory) {
      final revision = ++updateRevision;
      unawaited(
        retire().then((_) {
          if (mounted && !closed && revision == updateRevision) return start();
        }),
      );
    }
  }

  @override
  void dispose() {
    closed = true;
    updateRevision++;
    unawaited(retire());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = controller;
    if (current == null) return const SizedBox.expand();
    final occlusion = RaftNativeSurfaceOcclusion.forView(context);
    return SystemWebView(
      controller: current,
      visible: loaded && !failed && !closed,
      occlusion: occlusion,
      isOccluded: occlusion.overlaps,
    );
  }
}
