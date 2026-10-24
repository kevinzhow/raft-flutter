import 'package:flutter/material.dart';

import 'css_pixel_snap.dart';

import 'raft/avatar.dart';
import 'raft/status.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';

/// Mounted AvatarSlot contexts, independent of generic Avatar sizing.
enum RaftMountedAvatarContext {
  panelHeader,
  // AvatarSlot context="message-row" (Web v1.21.12): no forced frame. The
  // message row's avatar slot recipe sizes the image (32, 28 below 768, 34 on
  // the large text tier; the row passes tight constraints) and elegant drops
  // the border.
  messageRow,
  compactList,
  // AvatarSlot context="members-row": RAFT_AVATAR_SPEC `!size-7 !border`.
  membersRow,
  sidebarList,
  previewMini,
}

enum RaftMountedAvatarIdentity { human, agent, server, app }

enum RaftAvatarActivity { online, thinking, working, error, offline }

/// Reserves a compact mounted avatar slot without an identity or semantics.
class RaftAvatarSpace extends StatelessWidget {
  const RaftAvatarSpace({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(dimension: 20);
}

/// Already-authorized display state. The adapter owns membership, identity,
/// external-agent liveness and translation; this value never fetches data.
@immutable
class RaftAvatarPresence {
  const RaftAvatarPresence({
    required this.activity,
    this.external = false,
    this.online = false,
    this.label,
  });
  final RaftAvatarActivity activity;
  final bool external, online;
  final String? label;

  /// The presence light this state shows: an external agent that is not online is `external`, otherwise the
  /// activity (thinking and working are both `busy`).
  RaftPresence get light => external && !online
      ? RaftPresence.external
      : switch (activity) {
          RaftAvatarActivity.online => RaftPresence.online,
          RaftAvatarActivity.thinking ||
          RaftAvatarActivity.working => RaftPresence.busy,
          RaftAvatarActivity.error => RaftPresence.error,
          RaftAvatarActivity.offline => RaftPresence.offline,
        };
}

/// The 0.7.1 presence lights as RGB (light mode), kept for callers that compare against the busy / offline
/// colours without a theme.
abstract final class RaftAvatarStatusPrimitives {
  static const busy = Color(0xffffd440);
  static const offline = Color(0xffc0b9b1);
}

/// AvatarSlot contexts over the raft-ui 0.7.1 sticker avatar: the slot fixes the outer extent (RAFT_AVATAR_SPEC
/// `!size-9` ...), the text, placeholder icon and badge follow the nearest raft-ui size class.
@immutable
class RaftMountedAvatarRecipe {
  const RaftMountedAvatarRecipe(this.tokens, this.avatarContext, this.identity);
  final RaftTokens tokens;
  final RaftMountedAvatarContext avatarContext;
  final RaftMountedAvatarIdentity identity;
  bool get panelHeader => avatarContext == RaftMountedAvatarContext.panelHeader;
  bool get messageRow => avatarContext == RaftMountedAvatarContext.messageRow;
  bool get sidebarList => avatarContext == RaftMountedAvatarContext.sidebarList;
  bool get previewMini => avatarContext == RaftMountedAvatarContext.previewMini;
  bool get membersRow => avatarContext == RaftMountedAvatarContext.membersRow;
  // RAFT_AVATAR_SPEC: panel-header !size-9, compact-list !size-5,
  // sidebar-list !size-[18px], preview-mini !size-[14px]; members-row !size-7.
  double get extent => panelHeader
      ? 36
      : messageRow
      ? 32
      : membersRow
      ? 28
      : sidebarList
      ? 18
      : previewMini
      ? 14
      : 20;
  RaftAvatarSize get avatarSize => RaftAvatarSize.nearest(extent);

  /// `border-[1.5px]` (the painted width floors per device, see [raftControlBorderPx]).
  double get borderWidth => 1.5;
  double get contentExtent => extent - borderWidth * 2;
  double get placeholderExtent => avatarSize.icon;
  // One glyph size for the humanPlaceholder and the Gravatar User fallback:
  // a gravatar hash that arrives after first paint never resizes the glyph.
  double get gravatarFallbackExtent => placeholderExtent;
  double get badgeExtent => avatarSize.badge;

  /// `rounded-sticker`.
  double get radius => 4;
  Color get border => tokens.ui.stickerInk;
  RaftAvatarType get type => identity == RaftMountedAvatarIdentity.human
      ? RaftAvatarType.human
      : RaftAvatarType.agent;
  Color get fallbackFill => type == RaftAvatarType.human
      ? tokens.ui['palette-lavender-400']
      : tokens.ui.inactive;
  Color get placeholderForeground => tokens.ui.stickerInk;

  /// Tier 2: fixed status roles (`--presence-*`); the busy light never inherits a skin accent.
  Color activityFill(RaftAvatarPresence presence) =>
      tokens.ui.presence(presence.light.name);
}

/// Fallback for the leaf's existing uploaded -> Gravatar -> placeholder chain.
/// A person with a name shows initials (`MC`), without one the placeholder icon; an agent shows its first
/// letter. Neither path resolves identity or URLs. [gravatar] is kept for call sites: the explicit
/// humanPlaceholder branch and the nested Gravatar User fallback now draw the same icon.
class RaftMountedAvatarFallback extends StatelessWidget {
  const RaftMountedAvatarFallback({
    super.key,
    this.avatarContext = RaftMountedAvatarContext.panelHeader,
    this.identity = RaftMountedAvatarIdentity.human,
    this.gravatar = false,
    this.initials = '',
  });
  final RaftMountedAvatarContext avatarContext;
  final RaftMountedAvatarIdentity identity;
  final bool gravatar;
  final String initials;
  @override
  Widget build(BuildContext context) {
    final r = RaftMountedAvatarRecipe(
      RaftTokens.of(context),
      avatarContext,
      identity,
    );
    final size = r.avatarSize;
    final text = switch (identity) {
      RaftMountedAvatarIdentity.human =>
        RaftTokens.of(context).option('avatar.humanFallback', or: 'initials') ==
                'icon'
            ? ''
            : raftAvatarInitials(initials),
      RaftMountedAvatarIdentity.agent => raftAvatarInitials(initials, max: 1),
      RaftMountedAvatarIdentity.server =>
        initials.trim().isEmpty ? 'S' : raftAvatarInitials(initials, max: 1),
      RaftMountedAvatarIdentity.app =>
        initials.trim().isEmpty
            ? 'A'
            : initials.trim().characters.take(2).toString().toUpperCase(),
    };
    return text.isEmpty
        ? RaftAvatarPlaceholder(size: size)
        : RaftAvatarInitials(text, size: size);
  }
}

/// Mounted identity frame only. Trusted artwork supplied by the adapter paints
/// over the fallback fill. The status badge lives outside the image clip, and
/// does not change the layout extent or create a continuous animation.
class RaftMountedAvatarFrame extends StatelessWidget {
  const RaftMountedAvatarFrame({
    super.key,
    required this.name,
    this.avatarContext = RaftMountedAvatarContext.panelHeader,
    this.identity = RaftMountedAvatarIdentity.human,
    this.child,
    this.presence,
    this.deactivated = false,
    this.muted = false,
    this.extent,
  });
  final String name;
  final RaftMountedAvatarContext avatarContext;
  final RaftMountedAvatarIdentity identity;
  final Widget? child;
  final RaftAvatarPresence? presence;
  final bool deactivated;

  /// Source MentionCandidateAvatar: opacity-60, no badge.
  final bool muted;

  /// Explicit product size override, such as LeftRail's short-desktop size-8.
  /// The identity's text/icon size and border recipe remain unchanged.
  final double? extent;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final r = RaftMountedAvatarRecipe(t, avatarContext, identity);
    final admitted =
        identity == RaftMountedAvatarIdentity.agent && !deactivated && !muted
        ? presence
        : null;
    final dimension = extent ?? r.extent;
    final size = RaftAvatarSize.nearest(dimension);
    Widget badge() {
      final dot = RaftAvatarBadge(
        key: const ValueKey('mounted-avatar-presence'),
        size: size,
        presence: admitted!.light,
        outlineColor: t.panel,
        label: admitted.label,
      );
      // Sidebar rows: Blink keeps the fractional inset and paints the
      // badge snapped to device pixels.
      return avatarContext == RaftMountedAvatarContext.sidebarList
          ? RaftCssPixelSnap(child: dot)
          : dot;
    }

    Widget frame = RaftStickerAvatar(
      size: size,
      extent: dimension,
      type: r.type,
      badgeOutlineColor: t.panel,
      frameKey: const ValueKey('mounted-avatar-frame'),
      contentKey: const ValueKey('mounted-avatar-image-clip'),
      badge: admitted == null ? null : badge(),
      child:
          child ??
          RaftMountedAvatarFallback(
            avatarContext: avatarContext,
            identity: identity,
            initials: name,
          ),
    );
    if (muted) frame = Opacity(opacity: .6, child: frame);
    if (deactivated && identity == RaftMountedAvatarIdentity.agent) {
      frame = Opacity(
        opacity: .6,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            .2126,
            .7152,
            .0722,
            0,
            0,
            .2126,
            .7152,
            .0722,
            0,
            0,
            .2126,
            .7152,
            .0722,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: frame,
        ),
      );
    }
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: frame,
    );
  }
}
