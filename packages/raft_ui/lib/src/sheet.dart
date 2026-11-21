import 'dart:math' as math;

import 'hover_region.dart';

import 'package:flutter/material.dart';
// `closeButton` is a Raft-only drawer slot, so the router leaves it out.
import 'package:raft_theme/recipes/drawer.g.dart' as raft_drawer;

import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftSnappedDecoratedBox;
import 'raft/button.dart' show RaftButton;
import 'raft/css_box.dart' show RaftBorderSnap;
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/drawer.g.dart';
import 'recipes/recipe_runtime.dart'
    show CssNum, RaftShadowLayers, RaftSlotStyle;
import 'settings_layout.dart' show RaftSpace;
import 'surface_background_scope.dart';
import 'system_inset.dart';
import 'theme.dart';

// RaftSheet: the design system's bottom sheet. One look on every platform: the
// raft_ui popover color, a token-sized top corner, our own drag handle and the shared scrim. The gestures come
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
  /// content (the fallback when the drawer recipe has no handle height; the
  /// Raft look reads [handleBox]).
  static const handleArea = RaftSpace.x5 + RaftSpace.x1;
  static const handleWidth = 36.0, handleHeight = RaftSpace.x1;

  /// A drag target is never smaller than this: the Raft handle box is 16px
  /// tall, so the pinned header that holds it grows to this.
  static const minDragTarget = 44.0;

  /// The raft-ui Drawer popup (`side=down`): `layer-popover` fill,
  /// `ring-1 ring-line-seam`, `shadow-float`, `rounded-t-dialog`.
  static RaftSlotStyle _popup(RaftTokens t) => RaftDrawerRecipe.resolve(
    side: RaftDrawerRecipeSide.down,
    axis: RaftDrawerRecipeAxis.y,
    states: t.recipeStates(),
    tokens: t.recipeTokens,
  ).popup;

  static RaftSlotStyle _swipeHandle(RaftTokens t) => RaftDrawerRecipe.resolve(
    side: RaftDrawerRecipeSide.down,
    axis: RaftDrawerRecipeAxis.y,
    states: t.recipeStates(),
    tokens: t.recipeTokens,
  ).swipeHandle;

  /// The sheet's fill.
  static Color fill(RaftTokens t) =>
      _popup(t).backgroundColor?.resolve(t.recipeTokens) ??
      t.colors['layer-popover']!;

  static double snapOverlayOpacity(RaftTokens t) {
    final overlay = RaftDrawerRecipe.resolve(
      side: RaftDrawerRecipeSide.down,
      axis: RaftDrawerRecipeAxis.y,
      snapPoints: true,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).overlay;
    return switch (overlay['--drawer-overlay-min-opacity']) {
      CssNum(:final value) => value,
      _ => 0,
    };
  }

  /// The outer shadows: the ring and float shadow.
  static List<BoxShadow> shadows(RaftTokens t) =>
      _popup(t).boxShadow.toBoxShadows(t.recipeTokens);

  static double topRadius(RaftTokens t) =>
      _popup(t).borderRadius?.topLeft.x ?? RaftSpace.x4;

  /// The handle box: 16px tall (`swipeHandle` slot).
  static double handleBox(RaftTokens t) => _swipeHandle(t).height ?? handleArea;

  /// Where the mark starts inside [handleBox] (`::before` `top-1.5`); null
  /// centres it.
  static double? handleMarkTop(RaftTokens t) =>
      _swipeHandle(t).before?.length('top');

  /// The mark's color: `line-seam`.
  static Color handleColor(RaftTokens t) => t.colors['line-seam']!;

  /// The sheet's surface: rounded top corners; the ring is part of
  /// [shadows].
  static ShapeBorder shape(RaftTokens t) => RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius(t))),
    side: BorderSide.none,
  );
}

/// The sheet's own surface inside a route that paints none: fill, rounded top
/// and (Raft look) the ring and float shadow.
class RaftSheetPanel extends StatelessWidget {
  const RaftSheetPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final shadows = RaftSheetMetrics.shadows(t);
    final fill = RaftSheetMetrics.fill(t);
    final surface = Material(
      color: fill,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RaftSheetMetrics.shape(t),
      child: RaftSurfaceBackgroundScope(
        color: fill.a == 1 ? fill : null,
        child: child,
      ),
    );
    if (shadows.isEmpty) return surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RaftSheetMetrics.topRadius(t)),
        ),
        boxShadow: shadows,
      ),
      child: surface,
    );
  }
}

/// The sheet's surface, for drawing a sheet without a route (previews):
/// bottom-aligned, panel colored, with the sheet's top corners and frame.
class RaftSheetSurface extends StatelessWidget {
  const RaftSheetSurface({super.key, required this.child, this.height});
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: RaftSheetMetrics.maxWidth),
      child: SizedBox(
        height: height,
        child: RaftSheetPanel(child: child),
      ),
    ),
  );
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

/// The drag handle: a `line-seam` pill in a hit area tall enough for a thumb.
class RaftSheetHandle extends StatelessWidget {
  const RaftSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final markTop = RaftSheetMetrics.handleMarkTop(t);
    final mark = SizedBox(
      key: const ValueKey('raft-sheet-handle'),
      width: RaftSheetMetrics.handleWidth,
      height: RaftSheetMetrics.handleHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: RaftSheetMetrics.handleColor(t),
          borderRadius: BorderRadius.circular(RaftSheetMetrics.handleHeight),
        ),
      ),
    );
    return SizedBox(
      height: RaftSheetMetrics.handleBox(t),
      child: markTop == null
          ? Center(child: mark)
          : Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: markTop),
                child: mark,
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
/// raft-ui `DrawerClose` (drawer.mjs:110-131): a ghost `icon-lg` Button sized
/// by the drawer `closeButton` slot (`size-(--bar-button-size)`, 44 at radius
/// 10; 28 at radius 6 with a mouse from 768) with an `X` from the `closeIcon`
/// slot (`size-control-icon`: 22, or 18). The caller places it; Web's
/// select-text drawer puts it on the title row.
class RaftSheetClose extends StatelessWidget {
  const RaftSheetClose({
    super.key,
    required this.onPressed,
    this.tooltip = 'Close',
  });
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final slots = raft_drawer.RaftDrawerRecipe.resolve(
      side: raft_drawer.RaftDrawerRecipeSide.down,
      axis: raft_drawer.RaftDrawerRecipeAxis.y,
      states: t.recipeStates(responsive: true),
      tokens: t.recipeTokens,
    );
    final box = slots.closeButton.width ?? 44;
    final radius = slots.closeButton.borderRadius?.topLeft.x ?? 10;
    final icon = slots.closeIcon.width ?? 22;
    return RaftButton(
      tone: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.iconLg,
      glyph: RaftGlyph.x,
      iconBuilder: (_, color) =>
          RaftIcon(RaftGlyph.x, size: icon, color: color),
      semanticLabel: raftText(context, tooltip),
      onPressed: onPressed,
      physicalHeight: box,
      visualWidth: box,
      styleBuilder: (context, state, style) => style.copyWith(
        properties: {
          ...style.properties,
          for (final corner in [
            'top-left',
            'top-right',
            'bottom-left',
            'bottom-right',
          ])
            'border-$corner-radius': CssNum(radius, 'px'),
        },
      ),
    );
  }
}

class RaftSheet extends StatelessWidget {
  const RaftSheet({
    super.key,
    required this.body,
    this.header,
    this.headerExtent = 0,
    this.headerColor,
    this.footer,
    this.padding = EdgeInsets.zero,
    this.showHandle = true,
  }) : assert(header == null || headerExtent > 0, 'a header needs its height'),
       fixed = null;

  /// One child under the handle, given all the remaining height. It must
  /// scroll itself if it can overflow.
  const RaftSheet.fixed({super.key, required Widget child})
    : fixed = child,
      body = const SizedBox.shrink(),
      header = null,
      headerExtent = 0,
      headerColor = null,
      footer = null,
      showHandle = true,
      padding = EdgeInsets.zero;

  final Widget body;

  /// Pinned under the handle; drags the sheet. [headerExtent] is its height.
  final Widget? header, footer;
  final double headerExtent;
  final Color? headerColor;
  final bool showHandle;
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
          const _PointerDragArea(child: RaftSheetHandle()),
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
    final t = RaftTokens.of(context);
    final headFill = headerColor ?? t.canvas;
    final headerSlot = header == null
        ? null
        : SizedBox(height: headerExtent, child: header);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keep the dialog's actions in the box layout. Revealing a focused
        // field can change a pinned sliver's hit region even while it paints
        // in the same place.
        if (!showHandle && headerSlot != null)
          _PointerDragArea(
            child: RaftSnappedDecoratedBox(
              // PanelHeader snaps its canvas edge and bottom border to the
              // same paint grid while its controls keep their layout boxes.
              decoration: BoxDecoration(color: headFill),
              paintDevicePixelRatio: RaftBorderSnap.emulatedDeviceScaleFactor
                  ? 1
                  : null,
              child: RaftSurfaceBackgroundScope(
                color: headFill.a == 1 ? headFill : null,
                child: headerSlot,
              ),
            ),
          ),
        Expanded(
          child: CustomScrollView(
            controller: controller,
            slivers: [
              if (showHandle)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedHeader(
                    extent: math.max(
                      RaftSheetMetrics.handleBox(t) + headerExtent,
                      RaftSheetMetrics.minDragTarget,
                    ),
                    color: RaftSheetMetrics.fill(t),
                    child: _PointerDragArea(
                      child: Column(
                        children: [const RaftSheetHandle(), ?headerSlot],
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
