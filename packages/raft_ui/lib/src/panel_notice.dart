import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';

import 'agent_profile.dart' show RaftPanelText;
import 'recipe_surface.dart';
import 'recipes/panel_notice.g.dart';
import 'recipes/recipe_runtime.dart' show RaftRecipeSet, RaftRecipeStates;
import 'theme.dart';
import 'viewport_breakpoints.dart';

export 'recipes/panel_notice.g.dart' show RaftPanelNoticeRecipeStatus;

/// raft-ui `PanelNotice`: the strip directly under a panel header that says
/// something in this panel failed. It runs the full width of the panel, with no
/// radius and no hairline; its fill is the soft tint of [status], and a `line-seam`
/// closes it below.
///
/// [content] is one message of at most two lines (`PanelNoticeContent`:
/// semibold callout in the style it is handed). [actions] sit on the right,
/// centred on the first line (`PanelNoticeActions`): a small icon button or a
/// text button, and they never make the strip taller. [leading] is whatever
/// leads the copy.
///
/// The frozen Elegant and Brutal looks have no PanelNotice recipe; there the
/// strip is the soft tint with a `line-muted` rule and 20 x 8 padding the
/// panels always drew.
class RaftPanelNotice extends StatelessWidget {
  const RaftPanelNotice({
    super.key,
    required this.content,
    this.status = RaftPanelNoticeRecipeStatus.warning,
    this.leading,
    this.actions = const [],
  });

  final RaftPanelNoticeRecipeStatus status;
  final Widget? leading;

  /// Builds the message in [style], the text style of the strip's content.
  final Widget Function(BuildContext context, TextStyle style) content;
  final List<Widget> actions;

  /// The frozen looks' tint of each status.
  static String _legacyFill(RaftPanelNoticeRecipeStatus status) =>
      switch (status) {
        RaftPanelNoticeRecipeStatus.default_ => 'fill-muted',
        RaftPanelNoticeRecipeStatus.warning => 'warning-soft',
        RaftPanelNoticeRecipeStatus.destructive => 'danger-soft',
        RaftPanelNoticeRecipeStatus.info => 'info-soft',
        RaftPanelNoticeRecipeStatus.success => 'success-soft',
      };

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.recipeSet != RaftRecipeSet.raft) return _legacy(context, t);
    final tokens = t.recipeTokens;
    final recipe = RaftPanelNoticeRecipe.resolve(
      status: status,
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
      }, raftBreakpointWidth(context)),
      tokens: tokens,
    );
    final style = recipe.root.text(
      tokens,
      base: DefaultTextStyle.of(context).style,
    );
    // The first line grows with the text size, and the actions are centred on it.
    final lineHeight = MediaQuery.textScalerOf(context)
        .scale((style.fontSize ?? 14) * (style.height ?? 20 / 14));
    final gap = recipe.root.columnGap ?? 10;
    return Semantics(
      liveRegion: true,
      container: true,
      child: RaftRecipeBox(
        style: recipe.root,
        tokens: tokens,
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, SizedBox(width: gap)],
            Expanded(child: content(context, style)),
            if (actions.isNotEmpty) ...[
              SizedBox(width: gap),
              // `margin-block: -6px`: the actions are centred on the first
              // line and overflow it, so a 32px button adds no height.
              SizedBox(
                height: lineHeight,
                child: OverflowBox(
                  fit: OverflowBoxFit.deferToChild,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: recipe.actions.columnGap ?? 12,
                    children: actions,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legacy(BuildContext context, RaftTokens t) => Semantics(
    liveRegion: true,
    container: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: t.colors[_legacyFill(status)],
        border: Border(
          // ds-allow: the frozen Elegant and Brutal strip draws its 1px rule as it always did
          bottom: BorderSide(color: t.colors['line-muted']!, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(child: content(context, RaftPanelText.value(t))),
          for (final action in actions) ...[const SizedBox(width: 8), action],
        ],
      ),
    ),
  );
}
