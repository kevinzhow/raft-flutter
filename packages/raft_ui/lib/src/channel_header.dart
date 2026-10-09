// Mounted ChatPanel.tsx → ui/PanelHeader.tsx. Identity is always visible for
// ordinary/private/joint channels; the same generated panelHeader recipe
// supplies dimensions and text. ChannelDescription adds at most two lines.
import 'package:flutter/material.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'panel_layout.dart';
import 'recipe_surface.dart';
import 'recipes/panel_header.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

class RaftChannelHeader extends StatelessWidget {
  const RaftChannelHeader({
    super.key,
    required this.name,
    this.description = '',
    this.kind = 'channel',
    this.onBack,
    this.backKey,
    this.onSearch,
    this.onSettings,
    this.backLabel = 'Back',
    this.searchLabel = 'Search this channel',
    this.settingsLabel = 'Channel settings',
  });
  final String name, description, kind, backLabel, searchLabel, settingsLabel;
  final VoidCallback? onBack, onSearch, onSettings;
  final Key? backKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context),
        rt = RaftRecipeTokens(RaftTokens.of(context));
    final recipe = RaftPanelHeaderRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
      }, MediaQuery.sizeOf(context).width),
      tokens: rt,
    );
    final gap = recipe.header.columnGap ?? recipe.header.length('gap') ?? 12;
    TextStyle text(RaftSlotStyle slot) =>
        slot.text(rt, base: RaftTypography.body(t, size: 16, line: 20));
    final glyph = switch (kind) {
      'private' => RaftGlyph.lock,
      'joint' => RaftGlyph.gitBranch,
      _ => RaftGlyph.hash,
    };
    return RaftRecipeBox(
      style: recipe.header,
      tokens: rt,
      child: Row(
        children: [
          if (onBack != null) ...[
            RaftPanelAction(
              key: backKey,
              glyph: RaftGlyph.arrowLeft,
              tooltip: backLabel,
              onPressed: onBack,
            ),
            SizedBox(width: gap),
          ],
          RaftRecipeBox(
            style: recipe.headerIcon,
            tokens: rt,
            alignment: Alignment.center,
            child: RaftIcon(
              glyph,
              size: 14,
              color: recipe.headerIcon.color?.resolve(rt) ?? t.strong,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftCssText(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text(recipe.title),
                  // CSS establishes the line box from the primary face; CJK
                  // fallback glyph ascent must not change that box/baseline.
                  strutStyle: StrutStyle.fromTextStyle(
                    text(recipe.title),
                    forceStrutHeight: true,
                  ),
                ),
                if (description.isNotEmpty &&
                    (recipe.headerContent.rowGap ??
                            recipe.headerContent.length('gap') ??
                            0) >
                        0)
                  SizedBox(
                    height:
                        recipe.headerContent.rowGap ??
                        recipe.headerContent.length('gap'),
                  ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: MediaQuery.sizeOf(context).height <= 600 ? 1 : 2,
                    overflow: TextOverflow.clip,
                    softWrap: recipe.meta.whiteSpace != 'nowrap',
                    style: text(recipe.meta),
                    strutStyle: StrutStyle.fromTextStyle(
                      text(recipe.meta),
                      forceStrutHeight: true,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: gap),
          // ChannelOverflowMenu → OverflowMenuTrigger uses Button icon-sm;
          // PanelAction is the separate, narrower mobile back control.
          RaftPanelIconButton(
            glyph: RaftGlyph.search,
            tooltip: searchLabel,
            onPressed: onSearch,
          ),
          SizedBox(
            width:
                recipe.actions.columnGap ?? recipe.actions.length('gap') ?? 6,
          ),
          RaftPanelIconButton(
            glyph: RaftGlyph.settings,
            tooltip: settingsLabel,
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}
