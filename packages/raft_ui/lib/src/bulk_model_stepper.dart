import 'package:flutter/material.dart';

import '../raft_ui.dart';

/// Web `Stepper` (BulkChangeModelDialog): "1 Choose model ─── 2 Review". Once
/// reviewing, step 1 turns into a check mark in the success colour and step 2
/// takes the strong ink. Brutal draws it bold, uppercase and with a 2px rule.
class RaftBulkModelStepper extends StatelessWidget {
  const RaftBulkModelStepper({super.key, required this.reviewing});
  final bool reviewing;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final strong = t.brutal ? Colors.black : t.colors['foreground-strong']!;
    final placeholder = t.brutal
        ? Colors.black
        : t.colors['foreground-placeholder']!;
    final done = t.brutal ? Colors.black : t.colors['success-strong']!;
    TextStyle style(Color color) => RaftTypography.body(
      t,
      size: 12,
      line: 16,
      weight: t.brutal ? FontWeight.w700 : FontWeight.w500,
      color: color,
    ).copyWith(letterSpacing: t.brutal ? 0.3 : null);
    String label(String source) {
      final text = raftText(context, source);
      return t.brutal ? text.toUpperCase() : text;
    }

    Widget step(Widget marker, String text, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 4),
        Flexible(
          child: RaftCssText(
            label(text),
            style: style(color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    Widget number(int n, Color color) => RaftCssText('$n', style: style(color));
    final first = reviewing ? done : strong;
    final second = reviewing ? strong : placeholder;
    return Semantics(
      container: true,
      child: Row(
        key: const ValueKey('bulk-model-stepper'),
        children: [
          Flexible(
            child: step(
              reviewing
                  ? RaftIcon(RaftGlyph.check, size: 12, color: first)
                  : number(1, first),
              'Choose model',
              first,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: t.brutal ? 2 : 1,
              color: t.brutal ? Colors.black : t.colors['line-muted'],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: step(number(2, second), 'Review', second)),
        ],
      ),
    );
  }
}
