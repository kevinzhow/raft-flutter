import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'settings_layout.dart' show RaftSpace;
import 'system_inset.dart';
import 'theme.dart';

// RaftSheet: the design system's bottom sheet. One look on every platform: the
// raft_ui panel color, a token-sized top corner (square in brutal, with its 2px
// black frame), our own drag handle and the shared scrim. The gestures come
// from the framework's modal bottom sheet route and DraggableScrollableSheet
// (see `RaftPresentedRoute`), so the physics are the platform-standard ones:
//
//  * Material 3 bottom sheets: a drag handle, a tap on the scrim or a swipe
//    down dismisses, a 640 dp maximum width on wide windows, the sheet sits
//    above the keyboard.
//  * Apple HIG sheets: a grabber, detents (a medium one and a large one), swipe
//    down to dismiss, content that scrolls without closing the sheet and
//    closes it only when pulled down from the top.
//
// Nothing outside raft_ui opens a framework bottom sheet: callers open a
// RaftPresentationPolicy window and build the sheet's content with
// [RaftSheet] (a scrolling body between a pinned header and footer) or
// [RaftSheet.fixed] (one child that manages its own scrolling).

/// Sheet geometry shared by the route and the content.
abstract final class RaftSheetMetrics {
  /// Material 3: a sheet never grows wider than this on a large window.
  static const maxWidth = 640.0;

  /// The large detent: the most of the window height a sheet takes.
  static const largeDetent = .9;

  /// The medium detent a content-light sheet starts at.
  static const mediumDetent = .6;

  /// The handle's hit area, its mark and the gap that keeps it clear of the
  /// content.
  static const handleArea = RaftSpace.x5 + RaftSpace.x1;
  static const handleWidth = 36.0, handleHeight = RaftSpace.x1;

  static double topRadius(RaftTokens t) => RaftSpace.x4;

  /// The sheet's surface: panel color, rounded (elegant) or square (brutal)
  /// top corners and the frame line.
  static ShapeBorder shape(RaftTokens t) => RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius(t))),
    side: BorderSide(color: t.colors['line-muted']!, width: 1),
  );
}

/// The sheet's surface, for drawing a sheet without a route (previews):
/// bottom-aligned, panel colored, with the sheet's top corners and frame.
class RaftSheetSurface extends StatelessWidget {
  const RaftSheetSurface({super.key, required this.child, this.height});
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: RaftSheetMetrics.maxWidth),
        child: SizedBox(
          height: height,
          child: Material(
            color: t.panel,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RaftSheetMetrics.shape(t),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// What the route tells the content: the scroll controller of the sheet's
/// draggable detents (null for a fixed sheet).
class RaftSheetScope extends InheritedWidget {
  const RaftSheetScope({
    super.key,
    required this.scrollController,
    this.pointerDrag,
    required super.child,
  });
  final ScrollController? scrollController;

  /// Moves the sheet for a drag on the handle or the header, which the scroll
  /// view cannot be trusted with: it ignores a mouse on desktop, and turns a
  /// finger into scrolling once the body is scrolled. Null when the sheet
  /// moves another way.
  final RaftSheetPointerDrag? pointerDrag;

  static RaftSheetScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftSheetScope>();

  @override
  bool updateShouldNotify(RaftSheetScope oldWidget) =>
      scrollController != oldWidget.scrollController ||
      pointerDrag != oldWidget.pointerDrag;
}

/// A drag on the handle or the header, in logical pixels down the screen.
abstract interface class RaftSheetPointerDrag {
  void update(double dy);
  void end(double velocityDy);
}

/// The handle and the header move the sheet with any pointer, whatever the
/// body's scroll offset.
class _PointerDragArea extends StatelessWidget {
  const _PointerDragArea({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final drag = RaftSheetScope.maybeOf(context)?.pointerDrag;
    if (drag == null) return child;
    return GestureDetector(
      // Every device: the handle sits in the body's scroll view, and once
      // the body is scrolled a finger there would scroll the text instead.
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (d) => drag.update(d.delta.dy),
      onVerticalDragEnd: (d) => drag.end(d.velocity.pixelsPerSecond.dy),
      child: RaftHoverRegion(cursor: SystemMouseCursors.grab, child: child),
    );
  }
}

/// The drag handle: the same mark in every theme (brutal black, elegant a
/// placeholder-tinted pill), in a hit area tall enough for a thumb.
class RaftSheetHandle extends StatelessWidget {
  const RaftSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return SizedBox(
      height: RaftSheetMetrics.handleArea,
      child: Center(
        child: SizedBox(
          key: const ValueKey('raft-sheet-handle'),
          width: RaftSheetMetrics.handleWidth,
          height: RaftSheetMetrics.handleHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.colors['foreground-placeholder']!.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(
                RaftSheetMetrics.handleHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet's content: the handle, a pinned [header], one scrolling
/// [body] and a pinned [footer]. The body scrolls when it is taller than the
/// sheet; the header and the footer stay in place. Dragging the handle, the
/// header or the body (from its top) moves the sheet: scrolling elsewhere in
/// the body never closes it.
///
/// A sheet whose content manages its own scrolling (an editor) uses
/// [RaftSheet.fixed] instead.
class RaftSheet extends StatelessWidget {
  const RaftSheet({
    super.key,
    required this.body,
    this.header,
    this.headerExtent = 0,
    this.footer,
    this.padding = EdgeInsets.zero,
  }) : assert(header == null || headerExtent > 0, 'a header needs its height'),
       fixed = null;

  /// One child under the handle, given all the remaining height. It must
  /// scroll itself if it can overflow.
  const RaftSheet.fixed({super.key, required Widget child})
    : fixed = child,
      body = const SizedBox.shrink(),
      header = null,
      headerExtent = 0,
      footer = null,
      padding = EdgeInsets.zero;

  final Widget body;

  /// Pinned under the handle; drags the sheet. [headerExtent] is its height.
  final Widget? header, footer;
  final double headerExtent;
  final EdgeInsetsGeometry padding;
  final Widget? fixed;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : raftBottomInset(context);
    final fixed = this.fixed;
    if (fixed != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftSheetHandle(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: fixed,
            ),
          ),
        ],
      );
    }
    final controller = RaftSheetScope.maybeOf(context)?.scrollController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedHeader(
                  extent: RaftSheetMetrics.handleArea + headerExtent,
                  color: RaftTokens.of(context).panel,
                  child: _PointerDragArea(
                    child: Column(
                      children: [
                        const RaftSheetHandle(),
                        if (header != null)
                          SizedBox(height: headerExtent, child: header),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(padding: padding, child: body),
              ),
            ],
          ),
        ),
        ?footer,
        SizedBox(height: footer == null ? 0 : bottom),
      ],
    );
  }
}

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  const _PinnedHeader({
    required this.extent,
    required this.color,
    required this.child,
  });
  final double extent;
  final Color color;
  final Widget child;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: color, child: child);

  @override
  bool shouldRebuild(_PinnedHeader old) =>
      extent != old.extent || color != old.color || child != old.child;
}
