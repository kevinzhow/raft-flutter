// raft-ui 0.7.1 `Avatar` (dist `avatar`): a square sticker. 1.5px ink border, `rounded-sticker` (4px), the die-cut
// `sticker-edge` ring, a stone (agent) or lavender (human) fill, and the content clipped to a 2px radius inside
// the border. Sizes 19 / 27 / 35 / 51 / 99 (the 99px one also casts the 4px ink `elevation-sticker`). A presence
// badge is a Status pixel pinned over the bottom-right corner with a 2px canvas-coloured outline.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens/tokens.dart';
import '../tooltip.dart';
import 'css_box.dart';
import 'status.dart';
import 'ui_tokens.dart';

/// The die-cut `sticker-edge` ring over [surface] (default `layer-canvas`): translucent in dark mode, so it is
/// blended the way Blink does (see [raftChromeBlend]); the clear light-mode ring stays clear.
Color raftStickerEdge(RaftUiColors ui, [Color? surface]) {
  final edge = ui.stickerEdge;
  return edge.a == 0 ? edge : raftChromeBlend(edge, surface ?? ui.layerCanvas);
}

/// `type` axis of `avatar`: agents sit on `inactive` stone, people on `palette-lavender`.
enum RaftAvatarType { agent, human }

/// `size` axis of `avatar`, with the per-size fallback text, placeholder icon and badge (`group-data-[size]`).
enum RaftAvatarSize {
  xl(99, text: 40, icon: 48, badge: 20, badgeOffset: 8, badgeBorder: 2),
  lg(51, text: 22, icon: 24, badge: 14, badgeOffset: 5),
  md(35, text: 15, icon: 18, badge: 11, badgeOffset: 4),
  sm(27, text: 13, icon: 14, badge: 9, badgeOffset: 3),
  xs(19, text: 11, icon: 12, badge: 9, badgeOffset: 3, badgeOutline: 1),
  xxs(19, text: 11, icon: 12, badge: 9, badgeOffset: 3, badgeOutline: 1),
  xxxs(
    14,
    text: 8,
    icon: 8,
    badge: 6,
    badgeOffset: 2,
    badgeBorder: 1,
    badgeOutline: 1,
  );

  const RaftAvatarSize(
    this.extent, {
    required this.text,
    required this.icon,
    required this.badge,
    required this.badgeOffset,
    this.badgeBorder = 1.5,
    this.badgeOutline = 2,
  });

  /// `size-[99px]` ... (border box).
  final double extent;

  /// Fallback initials font size (`text-[22px]`, leading-none).
  final double text;

  /// Fallback placeholder icon edge.
  final double icon;

  /// Presence badge edge, how far it sticks out of the padding box (`-right-1`), its CSS border width and the
  /// canvas-coloured `outline-*` width.
  final double badge, badgeOffset, badgeBorder, badgeOutline;

  /// The size class a free extent (a mounted slot's `!size-[18px]`) borrows its text, icon and badge from.
  static RaftAvatarSize nearest(double extent) {
    if (extent >= 75) return xl;
    if (extent >= 43) return lg;
    if (extent >= 31) return md;
    if (extent >= 23) return sm;
    if (extent >= 16.5) return xs;
    return xxxs;
  }
}

/// The up-to-[max] initials of a name: first letters of its first words (`Mia Chen` is `MC`, `Wug` is `W`),
/// upper-cased. Empty for a blank name.
String raftAvatarInitials(String name, {int max = 2}) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.take(max).map((w) => w.characters.first).join().toUpperCase();
}

/// `AvatarFallback` text: `font-sans font-bold leading-none tracking-[-0.01em] text-sticker-ink`.
class RaftAvatarInitials extends StatelessWidget {
  const RaftAvatarInitials(this.text, {super.key, required this.size});
  final String text;
  final RaftAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // FittedBox: two initials in the smallest stickers shrink to the box instead of being cut off.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          // The avatar is a fixed-size sticker (px sizes, no rem): its initials keep their size, and a tall CJK glyph
          // may pass the 1.0 line box (the avatar clips them).
          overflow: TextOverflow.visible,
          textScaler: TextScaler.noScaling,
          style: t
              .scale(
                RaftTypeScale.body,
                weight: FontWeight.w700,
                color: t.ui.stickerInk,
                trackingEm: -0.01,
              )
              .copyWith(fontSize: size.text, height: 1),
        ),
      ),
    );
  }
}

/// `AvatarFallbackIcon`: the person with a dotted halo, drawn on an 18-unit viewBox, 1-unit strokes.
class RaftAvatarPlaceholder extends StatelessWidget {
  const RaftAvatarPlaceholder({super.key, required this.size, this.color});
  final RaftAvatarSize size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: size.icon,
      child: CustomPaint(
        painter: _PlaceholderPainter(
          color ?? RaftTokens.of(context).ui.stickerInk,
        ),
      ),
    ),
  );
}

class _PlaceholderPainter extends CustomPainter {
  _PlaceholderPainter(this.color);
  final Color color;

  static const _dots = [
    (1.889, 10.414),
    (2.971, 4.972),
    (2.972, 13.027),
    (1.89, 7.586),
    (4.973, 2.972),
    (7.586, 1.889),
    (15.029, 13.028),
    (16.111, 7.586),
    (13.028, 2.971),
    (16.11, 10.414),
    (15.028, 4.973),
    (10.414, 1.89),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 18, size.height / 18);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(9, 7.75), 2, stroke);
    // M9,16.25 c1.407,0,2.716-.407,3.827-1.101 -.481-1.67-2.003-2.899-3.827-2.899 s-3.347,1.229-3.827,2.899
    // c1.112,.694,2.42,1.101,3.827,1.101 Z
    final body = Path()
      ..moveTo(9, 16.25)
      ..cubicTo(10.407, 16.25, 11.716, 15.843, 12.827, 15.149)
      ..cubicTo(12.346, 13.479, 10.824, 12.25, 9, 12.25)
      ..cubicTo(7.176, 12.25, 5.653, 13.479, 5.173, 15.149)
      ..cubicTo(6.285, 15.843, 7.593, 16.25, 9, 16.25)
      ..close();
    canvas.drawPath(body, stroke);
    final fill = Paint()..color = color;
    for (final (x, y) in _dots) {
      canvas.drawCircle(Offset(x, y), .75, fill);
    }
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) => old.color != color;
}

/// raft-ui `Avatar`. [child] is the content (a pixel face, an image, [RaftAvatarInitials], a
/// [RaftAvatarPlaceholder]); it fills the padding box, clipped to a 2px radius. Pass [extent] to size the
/// sticker freely (a mounted slot) while [size] still picks the text, icon and badge sizes.
class RaftStickerAvatar extends StatelessWidget {
  const RaftStickerAvatar({
    super.key,
    this.size = RaftAvatarSize.md,
    this.extent,
    this.type = RaftAvatarType.agent,
    this.child,
    this.presence,
    this.presenceLabel,
    this.badge,
    this.badgeOutlineColor,
    this.frameKey,
    this.contentKey,
    this.presenceKey,
  });

  final RaftAvatarSize size;

  /// Free border-box edge; null is [size]'s.
  final double? extent;
  final RaftAvatarType type;
  final Widget? child;

  /// The presence badge (`AvatarBadge`): a [RaftStatus] pixel in the presence colour.
  final RaftPresence? presence;

  /// Tooltip of the presence badge.
  final String? presenceLabel;

  /// A caller-built badge instead of [presence] (`AvatarBadge render={<Status variant=.../>}`); it is pinned the
  /// same way and keeps its own look.
  final Widget? badge;

  /// `outline-layer-canvas` of the badge, and the backdrop of the die-cut ring: the surface the avatar sits on.
  /// Defaults to `layer-canvas`.
  final Color? badgeOutlineColor;
  final Key? frameKey, contentKey, presenceKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final dimension = extent ?? size.extent;
    final border = raftControlBorderPx(context, 1.5);
    // Both radii come from the theme. The inner one is its own token rather
    // than outer - inset: the official Raft specimen insets the image by 1px
    // and still rounds it to 2, so concentric arithmetic would give 3.
    final radiusOuter = t.size('radius.avatar', fallback: 4);
    final radiusInner = t.size('radius.avatarInner', fallback: 2);
    Widget frame = RaftCssBox(
      key: frameKey,
      radius: radiusOuter,
      fill: type == RaftAvatarType.human
          ? ui['palette-lavender-400']
          : ui.inactive,
      borderWidth: border,
      borderColor: ui.stickerInk,
      rings: [RaftRing(1.5, raftStickerEdge(ui, badgeOutlineColor))],
      width: dimension,
      height: dimension,
      child: ClipRRect(
        key: contentKey,
        borderRadius: BorderRadius.circular(radiusInner),
        child: SizedBox.expand(child: child),
      ),
    );
    final dot =
        badge ??
        (presence == null
            ? null
            : RaftAvatarBadge(
                key: presenceKey,
                size: size,
                presence: presence!,
                outlineColor: badgeOutlineColor,
                label: presenceLabel,
              ));
    final cast = size == RaftAvatarSize.xl && extent == null;
    if (dot == null && !cast) return frame;
    return SizedBox.square(
      dimension: dimension,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (cast)
            Positioned(
              left: _elevation(t).dx,
              top: _elevation(t).dy,
              width: dimension,
              height: dimension,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _elevationColor(t),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          Positioned.fill(child: frame),
          if (dot != null)
            Positioned(
              right: border - size.badgeOffset,
              bottom: border - size.badgeOffset,
              child: dot,
            ),
        ],
      ),
    );
  }

  static Offset _elevation(RaftTokens t) =>
      (t.dark ? RaftDark.elevationSticker : RaftLight.elevationSticker)
          .layers
          .first
          .offset;

  static Color _elevationColor(RaftTokens t) =>
      (t.dark ? RaftDark.elevationSticker : RaftLight.elevationSticker)
          .layers
          .first
          .color;
}

/// `AvatarBadge`: the presence pixel of an avatar, [size].badge wide.
class RaftAvatarBadge extends StatelessWidget {
  const RaftAvatarBadge({
    super.key,
    required this.size,
    this.presence,
    this.variant = RaftStatusVariant.default_,
    this.outlineColor,
    this.label,
  });

  final RaftAvatarSize size;

  /// The presence light, or (without one) the [variant] colour (`AvatarBadge render={<Status variant=.../>}`).
  final RaftPresence? presence;
  final RaftStatusVariant variant;
  final Color? outlineColor;

  /// Tooltip / accessible name.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ui = RaftTokens.of(context).ui;
    final dot = RaftCssBox(
      radius: 2,
      fill: RaftStatus.fillOf(ui, presence: presence, variant: variant),
      borderWidth: raftControlBorderPx(context, size.badgeBorder),
      borderColor: ui.stickerInk,
      rings: [
        RaftRing(
          math.max(1, size.badgeOutline),
          outlineColor ?? ui.layerCanvas,
        ),
      ],
      width: size.badge,
      height: size.badge,
    );
    return label == null || label!.isEmpty
        ? dot
        : RaftTooltip(message: label!, child: dot);
  }
}
