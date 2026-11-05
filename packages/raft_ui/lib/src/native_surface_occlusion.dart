import 'dart:ui' show FlutterView;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The painted Flutter overlays that a native surface must yield to.
///
/// This is layout coordination, not a platform service. Each Flutter view owns
/// its own registry. Entries disappear with the actual overlay render object;
/// a tooltip in another part of the window does not hide unrelated content.
class RaftNativeSurfaceOcclusion implements Listenable {
  RaftNativeSurfaceOcclusion._();
  static final _views = Expando<RaftNativeSurfaceOcclusion>();
  static RaftNativeSurfaceOcclusion forView(BuildContext context) {
    final FlutterView view = View.of(context);
    return _views[view] ??= RaftNativeSurfaceOcclusion._();
  }

  // This view-keyed value has no resource or disposable lifetime. Subscribers
  // own their listeners; ephemeral overlays own their bounds until detach.
  final _listeners = <VoidCallback>{};
  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      if (!_listeners.contains(listener)) continue;
      try {
        listener();
      } catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'Raft native surface visibility',
          ),
        );
      }
    }
  }

  final _entries = <Object, ({Rect bounds, bool blocksInput})>{};
  bool _notificationQueued = false;

  /// Bounds use the view's global logical coordinate space, before GTK scaling.
  bool overlaps(Rect viewLogicalBounds) =>
      !viewLogicalBounds.isEmpty &&
      _entries.values.any((entry) => entry.bounds.overlaps(viewLogicalBounds));

  /// Whether an interactive overlay occupies the native surface's input area.
  /// Passive painted overlays still participate in [overlaps].
  bool blocksInput(Rect viewLogicalBounds) =>
      !viewLogicalBounds.isEmpty &&
      _entries.values.any(
        (entry) =>
            entry.blocksInput && entry.bounds.overlaps(viewLogicalBounds),
      );

  void _setBlocksInput(Object token, bool blocksInput) {
    final entry = _entries[token];
    if (entry != null) {
      _replace(token, entry.bounds, blocksInput: blocksInput);
    }
  }

  void _replace(Object token, Rect? bounds, {bool blocksInput = true}) {
    final entry = bounds == null || bounds.isEmpty
        ? null
        : (bounds: bounds, blocksInput: blocksInput);
    if (_entries[token] == entry) return;
    if (entry == null) {
      _entries.remove(token);
    } else {
      _entries[token] = entry;
    }
    if (_notificationQueued) return;
    _notificationQueued = true;
    // A render object can retire during build/layout. Notify after that frame,
    // so listeners can request painting without rebuilding during traversal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationQueued = false;
      _notify();
    });
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One frame after an overlay changes; the callback does not request another frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

/// Paint observer for canonical overlay content. Adds no layout, pixels,
/// semantics or input behavior. Put it around the popup, not its full viewport.
class RaftNativeSurfaceOccluder extends SingleChildRenderObjectWidget {
  const RaftNativeSurfaceOccluder({
    super.key,
    required super.child,
    this.blocksInput = true,
  });

  /// Whether the painted content also blocks native pointer input. This only
  /// describes the child's existing behavior; it does not intercept input.
  final bool blocksInput;

  @override
  RenderObject createRenderObject(BuildContext context) => _OccluderBox(
    RaftNativeSurfaceOcclusion.forView(context),
    TickerMode.valuesOf(context).enabled,
    blocksInput,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _OccluderBox renderObject,
  ) => renderObject.configure(
    RaftNativeSurfaceOcclusion.forView(context),
    TickerMode.valuesOf(context).enabled,
    blocksInput,
  );
}

class _OccluderBox extends RenderProxyBox {
  _OccluderBox(this._registry, this._active, this._blocksInput);
  RaftNativeSurfaceOcclusion _registry;
  bool _active, _blocksInput;
  final Object _token = Object();
  bool _queued = false;

  void configure(
    RaftNativeSurfaceOcclusion registry,
    bool active,
    bool blocksInput,
  ) {
    if (registry != _registry) {
      _registry._replace(_token, null);
      _registry = registry;
    }
    _active = active;
    _blocksInput = blocksInput;
    if (!active) {
      _registry._replace(_token, null);
    } else {
      _registry._setBlocksInput(_token, blocksInput);
    }
    markNeedsPaint();
  }

  @override
  void detach() {
    _registry._replace(_token, null);
    super.detach();
  }

  void _report() {
    _queued = false;
    if (!attached || !_active || !hasSize || size.isEmpty) {
      _registry._replace(_token, null);
      return;
    }
    Rect bounds = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    RenderObject child = this;
    RenderObject? parent = this.parent;
    while (parent != null) {
      if (!parent.paintsChild(child)) {
        _registry._replace(_token, null);
        return;
      }
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        bounds = bounds.intersect(
          MatrixUtils.transformRect(parent.getTransformTo(null), clip),
        );
      }
      child = parent;
      parent = parent.parent;
    }
    _registry._replace(
      _token,
      bounds.isFinite ? bounds : null,
      blocksInput: _blocksInput,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }
}
