import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:ui' show SemanticsRole;
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'quick_reaction_picker.dart';
import 'recipes/context_menu.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

/// One Web `MenuItem` row (packages/web/src/components/ui/MenuItem.tsx) in the
/// MessageItem context menu.
@immutable
class RaftMessageContextMenuItem {
  const RaftMessageContextMenuItem({
    required this.label,
    required this.icon,
    this.onPressed,
    this.key,
  });
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Key? key;
}

/// Web MessageItem.tsx context menu (`ContextMenuPopup role=menu`), shared by
/// desktop right-click and mobile long-press: an optional quick-reaction row,
/// then [sections] separated by `ContextMenuDivider` (`ContextMenuSeparator`).
class RaftMessageContextMenu extends StatelessWidget {
  const RaftMessageContextMenu({
    super.key,
    required this.sections,
    this.onReact,
    this.reactionLabel,
    this.onDismiss,
  });

  /// Item groups; empty groups are skipped, a divider sits between groups.
  final List<List<RaftMessageContextMenuItem>> sections;

  /// Quick reaction row (`!isSystem && canReact`); null hides the row.
  final ValueChanged<String>? onReact;
  final String Function(String emoji)? reactionLabel;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final s = RaftContextMenuRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      tokens: resolver,
    );
    final content = s.content;
    final separator = s.separator;
    Widget divider() {
      final width = separator.borderWidth.top;
      return Padding(
        padding: separator.margin,
        child: width > 0
            ? Container(
                height: width,
                color: separator
                    .borderColorOf('top')
                    ?.resolve(resolver, currentColor: t.strong),
              )
            : Container(
                height: separator.height ?? 1,
                color: separator.backgroundColor?.resolve(resolver),
              ),
      );
    }

    final groups = sections.where((g) => g.isNotEmpty).toList();
    final children = <Widget>[
      if (onReact != null)
        _QuickReactionRow(onReact: onReact!, label: reactionLabel),
      for (var i = 0; i < groups.length; i++) ...[
        if (i > 0) divider(),
        for (final item in groups[i])
          _MessageMenuRow(key: item.key, item: item),
      ],
    ];
    final gap = content.rowGap ?? 0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            onDismiss?.call(),
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Semantics(
          role: SemanticsRole.menu,
          child: ConstrainedBox(
            // `min-w-48`; the width is otherwise the intrinsic content width.
            constraints: BoxConstraints(minWidth: content.minWidth ?? 192),
            child: IntrinsicWidth(
              child: Container(
                padding: content.padding,
                decoration: content.decoration(resolver),
                clipBehavior: Clip.hardEdge,
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

/// `flex h-9 items-center gap-1 bg-layer-panel px-2 theme-brutal:bg-white`
/// with seven `size-7 rounded` buttons holding 18px ReactionGlyphs.
class _QuickReactionRow extends StatelessWidget {
  const _QuickReactionRow({required this.onReact, this.label});
  final ValueChanged<String> onReact;
  final String Function(String emoji)? label;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftQuickReactionRecipe(t);
    return Container(
      key: const ValueKey('message-menu-reaction-quick-row'),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: t.brutal ? Colors.white : t.colors['layer-panel'],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < raftQuickReactions.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            RaftControl(
              key: ValueKey('message-menu-react-${raftQuickReactions[i]}'),
              recipe: recipe,
              onPressed: () => onReact(raftQuickReactions[i]),
              semanticLabel: label?.call(raftQuickReactions[i]),
              tooltip: label?.call(raftQuickReactions[i]),
              minimumTargetSize: 28,
              visualHeight: 28,
              visualWidth: 28,
              padding: EdgeInsets.zero,
              child: RaftReactionGlyph(raftQuickReactions[i], size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

/// Web `MenuItem`: raft-ui `Button size=sm variant=ghost` (h-7, ghost border)
/// + `flex w-full items-center gap-2 px-3 py-2 text-sm text-left font-medium
/// text-foreground-strong hover:bg-fill-muted theme-brutal:text-black
/// theme-brutal:hover:bg-soft-signal/30`.
class _MessageMenuRow extends StatefulWidget {
  const _MessageMenuRow({super.key, required this.item});
  final RaftMessageContextMenuItem item;
  @override
  State<_MessageMenuRow> createState() => _MessageMenuRowState();
}

class _MessageMenuRowState extends State<_MessageMenuRow> {
  bool hovered = false, focused = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final enabled = widget.item.onPressed != null;
    final foreground = !enabled
        ? (t.brutal
              ? Colors.black.withValues(alpha: .3)
              : t.colors['foreground-muted']!)
        : (t.brutal ? Colors.black : t.strong);
    final highlight = t.brutal
        ? t.colors['color-soft-signal']!.withValues(
            alpha: t.colors['color-soft-signal']!.a * .3,
          )
        : t.colors['fill-muted']!;
    // Ghost sm: brutal 2px transparent border / radius 0, elegant no border
    // / radius 4. Viewports <= 600px tall drop py-2 to py-1 (still h-7).
    final border = t.brutal ? 2.0 : 0.0;
    return Semantics(
      role: SemanticsRole.menuItem,
      label: widget.item.label,
      enabled: enabled,
      button: true,
      onTap: widget.item.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => hovered = v),
        onShowFocusHighlight: (v) => setState(() => focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.item.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.item.onPressed,
          child: Container(
            height: 28,
            padding: EdgeInsets.symmetric(horizontal: 12 - border),
            decoration: BoxDecoration(
              color: enabled && (hovered || focused)
                  ? highlight
                  : Colors.transparent,
              border: border > 0
                  ? Border.all(color: Colors.transparent, width: border)
                  : null,
              borderRadius: BorderRadius.circular(t.brutal ? 0 : 4),
            ),
            child: Row(
              children: [
                IconTheme.merge(
                  data: IconThemeData(color: foreground, size: 14),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: foreground),
                    child: SizedBox.square(
                      dimension: 14,
                      child: widget.item.icon,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: t.brutal ? t.headingFont : t.bodyFont,
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
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

/// Web `placeFloatingOverlay` axis rule (ui/floatingOverlayPosition.ts):
/// open toward the end when it fits, else flip before the anchor, else clamp.
double raftPlaceOverlayAxis({
  required double anchor,
  required double size,
  required double viewportSize,
  double padding = 8,
}) {
  final min = padding;
  final max = viewportSize - size - padding;
  double clamp(double v) => math.min(math.max(v, min), math.max(min, max));
  if (anchor + size <= viewportSize - padding) return clamp(anchor);
  if (anchor - size >= min) return anchor - size;
  return clamp(anchor);
}

/// Opens [menu] as the MessageItem context-menu portal at [anchor] (global):
/// a transparent dismiss backdrop, then the popup placed by the measured
/// `useFloatingOverlayPosition` rule with an 8px viewport margin.
Future<T?> showRaftMessageContextMenu<T>({
  required BuildContext context,
  required Offset anchor,
  required Widget Function(BuildContext context) builder,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (routeContext, _, _) => CustomSingleChildLayout(
        delegate: _RaftContextMenuLayout(anchor),
        child: Material(
          type: MaterialType.transparency,
          child: builder(routeContext),
        ),
      ),
    ),
  );
}

class _RaftContextMenuLayout extends SingleChildLayoutDelegate {
  const _RaftContextMenuLayout(this.anchor);
  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          math.max(0, constraints.maxWidth - 16),
          math.max(0, constraints.maxHeight - 16),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    raftPlaceOverlayAxis(
      anchor: anchor.dx,
      size: childSize.width,
      viewportSize: size.width,
    ),
    raftPlaceOverlayAxis(
      anchor: anchor.dy,
      size: childSize.height,
      viewportSize: size.height,
    ),
  );

  @override
  bool shouldRelayout(_RaftContextMenuLayout old) => old.anchor != anchor;
}

/// Convenience: a 14px lucide icon for a menu row.
Widget raftMessageMenuIcon(RaftGlyph glyph) => Builder(
  builder: (context) =>
      RaftIcon(glyph, size: 14, color: IconTheme.of(context).color),
);
