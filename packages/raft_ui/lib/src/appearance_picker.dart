import 'package:flutter/material.dart';
import 'package:raft_theme/raft_theme.dart' show RaftThemePack;

import 'design_primitives.dart';
import 'icons.dart';
import 'dialog_card.dart';
import 'localization.dart';
import 'theme.dart';

/// Appearance setting: which theme to paint with, and Light / Dark / System for
/// that theme's two modes.
///
/// The theme and the mode are separate choices: every theme carries its own
/// light and dark values, so any combination is meaningful.
class RaftAppearancePicker extends StatelessWidget {
  const RaftAppearancePicker({
    super.key,
    required this.appearance,
    required this.onChanged,
    this.showMode = true,
  });
  final RaftAppearance appearance;
  final ValueChanged<RaftAppearance> onChanged;

  /// Also offer Light / Dark / System. The Raft look shows those as the
  /// preview cards ([RaftAppearanceModeCards]) and keeps only the theme here.
  final bool showMode;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final eyebrow = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w700,
      color: t.muted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(raftText(context, 'Theme'), style: eyebrow),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: RaftRecipeSegmentedControl<String>(
            key: const Key('appearance-theme'),
            value: appearance.themeId,
            label: 'Theme',
            items: [
              for (final theme in builtInAppearanceThemes)
                (theme.id, null, raftText(context, theme.en)),
            ],
            onChanged: (id) => onChanged(appearance.copyWith(themeId: id)),
          ),
        ),
        if (showMode) ...[
          const SizedBox(height: 16),
          Text(raftText(context, 'Color mode'), style: eyebrow),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            // raft-ui SegmentedControl, recipe geometry without touch-target
            // growth.
            child: RaftRecipeSegmentedControl<ThemeMode>(
              key: const Key('appearance-mode'),
              value: appearance.mode,
              label: 'Appearance mode',
              items: const [
                (ThemeMode.light, null, 'Light'),
                (ThemeMode.dark, null, 'Dark'),
                (ThemeMode.system, null, 'System'),
              ],
              onChanged: (mode) => onChanged(appearance.copyWith(mode: mode)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            raftText(context, 'System follows your device.'),
            style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
          ),
        ],
      ],
    );
  }
}

/// Web v1.21.23 `AppearanceThemePicker`: Light / Dark / System as three
/// preview cards (`grid grid-cols-1 gap-2 sm:grid-cols-3`). Each card is a
/// miniature of the app in that mode (yellow frame, cream sidebar with the
/// sticker row, paper with the pink button); System is light with the dark
/// half on the diagonal. The checked card has a 1.5px `line-strong` border and
/// says "Saved on this device." under its label.
class RaftAppearanceModeCards extends StatelessWidget {
  const RaftAppearanceModeCards({
    super.key,
    required this.appearance,
    required this.onChanged,
  });
  final RaftAppearance appearance;
  final ValueChanged<RaftAppearance> onChanged;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 640;
    Widget card(ThemeMode mode, String label) => _ModeCard(
      key: ValueKey('appearance-theme-${mode.name}'),
      mode: mode,
      label: label,
      selected: appearance.mode == mode,
      pack: appearance.pack,
      onTap: () => onChanged(appearance.copyWith(mode: mode)),
    );
    final cards = [
      card(ThemeMode.light, raftText(context, 'Light')),
      card(ThemeMode.dark, raftText(context, 'Dark')),
      card(ThemeMode.system, raftText(context, 'System')),
    ];
    return Semantics(
      container: true,
      label: raftText(context, 'Appearance mode'),
      child: wide
          // The three cards hold the same content, so they share one height
          // without stretching (which breaks under a scroll view).
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [for (final c in cards) Expanded(child: c)],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: cards,
            ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.mode,
    required this.label,
    required this.selected,
    required this.pack,
    required this.onTap,
  });
  final ThemeMode mode;
  final String label;
  final bool selected;
  final RaftThemePack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final light = RaftTokens.theme(pack: pack);
    final dark = RaftTokens.theme(dark: true, pack: pack);
    Widget preview() => switch (mode) {
      ThemeMode.light => _PreviewSurface(tokens: light),
      ThemeMode.dark => _PreviewSurface(tokens: dark),
      ThemeMode.system => Stack(
        children: [
          _PreviewSurface(tokens: light),
          Positioned.fill(
            child: ClipPath(
              clipper: const _DiagonalClipper(),
              child: _PreviewSurface(tokens: dark),
            ),
          ),
        ],
      ),
    };
    final radius = t.size('radius.container', fallback: 10);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // `p-2`; the checked card swaps the 1px hairline for a 1.5px
          // `line-strong` border and `p-[7.5px]`.
          padding: EdgeInsets.all(selected ? 7.5 : 8),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? t.colors['line-strong']!
                  : t.colors['line-hairline']!,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              preview(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          weight: FontWeight.w600,
                          color: t.colors['foreground'],
                        ),
                      ),
                    ),
                    if (selected)
                      RaftIcon(
                        RaftGlyph.check,
                        size: 16,
                        color: t.colors['foreground'],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  height: 16,
                  child: selected
                      ? Text(
                          raftText(context, 'Saved on this device.'),
                          style: RaftTypography.body(
                            t,
                            size: 12,
                            line: 16,
                            color: t.colors['foreground-hint'],
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  const _DiagonalClipper();
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();
  @override
  bool shouldReclip(_DiagonalClipper old) => false;
}

/// ThemePreviewSurface: `flex h-20 overflow-hidden rounded-control border
/// border-line-seam bg-layer-canvas` of a frame strip (`w-3`), a sidebar
/// (`w-1/3`) with the sticker row and the paper with the pink button.
class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.tokens});
  final RaftTokens tokens;

  @override
  Widget build(BuildContext context) {
    final c = tokens.colors;
    final seam = BorderSide(color: c['line-seam']!);
    Widget bar(double widthFactor, Color color, {double height = 6}) =>
        FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
    final ink = c['foreground']!;
    return Container(
      height: 80,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c['layer-canvas'],
        borderRadius: BorderRadius.circular(
          tokens.size('radius.control', fallback: 8),
        ),
        border: Border.fromBorderSide(seam),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            decoration: BoxDecoration(
              color: c['layer-frame'],
              border: Border(right: seam),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c['layer-sidebar'],
                border: Border(right: seam),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 4,
                children: [
                  bar(.75, ink.withValues(alpha: .3)),
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: c['brand-400'],
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: c['sticker-ink']!),
                    ),
                  ),
                  bar(.667, ink.withValues(alpha: .15)),
                  bar(.5, ink.withValues(alpha: .15)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  bar(.5, ink.withValues(alpha: .4)),
                  Row(
                    spacing: 6,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color:
                              c['palette-lavender-400'] ??
                              const Color(0xffbbafe6),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: c['sticker-ink']!),
                        ),
                      ),
                      Expanded(child: bar(1, ink.withValues(alpha: .15))),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c['layer-card'],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: c['line-strong']!),
                    ),
                    child: Row(
                      spacing: 6,
                      children: [
                        Expanded(child: bar(1, ink.withValues(alpha: .15))),
                        Container(
                          width: 24,
                          height: 12,
                          decoration: BoxDecoration(
                            color: c['attention-400'],
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: c['sticker-ink']!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
