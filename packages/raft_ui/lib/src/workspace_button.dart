import 'package:flutter/material.dart';

import 'agent_profile.dart' show RaftAvatarSlot, RaftAvatarSlotContext;
import 'delegated_face.dart' show RaftAvatarCorner;
import 'design_primitives.dart' show RaftMetrics, RaftTypography;
import 'icons.dart';
import 'interaction.dart';
import 'tap_slop.dart';
import 'public_page_mark.dart';
import 'raft/avatar.dart' show RaftAvatarBadge, RaftAvatarSize;
import 'raft/button.dart';
import 'raft/status.dart' show RaftStatusVariant;
import 'raft/ui_tokens.dart' show raftChromeBlend;
import 'text_scaling.dart' show RaftChrome;
import 'theme.dart';

/// raft-ui `WorkspaceButton` (0.95.3): an `on-frame` `md` Button holding the
/// server's avatar, its name (`WorkspaceButtonName`, `max-w-[200px]`
/// truncated), the public-page globe and a `ChevronDown` 16 pulled in by 4.
/// Web's phone Home puts it in the tab-root band with `-ml-[11px]` ([hang]).
class RaftWorkspaceButton extends StatelessWidget {
  const RaftWorkspaceButton({
    super.key,
    required this.name,
    this.avatarUrl,
    this.attention = false,
    this.attentionLabel,
    this.publicPageLive = false,
    this.open = false,
    this.focusNode,
    this.onPressed,
  });

  /// The server's name; empty shows the avatar alone.
  final String name;
  final String? avatarUrl;

  /// Other servers have unread messages: the attention pixel on the avatar's
  /// corner, labelled [attentionLabel] for assistive tech.
  final bool attention;
  final String? attentionLabel;
  final bool publicPageLive;

  /// Its menu is open: Web `data-popup-open` keeps the on-frame pressed fill.
  final bool open;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  /// Web `-ml-[11px]` (the button's 1px border and 10px padding): the host
  /// band takes this off its start padding so the avatar sits on the band's
  /// 16px edge.
  static const hang = 11.0;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final initial = Center(
      child: Text(
        name.trim().isEmpty ? 'R' : name.trim().characters.first.toUpperCase(),
        textScaler: RaftChrome.boundedScalerOf(context),
        // Web AvatarSlot `compact-row` server fallback: 13/700 on the ink tile.
        style: RaftTypography.body(
          t,
          size: 13,
          line: 16,
          weight: FontWeight.w700,
          color: t.colors['foreground-avatar-server'] ?? t.strong,
        ),
      ),
    );
    // The server tile (ink fill, sticker-yellow initial), the same one the
    // bar's server tab shows, at AvatarSlot `compact-row` size 27.
    final tile = RaftAvatarSlot(
      name: name,
      slot: RaftAvatarSlotContext.compactList,
      agent: false,
      server: true,
      sizeOverride: 27,
      avatarUrl: avatarUrl,
      content: avatarUrl == null ? initial : null,
    );
    final avatar = attention
        ? RaftAvatarCorner(
            avatar: tile,
            size: RaftAvatarSize.sm,
            corner: const ExcludeSemantics(
              child: RaftAvatarBadge(
                size: RaftAvatarSize.sm,
                variant: RaftStatusVariant.accent,
              ),
            ),
          )
        : tile;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        if (name.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        if (publicPageLive) ...[
          const SizedBox(width: 8),
          const RaftPublicPageGlobe(live: true, size: 14),
        ],
        // `gap-2` then `-ml-1`: 4px between the last item and the chevron.
        const SizedBox(width: 4),
        const RaftIcon(RaftGlyph.chevronDown, size: 16),
      ],
    );
    final Widget button = DecoratedBox(
      // The top bar's workspace button paints the same pressed fill.
      decoration: BoxDecoration(
        color: open
            ? raftChromeBlend(
                t.colors['fill-frame-pressed']!,
                t.colors['layer-section-header-mobile']!,
              )
            : null,
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: RaftButton(
        label: '',
        // The dot's label joins the button's name, as the dot's aria-label does
        // inside the Web button.
        semanticLabel: attention && attentionLabel != null
            ? '$name, $attentionLabel'
            : name,
        leading: content,
        gap: 0,
        focusNode: focusNode,
        uiVariant: RaftButtonVariant.onFrame,
        uiSize: RaftButtonSize.md,
        onPressed: onPressed,
      ),
    );
    return RaftInteraction.of(context).touch
        ? RaftTapSlopAnchor(
            minSize: const Size.square(RaftMetrics.touchTarget),
            child: button,
          )
        : button;
  }
}
