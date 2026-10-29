import 'package:flutter/material.dart';

import 'components.dart'
    show RaftConversationNavKind, RaftConversationNavigationRecipe;
import 'design_primitives.dart' show RaftTypography;
import 'icons.dart';
import 'text_scaling.dart' show RaftChrome;
import 'theme.dart';

String _capped(int count) => count > 99 ? '99+' : '$count';

/// Sidebar.tsx `ChannelUnreadSegments` inside `SidebarItemCount` (loud) or as
/// quiet text (muted or not joined): the channel's own unread, a `·`
/// (`SidebarItemCountSeparator`, `mx-0.5 opacity-60`), then a thread icon with
/// the number of followed threads with new replies (`SidebarItemThreadCount`,
/// `inline-flex gap-0.5`, 12px icon). With no own unread only the thread
/// segment shows.
class RaftSidebarThreadUnreadCount extends StatelessWidget {
  const RaftSidebarThreadUnreadCount({
    super.key,
    required this.unread,
    required this.threads,
    required this.label,
    this.loud = true,
  });
  final int unread, threads;

  /// The screen-reader copy after the thread number (`sr-only`).
  final String label;
  final bool loud;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftConversationNavigationRecipe(
      t,
      kind: RaftConversationNavKind.directMessage,
    );
    final bounded = RaftChrome.boundedScalerOf(context);
    final color = loud ? recipe.countForeground : t.colors['foreground-muted']!;
    final style = loud
        ? recipe.countTextStyle
        : RaftTypography.mono(
            t,
            size: 10,
            line: 10,
          ).copyWith(fontWeight: FontWeight.w500, color: color);
    final segments = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unread > 0) ...[
          Text(_capped(unread), style: style, textScaler: bounded),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: .6,
              child: Text('·', style: style, textScaler: bounded),
            ),
          ),
        ],
        Row(
          key: const ValueKey('sidebar-thread-unread'),
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftThreadIcon(size: 12, color: color),
            const SizedBox(width: 2),
            Text(_capped(threads), style: style, textScaler: bounded),
          ],
        ),
      ],
    );
    final content = Semantics(
      label:
          '${unread > 0 ? '${_capped(unread)} ' : ''}'
          '${_capped(threads)} $label',
      excludeSemantics: true,
      child: segments,
    );
    if (!loud) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: content,
      );
    }
    return Container(
      constraints: BoxConstraints(
        minWidth: recipe.countMinimumWidth,
        minHeight: recipe.countHeight,
      ),
      padding: recipe.countPadding,
      decoration: recipe.countDecoration,
      child: Center(widthFactor: 1, heightFactor: 1, child: content),
    );
  }
}
