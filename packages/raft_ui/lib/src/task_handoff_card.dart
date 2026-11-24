// Web v1.24 TaskHandoffCard: a task handed to someone with a reason, in the
// task's conversation, is a MessageActionCard ("[avatar] @Otter → [avatar]
// @xxchan", the time, the reason as the body) instead of the server's one-line
// notice. When the task later came back to whoever handed it off, the card
// fades (opacity-60) and says who took it back.
import 'package:flutter/material.dart';

import 'message_embed_frame.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/message_action_card.g.dart';
import 'recipes/message_card.g.dart';
import 'space.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

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

  /// Each party's avatar at the `creator-link` (`xs`, 19px) size.
  final Widget fromAvatar, toAvatar;
  final String reason, time, semanticLabel;

  /// "Otter took it back · 10:51"; null while the wait is open.
  final String? returnedLabel;

  Widget _party(Widget avatar, String name, TextStyle style) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    spacing: RaftSpace.x1,
    children: [
      avatar,
      RaftCssText(name, style: style),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final states = t.recipeStates(responsive: true);
    final recipe = RaftMessageActionCardRecipe.resolve(
      states: states,
      tokens: t.recipeTokens,
    );
    final card = RaftMessageCardRecipe.resolve(
      states: states,
      tokens: t.recipeTokens,
    );
    final returned = returnedLabel != null;
    final titleStyle = raftSlotTextStyle(t, card.heading);
    final descriptionStyle = raftSlotTextStyle(t, recipe.headerDescription);
    final rawMetaStyle = raftSlotTextStyle(t, recipe.headerMeta, tabular: true);
    final descriptionLine =
        (descriptionStyle.fontSize ?? 12) * (descriptionStyle.height ?? 1);
    final metaFontSize = rawMetaStyle.fontSize ?? 11;
    final metaLine = metaFontSize * (rawMetaStyle.height ?? 1);
    final metaStyle = metaLine < descriptionLine
        ? rawMetaStyle.copyWith(height: descriptionLine / metaFontSize)
        : rawMetaStyle;
    final bodyStyle = raftCssText.merge(
      t.scale(RaftTypeScale.callout, color: t.ui.foreground),
    );
    final inset = card.inset.padding;
    final headerPadding = inset.copyWith(bottom: recipe.header.padding.bottom);
    final tile = recipe.headerIcon.width ?? 27;
    final scaledFontSize = MediaQuery.textScalerOf(context)
        .scale(titleStyle.fontSize ?? 14);
    final titleTopOffset =
        ((tile - scaledFontSize * (titleStyle.height ?? 1)) / 2).clamp(
          0.0,
          tile,
        );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Padding(
          key: ValueKey(
            returned ? 'task-handoff-card-returned' : 'task-handoff-card',
          ),
          // Web TaskHandoffCard: `<div className="py-1">` wrapping
          // `<MessageActionCard>` (`mt-2` = 8px). Padding prevents CSS margin
          // collapse, so top = 4 + 8 = 12px and bottom = 4px.
          padding: const EdgeInsets.only(
            top: RaftSpace.x3,
            bottom: RaftSpace.x1,
          ),
          child: Opacity(
            opacity: returned ? .6 : 1,
            child: RaftMessageEmbedFrame(
              size: RaftMessageEmbedSize.item,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: headerPadding,
                    child: Padding(
                      padding: EdgeInsets.only(top: titleTopOffset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: recipe.headerDescription.margin.top,
                        children: [
                          Text.rich(
                            key: const ValueKey('task-handoff-title'),
                            strutStyle: StrutStyle.fromTextStyle(
                              titleStyle,
                              forceStrutHeight: true,
                            ),
                            TextSpan(
                              style: titleStyle,
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: _party(fromAvatar, from, titleStyle),
                                ),
                                TextSpan(
                                  text: ' → ',
                                  style: titleStyle.copyWith(
                                    fontFamily: 'Inter',
                                    package: 'raft_ui',
                                    fontWeight: FontWeight.w400,
                                    fontVariations: const [
                                      FontVariation.weight(400),
                                    ],
                                  ),
                                ),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: _party(toAvatar, to, titleStyle),
                                ),
                              ],
                            ),
                          ),
                          RaftCssText(
                            key: const ValueKey('task-handoff-meta'),
                            returnedLabel ?? time,
                            style: returned ? descriptionStyle : metaStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: inset.copyWith(top: 0),
                    child: RaftCssText(
                      reason,
                      key: const ValueKey('task-handoff-reason'),
                      style: bodyStyle,
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
