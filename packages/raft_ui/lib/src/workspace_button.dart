import 'package:flutter/material.dart';

import 'components.dart' show RaftAvatar, RaftAvatarKind;
import 'design_primitives.dart' show RaftMetrics;
import 'icons.dart';
import 'interaction.dart';
import 'tap_slop.dart';
import 'mounted_avatar_recipe.dart' show RaftMountedAvatarContext;
import 'public_page_mark.dart';
import 'raft/button.dart';
import 'raft/status.dart' show RaftAttentionDot;

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
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  /// Web `-ml-[11px]` (the button's 1px border and 10px padding): the host
  /// band takes this off its start padding so the avatar sits on the band's
  /// 16px edge.
  static const hang = 11.0;

  @override
  Widget build(BuildContext context) {
    final avatar = RaftAvatar(
      name: name.trim().isEmpty ? 'R' : name,
      kind: RaftAvatarKind.server,
      mountedContext: RaftMountedAvatarContext.compactRow,
      imageUrl: avatarUrl,
      corner: attention
          ? const ExcludeSemantics(child: RaftAttentionDot())
          : null,
    );
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
    final button = RaftButton(
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
    );
    return RaftInteraction.of(context).touch
        ? RaftTapSlopAnchor(
            minSize: const Size.square(RaftMetrics.touchTarget),
            child: button,
          )
        : button;
  }
}
