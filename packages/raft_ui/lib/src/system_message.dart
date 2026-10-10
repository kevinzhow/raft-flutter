import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'theme.dart';
import 'tooltip.dart';

/// Mounted SystemMessage (raft-ui0.5.27). The adapter supplies formatted receipt
/// text/time; system rows have no author/avatar, reactions or message toolbar.
class RaftSystemMessageRecipe {
  const RaftSystemMessageRecipe(this.tokens);
  final RaftTokens tokens;
  EdgeInsets get padding =>
      const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
  Color get clockColor =>
      (tokens.dark ? tokens.strong : Colors.black).withValues(alpha: .4);
  Color get contentColor =>
      (tokens.dark ? tokens.strong : Colors.black).withValues(alpha: .5);
  TextStyle get clock =>
      (tokens.brutal
              ? RaftTypography.mono(tokens, size: 12, line: 16)
              : RaftTypography.body(
                  tokens,
                  size: 11,
                  line: 16.5,
                  weight: FontWeight.w500,
                ))
          .copyWith(
            color: clockColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          );
  TextStyle get content => RaftTypography.body(
    tokens,
    size: 12,
    line: tokens.brutal ? 16 : 18,
    color: contentColor,
  );
}

class RaftSystemMessage extends StatelessWidget {
  const RaftSystemMessage({
    super.key,
    required this.content,
    required this.timestamp,
    this.tooltip,
  });
  final String content, timestamp;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftSystemMessageRecipe(RaftTokens.of(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: recipe.padding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(timestamp, style: recipe.clock),
            const SizedBox(width: 8),
            Flexible(
              // The line already says it; the full text only helps when cut.
              child: RaftTooltip(
                message: tooltip ?? content,
                onlyWhenTruncated: tooltip == null,
                child: Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
