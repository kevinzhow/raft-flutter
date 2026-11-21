import 'package:flutter/widgets.dart';

import 'design_primitives.dart';
import 'panel_layout.dart' show RaftCssInlineBox, RaftCssText;
import 'raft/badge.dart';
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/badge.g.dart';
import 'space.dart';
import 'text_scaling.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// ArtifactsDashboardToolbar, TileGrid and ArtifactsTable in Web v1.24.
abstract final class RaftArtifactCollectionLayout {
  static const columnMargin = RaftLayoutMetrics.panelInset;
  static const narrowSearchWidth = 160.0;
  static const searchWidth = 260.0;
  static const tileMinWidth = 248.0;
  static const tableTitleMinWidth = 200.0;

  /// ArtifactTile scales its FilePreview fallback to 150%.
  static const tilePreviewScale = 1.5;

  /// The version badge sits on the cover header's inherited 16px/24px inline
  /// baseline. The source uses a separate one-pixel top inset.
  static Widget versionBadge(BuildContext context, String label) {
    final t = RaftTokens.of(context);
    const appearance = RaftBadgeRecipeAppearance.outline;
    const variant = RaftBadgeRecipeVariant.muted;
    final badge = RaftBadge(
      label: label,
      appearance: appearance,
      variant: variant,
    );
    if (!t.desktop) {
      return Padding(
        padding: const EdgeInsets.only(
          top: RaftSpace.hairline + RaftSpace.half,
        ),
        child: badge,
      );
    }
    final recipe = RaftBadgeRecipe.resolve(
      appearance: appearance,
      variant: variant,
      states: t.recipeStates(responsive: true),
      tokens: t.recipeTokens,
    ).root;
    return Padding(
      padding: const EdgeInsets.only(top: RaftSpace.hairline),
      child: RaftCssInlineBox(
        lineText: RaftTypography.body(
          t,
          size: RaftTypeScale.body.fontSize,
          line: RaftTypeScale.body.lineHeight,
        ),
        childText: t.scale(t.typeSlot('mono-meta'), mono: true),
        height: recipe.height ?? RaftSpace.x5 + RaftSpace.half,
        minHeight: true,
        child: badge,
      ),
    );
  }

  /// The phone PanelMeta count uses Space Mono for the localized numbers and
  /// the panel caption face for the surrounding label.
  static Widget headerCount(BuildContext context, String count) {
    final t = RaftTokens.of(context);
    final style = t.scale(
      t.typeSlot('caption'),
      weight: FontWeight.w500,
      color: t.ui.foregroundHint,
    );
    final mono = style.copyWith(fontFamily: t.monoFont);
    return RaftCssText.rich(
      TextSpan(
        children: [
          for (final part in RegExp(r'([0-9]+)|[^0-9]+').allMatches(count))
            TextSpan(text: part[0], style: part[1] == null ? null : mono),
        ],
      ),
      maxLines: RaftScaled.grows(context) ? null : 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// The fixed type scale of Web ArtifactCardExcerpt. The thumbnail's type does
/// not change at the desktop breakpoint.
class RaftArtifactExcerptStyle {
  const RaftArtifactExcerptStyle(this.tokens);

  final RaftTokens tokens;

  TextStyle get body => RaftTypography.body(tokens, size: 12, line: 18);

  TextStyle heading(int level) => switch (level) {
    1 => RaftTypography.body(
      tokens,
      size: 15,
      line: 20,
      weight: FontWeight.w600,
    ),
    2 => RaftTypography.body(
      tokens,
      size: 14,
      line: 20,
      weight: FontWeight.w600,
    ),
    _ => body.copyWith(fontWeight: FontWeight.w600),
  };

  TextStyle inline({
    required bool code,
    required bool bold,
    required bool italic,
  }) => (code ? RaftTypography.mono(tokens, size: 11, line: 16) : raftCssText)
      .copyWith(
        fontWeight: bold ? FontWeight.w600 : null,
        fontStyle: italic ? FontStyle.italic : null,
      );
}
