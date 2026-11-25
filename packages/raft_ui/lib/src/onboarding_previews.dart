import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'agent_profile.dart';
import 'icons.dart';
import 'interaction.dart';
import 'localization.dart';
import 'raft/avatar.dart';
import 'raft/css_box.dart';
import 'raft/ui_tokens.dart';
import 'text_scaling.dart' show RaftChrome;
import 'theme.dart';
import 'tokens/raft_tokens.g.dart';

/// OnboardingCreateDotPane: `bg-layer-onboarding-pane`, a 14px radial dot grid
/// at 0.7 opacity behind the centered preview.
class RaftOnboardingDotPane extends StatelessWidget {
  const RaftOnboardingDotPane({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1280;
    final padding = wide ? 32.0 : 24.0;
    final dotBase = t.colors['line-onboarding-dot'] ?? t.ui.lineSeam;
    return ColoredBox(
      color: t.colors['layer-onboarding-pane'] ?? t.ui.layerSidebar,
      child: CustomPaint(
        painter: _DotGridPainter(
          color: dotBase.withValues(
            alpha: dotBase.a * t.size('opacity.onboardingDots', fallback: .7),
          ),
          grid: t.size('size.onboardingDotGrid', fallback: 14),
          radius: t.size('size.onboardingDotRadius', fallback: 1.5),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padded = Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [child],
              ),
            );
            if (constraints.maxHeight.isFinite &&
                constraints.maxHeight >= 520 + padding * 2) {
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: padded,
              );
            }
            return SingleChildScrollView(child: padded);
          },
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({
    required this.color,
    required this.grid,
    required this.radius,
  });

  final Color color;
  final double grid;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = grid / 2; y < size.height; y += grid) {
      for (var x = grid / 2; x < size.width; x += grid) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) =>
      old.color != color || old.grid != grid || old.radius != radius;
}

double _stickerStroke(BuildContext context, RaftTokens t) =>
    raftControlBorderPx(context, t.size('border.sticker', fallback: 1.5));

double _hairlineStroke(BuildContext context, RaftTokens t) =>
    raftControlBorderPx(context, t.size('border.seam', fallback: 1));

List<BoxShadow> _stickerShadow(RaftTokens t) =>
    (t.dark ? RaftDark.elevationSticker : RaftLight.elevationSticker).outer;

BoxDecoration _stickerCardDecoration(
  BuildContext context,
  RaftTokens t, {
  Color? color,
  bool shadow = false,
}) => BoxDecoration(
  color: color ?? t.ui.layerCanvas,
  borderRadius: BorderRadius.all(
    Radius.circular(t.size('radius.container', fallback: RaftRadius.container)),
  ),
  border: Border.all(color: t.ui.lineStrong, width: _stickerStroke(context, t)),
  boxShadow: shadow ? _stickerShadow(t) : null,
);

/// Live ServerCreatePreview mirroring Web `ServerCreatePreview.tsx`.
class RaftServerCreatePreview extends StatelessWidget {
  const RaftServerCreatePreview({
    super.key,
    this.serverName = '',
    this.serverSlug = '',
  });

  final String serverName;
  final String serverSlug;

  static const defaultName = 'Alex Chen Studio';
  static const defaultSlug = 'alex-chen-studio';
  static const channel = 'onboarding-owner';

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    String tr(String s) => raftText(context, s);

    final trimmedName = serverName.trim();
    final name = trimmedName.isEmpty ? defaultName : trimmedName;
    final trimmedSlug = serverSlug.trim();
    final slug = trimmedSlug.isEmpty ? defaultSlug : trimmedSlug;
    final hasCustomName = trimmedName.isNotEmpty;
    final cindyMessage = hasCustomName
        ? raftFormat(context, 'I am getting {serverName} ready.', {
            'serverName': name,
          })
        : tr(
            'Once the server is created, I will help you connect a computer and create Cindy.',
          );

    final chipRadius = t.size('radius.chip', fallback: RaftRadius.chip);
    final controlRadius = t.size(
      'radius.control',
      fallback: RaftRadius.control,
    );
    final containerRadius = t.size(
      'radius.container',
      fallback: RaftRadius.container,
    );
    final dotRadius =
        t.size('radius.sticker', fallback: RaftRadius.sticker) / 2;
    final stickerWidth = _stickerStroke(context, t);
    final seamWidth = _hairlineStroke(context, t);
    final stickerEdge = raftStickerEdge(ui);
    final selectedBg = ui['selected'];

    Widget dot(Color color) => RaftCssBox(
      width: 12,
      height: 12,
      radius: dotRadius,
      fill: color,
      borderWidth: stickerWidth,
      borderColor: ui.stickerInk,
    );

    final bar = Container(
      decoration: BoxDecoration(
        color: ui.layerSidebar,
        border: Border(
          bottom: BorderSide(color: ui.lineSeam, width: seamWidth),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Transform.translate(
            offset: const Offset(1, 0),
            child: Row(
              children: [
                dot(ui.attention),
                const SizedBox(width: 6),
                dot(ui.brand),
                const SizedBox(width: 6),
                dot(ui.success),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RaftCssBox(
            height: 32,
            radius: controlRadius,
            fill: ui.layerCard,
            borderWidth: stickerWidth,
            borderColor: ui.lineStrong,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RaftIcon(RaftGlyph.lock, size: 12, color: ui.foregroundHint),
                const SizedBox(width: 6),
                Text(
                  'app.raft.build/s/',
                  style: t.scale(
                    RaftTypeScale.monoMeta,
                    mono: true,
                    color: ui.foregroundHint,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    slug,
                    overflow: TextOverflow.ellipsis,
                    style: t.scale(
                      RaftTypeScale.monoMeta,
                      mono: true,
                      weight: FontWeight.w700,
                      color: ui.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget sectionLabel(String label, int count) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            RaftIcon(RaftGlyph.chevronDown, size: 12, color: ui.foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: t.scale(
                  RaftTypeScale.monoMeta,
                  mono: true,
                  color: ui.foreground,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: t.scale(
                RaftTypeScale.monoMeta,
                mono: true,
                color: ui.foregroundHint,
              ),
            ),
          ],
        ),
      ),
    );

    Widget row({
      bool hash = false,
      bool active = false,
      bool last = false,
      Widget? avatar,
      required Widget child,
    }) => Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, last ? 0 : 4),
      child: RaftCssBox(
        minHeight: 32,
        radius: controlRadius,
        fill: active ? selectedBg : Colors.transparent,
        borderWidth: active ? stickerWidth : 0,
        borderColor: active ? ui.stickerInk : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            if (hash) ...[
              Text(
                '#',
                style: t.scale(
                  RaftTypeScale.footnote,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? ui.stickerInk : ui.foregroundHint,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (avatar != null) ...[avatar, const SizedBox(width: 6)],
            Expanded(child: child),
          ],
        ),
      ),
    );

    Text rowText(String text, {bool active = false}) => Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: t.scale(
        RaftTypeScale.footnote,
        weight: active ? FontWeight.w700 : FontWeight.w500,
        color: active ? ui.stickerInk : ui.foreground,
      ),
    );

    final headerHeight =
        !RaftInteraction.of(context).touch &&
            MediaQuery.sizeOf(context).width >= 768
        ? 44.0
        : 56.0;

    final sidebar = DecoratedBox(
      decoration: BoxDecoration(
        color: ui.layerSidebar,
        border: Border(
          right: BorderSide(color: ui.lineSeam, width: seamWidth),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ui.lineSeam, width: seamWidth),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: RaftCssBox(
              height: 32,
              radius: controlRadius,
              fill: ui.stickerInk,
              insetRingWidth: stickerWidth,
              insetRingColor: stickerEdge,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: t.scale(
                  RaftTypeScale.footnote,
                  weight: FontWeight.w700,
                  color: ui.brand,
                ),
              ),
            ),
          ),
          sectionLabel(tr('Channels'), 2),
          row(hash: true, child: rowText('all')),
          row(
            hash: true,
            active: true,
            last: true,
            child: rowText(channel, active: true),
          ),
          sectionLabel(tr('Direct messages'), 1),
          row(
            last: true,
            avatar: RaftAvatarSlot(
              name: 'Cindy',
              avatarUrl: 'pixel:mug',
              slot: RaftAvatarSlotContext.compactList,
              sizeOverride: RaftAvatarSize.xs.extent,
            ),
            child: rowText('Cindy'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    final chatPane = ColoredBox(
      color: ui.layerCanvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ui.lineSeam, width: seamWidth),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                RaftCssBox(
                  width: RaftAvatarSize.sm.extent,
                  height: RaftAvatarSize.sm.extent,
                  radius: chipRadius,
                  fill: ui.brand,
                  borderWidth: stickerWidth,
                  borderColor: ui.stickerInk,
                  alignment: Alignment.center,
                  child: RaftIcon(
                    RaftGlyph.hash,
                    size: 14,
                    color: ui.stickerInk,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    channel,
                    overflow: TextOverflow.ellipsis,
                    style: t.scale(
                      RaftTypeScale.headline,
                      weight: FontWeight.w700,
                      color: ui.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 1),
                    child: RaftAvatarSlot(
                      name: 'Cindy',
                      avatarUrl: 'pixel:mug',
                      slot: RaftAvatarSlotContext.surfaceList,
                      sizeOverride: RaftAvatarSize.sm.extent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Cindy',
                              style: t.scale(
                                RaftTypeScale.footnote,
                                weight: FontWeight.w700,
                                color: ui.foreground,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tr('onboarding agent'),
                                overflow: TextOverflow.ellipsis,
                                style: t.scale(
                                  RaftTypeScale.caption,
                                  color: ui.foregroundHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cindyMessage,
                          style: t.scale(
                            RaftTypeScale.callout,
                            color: ui.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: RaftCssBox(
              radius: containerRadius,
              fill: ui.layerCard,
              borderWidth: stickerWidth,
              borderColor: ui.lineStrong,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                raftFormat(context, 'Message #{channel}', {'channel': channel}),
                overflow: TextOverflow.ellipsis,
                style: t.scale(RaftTypeScale.callout, color: ui.foregroundHint),
              ),
            ),
          ),
        ],
      ),
    );

    return RaftChrome(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showSidebar = constraints.maxWidth >= 420;
          const targetHeight = 520.0;
          final targetWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 640.0;
          return Transform.rotate(
            angle: -math.pi / 180,
            child: SizedBox(
              width: targetWidth,
              height: targetHeight,
              child: Container(
                decoration: _stickerCardDecoration(context, t, shadow: true),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(
                    Radius.circular(
                      math.max(0, containerRadius - stickerWidth),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      bar,
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showSidebar)
                              SizedBox(width: 200, child: sidebar),
                            Expanded(child: chatPane),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Live IdentityImpactPreview mirroring Web `AccountIdentitySetupPage.tsx`.
class RaftIdentityImpactPreview extends StatelessWidget {
  const RaftIdentityImpactPreview({
    super.key,
    this.displayName = '',
    this.handle = '',
    this.avatar,
  });

  final String displayName;
  final String handle;

  /// Avatar builder for a square size (the form's avatar); null draws the default human avatar.
  final Widget Function(double size)? avatar;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    String tr(String s) => raftText(context, s);

    final displayNameText = displayName.trim().isEmpty
        ? tr('Alex Chen')
        : displayName.trim();
    final handleText = handle.trim().isEmpty ? tr('alexchen') : handle.trim();

    final smSize = RaftAvatarSize.sm.extent;
    final lgSize = RaftAvatarSize.lg.extent;
    final stickerWidth = _stickerStroke(context, t);
    final seamWidth = _hairlineStroke(context, t);
    final containerRadius = t.size(
      'radius.container',
      fallback: RaftRadius.container,
    );
    final chipRadius = t.size('radius.chip', fallback: RaftRadius.chip);
    final stickerRadius = t.size(
      'radius.sticker',
      fallback: RaftRadius.sticker,
    );

    Widget avatarOf(double size) => avatar != null
        ? avatar!(size)
        : RaftAvatarSlot(
            name: displayNameText,
            slot: size <= smSize + 2
                ? RaftAvatarSlotContext.surfaceList
                : RaftAvatarSlotContext.profileTile,
            sizeOverride: size,
            agent: false,
          );

    InlineSpan mentionInline() => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: RaftCssBox(
        radius: stickerRadius,
        fill: ui.brand,
        insetRingWidth: stickerWidth,
        insetRingColor: ui.stickerInk,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '@$handleText',
          style: t.scale(
            RaftTypeScale.callout,
            weight: FontWeight.w600,
            color: ui.stickerInk,
          ),
        ),
      ),
    );

    final template = tr(
      'morning — can <mention>@{handle}</mention> take a look at the Q3 draft?',
    );
    const mentionTag = '<mention>@{handle}</mention>';
    final tagIdx = template.indexOf(mentionTag);
    final calloutStyle = t.scale(RaftTypeScale.callout, color: ui.foreground);

    final seededMessage = RichText(
      text: TextSpan(
        style: calloutStyle,
        children: tagIdx >= 0
            ? [
                TextSpan(text: template.substring(0, tagIdx)),
                mentionInline(),
                TextSpan(text: template.substring(tagIdx + mentionTag.length)),
              ]
            : [TextSpan(text: template)],
      ),
    );

    final channelCard = Container(
      decoration: _stickerCardDecoration(
        context,
        t,
        color: ui.layerCanvas,
        shadow: true,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.all(
          Radius.circular(math.max(0, containerRadius - stickerWidth)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height:
                  !RaftInteraction.of(context).touch &&
                      MediaQuery.sizeOf(context).width >= 768
                  ? 44
                  : 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: ui.layerCanvas,
                border: Border(
                  bottom: BorderSide(color: ui.lineSeam, width: seamWidth),
                ),
              ),
              child: Row(
                children: [
                  RaftCssBox(
                    width: smSize,
                    height: smSize,
                    radius: chipRadius,
                    fill: ui.brand,
                    borderWidth: stickerWidth,
                    borderColor: ui.stickerInk,
                    alignment: Alignment.center,
                    child: RaftIcon(
                      RaftGlyph.hash,
                      size: 14,
                      color: ui.stickerInk,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('pricing'),
                      overflow: TextOverflow.ellipsis,
                      style: t.scale(
                        RaftTypeScale.headline,
                        weight: FontWeight.w700,
                        color: ui.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 1),
                        child: RaftCssBox(
                          width: smSize,
                          height: smSize,
                          radius: stickerRadius,
                          fill: ui['palette-lavender-400'],
                          borderWidth: stickerWidth,
                          borderColor: ui.stickerInk,
                          alignment: Alignment.center,
                          child: Text(
                            'M',
                            style: t.scale(
                              RaftTypeScale.caption,
                              weight: FontWeight.w700,
                              color: ui.stickerInk,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('Maya'),
                              style: t.scale(
                                RaftTypeScale.footnote,
                                weight: FontWeight.w700,
                                color: ui.foreground,
                              ),
                            ),
                            const SizedBox(height: 2),
                            seededMessage,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 1),
                        child: SizedBox(
                          width: smSize,
                          height: smSize,
                          child: avatarOf(smSize),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  displayNameText,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.scale(
                                    RaftTypeScale.footnote,
                                    weight: FontWeight.w700,
                                    color: ui.foreground,
                                  ),
                                ),
                                Text(
                                  tr('2:41 PM'),
                                  style: t.scale(
                                    RaftTypeScale.monoMeta,
                                    mono: true,
                                    color: ui.foregroundHint,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tr('On it, will have comments by noon.'),
                              style: calloutStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final profileCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: _stickerCardDecoration(
        context,
        t,
        color: ui['layer-popover'],
        shadow: true,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: lgSize, height: lgSize, child: avatarOf(lgSize)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayNameText,
                  overflow: TextOverflow.ellipsis,
                  style: t.scale(
                    RaftTypeScale.headline,
                    weight: FontWeight.w700,
                    color: ui.foreground,
                  ),
                ),
                Text(
                  '@$handleText',
                  overflow: TextOverflow.ellipsis,
                  style: t.scale(
                    RaftTypeScale.monoMeta,
                    mono: true,
                    color: ui.foregroundHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return RaftChrome(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, minHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, minHeight: 460),
              child: Center(
                heightFactor: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 520.0;
                    final channelWidth = math.min(width * 0.92, 480.0);
                    final profileWidth = math.min(width * 0.78, 360.0);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 96),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            heightFactor: 1,
                            child: SizedBox(
                              width: channelWidth,
                              child: Transform.rotate(
                                angle: -2 * math.pi / 180,
                                child: channelCard,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 8,
                          width: profileWidth,
                          child: Transform.rotate(
                            angle: 4 * math.pi / 180,
                            child: profileCard,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
