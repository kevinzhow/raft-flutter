import 'raft_location.dart';
import 'raft_navigation_history.dart';

/// One accepted location for the workspace presentation. Message windows,
/// drafts and authorized entity records remain independent data projections.
class WorkspaceNavigation {
  WorkspaceNavigation({RaftLocation? initial})
    : _location =
          initial ?? RaftLocation.at(serverSlug: '_', route: RaftRoute.home);

  RaftLocation _location;
  String? _authority;
  final List<RaftLocation> _entries = [];
  int _index = -1;
  int _revision = 0;
  RaftLocation get location => _location;
  int get revision => _revision;
  List<RaftLocation> get entries => List.unmodifiable(_entries);
  int get index => _index;

  /// A new principal/server epoch cannot inherit another epoch's history.
  bool bind(String authority, RaftLocation initial) {
    if (_authority == authority) return false;
    _authority = authority;
    _location = initial;
    _entries
      ..clear()
      ..add(initial);
    _index = 0;
    ++_revision;
    return true;
  }

  int reserve() => ++_revision;

  void navigate(
    RaftLocation next, {
    RaftNavigationKind kind = RaftNavigationKind.push,
  }) {
    if (next.uri.hasQuery && next.uri.query.isEmpty) {
      next = RaftLocation.parse(next.toString().replaceFirst('?', ''));
    }
    if (next.serverSlug != location.serverSlug) {
      throw ArgumentError('Workspace navigation must stay in the bound server');
    }
    if (kind == RaftNavigationKind.pop) {
      throw ArgumentError('Use back/forward for observed history');
    }
    if (kind == RaftNavigationKind.replace && _index >= 0) {
      _entries[_index] = next;
    } else {
      if (_index + 1 < _entries.length) {
        _entries.removeRange(_index + 1, _entries.length);
      }
      _entries.add(next);
      _index = _entries.length - 1;
    }
    _location = next;
    ++_revision;
  }

  /// Consume only the mounted Activity thread slot's URI focus.
  /// Source MainLayout899–910 supplies Activity's consumption callback, while
  /// Search756–784 and canonical side threads clear only the visual highlight.
  /// Replacing Activity `msg` is not a new navigation intent: independently held
  /// metadata retains its revision, while Back/new-route still retires requests.
  bool consumeThreadFocus({
    required String threadChannelId,
    required String parentChannelId,
    required String parentMessageId,
    required String expectedMessageId,
    required int expectedRevision,
  }) {
    final content = location.content;
    final thread = location.thread;
    if (expectedRevision != revision ||
        expectedMessageId.isEmpty ||
        location.route != RaftRoute.activity ||
        content?.kind != RaftContentKind.thread ||
        content?.id != threadChannelId ||
        thread?.channelId != parentChannelId ||
        thread?.itemId != parentMessageId ||
        location.messageId != expectedMessageId) {
      return false;
    }
    final next = location.withQuery({'msg': null});
    _location = next;
    if (_index >= 0) _entries[_index] = next;
    return true;
  }

  /// Cold details have no observed predecessor. Close their URL-owned slot or
  /// replace with the route's semantic tab root instead of leaving the server.
  RaftLocation back() {
    if (_index > 0 &&
        canUseRaftHistoryBack(
          _entries[_index - 1].toString(),
          location.toString(),
        )) {
      _location = _entries[--_index];
      ++_revision;
    } else {
      // A task modal, profile and thread own independent slots. Closing one
      // must not erase the others (rightPanelUrlSyncContract 385–511).
      final fallback = location.task != null
          ? location.withQuery({'task': null})
          : location.legacyTask != null
          ? location.withQuery({'legacyTask': null})
          : location.profile != null
          ? location.withQuery({'profile': null})
          : location.content != null
          ? location.withQuery({
              'open': null,
              'msg': null,
              if (location.content!.kind == RaftContentKind.thread)
                'thread': null,
            })
          : location.thread != null
          ? location.withQuery({'thread': null})
          : location.tabHome();
      navigate(fallback, kind: RaftNavigationKind.replace);
    }
    return location;
  }

  bool forward() {
    if (_index + 1 >= _entries.length) return false;
    _location = _entries[++_index];
    ++_revision;
    return true;
  }

  void selectSection(
    String section, {
    String? channelId,
    bool dm = false,
    RaftNavigationKind kind = RaftNavigationKind.push,
  }) {
    navigate(
      locationForSection(
        location.serverSlug,
        section,
        channelId: channelId,
        dm: dm,
      ),
      kind: kind,
    );
  }

  static RaftLocation locationForSection(
    String slug,
    String section, {
    String? channelId,
    bool dm = false,
  }) => RaftLocation.at(
    serverSlug: slug,
    route: switch (section) {
      'chat' when channelId != null => dm ? RaftRoute.dm : RaftRoute.channel,
      'home' || 'chat' => RaftRoute.home,
      'agents' || 'members' => RaftRoute.members,
      'computers' => RaftRoute.computers,
      'search' => RaftRoute.search,
      'activity' => RaftRoute.activity,
      'tasks' => RaftRoute.tasks,
      'saved' => RaftRoute.saved,
      _ => RaftRoute.settings,
    },
    entityId: section == 'chat' ? channelId : null,
    settingsPath: section == 'settings' || !settingsSections.contains(section)
        ? const []
        : [settingsRouteSlug(section)],
  );

  /// Mounted settingsNavigation.ts aliases; path identity is canonical.
  static String settingsRouteSlug(String tab) => switch (tab) {
    'workspace-settings' => 'server',
    'integrations' => 'applications',
    'mcp' => 'mcp-servers',
    _ => tab,
  };
  static String settingsTab(String slug) => switch (slug) {
    'applications' => 'integrations',
    'mcp-servers' => 'mcp',
    'browser' => 'notifications',
    'moderation' => 'administration',
    _ => slug,
  };

  static const settingsSections = {
    'workspace-settings',
    'sidebar-settings',
    'providers',
    'integrations',
    'im-bridges',
    'joint-channels',
    'administration',
    'billing',
  };
  static String sectionFor(RaftLocation value) => switch (value.route) {
    RaftRoute.channel || RaftRoute.dm => 'chat',
    RaftRoute.agent ||
    RaftRoute.human ||
    RaftRoute.memberGraph ||
    RaftRoute.members => 'members',
    RaftRoute.computer || RaftRoute.computers => 'computers',
    RaftRoute.settings =>
      value.settingsPath.isEmpty ||
              !settingsSections.contains(value.settingsPath.first)
          ? 'settings'
          : value.settingsPath.first,
    RaftRoute.home => 'home',
    RaftRoute.releaseNotes => 'settings',
    RaftRoute.unknown => 'home',
    _ => value.route.name,
  };

  String get section => sectionFor(location);
  String? get mobileRootTab {
    if (location.hasOverlay ||
        {RaftRoute.search, RaftRoute.activity}.contains(location.route) &&
            location.content != null) {
      return null;
    }
    return switch (location.route) {
      RaftRoute.home => 'chat',
      RaftRoute.tasks => 'tasks',
      RaftRoute.members => 'members',
      RaftRoute.settings when location.settingsPath.isEmpty => 'settings',
      _ => null,
    };
  }
}
