import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'page_component_recipes.dart';

/// SettingsPanel/SettingsNavList composition. Account transport and platform
/// notification ownership are supplied by the caller, never by this UI shell.
class RaftSettingsDestination {
  const RaftSettingsDestination(
    this.id,
    this.label,
    this.glyph,
    this.builder, {
    this.group = 'Personal',
    this.scroll = true,
  });
  final String id, label, group;
  final RaftGlyph glyph;
  final WidgetBuilder builder;
  final bool scroll;
}

class RaftSettingsPage extends StatefulWidget {
  const RaftSettingsPage({
    super.key,
    required this.destinations,
    this.initialTab = 'account',
    this.onBack,
  });
  final List<RaftSettingsDestination> destinations;
  final String initialTab;
  final VoidCallback? onBack;
  @override
  State<RaftSettingsPage> createState() => _RaftSettingsPageState();
}

class _RaftSettingsPageState extends State<RaftSettingsPage> {
  late String selected = widget.initialTab;
  bool mobileNavigation = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), recipe = RaftSettingsLayoutRecipe(t);
    final available = widget.destinations;
    if (available.isEmpty) return const SizedBox.shrink();
    final active =
        available.where((d) => d.id == selected).firstOrNull ?? available.first;
    final mobile =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    Widget navigation() => Material(
      color: recipe.navigationFill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: RaftLayoutMetrics.shellHeaderHeight(
              t,
              MediaQuery.sizeOf(context).height,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  raftText(context, 'Settings'),
                  style: RaftTypography.heading(t),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: recipe.navigationLine),
          Expanded(
            child: ListView(
              primary: false,
              padding: RaftSettingsLayoutRecipe.navigationInset,
              children: [
                for (final group in available.map((d) => d.group).toSet())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                          child: Text(
                            raftText(context, group).toUpperCase(),
                            style: recipe.groupLabel,
                          ),
                        ),
                        for (final destination in available.where(
                          (d) => d.group == group,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: RaftNavItem(
                              key: ValueKey(
                                'workspace-settings-nav-${destination.id}',
                              ),
                              label: raftText(context, destination.label),
                              glyph: destination.glyph,
                              glyphSize:
                                  RaftSettingsLayoutRecipe.navigationGlyphSize,
                              selected: active.id == destination.id,
                              onTap: () => setState(() {
                                selected = destination.id;
                                mobileNavigation = false;
                              }),
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
    Widget content() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: recipe.headerHeight(MediaQuery.sizeOf(context).height),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: t.panel,
            border: Border(bottom: BorderSide(color: recipe.navigationLine)),
          ),
          child: Row(
            children: [
              if (mobile) ...[
                RaftIconButton(
                  glyph: RaftGlyph.arrowLeft,
                  tooltip: 'Settings navigation',
                  visualSize: 28,
                  onPressed: () => setState(() => mobileNavigation = true),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  raftText(context, active.label),
                  style: RaftTypography.heading(t),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: active.scroll
              ? ListView(
                  key: ValueKey('settings-page-${active.id}'),
                  primary: false,
                  padding: RaftSettingsLayoutRecipe.contentInset,
                  children: [
                    KeyedSubtree(
                      key: ValueKey(active.id),
                      child: active.builder(context),
                    ),
                  ],
                )
              : KeyedSubtree(
                  key: ValueKey(active.id),
                  child: active.builder(context),
                ),
        ),
      ],
    );
    if (mobile) return mobileNavigation ? navigation() : content();
    return Row(
      children: [
        SizedBox(
          width: RaftSettingsLayoutRecipe.navigationWidth,
          child: navigation(),
        ),
        VerticalDivider(width: 1, color: recipe.navigationLine),
        Expanded(child: content()),
      ],
    );
  }
}

/// Two independent appearance axes from AppearanceThemePicker.tsx. Theme cards
/// render the same illustrative composition inside their own semantic scope.
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
    final t = RaftTokens.of(context), recipe = RaftSettingsLayoutRecipe(t);
    final dark =
        appearance.mode == ThemeMode.dark ||
        appearance.mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    Widget themes(bool night) {
      final choices = night ? [RaftFamily.elegant] : RaftFamily.values;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                raftText(
                  context,
                  night ? 'Dark appearance' : 'Light appearance',
                ),
                style: recipe.sectionTitle,
              ),
              if (dark == night) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: t.colors['primary-soft'],
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    raftText(context, 'Current'),
                    style: recipe.currentLabel,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 640 ? 2 : 1;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(raftText(context, 'Mode').toUpperCase(), style: recipe.modeLabel),
        const SizedBox(height: 8),
        RaftSegmentedControl<ThemeMode>(
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
        const SizedBox(height: 8),
        Text(
          raftText(
            context,
            'System follows your device while keeping separate Light and Dark theme choices.',
          ),
          style: recipe.description,
        ),
        const SizedBox(height: 16),
        themes(false),
        const SizedBox(height: 16),
        themes(true),
      ],
    );
  }
}

class _ThemeChoice extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = raftTheme(family, dark: dark),
        t = theme.extension<RaftTokens>()!,
        recipe = RaftAppearanceCardRecipe(t, selected: selected);
    return Theme(
      data: theme,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${family.name} ${dark ? 'dark' : 'light'}',
        child: Material(
          key: ValueKey(
            'appearance-${dark ? 'dark' : 'light'}-theme-${family.name}',
          ),
          color: t.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
            side: recipe.border,
          ),
          child: InkWell(
            onTap: onSelected,
            borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
            child: Container(
              decoration: BoxDecoration(boxShadow: recipe.shadow),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      height: 64,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.canvas,
                        border: Border.all(
                          color: t.line,
                          width: t.brutal ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: t.panel,
                          border: Border.all(
                            color: t.line,
                            width: t.brutal ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(t.brutal ? 0 : 4),
                          boxShadow: t.shadows,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: FractionallySizedBox(
                                widthFactor: .6,
                                child: Container(
                                  height: 6,
                                  color: t.muted.withValues(alpha: .35),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 14,
                              left: 0,
                              right: 0,
                              height: 12,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    color: t.brutal
                                        ? t.colors['primary-400']
                                        : t.colors['primary-soft'],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      height: 6,
                                      color: t.colors['fill-muted'],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 28,
                                    height: 12,
                                    color: t.brutal
                                        ? t.colors['accent-400']
                                        : t.accentSoft,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          raftText(
                            context,
                            family == RaftFamily.brutal ? 'Brutal' : 'Elegant',
                          ),
                          style: RaftTypography.body(
                            t,
                            size: 14,
                            line: 20,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (selected)
                        RaftIcon(
                          RaftGlyph.check,
                          size: 14,
                          color: t.brutal ? t.colors['primary-500'] : t.accent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
