import 'package:flutter/material.dart';

import 'design_primitives.dart';
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
  });
  final RaftAppearance appearance;
  final ValueChanged<RaftAppearance> onChanged;
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
    );
  }
}
