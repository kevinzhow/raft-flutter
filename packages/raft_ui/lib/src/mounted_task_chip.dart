import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'panel_layout.dart' show RaftCssText;
import 'theme.dart';

/// The status vocabulary is intentionally closed. The app must omit unknown
/// projections rather than render an invented Todo state.
enum RaftMessageTaskStatus { todo, inProgress, inReview, done, closed }

/// MessageItem's mounted default TaskChip, NOT the parked TaskChipList or the
/// independent editable TaskStatus badge. RUI 19273-19414; MessageItem 4857-4901.
@immutable
class RaftMessageTaskChipRecipe extends RaftControlRecipe {
  const RaftMessageTaskChipRecipe(super.tokens, this.status)
    : super(variant: RaftControlVariant.ghost);
  final RaftMessageTaskStatus status;
  double get chipHeight => tokens.brutal ? 13 * 1.25 + 2 : 19;
  double get gap => tokens.brutal ? 4 : 6;
  double get borderWidth => tokens.brutal ? 1 : .5;
  double get hoverBrightness => tokens.brutal ? .90 : .96;
  @override
  bool get transformsOnInteraction => false;
  @override
  double get disabledOpacity => .6;
  @override
  double get focusOutlineWidth => 2;
  @override
  double get focusOutlineOffset => 2;
  @override
  Color get focusRing => tokens.colors['line-strong']!;
  @override
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 999);
  @override
  EdgeInsets get padding =>
      EdgeInsets.symmetric(horizontal: tokens.brutal ? 4 : 8);
  String get _token => switch (status) {
    RaftMessageTaskStatus.todo => 'task-status-todo',
    RaftMessageTaskStatus.inProgress => 'task-status-in-progress',
    RaftMessageTaskStatus.inReview => 'task-status-in-review',
    RaftMessageTaskStatus.done => 'task-status-done',
    RaftMessageTaskStatus.closed => 'task-status-closed',
  };

  /// Brutal: the solid `taskStatus` fill. Elegant: the status' soft wash
  /// (raft-ui 0.5.30+: colours come from the `--task-status-*` tokens).
  @override
  Color get background =>
      tokens.colors[tokens.brutal ? _token : '$_token-soft']!;

  /// Brutal `text-black`; elegant the status' strong ink.
  @override
  Color get foreground =>
      tokens.brutal ? Colors.black : tokens.colors['$_token-strong']!;

  /// `TaskStatusIcon`: the strong token (elegant); brutal paints `currentColor`.
  Color get iconForeground => foreground;
  @override
  Color backgroundFor({bool hovered = false}) => background;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => background;
  @override
  Color foregroundFor({bool hovered = false}) => foreground;

  /// Brutal `border-black`; elegant the strong token at 35% (`color-mix`).
  @override
  BorderSide side({bool hovered = false}) => BorderSide(
    width: borderWidth,
    color: tokens.brutal
        ? Colors.black
        : _opacity(tokens.colors['$_token-strong']!, .35),
  );
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => const [];
  @override
  TextStyle get textStyle => RaftTypography.body(
    tokens,
    size: 13,
    line: tokens.brutal ? 13 * 1.25 : 13,
    weight: tokens.brutal ? FontWeight.w500 : FontWeight.w400,
    color: foreground,
  ).copyWith(letterSpacing: 0);
  static Color _opacity(Color color, double factor) =>
      color.withValues(alpha: color.a * factor);
}

// The mounted wrapper is an unstyled rectangular <button>, while its child
// TaskChip paints the pill. Global product focus-visible outlines the wrapper;
// an unfocusable inner span's rounded outline must not replace that contract.
class _TaskChipButtonRecipe extends RaftMessageTaskChipRecipe {
  const _TaskChipButtonRecipe(super.tokens, super.status);
  @override
  Color get background => Colors.transparent;
  @override
  BorderRadius get radius => BorderRadius.zero;
  @override
  EdgeInsets get padding => EdgeInsets.zero;
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
}

/// Controlled footer reference: #number and optional @claimant are painted;
/// [title] is accessible metadata, not an additional visible task title.
/// [openLabel] must come from the app's localized projection. There is no
/// tooltip by default: one repeating the painted #number/@claimant adds
/// nothing; pass [tooltipLabel] only for text that is not visible elsewhere.
/// The app owns permission checks and task intent routing; this never edits a
/// task, reads a store, opens a menu, or requests a network resource.
class RaftMountedMessageTaskChip extends StatefulWidget {
  const RaftMountedMessageTaskChip({
    super.key,
    required this.number,
    required this.status,
    required this.title,
    required this.openLabel,
    this.tooltipLabel,
    this.claimant,
    this.onOpen,
    this.loading = false,
    this.focusNode,
  });
  final int number;
  final RaftMessageTaskStatus status;
  final String title, openLabel;
  final String? tooltipLabel, claimant;
  final VoidCallback? onOpen;
  final bool loading;
  final FocusNode? focusNode;
  @override
  State<RaftMountedMessageTaskChip> createState() =>
      _RaftMountedMessageTaskChipState();
}

class _RaftMountedMessageTaskChipState
    extends State<RaftMountedMessageTaskChip> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final recipe = RaftMessageTaskChipRecipe(tokens, widget.status);
    final enabled = widget.onOpen != null && !widget.loading;
    final brightness = enabled && hovered ? recipe.hoverBrightness : 1.0;
    return RaftHoverRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: brightness),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 100),
        curve: const Cubic(.25, .1, .25, 1),
        builder: (context, filterBrightness, child) => ColorFiltered(
          // Source filter:brightness, applied to the entire chip including icon,
          // border and inverse check strokes. No generic Button gradient/shadow.
          colorFilter: ColorFilter.matrix([
            filterBrightness,
            0,
            0,
            0,
            0,
            0,
            filterBrightness,
            0,
            0,
            0,
            0,
            0,
            filterBrightness,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: child,
        ),
        child: RaftControl(
          recipe: _TaskChipButtonRecipe(tokens, widget.status),
          onPressed: enabled ? widget.onOpen : null,
          focusNode: widget.focusNode,
          semanticLabel: widget.openLabel,
          tooltip: widget.tooltipLabel,
          visualHeight: recipe.chipHeight,
          minimumTargetSize: recipe.chipHeight,
          child: ExcludeSemantics(
            child: Container(
              // The chip height is a minimum: larger text grows the chip
              // instead of clipping the `#8` / `@name` labels.
              constraints: BoxConstraints(minHeight: recipe.chipHeight),
              padding: recipe.padding,
              decoration: BoxDecoration(
                color: recipe.background,
                borderRadius: recipe.radius,
                border: Border.fromBorderSide(recipe.side()),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: recipe.gap,
                children: [
                  RaftMessageTaskStatusIcon(
                    status: widget.status,
                    color: recipe.iconForeground,
                  ),
                  // Blink line boxes: rounded ascent + floored half-leading
                  // (13px at a 16.25px line sits a whole px above Flutter's
                  // fractional even-leading baseline).
                  RaftCssText('#${widget.number}'),
                  if (widget.claimant != null && widget.claimant!.isNotEmpty)
                    Flexible(
                      child: RaftCssText(
                        '@${widget.claimant}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// raft-ui `TaskStatusIcon` (0.5.30+): the app's lucide `Circle`, `Play`,
/// `Eye`, `CheckCircle` and `Ban`, 12px (`[&>svg]:size-3`), coloured by the
/// caller (the chip's strong token; brutal `currentColor`).
class RaftMessageTaskStatusIcon extends StatelessWidget {
  const RaftMessageTaskStatusIcon({
    super.key,
    required this.status,
    required this.color,
    this.size = 12,
  });
  final RaftMessageTaskStatus status;
  final Color color;
  final double size;

  static RaftGlyph glyphOf(RaftMessageTaskStatus status) => switch (status) {
    RaftMessageTaskStatus.todo => RaftGlyph.circle,
    RaftMessageTaskStatus.inProgress => RaftGlyph.play,
    RaftMessageTaskStatus.inReview => RaftGlyph.eye,
    RaftMessageTaskStatus.done => RaftGlyph.checkCircle,
    RaftMessageTaskStatus.closed => RaftGlyph.ban,
  };

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: RaftIcon(glyphOf(status), size: size, color: color),
    ),
  );
}
