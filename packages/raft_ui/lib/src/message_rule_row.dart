import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// `flex items-center gap-* ... before:flex-1 after:flex-1 before:border-t
/// after:border-t min-w-3` (raft-ui SystemMessage and MessageListDateDivider):
/// a content cluster of its natural width between two 1px rules that share the
/// rest of the row. The cluster shrinks (and truncates) before the rules drop
/// under [minRule].
class RaftMessageRuleRow extends StatelessWidget {
  const RaftMessageRuleRow({
    super.key,
    required this.naturalWidth,
    required this.child,
    required this.ruleColor,
    this.gap = 8,
    this.minRule = 12,
    this.beforeKey,
    this.afterKey,
  });

  /// The width [child] takes when nothing truncates it.
  final double naturalWidth;
  final Widget child;
  final Color ruleColor;
  final double gap, minRule;
  final Key? beforeKey, afterKey;

  @override
  Widget build(BuildContext context) {
    Widget rule(Key? key) => Expanded(
      child: SizedBox(
        key: key,
        height: 1,
        child: ColoredBox(color: ruleColor),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = math.max(0.0, constraints.maxWidth - 2 * (gap + minRule));
        return Row(
          children: [
            rule(beforeKey),
            SizedBox(width: gap),
            SizedBox(width: math.min(naturalWidth, room), child: child),
            SizedBox(width: gap),
            rule(afterKey),
          ],
        );
      },
    );
  }
}

/// Natural single-line width of [spans] in [style], at the reader's text scale.
double raftMessageTextWidth(
  BuildContext context,
  String text,
  TextStyle style,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
