import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import '../recipes.dart';
import 'theme.dart';

/// One option of a [RaftInlineBadgeEditor] menu.
@immutable
class RaftInlineBadgeOption {
  const RaftInlineBadgeOption({required this.id, required this.label});
  final String id;
  final String label;
}

/// Product InlineBadgeEditor (packages/web/src/components/InlineBadgeEditor.tsx):
/// a raft-ui Badge rendered as a button (label + Pencil 10 at 40% opacity) that
/// opens a DropdownMenuPopup of MenuItem rows below it, each with a trailing
/// Check 14 that is only visible on the selected option.
///
/// [open] is controlled like the Web prop; when null the widget owns the state.
class RaftInlineBadgeEditor extends StatefulWidget {
  const RaftInlineBadgeEditor({
    super.key,
    required this.label,
    required this.selectedId,
    required this.options,
    required this.onSelect,
    required this.background,
    required this.foreground,
    this.open,
    this.onOpenChanged,
    this.uppercase = false,
    this.menuMinWidth = 140,
    this.alignRight = false,
    this.enabled = true,
    this.tooltip,
  });
  final String label, selectedId;
  final List<RaftInlineBadgeOption> options;
  final ValueChanged<String> onSelect;

  /// Resolved `badgeClassName` background/foreground (theme dependent).
  final Color background, foreground;
  final bool? open;
  final ValueChanged<bool>? onOpenChanged;
  final bool uppercase, alignRight, enabled;

  /// `dropdownMinWidth` (`min-w-[140px]` for task status).
  final double menuMinWidth;
  final String? tooltip;

  @override
  State<RaftInlineBadgeEditor> createState() => _RaftInlineBadgeEditorState();
}

class _RaftInlineBadgeEditorState extends State<RaftInlineBadgeEditor> {
  final portal = OverlayPortalController();
  final link = LayerLink();
  bool ownedOpen = false;
  bool hovered = false;
  bool get isOpen => widget.open ?? ownedOpen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(RaftInlineBadgeEditor old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted) return;
    if (isOpen && !portal.isShowing) portal.show();
    if (!isOpen && portal.isShowing) portal.hide();
  }

  void _setOpen(bool value) {
    if (widget.open == null) setState(() => ownedOpen = value);
    widget.onOpenChanged?.call(value);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final theme = t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;
    // Badge (appearance soft, variant from caller) merged with the editor's
    // className: `mt-0.5 inline-flex items-center gap-1
    // theme-brutal:border-2 theme-brutal:border-black px-2 py-0.5 text-xs
    // font-bold theme-brutal:text-black`.
    final badge = RaftBadgeRecipe.resolve(
      theme: theme,
      appearance: RaftBadgeRecipeAppearance.soft,
      uppercase: widget.uppercase,
      tokens: rt,
    ).root;
    final inherited = badge.textStyle(rt);
    final label = inherited.copyWith(
      // Badge sets no family: it inherits the document `font-sans`.
      fontFamily: inherited.fontFamily ?? t.bodyFont,
      decoration: TextDecoration.none,
      fontSize: 12, // text-xs
      height: 16 / 12,
      fontWeight: FontWeight.w700, // font-bold
      color: widget.foreground,
      letterSpacing: widget.uppercase ? 12 * .025 : badge.letterSpacing,
    );
    final trigger = Container(
      // brutal Badge `h-5`; elegant has no fixed height (py-0.5 + 16px line).
      height: badge.height,
      margin: const EdgeInsets.only(top: 2), // mt-0.5
      // px-2 py-0.5; with the brutal fixed h-5 the 16px line is centred
      // (items-center) and overflows into the padding, so only elegant keeps
      // the vertical inset in layout.
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: badge.height == null ? 2 : 0,
      ),
      decoration: BoxDecoration(
        color: widget.background,
        borderRadius: badge.borderRadius,
        border: t.brutal
            ? Border.all(color: Colors.black, width: 2)
            : Border.all(color: Colors.transparent),
      ),
      foregroundDecoration: hovered && widget.enabled
          // hover:brightness-90 (brutal) / brightness-[0.96] (elegant).
          ? BoxDecoration(
              color: Colors.black.withValues(alpha: t.brutal ? .1 : .04),
              borderRadius: badge.borderRadius,
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4, // gap-1
        children: [
          Text(
            widget.uppercase ? widget.label.toUpperCase() : widget.label,
            style: label,
          ),
          Opacity(
            opacity: .4,
            child: RaftIcon(
              RaftGlyph.pencil,
              size: 10,
              color: widget.foreground,
            ),
          ),
        ],
      ),
    );
    return OverlayPortal(
      controller: portal,
      overlayChildBuilder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _setOpen(false),
            ),
          ),
          CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            targetAnchor: widget.alignRight
                ? Alignment.bottomRight
                : Alignment.bottomLeft,
            followerAnchor: widget.alignRight
                ? Alignment.topRight
                : Alignment.topLeft,
            offset: const Offset(0, 4), // triggerRect.bottom + 4
            child: Align(
              alignment: widget.alignRight
                  ? Alignment.topRight
                  : Alignment.topLeft,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      _setOpen(false),
                },
                child: RaftInlineBadgeMenu(
                  minWidth: widget.menuMinWidth,
                  selectedId: widget.selectedId,
                  options: widget.options,
                  onSelect: (id) {
                    widget.onSelect(id);
                    _setOpen(false);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: link,
        child: Semantics(
          button: true,
          enabled: widget.enabled,
          label: widget.tooltip ?? widget.label,
          excludeSemantics: true,
          onTap: widget.enabled ? () => _setOpen(!isOpen) : null,
          child: MouseRegion(
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            onEnter: (_) => setState(() => hovered = true),
            onExit: (_) => setState(() => hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? () => _setOpen(!isOpen) : null,
              child: Opacity(
                opacity: widget.enabled ? 1 : .6, // disabled:opacity-60
                child: trigger,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The InlineBadgeEditor dropdown: raft-ui DropdownMenuPopup (`content` slot,
/// `overflow-y-auto min-w-[140px]`) holding product MenuItem rows
/// (packages/web/src/components/ui/MenuItem.tsx: Button size=sm variant=ghost
/// + `flex w-full items-center gap-2 px-3 py-2 text-sm font-medium
/// text-foreground-strong theme-brutal:text-black`) with a trailing Check 14.
class RaftInlineBadgeMenu extends StatelessWidget {
  const RaftInlineBadgeMenu({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelect,
    this.minWidth = 120,
  });
  final List<RaftInlineBadgeOption> options;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final theme = t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;
    final content = RaftDropdownMenuRecipe.resolve(
      theme: theme,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).content;
    return Semantics(
      role: SemanticsRole.menu,
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth),
        decoration: content.decoration(rt),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in options)
                _InlineBadgeMenuRow(
                  label: option.label,
                  selected: option.id == selectedId,
                  onPressed: () => onSelect(option.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineBadgeMenuRow extends StatefulWidget {
  const _InlineBadgeMenuRow({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  @override
  State<_InlineBadgeMenuRow> createState() => _InlineBadgeMenuRowState();
}

class _InlineBadgeMenuRowState extends State<_InlineBadgeMenuRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final button = RaftButtonRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      variant: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.sm,
      tokens: rt,
    ).root;
    final foreground = t.brutal ? Colors.black : t.strong;
    final style = button
        .textStyle(rt)
        .copyWith(
          fontSize: 14, // text-sm
          height: 20 / 14,
          fontWeight: FontWeight.w500, // font-medium
          color: foreground,
          decoration: TextDecoration.none,
        );
    final hoverFill = t.brutal
        // theme-brutal:hover:bg-soft-signal/30
        ? t.colors['color-soft-signal']!.withValues(alpha: .3)
        // hover:bg-fill-muted
        : t.colors['fill-muted']!;
    return Semantics(
      role: SemanticsRole.menuItem,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            height: button.height, // Button size=sm h-7
            padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
            decoration: BoxDecoration(
              color: hovered ? hoverFill : null,
              borderRadius: button.borderRadius,
              // brutal Button border-2 (ghost: transparent).
              border: t.brutal
                  ? Border.all(color: Colors.transparent, width: 2)
                  : null,
            ),
            child: Row(
              spacing: 8, // gap-2
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                Opacity(
                  opacity: widget.selected ? 1 : 0,
                  child: RaftIcon(RaftGlyph.check, size: 14, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline-level control placed in a block container, as the Web DOM does
/// (e.g. TaskCard's `<div class="relative shrink-0">` around the badge
/// button): the control sits on the baseline of a CSS line box whose strut is
/// the inherited [style] (font, size, line-height). The line box can be taller
/// than the control, which is what offsets it inside the block.
class RaftInlineLineBox extends StatelessWidget {
  const RaftInlineLineBox({
    super.key,
    required this.style,
    required this.child,
  });
  final TextStyle style;
  final Widget child;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: child,
        ),
      ],
    ),
    style: style,
    strutStyle: StrutStyle.fromTextStyle(style),
    textScaler: TextScaler.noScaling,
  );
}

/// Grows the hit-test and semantics rectangle of [child] to [minSize]
/// (centred) without changing layout, so a Web-sized control keeps the
/// native touch target while every pixel stays where the Web puts it.
class RaftTouchTargetExpander extends SingleChildRenderObjectWidget {
  const RaftTouchTargetExpander({
    super.key,
    required this.minSize,
    required super.child,
  });
  final Size minSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTouchTargetExpander(minSize);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTouchTargetExpander renderObject,
  ) => renderObject.minSize = minSize;
}

class _RenderTouchTargetExpander extends RenderProxyBox {
  _RenderTouchTargetExpander(this._minSize);
  Size _minSize;
  set minSize(Size value) {
    if (value == _minSize) return;
    _minSize = value;
    markNeedsSemanticsUpdate();
  }

  Rect get _target {
    final w = size.width < _minSize.width ? _minSize.width : size.width;
    final h = size.height < _minSize.height ? _minSize.height : size.height;
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: w,
      height: h,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_target.contains(position)) return false;
    final clamped = Offset(
      position.dx.clamp(0, size.width).toDouble(),
      position.dy.clamp(0, size.height).toDouble(),
    );
    if (hitTestChildren(result, position: clamped) || hitTestSelf(clamped)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  Rect get semanticBounds => _target;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // Own the control's node so its rectangle is the expanded target.
    config
      ..isSemanticBoundary = true
      ..isMergingSemanticsOfDescendants = true;
  }
}
