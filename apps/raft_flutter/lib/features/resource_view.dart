import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'resource_filters.dart';

class ResourceView extends StatefulWidget {
  const ResourceView({
    super.key,
    required this.controller,
    required this.section,
    required this.onMessage,
  });
  final WorkspaceController controller;
  final String section;
  final Future<void> Function(String, String?) onMessage;
  @override
  State<ResourceView> createState() => _ResourceViewState();
}

class _ResourceViewState extends State<ResourceView> {
  final query = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? error;
  String filter = 'all';
  ResourceFilters advanced = ResourceFilters();
  List<ResourceSender> senders = [];
  List<Map<String, dynamic>> activityGroups = [];
  String? catalogScope;
  int catalogRequest = 0;
  String taskLayout = 'list';
  final taskAdvanced = TaskResourceFilters();
  final Map<String, List<Map<String, dynamic>>> lanes = {};
  final Map<String, String?> laneCursors = {};
  final Set<String> laneBusy = {};
  String? cursor;
  bool hasMore = false;
  int requestGeneration = 0;
  StreamSubscription<RaftEvent>? events;
  Timer? refreshTimer;
  WorkspaceController get w => widget.controller;
  String? acceptedAuthority;
  int authorityRevision = 0;
  final Set<ModalRoute<dynamic>> dialogs = {};
  String get authority {
    final channels = [...w.channels, ...w.dms]
      ..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode([
      w.client.origin,
      w.client.generation,
      w.client.user?.id,
      w.client.serverId,
      w.server?.id,
      w.server?.string('role'),
      widget.section,
      authorityRevision,
      for (final c in channels)
        {
          'id': c.id,
          'type': c.type,
          'joined': c.joined,
          'archived': c.archived,
          for (final key in [
            'isPrivate',
            'visibility',
            'accessLevel',
            'membership',
            'capabilities',
            'channelCapabilities',
            'guestAccessEnabled',
            'readOnlyReason',
            'parentChannelId',
            'serverId',
            'role',
          ])
            if (c.json.containsKey(key)) key: c.json[key],
        },
    ]);
  }

  bool accepts(String scope, [int? request]) =>
      mounted &&
      scope == authority &&
      scope == acceptedAuthority &&
      (request == null || request == requestGeneration);
  void clearRows() {
    rows = [];
    lanes.clear();
    laneCursors.clear();
    laneBusy.clear();
    cursor = null;
    hasMore = false;
    activityGroups = [];
    taskAdvanced.clear();
  }

  void resetAdvanced() {
    advanced = ResourceFilters();
    senders = [];
    catalogScope = null;
    ++catalogRequest;
  }

  void closeDialogs() {
    for (final route in dialogs.toList()) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }
    dialogs.clear();
  }

  void fail(Object cause, String scope, {int? request}) {
    if (!accepts(scope, request)) return;
    if (cause is RaftApiException && [401, 403].contains(cause.status)) {
      authorityRevision++;
      acceptedAuthority = authority;
      requestGeneration++;
      refreshTimer?.cancel();
      closeDialogs();
      clearRows();
      resetAdvanced();
    }
    setState(() {
      error = '$cause';
      loading = false;
    });
  }

  void authorityChanged() {
    if (!mounted || acceptedAuthority == authority) return;
    acceptedAuthority = authority;
    requestGeneration++;
    refreshTimer?.cancel();
    closeDialogs();
    setState(() {
      clearRows();
      resetAdvanced();
      query.clear();
      filter = 'all';
      error = null;
      loading = true;
    });
    load();
  }

  Future<V?> scopedDialog<V>(
    String scope,
    Widget Function(BuildContext) builder,
  ) async {
    if (!accepts(scope)) return null;
    ModalRoute<dynamic>? owned;
    try {
      return await showDialog<V>(
        context: context,
        builder: (context) {
          owned = ModalRoute.of(context);
          if (owned != null) dialogs.add(owned!);
          if (!accepts(scope)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (owned?.isActive == true) {
                owned?.navigator?.removeRoute(owned!);
              }
            });
            return const SizedBox.shrink();
          }
          return builder(context);
        },
      );
    } finally {
      dialogs.remove(owned);
    }
  }

  void closeOwnedDialog(BuildContext context, String scope, [Object? result]) {
    if (!context.mounted || !accepts(scope)) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) {
      route!.navigator?.pop(result);
    }
  }

  void subscribeEvents() {
    final client = w.client;
    events = client.events.listen((event) {
      if (!mounted || !identical(client, w.client)) return;
      if ([
        'channel:removed',
        'channel:updated',
        'channel:members-updated',
        'channel:authority-updated',
      ].contains(event.name)) {
        authorityRevision++;
        authorityChanged();
        return;
      }
      final relevant = switch (widget.section) {
        'activity' =>
          event.name.startsWith('message:') ||
              event.name.startsWith('read_state:') ||
              event.name.startsWith('scope_read:') ||
              event.name.startsWith('thread:') ||
              event.name == 'sync:resume:response',
        'tasks' => event.name.startsWith('task:'),
        'saved' || 'search' => event.name == 'message:updated',
        'agents' => event.name.startsWith('agent:'),
        'computers' =>
          event.name.startsWith('machine:') || event.name.startsWith('daemon:'),
        'members' => event.name.startsWith('server:member'),
        _ => false,
      };
      if (relevant) {
        final scope = authority;
        refreshTimer?.cancel();
        refreshTimer = Timer(const Duration(milliseconds: 150), () {
          if (accepts(scope)) load();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    acceptedAuthority = authority;
    w.addListener(authorityChanged);
    subscribeEvents();
    load();
  }

  @override
  void didUpdateWidget(covariant ResourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, w)) {
      oldWidget.controller.removeListener(authorityChanged);
      events?.cancel();
      w.addListener(authorityChanged);
      subscribeEvents();
    }
    authorityChanged();
  }

  @override
  void dispose() {
    final owned = dialogs.toList();
    dialogs.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in owned) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    requestGeneration++;
    ++catalogRequest;
    w.removeListener(authorityChanged);
    query.dispose();
    events?.cancel();
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    final request = ++requestGeneration, scope = authority;
    if (['search', 'tasks'].contains(widget.section)) {
      unawaited(loadSenders(scope));
    }
    if (w.server == null ||
        !w.canVisitSection(widget.section) ||
        widget.section == 'search' && advanced.search(query.text) == null) {
      setState(() {
        clearRows();
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
      laneBusy.clear();
      if (!append && ['search', 'saved', 'activity'].contains(widget.section)) {
        rows = [];
        cursor = null;
        hasMore = false;
      }
    });
    try {
      if (widget.section == 'tasks' && taskLayout == 'board') {
        final pages = await Future.wait(
          raftTaskStatuses.map(
            (status) => w.query(
              '/tasks/server',
              query: {'status': status, 'detail': 'summary', 'limit': 30},
            ),
          ),
        );
        if (!accepts(scope, request)) return;
        setState(() {
          for (var i = 0; i < raftTaskStatuses.length; i++) {
            final status = raftTaskStatuses[i], page = pages[i];
            lanes[status] = (page['tasks'] as List)
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
            laneCursors[status] = page['next_cursor'];
          }
          rows = lanes.values.expand((r) => r).toList();
        });
        return;
      }
      final path = switch (widget.section) {
        'activity' => switch (filter) {
          'done' => '/channels/inbox/done',
          'unfollowed' => '/channels/inbox/unfollowed',
          _ => '/channels/inbox',
        },
        'saved' => '/channels/saved',
        'search' => '/messages/search',
        'tasks' => '/tasks/server',
        'agents' => '/agents',
        'computers' => '/servers/${w.server!.id}/machines',
        'members' => '/servers/${w.server!.id}/members',
        _ => throw const RaftApiException('This page is not available.'),
      };
      final value = await w.query(
        path,
        query: widget.section == 'search'
            ? advanced.search(query.text, offset: append ? rows.length : 0)
            : ['saved', 'activity'].contains(widget.section)
            ? advanced.list(
                query.text,
                offset: append ? rows.length : 0,
                limit: widget.section == 'saved' ? 20 : 30,
                filter:
                    widget.section == 'activity' &&
                        !['done', 'unfollowed'].contains(filter)
                    ? filter
                    : null,
              )
            : {
                if (widget.section == 'tasks' && filter != 'all')
                  'status': filter,
                if (widget.section == 'tasks') 'detail': 'summary',
                if (query.text.trim().isNotEmpty && widget.section != 'tasks')
                  'q': query.text.trim(),
                'limit': 50,
                if (append && widget.section == 'tasks' && cursor != null)
                  'cursor': cursor,
                if (widget.section != 'tasks')
                  'offset': append ? rows.length : 0,
              },
      );
      final list = value is List
          ? value
          : value['items'] ??
                value['results'] ??
                value['tasks'] ??
                value['saved'] ??
                value['machines'] ??
                [];
      if (accepts(scope, request)) {
        setState(() {
          final fetched = (list as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          rows = append ? [...rows, ...fetched] : fetched;
          if (widget.section == 'activity' &&
              value is Map &&
              value['groups'] is List) {
            activityGroups = (value['groups'] as List)
                .whereType<Map>()
                .map((g) => Map<String, dynamic>.from(g))
                .toList();
          }
          cursor = value is Map ? value['next_cursor'] as String? : null;
          hasMore = widget.section == 'tasks'
              ? cursor != null
              : value is Map && value['hasMore'] == true;
        });
      }
    } catch (e) {
      fail(e, scope, request: request);
    } finally {
      if (accepts(scope, request)) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> command(
    String method,
    String path, {
    dynamic data,
    String? sourceScope,
  }) async {
    final scope = sourceScope ?? authority;
    if (!accepts(scope)) return;
    try {
      await w.client.request(method, path, data: data);
      if (!accepts(scope)) return;
      await w.refreshUnread();
      if (accepts(scope)) await load();
    } catch (e) {
      fail(e, scope);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = authority;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (['search', 'saved'].contains(widget.section))
                Expanded(
                  child: TextField(
                    controller: query,
                    decoration: InputDecoration(
                      hintText: raftText(
                        context,
                        widget.section == 'search'
                            ? 'Search messages'
                            : 'Filter saved messages',
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (_) => load(),
                  ),
                )
              else if (widget.section == 'activity')
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'all',
                        label: Text(raftText(context, 'All')),
                      ),
                      ButtonSegment(
                        value: 'unread',
                        label: Text(raftText(context, 'Unread')),
                      ),
                      ButtonSegment(
                        value: 'mentions',
                        label: Text(raftText(context, 'Mentions')),
                      ),
                    ],
                    emptySelectionAllowed: true,
                    selected: ['all', 'unread', 'mentions'].contains(filter)
                        ? {filter}
                        : <String>{},
                    onSelectionChanged: (s) {
                      if (s.isEmpty || !accepts(scope)) return;
                      filter = s.first;
                      load();
                    },
                  ),
                )
              else if (widget.section == 'tasks')
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: filter,
                    decoration: InputDecoration(
                      labelText: raftText(context, 'Task status'),
                    ),
                    items:
                        [
                              'all',
                              'todo',
                              'in_progress',
                              'in_review',
                              'done',
                              'closed',
                            ]
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  raftText(
                                    context,
                                    s == 'all' ? 'All' : raftTaskStatusLabel(s),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (s) {
                      filter = s!;
                      load();
                    },
                  ),
                )
              else
                Expanded(
                  child: Text(
                    '${rows.length} ${widget.section}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              if (widget.section == 'tasks')
                IconButton(
                  tooltip: raftText(
                    context,
                    taskLayout == 'board'
                        ? 'Show task list'
                        : 'Show task board',
                  ),
                  icon: Icon(
                    taskLayout == 'board'
                        ? Icons.view_list_outlined
                        : Icons.view_kanban_outlined,
                  ),
                  onPressed: () {
                    taskLayout = taskLayout == 'board' ? 'list' : 'board';
                    load();
                  },
                ),
              IconButton(
                tooltip: raftText(context, 'Refresh'),
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
              if (widget.section == 'tasks')
                IconButton(
                  tooltip: raftText(context, 'Create task'),
                  onPressed: w.server?.string('role') == 'guest'
                      ? null
                      : () => createTask(sourceScope: scope),
                  icon: const Icon(Icons.add),
                ),
              if (widget.section == 'activity')
                PopupMenuButton<String>(
                  tooltip: raftText(context, 'Activity actions'),
                  onSelected: (action) {
                    if (!accepts(scope)) return;
                    if (action == 'read-all') {
                      command(
                        'POST',
                        '/channels/inbox/read-all',
                        sourceScope: scope,
                      );
                    } else {
                      filter = action;
                      load();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'read-all',
                      child: Text(raftText(context, 'Mark all read')),
                    ),
                    PopupMenuItem(
                      value: 'done',
                      child: Text(raftText(context, 'Done conversations')),
                    ),
                    PopupMenuItem(
                      value: 'unfollowed',
                      child: Text(raftText(context, 'Unfollowed threads')),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (['search', 'saved', 'activity'].contains(widget.section))
          advancedFilters(),
        if (widget.section == 'tasks') taskFilters(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: loading && rows.isEmpty
              ? Center(child: CircularProgressIndicator())
              : widget.section == 'tasks' && taskLayout == 'board'
              ? taskBoard()
              : rows.isEmpty
              ? RaftEmptyState(
                  title: widget.section == 'search'
                      ? 'Search your workspace'
                      : 'No ${widget.section}',
                  detail: widget.section == 'search'
                      ? 'Enter words to find messages.'
                      : 'There are no items in this view.',
                )
              : widget.section == 'activity' && advanced.groupByChannel
              ? groupedActivity()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: visibleRows.length + (hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => index == visibleRows.length
                      ? TextButton(
                          onPressed: () => load(append: true),
                          child: Text(raftText(context, 'Load more')),
                        )
                      : item(visibleRows[index]),
                ),
        ),
      ],
    );
  }

  Future<void> loadSenders(String scope) async {
    if (!accepts(scope) || catalogScope == scope || w.server == null) return;
    catalogScope = scope;
    final ticket = ++catalogRequest;
    final paths = [
      if (w.can('viewMembers')) '/servers/${w.server!.id}/members',
      if (w.can('viewAgents')) '/agents',
    ];
    final options = <String, ResourceSender>{};
    final self = w.client.user;
    if (self != null) {
      options['user:${self.id}'] = ResourceSender(
        self.id,
        'user',
        self.name.isEmpty ? 'You' : self.name,
      );
    }
    try {
      final values = await Future.wait(paths.map((path) => w.query(path)));
      if (!accepts(scope) || ticket != catalogRequest) return;
      for (var i = 0; i < paths.length; i++) {
        final type = paths[i] == '/agents' ? 'agent' : 'user';
        final value = values[i];
        final list = value is List
            ? value
            : value is Map
            ? value['members'] ?? value['agents'] ?? []
            : [];
        for (final row in (list as List).whereType<Map>()) {
          final id = type == 'user' ? row['userId'] ?? row['id'] : row['id'];
          if (id is! String || row['deletedAt'] != null) continue;
          final name = '${row['displayName'] ?? row['name'] ?? ''}';
          if (name.isEmpty) continue;
          options['$type:$id'] = ResourceSender(
            id,
            type,
            name,
            handle: row['name'] is String ? row['name'] as String : '',
          );
        }
      }
      setState(() => senders = options.values.toList());
    } catch (e) {
      if (!accepts(scope) || ticket != catalogRequest) return;
      catalogScope = null;
      fail(e, scope);
    }
  }

  Widget filterMenu(
    String title,
    String label,
    Map<String, String> options,
    void Function(String) changed, {
    bool labelIsContent = false,
  }) {
    final scope = authority;
    return PopupMenuButton<String>(
      tooltip: raftText(context, title),
      onSelected: (value) {
        if (accepts(scope)) changed(value);
      },
      itemBuilder: (_) => [
        for (final option in options.entries)
          PopupMenuItem(
            value: option.key,
            child: privateMenuLabel(scope, raftText(context, option.value)),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  labelIsContent ? label : raftText(context, label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget advancedFilters() {
    final scope = authority;
    final channelOptions = <String, String>{
      '': 'All channels',
      for (final c in [...w.channels, ...w.dms])
        c.id: '${c.type == 'dm' ? '@' : '#'}${c.name}',
    };
    if (widget.section == 'activity') {
      for (final group in activityGroups) {
        final id = group['channelId'], label = group['channelName'];
        if (id is String && label is String && label.isNotEmpty) {
          channelOptions[id] =
              '${group['channelType'] == 'dm' ? '@' : '#'}$label (${group['count'] ?? 0})';
        }
      }
    }
    final options = <String, ResourceSender>{
      for (final sender in senders) sender.key: sender,
    };
    for (final row in rows) {
      final id = row['senderId'],
          type = row['senderType'],
          label = row['senderName'];
      if (id is String &&
          ['user', 'agent'].contains(type) &&
          label is String &&
          label.isNotEmpty) {
        options['$type:$id'] = ResourceSender(id, type, label);
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 4,
        runSpacing: 0,
        children: [
          if (widget.section == 'activity')
            SizedBox(
              width: 220,
              child: TextField(
                controller: query,
                decoration: InputDecoration(
                  hintText: raftText(context, 'Filter Activity'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onSubmitted: (_) {
                  if (accepts(scope)) load();
                },
              ),
            ),
          filterMenu(
            'Filter by channel',
            channelOptions[advanced.channelId] ?? 'All channels',
            channelOptions,
            (id) {
              advanced.channelId = id.isEmpty ? null : id;
              load();
            },
          ),
          if (widget.section == 'search') ...[
            filterMenu(
              'Filter by sender',
              advanced.sender?.label ?? 'All senders',
              {
                '': 'All senders',
                for (final sender in options.values)
                  sender.key:
                      '${sender.label} · ${sender.type == 'user' ? raftText(context, 'Human') : raftText(context, 'Agent')}',
              },
              (key) {
                advanced.selectSender(options[key]);
                load();
              },
              labelIsContent: advanced.sender != null,
            ),
            for (final entry in const {
              'mentioned': 'Mentions me',
              'humans': 'Humans',
              'agents': 'Agents',
            }.entries)
              FilterChip(
                label: Text(raftText(context, entry.value)),
                selected: advanced.scopes.contains(entry.key),
                onSelected: (_) {
                  if (!accepts(scope)) return;
                  advanced.toggleScope(entry.key);
                  load();
                },
              ),
            filterMenu(
              'Search date range',
              const {
                'any': 'Any time',
                'today': 'Today',
                '7d': 'Last 7 days',
                '30d': 'Last 30 days',
              }[advanced.timeRange]!,
              const {
                'any': 'Any time',
                'today': 'Today',
                '7d': 'Last 7 days',
                '30d': 'Last 30 days',
              },
              (value) {
                advanced.timeRange = value;
                load();
              },
            ),
            filterMenu(
              'Sort search results',
              advanced.searchSort == 'recent' ? 'Most recent' : 'Relevance',
              const {'relevance': 'Relevance', 'recent': 'Most recent'},
              (value) {
                advanced.searchSort = value;
                load();
              },
            ),
          ] else ...[
            filterMenu(
              'Sort conversations',
              advanced.direction == 'asc' ? 'Oldest first' : 'Newest first',
              const {'desc': 'Newest first', 'asc': 'Oldest first'},
              (value) {
                advanced.direction = value;
                load();
              },
            ),
            if (widget.section == 'activity')
              FilterChip(
                label: Text(raftText(context, 'Group by channel')),
                selected: advanced.groupByChannel,
                onSelected: (value) {
                  if (accepts(scope)) {
                    setState(() => advanced.groupByChannel = value);
                  }
                },
              ),
          ],
          TextButton(
            onPressed: () {
              if (!accepts(scope)) return;
              advanced = ResourceFilters();
              query.clear();
              load();
            },
            child: Text(raftText(context, 'Clear filters')),
          ),
        ],
      ),
    );
  }

  Widget groupedActivity() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final id =
          '${row['kind'] == 'thread' ? row['parentChannelId'] : row['channelId']}';
      (groups[id] ??= []).add(row);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final group in groups.values) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${group.first['parentChannelName'] ?? group.first['channelName'] ?? group.first['peerDisplayName'] ?? group.first['peerName'] ?? raftText(context, 'Conversation')} · ${group.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final row in group) item(row),
        ],
        if (hasMore)
          TextButton(
            onPressed: () => load(append: true),
            child: Text(raftText(context, 'Load more')),
          ),
      ],
    );
  }

  Future<void> activityAction(
    Map<String, dynamic> row,
    String action,
    String scope,
  ) async {
    if (!accepts(scope) ||
        !rows.any((candidate) => identical(candidate, row))) {
      return;
    }
    final mutation = activityMutation(row, action);
    if (mutation == null) {
      if (action == 'done') {
        await load();
        if (accepts(scope)) {
          setState(
            () => error =
                'Refresh Activity before marking this conversation done.',
          );
        }
      }
      return;
    }
    await command(
      'POST',
      mutation.path,
      data: mutation.data,
      sourceScope: scope,
    );
  }

  List<Map<String, dynamic>> get visibleRows =>
      widget.section == 'tasks' ? rows.where(matchesTask).toList() : rows;
  bool matchesTask(Map<String, dynamic> row) => taskAdvanced.matches(row);
  Widget privateMenuLabel(String scope, String value) => Builder(
    builder: (context) {
      final route = ModalRoute.of(context);
      dialogs.removeWhere((r) => !r.isActive);
      if (route != null) dialogs.add(route);
      return accepts(scope) ? Text(value) : const SizedBox.shrink();
    },
  );
  Future<void> taskFilterPicker(
    String field,
    Map<String, String> options,
    Set<String> selection, {
    String? selfName,
    Map<String, String> aliases = const {},
  }) async {
    final scope = authority;
    final selected = selection.toSet();
    var needle = '';
    final accepted = await scopedDialog<bool>(
      scope,
      (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            raftText(context, 'Filter tasks by ${field.toLowerCase()}'),
          ),
          content: SizedBox(
            width: 400,
            height:
                (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom) *
                .45,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: raftText(context, 'Search'),
                  ),
                  onChanged: (value) {
                    if (context.mounted &&
                        accepts(scope) &&
                        ModalRoute.of(context)?.isCurrent == true) {
                      update(() => needle = value.trim().toLowerCase());
                    }
                  },
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final option in options.entries)
                        if (option.value.toLowerCase().contains(needle) ||
                            aliases[option.key]?.toLowerCase().contains(
                                  needle,
                                ) ==
                                true ||
                            option.key == 'user:${w.client.user?.id}' &&
                                selfName?.toLowerCase().contains(needle) ==
                                    true)
                          CheckboxListTile(
                            title: Text(option.value),
                            secondary:
                                option.key == 'unassigned' || field == 'Channel'
                                ? null
                                : Icon(
                                    option.key.startsWith('user:')
                                        ? Icons.person_outline
                                        : Icons.smart_toy_outlined,
                                    semanticLabel: raftText(
                                      context,
                                      option.key.startsWith('user:')
                                          ? 'Human'
                                          : 'Agent',
                                    ),
                                  ),
                            subtitle:
                                option.key == 'user:${w.client.user?.id}' &&
                                    selfName?.isNotEmpty == true
                                ? Text(selfName!)
                                : null,
                            value: selected.contains(option.key),
                            onChanged: (value) {
                              if (!context.mounted ||
                                  !accepts(scope) ||
                                  ModalRoute.of(context)?.isCurrent != true) {
                                return;
                              }
                              update(() {
                                if (value == true) {
                                  selected.add(option.key);
                                } else {
                                  selected.remove(option.key);
                                }
                              });
                            },
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.mounted &&
                    accepts(scope) &&
                    ModalRoute.of(context)?.isCurrent == true) {
                  update(selected.clear);
                }
              },
              child: Text(raftText(context, 'Clear filters')),
            ),
            TextButton(
              onPressed: () {
                if (accepts(scope)) closeOwnedDialog(context, scope, false);
              },
              child: Text(raftText(context, 'Cancel')),
            ),
            TextButton(
              onPressed: () {
                if (accepts(scope)) closeOwnedDialog(context, scope, true);
              },
              child: Text(raftText(context, 'Apply')),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !accepts(scope)) return;
    setState(() {
      selection
        ..clear()
        ..addAll(selected);
    });
  }

  Widget taskFilters() {
    final scope = authority;
    final names = <String, String>{
      for (final person in senders) person.key: person.label,
    };
    for (final row in [...rows, ...lanes.values.expand((v) => v)]) {
      for (final prefix in ['created', 'claimed']) {
        final id = row['${prefix}ById'], type = row['${prefix}ByType'];
        final label = row['${prefix}ByName'];
        if (id is String &&
            ['user', 'agent'].contains(type) &&
            label is String &&
            label.isNotEmpty) {
          names['$type:$id'] = label;
        }
      }
    }
    final ordered = names.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final channelOptions = <String, String>{
      for (final c in w.channels.where(
        (c) => ['channel', 'private'].contains(c.type),
      ))
        c.id: '#${c.name}',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final field in ['Channel', 'Creator', 'Assignee'])
            Builder(
              builder: (context) {
                final selection = switch (field) {
                  'Channel' => taskAdvanced.channels,
                  'Creator' => taskAdvanced.creators,
                  _ => taskAdvanced.assignees,
                };
                final self = w.client.user;
                final options = field == 'Channel'
                    ? channelOptions
                    : <String, String>{
                        if (field == 'Assignee')
                          'unassigned': raftText(context, 'Unassigned'),
                        if (self != null)
                          'user:${self.id}': raftText(
                            context,
                            field == 'Creator'
                                ? 'Created by me'
                                : 'Assigned to me',
                          ),
                        for (final entry in ordered)
                          if (entry.key != 'user:${self?.id}')
                            entry.key: entry.value,
                      };
                return Tooltip(
                  message: raftText(
                    context,
                    'Filter tasks by ${field.toLowerCase()}',
                  ),
                  child: TextButton.icon(
                    icon: Icon(
                      field == 'Channel' ? Icons.tag : Icons.person_outline,
                      size: 16,
                    ),
                    label: Text(
                      '${raftText(context, field)}${selection.isEmpty ? '' : ' (${selection.length})'}',
                    ),
                    onPressed: () {
                      if (accepts(scope)) {
                        taskFilterPicker(
                          field,
                          options,
                          selection,
                          selfName: field == 'Channel'
                              ? null
                              : names['user:${self?.id}'],
                          aliases: {
                            for (final person in senders)
                              person.key: person.handle,
                          },
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                );
              },
            ),
          if (!taskAdvanced.isEmpty)
            TextButton(
              onPressed: () {
                if (accepts(scope)) setState(taskAdvanced.clear);
              },
              child: Text(raftText(context, 'Clear filters')),
            ),
        ],
      ),
    );
  }

  Future<void> moreLane(String status) async {
    final cursor = laneCursors[status],
        request = requestGeneration,
        scope = authority;
    if (cursor == null || laneBusy.contains(status)) return;
    setState(() => laneBusy.add(status));
    try {
      final page = await w.query(
        '/tasks/server',
        query: {
          'status': status,
          'detail': 'summary',
          'limit': 30,
          'cursor': cursor,
        },
      );
      if (!accepts(scope, request)) return;
      setState(() {
        final ids = lanes[status]!.map((r) => r['id']).toSet();
        lanes[status]!.addAll(
          (page['tasks'] as List)
              .map((r) => Map<String, dynamic>.from(r))
              .where((r) => ids.add(r['id'])),
        );
        laneCursors[status] = page['next_cursor'];
        rows = lanes.values.expand((r) => r).toList();
      });
    } catch (e) {
      fail(e, scope, request: request);
    } finally {
      if (accepts(scope, request)) setState(() => laneBusy.remove(status));
    }
  }

  Widget taskBoard() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final status in raftTaskStatuses.where(
          (s) => filter == 'all' || filter == s,
        ))
          Container(
            width: 320,
            margin: const EdgeInsets.fromLTRB(16, 8, 0, 16),
            decoration: BoxDecoration(
              color: RaftTokens.of(context).sidebar,
              border: Border.all(color: RaftTokens.of(context).line),
              borderRadius: BorderRadius.circular(
                RaftTokens.of(context).radius,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      RaftTaskStatus(status: status),
                      const Spacer(),
                      Text(
                        '${(lanes[status] ?? []).where(matchesTask).length}${laneCursors[status] != null ? '+' : ''}',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final row in (lanes[status] ?? []).where(
                        matchesTask,
                      ))
                        item(row),
                      if (laneCursors[status] != null)
                        TextButton(
                          onPressed: laneBusy.contains(status)
                              ? null
                              : () => moreLane(status),
                          child: Text(
                            laneBusy.contains(status)
                                ? 'Loading…'
                                : 'Load more ${raftTaskStatusLabel(status)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget item(Map<String, dynamic> row) {
    final section = widget.section, scope = authority;
    final name =
        (row['title'] ??
                row['parentChannelName'] ??
                row['channelName'] ??
                row['displayName'] ??
                row['name'] ??
                row['peerDisplayName'] ??
                row['peerName'] ??
                'Conversation')
            .toString();
    final content =
        (row['preview'] ??
                row['lastMessageContent'] ??
                row['lastMessagePreview'] ??
                row['latestActivityPreview'] ??
                row['content'] ??
                row['description'] ??
                row['status'] ??
                row['role'] ??
                row['hostname'] ??
                '')
            .toString();
    if (section == 'tasks') {
      final status = '${row['status'] ?? 'todo'}';
      final role = w.server?.string('role');
      final allowed = ['owner', 'admin'].contains(role)
          ? raftTaskStatuses
          : [status, ...?raftTaskTransitions[status]];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: RaftTaskCard(
          key: ValueKey('task-${row['id']}'),
          title: name,
          number: '${row['taskNumber'] ?? row['number'] ?? ''}',
          channel: '${row['channelName'] ?? ''}',
          status: status,
          description:
              '${row['descriptionPreview'] ?? row['description'] ?? ''}',
          assignee: row['claimedByName'] as String?,
          onTap: () => taskDetails(row, sourceScope: scope),
          statusOptions: allowed,
          onStatus:
              role == 'guest' ||
                  row['readOnlyReason'] != null ||
                  !w.channels.any(
                    (c) => c.id == row['channelId'] && c.joined && !c.archived,
                  )
              ? null
              : (next) => command(
                  'PATCH',
                  '/tasks/${row['id']}/status',
                  data: {'status': next},
                  sourceScope: scope,
                ),
        ),
      );
    }
    return ListTile(
      key: section == 'activity' && row['kind'] == 'thread'
          ? ValueKey('activity-thread-${row['threadChannelId']}')
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: section == 'agents' || section == 'members'
          ? RaftAvatar(name: name)
          : Icon(
              section == 'computers'
                  ? Icons.computer_outlined
                  : section == 'saved'
                  ? Icons.bookmark_border
                  : Icons.forum_outlined,
            ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(content, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: section == 'saved'
          ? IconButton(
              tooltip: raftText(context, 'Remove saved message'),
              icon: const Icon(Icons.bookmark_remove_outlined),
              onPressed: () => command(
                'DELETE',
                '/channels/saved/${row['messageId']}',
                sourceScope: scope,
              ),
            )
          : section == 'activity' && row['kind'] != 'mention_action'
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: raftText(
                    context,
                    filter == 'done'
                        ? 'Restore conversation'
                        : 'Mark conversation done',
                  ),
                  icon: Icon(filter == 'done' ? Icons.undo : Icons.done),
                  onPressed: () => activityAction(
                    row,
                    filter == 'done' ? 'undone' : 'done',
                    scope,
                  ),
                ),
                if (row['kind'] == 'thread')
                  IconButton(
                    tooltip: raftText(
                      context,
                      row['isFollowing'] == false
                          ? 'Follow thread'
                          : 'Unfollow thread',
                    ),
                    icon: Icon(
                      row['isFollowing'] == false
                          ? Icons.notifications_outlined
                          : Icons.notifications_off_outlined,
                    ),
                    onPressed: () => activityAction(
                      row,
                      row['isFollowing'] == false ? 'follow' : 'unfollow',
                      scope,
                    ),
                  ),
              ],
            )
          : row['unreadCount'] is num && (row['unreadCount'] as num) > 0
          ? Badge(label: Text('${row['unreadCount']}'))
          : null,
      onTap: () async {
        if (!accepts(scope)) return;
        if (['agents', 'computers', 'members'].contains(section)) {
          await scopedDialog<void>(
            scope,
            (context) => AlertDialog(
              title: Text(name),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => closeOwnedDialog(context, scope),
                  child: Text(raftText(context, 'Close')),
                ),
              ],
            ),
          );
          return;
        }
        final id = row['parentChannelId'] ?? row['channelId'];
        if (id is! String) return;
        await widget.onMessage(
          id,
          (row['messageId'] ??
                  row['latestActivityMessageId'] ??
                  row['lastMessageId'] ??
                  (section == 'search' ? row['id'] : null))
              as String?,
        );
      },
    );
  }

  Future<void> createTask({String? sourceScope}) async {
    final scope = sourceScope ?? authority;
    if (!accepts(scope) || w.server?.string('role') == 'guest') return;
    final available = w.channels.where((c) => c.joined && !c.archived).toList();
    if (available.isEmpty) {
      setState(() => error = 'Join a channel before creating a task.');
      return;
    }
    await scopedDialog<bool>(
      scope,
      (dialogContext) => RaftFormDialog(
        title: 'Create task',
        submitLabel: 'Create',
        fields: [
          RaftFormField(
            'channel',
            'Channel',
            initial: available.any((c) => c.id == w.channel?.id)
                ? w.channel!.id
                : available.first.id,
            choices: {for (final c in available) c.id: '#${c.name}'},
            localizeChoices: false,
          ),
          const RaftFormField('title', 'Title', required: true),
          const RaftFormField(
            'description',
            'Description (Markdown)',
            multiline: true,
          ),
        ],
        onSubmit: (values) async {
          if (!accepts(scope) ||
              w.server?.string('role') == 'guest' ||
              !w.channels.any(
                (c) => c.id == values['channel'] && c.joined && !c.archived,
              )) {
            throw const RaftApiException(
              'Channel access changed. Reopen this form.',
            );
          }
          try {
            await w.client.request(
              'POST',
              '/tasks/channel/${values['channel']}',
              data: {
                'tasks': [
                  {
                    'title': values['title'],
                    'description': values['description'],
                  },
                ],
              },
            );
            if (!accepts(scope)) return;
            await w.refreshUnread();
            if (accepts(scope)) await load();
          } catch (e) {
            fail(e, scope);
            rethrow;
          }
        },
      ),
    );
  }

  Future<void> assignTask(
    Map<String, dynamic> task, {
    String? sourceScope,
  }) async {
    final scope = sourceScope ?? authority;
    if (!accepts(scope) || !w.can('assignTasks')) return;
    try {
      final people = await w.query('/channels/${task['channelId']}/members');
      if (!accepts(scope)) return;
      final choices = <Map<String, dynamic>>[
        for (final person in people['humans'] as List)
          {...Map<String, dynamic>.from(person), 'actorType': 'user'},
        for (final person in people['agents'] as List)
          {...Map<String, dynamic>.from(person), 'actorType': 'agent'},
      ];
      final selected = await scopedDialog<Map<String, dynamic>>(
        scope,
        (context) => SimpleDialog(
          title: Text(raftText(context, 'Assign task')),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  closeOwnedDialog(context, scope, <String, dynamic>{}),
              child: Text(raftText(context, 'Unassign')),
            ),
            for (final person in choices)
              SimpleDialogOption(
                onPressed: () => closeOwnedDialog(context, scope, person),
                child: Text(
                  '${person['displayName'] ?? person['name']} · ${person['actorType'] ?? person['type']}',
                ),
              ),
          ],
        ),
      );
      if (selected != null && accepts(scope)) {
        await command(
          'PATCH',
          '/tasks/${task['id']}/assignee',
          sourceScope: scope,
          data: {
            'assignee': selected.isEmpty
                ? null
                : {
                    'type': selected['actorType'] ?? selected['type'],
                    'id': selected['userId'] ?? selected['id'],
                  },
            if (task['revision'] is num) 'expectedRevision': task['revision'],
          },
        );
      }
    } catch (e) {
      fail(e, scope);
    }
  }

  Future<void> taskDetails(
    Map<String, dynamic> row, {
    String? sourceScope,
  }) async {
    final scope = sourceScope ?? authority;
    if (!accepts(scope)) return;
    var task = row;
    var history = <dynamic>[];
    String? historyNotice;
    try {
      if (row['channelId'] != null && row['taskNumber'] != null) {
        try {
          final full = await w.query(
            '/tasks/channel/${row['channelId']}/number/${row['taskNumber']}',
          );
          if (!accepts(scope)) return;
          task = Map<String, dynamic>.from(full['task']);
        } on RaftApiException catch (e) {
          if (!accepts(scope)) return;
          // Number lookup excludes deleted surfaces. History below resolves
          // includeDeleted and must freshly authorize this already-known ID
          // before exposing terminal cleanup; an inaccessible history fails.
          if (e.status != 404 ||
              w.channels.any((c) => c.id == row['channelId'])) {
            rethrow;
          }
        }
      }
      if (!accepts(scope)) return;
      try {
        final audit = await w.query('/tasks/${task['id']}/history');
        if (!accepts(scope)) return;
        history = audit['events'] as List;
      } on RaftApiException catch (e) {
        if (e.status != 409) rethrow;
        historyNotice = 'This legacy task has no recorded history.';
      }
    } catch (e) {
      fail(e, scope);
      return;
    }
    if (!accepts(scope)) return;
    final writable =
        w.server?.string('role') != 'guest' &&
        task['readOnlyReason'] == null &&
        w.channels.any(
          (c) => c.id == task['channelId'] && c.joined && !c.archived,
        );
    final manage = w.can('deleteAnyTask');
    // Absence from the local directory is not a declaration of deletion.
    // A fresh accessible task permits requesting only terminal cleanup;
    // the mounted server route rechecks deleted-channel and actor authority.
    final missingParent = !w.channels.any((c) => c.id == task['channelId']);
    final cleanup =
        missingParent &&
        task['readOnlyReason'] == null &&
        w.server?.string('role') != 'guest';
    final ownsTask =
        task['createdByType'] == 'user' &&
        task['createdById'] == w.client.user?.id;
    final result = await scopedDialog<String>(
      scope,
      (context) => AlertDialog(
        title: Text('task #${task['taskNumber'] ?? ''} · ${task['title']}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('${task['description'] ?? ''}'),
                const SizedBox(height: 16),
                Text(
                  raftFormat(context, 'Status: {status}', {
                    'status': raftText(
                      context,
                      raftTaskStatusLabel('${task['status']}'),
                    ),
                  }),
                ),
                Text(
                  raftFormat(context, 'Assignee: {name}', {
                    'name':
                        task['claimedByName'] ??
                        raftText(context, 'Unassigned'),
                  }),
                ),
                if (task['revision'] != null)
                  Text(
                    raftFormat(context, 'Revision: {revision}', {
                      'revision': task['revision'],
                    }),
                  ),
                const Divider(),
                Text(
                  raftText(context, 'History'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (historyNotice != null) Text(historyNotice),
                for (final event in history)
                  ListTile(
                    dense: true,
                    title: Text(
                      '${event['eventType']} · ${event['actorName'] ?? event['actorType']}',
                    ),
                    subtitle: Text('${event['createdAt']}'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (task['messageId'] is String)
            TextButton(
              onPressed: () => closeOwnedDialog(context, scope, 'discussion'),
              child: Text(raftText(context, 'Discussion')),
            ),
          if (writable && task['status'] != 'done')
            TextButton(
              onPressed: () => closeOwnedDialog(context, scope, 'assign'),
              child: Text(raftText(context, 'Assign')),
            ),
          if (writable && task['claimedById'] == null)
            TextButton(
              onPressed: () => closeOwnedDialog(context, scope, 'claim'),
              child: Text(raftText(context, 'Claim')),
            ),
          if (writable &&
              task['claimedByType'] == 'user' &&
              task['claimedById'] == w.client.user?.id)
            TextButton(
              onPressed: () => closeOwnedDialog(context, scope, 'unclaim'),
              child: Text(raftText(context, 'Release')),
            ),
          if (cleanup && manage)
            for (final status in ['done', 'closed'])
              TextButton(
                onPressed: () =>
                    closeOwnedDialog(context, scope, 'cleanup:$status'),
                child: Text(
                  raftText(
                    context,
                    status == 'done' ? 'Mark done' : 'Close task',
                  ),
                ),
              ),
          if ((writable || cleanup) && (manage || ownsTask))
            TextButton(
              onPressed: () => closeOwnedDialog(context, scope, 'delete'),
              child: Text(raftText(context, 'Delete')),
            ),
          TextButton(
            onPressed: () => closeOwnedDialog(context, scope),
            child: Text(raftText(context, 'Close')),
          ),
        ],
      ),
    );
    if (!accepts(scope)) return;
    if (result != null && result.startsWith('cleanup:') && cleanup && manage) {
      await command(
        'PATCH',
        '/tasks/${task['id']}/status',
        data: {'status': result.substring('cleanup:'.length)},
        sourceScope: scope,
      );
    } else if (result == 'assign') {
      await assignTask(task, sourceScope: scope);
    } else if (result == 'discussion') {
      await widget.onMessage(task['channelId'], task['messageId']);
    } else if (result == 'claim' || result == 'unclaim') {
      await command(
        'PATCH',
        '/tasks/${task['id']}/$result',
        sourceScope: scope,
      );
    } else if (result == 'delete' && mounted) {
      final confirmed = await scopedDialog<bool>(
        scope,
        (context) => AlertDialog(
          title: Text(raftText(context, 'Delete task?')),
          content: Text('${task['title']}'),
          actions: [
            TextButton(
              onPressed: () => closeOwnedDialog(context, scope, false),
              child: Text(raftText(context, 'Cancel')),
            ),
            RaftButton(
              label: 'Delete',
              onPressed: () => closeOwnedDialog(context, scope, true),
            ),
          ],
        ),
      );
      if (confirmed == true && accepts(scope)) {
        await command('DELETE', '/tasks/${task['id']}', sourceScope: scope);
      }
    }
  }
}
