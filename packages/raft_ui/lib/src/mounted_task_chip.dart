import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'space.dart';
import 'panel_layout.dart' show RaftCssText;
import 'theme.dart';
import 'raft/ui_tokens.dart';

/// The status vocabulary is intentionally closed. The app must omit unknown
/// projections rather than render an invented Todo state.
enum RaftMessageTaskStatus { backlog, todo, inProgress, inReview, done, closed }

/// MessageItem's mounted default TaskChip, NOT the parked TaskChipList or the
/// independent editable TaskStatus badge. RUI 19273-19414; MessageItem 4857-4901.
@immutable
class RaftMessageTaskChipRecipe extends RaftControlRecipe {
  const RaftMessageTaskChipRecipe(super.tokens, this.status)
    : super(variant: RaftControlVariant.ghost);
  final RaftMessageTaskStatus status;
  bool get squareStatus =>
      tokens.option('task.status', or: 'symbol') == 'square';
  double get chipHeight => squareStatus ? 22 : 19;
  double get gap => 6;
  double get borderWidth => .5;
  double get hoverBrightness => .96;
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
  BorderRadius get radius => BorderRadius.circular(
    squareStatus ? tokens.size('radius.chip', fallback: 5) : 999,
  );

  /// raft-ui 0.95.3 TaskChip `default`: `h-[22px] gap-1.5 px-[7px]`
  /// (0.7.0 was `pr-2 pl-1.5`).
  @override
  EdgeInsets get padding =>
      // ignore: raft_lints/off_grid_spacing -- TaskChip's `px-[7px]` is an explicit arbitrary value in the raft-ui 0.95.3 source, not a spacing step.
      EdgeInsets.symmetric(horizontal: squareStatus ? 7 : 8);
  String get _token => tokenOf(status);

  /// The `--task-status-*` token a status paints with. The one place a task
  /// surface reads a status colour from: the chip, the status badge, the
  /// editor trigger and the history marker all resolve this token.
  static String tokenOf(RaftMessageTaskStatus status) => switch (status) {
    // Backlog has no hue (raft-ui 0.95.3): it never reads this token.
    RaftMessageTaskStatus.backlog => 'task-status-todo',
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
      backlog ? Colors.transparent : tokens.colors['$_token-soft']!;

  /// raft-ui 0.95.3 backlog: `bg-transparent inset-ring
  /// inset-ring-line-hairline text-foreground`, no status hue.
  bool get backlog => status == RaftMessageTaskStatus.backlog;

  /// Brutal `text-black`; elegant the status' strong ink.
  @override
  Color get foreground => squareStatus || backlog
      ? tokens.ui.foreground
      : tokens.colors['$_token-strong']!;

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
  BorderSide side({bool hovered = false}) => backlog
      ? BorderSide(
          width: RaftSpace.hairline,
          color: tokens.colors['line-hairline']!,
        )
      : squareStatus
      ? BorderSide.none
      : BorderSide(
          width: borderWidth,
          color: _opacity(tokens.colors['$_token-strong']!, .35),
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
    size: squareStatus ? 12 : 13,
    line: squareStatus ? 16 : 13,
    weight: squareStatus ? FontWeight.w600 : FontWeight.w400,
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
    RaftMessageTaskStatus.backlog => RaftGlyph.circle,
    RaftMessageTaskStatus.todo => RaftGlyph.circle,
    RaftMessageTaskStatus.inProgress => RaftGlyph.play,
    RaftMessageTaskStatus.inReview => RaftGlyph.eye,
    RaftMessageTaskStatus.done => RaftGlyph.checkCircle,
    RaftMessageTaskStatus.closed => RaftGlyph.ban,
  };

  /// raft-ui 0.95.3 `TaskStatusPixel`: a 10px square (8.5 + the 1.5px edge)
  /// that is also its slot in a chip (`[&>svg[data-slot=task-status-icon]]:
  /// size-2.5`); 0.7.0 drew it at 9. The frozen looks keep 9 for Backlog.
  static double pixelOf(RaftTokens tokens) =>
      tokens.option('task.status', or: 'symbol') == 'square' ? 10 : 9;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final square = t.option('task.status', or: 'symbol') == 'square';
    final pixel = pixelOf(t);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: square ? pixel : size,
        // Backlog (raft-ui 0.95.3 TaskBacklogIcon) is the status pixel,
        // hollow, with a `line-strong` edge (sticker-ink would vanish on a
        // dark canvas).
        child: status == RaftMessageTaskStatus.backlog || square
            ? Center(
                child: Container(
                  width: pixel,
                  height: pixel,
                  decoration: BoxDecoration(
                    color: status == RaftMessageTaskStatus.backlog
                        ? null
                        : t.colors[RaftMessageTaskChipRecipe.tokenOf(status)],
                    border: Border.all(
                      color: status == RaftMessageTaskStatus.backlog
                          ? t.colors['line-strong']!
                          : t.ui.stickerInk,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )
            : RaftIcon(glyphOf(status), size: size, color: color),
      ),
    );
  }
}
