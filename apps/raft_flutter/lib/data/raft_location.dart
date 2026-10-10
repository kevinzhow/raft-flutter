import 'raft_navigation_history.dart';

/// The mounted workspace URL contract in raft-source 26f77ef.
/// This value owns location identity; entity payloads and loading are separate.
enum RaftRoute {
  home,
  channel,
  dm,
  agent,
  computer,
  human,
  members,
  memberGraph,
  computers,
  search,
  settings,
  activity,
  tasks,
  saved,
  releaseNotes,
  unknown,
}

enum RaftMobileTab { chat, tasks, members, settings }

enum RaftContentKind { channel, dm, thread, agent, human, machine }

enum RaftProfileKind { agent, human, external }

/// Source splits anchors at the first colon and rejects either empty side.
class RaftAnchor {
  const RaftAnchor(this.channelId, this.itemId);
  final String channelId, itemId;
  static RaftAnchor? parse(String? value) {
    if (value == null) return null;
    final split = value.indexOf(':');
    if (split <= 0 || split == value.length - 1) return null;
    return RaftAnchor(value.substring(0, split), value.substring(split + 1));
  }

  @override
  String toString() => '$channelId:$itemId';
}

class RaftContentLocation {
  const RaftContentLocation(this.kind, this.id, {this.messageId});
  final RaftContentKind kind;
  final String id;
  final String? messageId;
  static RaftContentLocation? parse(String? value, {String? messageId}) {
    if (value == null) return null;
    final split = value.indexOf(':');
    if (split <= 0 || split == value.length - 1) return null;
    final kinds = RaftContentKind.values.where(
      (kind) => kind.name == value.substring(0, split),
    );
    if (kinds.isEmpty) return null;
    final kind = kinds.first;
    return RaftContentLocation(
      kind,
      value.substring(split + 1),
      messageId:
          {
            RaftContentKind.channel,
            RaftContentKind.dm,
            RaftContentKind.thread,
          }.contains(kind)
          ? messageId
          : null,
    );
  }

  @override
  String toString() => '${kind.name}:$id';
}

class RaftProfileLocation {
  const RaftProfileLocation(this.kind, this.id, {this.channelId});
  final RaftProfileKind kind;
  final String id;
  final String? channelId;
  static RaftProfileLocation? parse(String? value) {
    if (value == null) return null;
    final split = value.indexOf(':');
    if (split <= 0 || split == value.length - 1) return null;
    final prefix = value.substring(0, split), id = value.substring(split + 1);
    if (prefix == 'agent' || prefix == 'human') {
      return RaftProfileLocation(
        prefix == 'agent' ? RaftProfileKind.agent : RaftProfileKind.human,
        id,
      );
    }
    if (prefix != 'external') return null;
    final parts = id.split(':');
    if (parts.length != 2 || parts.any((part) => part.isEmpty)) return null;
    return RaftProfileLocation(
      RaftProfileKind.external,
      parts[1],
      channelId: parts[0],
    );
  }

  @override
  String toString() => kind == RaftProfileKind.external
      ? 'external:$channelId:$id'
      : '${kind.name}:$id';
}

class RaftLocation {
  RaftLocation._(
    this.uri,
    this.serverSlug,
    this.route,
    this.entityId,
    this.settingsPath,
  );

  /// A local workspace path. Hosts validate the origin before parsing it.
  factory RaftLocation.parse(String path) =>
      RaftLocation.fromUri(Uri.parse(path));

  /// useRailLegacyRedirect.ts:29–64. Folds the older rail-mode shapes
  /// (`/machine/:id`, `?sidebarTab=`, `?tab=machines|messages`) into the canonical
  /// path; every other query key and the fragment are preserved.
  static Uri canonicalLegacy(Uri uri) {
    final sidebarTab = uri.queryParametersAll['sidebarTab']?.first;
    final legacyTab = uri.queryParametersAll['tab']?.first;
    final dropTab = legacyTab == 'machines' || legacyTab == 'messages';
    var path = uri.path, changed = sidebarTab != null || dropTab;
    final machine = RegExp(r'^(/s/[^/]+)/machine/([^/?#]+)$').firstMatch(path);
    if (machine != null) {
      path = '${machine[1]}/computer/${machine[2]}';
      changed = true;
    }
    final root = RegExp(r'^(/s/[^/]+)/?$').firstMatch(path);
    final mode = root == null
        ? null
        : sidebarTab == 'members'
        ? 'members'
        : sidebarTab == 'computers' || legacyTab == 'machines'
        ? 'computers'
        : null;
    if (mode != null) path = '${root![1]}/$mode';
    if (!changed) return uri;
    final query = {
      for (final entry in uri.queryParametersAll.entries)
        if (entry.key != 'sidebarTab' && !(dropTab && entry.key == 'tab'))
          entry.key: entry.value,
    };
    return Uri(
      path: path,
      queryParameters: query.isEmpty ? null : query,
      fragment: uri.hasFragment ? uri.fragment : null,
    );
  }

  factory RaftLocation.fromUri(Uri uri) {
    if (uri.hasScheme || uri.hasAuthority || !uri.path.startsWith('/')) {
      throw const FormatException('Expected a local workspace path');
    }
    final parts = uri.pathSegments.toList();
    if (parts.length < 2 || parts[0] != 's' || parts[1].isEmpty) {
      throw const FormatException('Expected /s/<serverSlug>');
    }
    final rest = parts.skip(2).where((part) => part.isNotEmpty).toList();
    final kind = rest.isEmpty ? '' : rest.first;
    final entity = rest.length == 2 ? rest[1] : null;
    final route = switch (kind) {
      '' => RaftRoute.home,
      'channel' when entity != null => RaftRoute.channel,
      'dm' when entity != null => RaftRoute.dm,
      'agent' when entity != null => RaftRoute.agent,
      'computer' || 'machine' when entity != null => RaftRoute.computer,
      'human' when entity != null => RaftRoute.human,
      'members' when rest.length == 1 => RaftRoute.members,
      'members' when rest.length == 2 && rest[1] == 'graph' =>
        RaftRoute.memberGraph,
      'computers' when rest.length == 1 => RaftRoute.computers,
      'search' when rest.length == 1 => RaftRoute.search,
      'settings' => RaftRoute.settings,
      'activity' when rest.length == 1 => RaftRoute.activity,
      'inbox' when rest.length == 1 => RaftRoute.activity,
      'threads' when rest.length == 1 => RaftRoute.activity,
      'tasks' when rest.length == 1 => RaftRoute.tasks,
      'saved' when rest.length == 1 => RaftRoute.saved,
      'release-notes' when rest.length == 1 => RaftRoute.releaseNotes,
      _ => RaftRoute.unknown,
    };
    return RaftLocation._(
      uri,
      parts[1],
      route,
      {
            RaftRoute.channel,
            RaftRoute.dm,
            RaftRoute.agent,
            RaftRoute.computer,
            RaftRoute.human,
          }.contains(route)
          ? entity
          : null,
      List.unmodifiable(
        route == RaftRoute.settings ? rest.skip(1) : <String>[],
      ),
    );
  }

  factory RaftLocation.at({
    required String serverSlug,
    required RaftRoute route,
    String? entityId,
    List<String> settingsPath = const [],
    Map<String, String> query = const {},
    String? fragment,
  }) {
    if (serverSlug.isEmpty) throw ArgumentError.value(serverSlug, 'serverSlug');
    final suffix = switch (route) {
      RaftRoute.home => <String>[],
      RaftRoute.channel ||
      RaftRoute.dm ||
      RaftRoute.agent ||
      RaftRoute.computer ||
      RaftRoute.human =>
        entityId == null || entityId.isEmpty
            ? throw ArgumentError('Entity routes require an ID')
            : [route.name, entityId],
      RaftRoute.memberGraph => ['members', 'graph'],
      RaftRoute.settings => ['settings', ...settingsPath],
      RaftRoute.releaseNotes => ['release-notes'],
      RaftRoute.unknown => throw ArgumentError(
        'Unknown routes require parsing',
      ),
      _ => [route.name],
    };
    return RaftLocation.fromUri(
      Uri(
        pathSegments: ['', 's', serverSlug, ...suffix],
        queryParameters: query.isEmpty ? null : query,
        fragment: fragment,
      ),
    );
  }

  final Uri uri;
  final String serverSlug;
  final RaftRoute route;
  final String? entityId;
  final List<String> settingsPath;

  String? query(String key) => uri.queryParametersAll[key]?.first;
  String? get messageId => query('msg');
  RaftContentLocation? get content =>
      RaftContentLocation.parse(query('open'), messageId: messageId);
  RaftAnchor? get thread => RaftAnchor.parse(query('thread'));
  String? get threadFocusedMessageId =>
      thread != null && messageId != thread!.itemId ? messageId : null;
  String? get knownThreadChannelId =>
      content?.kind == RaftContentKind.thread ? content!.id : null;
  RaftAnchor? get task =>
      query('task') == '1' ? thread : RaftAnchor.parse(query('task'));
  RaftAnchor? get legacyTask => RaftAnchor.parse(query('legacyTask'));
  RaftProfileLocation? get profile =>
      RaftProfileLocation.parse(query('profile'));
  String? get agentTab => query('agentTab');
  String? get chatTab => {'chat', 'tasks', 'files'}.contains(query('chatTab'))
      ? query('chatTab')
      : null;
  bool get searchDeferred => query('defer') == '1';
  bool get hasOverlay =>
      thread != null || profile != null || task != null || legacyTask != null;

  RaftMobileTab get mobileTab => switch (route) {
    RaftRoute.tasks => RaftMobileTab.tasks,
    RaftRoute.agent ||
    RaftRoute.human ||
    RaftRoute.members ||
    RaftRoute.memberGraph => RaftMobileTab.members,
    RaftRoute.computer ||
    RaftRoute.computers ||
    RaftRoute.settings ||
    RaftRoute.releaseNotes => RaftMobileTab.settings,
    _ => RaftMobileTab.chat,
  };

  RaftLocation tabHome([RaftMobileTab? tab]) => RaftLocation.at(
    serverSlug: serverSlug,
    route: switch (tab ?? mobileTab) {
      RaftMobileTab.chat => RaftRoute.home,
      RaftMobileTab.tasks => RaftRoute.tasks,
      RaftMobileTab.members => RaftRoute.members,
      RaftMobileTab.settings => RaftRoute.settings,
    },
  );

  /// Change named parameters without dropping other URL state or the fragment.
  RaftLocation withQuery(Map<String, String?> changes) {
    final next = <String, List<String>>{
      for (final entry in uri.queryParametersAll.entries)
        entry.key: List.of(entry.value),
    };
    for (final entry in changes.entries) {
      if (entry.value == null) {
        next.remove(entry.key);
      } else {
        next[entry.key] = [entry.value!];
      }
    }
    return RaftLocation.fromUri(
      uri.replace(query: next.isEmpty ? '' : Uri(queryParameters: next).query),
    );
  }

  /// mobileNavStore cold hydration strips exactly these two overlay slots.
  RaftLocation withoutMobileOverlays() =>
      withQuery({'thread': null, 'profile': null});

  /// rightPanelUrlSync.ts:477–542. Adding an overlay pushes; retargeting or
  /// removing one replaces. A task modal owns its own slot alongside a thread.
  RaftNavigationKind panelNavigationKindTo(
    RaftLocation next, {
    bool replaceMode = false,
  }) {
    final removed =
        (next.thread == null && query('thread') != null) ||
        (next.profile == null && query('profile') != null) ||
        (next.legacyTask == null && query('legacyTask') != null);
    final added =
        (next.thread != null && query('thread') == null) ||
        (next.profile != null && query('profile') == null) ||
        (next.task != null && query('task') == null) ||
        (next.legacyTask != null && query('legacyTask') == null);
    return !replaceMode && added && !removed
        ? RaftNavigationKind.push
        : RaftNavigationKind.replace;
  }

  @override
  String toString() => uri.toString();
  @override
  bool operator ==(Object other) => other is RaftLocation && other.uri == uri;
  @override
  int get hashCode => uri.hashCode;
}
