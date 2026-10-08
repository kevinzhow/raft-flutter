import 'package:flutter/material.dart';

import 'design_primitives.dart';
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
  @override
  Color get background => tokens.brutal
      ? tokens.colors[switch (status) {
          RaftMessageTaskStatus.todo => 'color-brutal-orange',
          RaftMessageTaskStatus.inProgress => 'color-brutal-cyan',
          RaftMessageTaskStatus.inReview => 'color-brutal-lavender',
          RaftMessageTaskStatus.done => 'color-brutal-lime',
          RaftMessageTaskStatus.closed => 'color-brutal-stone',
        }]!
      : switch (status) {
          RaftMessageTaskStatus.todo ||
          RaftMessageTaskStatus.closed => tokens.colors['ink-4']!,
          RaftMessageTaskStatus.inProgress => _opacity(
            tokens.colors['primary-500']!,
            .1,
          ),
          RaftMessageTaskStatus.inReview => _opacity(
            tokens.colors['warning']!,
            .1,
          ),
          RaftMessageTaskStatus.done => _opacity(tokens.colors['success']!, .1),
        };
  @override
  Color get foreground => tokens.brutal
      ? Colors.black
      : switch (status) {
          RaftMessageTaskStatus.todo ||
          RaftMessageTaskStatus.closed => tokens.ink,
          RaftMessageTaskStatus.inProgress =>
            tokens.colors[tokens.dark
                ? 'primary-strong'
                : 'color-brutal-yellow-800']!,
          RaftMessageTaskStatus.inReview => tokens.colors['warning-strong']!,
          RaftMessageTaskStatus.done => tokens.colors['success-strong']!,
        };
  Color get iconForeground => tokens.brutal
      ? Colors.black
      : switch (status) {
          RaftMessageTaskStatus.todo =>
            tokens.colors['foreground-placeholder']!,
          // Exact source task-status-icon literal OKLCH values converted to sRGB.
          RaftMessageTaskStatus.inProgress => const Color(0xffefb400),
          RaftMessageTaskStatus.inReview => const Color(0xffed8725),
          RaftMessageTaskStatus.done => tokens.colors['success']!,
          RaftMessageTaskStatus.closed => tokens.colors['inactive']!,
        };
  @override
  Color backgroundFor({bool hovered = false}) => background;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => background;
  @override
  Color foregroundFor({bool hovered = false}) => foreground;
  @override
  BorderSide side({bool hovered = false}) => BorderSide(
    width: borderWidth,
    color: tokens.brutal
        ? Colors.black
        : _opacity(
            tokens.colors[switch (status) {
              RaftMessageTaskStatus.todo ||
              RaftMessageTaskStatus.closed => 'line-muted',
              RaftMessageTaskStatus.inProgress => 'primary-500',
              RaftMessageTaskStatus.inReview => 'warning',
              RaftMessageTaskStatus.done => 'success',
            }]!,
            .75,
          ),
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
/// [openLabel] and [tooltipLabel] must come from the app's localized projection.
/// The app owns permission checks and task intent routing; this never edits a
/// task, reads a store, opens a menu, or requests a network resource.
class RaftMountedMessageTaskChip extends StatefulWidget {
  const RaftMountedMessageTaskChip({
    super.key,
    required this.number,
    required this.status,
    required this.title,
    required this.openLabel,
    required this.tooltipLabel,
    this.claimant,
    this.onOpen,
    this.loading = false,
    this.focusNode,
  });
  final int number;
  final RaftMessageTaskStatus status;
  final String title, openLabel, tooltipLabel;
  final String? claimant;
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
    return MouseRegion(
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
              height: recipe.chipHeight,
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
                    inverse: tokens.colors['foreground-inverse']!,
                  ),
                  Text('#${widget.number}'),
                  if (widget.claimant != null && widget.claimant!.isNotEmpty)
                    Flexible(
                      child: Text(
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

/// RUI TaskStatusIcon geometry (viewBox 1.2 1.2 21.6 21.6), not Lucide Play/Eye.
class RaftMessageTaskStatusIcon extends StatelessWidget {
  const RaftMessageTaskStatusIcon({
    super.key,
    required this.status,
    required this.color,
    required this.inverse,
  });
  final RaftMessageTaskStatus status;
  final Color color, inverse;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 12,
      child: CustomPaint(painter: _TaskIconPainter(status, color, inverse)),
    ),
  );
}

class _TaskIconPainter extends CustomPainter {
  const _TaskIconPainter(this.status, this.color, this.inverse);
  final RaftMessageTaskStatus status;
  final Color color, inverse;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 21.6, size.height / 21.6);
    canvas.translate(-1.2, -1.2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (status == RaftMessageTaskStatus.done ||
        status == RaftMessageTaskStatus.closed) {
      // Preserve the source's asymmetric SVG arc path, not a substitute icon.
      final filled = Path()
        ..moveTo(17, 3.34)
        ..relativeArcToPoint(
          const Offset(-14.995, 8.984),
          radius: const Radius.circular(10),
          largeArc: true,
        )
        ..relativeLineTo(-.005, -.324)
        ..relativeLineTo(.005, -.324)
        ..relativeArcToPoint(
          const Offset(14.995, -8.336),
          radius: const Radius.circular(10),
        )
        ..close();
      canvas.drawPath(filled, Paint()..color = color);
      final mark = Path()
        ..moveTo(8.5, status == RaftMessageTaskStatus.done ? 12 : 8.5);
      if (status == RaftMessageTaskStatus.done) {
        mark
          ..relativeLineTo(2.5, 2.5)
          ..relativeLineTo(4.5, -5);
      } else {
        mark
          ..relativeLineTo(7, 7)
          ..relativeMoveTo(0, -7)
          ..relativeLineTo(-7, 7);
      }
      stroke.color = inverse;
      stroke.strokeWidth = 2.25;
      canvas.drawPath(mark, stroke);
      return;
    }
    canvas.drawCircle(const Offset(12, 12), 9, stroke);
    if (status == RaftMessageTaskStatus.inProgress) {
      final hatch = Path()
        ..moveTo(12, 3)
        ..lineTo(12, 21)
        ..moveTo(12, 14)
        ..relativeLineTo(7, -7)
        ..moveTo(12, 19)
        ..relativeLineTo(8.5, -8.5)
        ..moveTo(12, 9)
        ..relativeLineTo(4.5, -4.5);
      canvas.drawPath(hatch, stroke);
    } else if (status == RaftMessageTaskStatus.inReview) {
      canvas.drawCircle(const Offset(12, 12), 1, stroke);
    }
  }

  @override
  bool shouldRepaint(_TaskIconPainter oldDelegate) =>
      oldDelegate.status != status ||
      oldDelegate.color != color ||
      oldDelegate.inverse != inverse;
}
