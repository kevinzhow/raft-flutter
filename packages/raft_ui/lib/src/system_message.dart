import 'package:flutter/material.dart';

import 'icons.dart';
import 'message_read_faces.dart';
import 'message_rule_row.dart';
import 'recipe_surface.dart';
import 'recipes/message_system.g.dart';
import 'theme.dart';
import 'tooltip.dart';

/// The rows of an expanded [RaftSystemMessageGroup] (Web
/// `[&_[data-slot=system-message-item]]:pt-1`).
class _SystemGroupScope extends InheritedWidget {
  const _SystemGroupScope({required super.child});
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SystemGroupScope>() != null;
  @override
  bool updateShouldNotify(_SystemGroupScope oldWidget) => false;
}

/// Mounted SystemMessage. The adapter supplies formatted receipt text/time;
/// system rows have no author/avatar, reactions or message toolbar.
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
    final t = RaftTokens.of(context);
    // raft-ui 0.95.3 `SystemMessage`: `flex items-center justify-center gap-2
    // px-4 pt-timeline-lead pb-timeline-row font-mono text-mono-meta
    // text-foreground-hint` with a flex-1 hairline before and after.
    final tokens = t.recipeTokens;
    final recipe = RaftMessageSystemRecipe.resolve(
      tokens: tokens,
      states: t.recipeStates(responsive: true),
    );
    // The time and content slots inherit `font-mono text-mono-meta
    // text-foreground-hint` from the root.
    final base = recipe.systemRoot.text(
      tokens,
      base: DefaultTextStyle.of(context).style,
    );
    final gap = recipe.systemRoot.columnGap ?? 8;
    final timeStyle = recipe.systemTime.text(tokens, base: base);
    final contentStyle = recipe.systemContent.text(tokens, base: base);
    // `in-data-[slot=system-message-group-panel]:py-1.5`; the group host
    // re-asserts the lead (`pt-1`, SystemMessageGroupDisclosure.tsx).
    final inGroup = _SystemGroupScope.of(context);
    return Padding(
      padding: inGroup
          ? recipe.systemRoot.padding.copyWith(top: 4, bottom: 6)
          : recipe.systemRoot.padding,
      child: RaftMessageRuleRow(
        gap: gap,
        ruleColor: t.colors['line-hairline']!,
        beforeKey: const ValueKey('system-message-rule-before'),
        afterKey: const ValueKey('system-message-rule-after'),
        naturalWidth:
            raftMessageTextWidth(context, timestamp, timeStyle) +
            gap +
            raftMessageTextWidth(context, content, contentStyle),
        child: Row(
          children: [
            Text(timestamp, style: timeStyle),
            SizedBox(width: gap),
            Flexible(
              // The line already says it; the full text only helps when cut.
              child: RaftTooltip(
                message: tooltip ?? content,
                onlyWhenTruncated: tooltip == null,
                child: Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: contentStyle,
                ),
              ),
            ),
          ],
        ),
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
    this.trailing,
  });
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  /// Key of the disclosure button (Web `system-message-group-toggle`).
  final Key? toggleKey;
  final Widget? trailing;

  static bool containsExpandedRows(BuildContext context) =>
      _SystemGroupScope.of(context);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final recipe = RaftMessageSystemRecipe.resolve(
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
          _trailing(
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
                              width:
                                  recipe.systemGroupDisclosure.columnGap ?? 6,
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

  Widget _trailing(Widget header) => trailing == null
      ? header
      : RaftMessageSystemTrailing(trailing: trailing!, child: header);
}
