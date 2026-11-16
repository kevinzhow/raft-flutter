// Web v1.24 components/agent/LoungeAvatar.tsx: an agent's Lounge is drawn as
// its agent's face with the Lounge mark in the bottom-right corner, wherever
// the Lounge itself is shown (its header, a thread's parent, Activity). The
// mark is an ink-edged square on `info-soft`, ringed with the surface; the
// corner holds one thing, so a Lounge's face carries this mark and no presence
// light. The face is decorative: the header around it carries the name.
import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'mounted_avatar_recipe.dart';
import 'raft/avatar.dart';
import 'raft/css_box.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';

/// The mark's glyph is drawn heavier so it holds at 8px (LoungeAvatar.tsx
/// `strokeWidth={3}`).
const double _markStroke = 3;

/// The Lounge mark's box, glyph and how far it sticks out of the avatar, per
/// avatar size (LoungeAvatar.tsx `LOUNGE_BADGE_CLASS`).
({double box, double glyph, double offset}) raftLoungeBadgeSpec(
  RaftAvatarSize size,
) => switch (size) {
  RaftAvatarSize.xl => (box: 24, glyph: 16, offset: 6),
  RaftAvatarSize.lg => (box: 18, glyph: 12, offset: 4),
  RaftAvatarSize.md => (box: 14, glyph: 10, offset: 3),
  RaftAvatarSize.sm => (box: 12, glyph: 8, offset: 3),
  RaftAvatarSize.xs || RaftAvatarSize.xxs => (box: 11, glyph: 8, offset: 3),
  RaftAvatarSize.xxxs => (box: 9, glyph: 6, offset: 2),
};

/// A Lounge's face: [content] (the agent's picture, or the fallback letter
/// when null) in the mounted [avatarContext] frame, with the Lounge mark.
class RaftLoungeAvatar extends StatelessWidget {
  const RaftLoungeAvatar({
    super.key,
    required this.name,
    this.content,
    this.avatarContext = RaftMountedAvatarContext.panelHeader,
  });

  /// The agent's name (the fallback letter and the accessible name).
  final String name;
  final Widget? content;
  final RaftMountedAvatarContext avatarContext;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMountedAvatarRecipe(
      t,
      avatarContext,
      RaftMountedAvatarIdentity.agent,
    );
    final size = recipe.avatarSize;
    final spec = raftLoungeBadgeSpec(size);
    final mark = Transform.translate(
      // The sticker pins its badge by the size class's own offset.
      offset: Offset(
        spec.offset - size.badgeOffset,
        spec.offset - size.badgeOffset,
      ),
      child: RaftCssBox(
        key: const ValueKey('lounge-avatar-badge'),
        radius: 3,
        fill: Color.alphaBlend(t.colors['info-soft']!, t.panel),
        borderWidth: raftControlBorderPx(context, 1),
        borderColor: t.ui.stickerInk,
        rings: [RaftRing(2, t.panel)],
        width: spec.box,
        height: spec.box,
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: RaftIcon(
            RaftGlyph.users,
            size: spec.glyph,
            strokeWidth: _markStroke,
            color: t.colors['foreground'],
          ),
        ),
      ),
    );
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: RaftStickerAvatar(
        size: size,
        extent: recipe.extent,
        type: recipe.type,
        badgeOutlineColor: t.panel,
        frameKey: const ValueKey('lounge-avatar-frame'),
        badge: mark,
        child:
            content ??
            RaftMountedAvatarFallback(
              avatarContext: avatarContext,
              identity: RaftMountedAvatarIdentity.agent,
              initials: name,
            ),
      ),
    );
  }
}
