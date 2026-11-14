// Web v1.24 TaskHandoffCard: a task handed to someone with a reason, in the
// task's conversation, is a card ("[avatar] @Otter -> [avatar] @xxchan", the
// time, the reason as the body) instead of the server's one-line notice. When
// the task later came back to whoever handed it off, the card fades and says
// who took it back. The app reads the notice and finds the return.
import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftTypography;
import 'message_row_recipe.dart' show RaftMessageBodyMargin;
import 'rich_card_tokens.dart';
import 'space.dart';
import 'theme.dart';

class RaftTaskHandoffCard extends StatelessWidget {
  const RaftTaskHandoffCard({
    super.key,
    required this.from,
    required this.to,
    required this.fromAvatar,
    required this.toAvatar,
    required this.reason,
    required this.time,
    required this.semanticLabel,
    this.returnedLabel,
  });

  /// Who handed it over and who got it, as the title names them (`@handle`).
  final String from, to;

  /// Each party's avatar at the size of a name in text.
  final Widget fromAvatar, toAvatar;
  final String reason, time, semanticLabel;

  /// "Otter took it back · 10:51"; null while the wait is open.
  final String? returnedLabel;

  Widget _party(Widget avatar, String name, TextStyle style) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: RaftSpace.x1,
    children: [
      SizedBox.square(dimension: RaftSpace.x4, child: avatar),
      Flexible(child: Text(name, style: style)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = ActionSnapshotRecipe(t);
    final returned = returnedLabel != null;
    final body = RaftTypography.body(
      t,
      size: 14,
      line: 20,
      color: t.colors['foreground'],
    );
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: returned ? .6 : 1,
          child: SizedBox(
            key: ValueKey(
              returned ? 'task-handoff-card-returned' : 'task-handoff-card',
            ),
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.only(
                top: RaftMessageBodyMargin.collapse(context, recipe.topGap),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: recipe.background,
                  border: Border.fromBorderSide(recipe.border),
                ),
                child: Padding(
                  padding: recipe.inset + EdgeInsets.all(recipe.border.width),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: RaftSpace.x1,
                    children: [
                      Wrap(
                        spacing: RaftSpace.x1,
                        runSpacing: RaftSpace.x1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _party(fromAvatar, from, recipe.title),
                          Text('→', style: recipe.title),
                          _party(toAvatar, to, recipe.title),
                        ],
                      ),
                      Text(
                        key: const ValueKey('task-handoff-meta'),
                        returnedLabel ?? time,
                        style: recipe.summary,
                      ),
                      Text(
                        reason,
                        key: const ValueKey('task-handoff-reason'),
                        style: body,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
