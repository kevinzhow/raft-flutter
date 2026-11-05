import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'geometry.dart';
import 'snapshot.dart';

/// A Flutter layout placeholder for a native GTK widget. [visible] is a
/// caller-owned fence: keep it false for loading/error surfaces and whenever a
/// Flutter overlay covers the report. Native GTK cannot paint behind Flutter.
class SystemWebView extends StatefulWidget {
  const SystemWebView({
    super.key,
    required this.controller,
    required this.visible,
    this.occlusion,
    this.isOccluded,
  });
  final SystemWebViewController controller;
  final bool visible;
  final Listenable? occlusion;
  final bool Function(Rect viewLogicalBounds)? isOccluded;
  @override
  State<SystemWebView> createState() => _SystemWebViewState();
}

class _SystemWebViewState extends State<SystemWebView>
    with WidgetsBindingObserver {
  SystemWebViewLayout _last = SystemWebViewLayout.hidden;
  bool _foreground = true;
  bool _routeActive = true;
  Size _viewportSize = Size.zero;
  Size _imageViewport = Size.zero;
  StreamSubscription<Map<Object?, Object?>>? _events;
  late SystemWebViewSnapshotCache _snapshot;

  void _bindSnapshots() {
    final owner = widget.controller;
    _snapshot = SystemWebViewSnapshotCache(
      capture: owner.snapshot,
      changed: _snapshotChanged,
    );
    _events = owner.events.listen(
      (event) {
        if (owner != widget.controller) return;
        if (event['type'] == 'focus' && event['focused'] == true) {
          _releaseFlutterFocus(owner);
        }
        if (event['type'] == 'closed') {
          _snapshot.dispose();
          _snapshotChanged();
          return;
        }
        if (event['type'] == 'loaded' || event['type'] == 'snapshotDirty') {
          _refreshSnapshot();
        }
      },
      onDone: () {
        if (owner != widget.controller) return;
        _snapshot.dispose();
        _snapshotChanged();
      },
    );
  }

  bool _acceptsNativeFocus(SystemWebViewController owner) =>
      mounted &&
      owner == widget.controller &&
      !owner.closed &&
      widget.visible &&
      _last.visible &&
      _foreground &&
      _routeActive &&
      !(widget.isOccluded?.call(_last.frame) ?? false);

  void _releaseFlutterFocus(SystemWebViewController owner) {
    if (!_acceptsNativeFocus(owner)) return;
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focus == null ||
        focusContext == null ||
        View.maybeOf(focusContext) != View.maybeOf(context)) {
      return;
    }
    // GTK emits focus-out before forwarding a real Flutter-side press. Handle
    // its notifications synchronously, without a second round-trip that can
    // clear an editor the user has already clicked again.
    focus.unfocus();
  }

  void _snapshotChanged() {
    _imageViewport = _snapshot.image == null ? Size.zero : _viewportSize;
    if (!mounted) return;
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _viewportMeasured(Size size) {
    if (_viewportSize == size) return;
    _viewportSize = size;
    _snapshot.invalidate(clearImage: true);
  }

  void _refreshSnapshot() {
    if (widget.visible &&
        _foreground &&
        _routeActive &&
        widget.controller.supportsSnapshots &&
        !widget.controller.closed) {
      unawaited(_snapshot.refresh());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.occlusion?.addListener(_occlusionChanged);
    _bindSnapshots();
  }

  void _occlusionChanged() {
    _refreshSnapshot();
    context.findRenderObject()?.markNeedsPaint();
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One frame follows an actual overlay change; there is no repeating native-visibility poll.
    WidgetsBinding.instance.ensureVisualUpdate();
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
    final previous = _last;
    final viewportChanged =
        effective.visible &&
        (!previous.visible || previous.frame.size != effective.frame.size);
    if (viewportChanged) _snapshot.invalidate();
    _last = effective;
    final owner = widget.controller;
    unawaited(() async {
      try {
        await owner.layout(effective);
        if (mounted && owner == widget.controller && viewportChanged) {
          _refreshSnapshot();
        }
      } catch (_) {
        // Native disposal/layout failure cannot revive old input or images.
      }
    }());
  }

  @override
  void didUpdateWidget(SystemWebView old) {
    super.didUpdateWidget(old);
    if (old.occlusion != widget.occlusion) {
      old.occlusion?.removeListener(_occlusionChanged);
      widget.occlusion?.addListener(_occlusionChanged);
    }
    if (old.controller != widget.controller) {
      unawaited(_events?.cancel());
      _snapshot.dispose();
      _bindSnapshots();
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
    widget.occlusion?.removeListener(_occlusionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _report(SystemWebViewLayout.hidden);
    unawaited(_events?.cancel());
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GeometryObserver(
    onLayout: _report,
    onViewportSize: _viewportMeasured,
    snapshotViewport: _imageViewport,
    isOccluded: widget.isOccluded,
    child: widget.visible && !widget.controller.closed
        ? RawImage(image: _snapshot.image, fit: BoxFit.fill) // ignore: raft_lints/avoid_raw_image_decode -- Private bounded native snapshot cache owns this image; no ImageProvider or shared ImageCache entry is created.
        : const SizedBox.shrink(),
  );
}

class _GeometryObserver extends SingleChildRenderObjectWidget {
  const _GeometryObserver({
    required this.onLayout,
    required this.onViewportSize,
    required this.snapshotViewport,
    this.isOccluded,
    required super.child,
  });
  final bool Function(Rect viewLogicalBounds)? isOccluded;
  final ValueChanged<SystemWebViewLayout> onLayout;
  final ValueChanged<Size> onViewportSize;
  final Size snapshotViewport;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GeometryBox(onLayout, onViewportSize, snapshotViewport, isOccluded);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _GeometryBox renderObject,
  ) {
    renderObject.onLayout = onLayout;
    renderObject.onViewportSize = onViewportSize;
    renderObject.snapshotViewport = snapshotViewport;
    renderObject.isOccluded = isOccluded;
    renderObject.markNeedsPaint();
  }
}

class _GeometryBox extends RenderProxyBox {
  _GeometryBox(
    this.onLayout,
    this.onViewportSize,
    this.snapshotViewport,
    this.isOccluded,
  );
  bool Function(Rect viewLogicalBounds)? isOccluded;
  ValueChanged<SystemWebViewLayout> onLayout;
  ValueChanged<Size> onViewportSize;
  Size snapshotViewport;
  bool _scheduled = false;
  @override
  bool get isRepaintBoundary => true;
  @override
  void performLayout() {
    size = constraints.biggest;
    child?.layout(BoxConstraints.tight(size));
  }

  @override
  void detach() {
    onLayout(SystemWebViewLayout.hidden);
    super.detach();
  }

  void report() {
    if (attached && hasSize) onViewportSize(size);
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
        if (parent is RenderClipRRect && parent.clipper == null) {
          final rounded = parent.borderRadius
              .resolve(parent.textDirection)
              .toRRect(Offset.zero & parent.size);
          final accepted = SystemWebViewLayout.roundedClipForFrame(
            frameInClip: MatrixUtils.transformRect(
              getTransformTo(parent),
              Offset.zero & size,
            ),
            clip: rounded,
            clipToView: parent.getTransformTo(root.child),
          );
          if (accepted == null) {
            onLayout(SystemWebViewLayout.hidden);
            return;
          }
          clips.add(accepted);
        } else if (parent is RenderClipRect) {
          clips.add(
            MatrixUtils.transformRect(parent.getTransformTo(root.child), clip),
          );
        } else {
          onLayout(SystemWebViewLayout.hidden);
          return;
        }
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
        isOccluded: isOccluded,
        scale:
            root.configuration.devicePixelRatio /
            root.flutterView.devicePixelRatio,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (snapshotViewport == size) super.paint(context, offset);
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      report();
    });
  }
}
