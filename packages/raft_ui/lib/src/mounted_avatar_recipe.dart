import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftTypography;
import 'icons.dart';
import 'theme.dart';
import 'tooltip.dart';

/// Mounted AvatarSlot contexts, independent of generic Avatar sizing.
enum RaftMountedAvatarContext {
  panelHeader,
  compactList,
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
}

/// Tier 1: product index.css57 and Tailwind gray-400 (CSS to sRGB conversion).
abstract final class RaftAvatarStatusPrimitives {
  static const busy = Color(0xffffd440);
  static const offline = Color(0xff99a1af);
}

/// Tier 3: AvatarSlot SPEC/RAFT_AVATAR_SPEC and RUI0.5.27 avatar recipe.
@immutable
class RaftMountedAvatarRecipe {
  const RaftMountedAvatarRecipe(this.tokens, this.avatarContext, this.identity);
  final RaftTokens tokens;
  final RaftMountedAvatarContext avatarContext;
  final RaftMountedAvatarIdentity identity;
  bool get panelHeader => avatarContext == RaftMountedAvatarContext.panelHeader;
  bool get sidebarList => avatarContext == RaftMountedAvatarContext.sidebarList;
  bool get previewMini => avatarContext == RaftMountedAvatarContext.previewMini;
  // RAFT_AVATAR_SPEC: panel-header !size-9, compact-list !size-5,
  // sidebar-list !size-[18px], preview-mini !size-[14px]; SPEC icon sizes.
  double get extent => panelHeader
      ? 36
      : sidebarList
      ? 18
      : previewMini
      ? 14
      : 20;
  double get borderWidth => panelHeader ? 2 : 1;
  double get contentExtent => extent - borderWidth * 2;
  double get placeholderExtent => panelHeader
      ? 18
      : sidebarList || previewMini
      ? 10
      : 12;
  // One glyph size for the humanPlaceholder and the Gravatar User fallback:
  // a gravatar hash that arrives after first paint never resizes the glyph.
  double get gravatarFallbackExtent => placeholderExtent;
  double get badgeExtent => panelHeader ? 10 : 6;
  double get radius => tokens.brutal ? 0 : extent / 2;
  Color get border => tokens.brutal ? Colors.black : Colors.transparent;
  Color get fallbackFill => tokens.brutal
      ? identity == RaftMountedAvatarIdentity.agent
            ? tokens.colors['color-brutal-cyan']!
            : identity == RaftMountedAvatarIdentity.human
            ? tokens.colors['color-brutal-lavender']!
            : tokens.primaryFill
      : tokens.colors[identity == RaftMountedAvatarIdentity.human
            ? 'fill-strong'
            : 'fill-muted']!;
  Color get placeholderForeground => tokens.brutal
      ? Colors.black
      : tokens.colors['foreground-placeholder']!.withValues(
          alpha: tokens.colors['foreground-placeholder']!.a * .7,
        );

  // Absolute CSS badge positions are relative to the padding box. The panel
  // value is also checked against actual mounted DOM: global inset1 Elegant,
  // global inset-2.75 Brutal. Compact badge is source-recipe only: the public
  // MessageReplies fixture mounts compact avatars without presence chrome.
  double get badgeInset => tokens.brutal
      ? borderWidth - (panelHeader ? 4.75 : 2.75)
      : panelHeader
      ? 1
      : borderWidth + .333;
  Color get badgeBorder =>
      tokens.brutal ? Colors.black : tokens.colors['line-strong']!;
  List<BoxShadow> get badgeOutline => tokens.brutal
      ? const []
      : [BoxShadow(color: tokens.panel, spreadRadius: 2)];

  /// Tier 2: fixed status roles; the busy lamp never inherits a skin accent.
  Color activityFill(RaftAvatarPresence presence) =>
      presence.external && !presence.online
      ? tokens.colors['color-brutal-cyan']!
      : switch (presence.activity) {
          RaftAvatarActivity.online => tokens.colors['color-brutal-lime']!,
          RaftAvatarActivity.thinking ||
          RaftAvatarActivity.working => RaftAvatarStatusPrimitives.busy,
          RaftAvatarActivity.error => tokens.colors['color-brutal-orange']!,
          RaftAvatarActivity.offline => RaftAvatarStatusPrimitives.offline,
        };
}

/// Fallback for the leaf's existing uploaded → Gravatar → placeholder chain.
/// Use gravatar:true for the nested GravatarAvatar User icon, false for the
/// explicit humanPlaceholder branch. Neither path resolves identity or URLs.
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
    final t = RaftTokens.of(context);
    final r = RaftMountedAvatarRecipe(t, avatarContext, identity);
    return Center(
      child: identity == RaftMountedAvatarIdentity.human
          ? RaftIcon(
              RaftGlyph.user,
              size: gravatar ? r.gravatarFallbackExtent : r.placeholderExtent,
              color: r.placeholderForeground,
            )
          : identity == RaftMountedAvatarIdentity.agent
          ? const SizedBox.shrink() // Existing RaftAvatarContent owns pixel art.
          : Text(
              initials.trim().isEmpty
                  ? identity == RaftMountedAvatarIdentity.server
                        ? 'S'
                        : 'A'
                  : initials
                        .trim()
                        .characters
                        .take(
                          identity == RaftMountedAvatarIdentity.server ? 1 : 2,
                        )
                        .toString()
                        .toUpperCase(),
              style: TextStyle(
                fontFamily: t.headingFont,
                fontSize: r.panelHeader ? 14 : 10,
                fontWeight: identity == RaftMountedAvatarIdentity.app
                    ? RaftTypography.black(t)
                    : FontWeight.w700,
                color: t.brutal ? Colors.black : r.placeholderForeground,
              ),
            ),
    );
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

  /// Source MentionCandidateAvatar: !border-black/40 opacity-60, no badge.
  final bool muted;

  /// Explicit product size override, such as LeftRail's short-desktop size-8.
  /// The identity's text/icon size and border recipe remain unchanged.
  final double? extent;
  @override
  Widget build(BuildContext context) {
    final r = RaftMountedAvatarRecipe(
      RaftTokens.of(context),
      avatarContext,
      identity,
    );
    final admitted =
        identity == RaftMountedAvatarIdentity.agent && !deactivated && !muted
        ? presence
        : null;
    final dimension = extent ?? r.extent;
    final radius = BorderRadius.circular(r.tokens.brutal ? 0 : dimension / 2);
    Widget frame = SizedBox.square(
      dimension: dimension,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: const ValueKey('mounted-avatar-frame'),
              decoration: BoxDecoration(
                border: Border.all(
                  color: muted ? Colors.black.withValues(alpha: .4) : r.border,
                  width: r.borderWidth,
                ),
                borderRadius: radius,
              ),
              child: Padding(
                padding: EdgeInsets.all(r.borderWidth),
                child: DecoratedBox(
                  key: const ValueKey('mounted-avatar-fallback-fill'),
                  decoration: BoxDecoration(
                    color: r.fallbackFill,
                    borderRadius: radius,
                  ),
                  child: ClipRRect(
                    key: const ValueKey('mounted-avatar-image-clip'),
                    borderRadius: radius,
                    child: SizedBox.expand(
                      child:
                          child ??
                          RaftMountedAvatarFallback(
                            avatarContext: avatarContext,
                            identity: identity,
                            initials: name,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (admitted != null)
            Positioned(
              right: r.badgeInset,
              bottom: r.badgeInset,
              child: _PresenceDot(recipe: r, presence: admitted),
            ),
        ],
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

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.recipe, required this.presence});
  final RaftMountedAvatarRecipe recipe;
  final RaftAvatarPresence presence;
  @override
  Widget build(BuildContext context) {
    final dot = SizedBox.square(
      dimension: recipe.badgeExtent,
      child: DecoratedBox(
        key: const ValueKey('mounted-avatar-presence'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recipe.activityFill(presence),
          border: Border.all(color: recipe.badgeBorder),
          boxShadow: recipe.badgeOutline,
        ),
      ),
    );
    final label = presence.label;
    return label == null || label.isEmpty
        ? dot
        : RaftTooltip(message: label, child: dot);
  }
}
