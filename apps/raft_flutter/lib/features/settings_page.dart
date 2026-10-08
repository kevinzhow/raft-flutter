import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'page_component_recipes.dart';

/// SettingsPanel / Sidebar(mobileInline) SettingsSidebarList composition.
/// Account transport and platform notification ownership are supplied by the
/// caller, never by this UI shell.
class RaftSettingsDestination {
  const RaftSettingsDestination(
    this.id,
    this.label,
    this.glyph,
    this.builder, {
    this.group = 'Personal',
    this.scroll = true,
    this.title,
    this.onOpen,
  }) : assert(builder != null || onOpen != null);

  /// A row that leaves the Settings page (external link or another route),
  /// like the Sidebar.tsx Documentation / Computers / Release Notes rows.
  const RaftSettingsDestination.action(
    this.id,
    this.label,
    this.glyph, {
    required VoidCallback this.onOpen,
    this.group = 'Personal',
  }) : builder = null,
       scroll = false,
       title = null;
  final String id, label, group;

  /// Panel title (SETTINGS_TAB_TITLE_ID) when it differs from the nav label.
  final String? title;
  final RaftGlyph glyph;
  final WidgetBuilder? builder;
  final VoidCallback? onOpen;
  final bool scroll;
}

class RaftSettingsPage extends StatefulWidget {
  const RaftSettingsPage({
    super.key,
    required this.destinations,
    this.initialTab = 'account',
    this.onBack,
    this.mobileRoot = false,
    this.mobileResetRevision = 0,
    this.onMobileDetailChanged,
  });
  final List<RaftSettingsDestination> destinations;
  final String initialTab;
  final VoidCallback? onBack;
  final bool mobileRoot;
  final int mobileResetRevision;
  final ValueChanged<bool>? onMobileDetailChanged;
  @override
  State<RaftSettingsPage> createState() => _RaftSettingsPageState();
}

class _RaftSettingsPageState extends State<RaftSettingsPage> {
  late String selected = widget.initialTab;
  late bool mobileNavigation = widget.mobileRoot;
  @override
  void didUpdateWidget(covariant RaftSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mobileResetRevision != widget.mobileResetRevision) {
      mobileNavigation = true;
    }
  }

  void showNavigation() {
    if (!mounted) return;
    setState(() => mobileNavigation = true);
    widget.onMobileDetailChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), recipe = RaftSettingsLayoutRecipe(t);
    final available = widget.destinations;
    final pages = available.where((d) => d.builder != null).toList();
    if (pages.isEmpty) return const SizedBox.shrink();
    final active =
        pages.where((d) => d.id == selected).firstOrNull ?? pages.first;
    final mobile =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    void open(RaftSettingsDestination destination) {
      if (destination.onOpen != null) {
        destination.onOpen!();
        return;
      }
      if (!mounted) return;
      setState(() {
        selected = destination.id;
        mobileNavigation = false;
      });
      if (mobile) widget.onMobileDetailChanged?.call(true);
    }

    final groups = [
      for (final group in available.map((d) => d.group).toSet())
        RaftSettingsNavGroup(group, [
          for (final d in available.where((d) => d.group == group))
            RaftSettingsNavEntry(
              id: d.id,
              label: d.label,
              glyph: d.glyph,
              onTap: () => open(d),
            ),
        ]),
    ];
    // Sidebar.tsx mobile root highlights nothing until a sub-page is open.
    Widget list(String? activeId) => ListView(
      primary: false,
      padding: RaftSettingsLayoutRecipe.navigationInset,
      children: [RaftSettingsSidebarList(groups: groups, activeId: activeId)],
    );
    Widget navigation() => mobile
        ? ColoredBox(
            // Sidebar mobileInline: `theme-brutal:bg-white`.
            color: t.brutal ? Colors.white : t.panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RaftMobileRootHeader(title: 'Settings'),
                Expanded(child: list(null)),
              ],
            ),
          )
        : Material(
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
                Expanded(child: list(active.id)),
              ],
            ),
          );
    Widget content() => RaftSettingsPanelFrame(
      header: RaftSettingsPanelHeader(
        title: active.title ?? active.label,
        glyph: active.glyph,
        mobile: mobile,
        backKey: const Key('mobile-settings-back'),
        backTooltip: 'Back',
        onMobileBack: showNavigation,
      ),
      child: active.scroll
          ? ListView(
              key: ValueKey('settings-page-${active.id}'),
              primary: false,
              padding: RaftSettingsPanelFrame.contentInset,
              children: [
                KeyedSubtree(
                  key: ValueKey(active.id),
                  child: active.builder!(context),
                ),
              ],
            )
          : KeyedSubtree(
              key: ValueKey(active.id),
              child: active.builder!(context),
            ),
    );
    if (mobile) return mobileNavigation ? navigation() : content();
    return Row(
      children: [
        SizedBox(
          width: RaftSettingsLayoutRecipe.navigationWidth,
          child: navigation(),
        ),
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
