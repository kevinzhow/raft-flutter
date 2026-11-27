import 'hover_region.dart';

import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'list_items.dart';
import 'design_primitives.dart' show RaftInteractive;
import 'menu_action_row.dart';
import 'recipe_surface.dart';
import 'popover_surface.dart';
import 'recipes/context_menu.g.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

/// One entry of a Sidebar.tsx `ContextMenuPopup`: a `MenuItem` row, the small
/// group heading above the sort / display rows, or a
/// `ContextMenuDivider`.
@immutable
sealed class RaftSidebarMenuEntry {
  const RaftSidebarMenuEntry();
}

class RaftSidebarMenuItem extends RaftSidebarMenuEntry {
  const RaftSidebarMenuItem({
    required this.label,
    this.glyph,
    this.leading,
    this.onPressed,
    this.checked = false,
    this.submenu = false,
    this.onHover,
    this.itemKey,
    this.submenuEntries,
    this.submenuLabel,
    this.submenuWidth,
  });
  final String label;

  /// 14px lucide icon before the label (`icon={<Plus size={14} />}`).
  final RaftGlyph? glyph;
  final Widget? leading;
  final VoidCallback? onPressed;

  /// Trailing `<Check size={14} />` of the checked radio / checkbox rows.
  final bool checked;

  /// Trailing `<ChevronRight size={14} />` of "Move to section".
  final bool submenu;
  final VoidCallback? onHover;
  final Key? itemKey;

  /// This row's own submenu (Sidebar.tsx `NotificationLevelSubmenu`). Without
  /// it a `submenu` row opens the menu's [RaftSidebarContextMenu.submenuEntries]
  /// ("Move to section").
  final List<RaftSidebarMenuEntry>? submenuEntries;
  final String? submenuLabel;
  final double? submenuWidth;
}

/// A wrapping note in a menu (`ContextMenuLabel className="whitespace-normal
/// font-normal text-foreground-muted"`): the Mute note under the levels.
class RaftSidebarMenuNote extends RaftSidebarMenuEntry {
  const RaftSidebarMenuNote(this.text);
  final String text;
}

class RaftSidebarMenuHeading extends RaftSidebarMenuEntry {
  const RaftSidebarMenuHeading(this.label);
  final String label;
}

class RaftSidebarMenuDivider extends RaftSidebarMenuEntry {
  const RaftSidebarMenuDivider();
}

/// Sidebar.tsx row / section / surface context menu and the "Move to section"
/// submenu: raft-ui `ContextMenuPopup` (the message menu recipe) at a fixed
/// width. The Raft recipe's `min-w-60` also bounds caller-supplied widths;
/// frozen looks retain their original `w-48` / `w-64` / `w-56` widths.
class RaftSidebarContextMenu extends StatefulWidget {
  const RaftSidebarContextMenu({
    super.key,
    required this.entries,
    this.width = 192,
    this.onDismiss,
    this.label,
    this.submenuEntries,
    this.submenuWidth = 224,
    this.submenuLabel,
    this.contextItems = false,
  }) : _sidebarSourceWidth = false;

  /// Sidebar.tsx mounts row, section, surface and submenu popups at `w-60`.
  /// That matches the generated current recipe's `min-w-60`; its declared
  /// width/minimum is used; [legacyWidth] and [legacySubmenuWidth] are only
  /// the fallbacks. Use the default constructor when a caller intentionally requests a custom current width.
  const RaftSidebarContextMenu.sidebar({
    super.key,
    required this.entries,
    double legacyWidth = 192,
    this.onDismiss,
    this.label,
    this.submenuEntries,
    double legacySubmenuWidth = 224,
    this.submenuLabel,
  }) : width = legacyWidth,
       submenuWidth = legacySubmenuWidth,
       _sidebarSourceWidth = true,
       contextItems = false;

  final List<RaftSidebarMenuEntry> entries;
  final double width;
  final bool _sidebarSourceWidth;
  final bool contextItems;
  final VoidCallback? onDismiss;
  final String? label;

  /// "Move to section": opened by hovering / pressing the `submenu: true` row,
  /// closed by hovering any other row (Sidebar.tsx `moveToSectionMenuOpen`).
  final List<RaftSidebarMenuEntry>? submenuEntries;
  final double submenuWidth;
  final String? submenuLabel;

  @override
  State<RaftSidebarContextMenu> createState() => _RaftSidebarContextMenuState();
}

class _RaftSidebarContextMenuState extends State<RaftSidebarContextMenu> {
  bool submenuOpen = false;
  final mainKey = GlobalKey();
  final portal = OverlayPortalController();

  /// The row whose submenu is open, and each submenu row's position.
  RaftSidebarMenuItem? openItem;
  final rowKeys = <RaftSidebarMenuItem, GlobalKey>{};

  void setOpen(bool open, [RaftSidebarMenuItem? item]) {
    final next = open ? item : null;
    if (open == submenuOpen && identical(next, openItem)) return;
    setState(() {
      submenuOpen = open;
      openItem = next;
    });
    open ? portal.show() : portal.hide();
  }

  bool get _hasSubmenu =>
      widget.submenuEntries != null ||
      widget.entries.any(
        (e) => e is RaftSidebarMenuItem && e.submenuEntries != null,
      );

  @override
  Widget build(BuildContext context) {
    final menu = KeyedSubtree(
      key: mainKey,
      child: _menu(
        context,
        widget.entries,
        widget.width,
        widget.label,
        primary: true,
      ),
    );
    if (!_hasSubmenu) return menu;
    return OverlayPortal(
      controller: portal,
      overlayChildBuilder: (overlayContext) {
        final item = openItem;
        final sub = item?.submenuEntries ?? widget.submenuEntries;
        if (sub == null) return const SizedBox.shrink();
        return _submenu(overlayContext, context, sub, item);
      },
      child: menu,
    );
  }

  /// Sidebar.tsx `placeSidebarContextSubmenu`: a second popup (z 51)
  /// level with the trigger row, 4px right of the main menu, else 4px left of
  /// it, never closer than 8px to the viewport edge - on a phone it therefore
  /// covers the main menu.
  Widget _submenu(
    BuildContext overlayContext,
    BuildContext menuContext,
    List<RaftSidebarMenuEntry> sub,
    RaftSidebarMenuItem? item,
  ) {
    final main = mainKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(overlayContext).context.findRenderObject();
    if (main is! RenderBox ||
        !main.attached ||
        overlay is! RenderBox ||
        !overlay.attached) {
      return const SizedBox.shrink();
    }
    final t = RaftTokens.of(menuContext);
    final content = RaftContextMenuRecipe.resolve(
      states: t.recipeStates(responsive: true),
      tokens: RaftRecipeTokens(t),
    ).content;
    final origin = main.localToGlobal(Offset.zero, ancestor: overlay);
    // Level with the trigger row; "Move to section" is the first row, below
    // the popup's border and padding.
    final row = item?.submenuEntries == null
        ? null
        : rowKeys[item]?.currentContext?.findRenderObject();
    final top = row is RenderBox && row.attached
        ? row.localToGlobal(Offset.zero, ancestor: overlay).dy
        : origin.dy + content.borderWidth.top + content.padding.top;
    return CustomSingleChildLayout(
      delegate: _SubmenuLayout(
        left: origin.dx,
        right: origin.dx + main.size.width,
        top: top,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: _menu(
          menuContext,
          sub,
          item?.submenuWidth ?? widget.submenuWidth,
          item?.submenuLabel ?? widget.submenuLabel,
        ),
      ),
    );
  }

  Widget _menu(
    BuildContext context,
    List<RaftSidebarMenuEntry> entries,
    double width,
    String? label, {
    bool primary = false,
  }) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final s = RaftContextMenuRecipe.resolve(
      states: t.recipeStates(responsive: true),
      tokens: resolver,
    );
    final content = s.content;
    final separator = s.separator;
    // The real Sidebar.tsx w-60 mounts match the current recipe's min-w-60.
    // Other users of this component keep their explicit width, bounded by CSS
    // min-width.
    final requestedWidth = widget._sidebarSourceWidth
        ? content.width ?? content.minWidth ?? width
        : width;
    final usedWidth = widget.contextItems
        ? width
        : math.max(requestedWidth, content.minWidth ?? 0);
    Widget divider() {
      final w = separator.borderWidth.top;
      final m = separator.margin;
      final color = w > 0
          ? separator
                .borderColorOf('top')
                ?.resolve(resolver, currentColor: t.strong)
          : separator.backgroundColor?.resolve(resolver);
      return Padding(
        padding: EdgeInsets.only(top: m.top, bottom: m.bottom),
        child: CustomPaint(
          size: Size(0, w > 0 ? w : (separator.height ?? 1)),
          painter: _Rule(color ?? t.strong, left: m.left, right: m.right),
        ),
      );
    }

    final children = <Widget>[
      for (final entry in entries)
        switch (entry) {
          RaftSidebarMenuDivider() => divider(),
          RaftSidebarMenuHeading(:final label) => RaftRecipeBox(
            style: s.label,
            tokens: resolver,
            child: Text(label),
          ),
          RaftSidebarMenuNote(:final text) => RaftRecipeBox(
            style: s.label,
            tokens: resolver,
            child: Text(
              text,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: t.colors['foreground-muted'],
              ),
            ),
          ),
          RaftSidebarMenuItem() => RaftHoverRegion(
            key: primary && entry.submenu
                ? rowKeys.putIfAbsent(entry, GlobalKey.new)
                : null,
            onEnter: (_) {
              if (primary) setOpen(entry.submenu, entry);
              entry.onHover?.call();
            },
            child: widget.contextItems
                ? Semantics(
                    role: SemanticsRole.menuItem,
                    child: RaftInteractive(
                      key: entry.itemKey,
                      onPressed: entry.onPressed,
                      builder: (context, state) => RaftMenuSlotRow(
                        label: entry.label,
                        root: RaftContextMenuRecipe.resolve(
                          states: t.recipeStates(
                            responsive: true,
                            hovered: state.hovered,
                            focusVisible: state.focusVisible,
                            extra: [if (state.focusVisible) 'data-highlighted'],
                          ),
                          tokens: resolver,
                        ).item,
                        tokens: resolver,
                        leading:
                            entry.leading ??
                            (entry.glyph == null
                                ? null
                                : RaftIcon(entry.glyph!, size: 16)),
                      ),
                    ),
                  )
                : RaftMenuButtonItem(
                    key: entry.itemKey,
                    label: entry.label,
                    icon: entry.glyph == null
                        ? null
                        : SizedBox.square(
                            dimension: 14,
                            child: RaftIcon(
                              entry.glyph!,
                              size: 14,
                              color: IconTheme.of(context).color,
                            ),
                          ),
                    trailing: entry.checked
                        ? const RaftIcon(RaftGlyph.check, size: 14)
                        : entry.submenu
                        ? const RaftIcon(RaftGlyph.chevronRight, size: 14)
                        : null,
                    onPressed: entry.submenu
                        ? () => setOpen(true, entry)
                        : (entry.onPressed ?? () {}),
                  ),
          ),
        },
    ];
    final gap = content.rowGap ?? 0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            widget.onDismiss?.call(),
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Semantics(
          role: SemanticsRole.menu,
          label: label,
          child: SizedBox(
            width: usedWidth,
            child: RaftPopoverSurface(
              surfaceStyle: content,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0 && gap > 0) SizedBox(height: gap),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Rule extends CustomPainter {
  const _Rule(this.color, {this.left = 0, this.right = 0});
  final Color color;
  final double left, right;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    Rect.fromLTRB(left, 0, size.width - right, size.height),
    Paint()..color = color,
  );
  @override
  bool shouldRepaint(_Rule old) =>
      old.color != color || old.left != left || old.right != right;
}

class _SubmenuLayout extends SingleChildLayoutDelegate {
  const _SubmenuLayout({
    required this.left,
    required this.right,
    required this.top,
  });
  final double left, right, top;
  static const margin = 8.0, gap = 4.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          math.max(0, constraints.maxWidth - margin * 2),
          math.max(0, constraints.maxHeight - margin * 2),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rightX = right + gap;
    final x = rightX + childSize.width <= size.width - margin
        ? rightX
        : math.max(margin, left - childSize.width - gap);
    final maxY = math.max(margin, size.height - childSize.height - margin);
    return Offset(x, top.clamp(margin, maxY).toDouble());
  }

  @override
  bool shouldRelayout(_SubmenuLayout old) =>
      old.left != left || old.right != right || old.top != top;
}
