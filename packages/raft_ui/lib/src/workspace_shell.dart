import 'sidebar_text.dart';
import 'tap_slop.dart';

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'list_items.dart';
import 'menu_action_row.dart';
import 'recipe_surface.dart';
import 'rail_attention.dart';
import 'recipes/app_rail.g.dart';
import 'recipes/recipe_router.dart' show usesLegacyRecipes;
import 'recipes/web_help_menu.g.dart';
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';
import 'panel_layout.dart' show RaftCssFocusOutline;
import 'raft/css_box.dart' show raftControlBorderPx;

/// Sidebar.tsx3840–3848: one bordered heading, no duplicate server switcher.
class RaftChatSidebarHeading extends StatelessWidget {
  const RaftChatSidebarHeading({
    super.key,
    required this.label,
    this.workspaceEnabled = false,
    this.trailing,
  });
  final String label;
  final bool workspaceEnabled;

  /// The working-agents summary when the screen has no top bar to hold it.
  final Widget? trailing;
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
    final grows = RaftScaled.grows(context);
    final title = RaftSidebarText(
      label,
      style: RaftTypography.heading(
        t,
        size: workspaceEnabled
            ? 16
            : t.size('type.sidebarHeading.size', fallback: 18),
        line: workspaceEnabled
            ? 24
            : t.size('type.sidebarHeading.line', fallback: 28),
        weight: workspaceEnabled ? FontWeight.w600 : FontWeight.w700,
      ),
    );
    final heading = trailing == null
        ? title
        : Row(
            children: [
              Expanded(child: title),
              trailing!,
            ],
          );
    return Container(
      height: grows ? null : recipe.headerHeight,
      constraints: grows
          ? BoxConstraints(minHeight: recipe.headerHeight)
          : null,
      padding: recipe.headerInset,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                t.colors[workspaceEnabled
                    ? 'line-sidebar-heading-workspace'
                    : 'line-sidebar-heading'] ??
                t.colors['line-muted']!,
            width: workspaceEnabled
                ? 1
                : t.size('stroke.sidebarHeading', fallback: 1),
          ),
        ),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: heading,
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
    final short = MediaQuery.sizeOf(context).height <= 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.size('space.railInline', fallback: 0),
        0,
        t.size('space.railInline', fallback: 0),
        t.size(
          short ? 'space.railFooterBottomCompact' : 'space.railFooterBottom',
          fallback: footer.padding.bottom,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              SizedBox(
                height: t.size(
                  'space.railItemGap',
                  fallback: footer.rowGap ?? 0,
                ),
              ),
            SizedBox(
              height: t.size(
                'size.railFooterSlot',
                fallback: RaftMetrics.railSlot,
              ),
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
    this.semanticLabel,
    this.glyph,
    this.icon,
    required this.onPressed,
    this.navigation = false,
    this.extent,
    this.badge,
    this.selected = false,
    this.focusNode,
    this.showTooltip = true,
    this.attention = false,
  }) : assert(glyph != null || icon != null);
  final String label;
  final String? semanticLabel;
  final RaftGlyph? glyph;
  final Widget? icon;
  final bool navigation;

  /// The same frame action in a top bar has a 36px box.
  final double? extent;
  final Widget? badge;
  final VoidCallback? onPressed;
  final bool selected, showTooltip, attention;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftRailRecipe(
      t,
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    final size = extent ?? recipe.itemSize;
    Widget iconFor() => icon ?? RaftIcon(glyph!, size: recipe.glyphSize);
    final control = RaftInteractive(
      semanticLabel: semanticLabel ?? label,
      selected: selected,
      focusNode: focusNode,
      tooltip: showTooltip ? label : null,
      onPressed: onPressed,
      builder: (context, state) {
        final style = RaftAppRailRecipe.resolve(
          theme: t.recipeTheme,
          tokens: t.recipeTokens,
          states: t.recipeStates(
            hovered: state.hovered,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
            disabled: !state.enabled,
            extra: [if (selected) 'data-selected=true'],
          ),
        ).item;
        final active = state.hovered || state.pressed;
        final foreground = navigation
            ? selected
                  ? recipe.selectedForeground
                  : active
                  ? t.colors['foreground-workspace-rail-action-hover']!
                  : recipe.foreground
            : t.colors[selected
                  ? 'foreground-workspace-rail-action-selected'
                  : active
                  ? 'foreground-workspace-rail-action-hover'
                  : 'foreground-workspace-rail-action']!;
        final hoverFill = t.colors['layer-workspace-rail-hover']!;
        return CustomPaint(
          foregroundPainter: RaftCssFocusOutline(
            enabled:
                state.focusVisible &&
                t.size('stroke.railFocus', fallback: 0) > 0,
            color: t.colors['line-workspace-rail-focus']!,
            width: t.size('stroke.railFocus', fallback: 0),
            offset: t.size('space.railFocusOffset', fallback: 0),
            radius: recipe.radius,
          ),
          child: RaftRecipeBox(
            style: style,
            tokens: t.recipeTokens,
            width: size,
            height: size,
            // This is icon-only chrome. Text scaling must not turn its finite
            // square into a minimum height around an expanding Stack.
            growWithText: false,
            padding: EdgeInsets.zero,
            decorationOverride: (base) => base.copyWith(
              color: selected
                  ? recipe.selectedBackground
                  : active
                  ? hoverFill.withValues(
                      alpha:
                          hoverFill.a *
                          t.size('opacity.railActionHover', fallback: 1),
                    )
                  : Colors.transparent,
              borderRadius: recipe.radius,
              border: Border.all(
                color: selected
                    ? t.colors['line-workspace-rail-selected']!
                    : active
                    ? t.colors['line-workspace-rail-hover']!
                    : Colors.transparent,
                width: raftControlBorderPx(
                  context,
                  t.size('stroke.railItem', fallback: 1),
                ),
              ),
              boxShadow: [
                if (selected) ...recipe.selectedShadows(action: !navigation),
                if (state.focusVisible) ...recipe.focusShadows,
              ],
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground, size: recipe.glyphSize),
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: SizedBox.square(
                        dimension: recipe.glyphSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          fit: StackFit.expand,
                          children: [
                            iconFor(),
                            if (attention) RaftRailAttention(child: iconFor()),
                          ],
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(right: -4, top: -4, child: badge!),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    return RaftDensityScope.of(context) == RaftDensity.touch
        ? RaftTapSlopAnchor(
            minSize: const Size.square(RaftMetrics.touchTarget),
            child: control,
          )
        : control;
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
    this.attention = false,
  });
  final bool attention;
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
    final tokens = t.recipeTokens;
    final composition = usesLegacyRecipes(tokens)
        ? null
        : RaftWebHelpMenuRecipe.resolve(
            tokens: tokens,
            states: t.recipeStates(),
          );
    return RaftDropdownMenu(
      label: widget.label,
      surfaceKey: const ValueKey('workspace-help-popup'),
      width: composition?.root.width ?? 320,
      side: RaftDropdownSide.right,
      align: RaftDropdownAlign.end,
      sideOffset: 8,
      controller: controller,
      entries: widget.entries,
      panelInset: composition?.root.padding ?? EdgeInsets.zero,
      openOnHover: true,
      closeDelay: const Duration(milliseconds: 120),
      header: composition == null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: t.panel,
                border: Border(
                  bottom: BorderSide(color: t.colors['line-muted']!, width: 1),
                ),
              ),
              child: RaftSectionEyebrow(widget.heading),
            )
          : RaftMenuItemSurface(
              style: composition.header,
              tokens: tokens,
              applyText: false,
              child: RaftSectionEyebrow(widget.heading),
            ),
      triggerBuilder: (context, focus, action) => RaftWorkspaceRailAction(
        label: widget.label,
        glyph: RaftGlyph.circleHelp,
        onPressed: action,
        focusNode: focus,
        showTooltip: false,
        selected: controller.isOpen,
        attention: widget.attention,
      ),
    );
  }
}
