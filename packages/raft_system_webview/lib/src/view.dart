import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'geometry.dart';

/// A Flutter layout placeholder for a native GTK widget. [visible] is a
/// caller-owned fence: keep it false for loading/error surfaces and whenever a
/// Flutter overlay covers the report. Native GTK cannot paint behind Flutter.
class SystemWebView extends StatefulWidget {
  const SystemWebView({
    super.key,
    required this.controller,
    required this.visible,
  });
  final SystemWebViewController controller;
  final bool visible;
  @override
  State<SystemWebView> createState() => _SystemWebViewState();
}

class _SystemWebViewState extends State<SystemWebView>
    with WidgetsBindingObserver {
  SystemWebViewLayout _last = SystemWebViewLayout.hidden;
  bool _foreground = true;
  bool _routeActive = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeActive =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (!_routeActive) _report(SystemWebViewLayout.hidden);
    context.findRenderObject()?.markNeedsPaint();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!_foreground) _report(SystemWebViewLayout.hidden);
    context.findRenderObject()?.markNeedsPaint();
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One frame after an OS lifecycle change restores committed native geometry; the callback never reschedules itself.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _report(SystemWebViewLayout value) {
    final effective = widget.visible && _foreground && _routeActive
        ? value
        : SystemWebViewLayout.hidden;
    if (_last == effective || widget.controller.closed) return;
    _last = effective;
    unawaited(widget.controller.layout(effective).catchError((Object _) {}));
  }

  @override
  void didUpdateWidget(SystemWebView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      unawaited(
        old.controller
            .layout(SystemWebViewLayout.hidden)
            .catchError((Object _) {}),
      );
      _last = SystemWebViewLayout.hidden;
    }
    if (!widget.visible) _report(SystemWebViewLayout.hidden);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _report(SystemWebViewLayout.hidden);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GeometryObserver(onLayout: _report);
}

class _GeometryObserver extends LeafRenderObjectWidget {
  const _GeometryObserver({required this.onLayout});
  final ValueChanged<SystemWebViewLayout> onLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GeometryBox(onLayout);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _GeometryBox renderObject,
  ) {
    renderObject.onLayout = onLayout;
    renderObject.markNeedsPaint();
  }
}

class _GeometryBox extends RenderBox {
  _GeometryBox(this.onLayout);
  ValueChanged<SystemWebViewLayout> onLayout;
  bool _scheduled = false;
  @override
  bool get isRepaintBoundary => true;
  @override
  void performLayout() => size = constraints.biggest;
  @override
  void detach() {
    onLayout(SystemWebViewLayout.hidden);
    super.detach();
  }

  void report() {
    if (!attached || layer?.attached != true) {
      onLayout(SystemWebViewLayout.hidden);
      return;
    }
    RenderObject? root = this;
    while (root?.parent != null) {
      root = root!.parent;
    }
    if (root is! RenderView || root.child == null) {
      onLayout(SystemWebViewLayout.hidden);
      return;
    }
    final clips = <Rect>[];
    RenderObject child = this;
    RenderObject? parent = this.parent;
    while (parent != null && parent != root) {
      if (!parent.paintsChild(child)) {
        onLayout(SystemWebViewLayout.hidden);
        return;
      }
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        // First prototype accepts rectangular clips only. Unknown/rounded
        // clipping must not accidentally expose native pixels or input.
        if (parent is! RenderClipRect) {
          onLayout(SystemWebViewLayout.hidden);
          return;
        }
        clips.add(
          MatrixUtils.transformRect(parent.getTransformTo(root.child), clip),
        );
      }
      child = parent;
      parent = parent.parent;
    }
    onLayout(
      SystemWebViewLayout.resolve(
        local: Offset.zero & size,
        transform: getTransformTo(root.child),
        viewport: Offset.zero & root.size,
        clips: clips,
        scale:
            root.configuration.devicePixelRatio /
            root.flutterView.devicePixelRatio,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      report();
    });
  }
}
