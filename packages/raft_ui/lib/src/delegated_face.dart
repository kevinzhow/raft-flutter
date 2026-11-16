import 'package:flutter/material.dart';

import 'raft/avatar.dart';
import 'raft/css_box.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';

/// The fill a [RaftMessageRow] paints right now (`--mi-row-fill`): rest,
/// hover, popup, highlighted. Parts that must melt into the row (the
/// delegated face's ring) read it; transparent outside a row.
class RaftMessageRowFillScope extends InheritedWidget {
  const RaftMessageRowFillScope({
    super.key,
    required this.color,
    required super.child,
  });

  final Color color;

  static Color of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RaftMessageRowFillScope>()
          ?.color ??
      Colors.transparent;

  @override
  bool updateShouldNotify(RaftMessageRowFillScope old) => color != old.color;
}

/// raft-ui `MessageItemDelegatedAvatar` (RFC 077): the assistant's face on
/// the owner's avatar, 19px, `rounded-sticker`, a ring in the row's fill over
/// `layer-canvas` (1.5px, 3px in dark). A deleted assistant is grayed and
/// faded. Decoration only: the words say who sent it.
class RaftDelegatedFace extends StatelessWidget {
  const RaftDelegatedFace({
    super.key,
    required this.agentAvatar,
    this.deleted = false,
  });

  final Widget agentAvatar;
  final bool deleted;

  static const double extent = 19;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final canvas = t.ui.layerCanvas;
    final ring = t.dark ? 3.0 : 1.5;
    final radius = t.size('radius.sticker', fallback: 4);
    Widget face = RaftCssBox(
      radius: radius,
      fill: canvas,
      // CSS lists the row fill first (on top), then the canvas.
      rings: [
        RaftRing(ring, RaftMessageRowFillScope.of(context)),
        RaftRing(ring, canvas),
      ],
      width: extent,
      height: extent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.square(dimension: extent, child: agentAvatar),
      ),
    );
    if (deleted) {
      face = Opacity(
        opacity: .6,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            .2126, .7152, .0722, 0, 0, //
            .2126, .7152, .0722, 0, 0,
            .2126, .7152, .0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: face,
        ),
      );
    }
    return ExcludeSemantics(child: face);
  }
}

/// `AvatarSlot corner`: [corner] pinned over the avatar's bottom-right like
/// an `AvatarBadge` of the avatar's size class (`-right-1 -bottom-1` of the
/// padding box for md).
class RaftAvatarCorner extends StatelessWidget {
  const RaftAvatarCorner({
    super.key,
    required this.avatar,
    required this.corner,
    this.size = RaftAvatarSize.md,
  });

  final Widget avatar;
  final Widget corner;
  final RaftAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final offset = raftControlBorderPx(context, 1.5) - size.badgeOffset;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(right: offset, bottom: offset, child: corner),
      ],
    );
  }
}
