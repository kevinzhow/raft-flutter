import 'navigation_registry.dart';
import 'phone_stack.dart';
import 'raft_location.dart';
import 'raft_navigation_history.dart';

/// What [WorkspaceNavigation.translateForLayout] rewrote.
class LayoutTranslation {
  const LayoutTranslation(this.from, this.to);
  final RaftLocation from, to;
}

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
  int _taskRevision = 0;

  /// First history entry made under the live phone layout; see
  /// [phoneReturnSource].
  int _phoneFloor = 0;
  int get phoneFloor => _phoneFloor;
  RaftLocation get location => _location;
  int get revision => _revision;
  int get taskRevision => _taskRevision;
  List<RaftLocation> get entries => List.unmodifiable(_entries);
  int get index => _index;

  /// A route reads its own location while sharing the accepted history owner.
  /// Updating presentation never creates a navigation intent.
  void projectHistory(WorkspaceNavigation source, RaftLocation location) {
    _authority = source._authority;
    _location = location;
    _entries
      ..clear()
      ..addAll(source._entries);
    _index = source.location.uri == location.uri
        ? source.index
        : _entries
              .take(source.index + 1)
              .toList()
              .lastIndexWhere((entry) => entry.uri == location.uri);
    _revision = source._revision;
    _taskRevision = source._taskRevision;
    _phoneFloor = source._phoneFloor;
  }

  /// A new principal/server epoch cannot inherit another epoch's history.
  bool bind(String authority, RaftLocation initial) {
    if (_authority == authority) return false;
    _authority = authority;
    _location = initial;
    _entries
      ..clear()
      ..add(initial);
    _index = 0;
    _phoneFloor = 0;
    ++_revision;
    ++_taskRevision;
    return true;
  }

  int reserve() => ++_revision;

  static bool taskOnlyTransition(RaftLocation from, RaftLocation to) =>
      from.uri != to.uri &&
      from.withQuery({'task': null, 'legacyTask': null}).uri ==
          to.withQuery({'task': null, 'legacyTask': null}).uri;

  /// The profile side panel owns its own slot (`profile=` and its agent tab):
  /// opening, retargeting or closing it never retires an independently
  /// pending window.
  static bool profileOnlyTransition(RaftLocation from, RaftLocation to) =>
      from.uri != to.uri &&
      from.withQuery(_profileQuery).uri == to.withQuery(_profileQuery).uri;

  static const _profileQuery = <String, String?>{
    'profile': null,
    'agentTab': null,
  };

  /// Navigate the profile slot without bumping the window revision.
  void navigateProfile(
    RaftLocation next, {
    RaftNavigationKind kind = RaftNavigationKind.push,
  }) {
    final keep = profileOnlyTransition(location, next);
    final before = _revision;
    navigate(next, kind: kind);
    if (keep) _revision = before;
  }

  /// Source rightPanelUrlSync331–389/475–535: task slots own history without
  /// retiring an independently pending main window or ordinary side thread.
  void navigateTask(
    RaftLocation next, {
    RaftNavigationKind kind = RaftNavigationKind.push,
  }) {
    final previous = location;
    if (!taskOnlyTransition(previous, next)) {
      navigate(next, kind: kind);
      return;
    }
    final before = _revision;
    navigate(next, kind: kind);
    _revision = before;
  }

  void navigate(
    RaftLocation next, {
    RaftNavigationKind kind = RaftNavigationKind.push,
  }) {
    final previous = _location;
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
    if (previous.query('task') != next.query('task') ||
        previous.query('legacyTask') != next.query('legacyTask') ||
        (next.query('task') == '1' &&
            previous.query('thread') != next.query('thread'))) {
      ++_taskRevision;
    }
  }

  /// Replace Source Search's committed q without changing its content intent.
  /// Typing preserves pending content metadata, open slots and the same history
  /// entry (MessageSearchPage1069–1078); actual Back/retarget still retires them.
  bool replaceSearchQuery(String committed) {
    if (location.route != RaftRoute.search) return false;
    final value = committed.trim();
    final next = location.withQuery({'q': value.isEmpty ? null : value});
    if (next.uri == location.uri) return false;
    _location = next;
    if (_index >= 0) _entries[_index] = next;
    return true;
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

  /// Translate the accepted location across the layout breakpoint. The
  /// location is the only navigation state; identities that exist in one
  /// layout only are rewritten to their equivalent in the other, so Back and
  /// the visible page stay coherent without a second history. Returns null
  /// when nothing needed translating. A layout projection keeps the same
  /// conversation visit: its already loaded thread and pending replies must
  /// remain current. Location and task revision still reconcile the page stack;
  /// actual navigation continues to retire the message-request revision.
  ///
  /// * phone: a master/detail content slot (`activity|search ?open=`) becomes
  ///   the conversation page above its list (the list is the Back entry).
  /// * wide: `channelPage=` is dropped (the caller opens the matching dialog);
  ///   if the page was pushed in this session its history entry is removed.
  LayoutTranslation? translateForLayout({required bool compact}) {
    final from = _location;
    if (_index < 0) return null;
    if (compact) {
      if (!hasContentSlot(from)) return null;
      final to = locationForPhone(from);
      if (to.uri == from.uri) return null;
      _entries[_index] = contentList(from);
      _entries.removeRange(_index + 1, _entries.length);
      _entries.add(to);
      _index = _entries.length - 1;
      _location = to;
      ++_taskRevision;
      return LayoutTranslation(from, to);
    }
    if (!hasPhoneOnlyIdentity(from)) return null;
    final to = locationForWide(from);
    if (_index > 0 && _entries[_index - 1].uri == to.uri) {
      _entries.removeRange(_index, _entries.length);
      _index--;
    } else {
      _entries[_index] = to;
    }
    _location = _entries[_index];
    ++_taskRevision;
    return LayoutTranslation(from, to);
  }

  /// The layout just changed: whatever history exists was made by the other
  /// layout. A phone only treats entries made from here on as its own journey
  /// ([translated] keeps the list a content slot was opened from).
  void markLayoutCrossing({bool translated = false}) {
    _phoneFloor = translated && _index > 0 ? _index - 1 : _index;
  }

  /// Panel close replaces its entry, so a session of opening and closing side
  /// panels leaves runs of identical entries behind. They carry no
  /// destination of their own; drop them around the current entry.
  bool collapseRepeatedEntries() {
    var changed = false;
    for (var at = _entries.length - 1; at > 0; at--) {
      if (_entries[at].uri != _entries[at - 1].uri) continue;
      _entries.removeAt(at);
      if (_index >= at) _index--;
      changed = true;
    }
    return changed;
  }

  /// Cold details have no observed predecessor. Close their URL-owned slot or
  /// replace with the route's semantic tab root instead of leaving the server.
  RaftLocation back() {
    if (_index > 0 &&
        canUseRaftHistoryBack(
          _entries[_index - 1].toString(),
          location.toString(),
        )) {
      final previous = _location;
      _location = _entries[--_index];
      if (!taskOnlyTransition(previous, _location) &&
          !profileOnlyTransition(previous, _location)) {
        ++_revision;
      }
      ++_taskRevision;
    } else {
      // A task modal, profile and thread own independent slots. Closing one
      // must not erase the others (rightPanelUrlSyncContract 385–511).
      final fallback = location.channelPage != null
          ? location.withQuery({'channelPage': null})
          : location.task != null
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
          : mobileTabHome(location);
      if (location.task != null || location.legacyTask != null) {
        navigateTask(fallback, kind: RaftNavigationKind.replace);
      } else {
        navigate(fallback, kind: RaftNavigationKind.replace);
      }
    }
    return location;
  }

  bool forward() {
    if (_index + 1 >= _entries.length) return false;
    final previous = _location;
    _location = _entries[++_index];
    if (!taskOnlyTransition(previous, _location) &&
        !profileOnlyTransition(previous, _location)) {
      ++_revision;
    }
    ++_taskRevision;
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
  }) {
    if (!NavigationRegistry.knowsSection(section)) {
      NavigationRegistry.reportFallback(
        'section',
        section,
        NavigationRegistry.unsupportedSections[section],
      );
      section = 'settings';
    }
    return _locationForSection(slug, section, channelId: channelId, dm: dm);
  }

  static RaftLocation _locationForSection(
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
    'server-labs' => 'labs',
    _ => slug,
  };

  static const settingsSections = {
    'workspace-settings',
    'providers',
    'integrations',
    'im-bridges',
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

  /// Tabs the mobile bottom bar shows besides the always-root Home, Tasks,
  /// Members and Settings. A location of a tab listed here is a tab root;
  /// otherwise Computers is a Settings sub-page and Activity a pushed page.
  Set<String> mobileTabs = const {};

  String? get mobileRootTab => mobileRootTabOf(location);

  /// The semantic root a cold detail returns to: its own tab root when the
  /// bar has one for it, otherwise the route's usual tab.
  RaftLocation mobileTabHome(RaftLocation location) =>
      tabHomeOf(location, mobileTabs);

  static RaftLocation tabHomeOf(RaftLocation location, Set<String> tabs) {
    final tab = switch (location.route) {
      RaftRoute.computers || RaftRoute.computer => 'computers',
      RaftRoute.activity => 'activity',
      _ => null,
    };
    return tab == null || !tabs.contains(tab)
        ? location.tabHome()
        : RaftLocation.at(
            serverSlug: location.serverSlug,
            route: tab == 'computers'
                ? RaftRoute.computers
                : RaftRoute.activity,
          );
  }

  String? mobileRootTabOf(RaftLocation location) =>
      rootTabOf(location, mobileTabs);

  static String? rootTabOf(RaftLocation location, Set<String> tabs) {
    if (location.hasOverlay ||
        {RaftRoute.search, RaftRoute.activity}.contains(location.route) &&
            location.content != null) {
      return null;
    }
    return switch (location.route) {
      RaftRoute.home => 'chat',
      RaftRoute.tasks => 'tasks',
      RaftRoute.members => 'members',
      RaftRoute.computers when tabs.contains('computers') => 'computers',
      RaftRoute.activity when tabs.contains('activity') => 'activity',
      RaftRoute.settings when location.settingsPath.isEmpty => 'settings',
      _ => null,
    };
  }
}
