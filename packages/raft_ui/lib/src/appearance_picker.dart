import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'theme.dart';

/// AppearanceThemePicker.tsx (preferences branch): mode segmented control
/// and the Light / Dark theme radio groups. Each theme card renders inside its
/// own theme scope (`data-theme={option.family}` + mode class).
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
    final dark =
        appearance.mode == ThemeMode.dark ||
        appearance.mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    // `text-sm font-bold text-foreground-strong`
    final groupTitle = RaftTypography.body(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w700,
    );
    Widget themes(bool night) {
      final choices = night ? [RaftFamily.elegant] : RaftFamily.values;
      return Column(
        key: Key('appearance-theme-group-${night ? 'dark' : 'light'}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                raftText(
                  context,
                  night ? 'Dark appearance' : 'Light appearance',
                ),
                style: groupTitle,
              ),
              if (dark == night) ...[
                const SizedBox(width: 8),
                // `rounded-full bg-primary-soft px-2 py-0.5 text-[10px]
                // font-bold text-primary-strong`
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: t.colors['primary-soft'],
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    raftText(context, 'Current'),
                    style: RaftTypography.body(
                      t,
                      size: 10,
                      line: 15,
                      weight: FontWeight.w700,
                      color: t.colors['primary-strong'],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // `grid gap-2 sm:grid-cols-2`
          LayoutBuilder(
            builder: (context, c) {
              final columns = MediaQuery.sizeOf(context).width >= 640 ? 2 : 1;
              final cardWidth = (c.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final family in choices)
                    SizedBox(
                      width: cardWidth,
                      child: _ThemeChoice(
                        family: family,
                        dark: night,
                        selected: night || appearance.light == family,
                        onSelected: () => onChanged(
                          appearance.copyWith(light: night ? null : family),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );
    }

    // `text-xs font-bold uppercase tracking-widest text-foreground-muted`
    final eyebrow = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w700,
      color: t.muted,
    ).copyWith(letterSpacing: 1.2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(raftText(context, 'Color mode').toUpperCase(), style: eyebrow),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: RaftSegmentedControl<ThemeMode>(
            key: const Key('appearance-mode'),
            style: RaftSegmentedStyle.tabs,
            value: appearance.mode,
            label: 'Appearance mode',
            visualHeight: 32,
            items: [
              for (final mode in [
                ThemeMode.light,
                ThemeMode.dark,
                ThemeMode.system,
              ])
                RaftSegmentedOption(
                  value: mode,
                  label: raftText(context, switch (mode) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    _ => 'System',
                  }),
                ),
            ],
            onChanged: (mode) => onChanged(appearance.copyWith(mode: mode)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          raftText(
            context,
            'System follows your device while keeping separate Light and Dark theme choices.',
          ),
          style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
        ),
        const SizedBox(height: 16),
        themes(false),
        const SizedBox(height: 16),
        themes(true),
      ],
    );
  }
}

class _ThemeChoice extends StatefulWidget {
  const _ThemeChoice({
    required this.family,
    required this.dark,
    required this.selected,
    required this.onSelected,
  });
  final RaftFamily family;
  final bool dark, selected;
  final VoidCallback onSelected;
  @override
  State<_ThemeChoice> createState() => _ThemeChoiceState();
}

class _ThemeChoiceState extends State<_ThemeChoice> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final host = RaftTokens.of(context);
    final family = widget.family, selected = widget.selected;
    final theme = raftTheme(family, dark: widget.dark),
        t = theme.extension<RaftTokens>()!;
    final brutal = family == RaftFamily.brutal;
    // Card class: brutal `border-2 bg-layer-panel` + selected
    // `border-line-strong shadow-raft-md` / `border-line-muted shadow-none`;
    // elegant `rounded-lg border-[0.5px] bg-layer-panel shadow-none` +
    // selected `border-accent-strong theme-brutal:border-soft-signal`.
    final cardBorder = brutal
        ? Border.all(
            color: t.colors[selected ? 'line-strong' : 'line-muted']!,
            width: 2,
          )
        : Border.all(
            color: selected
                ? (host.brutal
                      ? host.colors['color-soft-signal']!
                      : t.colors['accent-strong']!)
                : t.colors['line-muted']!,
            width: .5,
          );
    final previewLine = brutal ? 2.0 : 1.0;
    return Theme(
      data: theme,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${family.name} ${widget.dark ? 'dark' : 'light'}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            key: ValueKey(
              'appearance-${widget.dark ? 'dark' : 'light'}-theme-${family.name}',
            ),
            onTap: widget.onSelected,
            child: Transform.translate(
              // `group-hover:-translate-y-px`
              offset: Offset(0, hovered ? -1 : 0),
              child: Container(
                decoration: BoxDecoration(
                  color: t.panel,
                  border: cardBorder,
                  borderRadius: brutal ? null : BorderRadius.circular(8),
                  boxShadow: brutal && selected
                      ? t.themeShadows.md.outer
                      : null,
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        height: 64,
                        padding: const EdgeInsets.all(8),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: t.canvas,
                          border: Border.all(
                            color: t
                                .colors[brutal ? 'line-strong' : 'line-muted']!,
                            width: previewLine,
                          ),
                          borderRadius: brutal
                              ? null
                              : BorderRadius.circular(6),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: t.panel,
                            border: Border.all(
                              color: brutal
                                  ? Colors.black
                                  : t.colors['line-muted']!,
                              width: previewLine,
                            ),
                            borderRadius: brutal
                                ? null
                                : BorderRadius.circular(4),
                            // brutal `shadow-brutal-xs` is not a defined
                            // utility; elegant `shadow-raft-xs`.
                            boxShadow: brutal ? null : t.themeShadows.xs.outer,
                          ),
                          // The rows overflow the h-full panel; the h-16
                          // preview's `overflow-hidden` clips them.
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            maxHeight: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FractionallySizedBox(
                                  widthFactor: .6,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: t.muted.withValues(
                                        alpha: t.muted.a * .35,
                                      ),
                                      borderRadius: brutal
                                          ? null
                                          : BorderRadius.circular(9999),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color:
                                            t.colors[brutal
                                                ? 'primary-400'
                                                : 'primary-soft'],
                                        borderRadius: brutal
                                            ? null
                                            : BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: t.colors['fill-muted'],
                                          borderRadius: brutal
                                              ? null
                                              : BorderRadius.circular(9999),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 28,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: brutal
                                            ? t.colors['accent-400']
                                            : t.accentSoft,
                                        borderRadius: brutal
                                            ? null
                                            : BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            raftText(context, brutal ? 'Brutal' : 'Elegant'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RaftTypography.body(
                              t,
                              size: 14,
                              line: 20,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          RaftIcon(
                            RaftGlyph.check,
                            size: 14,
                            color:
                                t.colors[brutal
                                    ? 'primary-500'
                                    : 'accent-strong'],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
