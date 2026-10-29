import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/icons.dart';
import 'src/mobile_navigation.dart';
import 'src/mobile_tabbar_config.dart';
import 'src/settings_layout.dart';
import 'src/theme.dart';

/// Design preview of the mobile "Bottom bar" setting (not wired into the app):
/// the Settings root with the new entry, the configuration page in its three
/// limit states, and the five-item bar at 360dp.

const _tabs = [
  RaftMobileTabOption(id: 'chat', label: 'Home', glyph: RaftGlyph.home),
  RaftMobileTabOption(
    id: 'tasks',
    label: 'Tasks',
    glyph: RaftGlyph.checkSquare,
  ),
  RaftMobileTabOption(id: 'members', label: 'Members', glyph: RaftGlyph.users),
  RaftMobileTabOption(
    id: 'computers',
    label: 'Computers',
    glyph: RaftGlyph.monitor,
  ),
  RaftMobileTabOption(
    id: 'activity',
    label: 'Activity',
    glyph: RaftGlyph.activity,
  ),
];
const _settings = RaftMobileTabOption(
  id: 'settings',
  label: 'Settings',
  glyph: RaftGlyph.settings,
);

/// Today's bar: Home, Tasks, Members + Settings.
const _defaultConfig = RaftMobileTabbarConfig(
  order: ['chat', 'tasks', 'members', 'computers', 'activity'],
  enabled: {'chat', 'tasks', 'members'},
);

/// Home, Tasks, Activity, Computers + Settings: the limit (5) is reached.
const _fullConfig = RaftMobileTabbarConfig(
  order: ['chat', 'tasks', 'activity', 'computers', 'members'],
  enabled: {'chat', 'tasks', 'activity', 'computers'},
);

/// Only Home + Settings: the last non-Settings tab cannot be turned off.
const _minimumConfig = RaftMobileTabbarConfig(
  order: ['chat', 'tasks', 'members', 'computers', 'activity'],
  enabled: {'chat'},
);

@RaftPreviews(
  'Mobile settings root with Bottom bar entry',
  size: Size(390, 844),
)
Widget mobileSettingsRootBottomBarPreview() =>
    const MobileSettingsRootPreview(bottomBarEntry: true);

@RaftPreviews('Mobile settings root (current)', size: Size(390, 844))
Widget mobileSettingsRootCurrentPreview() =>
    const MobileSettingsRootPreview(bottomBarEntry: false);

@RaftPreviews('Mobile Bottom bar settings (default)', size: Size(390, 844))
Widget mobileTabbarConfigDefaultPreview() =>
    const MobileTabbarConfigPagePreview(initial: _defaultConfig);

@RaftPreviews(
  'Mobile Bottom bar settings (gesture inset)',
  size: Size(390, 844),
)
Widget mobileTabbarConfigGesturePreview() => _insetPreview(24);

@RaftPreviews(
  'Mobile Bottom bar settings (3-button inset)',
  size: Size(390, 844),
)
Widget mobileTabbarConfigButtonsPreview() => _insetPreview(48);

Widget _insetPreview(double bottom) => Builder(
  builder: (context) {
    final metrics = MediaQuery.of(context);
    return MediaQuery(
      data: metrics.copyWith(
        padding: metrics.padding.copyWith(bottom: bottom),
        viewPadding: metrics.viewPadding.copyWith(bottom: bottom),
      ),
      child: mobileTabbarConfigDefaultPreview(),
    );
  },
);

@RaftPreviews(
  'Mobile Bottom bar settings (limit reached)',
  size: Size(390, 844),
)
Widget mobileTabbarConfigFullPreview() =>
    const MobileTabbarConfigPagePreview(initial: _fullConfig);

@RaftPreviews('Mobile Bottom bar settings (minimum)', size: Size(390, 844))
Widget mobileTabbarConfigMinimumPreview() =>
    const MobileTabbarConfigPagePreview(initial: _minimumConfig);

@RaftPreviews('Mobile bottom bar, 5 items at 360dp', size: Size(360, 120))
Widget mobileTabbarFiveItemsPreview() => const Align(
  alignment: Alignment.bottomCenter,
  child: MobileTabbarFiveItems(),
);

/// Home, Tasks, Activity, Computers, Settings: the widest bar the setting
/// allows.
class MobileTabbarFiveItems extends StatelessWidget {
  const MobileTabbarFiveItems({super.key});
  @override
  Widget build(BuildContext context) => RaftMobileNav(
    selectedId: 'chat',
    bottomInset: 0,
    // A phone-height viewport: Brutal drops glyphs below 600dp.
    viewportHeight: 844,
    onSelected: (_) {},
    items: [
      for (final id in const ['chat', 'tasks', 'activity', 'computers'])
        RaftMobileNavItem(
          id: id,
          // ignore: raft_lints/avoid_render_where_without_or_else -- Preview-only widget with a fixed tab list and ids taken from it.
          label: _tabs.firstWhere((t) => t.id == id).label,
          // ignore: raft_lints/avoid_render_where_without_or_else -- Preview-only widget with a fixed tab list and ids taken from it.
          glyph: _tabs.firstWhere((t) => t.id == id).glyph,
        ),
      RaftMobileNavItem(
        id: _settings.id,
        label: _settings.label,
        glyph: _settings.glyph,
      ),
    ],
  );
}

/// The mobile Settings root (settings_page.dart `mobile` navigation): root
/// header, grouped rows, and the tab bar with Settings selected. The new
/// "Bottom bar" row sits in Personal after Appearance: it customises how the
/// app looks and behaves for this device, next to Language & Region and
/// Appearance, and before Notifications.
class MobileSettingsRootPreview extends StatelessWidget {
  const MobileSettingsRootPreview({super.key, required this.bottomBarEntry});
  final bool bottomBarEntry;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    RaftSettingsNavEntry e(String id, String label, RaftGlyph glyph) =>
        RaftSettingsNavEntry(id: id, label: label, glyph: glyph, onTap: () {});
    return ColoredBox(
      color: RaftSettingsText(t).panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftMobileRootHeader(title: 'Settings'),
          Expanded(
            child: ListView(
              primary: false,
              padding: RaftSettingsSidebarList.inset(t),
              children: [
                RaftSettingsSidebarList(
                  groups: [
                    RaftSettingsNavGroup('Personal', [
                      e('account', 'Account', RaftGlyph.user),
                      e(
                        'language-region',
                        'Language & Region',
                        RaftGlyph.languages,
                      ),
                      e('appearance', 'Appearance', RaftGlyph.type),
                      if (bottomBarEntry)
                        e('bottom-bar', 'Bottom bar', RaftGlyph.smartphone),
                      e('notifications', 'Notifications', RaftGlyph.bell),
                    ]),
                    RaftSettingsNavGroup('Workspace', [
                      e('server', 'Server Profile', RaftGlyph.building2),
                      e('billing', 'Plan & Billing', RaftGlyph.creditCard),
                      e('administration', 'Administration', RaftGlyph.shield),
                      e('integrations', 'Applications', RaftGlyph.link2),
                      e('mcp', 'MCP Servers', RaftGlyph.blocks),
                      e('providers', 'Providers', RaftGlyph.keyRound),
                      e('computers', 'Computers', RaftGlyph.monitor),
                    ]),
                    RaftSettingsNavGroup('Resources', [
                      e('about', 'About', RaftGlyph.badgeInfo),
                      e(
                        'documentation',
                        'Documentation',
                        RaftGlyph.bookOpenText,
                      ),
                      e('feedback', 'Feedback', RaftGlyph.messageSquare),
                      e('release-notes', 'Release Notes', RaftGlyph.fileText),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          RaftMobileNav(
            selectedId: 'settings',
            bottomInset: 0,
            onSelected: (_) {},
            items: const [
              RaftMobileNavItem(
                id: 'chat',
                label: 'Home',
                glyph: RaftGlyph.home,
              ),
              RaftMobileNavItem(
                id: 'tasks',
                label: 'Tasks',
                glyph: RaftGlyph.checkSquare,
              ),
              RaftMobileNavItem(
                id: 'members',
                label: 'Members',
                glyph: RaftGlyph.users,
              ),
              RaftMobileNavItem(
                id: 'settings',
                label: 'Settings',
                glyph: RaftGlyph.settings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The Bottom bar detail page as the Settings panel frames it on mobile
/// (back header + content surface). Interactive: toggles, reorder, reset.
class MobileTabbarConfigPagePreview extends StatefulWidget {
  const MobileTabbarConfigPagePreview({super.key, required this.initial});
  final RaftMobileTabbarConfig initial;
  @override
  State<MobileTabbarConfigPagePreview> createState() =>
      _MobileTabbarConfigPagePreviewState();
}

class _MobileTabbarConfigPagePreviewState
    extends State<MobileTabbarConfigPagePreview> {
  late RaftMobileTabbarConfig config = widget.initial;
  @override
  Widget build(BuildContext context) {
    final isDefault =
        config.order.join() == _defaultConfig.order.join() &&
        config.enabled.length == _defaultConfig.enabled.length &&
        config.enabled.containsAll(_defaultConfig.enabled);
    return RaftSettingsPanelFrame(
      header: RaftSettingsPanelHeader(
        title: 'Bottom bar',
        glyph: RaftGlyph.smartphone,
        onMobileBack: () {},
      ),
      child: RaftMobileTabbarConfigView(
        tabs: _tabs,
        settingsTab: _settings,
        config: config,
        onChanged: (next) => setState(() => config = next),
        onReset: isDefault
            ? null
            : () => setState(() => config = _defaultConfig),
      ),
    );
  }
}
