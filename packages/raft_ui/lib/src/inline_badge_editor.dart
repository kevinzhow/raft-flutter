import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'design_primitives.dart';
import 'recipe_surface.dart';
import '../recipes.dart';
import 'theme.dart';

/// One option of a [RaftInlineBadgeEditor] menu.
@immutable
class RaftInlineBadgeOption {
  const RaftInlineBadgeOption({
    required this.id,
    required this.label,
    this.disabled = false,
  });
  final String id;
  final String label;
  final bool disabled;
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
  final triggerFocus = FocusNode();
  final menuKey = GlobalKey<_RaftInlineBadgeMenuState>();
  bool? keyboardEdge;
  bool get isOpen => widget.enabled && (widget.open ?? ownedOpen);

  @override
  void dispose() {
    triggerFocus.dispose();
    super.dispose();
  }

  void openFromKeyboard({bool last = false}) {
    if (!widget.enabled) return;
    if (isOpen && menuKey.currentState != null) {
      menuKey.currentState!.focusEdge(last: last);
    } else {
      keyboardEdge = last;
      _setOpen(true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(RaftInlineBadgeEditor old) {
    super.didUpdateWidget(old);
    if (old.open == true &&
        !isOpen &&
        widget.enabled &&
        menuKey.currentState?.ownsFocus == true) {
      triggerFocus.requestFocus();
    }
    if (!widget.enabled) {
      ownedOpen = false;
      keyboardEdge = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted) return;
    if (isOpen && !portal.isShowing) portal.show();
    if (!isOpen && portal.isShowing) portal.hide();
  }

  void _setOpen(bool value, {bool restoreFocus = true}) {
    if (value && !widget.enabled) return;
    if (!value) {
      keyboardEdge = null;
      if (restoreFocus && widget.enabled) triggerFocus.requestFocus();
    }
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
    final inherited = DefaultTextStyle.of(context).style
        .merge(badge.textStyle(rt));
    final label = inherited.copyWith(
      // Badge sets no family: inherit the caller's mounted shell style.
      fontFamily: inherited.fontFamily,
      decoration: TextDecoration.none,
      fontSize: 12, // text-xs
      height: 16 / 12,
      fontWeight: FontWeight.w700, // font-bold
      color: widget.foreground,
      letterSpacing: widget.uppercase ? 12 * .025 : badge.letterSpacing,
    );
    Widget trigger(RaftInteractionState state) => Padding(
      padding: const EdgeInsets.only(top: 2), // mt-0.5 is outside the button.
      child: CustomPaint(
        foregroundPainter: state.focusVisible
            ? _BadgeFocusOutline(t.semantic.lineStrong, badge.borderRadius)
            : null,
        child: Container(
          // brutal Badge `h-5`; elegant has no fixed height (py-0.5 + 16px line).
          height: badge.height,
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
          foregroundDecoration: state.hovered && widget.enabled
              // Product InlineBadgeEditor: hover:brightness-90 in both families.
              ? BoxDecoration(
                  color: Colors.black.withValues(alpha: .1),
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
        ),
      ),
    );
    return OverlayPortal(
      controller: portal,
      overlayChildBuilder: (context) => !isOpen
          ? const SizedBox.shrink()
          : Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _setOpen(false, restoreFocus: false),
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
                        key: menuKey,
                        autofocus: keyboardEdge != null,
                        focusLast: keyboardEdge ?? false,
                        onDismiss: () => _setOpen(false),
                        minWidth: widget.menuMinWidth,
                        selectedId: widget.selectedId,
                        options: widget.options,
                        onSelect: (id) {
                          if (!mounted ||
                              !widget.enabled ||
                              !isOpen ||
                              !widget.options.any(
                                (o) => o.id == id && !o.disabled,
                              ))
                            return;
                          _setOpen(false);
                          widget.onSelect(id);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
      child: CompositedTransformTarget(
        link: link,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent || !widget.enabled)
              return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              if (isOpen) {
                _setOpen(false);
              } else {
                openFromKeyboard();
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              openFromKeyboard(
                last: event.logicalKey == LogicalKeyboardKey.arrowUp,
              );
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape && isOpen) {
              _setOpen(false);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            expanded: isOpen,
            child: RaftInteractive(
              focusNode: triggerFocus,
              semanticLabel: widget.tooltip ?? widget.label,
              tooltip: widget.tooltip,
              onPressed: widget.enabled
                  ? () {
                      if (triggerFocus.hasFocus) keyboardEdge = null;
                      _setOpen(!isOpen);
                    }
                  : null,
              builder: (context, state) => ExcludeSemantics(
                child: Opacity(
                  opacity: widget.enabled ? 1 : .6,
                  child: trigger(state),
                ),
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
class RaftInlineBadgeMenu extends StatefulWidget {
  const RaftInlineBadgeMenu({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelect,
    this.minWidth = 120,
    this.autofocus = false,
    this.focusLast = false,
    this.onDismiss,
  });
  final List<RaftInlineBadgeOption> options;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final double minWidth;
  final bool autofocus, focusLast;
  final VoidCallback? onDismiss;
  @override
  State<RaftInlineBadgeMenu> createState() => _RaftInlineBadgeMenuState();
}

class _RaftInlineBadgeMenuState extends State<RaftInlineBadgeMenu> {
  final nodes = <String, FocusNode>{};
  List<RaftInlineBadgeOption> get eligible =>
      widget.options.where((o) => !o.disabled).toList();
  bool get ownsFocus => nodes.values.any((node) => node.hasFocus);
  @override
  void initState() {
    super.initState();
    updateNodes();
    if (widget.autofocus)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusEdge(last: widget.focusLast);
      });
  }

  void updateNodes() {
    final ids = widget.options.map((o) => o.id).toSet();
    for (final id in nodes.keys.toList()) {
      if (!ids.contains(id)) nodes.remove(id)!.dispose();
    }
    for (final o in widget.options) {
      nodes.putIfAbsent(o.id, () => FocusNode());
      nodes[o.id]!.canRequestFocus = !o.disabled;
    }
  }

  @override
  void didUpdateWidget(RaftInlineBadgeMenu old) {
    super.didUpdateWidget(old);
    final focusedIds = nodes.entries
        .where((entry) => entry.value.hasFocus)
        .map((entry) => entry.key)
        .toSet();
    updateNodes();
    if (focusedIds.isNotEmpty &&
        !eligible.any((option) => focusedIds.contains(option.id))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusEdge();
      });
    }
  }

  @override
  void dispose() {
    for (final node in nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void focusEdge({bool last = false}) {
    if (eligible.isEmpty) return;
    nodes[(last ? eligible.last : eligible.first).id]!.requestFocus();
  }

  KeyEventResult keyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onDismiss?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) {
      focusEdge(last: key == LogicalKeyboardKey.end);
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp)
      return KeyEventResult.ignored;
    final rows = eligible;
    if (rows.isEmpty) return KeyEventResult.handled;
    final index = rows.indexWhere((o) => nodes[o.id]!.hasFocus);
    final next = index < 0
        ? (key == LogicalKeyboardKey.arrowUp ? rows.length - 1 : 0)
        : (index + (key == LogicalKeyboardKey.arrowUp ? -1 : 1)) % rows.length;
    nodes[rows[next].id]!.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final content = RaftDropdownMenuRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).content;
    return FocusScope(
      onKeyEvent: keyEvent,
      child: Semantics(
        role: SemanticsRole.menu,
        child: Container(
          constraints: BoxConstraints(minWidth: widget.minWidth),
          decoration: content.decoration(rt),
          clipBehavior: Clip.hardEdge,
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in widget.options)
                  _InlineBadgeMenuRow(
                    key: ValueKey(option.id),
                    option: option,
                    selected: option.id == widget.selectedId,
                    focusNode: nodes[option.id]!,
                    onPressed: () {
                      if (!mounted ||
                          !widget.options.any(
                            (o) => o.id == option.id && !o.disabled,
                          ))
                        return;
                      widget.onSelect(option.id);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineBadgeMenuRow extends StatefulWidget {
  const _InlineBadgeMenuRow({
    super.key,
    required this.option,
    required this.selected,
    required this.onPressed,
    required this.focusNode,
  });
  final RaftInlineBadgeOption option;
  final bool selected;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  @override
  State<_InlineBadgeMenuRow> createState() => _InlineBadgeMenuRowState();
}

class _InlineBadgeMenuRowState extends State<_InlineBadgeMenuRow> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(focusChanged);
  }

  void focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_InlineBadgeMenuRow old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(focusChanged);
      widget.focusNode.addListener(focusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(focusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    return RaftInteractive(
      focusNode: widget.focusNode,
      button: false,
      onPressed: widget.option.disabled ? null : widget.onPressed,
      builder: (context, state) {
        final button = RaftButtonRecipe.resolve(
          theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
          variant: RaftButtonRecipeVariant.ghost,
          size: RaftButtonRecipeSize.sm,
          states: t.recipeStates(
            hovered: state.hovered,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
            disabled: widget.option.disabled,
          ),
          tokens: rt,
        ).root;
        final foreground = widget.option.disabled
            ? (t.brutal ? Colors.black.withValues(alpha: .3) : t.muted)
            : (t.brutal ? Colors.black : t.strong);
        final hoverFill = t.brutal
            ? t.colors['color-soft-signal']!.withValues(alpha: .3)
            : t.colors['fill-muted']!;
        return Semantics(
          role: SemanticsRole.menuItem,
          selected: widget.selected,
          label: widget.option.label,
          enabled: !widget.option.disabled,
          focusable: !widget.option.disabled,
          focused: widget.option.disabled ? null : widget.focusNode.hasFocus,
          excludeSemantics: true,
          child: RaftRecipeBox(
            style: button,
            tokens: rt,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decorationOverride: (d) => d.copyWith(
              color: state.hovered ? hoverFill : null,
              border: t.brutal
                  ? Border.all(color: Colors.transparent, width: 2)
                  : null,
            ),
            child: DefaultTextStyle.merge(
              style: button
                  .textStyle(rt)
                  .copyWith(
                    fontFamily: t.bodyFont,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                    decoration: TextDecoration.none,
                  ),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      widget.option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Opacity(
                    opacity: widget.selected ? 1 : 0,
                    child: RaftIcon(
                      RaftGlyph.check,
                      size: 14,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BadgeFocusOutline extends CustomPainter {
  const _BadgeFocusOutline(this.color, this.radius);
  final Color color;
  final BorderRadius? radius;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    (radius ?? BorderRadius.zero).toRRect(Offset.zero & size).inflate(3),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  @override
  bool shouldRepaint(_BadgeFocusOutline old) =>
      old.color != color || old.radius != radius;
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
