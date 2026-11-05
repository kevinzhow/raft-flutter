import 'dart:ui' show FlutterView;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The painted Flutter overlays that a native surface must yield to.
///
/// This is layout coordination, not a platform service. Each Flutter view owns
/// its own registry. Entries disappear with the actual overlay render object;
/// a tooltip in another part of the window does not hide unrelated content.
class RaftNativeSurfaceOcclusion extends ChangeNotifier {
  RaftNativeSurfaceOcclusion._();
  static final _views = Expando<RaftNativeSurfaceOcclusion>();
  static RaftNativeSurfaceOcclusion forView(BuildContext context) {
    final FlutterView view = View.of(context);
    return _views[view] ??= RaftNativeSurfaceOcclusion._();
  }

  final _bounds = <Object, Rect>{};
  bool _notificationQueued = false;

  /// Bounds use the view's global logical coordinate space, before GTK scaling.
  bool overlaps(Rect viewLogicalBounds) =>
      !viewLogicalBounds.isEmpty &&
      _bounds.values.any((bounds) => bounds.overlaps(viewLogicalBounds));

  void _replace(Object token, Rect? bounds) {
    if (_bounds[token] == bounds) return;
    if (bounds == null || bounds.isEmpty) {
      if (_bounds.remove(token) == null) return;
    } else {
      _bounds[token] = bounds;
    }
    if (_notificationQueued) return;
    _notificationQueued = true;
    // A render object can retire during build/layout. Notify after that frame,
    // so listeners can request painting without rebuilding during traversal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationQueued = false;
      notifyListeners();
    });
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One frame after an overlay changes; the callback does not request another frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

/// Paint observer for canonical overlay content. Adds no layout, pixels,
/// semantics or input behavior. Put it around the popup, not its full viewport.
class RaftNativeSurfaceOccluder extends SingleChildRenderObjectWidget {
  const RaftNativeSurfaceOccluder({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _OccluderBox(
    RaftNativeSurfaceOcclusion.forView(context),
    TickerMode.valuesOf(context).enabled,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _OccluderBox renderObject,
  ) => renderObject.configure(
    RaftNativeSurfaceOcclusion.forView(context),
    TickerMode.valuesOf(context).enabled,
  );
}

class _OccluderBox extends RenderProxyBox {
  _OccluderBox(this._registry, this._active);
  RaftNativeSurfaceOcclusion _registry;
  bool _active;
  final Object _token = Object();
  bool _queued = false;

  void configure(RaftNativeSurfaceOcclusion registry, bool active) {
    if (registry != _registry) {
      _registry._replace(_token, null);
      _registry = registry;
    }
    _active = active;
    if (!active) _registry._replace(_token, null);
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
    _registry._replace(_token, bounds.isFinite ? bounds : null);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }
}
