import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'list_items.dart';
import 'recipe_surface.dart';
import 'recipes/app_rail.g.dart';
import 'recipes/recipe_runtime.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// Sidebar.tsx3840–3848: one bordered heading, no duplicate server switcher.
class RaftChatSidebarHeading extends StatelessWidget {
  const RaftChatSidebarHeading({
    super.key,
    required this.label,
    this.workspaceEnabled = false,
  });
  final String label;
  final bool workspaceEnabled;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final recipe = RaftSidebarRecipe(
      t,
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
      variant: RaftSidebarVariant.mountedProduct,
      workspaceEnabled: workspaceEnabled,
    );
    return Container(
      height: recipe.headerHeight,
      padding: recipe.headerInset,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: t.brutal
                ? (workspaceEnabled
                      ? Colors.black.withValues(alpha: .25)
                      : Colors.black)
                : t.colors['line-muted']!,
            width: t.brutal && !workspaceEnabled ? 2 : 1,
          ),
        ),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        label,
        style: RaftTypography.heading(
          t,
          size: workspaceEnabled ? 16 : 18,
          line: workspaceEnabled ? 24 : 28,
          weight: workspaceEnabled ? FontWeight.w600 : FontWeight.w700,
        ),
      ),
    );
  }
}

/// LeftRail.tsx693–771: Bell, Help, optional workspace mode, Settings h11 slots.
class RaftWorkspaceRailFooter extends StatelessWidget {
  const RaftWorkspaceRailFooter({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final footer = RaftAppRailRecipe.resolve(
      theme: t.recipeTheme,
      tokens: t.recipeTokens,
      states: t.recipeStates(),
    ).footer;
    // Footer's own pb-2 is separate from LeftRail root's pb-2.
    return Padding(
      padding: footer.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: footer.rowGap ?? 0),
            SizedBox(
              height: RaftMetrics.railSlot,
              child: Center(child: children[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Actual AppRailItem recipe with RailTabButton's size10/short size9 override.
class RaftWorkspaceRailAction extends StatelessWidget {
  const RaftWorkspaceRailAction({
    super.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.selected = false,
    this.depressed = false,
    this.focusNode,
    this.showTooltip = true,
  });
  final String label;
  final RaftGlyph glyph;
  final VoidCallback? onPressed;
  final bool selected, depressed, showTooltip;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = MediaQuery.sizeOf(context).height <= 600
        ? RaftMetrics.railItemCompact
        : RaftMetrics.railItem;
    return RaftInteractive(
      semanticLabel: label,
      selected: selected,
      focusNode: focusNode,
      tooltip: showTooltip ? label : null,
      onPressed: onPressed,
      builder: (context, state) {
        final slot = RaftAppRailRecipe.resolve(
          theme: t.recipeTheme,
          tokens: t.recipeTokens,
          states: t.recipeStates(
            hovered: state.hovered,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
            extra: [if (selected) 'data-selected=true'],
          ),
        ).item;
        final pressedMode = selected && depressed;
        final style = !pressedMode
            ? slot
            : RaftSlotStyle(
                {
                  ...slot.properties,
                  'background-color': CssColor(
                    t.product.workspaceModeActive.toARGB32(),
                  ),
                  'box-shadow': const CssKeyword('none'),
                  for (final side in ['top', 'right', 'bottom', 'left'])
                    'border-$side-color': const CssColor(0xff000000),
                },
                slot.targets,
                slot.classes,
                slot.tokens,
              );
        Widget box = RaftRecipeBox(
          style: style,
          tokens: t.recipeTokens,
          width: size,
          height: size,
          padding: EdgeInsets.zero,
          child: Center(
            child: RaftIcon(
              glyph,
              size: RaftMetrics.railGlyph,
              color: style.foreground(t.recipeTokens, inherited: t.strong),
            ),
          ),
        );
        if (pressedMode) {
          box = DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: RaftLayeredDecoration(
              BoxDecoration(borderRadius: style.borderRadius),
              RaftProductShadows.shadowWorkspaceModeActive.layers,
              style.borderRadius ?? BorderRadius.zero,
              null,
              style.borderWidth,
            ),
            child: box,
          );
        }
        return box;
      },
    );
  }
}

/// HelpMenu owns no API state. The host supplies authorized actions.
class RaftWorkspaceHelpMenu extends StatefulWidget {
  const RaftWorkspaceHelpMenu({
    super.key,
    required this.label,
    required this.heading,
    required this.entries,
    this.controller,
  });
  final String label, heading;
  final List<RaftMenuEntry> entries;
  final RaftMenuController? controller;
  @override
  State<RaftWorkspaceHelpMenu> createState() => _RaftWorkspaceHelpMenuState();
}

class _RaftWorkspaceHelpMenuState extends State<RaftWorkspaceHelpMenu> {
  final ownedController = RaftMenuController();
  RaftMenuController get controller => widget.controller ?? ownedController;
  @override
  void dispose() {
    ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftDropdownMenu(
      label: widget.label,
      width: 320,
      side: RaftDropdownSide.right,
      align: RaftDropdownAlign.end,
      sideOffset: 8,
      controller: controller,
      entries: widget.entries,
      panelInset: EdgeInsets.zero,
      openOnHover: true,
      closeDelay: const Duration(milliseconds: 120),
      header: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.brutal ? t.product.brutalCream : t.panel,
          border: Border(
            bottom: BorderSide(
              color: t.brutal ? Colors.black : t.colors['line-muted']!,
              width: t.brutal ? 2 : 1,
            ),
          ),
        ),
        child: RaftSectionEyebrow(widget.heading),
      ),
      triggerBuilder: (context, focus, action) => RaftWorkspaceRailAction(
        label: widget.label,
        glyph: RaftGlyph.circleHelp,
        onPressed: action,
        focusNode: focus,
        showTooltip: false,
        selected: controller.isOpen,
      ),
    );
  }
}
