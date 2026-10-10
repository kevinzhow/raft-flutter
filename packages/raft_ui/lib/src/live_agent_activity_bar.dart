import 'package:flutter/widgets.dart';

import 'indicators.dart';
import 'mounted_avatar_recipe.dart';
import 'recipe_surface.dart';
import 'recipes/live_agent_activity_bar.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/status.g.dart';
import 'theme.dart';
import 'tooltip.dart';
import 'viewport_breakpoints.dart';

/// Web `LiveAgentActivityBarPresentation` (layout/LiveAgentActivityBar.tsx)
/// over the raft-ui `liveAgentActivityBar` recipe: the "what the bot is doing
/// now" strip. The caller owns which agent is shown, its authorized avatar
/// artwork and the text; this widget owns the geometry and colours.
///
/// Web composition (`beam={false}`):
///   root    elegant `rounded-lg border border-line-muted bg-layer-panel
///           shadow-raft-md px-3 py-2` (dark: transparent border); brutal
///           `border-t-2 border-black bg-white md:bg-brutal-cream`, whose
///           `px-4` the callsite pulls back to `px-3!`
///   row     `flex min-h-8 items-center gap-2`
///   avatar  `size-9` (36px) agent avatar frame, 1px border
///   status  `Status md` (10px) after the avatar in both themes; semantic
///           variant per activity, brutal keeps the fixed status colours and a
///           black border
///   text    one line, ellipsis; elegant 13px sans `text-foreground-muted`,
///           brutal 14px mono `text-black/60`
/// The strip has no action: nothing is tappable. Web's enter/exit motion
/// (220ms fade + 8px rise, elegant only) never runs in the product because
/// the connected wrapper unmounts it instead of passing a null child.
class RaftLiveAgentActivityBar extends StatelessWidget {
  const RaftLiveAgentActivityBar({
    super.key,
    required this.agentName,
    required this.avatarContent,
    required this.text,
    this.activity = RaftActivityTone.working,
  });

  /// Agent display name; the semantic label reads `<name>: <text>`.
  final String agentName;

  /// Authorized artwork inside the avatar frame (pixel art or an image).
  final Widget avatarContent;
  final String text;

  /// `thinking` / `working` are the only kinds the product shows; the others
  /// keep their Web status colours for completeness.
  final RaftActivityTone activity;

  /// The root's key: the measured box of the strip.
  static const barKey = Key('live-agent-activity-bar');

  static RaftStatusRecipeVariant _variant(RaftActivityTone a) => switch (a) {
    RaftActivityTone.online => RaftStatusRecipeVariant.success,
    RaftActivityTone.thinking ||
    RaftActivityTone.working => RaftStatusRecipeVariant.warning,
    RaftActivityTone.error => RaftStatusRecipeVariant.danger,
    RaftActivityTone.offline => RaftStatusRecipeVariant.default_,
  };

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final states = t.recipeStates().copyWith(
      viewportWidth: raftBreakpointWidth(context),
    );
    final recipe = RaftLiveAgentActivityBarRecipe.resolve(
      theme: t.recipeTheme,
      states: states,
      tokens: tokens,
    );
    final status = RaftStatusRecipe.resolve(
      theme: t.recipeTheme,
      size: RaftStatusRecipeSize.md,
      variant: _variant(activity),
      states: t.recipeStates(),
      tokens: tokens,
    ).root;
    // `Status` + the callsite's `theme-brutal:border-black` (recipe `status`).
    final dotStyle = RaftSlotStyle(
      {...status.properties, ...recipe.status.properties},
      {...status.targets, ...recipe.status.targets},
      [...status.classes, ...recipe.status.classes],
      tokens,
    );
    // Brutal status lights keep their fixed semantic colours
    // (`--color-status-busy`, `--color-brutal-orange`), not the skin's.
    final brutalFill = switch (activity) {
      RaftActivityTone.thinking ||
      RaftActivityTone.working => t.product.statusBusy,
      RaftActivityTone.error => t.product.brutalOrange,
      _ => null,
    };
    final label = '$agentName: $text';
    final textStyle = recipe.text.text(
      tokens,
      base: DefaultTextStyle.of(context).style,
    );
    // The raw raft-ui `Avatar xs` forced to `size-9`: its 1px border (black
    // in brutal) stays, unlike the 2px panel-header AvatarSlot frame.
    final avatar = RaftMountedAvatarFrame(
      name: agentName,
      avatarContext: RaftMountedAvatarContext.compactList,
      identity: RaftMountedAvatarIdentity.agent,
      extent: 36,
      child: avatarContent,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: RaftRecipeBox(
          key: barKey,
          style: recipe.root,
          tokens: tokens,
          // The callsite's `theme-brutal:px-3!` over the recipe's `px-4`.
          padding: t.brutal
              ? recipe.root.padding.copyWith(left: 12, right: 12)
              : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: recipe.row.minHeight ?? 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                SizedBox(width: recipe.row.columnGap ?? 0),
                RaftRecipeBox(
                  key: const Key('live-agent-activity-status'),
                  style: dotStyle,
                  tokens: tokens,
                  decorationOverride: t.brutal && brutalFill != null
                      ? (d) => d.copyWith(color: brutalFill)
                      : null,
                ),
                // Brutal wraps status + text in `content` (`gap-1.5`); in
                // elegant `content` is `display: contents` (row `gap-2`).
                SizedBox(
                  width: t.brutal
                      ? recipe.content.columnGap ?? 0
                      : recipe.row.columnGap ?? 0,
                ),
                Expanded(
                  child: RaftTooltip(
                    message: text,
                    onlyWhenTruncated: true,
                    child: Text(
                      text,
                      key: const Key('live-agent-activity-text'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: textStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
