import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'css_pixel_snap.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'interaction.dart';
import 'localization.dart';
import 'kbd.dart';
import 'recipe_surface.dart';
import 'recipes/search_trigger.g.dart';
import 'shortcut_platform.dart';
import 'space.dart';
import 'status_bar.dart';
import 'tap_slop.dart';
import 'text_scaling.dart';
import 'theme.dart';
import 'tokens/raft_tokens.g.dart' show RaftDesktopMetrics, RaftLight;

/// Global workspace actions occupy wide native desktop windows as well as
/// browser/tablet layouts whose theme includes the workspace bar.
bool raftShowsWorkspaceTopBar({
  required RaftTokens tokens,
  required double width,
  required bool nativeWindowChrome,
}) =>
    width >= RaftLayoutMetrics.desktopBreakpoint &&
    (nativeWindowChrome ||
        tokens.option('shell.browserTopBar', or: 'hidden') == 'shown');

/// The workspace frame row. The two side regions have equal widths, so
/// the search trigger remains centred on the window while workspace names vary.
class RaftWorkspaceTopBar extends StatelessWidget {
  static double heightFor(RaftTokens tokens) => tokens.desktop ? 44 : 48;

  const RaftWorkspaceTopBar({
    super.key,
    required this.workspace,
    required this.onSearch,
    this.trailing = const [],
    this.searchKey,
    this.leadingInset = 0,
    this.trailingInset = 0,
    this.navigation,
    this.onDragStart,
    this.onDoubleTap,
    this.preserveTextFieldFocusOnDrag = false,
  });
  final Widget workspace;
  final VoidCallback onSearch;
  final List<Widget> trailing;
  final double leadingInset, trailingInset;
  final Widget? navigation;
  final VoidCallback? onDragStart, onDoubleTap;
  final bool preserveTextFieldFocusOnDrag;

  /// Lets the host publish the real search field bounds to its overlay.
  final Key? searchKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final leadingPadding = t.desktop && leadingInset == 0
        ? (RaftDesktopMetrics.railWidth - 1 - RaftDesktopMetrics.railItem) / 2 +
              1
        : 8.0 + leadingInset;
    // The trailing frame glyph ends 20px from the window edge in AppTopBar.
    final trailingPadding = t.desktop
        ? 20 - (RaftLight.frameItemHeight - 20) / 2 + trailingInset
        : 8 + trailingInset;
    final border = Border(
      bottom: BorderSide(color: t.colors['line-workspace-rail']!),
    );
    final borderInset = border.bottom.strokeInset;
    final drag = RaftTapSlopBackground(
      child: GestureDetector(
        key: const Key('workspace-topbar-drag'),
        behavior: HitTestBehavior.opaque,
        onPanStart: onDragStart == null ? null : (_) => onDragStart!(),
        onDoubleTap: onDoubleTap,
        child: const SizedBox.expand(),
      ),
    );
    return RaftChrome(
      child: RaftTapSlopHost(
        child: RaftStatusBarSource(
          color: t.colors['layer-workspace-rail']!,
          child: Container(
            height: heightFor(t),
            color: t.colors['layer-workspace-rail'],
            foregroundDecoration: BoxDecoration(border: border),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  // AppKit routes the painted border as part of the Mac title bar.
                  bottom: preserveTextFieldFocusOnDrag ? 0 : borderInset,
                  child: preserveTextFieldFocusOnDrag
                      ? TextFieldTapRegion(child: drag)
                      : drag,
                ),
                Positioned.fill(
                  bottom: borderInset,
                  child: CustomMultiChildLayout(
                    delegate: _WorkspaceTopBarLayout(
                      elasticSearch: t.desktop,
                      leadingPadding: leadingPadding,
                    ),
                    children: [
                      LayoutId(id: _TopBarSlot.leading, child: workspace),
                      if (navigation case final navigation?)
                        LayoutId(id: _TopBarSlot.navigation, child: navigation),
                      LayoutId(
                        id: _TopBarSlot.search,
                        child: RaftWorkspaceSearchTrigger(
                          key: searchKey,
                          onPressed: onSearch,
                        ),
                      ),
                      LayoutId(
                        id: _TopBarSlot.trailing,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 8,
                            right: trailingPadding,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: trailing,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TopBarSlot { leading, navigation, search, trailing }

/// Keep search centred, allowing its width to shrink when window controls and
/// working agents need more space. No fixed estimate of a translated label's width.
class _WorkspaceTopBarLayout extends MultiChildLayoutDelegate {
  _WorkspaceTopBarLayout({
    required this.elasticSearch,
    required this.leadingPadding,
  });

  /// The inner edge of either action region is 8px from the search field.
  static const double _innerGap = RaftSpace.x2;
  static const double _searchMaxWidth = 520;

  final bool elasticSearch;
  final double leadingPadding;

  @override
  void performLayout(Size size) {
    final right = layoutChild(_TopBarSlot.trailing, BoxConstraints.loose(size));
    final hasNavigation = hasChild(_TopBarSlot.navigation);
    final nav = hasNavigation
        ? layoutChild(_TopBarSlot.navigation, BoxConstraints.loose(size))
        : Size.zero;
    final searchBase = (size.width * .32).clamp(
      math.min(360.0, size.width),
      _searchMaxWidth,
    );
    final baseSide = math
        .max((size.width - searchBase) / 2, right.width)
        .clamp(0.0, size.width / 2);
    final navigationGap = elasticSearch && hasNavigation ? _innerGap : 0.0;
    final leadingInsets =
        leadingPadding + nav.width + _innerGap + navigationGap;
    // Lay out the switcher at the base field width, so search growth cannot
    // reduce the number of avatars it chooses to show.
    final workspaceWidth = math.max(0.0, baseSide - leadingInsets);
    final left = layoutChild(
      _TopBarSlot.leading,
      BoxConstraints(
        minWidth: elasticSearch ? 0 : workspaceWidth,
        maxWidth: workspaceWidth,
        maxHeight: size.height,
      ),
    );
    final leadingDemand = leadingInsets + left.width;
    final remaining = baseSide - math.max(leadingDemand, right.width);
    final growth = elasticSearch
        ? math.max(
            0.0,
            math.min(
              remaining.floorToDouble(),
              (_searchMaxWidth - searchBase) / 2,
            ),
          )
        : 0.0;
    final side = baseSide - growth;
    final search = layoutChild(
      _TopBarSlot.search,
      BoxConstraints(
        minWidth: size.width - 2 * side,
        maxWidth: size.width - 2 * side,
        maxHeight: size.height,
      ),
    );
    positionChild(
      _TopBarSlot.leading,
      Offset(leadingPadding, (size.height - left.height) / 2),
    );
    if (hasNavigation) {
      positionChild(
        _TopBarSlot.navigation,
        Offset(side - _innerGap - nav.width, (size.height - nav.height) / 2),
      );
    }
    positionChild(
      _TopBarSlot.search,
      Offset(side, (size.height - search.height) / 2),
    );
    positionChild(
      _TopBarSlot.trailing,
      Offset(size.width - right.width, (size.height - right.height) / 2),
    );
  }

  @override
  bool shouldRelayout(_WorkspaceTopBarLayout old) =>
      elasticSearch != old.elasticSearch ||
      leadingPadding != old.leadingPadding;
}

/// SearchTrigger is a button drawn as a field; opening it uses the application's
/// existing global-search controller rather than a second editable search.
class RaftWorkspaceSearchTrigger extends StatelessWidget {
  const RaftWorkspaceSearchTrigger({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final control = RaftInteractive(
      key: const Key('topbar-search'),
      semanticLabel: raftText(context, 'Search'),
      onPressed: onPressed,
      builder: (context, state) {
        final rt = t.recipeTokens;
        final slots = RaftSearchTriggerRecipe.resolve(
          tokens: rt,
          states: t.recipeStates(
            responsive: true,
            hovered: state.hovered,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
          ),
        );
        final glyph = slots.root.target("& > svg:not([class*='size-'])")!;
        final face = RaftRecipeBox(
          style: slots.root.withCssUsedBorderWidths(),
          tokens: rt,
          height: t.desktop ? RaftDesktopMetrics.frameItemHeight : null,
          controlLabel: true,
          child: Row(
            spacing: slots.root.columnGap ?? 0,
            children: [
              RaftIcon(RaftGlyph.search, size: glyph.width!),
              Expanded(
                child: RaftRecipeBox(
                  style: slots.label,
                  tokens: rt,
                  child: Text(
                    raftText(context, 'Search'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (RaftInteraction.of(context).pointer)
                RaftRecipeBox(
                  style: slots.shortcut,
                  tokens: rt,
                  child: RaftKbd(globalSearchShortcutLabel()),
                ),
            ],
          ),
        );
        return t.desktop ? RaftCssPixelSnap(child: face) : face;
      },
    );
    return RaftInteraction.of(context).touch
        ? RaftTapSlopAnchor(
            minSize: const Size.square(RaftMetrics.touchTarget),
            child: control,
          )
        : control;
  }
}
