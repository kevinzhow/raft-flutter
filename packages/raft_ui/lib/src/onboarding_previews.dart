import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'agent_profile.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'text_scaling.dart' show RaftChrome;
import 'theme.dart';
import 'tokens/shadows.g.dart';

/// OnboardingCreateDotPane: `bg-layer-canvas-muted theme-brutal:bg-brutal-cream`, a 16px radial dot grid
/// (`radial-gradient(var(--line-strong) 1px, transparent 1px)`, opacity 60%) and the preview centred in a
/// `p-6 xl:p-8` box. Only mounted at the `lg` breakpoint (RaftOnboardingShell).
class RaftOnboardingDotPane extends StatelessWidget {
  const RaftOnboardingDotPane({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final padding = MediaQuery.sizeOf(context).width >= 1280 ? 32.0 : 24.0;
    return ClipRect(
      child: ColoredBox(
        color: t.brutal ? t.product.brutalCream : t.semantic.layerCanvasMuted,
        child: CustomPaint(
          painter: _DotGridPainter(t.semantic.lineStrong.withValues(alpha: .6)),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [child],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 8.0; y < size.height + 8; y += 16) {
      for (var x = 8.0; x < size.width + 8; x += 16) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

const _black = Color(0xFF000000);

BoxDecoration _brutalCard({
  Color color = const Color(0xFFFFFFFF),
  bool shadow = false,
}) => BoxDecoration(
  color: color,
  border: Border.all(color: _black, width: 2),
  boxShadow: shadow ? RaftProductShadows.shadowBrutalLg.outer : null,
);

TextStyle _text(
  RaftTokens t,
  double size,
  double line,
  FontWeight weight,
  Color color,
) => RaftTypography.heading(
  t,
  size: size,
  line: line,
  weight: weight,
).copyWith(color: color);

TextStyle _mono(
  RaftTokens t,
  double size,
  double line,
  FontWeight weight,
  Color color,
) => RaftTypography.mono(
  t,
  size: size,
  line: line,
  color: color,
).copyWith(fontWeight: weight);

const _rotation1 = -math.pi / 180;

// The identity cards combine Tailwind's `rotate-[-1deg]` / `rotate-[2deg]` (the `rotate` property) with the
// `onboarding-identity-card-enter` animation's final `transform: rotate(-1deg / 2deg)`: the rendered angles
// are double.
const _identityRotation1 = -2 * math.pi / 180;
const _identityRotation2 = 4 * math.pi / 180;

/// ServerCreatePreview (components/auth/ServerCreatePreview.tsx): a rotated browser window showing the
/// workspace the typed name and slug will create.
class RaftServerCreatePreview extends StatelessWidget {
  const RaftServerCreatePreview({
    super.key,
    this.serverName = '',
    this.serverSlug = '',
  });
  final String serverName, serverSlug;

  static const defaultName = 'Alex Chen Studio';
  static const defaultSlug = 'alex-chen-studio';
  static const channel = 'onboarding-owner';

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final name = serverName.trim().isEmpty ? defaultName : serverName.trim();
    final slug = serverSlug.trim().isEmpty ? defaultSlug : serverSlug.trim();
    final custom = name != defaultName;
    final message = custom
        ? raftFormat(context, 'I am getting {serverName} ready.', {
            'serverName': name,
          })
        : tr(
            'Once the server is created, I will help you connect a computer and create Cindy.',
          );
    final dim = _black.withValues(alpha: .4);
    Widget dot(Color color) =>
        Container(width: 12, height: 12, decoration: _brutalCard(color: color));
    final header = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.product.brutalCream,
        border: const Border(bottom: BorderSide(color: _black, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // ds-allow: Web ServerCreatePreview.tsx `pl-px`
            padding: const EdgeInsets.only(left: 1),
            child: Row(
              children: [
                dot(t.product.brutalPink),
                const SizedBox(width: 6),
                dot(t.product.softSignal),
                const SizedBox(width: 6),
                dot(t.product.brutalLime),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _black, width: 2),
              boxShadow: RaftProductShadows.shadowBrutalSm.outer,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RaftIcon(
                        RaftGlyph.lockKeyhole,
                        size: 12,
                        color: _black.withValues(alpha: .5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'app.raft.build/s/',
                        style: _mono(
                          t,
                          12,
                          16,
                          FontWeight.w400,
                          _black.withValues(alpha: .5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          slug,
                          overflow: TextOverflow.ellipsis,
                          style: _mono(t, 12, 16, FontWeight.w700, _black),
                        ),
                      ),
                    ],
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
        height: 24,
        child: Row(
          children: [
            // Expanded sections rotate the ChevronRight 90 degrees.
            Transform.rotate(
              angle: math.pi / 2,
              child: const RaftIcon(
                RaftGlyph.chevronRight,
                size: 12,
                strokeWidth: 3,
                color: _black,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: _text(
                t,
                11,
                16.5,
                FontWeight.w700,
                _black,
              ).copyWith(letterSpacing: .88),
            ),
            const SizedBox(width: 6),
            Text('$count', style: _mono(t, 11, 16.5, FontWeight.w700, dim)),
          ],
        ),
      ),
    );
    Widget row({
      required Widget child,
      Widget? avatar,
      bool active = false,
      bool hash = false,
      bool last = false,
    }) => Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, last ? 0 : 4),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.product.brutalPink : null,
          border: Border.all(
            color: active ? _black : Colors.transparent,
            width: 2,
          ),
          boxShadow: active ? RaftProductShadows.shadowBrutalSm.outer : null,
        ),
        child: Row(
          children: [
            if (hash) ...[
              Text(
                '#',
                style: _text(
                  t,
                  12,
                  16,
                  active ? FontWeight.w700 : FontWeight.w500,
                  _black.withValues(alpha: .45),
                ),
              ),
              const SizedBox(width: 6),
            ],
            ?avatar,
            if (avatar != null) const SizedBox(width: 6),
            Flexible(child: child),
          ],
        ),
      ),
    );
    Widget rowText(String s, {bool active = false}) => Text(
      s,
      overflow: TextOverflow.ellipsis,
      style: _text(
        t,
        12,
        16,
        active ? FontWeight.w700 : FontWeight.w500,
        t.semantic.foreground,
      ),
    );
    final sidebar = Container(
      width: 200,
      decoration: BoxDecoration(
        color: t.product.brutalCream,
        border: const Border(right: BorderSide(color: _black, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: t.product.softSignal,
              border: const Border(bottom: BorderSide(color: _black, width: 2)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _black,
                border: Border.all(color: _black, width: 2),
                boxShadow: RaftProductShadows.shadowBrutalSm.outer,
              ),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(t, 12, 16, FontWeight.w700, t.product.softSignal),
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
          sectionLabel(tr('Direct Messages'), 1),
          row(
            last: true,
            avatar: const RaftAvatarSlot(
              name: 'Cindy',
              avatarUrl: 'pixel:mug',
              slot: RaftAvatarSlotContext.compactList,
            ),
            child: rowText('Cindy'),
          ),
        ],
      ),
    );
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _black, width: 2)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: _brutalCard(color: t.product.softSignal),
                child: const Center(
                  child: RaftIcon(RaftGlyph.hash, size: 16, color: _black),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  channel,
                  overflow: TextOverflow.ellipsis,
                  style: _text(t, 14, 20, FontWeight.w700, _black),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    // ds-allow: Web ServerCreatePreview.tsx MessageRow avatar `mt-px`
                    padding: EdgeInsets.only(top: 1),
                    child: RaftAvatarSlot(
                      name: 'Cindy',
                      avatarUrl: 'pixel:mug',
                      slot: RaftAvatarSlotContext.surfaceList,
                      sizeOverride: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Cindy',
                                style: _text(
                                  t,
                                  12,
                                  16,
                                  FontWeight.w700,
                                  _black,
                                ),
                              ),
                              const WidgetSpan(child: SizedBox(width: 6)),
                              TextSpan(
                                text: tr('onboarding agent'),
                                style: _mono(
                                  t,
                                  9.5,
                                  12.6667,
                                  FontWeight.w700,
                                  dim,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: _text(
                            t,
                            12,
                            20,
                            FontWeight.w400,
                            _black.withValues(alpha: .8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _black, width: 2)),
          ),
          child: Opacity(
            opacity: .6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _black, width: 2),
                boxShadow: RaftProductShadows.shadowBrutalSm.outer,
              ),
              child: Text(
                raftFormat(context, 'Message #{channel}', {'channel': channel}),
                style: _text(t, 12, 16, FontWeight.w400, dim),
              ),
            ),
          ),
        ),
      ],
    );
    return Transform.rotate(
      angle: _rotation1,
      child: SizedBox(
        height: 520,
        child: Container(
          decoration: _brutalCard(shadow: true),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sidebar,
                    Expanded(child: main),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// IdentityImpactPreview (AccountIdentitySetupPage.tsx): a rotated channel message card and a profile card
/// that mirror the typed display name, handle and avatar.
class RaftIdentityImpactPreview extends StatelessWidget {
  const RaftIdentityImpactPreview({
    super.key,
    this.displayName = '',
    this.handle = '',
    this.avatar,
  });
  final String displayName, handle;

  /// Avatar builder for a square size (the form's avatar); null draws the default human avatar.
  final Widget Function(double size)? avatar;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final name = displayName.trim().isEmpty
        ? tr('Alex Chen')
        : displayName.trim();
    final handleText = handle.trim().isEmpty ? tr('alexchen') : handle.trim();
    // AvatarSlot `account-tile` (56) / `members-row` (28): Brutal lavender tile, user glyph 24 / 16.
    Widget avatarOf(double size) =>
        avatar?.call(size) ??
        (size >= 48
            ? RaftAvatarSlot(
                name: name,
                agent: false,
                slot: RaftAvatarSlotContext.profileTile,
                sizeOverride: size,
              )
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: t.brutal
                      ? t.product.brutalLavender
                      : t.semantic.fillMuted,
                  border: t.brutal ? Border.all(color: _black) : null,
                  shape: t.brutal ? BoxShape.rectangle : BoxShape.circle,
                ),
                child: Center(
                  child: RaftIcon(
                    RaftGlyph.user,
                    size: 16,
                    color: t.brutal ? _black : t.semantic.foregroundMuted,
                  ),
                ),
              ));
    final body = _text(
      t,
      12,
      20,
      FontWeight.w400,
      _black.withValues(alpha: .8),
    );
    final template = tr(
      'morning — can <mention>@{handle}</mention> take a look at the Q3 draft?',
    );
    final open = template.indexOf('<mention>');
    final close = template.indexOf('</mention>');
    final before = template.substring(0, open);
    final after = template.substring(close + '</mention>'.length);
    final seeded = Text.rich(
      TextSpan(
        style: body,
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: t.product.softSignal,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '@$handleText',
                style: _text(t, 12, 20, FontWeight.w700, _black),
              ),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
    final channelCard = Container(
      decoration: _brutalCard(shadow: true),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _black, width: 2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: _brutalCard(color: t.product.softSignal),
                  child: const Center(
                    child: RaftIcon(RaftGlyph.hash, size: 15, color: _black),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tr('pricing'),
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      t,
                      14,
                      20,
                      FontWeight.w900,
                      t.semantic.foreground,
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
                    Padding(
                      // ds-allow: Web AccountIdentitySetupPage.tsx avatar `mt-px`
                      padding: const EdgeInsets.only(top: 1),
                      // ignore: raft_lints/avoid_fixed_height_text -- a fixed 28px avatar: the initial is bounded by RaftChrome and always fits
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: _brutalCard(
                          color: t.product.brutalLavender.withValues(alpha: .7),
                        ),
                        child: Text(
                          'M',
                          textScaler: RaftChrome.boundedScalerOf(context),
                          style: _text(
                            t,
                            11,
                            16.5,
                            FontWeight.w900,
                            t.semantic.foreground,
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
                            style: _text(t, 12, 16, FontWeight.w700, _black),
                          ),
                          const SizedBox(height: 2),
                          seeded,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      // ds-allow: Web AccountIdentitySetupPage.tsx avatar `mt-px`
                      padding: const EdgeInsets.only(top: 1),
                      child: SizedBox.square(
                        dimension: 28,
                        child: avatarOf(28),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: name,
                                  style: _text(
                                    t,
                                    12,
                                    16,
                                    FontWeight.w700,
                                    _black,
                                  ),
                                ),
                                const WidgetSpan(child: SizedBox(width: 6)),
                                TextSpan(
                                  text: tr('2:41 PM').toUpperCase(),
                                  style: _mono(
                                    t,
                                    9.5,
                                    14.25,
                                    FontWeight.w700,
                                    _black.withValues(alpha: .35),
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr('On it, will have comments by noon.'),
                            style: body,
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
    );
    final profileCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: _brutalCard(shadow: true),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(dimension: 56, child: avatarOf(56)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    t,
                    16,
                    24,
                    FontWeight.w900,
                    t.semantic.foreground,
                  ),
                ),
                Text(
                  '@$handleText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mono(
                    t,
                    12,
                    16,
                    FontWeight.w700,
                    _black.withValues(alpha: .5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    // `relative z-10 min-h-[520px] w-full max-w-[640px] p-4 sm:p-6` > `h-full min-h-[460px]` centred >
    // `w-[min(100%,520px)]` > `relative pb-24` (card 1 w-[min(92%,480px)], card 2 absolute bottom-2 right-0
    // w-[min(78%,360px)]).
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, minHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          // `h-full min-h-[460px]` inside the 472px content box of the border-box `min-h-[520px]` preview: the
          // 460px box sits at the top (36px spare below), the cards centre inside it.
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: SizedBox(
              height: 460,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final zone = math.min(box.maxWidth, 520.0);
                    return SizedBox(
                      width: zone,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 96),
                            child: Align(
                              alignment: Alignment.topLeft,
                              heightFactor: 1,
                              child: SizedBox(
                                width: math.min(zone * .92, 480),
                                child: Transform.rotate(
                                  angle: _identityRotation1,
                                  child: channelCard,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 8,
                            width: math.min(zone * .78, 360),
                            child: Transform.rotate(
                              angle: _identityRotation2,
                              child: profileCard,
                            ),
                          ),
                        ],
                      ),
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
