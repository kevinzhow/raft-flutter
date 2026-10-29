import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'mobile_navigation.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'raft/switch.dart';
import 'system_inset.dart';
import 'theme.dart';

/// One configurable bottom-bar tab (everything except the fixed Settings tab).
@immutable
class RaftMobileTabOption {
  const RaftMobileTabOption({
    required this.id,
    required this.label,
    required this.glyph,
  });
  final String id, label;
  final RaftGlyph glyph;
}

/// Pure state of the mobile bottom-bar configuration: the order of every
/// configurable tab and which of them are on. Settings is not part of it; it is
/// always shown and always last. The caller owns persistence.
@immutable
class RaftMobileTabbarConfig {
  const RaftMobileTabbarConfig({
    required this.order,
    required this.enabled,
    this.maxTabs = defaultMaxTabs,
  });

  /// Most tabs the bar holds, Settings included. Five fit 360dp with the
  /// Brutal bar's equal-width cells (72dp each, "Computers" needs ~58dp) and is
  /// the platform tab-bar convention.
  static const defaultMaxTabs = 5;

  final List<String> order;
  final Set<String> enabled;
  final int maxTabs;

  /// Tabs on in the bar, Settings included.
  int get total => enabled.length + 1;
  bool get atLimit => total >= maxTabs;
  bool get atMinimum => enabled.length <= 1;
  List<String> get visible => [
    for (final id in order)
      if (enabled.contains(id)) id,
  ];

  bool canToggle(String id) => enabled.contains(id) ? !atMinimum : !atLimit;

  RaftMobileTabbarConfig toggled(String id) {
    if (!canToggle(id)) return this;
    final next = {...enabled};
    if (!next.remove(id)) next.add(id);
    return RaftMobileTabbarConfig(
      order: order,
      enabled: next,
      maxTabs: maxTabs,
    );
  }

  RaftMobileTabbarConfig reordered(int oldIndex, int newIndex) {
    final next = [...order];
    next.insert(newIndex, next.removeAt(oldIndex));
    return RaftMobileTabbarConfig(
      order: next,
      enabled: enabled,
      maxTabs: maxTabs,
    );
  }
}

/// "Bottom bar" settings page body: the configurable tab list (switch +
/// reorder handle per row, Settings locked last) above a pinned live preview of
/// the resulting [RaftMobileNav]. The settings row pattern is the Labs card
/// (RaftServerLabsSection): title + switch rows divided by `divide-black/10`.
class RaftMobileTabbarConfigView extends StatelessWidget {
  const RaftMobileTabbarConfigView({
    super.key,
    required this.tabs,
    required this.settingsTab,
    required this.config,
    required this.onChanged,
    this.onReset,
    this.viewportHeight,
  });
  final List<RaftMobileTabOption> tabs;
  final RaftMobileTabOption settingsTab;
  final RaftMobileTabbarConfig config;
  final ValueChanged<RaftMobileTabbarConfig> onChanged;

  /// Null hides "Reset to default" (the bar already is the default).
  final VoidCallback? onReset;
  final double? viewportHeight;

  RaftMobileTabOption _tab(String id) => tabs.firstWhere((t) => t.id == id);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    final divider = Colors.black.withValues(alpha: .1);
    final ordered = [for (final id in config.order) _tab(id)];
    final warn = t.colors['warning-strong'];

    Widget row(int index, RaftMobileTabOption tab) {
      final on = config.enabled.contains(tab.id);
      final editable = config.canToggle(tab.id);
      return Container(
        key: ValueKey('mobile-tabbar-row-${tab.id}'),
        decoration: BoxDecoration(
          border: index == 0
              ? null
              : Border(top: BorderSide(color: divider, width: 2)),
        ),
        child: Opacity(
          opacity: editable ? 1 : .6,
          child: Row(
            children: [
              // Same handle as the server switcher menu (24x48, 14px grip).
              ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  button: true,
                  label: raftFormat(context, 'Reorder {name}', {
                    'name': raftText(context, tab.label),
                  }),
                  child: SizedBox(
                    width: 24,
                    height: 48,
                    child: Center(
                      child: RaftIcon(
                        RaftGlyph.gripVertical,
                        size: 14,
                        color: text.faint,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RaftIcon(
                tab.glyph,
                size: 18,
                color: on ? text.strong : text.faint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  raftText(context, tab.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.title,
                ),
              ),
              const SizedBox(width: 16),
              RaftSwitch(
                key: ValueKey('mobile-tabbar-switch-${tab.id}'),
                value: on,
                size: RaftSwitchSize.md,
                enabled: editable,
                semanticLabel: raftText(context, tab.label),
                onChanged: (_) => onChanged(config.toggled(tab.id)),
              ),
            ],
          ),
        ),
      );
    }

    final notice = config.atLimit && !config.atMinimum
        ? 'Limit reached. Turn one off to add another.'
        : config.atMinimum
        ? 'Keep at least one tab besides Settings.'
        : null;
    final nav = RaftMobileNav(
      selectedId: config.visible.firstOrNull ?? settingsTab.id,
      // Only floating capsules need shadow clearance. The dock owns the
      // actual system inset; an in-flow preview matches the real bar height.
      bottomInset:
          t.option('mobileNav.style', or: 'docked') == 'floatingCapsule'
          ? 16
          : 0,
      viewportHeight: viewportHeight,
      onSelected: (_) {},
      items: [
        for (final id in config.visible)
          RaftMobileNavItem(
            id: id,
            label: _tab(id).label,
            glyph: _tab(id).glyph,
          ),
        RaftMobileNavItem(
          id: settingsTab.id,
          label: settingsTab.label,
          glyph: settingsTab.glyph,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            primary: false,
            padding: RaftSettingsPanelFrame.contentInset,
            children: [
              Text(
                raftText(
                  context,
                  'Choose which tabs appear in the bottom bar and in what order. Settings is always shown, at the end.',
                ),
                style: text.description,
              ),
              const SizedBox(height: 16),
              RaftSettingsSectionHeader(
                label: 'Tabs',
                glyph: RaftGlyph.smartphone,
                action: Text(
                  '${config.total} / ${config.maxTabs}',
                  style: RaftTypography.mono(
                    t,
                    size: 12,
                    line: 16,
                    color: t.colors['foreground-placeholder'],
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
              ),
              RaftSettingsCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReorderableListView.builder(
                      key: const Key('mobile-tabbar-list'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      buildDefaultDragHandles: false,
                      itemCount: ordered.length,
                      onReorderItem: (o, n) =>
                          onChanged(config.reordered(o, n)),
                      proxyDecorator: (child, _, _) =>
                          Opacity(opacity: .6, child: child),
                      itemBuilder: (_, i) => row(i, ordered[i]),
                    ),
                    Container(
                      key: const ValueKey('mobile-tabbar-row-settings'),
                      constraints: const BoxConstraints(minHeight: 48),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: divider, width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 32),
                          RaftIcon(
                            settingsTab.glyph,
                            size: 18,
                            color: text.strong,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  raftText(context, settingsTab.label),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.title,
                                ),
                                Text(
                                  raftText(context, 'Always shown'),
                                  style: text.description,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 44,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: RaftIcon(
                                RaftGlyph.lock,
                                size: 16,
                                color: text.faint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                raftFormat(context, 'Up to {count} tabs, including Settings.', {
                  'count': config.maxTabs,
                }),
                style: text.description,
              ),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    raftText(context, notice),
                    key: const Key('mobile-tabbar-notice'),
                    style: text.description.copyWith(
                      fontWeight: FontWeight.w700,
                      color: warn,
                    ),
                  ),
                ),
              if (onReset != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RaftSettingsRecipeButton(
                    label: 'Reset to Default',
                    glyph: RaftGlyph.rotateCcw,
                    onPressed: onReset,
                  ),
                ),
              ],
            ],
          ),
        ),
        _PreviewDock(nav: nav),
      ],
    );
  }
}

/// Pinned where the real bar sits: edge to edge, so cell widths (and label
/// truncation) are exactly what the user will get at this screen width.
class _PreviewDock extends StatelessWidget {
  const _PreviewDock({required this.nav});
  final Widget nav;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(top: BorderSide(color: t.colors['line-muted']!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: RaftSettingsSectionHeader(label: 'Preview', bottom: 4),
          ),
          // Keep the preview header on the panel, while extending the bar's
          // own surface through the system inset. Transparent legacy bars
          // retain the panel backdrop.
          RaftBottomInsetSurface(
            color: Color.alphaBlend(
              t.colors['layer-mobile-nav-system']!,
              t.panel,
            ),
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: KeyedSubtree(
                  key: const Key('mobile-tabbar-preview'),
                  child: nav,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
