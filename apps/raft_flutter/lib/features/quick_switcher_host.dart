import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';

import '../data/raft_location.dart';
import '../data/recent_conversations.dart';
import '../data/search_memory.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'private_route_guard.dart';
import 'quick_switcher.dart';
import 'quick_switcher_model.dart';
import 'resource_search.dart';
import 'search_home.dart';

/// Navigation the switcher asks of the workspace; each one mirrors what a
/// click on the same destination does elsewhere in the app.
class QuickSwitcherActions {
  const QuickSwitcherActions({
    required this.openConversation,
    required this.openDirectory,
    required this.openThread,
    required this.openMessage,
    required this.searchAll,
  });

  /// Sidebar-style entry into a known channel or DM.
  final Future<void> Function(RaftChannel channel) openConversation;

  /// Profile / computer detail (also the fallback when a DM cannot be made).
  final void Function(RaftRoute route, String id) openDirectory;
  final Future<void> Function({
    required String parentChannelId,
    required String parentMessageId,
    required String messageId,
    required String threadChannelId,
  })
  openThread;
  final Future<void> Function(String channelId, String? messageId) openMessage;

  /// The full Search page with the typed query.
  final void Function(String query) searchAll;
}

/// Owns everything the Cmd/Ctrl+K switcher needs between openings: the visit
/// history, the shared search memory, the memoized destination catalog and the
/// dialog route. Data comes from caches the workspace already holds, so the
/// switcher paints its results in the first frame and never waits for a
/// request. Recent visits are recorded as conversations open.
class QuickSwitcherHost {
  QuickSwitcherHost({
    required WorkspaceController controller,
    required this.actions,
    RecentConversationStore? recents,
    SearchMemoryStore? searchMemory,
    this.clock,
  }) : w = controller,
       recents = recents ?? RecentConversationStore(),
       searchMemory = searchMemory ?? SearchMemoryStore(clock: clock) {
    w.addListener(changed);
    changed();
  }

  WorkspaceController w;
  final QuickSwitcherActions actions;
  final RecentConversationStore recents;
  final SearchMemoryStore searchMemory;
  final DateTime Function()? clock;
  RawDialogRoute<void>? route;
  String? openedAuthority, lastVisit, lastVisitScope;
  bool _disposed = false;

  void rebind(WorkspaceController controller) {
    if (identical(controller, w)) return;
    close();
    w.removeListener(changed);
    w = controller;
    lastVisit = lastVisitScope = null;
    _catalog = null;
    w.addListener(changed);
    changed();
  }

  void dispose() {
    _disposed = true;
    close();
    w.removeListener(changed);
    recents.dispose();
  }

  RecentConversationScope? get recentScope {
    final server = w.server?.id, principal = w.client.user?.id;
    return server == null || principal == null
        ? null
        : RecentConversationScope(w.client.origin, server, principal);
  }

  SearchMemoryScope? get memoryScope {
    final server = w.server?.id, principal = w.client.user?.id;
    return server == null || principal == null
        ? null
        : SearchMemoryScope(w.client.origin, server, principal);
  }

  void changed() {
    if (_disposed) return;
    if (route != null && openedAuthority != directoryAuthority(w)) close();
    recordVisit();
  }

  /// Source useRecordRecentConversation: a conversation counts once it has
  /// resolved against the channel and DM lists, never a bogus id.
  void recordVisit() {
    final channel = w.section == 'chat' ? w.channel : null;
    final scope = recentScope;
    if (channel == null || scope == null || channel.type == 'thread') return;
    if (lastVisit == channel.id && lastVisitScope == scope.key) return;
    if (![...w.channels, ...w.dms].any((c) => c.id == channel.id)) return;
    lastVisit = channel.id;
    lastVisitScope = scope.key;
    recents.recordVisit(scope, channel.id);
  }

  // Identity of every input of the catalog; a notification that changed none
  // of them (a new message, an unread count) reuses the catalog and its
  // ranked results.
  QuickSwitcherCatalog? _catalog;
  Object? _channels, _dms, _agents, _members, _hidden;
  int _computerRevision = -1;
  bool _machines = false;
  String? _principal;
  List<Map<String, dynamic>> _computers = const [];

  QuickSwitcherData data() {
    final directory = w.entityDirectory;
    final principal = w.client.user?.id;
    final machines = w.can('viewMachines');
    if (machines) directory.ensure(const [WorkspaceEntityKind.computers]);
    final agents = directory.authorAgents, members = directory.authorMembers;
    final hidden = w.sidebarOrder['hiddenDmIds'];
    final computerRevision = machines ? directory.computerRevision : -1;
    if (_catalog == null ||
        !identical(_channels, w.channels) ||
        !identical(_dms, w.dms) ||
        !identical(_agents, agents) ||
        !identical(_members, members) ||
        !identical(_hidden, hidden) ||
        _computerRevision != computerRevision ||
        _machines != machines ||
        _principal != principal) {
      if (_computerRevision != computerRevision || _machines != machines) {
        _computers = machines
            ? directory.rows(WorkspaceEntityKind.computers)
            : const [];
      }
      _channels = w.channels;
      _dms = w.dms;
      _agents = agents;
      _members = members;
      _hidden = hidden;
      _computerRevision = computerRevision;
      _machines = machines;
      _principal = principal;
      _catalog = QuickSwitcherCatalog(
        channels: [for (final c in w.channels) c.json],
        dms: [for (final c in w.dms) c.json],
        computers: _computers,
        agents: agents,
        people: members,
        principal: principal,
        hiddenDmIds: hidden is List ? hidden.whereType<String>().toSet() : {},
      );
    }
    return QuickSwitcherData(
      catalog: _catalog!,
      visited: recents.idsFor(recentScope),
      excludeChannelId: w.section == 'chat' ? w.channel?.id : null,
      agents: agents,
      members: members,
      currentUser: w.client.user?.json,
      origin: w.client.origin,
    );
  }

  bool get isOpen => route?.isActive ?? false;

  /// Opens the switcher over the current page. A repeated Cmd/Ctrl+K while it
  /// is open leaves it open (the field keeps focus).
  void open(BuildContext context) {
    if (isOpen || w.server == null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    openedAuthority = directoryAuthority(w);
    // Conversations the server-level lists have not delivered yet start now;
    // settled kinds are reused as they are.
    w.entityDirectory.ensureAuthors();
    final created = RawDialogRoute<void>(
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: 'Close search',
      transitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => Material(
        type: MaterialType.transparency,
        child: QuickSwitcher(
          listenable: Listenable.merge([w, w.entityDirectory, recents]),
          data: data,
          clock: clock,
          onClose: close,
          onOpenEntity: openEntity,
          onOpenMessage: openMessage,
          onSearchAll: searchAll,
          searchMessages: searchMessages,
        ),
      ),
    );
    route = created;
    unawaited(
      navigator.push(created).whenComplete(() {
        if (identical(route, created)) route = null;
      }),
    );
  }

  void close() {
    final current = route;
    route = null;
    if (current != null && current.isActive) {
      current.navigator?.removeRoute(current);
    }
  }

  Future<List<Map<String, dynamic>>> searchMessages(String query) async {
    final authority = directoryAuthority(w);
    final value = await w.query(
      '/messages/search',
      query: {'q': query, 'limit': 10},
    );
    if (_disposed || authority != directoryAuthority(w)) return const [];
    final list = value is List
        ? value
        : (value is Map ? value['results'] : null);
    return [
      if (list is List)
        for (final row in list.whereType<Map>()) Map<String, dynamic>.from(row),
    ];
  }

  Future<void> remember({
    SearchEntity? entity,
    String? channelId,
    required String query,
  }) async {
    final scope = memoryScope;
    if (scope == null) return;
    // The record is read before it is extended, so a first use never replaces
    // what the device already holds.
    await searchMemory.load(scope);
    if (_disposed || memoryScope?.key != scope.key) return;
    if (query.trim().isNotEmpty) searchMemory.rememberQuery(scope, query);
    final key = entity != null
        ? searchUsageEntityKey(entity)
        : channelId == null
        ? null
        : usageKeyOfChannel(channelId);
    if (key != null) searchMemory.recordOpen(scope, key);
  }

  /// Source rememberOpenedChannel: a channel by its id, a DM by its peer.
  String? usageKeyOfChannel(String channelId) {
    final channel = [
      ...w.channels,
      ...w.dms,
    ].where((c) => c.id == channelId).firstOrNull;
    if (channel == null) return null;
    final peer = channel.json['peerId'];
    if (channel.type == 'dm') {
      if (peer is! String) return null;
      return switch (channel.json['peerType']) {
        'agent' => 'agent:$peer',
        'user' => 'human:$peer',
        _ => null,
      };
    }
    return 'channel:$channelId';
  }

  Future<void> openEntity(SearchEntity entity, String query) async {
    final authority = directoryAuthority(w);
    close();
    if (entity.kind == 'computer') {
      actions.openDirectory(RaftRoute.computer, entity.id);
      return;
    }
    unawaited(remember(entity: entity, query: query));
    if (entity.kind == 'channel') {
      final channel = [
        ...w.channels,
        ...w.dms,
      ].where((c) => c.id == entity.id).firstOrNull;
      if (channel != null) await actions.openConversation(channel);
      return;
    }
    final agent = entity.kind == 'agent';
    final existing = w.dms
        .where(
          (c) =>
              c.json['peerId'] == entity.id &&
              c.json['peerType'] == (agent ? 'agent' : 'user'),
        )
        .firstOrNull;
    if (existing != null) {
      await actions.openConversation(existing);
      return;
    }
    try {
      final result = await w.command(
        'POST',
        '/channels/dm',
        data: {agent ? 'agentId' : 'userId': entity.id},
      );
      if (_disposed || authority != directoryAuthority(w)) return;
      if (result is Map && result['id'] is String) {
        await w.refreshChannels();
        if (_disposed || authority != directoryAuthority(w)) return;
        await actions.openConversation(
          RaftChannel(Map<String, dynamic>.from(result)),
        );
        return;
      }
    } catch (_) {
      if (_disposed || authority != directoryAuthority(w)) return;
    }
    // Source falls back to the person's or agent's profile.
    actions.openDirectory(agent ? RaftRoute.agent : RaftRoute.human, entity.id);
  }

  Future<void> openMessage(Map<String, dynamic> row, String query) async {
    close();
    final channelId = row['channelId'], messageId = row['id'];
    if (channelId is! String || messageId is! String) return;
    if (row['channelType'] == 'thread') {
      final parentChannel = row['parentChannelId'];
      final parentMessage = row['parentMessageId'];
      if (parentChannel is! String || parentMessage is! String) return;
      unawaited(remember(channelId: parentChannel, query: query));
      await actions.openThread(
        parentChannelId: parentChannel,
        parentMessageId: parentMessage,
        messageId: messageId,
        threadChannelId: channelId,
      );
      return;
    }
    unawaited(remember(channelId: channelId, query: query));
    await actions.openMessage(channelId, messageId);
  }

  void searchAll(String query) {
    close();
    unawaited(remember(query: query));
    actions.searchAll(query);
  }
}
