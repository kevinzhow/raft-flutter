import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'recipe_surface.dart';
import 'recipes/message_system.g.dart';
import 'theme.dart';
import 'tooltip.dart';

/// Mounted SystemMessage (raft-ui 0.5.52). The adapter supplies formatted
/// receipt text/time; system rows have no author/avatar, reactions or message
/// toolbar.
///
/// The note owns a short lead-in (`pt-[3px]`, brutal `pt-0`) and no bottom
/// padding or margin; the message that follows cancels the rest of the seam
/// with `data-follows-system` (see [RaftMessageRowRecipe]). Inside an expanded
/// group the host re-asserts the lead: `pt-1` elegant, `pt-1.5` brutal.
class RaftSystemMessageRecipe {
  const RaftSystemMessageRecipe(this.tokens, {this.inGroup = false});
  final RaftTokens tokens;
  final bool inGroup;
  EdgeInsets get padding => EdgeInsets.fromLTRB(
    8,
    inGroup
        ? (tokens.brutal ? 6 : 4)
        : tokens.brutal
        ? 0
        // ignore: raft_lints/off_grid_spacing -- Web `pt-[3px]`
        : 3,
    8,
    0,
  );
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

/// The rows of an expanded [RaftSystemMessageGroup] (Web
/// `[&_[data-slot=system-message-item]]:pt-1`).
class _SystemGroupScope extends InheritedWidget {
  const _SystemGroupScope({required super.child});
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SystemGroupScope>() != null;
  @override
  bool updateShouldNotify(_SystemGroupScope oldWidget) => false;
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
    final recipe = RaftSystemMessageRecipe(
      RaftTokens.of(context),
      inGroup: _SystemGroupScope.of(context),
    );
    return Padding(
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
    );
  }
}

/// raft-ui `SystemMessageGroup*` (web SystemMessageGroupDisclosure.tsx): the
/// centred summary disclosure of an adjacent system-message run. The adapter
/// owns the summary copy and the expanded state; [children] are the run's
/// system rows, shown while [expanded].
class RaftSystemMessageGroup extends StatelessWidget {
  const RaftSystemMessageGroup({
    super.key,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.toggleKey,
  });
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  /// Key of the disclosure button (Web `system-message-group-toggle`).
  final Key? toggleKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final recipe = RaftMessageSystemRecipe.resolve(
      theme: t.recipeTheme,
      tokens: tokens,
      states: t.recipeStates(),
    );
    final label = recipe.systemGroupDisclosure.text(
      tokens,
      base: DefaultTextStyle.of(context).style,
    );
    final chevron = recipe.systemGroupChevron;
    return Padding(
      padding: recipe.systemGroup.margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: recipe.systemGroupHeader.padding,
            child: Center(
              child: RaftTooltip(
                message: summary,
                onlyWhenTruncated: true,
                child: GestureDetector(
                  key: toggleKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Semantics(
                    button: true,
                    expanded: expanded,
                    child: Padding(
                      padding: recipe.systemGroupDisclosure.padding,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: label,
                            ),
                          ),
                          SizedBox(
                            width: recipe.systemGroupDisclosure.columnGap ?? 6,
                          ),
                          // ChevronRight: rotate-90 closed, -rotate-90 open.
                          RotatedBox(
                            quarterTurns: expanded ? 3 : 1,
                            child: RaftIcon(
                              RaftGlyph.chevronRight,
                              size: chevron.width ?? 12,
                              color: chevron.textStyle(tokens).color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            _SystemGroupScope(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}
