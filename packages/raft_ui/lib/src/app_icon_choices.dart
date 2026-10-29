import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand.dart';
import 'design_primitives.dart';
import 'error_presentation.dart';
import 'icons.dart';
import 'localization.dart';
import 'settings_layout.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// Packaged brand palettes. The choice is independent of the page theme.
enum RaftAppIconPalette {
  yellow('Yellow'),
  blue('Blue'),
  green('Green'),
  white('White'),
  pink('Pink');

  const RaftAppIconPalette(this.label);
  final String label;
  Color get background => switch (this) {
    yellow => RaftTokenSet.light.product.brutalYellow,
    blue => RaftTokenSet.light.product.brutalCyan,
    green => RaftTokenSet.light.product.brutalLime,
    white => RaftTokenSet.light.product.codeSurface,
    pink => RaftTokenSet.light.product.brutalPink,
  };
}

/// Appearance card; platform support, OS readback and persistence belong to its caller.
class RaftAppIconChoices extends StatelessWidget {
  const RaftAppIconChoices({
    super.key,
    required this.selected,
    this.onChanged,
    this.busy = false,
    this.error,
  });
  final RaftAppIconPalette selected;
  final ValueChanged<RaftAppIconPalette>? onChanged;
  final bool busy;
  final String? error;

  Widget _icon(RaftAppIconPalette choice, double size, RaftSettingsText text) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: choice.background,
          borderRadius: BorderRadius.circular(size * .22),
          border: Border.all(color: text.softEdge),
        ),
        alignment: Alignment.center,
        child: RaftBrandMark(
          RaftBrandMarkKind.appIcon,
          height: size * .625 * 253 / 274,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    final label = selected == RaftAppIconPalette.yellow
        ? 'Yellow (default)'
        : selected.label;
    return RaftSettingsCard.box(
      t,
      padding: const EdgeInsets.all(RaftSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            raftText(context, 'Choose an icon for this device.'),
            style: RaftTypography.body(
              t,
              size: 14,
              line: 20,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: RaftSpace.x1),
          Text(
            raftText(context, 'Icon color is independent of the page theme.'),
            style: RaftTypography.body(
              t,
              size: 12,
              line: 16,
              color: text.muted,
            ),
          ),
          const SizedBox(height: RaftSpace.x4),
          Row(
            children: [
              _icon(selected, RaftSpace.x6 * 3, text),
              const SizedBox(width: RaftSpace.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      raftText(context, label),
                      style: RaftTypography.body(t, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: RaftSpace.x2),
                    Text(
                      raftText(context, 'Currently in use'),
                      style: RaftTypography.body(
                        t,
                        size: 12,
                        line: 16,
                        color: text.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RaftSpace.x4),
          LayoutBuilder(
            builder: (context, bounds) {
              final columns = bounds.maxWidth >= RaftSpace.x4 * 17 ? 5 : 3;
              final width =
                  (bounds.maxWidth - (columns - 1) * RaftSpace.x2) / columns;
              final iconSize = math.min(RaftSpace.x4 * 3, width - RaftSpace.x2);
              return Wrap(
                spacing: RaftSpace.x2,
                runSpacing: RaftSpace.x2,
                children: [
                  for (final choice in RaftAppIconPalette.values)
                    SizedBox(
                      width: width,
                      child: Semantics(
                        inMutuallyExclusiveGroup: true,
                        child: RaftInteractive(
                          key: ValueKey('app-icon-${choice.name}'),
                          selected: selected == choice,
                          button: false,
                          checked: selected == choice,
                          onPressed: busy || onChanged == null
                              ? null
                              : () => onChanged!(choice),
                          builder: (context, state) => Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: RaftSpace.x2,
                            ),
                            decoration: BoxDecoration(
                              color: selected == choice ? t.accentSoft : null,
                              borderRadius: BorderRadius.circular(t.radius),
                              border: Border.all(
                                color: state.focusVisible || selected == choice
                                    ? t.accent
                                    : Colors.transparent,
                                width: RaftSpace.half,
                              ),
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _icon(choice, iconSize, text),
                                    if (selected == choice)
                                      Positioned(
                                        top: -RaftSpace.x1,
                                        right: -RaftSpace.x1,
                                        child: Container(
                                          padding: const EdgeInsets.all(
                                            RaftSpace.half,
                                          ),
                                          decoration: BoxDecoration(
                                            color: text.strong,
                                            shape: BoxShape.circle,
                                          ),
                                          child: RaftIcon(
                                            RaftGlyph.check,
                                            size: RaftSpace.x3,
                                            color: t.panel,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: RaftSpace.x2),
                                Text(
                                  raftText(context, choice.label),
                                  style: RaftTypography.body(
                                    t,
                                    size: 12,
                                    line: 16,
                                    color: text.strong,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: RaftSpace.x4),
          if (error != null)
            // Native only (no Web counterpart): the failure is the warning
            // Banner every settings panel uses, density sm.
            RaftErrorBanner(error!, small: true, bold: true)
          else
            Semantics(
              liveRegion: busy,
              child: Text(
                raftText(
                  context,
                  busy
                      ? 'Changing icon…'
                      : 'Saved on this device. Tap a color to apply.',
                ),
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  color: text.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
