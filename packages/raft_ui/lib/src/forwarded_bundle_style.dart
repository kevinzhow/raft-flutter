// The Raft look's forwarded bundle (raft-ui 0.95.3 message-forwarded-bundle
// recipes on the `messageEmbed` frame): every size, weight, colour and inset
// is read from the generated slots. The frozen looks keep
// `ForwardedSnapshotRecipe` (rich_card_tokens.dart).
import 'package:flutter/widgets.dart';

import 'message_embed_frame.dart';
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/message_forwarded_bundle.g.dart';
import 'recipes/message_forwarded_bundle_item.g.dart';
import 'theme.dart';

@immutable
class RaftForwardedBundleStyle {
  const RaftForwardedBundleStyle({
    required this.headerPadding,
    required this.footerPadding,
    required this.itemPadding,
    required this.label,
    required this.count,
    required this.source,
    required this.sourceHover,
    required this.meta,
    required this.author,
    required this.footer,
    required this.foreground,
    required this.fade,
    required this.headerGap,
    required this.metaGap,
    required this.metaBottom,
    required this.collapsedHeight,
  });

  final EdgeInsets headerPadding, footerPadding, itemPadding;
  final TextStyle label, count, source, sourceHover, meta, author, footer;
  final Color foreground, fade;
  final double headerGap, metaGap, metaBottom, collapsedHeight;

  factory RaftForwardedBundleStyle.of(BuildContext context) {
    final t = RaftTokens.of(context);
    final states = t.recipeStates(responsive: true);
    final embed = raftMessageEmbedSlots(context);
    final bundle = RaftMessageForwardedBundleRecipe.resolve(
      theme: t.recipeTheme,
      collapsed: true,
      states: states,
      tokens: t.recipeTokens,
    );
    final item = RaftMessageForwardedBundleItemRecipe.resolve(
      theme: t.recipeTheme,
      states: states,
      tokens: t.recipeTokens,
    );
    final hoverStates = t.recipeStates(responsive: true, hovered: true);
    final hovered = RaftMessageForwardedBundleRecipe.resolve(
      theme: t.recipeTheme,
      states: hoverStates,
      tokens: t.recipeTokens,
    );
    return RaftForwardedBundleStyle(
      headerPadding: embed.header.padding,
      footerPadding: embed.footer.padding,
      itemPadding: item.root.padding,
      label: raftSlotTextStyle(t, bundle.headerLabel),
      count: raftSlotTextStyle(t, bundle.headerCount),
      source: raftSlotTextStyle(t, bundle.source),
      sourceHover: raftSlotTextStyle(t, hovered.source),
      meta: raftSlotTextStyle(t, item.meta, tabular: true),
      author: raftSlotTextStyle(t, item.author),
      footer: raftSlotTextStyle(t, bundle.footerAction),
      foreground: t.ui.foreground,
      fade: t.ui.layerCard,
      headerGap: bundle.header.columnGap ?? 8,
      metaGap: item.meta.columnGap ?? 6,
      metaBottom: item.meta.margin.bottom,
      // `max-h-40` of the collapsed `items` slot.
      collapsedHeight: bundle.items.maxHeight ?? 160,
    );
  }
}
