import 'package:flutter/material.dart';

import 'icons.dart';
import 'sidebar_text.dart';
import 'raft/css_box.dart' show raftControlBorderPx;
import 'design_primitives.dart';
import 'theme.dart';
import 'tooltip.dart' show RaftTooltip;

/// Quiet count from mounted Sidebar.tsx:902–905. Muted or unjoined channels
/// retain their unread count without inheriting the accent badge.
class RaftSidebarQuietUnreadCount extends StatelessWidget {
  const RaftSidebarQuietUnreadCount({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.size('space.sidebarQuietInline', fallback: 6),
        vertical: t.size('space.sidebarQuietVertical', fallback: 2),
      ),
      child: RaftSidebarText(
        count > 99 ? '99+' : '$count',
        style:
            RaftTypography.mono(
              t,
              size: t.size('type.sidebarMeta.size', fallback: 10),
              line: t.size('type.sidebarQuietMeta.line', fallback: 10),
            ).copyWith(
              fontWeight: raftFontWeight(
                t.size('type.sidebarMeta.weight', fallback: 500),
              ),
              color: t.colors['foreground-sidebar-quiet'],
            ),
      ),
    );
  }
}

/// Sidebar.tsx `sidebar-quiet-new-dot`: `ml-auto size-1.5 rounded-full
/// bg-foreground-muted` (brutal `bg-black/50`).
class RaftSidebarQuietNewDot extends StatelessWidget {
  const RaftSidebarQuietNewDot({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Semantics(
        label: label,
        child: DecoratedBox(
          key: const ValueKey('sidebar-quiet-new-dot'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.colors['foreground-muted'],
          ),
          child: const SizedBox.square(dimension: 6),
        ),
      ),
    );
  }
}

/// SidebarItemMetaIcon uses a 16px slot around the mounted 12px BellOff.
class RaftSidebarMutedIcon extends StatelessWidget {
  const RaftSidebarMutedIcon({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftTooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        child: SizedBox.square(
          dimension: 16,
          child: Center(
            child: RaftIcon(
              RaftGlyph.bellOff,
              size: t.size('size.sidebarMetaGlyph', fallback: 12),
              color: t.colors['foreground-sidebar-meta'],
            ),
          ),
        ),
      ),
    );
  }
}

/// A draft is the fallback marker after a conversation's unread indicator.
class RaftSidebarDraftIcon extends StatelessWidget {
  const RaftSidebarDraftIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return SizedBox.square(
      dimension: t.size('size.sidebarMetaSlot', fallback: 12),
      child: Center(
        child: RaftIcon(
          RaftGlyph.pencil,
          size: t.size('size.sidebarMetaGlyph', fallback: 12),
          color: t.colors['foreground-sidebar-meta'],
        ),
      ),
    );
  }
}

/// Sidebar.tsx ChannelRow `sidebar-mention-marker`: a 16px chip with an 10px
/// AtSign, `border-line-strong bg-primary-soft text-primary-strong`
/// (Brutal `border-black bg-soft-signal text-black`).
class RaftSidebarMentionMarker extends StatelessWidget {
  const RaftSidebarMentionMarker({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftTooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        child: Container(
          key: const ValueKey('sidebar-mention-marker'),
          width: t.size('size.sidebarMention', fallback: 16),
          height: t.size('size.sidebarMention', fallback: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.colors['layer-sidebar-mention'],
            boxShadow: [
              if (t.size('stroke.sidebarMentionRing', fallback: 0) > 0)
                BoxShadow(
                  color: t.colors['line-sidebar-mention-ring']!,
                  spreadRadius: t.size(
                    'stroke.sidebarMentionRing',
                    fallback: 0,
                  ),
                ),
            ],
            border: Border.all(
              color: t.colors['line-sidebar-mention']!,
              width: raftControlBorderPx(
                context,
                t.size('stroke.sidebarMention', fallback: 1),
              ),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: RaftIcon(
            RaftGlyph.atSign,
            size: t.size('size.sidebarMentionGlyph', fallback: 10),
            color: t.colors['foreground-sidebar-mention'],
          ),
        ),
      ),
    );
  }
}
