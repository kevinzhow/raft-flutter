import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'theme.dart';
import 'popover_surface.dart';

const raftQuickReactions = ['👍', '❤️', '🎉', '👀', '🔥', '😂', '✅'];

/// Mounted MessageItem quick reaction BUTTON. Product overrides do not inherit
/// primary-button motion or minimum touch size; the source surface is 28px.
@immutable
class RaftQuickReactionRecipe extends RaftControlRecipe {
  const RaftQuickReactionRecipe(super.tokens)
    : super(variant: RaftControlVariant.ghost, visualHeight: 28);
  @override
  bool get transformsOnInteraction => false;
  @override
  BorderRadius get radius => BorderRadius.circular(4);
  @override
  EdgeInsets get padding => EdgeInsets.zero;
  @override
  Color get background => Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => !hovered
      ? background
      : tokens.brutal
      ? tokens.colors['color-brutal-pink']!.withValues(alpha: .2)
      : tokens.accentSoft;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered);
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => const [];
}

/// Plain source popup: seven buttons in source order. No menu/roving-focus roles
/// are invented: the Web portal leaves opener focus alone and uses normal Tab.
/// The authorized overlay owner controls placement, outside-pointer dismissal,
/// scrolling/resize closure, scoped mutation and the 120ms boundary timer.
///
/// [glyphBuilder] supplies original source-sprite pixels for the seven known
/// values. Platform emoji is not an equivalent substitute for these assets.
/// The default uses the shared source Popover surface (Brutal LG/Elegant XL).
/// [popupDecoration] remains an explicit caller override.
class RaftQuickReactionPicker extends StatefulWidget {
  const RaftQuickReactionPicker({
    super.key,
    required this.glyphBuilder,
    required this.labelBuilder,
    required this.onSelect,
    required this.onDismiss,
    this.returnFocusNode,
    this.popupDecoration,
    this.onBoundaryEnter,
    this.onBoundaryLeave,
    this.enabled = true,
  });
  final Widget Function(String reaction) glyphBuilder;
  final String Function(String reaction) labelBuilder;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;
  final FocusNode? returnFocusNode;
  final BoxDecoration? popupDecoration;
  final VoidCallback? onBoundaryEnter, onBoundaryLeave;
  final bool enabled;
  @override
  State<RaftQuickReactionPicker> createState() =>
      _RaftQuickReactionPickerState();
}

class _RaftQuickReactionPickerState extends State<RaftQuickReactionPicker> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(key);
  }

  KeyEventResult key(KeyEvent event) {
    if (!mounted ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape)
      return KeyEventResult.ignored;
    final returnFocus = widget.returnFocusNode;
    widget.onDismiss();
    if (returnFocus?.context != null) returnFocus!.requestFocus();
    // Source capture-phase Escape closes this popup before background routing.
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(key);
    super.dispose();
  }

  Widget surface(Widget content) => widget.popupDecoration == null
      ? RaftPopoverSurface(child: content)
      : DecoratedBox(decoration: widget.popupDecoration!, child: content);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftQuickReactionRecipe(t);
    return MouseRegion(
      onEnter: (_) => widget.onBoundaryEnter?.call(),
      onExit: (_) => widget.onBoundaryLeave?.call(),
      child: surface(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < raftQuickReactions.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                RaftControl(
                  key: ValueKey('quick-reaction-${raftQuickReactions[i]}'),
                  recipe: recipe,
                  onPressed: widget.enabled
                      ? () => widget.onSelect(raftQuickReactions[i])
                      : null,
                  semanticLabel: widget.labelBuilder(raftQuickReactions[i]),
                  tooltip: widget.labelBuilder(raftQuickReactions[i]),
                  minimumTargetSize: 28,
                  visualHeight: 28,
                  visualWidth: 28,
                  padding: EdgeInsets.zero,
                  child: ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 18,
                      child: widget.glyphBuilder(raftQuickReactions[i]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
