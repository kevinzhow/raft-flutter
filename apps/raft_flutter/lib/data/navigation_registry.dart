import 'package:flutter/foundation.dart';

import 'raft_location.dart';

/// A section name the workspace accepts from `select(...)`, `setSection(...)`
/// and `selectSection(...)`, and where it must land.
@immutable
class NavigationSection {
  const NavigationSection(this.id, this.route, {this.settingsTab});
  final String id;

  /// The location route the section produces (`chat` produces a channel route
  /// when a conversation is open).
  final RaftRoute route;

  /// For sections that are settings sub-pages: the settings tab shown.
  final String? settingsTab;
}

/// One settings destination (`WorkspaceSettings`). [page] is false for rows
/// that run an action instead of showing a page.
@immutable
class NavigationSettingsTab {
  const NavigationSettingsTab(
    this.id, {
    this.phone = true,
    this.wide = true,
    this.page = true,
    this.reason,
  });
  final String id;
  final bool phone, wide, page;

  /// Why the tab is absent on a layout or has no page.
  final String? reason;
}

/// Every navigation target the app code names by literal. A new
/// `select('<literal>')`, `setSection('<literal>')`, `openHelpSettings(...)` or
/// `settingsPath: ['<literal>']` must be listed here (the navigation registry
/// test scans lib/ and fails otherwise), and the registry test then walks it
/// on a phone and a wide WorkspaceView.
///
/// Unknown targets fall back safely in release builds (Web falls back to
/// Account too) but fail loudly in debug and tests through [reportFallback].
abstract final class NavigationRegistry {
  static const sections = <NavigationSection>[
    NavigationSection('home', RaftRoute.home),
    NavigationSection('chat', RaftRoute.home),
    NavigationSection('agents', RaftRoute.members),
    NavigationSection('members', RaftRoute.members),
    NavigationSection('computers', RaftRoute.computers),
    NavigationSection('search', RaftRoute.search),
    NavigationSection('activity', RaftRoute.activity),
    NavigationSection('tasks', RaftRoute.tasks),
    NavigationSection('saved', RaftRoute.saved),
    NavigationSection('settings', RaftRoute.settings),
    NavigationSection(
      'workspace-settings',
      RaftRoute.settings,
      settingsTab: 'server',
    ),
    NavigationSection(
      'providers',
      RaftRoute.settings,
      settingsTab: 'providers',
    ),
    NavigationSection(
      'integrations',
      RaftRoute.settings,
      settingsTab: 'integrations',
    ),
    NavigationSection(
      'im-bridges',
      RaftRoute.settings,
      settingsTab: 'im-bridges',
    ),
    NavigationSection(
      'administration',
      RaftRoute.settings,
      settingsTab: 'administration',
    ),
    NavigationSection('billing', RaftRoute.settings, settingsTab: 'billing'),
  ];

  /// Section names that used to be accepted but have no page in the Flutter
  /// client (and none on Web). Selecting one is a bug, not a navigation.
  static const unsupportedSections = <String, String>{
    'joint-channels':
        'No Web counterpart and no phone page: Web opens '
        'CreateJointChannelDialog in place (use createJointChannel).',
    'sidebar-settings':
        'No Web counterpart: sidebar preferences live in the sidebar menus.',
  };

  /// Every id of a `WorkspaceSettings` destination, whatever flag, role or
  /// layout currently shows it. An id outside this list is a typo or a target
  /// that has no page.
  static const settingsTabs = <NavigationSettingsTab>[
    NavigationSettingsTab('account'),
    NavigationSettingsTab('language-region'),
    NavigationSettingsTab('appearance'),
    NavigationSettingsTab(
      'bottom-bar',
      wide: false,
      reason:
          'Phone-only device preference (no Web counterpart); hidden while '
          'the left rail replaces the bottom bar (wide foldable, landscape).',
    ),
    NavigationSettingsTab('notifications'),
    NavigationSettingsTab(
      'desktop',
      phone: false,
      wide: false,
      reason:
          'Linux AppImage only (raft:// link handler); absent everywhere '
          'else, no Web counterpart.',
    ),
    NavigationSettingsTab('server'),
    NavigationSettingsTab('raftbench'),
    NavigationSettingsTab('billing'),
    NavigationSettingsTab('administration'),
    NavigationSettingsTab('im-bridges'),
    NavigationSettingsTab('integrations'),
    NavigationSettingsTab('labs'),
    NavigationSettingsTab('mcp'),
    NavigationSettingsTab('providers'),
    NavigationSettingsTab(
      'computers',
      wide: false,
      page: false,
      reason:
          'Settings row that opens the Computers route (Web mobileInline '
          'only); desktop has the Computers rail.',
    ),
    NavigationSettingsTab('about'),
    NavigationSettingsTab(
      'network',
      reason:
          'Native-only (no Web counterpart): system / manual HTTP proxy. '
          'Web uses the browser network stack.',
    ),
    NavigationSettingsTab(
      'storage',
      reason:
          'Native-only (no Web counterpart): attachment cache size and '
          'Clear cache. Web leaves caching to the browser.',
    ),
    NavigationSettingsTab(
      'documentation',
      page: false,
      reason: 'Settings row that opens docs.raft.build externally.',
    ),
    NavigationSettingsTab('feedback'),
    NavigationSettingsTab('release-notes'),
  ];

  /// Literals the settings location is built from outside `select(...)`
  /// (`openHelpSettings`, invite dialog billing link, a failed media card's
  /// Network settings action).
  static const settingsPathLiterals = <String>{
    'about',
    'feedback',
    'billing',
    'network',
  };

  static NavigationSection? section(String id) =>
      sections.where((s) => s.id == id).firstOrNull;

  static bool knowsSection(String id) => section(id) != null;

  static bool knowsSettingsTab(String id) =>
      settingsTabs.any((tab) => tab.id == id);

  /// Throws in debug and test builds; a no-op in release, where the caller
  /// keeps its safe fallback.
  static void reportFallback(String kind, String target, [String? detail]) {
    if (!kDebugMode) return;
    throw FlutterError(
      'Navigation target "$target" ($kind) has no page and would silently '
      'fall back to a default page.'
      '${detail == null ? '' : ' $detail'}\n'
      'Register it in NavigationRegistry or fix the call site.',
    );
  }
}
