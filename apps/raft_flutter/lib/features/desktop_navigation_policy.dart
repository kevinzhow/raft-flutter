/// Classic mounted MainLayout/useSidebarTab projection. Workspace-grid is a
/// separate feature/preference branch; this policy never enables it implicitly.
enum DesktopSidebarKind {
  conversation,
  members,
  computers,
  settings,
  searchMaster,
  activityMaster,
  hidden,
}

class DesktopNavigationPolicy {
  const DesktopNavigationPolicy._(this.railMode, this.sidebarKind);
  final String railMode;
  final DesktopSidebarKind sidebarKind;
  bool get usesConversationSidebar =>
      sidebarKind == DesktopSidebarKind.conversation;
  bool get contentMasterDetail =>
      sidebarKind == DesktopSidebarKind.searchMaster ||
      sidebarKind == DesktopSidebarKind.activityMaster;

  factory DesktopNavigationPolicy.forSection(
    String section,
  ) => switch (section) {
    'tasks' => const DesktopNavigationPolicy._(
      'tasks',
      DesktopSidebarKind.hidden,
    ),
    'search' => const DesktopNavigationPolicy._(
      'search',
      DesktopSidebarKind.searchMaster,
    ),
    'activity' => const DesktopNavigationPolicy._(
      'activity',
      DesktopSidebarKind.activityMaster,
    ),
    'agents' || 'members' => const DesktopNavigationPolicy._(
      'members',
      DesktopSidebarKind.members,
    ),
    'computers' => const DesktopNavigationPolicy._(
      'computers',
      DesktopSidebarKind.computers,
    ),
    'settings' => const DesktopNavigationPolicy._(
      'settings',
      DesktopSidebarKind.settings,
    ),
    // Saved belongs to the regular Chat rail; it is not a classic rail mode.
    _ => const DesktopNavigationPolicy._(
      'chat',
      DesktopSidebarKind.conversation,
    ),
  };
}

/// Identifiers only. Private entity payloads remain owned by authorized loaders.
enum DesktopContentKind { channel, thread, agent, human, computer }

class DesktopContentTarget {
  const DesktopContentTarget(
    this.kind,
    this.id, {
    this.channelId,
    this.messageId,
  });
  final DesktopContentKind kind;
  final String id;
  final String? channelId, messageId;
}

/// Independent content route state. A selected channel may be visible/readable
/// in col3 while the rail and retained col2 still belong to Search or Activity.
class DesktopNavigationState {
  String? _scope;
  String? masterRoute;
  DesktopContentTarget? target;
  int _revision = 0;
  bool bind(String scope) {
    if (_scope == scope) return false;
    _scope = scope;
    masterRoute = null;
    target = null;
    ++_revision;
    return true;
  }

  void selectRoute(String route) {
    masterRoute =
        ['search', 'activity', 'members', 'computers', 'agents'].contains(route)
        ? route
        : null;
    target = null;
    ++_revision;
  }

  /// Reserve an asynchronous selection without mounting a failure-only profile.
  int beginSelection() => ++_revision;

  int selectTarget(DesktopContentTarget value) {
    target = value;
    return ++_revision;
  }

  bool accepts(String scope, int revision) =>
      _scope == scope && revision == _revision;
  void closeTarget() {
    target = null;
    ++_revision;
  }

  void clear() {
    masterRoute = null;
    target = null;
    ++_revision;
  }

  String visibleRoute(String section) => masterRoute ?? section;
}
