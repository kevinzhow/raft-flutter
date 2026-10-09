import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_navigation.dart';

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
    this.parentMessageId,
    this.dm = false,
  });
  final DesktopContentKind kind;
  final String id;
  final String? channelId, messageId, parentMessageId;
  final bool dm;
}

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
    if (!{RaftRoute.search, RaftRoute.activity}.contains(location.route)) {
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

  int selectTarget(DesktopContentTarget value) {
    final current = navigation.location;
    if (['members', 'computers'].contains(navigation.section)) {
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
      final next = current.withQuery({
        'open': '$prefix:${value.id}',
        'msg': value.messageId,
        'thread':
            value.kind == DesktopContentKind.thread &&
                value.channelId != null &&
                value.parentMessageId != null
            ? '${value.channelId}:${value.parentMessageId}'
            : null,
      });
      navigation.navigate(next, kind: RaftNavigationKind.replace);
    }
    return navigation.revision;
  }

  bool accepts(String scope, int revision) =>
      _scope == scope && revision == navigation.revision;
  void closeTarget() {
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
        navigation.location.withQuery({
          'open': null,
          'msg': null,
          'thread': null,
          'profile': null,
        }),
        kind: RaftNavigationKind.replace,
      );
    }
  }

  void clear() => closeTarget();
  String visibleRoute(String section) => navigation.section;
}
