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
