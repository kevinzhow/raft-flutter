// Large Content Viewer (Apple's UILargeContentViewerInteraction).
//
// Fixed chrome stops growing at RaftTextScaling.chromeMaxScale, so at large
// text sizes its labels are smaller than the user asked for. While the bound is
// engaged, pressing and holding such an item shows its icon and label large in
// the middle of the screen; sliding the finger over a sibling item in the same
// RaftLargeContentScope shows that sibling; lifting the finger on an item
// activates it. A normal tap still activates the item directly.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'text_scaling.dart';
import 'theme.dart' show RaftTokens;

/// Groups the items of one bar (tab bar, channel tabs) so the viewer follows
/// the finger from one item to the next.
class RaftLargeContentScope extends StatefulWidget {
  const RaftLargeContentScope({super.key, required this.child});

  final Widget child;

  @override
  State<RaftLargeContentScope> createState() => _RaftLargeContentScopeState();
}

class _RaftLargeContentScopeState extends State<RaftLargeContentScope> {
  final _controller = _ViewerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ScopeData(controller: _controller, child: widget.child);
}

class _ScopeData extends InheritedWidget {
  const _ScopeData({required this.controller, required super.child});

  final _ViewerController controller;

  @override
  bool updateShouldNotify(_ScopeData old) => old.controller != controller;
}

/// One fixed-chrome item that offers the Large Content Viewer.
///
/// Wrap the item (the widget that handles taps) in this. [onActivate] runs
/// when the finger is lifted on the item after a long press; give it the same
/// action as the item's tap. The press only starts while an enclosing
/// [RaftChrome] is bounding the text scale, so at normal sizes the item behaves
/// exactly as before.
class RaftLargeContentViewer extends StatefulWidget {
  const RaftLargeContentViewer({
    super.key,
    required this.label,
    required this.child,
    this.iconBuilder,
    this.onActivate,
    this.enabled = true,
  });

  /// The text shown large (and read by screen readers).
  final String label;

  /// Builds the icon at [size] logical pixels; null shows the label only.
  final Widget Function(BuildContext context, double size)? iconBuilder;

  /// Called when the finger is lifted on this item after the viewer opened.
  final VoidCallback? onActivate;

  final bool enabled;
  final Widget child;

  @override
  State<RaftLargeContentViewer> createState() => _RaftLargeContentViewerState();
}

class _RaftLargeContentViewerState extends State<RaftLargeContentViewer> {
  _ViewerController? _own;
  _ViewerController? _registered;

  _ViewerController get _controller {
    final scope = context.getInheritedWidgetOfExactType<_ScopeData>();
    return scope?.controller ?? (_own ??= _ViewerController());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = _controller;
    if (!identical(controller, _registered)) {
      _registered?.items.remove(this);
      controller.items.add(this);
      _registered = controller;
    }
  }

  @override
  void dispose() {
    final controller = _registered;
    if (controller != null) {
      controller.items.remove(this);
      if (controller.shown == this) controller.hide();
    }
    _own?.dispose();
    super.dispose();
  }

  Rect? get _globalRect {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _show(_RaftLargeContentViewerState item) {
    final controller = _registered!;
    controller.show(context, item);
  }

  void _start(LongPressStartDetails details) {
    HapticFeedback.selectionClick();
    _show(this);
  }

  void _move(LongPressMoveUpdateDetails details) {
    final controller = _registered!;
    final hit = controller.itemAt(details.globalPosition);
    if (hit != null && !identical(controller.shown, hit)) {
      HapticFeedback.selectionClick();
      _show(hit);
    }
  }

  void _end(LongPressEndDetails details) {
    final controller = _registered!;
    final hit = controller.itemAt(details.globalPosition);
    controller.hide();
    if (hit != null && hit.mounted) hit.widget.onActivate?.call();
  }

  void _cancel() => _registered?.hide();

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && RaftChrome.engagedOf(context);
    return _ForwardOutsideHits(
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: active
            ? <Type, GestureRecognizerFactory>{
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(),
                      (r) => r
                        ..onLongPressStart = _start
                        ..onLongPressMoveUpdate = _move
                        ..onLongPressEnd = _end
                        ..onLongPressCancel = _cancel,
                    ),
              }
            : const <Type, GestureRecognizerFactory>{},
        child: widget.child,
      ),
    );
  }
}

/// Lets a touch target that extends beyond the item's box (the 48dp expander
/// inside Raft controls) keep working through the viewer's gesture detector:
/// hits up to the touch-target size around the item are forwarded to the
/// child at the nearest point inside it.
class _ForwardOutsideHits extends SingleChildRenderObjectWidget {
  const _ForwardOutsideHits({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderForwardOutsideHits();
}

class _RenderForwardOutsideHits extends RenderProxyBox {
  static const _minTarget = 48.0;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final w = size.width < _minTarget ? _minTarget : size.width;
    final h = size.height < _minTarget ? _minTarget : size.height;
    final target = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: w,
      height: h,
    );
    if (!target.contains(position)) return false;
    final clamped = Offset(
      position.dx.clamp(0, size.width - 0.01).toDouble(),
      position.dy.clamp(0, size.height - 0.01).toDouble(),
    );
    if (hitTestChildren(result, position: clamped) || hitTestSelf(clamped)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// What the viewer shows.
@immutable
class _Shown {
  const _Shown(this.item, this.label, this.icon, this.content);
  final _RaftLargeContentViewerState item;
  final String label;
  final Widget Function(BuildContext, double)? icon;
  final TextScaler content;
}

/// The items of a bar and the one overlay they share.
class _ViewerController {
  final Set<_RaftLargeContentViewerState> items = {};
  final ValueNotifier<_Shown?> _shown = ValueNotifier<_Shown?>(null);
  OverlayEntry? _entry;

  _RaftLargeContentViewerState? get shown => _shown.value?.item;

  _RaftLargeContentViewerState? itemAt(Offset global) {
    for (final item in items) {
      if (!item.mounted) continue;
      final rect = item._globalRect;
      if (rect != null && rect.contains(global)) return item;
    }
    return null;
  }

  void show(BuildContext context, _RaftLargeContentViewerState item) {
    _shown.value = _Shown(
      item,
      item.widget.label,
      item.widget.iconBuilder,
      RaftChrome.contentScalerOf(item.context),
    );
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (context) => _ViewerOverlay(shown: _shown),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  void hide() {
    _shown.value = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void dispose() {
    hide();
    _shown.dispose();
  }
}

class _ViewerOverlay extends StatelessWidget {
  const _ViewerOverlay({required this.shown});

  final ValueListenable<_Shown?> shown;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_Shown?>(
      valueListenable: shown,
      builder: (context, value, _) {
        if (value == null) return const SizedBox.shrink();
        final tokens = RaftTokens.of(context);
        final media = MediaQuery.of(context);
        final text =
            Theme.of(context).textTheme.titleLarge ?? const TextStyle();
        return Positioned.fill(
          child: IgnorePointer(
            child: Semantics(
              container: true,
              liveRegion: true,
              label: value.label,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16) + media.padding,
                  child: DecoratedBox(
                    key: const Key('raft-large-content-viewer'),
                    decoration: BoxDecoration(
                      color: tokens.popover,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: media.size.width - 32 - 56,
                        ),
                        child: MediaQuery(
                          data: media.copyWith(textScaler: value.content),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (value.icon != null) ...[
                                IconTheme(
                                  data: IconThemeData(
                                    color: tokens.ink,
                                    size: 72,
                                  ),
                                  child: value.icon!(context, 72),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Text(
                                value.label,
                                textAlign: TextAlign.center,
                                style: text.copyWith(
                                  color: tokens.ink,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
