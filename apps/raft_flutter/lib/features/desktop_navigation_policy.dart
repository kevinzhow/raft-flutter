import '../data/navigation_registry.dart';
import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_navigation.dart';
import 'task_content_slot.dart' show taskSlotId;

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
    'tasks' || 'artifacts' => DesktopNavigationPolicy._(
      section,
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
    'home' || 'chat' || 'saved' || 'drafts' => const DesktopNavigationPolicy._(
      'chat',
      DesktopSidebarKind.conversation,
    ),
    _ => _unregistered(section),
  };

  /// Which location-driven side panels (`?thread=`, `?profile=`) a route hosts
  /// beside its content. Every message timeline writes these queries (reply
  /// card, avatar, @mention); a host that does not render the panel turns the
  /// tap into a silent no-op, so the workspace derives its slots only from this
  /// table and `test/tap_target_matrix_test.dart` taps each container.
  ///
  /// Web `RightPanel`: chat routes host both; the Activity / Search content
  /// routes host the Thread panel in column 4 beside a channel / DM detail
  /// (a thread detail IS column 3 and never gets a second one) and the Profile
  /// panel beside any detail. The Tasks route hosts a profile beside its task.
  static ({bool thread, bool profile}) sidePanels({
    required String route,
    required bool wide,
    required RaftLocation location,
    DesktopContentKind? target,
  }) {
    final chat = route == 'chat' || route == 'home';
    final content = wide && (route == 'activity' || route == 'search');
    final threadIsDetail = wide && target == DesktopContentKind.thread;
    return (
      thread:
          location.thread != null &&
          !threadIsDetail &&
          (route == 'chat' || content && target != null),
      profile:
          location.profile != null &&
          (chat || content || wide && taskSlotId(location) != null),
    );
  }

  /// A section with no rail mode would silently show the Chat rail.
  static DesktopNavigationPolicy _unregistered(String section) {
    NavigationRegistry.reportFallback('desktop rail mode', section);
    return const DesktopNavigationPolicy._(
      'chat',
      DesktopSidebarKind.conversation,
    );
  }
}

/// Identifiers only. Private entity payloads remain owned by authorized loaders.
enum DesktopContentKind { channel, thread, agent, human, computer, task }

class DesktopContentTarget {
  const DesktopContentTarget(
    this.kind,
    this.id, {
    this.channelId,
    this.messageId,
    this.parentMessageId,
    this.dm = false,
  });
  final DesktopContentKind kind;
  final String id;
  final String? channelId, messageId, parentMessageId;
  final bool dm;
}

RaftLocation desktopContentLocation(
  RaftLocation current, {
  String? open,
  String? messageId,
  String? thread,
  bool clearProfile = false,
}) => current.withQuery({
  'open': open,
  'msg': messageId,
  'thread': thread,
  if (clearProfile) 'profile': null,
  if (open != current.query('open') && taskSlotId(current) != null)
    'task': null,
});

/// A compatibility projection of the same location used by the workspace.
/// Selected message data cannot independently change the master or rail.
class DesktopNavigationState {
  DesktopNavigationState({WorkspaceNavigation? navigation})
    : navigation = navigation ?? WorkspaceNavigation(),
      _standalone = navigation == null;
  final WorkspaceNavigation navigation;
  final bool _standalone;
  String? _scope;
  String? get masterRoute =>
      [
        'search',
        'activity',
        'members',
        'computers',
      ].contains(navigation.section)
      ? navigation.section
      : null;

  DesktopContentTarget? get target {
    final location = navigation.location;
    final entityKind = switch (location.route) {
      RaftRoute.agent => DesktopContentKind.agent,
      RaftRoute.human => DesktopContentKind.human,
      RaftRoute.computer => DesktopContentKind.computer,
      _ => null,
    };
    if (entityKind != null) {
      return DesktopContentTarget(entityKind, location.entityId!);
    }
    if (!{
      RaftRoute.search,
      RaftRoute.activity,
      RaftRoute.computers,
    }.contains(location.route)) {
      return null;
    }
    final content = location.content;
    if (content == null) return null;
    final kind = switch (content.kind) {
      RaftContentKind.channel ||
      RaftContentKind.dm => DesktopContentKind.channel,
      RaftContentKind.thread => DesktopContentKind.thread,
      RaftContentKind.agent => DesktopContentKind.agent,
      RaftContentKind.human => DesktopContentKind.human,
      RaftContentKind.machine => DesktopContentKind.computer,
      RaftContentKind.task => DesktopContentKind.task,
    };
    return DesktopContentTarget(
      kind,
      content.id,
      channelId: kind == DesktopContentKind.thread
          ? location.thread?.channelId
          : kind == DesktopContentKind.channel
          ? content.id
          : null,
      messageId: content.messageId,
      parentMessageId: location.thread?.itemId,
      dm: content.kind == RaftContentKind.dm,
    );
  }

  bool bind(String scope) {
    if (_scope == scope) return false;
    final hadScope = _scope != null;
    _scope = scope;
    if (_standalone) {
      navigation.bind(
        scope,
        RaftLocation.at(serverSlug: '_', route: RaftRoute.home),
      );
    } else if (hadScope) {
      // Scope loss retires the private detail without erasing a public master.
      closeTarget();
    }
    return true;
  }

  void selectRoute(String route) => navigation.selectSection(route);
  int beginSelection() => navigation.reserve();

  int selectTarget(
    DesktopContentTarget value, {
    RaftNavigationKind kind = RaftNavigationKind.replace,
  }) {
    final current = navigation.location;
    // An agent opened on the Computers page (a rack slot, the computer's
    // agent list) stays beside the rack: Web openProfile keeps /computers.
    final besideRack =
        navigation.section == 'computers' &&
        value.kind == DesktopContentKind.agent;
    if (besideRack) {
      navigation.navigate(
        RaftLocation.at(
          serverSlug: current.serverSlug,
          route: RaftRoute.computers,
        ).withQuery({'open': 'agent:${value.id}'}),
      );
    } else if (['members', 'computers'].contains(navigation.section)) {
      navigation.navigate(
        RaftLocation.at(
          serverSlug: current.serverSlug,
          route: switch (value.kind) {
            DesktopContentKind.agent => RaftRoute.agent,
            DesktopContentKind.human => RaftRoute.human,
            DesktopContentKind.computer => RaftRoute.computer,
            _ => RaftRoute.channel,
          },
          entityId: value.id,
        ),
      );
    } else {
      final prefix = switch (value.kind) {
        DesktopContentKind.channel when value.dm => 'dm',
        DesktopContentKind.computer => 'machine',
        _ => value.kind.name,
      };
      final next = desktopContentLocation(
        current,
        open: '$prefix:${value.id}',
        messageId: value.messageId,
        thread:
            value.kind == DesktopContentKind.thread &&
                value.channelId != null &&
                value.parentMessageId != null
            ? '${value.channelId}:${value.parentMessageId}'
            : null,
      );
      navigation.navigate(next, kind: kind);
    }
    return navigation.revision;
  }

  bool accepts(String scope, int revision) =>
      _scope == scope && revision == navigation.revision;
  void closeTarget() {
    if (navigation.location.route == RaftRoute.computer) {
      // The computer beside the rack closes back to the Computers page (Web
      // ProfilePanel `closeProfile` keeps /computers); its tab's home is
      // Settings, which would leave the page.
      navigation.navigate(
        RaftLocation.at(
          serverSlug: navigation.location.serverSlug,
          route: RaftRoute.computers,
        ),
        kind: RaftNavigationKind.replace,
      );
      return;
    }
    if ({
      RaftRoute.agent,
      RaftRoute.human,
      RaftRoute.computer,
    }.contains(navigation.location.route)) {
      navigation.navigate(
        navigation.location.tabHome(),
        kind: RaftNavigationKind.replace,
      );
    } else {
      navigation.navigate(
        desktopContentLocation(navigation.location, clearProfile: true),
        kind: RaftNavigationKind.replace,
      );
    }
  }

  void clear() => closeTarget();
  String visibleRoute(String section) => navigation.section;
}
