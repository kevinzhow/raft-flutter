import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'interaction.dart';
import 'localization.dart';
import 'kbd.dart';
import 'recipe_surface.dart';
import 'recipes/search_trigger.g.dart';
import 'shortcut_platform.dart';
import 'status_bar.dart';
import 'tap_slop.dart';
import 'text_scaling.dart';
import 'theme.dart';

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
  });
  final Widget workspace;
  final VoidCallback onSearch;
  final List<Widget> trailing;
  final double leadingInset, trailingInset;
  final Widget? navigation;
  final VoidCallback? onDragStart, onDoubleTap;

  /// Lets the host publish the real search field bounds to its overlay.
  final Key? searchKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return RaftChrome(
      child: RaftTapSlopHost(
        child: RaftStatusBarSource(
          color: t.colors['layer-workspace-rail']!,
          child: Container(
            height: t.desktop ? 44 : 48,
            decoration: BoxDecoration(
              color: t.colors['layer-workspace-rail'],
              border: Border(
                bottom: BorderSide(color: t.colors['line-workspace-rail']!),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: RaftTapSlopBackground(
                    child: GestureDetector(
                      key: const Key('workspace-topbar-drag'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: onDragStart == null
                          ? null
                          : (_) => onDragStart!(),
                      onDoubleTap: onDoubleTap,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                CustomMultiChildLayout(
                  delegate: _WorkspaceTopBarLayout(
                    (width * .32).clamp(360.0, math.min(520.0, width)),
                  ),
                  children: [
                    LayoutId(
                      id: _TopBarSlot.leading,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 8 + leadingInset,
                          right: 8,
                        ),
                        child: navigation == null
                            ? workspace
                            : Row(
                                children: [
                                  Expanded(child: workspace),
                                  navigation!,
                                ],
                              ),
                      ),
                    ),
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
                          right: 8 + trailingInset,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TopBarSlot { leading, search, trailing }

/// Keep search centred, allowing its width to shrink when window controls and
/// working agents need more space. No fixed estimate of a translated label's width.
class _WorkspaceTopBarLayout extends MultiChildLayoutDelegate {
  _WorkspaceTopBarLayout(this.preferredSearchWidth);
  final double preferredSearchWidth;
  @override
  void performLayout(Size size) {
    final right = layoutChild(_TopBarSlot.trailing, BoxConstraints.loose(size));
    final side = math
        .max((size.width - preferredSearchWidth) / 2, right.width)
        .clamp(0.0, size.width / 2);
    final search = layoutChild(
      _TopBarSlot.search,
      BoxConstraints(
        minWidth: size.width - 2 * side,
        maxWidth: size.width - 2 * side,
        maxHeight: size.height,
      ),
    );
    final left = layoutChild(
      _TopBarSlot.leading,
      BoxConstraints(minWidth: side, maxWidth: side, maxHeight: size.height),
    );
    positionChild(
      _TopBarSlot.leading,
      Offset(0, (size.height - left.height) / 2),
    );
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
      preferredSearchWidth != old.preferredSearchWidth;
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
            hovered: state.hovered,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
          ),
        );
        final glyph = slots.root.target("& > svg:not([class*='size-'])")!;
        return RaftRecipeBox(
          style: slots.root.withCssUsedBorderWidths(),
          tokens: rt,
          height: t.desktop ? RaftLayoutMetrics.desktopControl : null,
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
