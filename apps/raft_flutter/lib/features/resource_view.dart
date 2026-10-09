import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' hide RaftPanelHeaderRecipe;

import '../data/workspace_controller.dart';
import '../data/search_memory.dart';
import '../data/activity_follow_state.dart';
import 'search_home.dart';
import 'task_surface.dart';
import 'task_surface_controller.dart';
import 'resource_filters.dart';
import 'page_layout.dart';
import 'resource_cards.dart';
import 'task_selection_filter.dart';
import 'sender_avatar_projection.dart';
import 'resource_search.dart';
import '../platform/content_links.dart';

class ResourceView extends StatefulWidget {
  const ResourceView({
    super.key,
    required this.controller,
    required this.section,
    required this.onMessage,
    this.onBack,
    this.clock,
    this.initialQuery,
    this.initialSearchChannelId,
    this.initialSearchDeferUntilQuery = false,
    this.onSearchEntity,
    this.onSearchMessage,
    this.onSearchQueryCommitted,
    this.onActivityItem,
    this.onActivityCanonical,
    this.onActivityUnreadAccepted,
    this.onActivityWindowAccepted,
    this.searchMemory,
    this.restoreSearchState = true,
    this.channelId,
    this.onTask,
  });
  final WorkspaceController controller;
  final String? channelId;
  final void Function(Map<String, dynamic>, Future<void> Function())? onTask;
  final String section;
  final Future<void> Function(String, String?) onMessage;
  final VoidCallback? onBack;
  final DateTime Function()? clock;
  final String? initialQuery;

  /// Explicit channel search entry. Consumers key the view by entry identity;
  /// saved global search state is not restored over this initial filter.
  final String? initialSearchChannelId;

  /// ChatPanel channel-search entry waits for a committed nonempty query.
  /// Source MessageSearchPage defer=1; manual filter-only searches are unchanged.
  final bool initialSearchDeferUntilQuery;

  final SearchMemoryStore? searchMemory;
  final bool restoreSearchState;
  final Future<void> Function(SearchEntity)? onSearchEntity;

  /// Typed Source search hits retain thread and parent identities for the
  /// owning route. Embedded consumers may keep the ordinary message callback.
  final Future<void> Function(Map<String, dynamic>)? onSearchMessage;

  /// Source's committed query URL writer. IME composition stays in the input;
  /// embedded search consumers may omit URL ownership.
  final ValueChanged<String>? onSearchQueryCommitted;
  final Future<void> Function(Map<String, dynamic>)? onActivityItem;

  /// Mounted Source master/detail arbitration: a second activation navigates
  /// to the canonical route and cancels the pending 220 ms content-slot open.
  /// Custom embedded consumers without this callback keep immediate onOpen.
  final Future<void> Function(Map<String, dynamic>)? onActivityCanonical;

  /// Server-wide Activity total from an accepted window, independent of filter.
  /// Null retires the projection after an explicit authority denial.
  final ValueChanged<int?>? onActivityUnreadAccepted;

  /// Accepted Activity response for an independent scoped unread data owner.
  /// Includes real row frontiers; null retires it after an authority denial.
  final ValueChanged<Map?>? onActivityWindowAccepted;
  @override
  State<ResourceView> createState() => _ResourceViewState();
}

class _ResourceViewState extends State<ResourceView> {
  final query = TextEditingController();
  String? lastPublishedQuery;
  TextEditingValue lastSearchEditingValue = TextEditingValue.empty;
  bool adoptingSearchQuery = false;
  Timer? searchDebounce, activityActivation;
  String? selectedSearchKey;
  List<Map<String, dynamic>> searchPeople = [],
      searchAgents = [],
      searchComputers = [];
  final queryFocus = FocusNode();
  late final ownedSearchMemory = SearchMemoryStore(clock: widget.clock);
  SearchMemoryStore get searchMemory =>
      widget.searchMemory ?? ownedSearchMemory;
  String? memoryReadyKey, restoringSenderKey;
  bool initialSearchUnavailable = false;
  SearchMemoryScope? get memoryScope {
    final server = w.server?.id, principal = w.client.user?.id;
    return widget.section == 'search' && server != null && principal != null
        ? SearchMemoryScope(w.client.origin, server, principal)
        : null;
  }

  SearchStateSnapshot get currentSearchState => SearchStateSnapshot(
    query: query.text,
    channelId: advanced.channelId,
    senderKey: restoringSenderKey ?? advanced.sender?.key,
    scopes: advanced.scopes.toList(),
    range: advanced.timeRange,
    sort: advanced.searchSort,
  );
  void saveSearchState() {
    final personal = memoryScope;
    if (personal != null && memoryReadyKey == personal.key) {
      searchMemory.saveState(personal, currentSearchState);
    }
  }

  Future<void> activateSearchMemory({required bool restore}) async {
    final personal = memoryScope, scope = authority;
    if (personal == null) return;
    final before = jsonEncode(currentSearchState.toJson());
    final data = await searchMemory.load(personal);
    if (!accepts(scope) || memoryScope?.key != personal.key) return;
    final untouched = before == jsonEncode(currentSearchState.toJson());
    setState(() {
      memoryReadyKey = personal.key;
      if (restore &&
          untouched &&
          widget.initialQuery == null &&
          widget.initialSearchChannelId == null) {
        final snapshot = data.state;
        query.text = snapshot.query;
        advanced.scopes.addAll(snapshot.scopes);
        advanced.timeRange = snapshot.range;
        advanced.searchSort = snapshot.sort;
        advanced.channelId =
            [...w.channels, ...w.dms].any((c) => c.id == snapshot.channelId)
            ? snapshot.channelId
            : null;
        restoringSenderKey = snapshot.senderKey;
        resolveRestoredSender();
      }
    });
    saveSearchState();
    if (restore &&
        untouched &&
        widget.initialQuery == null &&
        widget.initialSearchChannelId == null) {
      lastPublishedQuery = query.text.trim();
      widget.onSearchQueryCommitted?.call(lastPublishedQuery!);
    }
    if (restore && untouched) await load();
  }

  void resolveRestoredSender() {
    if (restoringSenderKey == null ||
        catalogScope != authority ||
        senders.isEmpty) {
      return;
    }
    advanced.selectSender(
      senders.where((s) => s.key == restoringSenderKey).firstOrNull,
    );
    restoringSenderKey = null;
  }

  List<SearchEntity> get authorizedSearchCatalog => searchEntities(
    '',
    includeAll: true,
    channels: w.channels.map((c) => c.json).toList(),
    computers: searchComputers,
    agents: searchAgents,
    people: searchPeople,
    principal: w.client.user?.id,
  );
  List<SearchEntity> get frequentEntities {
    final personal = memoryScope;
    return personal == null || memoryReadyKey != personal.key
        ? []
        : frequentSearchEntities(
            catalog: authorizedSearchCatalog,
            usage: searchMemory.current(personal).usage,
            principal: w.client.user?.id,
            now: widget.clock?.call() ?? DateTime.now(),
            hiddenDmIds: (w.sidebarOrder['hiddenDmIds'] as List? ?? const [])
                .whereType<String>()
                .toSet(),
            dms: w.dms.map((c) => c.json).toList(),
          );
  }

  void rememberSearchOpen(
    String scope, {
    SearchEntity? entity,
    String? queryText,
  }) {
    final personal = memoryScope;
    if (personal == null || !accepts(scope)) return;
    searchMemory.rememberQuery(personal, queryText ?? query.text);
    if (entity != null) {
      searchMemory.recordOpen(personal, searchUsageEntityKey(entity));
    }
  }

  Widget searchHome(String scope) {
    final personal = memoryScope;
    final history = personal == null || memoryReadyKey != personal.key
        ? const <String>[]
        : searchMemory.current(personal).history;
    return ResourceSearchHome(
      key: ValueKey('search-home-$scope'),
      history: history,
      frequent: frequentEntities,
      origin: w.client.origin,
      onQuery: (text) {
        if (!accepts(scope)) return;
        query.text = text;
        query.selection = TextSelection.collapsed(offset: text.length);
        queryFocus.requestFocus();
        searchChanged(text);
      },
      onRemove: (text) {
        if (personal != null && accepts(scope)) {
          setState(() => searchMemory.removeQuery(personal, text));
        }
      },
      onClear: () {
        if (personal != null && accepts(scope)) {
          setState(() => searchMemory.clearHistory(personal));
        }
      },
      onEntity: (entity) => openSearchEntity(entity, scope),
    );
  }

  List<Map<String, dynamic>> rows = [];
  final activityFollowState = ActivityFollowState();
  bool loading = true;
  String? error;
  String filter = 'all';
  ResourceFilters advanced = ResourceFilters();
  List<ResourceSender> senders = [];
  List<Map<String, dynamic>> activityGroups = [];
  String? catalogScope;
  int catalogRequest = 0;
  String taskLayout = 'list';
  bool initializedTaskLayout = false;
  bool extraFilters = false;
  int? totalCount;
  int? totalUnreadCount;
  final collapsedTaskStatuses = <String>{'done', 'closed'};
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
  String get taskPath => widget.channelId == null
      ? '/tasks/server'
      : '/tasks/channel/${widget.channelId}';
  bool get acceptsTaskChannel =>
      widget.channelId == null ||
      [...w.channels, ...w.dms].any(
        (channel) =>
            channel.id == widget.channelId &&
            w.can('viewChannel', resource: channel),
      );

  String? acceptedAuthority;
  int authorityRevision = 0;
  final Set<ModalRoute<dynamic>> dialogs = {};
  final Set<MenuController> filterMenus = {};
  final dragFeedbackRevision = ValueNotifier<int>(0);
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
      widget.channelId,
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
    activityFollowState.clear();
    activityActivation?.cancel();
    dragFeedbackRevision.value++;
    rows = [];
    lanes.clear();
    laneCursors.clear();
    laneBusy.clear();
    cursor = null;
    hasMore = false;
    activityGroups = [];
    totalCount = null;
    totalUnreadCount = null;
    taskAdvanced.clear();
  }

  void resetAdvanced() {
    advanced = ResourceFilters();
    senders = [];
    searchPeople = [];
    searchAgents = [];
    searchComputers = [];
    selectedSearchKey = null;
    restoringSenderKey = null;
    memoryReadyKey = null;
    initialSearchUnavailable = false;
    searchDebounce?.cancel();
    catalogScope = null;
    ++catalogRequest;
  }

  void closeDialogs() {
    for (final menu in filterMenus.toList()) {
      if (menu.isOpen) menu.close();
    }
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
      if (widget.section == 'activity') {
        widget.onActivityUnreadAccepted?.call(null);
        widget.onActivityWindowAccepted?.call(null);
      }
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
    unawaited(activateSearchMemory(restore: false));
    load();
  }

  Future<V?> scopedDialog<V>(
    String scope,
    Widget Function(BuildContext) builder, {
    bool sourceModal = false,
  }) async {
    if (!accepts(scope)) return null;
    ModalRoute<dynamic>? owned;
    Widget buildOwned(BuildContext context) {
      owned = ModalRoute.of(context);
      if (owned != null) dialogs.add(owned!);
      if (!accepts(scope)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (owned?.isActive == true) owned?.navigator?.removeRoute(owned!);
        });
        return const SizedBox.shrink();
      }
      return builder(context);
    }

    try {
      return sourceModal
          ? await showRaftModal<V>(context, builder: buildOwned)
          : await showDialog<V>(context: context, builder: buildOwned);
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
      if (['search', 'saved'].contains(widget.section) &&
          (event.name.startsWith('agent:') ||
              event.name.startsWith('machine:') ||
              event.name.startsWith('server:member'))) {
        final scope = authority;
        ++catalogRequest;
        catalogScope = null;
        setState(() {
          searchPeople = [];
          searchAgents = [];
          searchComputers = [];
          senders = [];
          advanced.sender = null;
          selectedSearchKey = null;
        });
        unawaited(loadSenders(scope));
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
    query.text = widget.initialQuery ?? '';
    lastPublishedQuery = widget.initialQuery ?? '';
    lastSearchEditingValue = query.value;
    query.addListener(searchCompositionCommitted);
    if (widget.section == 'search' && widget.initialSearchChannelId != null) {
      final channel = [
        ...w.channels,
        ...w.dms,
        if (w.channel != null) w.channel!,
      ].where((c) => c.id == widget.initialSearchChannelId).firstOrNull;
      if (channel != null && w.can('viewChannel', resource: channel)) {
        advanced.channelId = channel.id;
      } else {
        initialSearchUnavailable = true;
      }
    }
    w.addListener(authorityChanged);
    subscribeEvents();
    unawaited(activateSearchMemory(restore: widget.restoreSearchState));
    load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initializedTaskLayout && widget.section == 'tasks') {
      initializedTaskLayout = true;
      final next =
          MediaQuery.sizeOf(context).width >=
              RaftLayoutMetrics.desktopBreakpoint
          ? 'board'
          : 'list';
      if (taskLayout != next) {
        taskLayout = next;
        load();
      }
    }
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
    if (widget.section == 'search' &&
        oldWidget.initialQuery != widget.initialQuery &&
        (widget.initialQuery ?? '') != lastPublishedQuery) {
      searchDebounce?.cancel();
      requestGeneration++;
      final next = widget.initialQuery ?? '';
      adoptingSearchQuery = true;
      query.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      adoptingSearchQuery = false;
      lastPublishedQuery = next;
      rows = [];
      selectedSearchKey = null;
      error = null;
      hasMore = false;
      saveSearchState();
      unawaited(load());
    }
  }

  @override
  void dispose() {
    dragFeedbackRevision.value++;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => dragFeedbackRevision.dispose(),
    );
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
    searchDebounce?.cancel();
    activityActivation?.cancel();
    queryFocus.dispose();
    query.dispose();
    events?.cancel();
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    final acceptActivityWindow = widget.onActivityWindowAccepted;
    saveSearchState();
    final request = ++requestGeneration, scope = authority;
    if (widget.section == 'tasks' && !acceptsTaskChannel) {
      if (accepts(scope, request)) {
        setState(() {
          clearRows();
          loading = false;
          error = 'This channel is not available.';
        });
      }
      return;
    }
    if (widget.section == 'search' && initialSearchUnavailable) {
      setState(() {
        clearRows();
        loading = false;
        error = 'This channel is no longer available.';
      });
      return;
    }
    if (widget.section == 'search' &&
        widget.initialSearchDeferUntilQuery &&
        query.text.trim().isEmpty) {
      setState(() {
        clearRows();
        loading = false;
        error = null;
      });
      return;
    }
    if (['search', 'tasks', 'activity', 'saved'].contains(widget.section)) {
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
      if (!append &&
          ['search', 'saved', 'activity'].contains(widget.section) &&
          !(widget.section == 'activity' && activityFollowState.busy)) {
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
              taskPath,
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
          dragFeedbackRevision.value++;
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
        'tasks' => taskPath,
        'agents' => '/agents',
        'computers' => '/servers/${w.server!.id}/machines',
        'members' => '/servers/${w.server!.id}/members',
        _ => throw const RaftApiException('This page is not available.'),
      };
      var value = await w.query(
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
      if (!accepts(scope, request)) return;
      if (widget.section == 'activity' && value is Map) {
        value = activityFollowState.window(value);
      }
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
          dragFeedbackRevision.value++;
          if (value is Map) {
            totalCount = (value['total'] ?? value['totalCount']) as int?;
            totalUnreadCount = value['totalUnreadCount'] as int?;
          }
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
        if (widget.section == 'activity' &&
            value is Map &&
            value['totalUnreadCount'] is num) {
          widget.onActivityUnreadAccepted?.call(
            (value['totalUnreadCount'] as num).toInt(),
          );
        }
        if (widget.section == 'activity' && value is Map) {
          acceptActivityWindow?.call(value);
        }
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
    final t = RaftTokens.of(context);
    // ThreadsInbox mounts ActivityInboxPanel with `theme-brutal:!border-l`.
    final activityEdge = widget.section == 'activity';
    return Container(
      decoration: activityEdge
          ? BoxDecoration(
              color: t.brutal ? t.panel : t.sidebar,
              border: Border(
                left: BorderSide(
                  color: t.brutal ? t.colors['color-black']! : t.line,
                ),
              ),
            )
          : null,
      child: widget.section == 'tasks'
          ? DefaultTextStyle.merge(
              style: RaftTaskSectionRecipe(t).documentStyle,
              child: buildBody(context),
            )
          : buildBody(context),
    );
  }

  Widget buildBody(BuildContext context) {
    final scope = authority;
    return Column(
      children: [
        if (widget.channelId == null)
          widget.section == 'search'
              ? searchHeader(scope)
              : resourceHeader(scope),
        if (widget.section != 'search' &&
            widget.section != 'activity' &&
            (widget.section != 'tasks' || extraFilters) &&
            (widget.section != 'saved' || extraFilters))
          Padding(
            padding: RaftLayoutMetrics.toolbarInset,
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
                        prefixIcon: const RaftIcon(RaftGlyph.search),
                      ),
                      onSubmitted: (_) => load(),
                    ),
                  )
                else if (widget.section == 'activity')
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: RaftSegmentedControl<String>(
                        style: RaftSegmentedStyle.tabs,
                        value: ['all', 'unread', 'mentions'].contains(filter)
                            ? filter
                            : '',
                        label: raftText(context, 'Activity filters'),
                        items: [
                          for (final value in ['all', 'unread', 'mentions'])
                            RaftSegmentedOption(
                              value: value,
                              label: raftText(context, switch (value) {
                                'all' => 'All',
                                'unread' => 'Unread',
                                _ => 'Mentions',
                              }),
                            ),
                        ],
                        onChanged: (value) {
                          if (accepts(scope) && filter != value) {
                            filter = value;
                            load();
                          }
                        },
                      ),
                    ),
                  )
                else if (widget.section == 'tasks')
                  Expanded(
                    child: RaftSelectField<String>(
                      value: filter,
                      label: 'Task status',
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
                                      s == 'all'
                                          ? 'All'
                                          : raftTaskStatusLabel(s),
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
                    icon: RaftIcon(
                      taskLayout == 'board'
                          ? RaftGlyph.layoutList
                          : RaftGlyph.columns3,
                      size: 12,
                    ),
                    onPressed: () {
                      taskLayout = taskLayout == 'board' ? 'list' : 'board';
                      load();
                    },
                  ),
                if (widget.section == 'tasks')
                  IconButton(
                    tooltip: raftText(context, 'Create task'),
                    onPressed: w.server?.string('role') == 'guest'
                        ? null
                        : () => createTask(sourceScope: scope),
                    icon: const RaftIcon(RaftGlyph.plus, size: 12),
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
        if (widget.section == 'activity') activityToolbar(scope),
        if (widget.section == 'search') searchFilters(),
        if (['saved', 'activity'].contains(widget.section) && extraFilters)
          advancedFilters(),
        if (widget.section == 'tasks') taskFilters(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              raftText(context, error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: loading && rows.isEmpty
              ? Center(child: CircularProgressIndicator())
              : widget.section == 'search' &&
                    query.text.trim().isEmpty &&
                    (!advanced.hasSearchFilter ||
                        widget.initialSearchDeferUntilQuery)
              ? searchHome(scope)
              : widget.section == 'search'
              ? ResourceSearchResults(
                  query: query.text,
                  rows: rows,
                  entities: currentSearchEntities,
                  origin: w.client.origin,
                  agents: searchAgents,
                  members: searchPeople,
                  currentUser: w.client.user?.json,
                  plan: w.server?.string('plan', 'free') ?? 'free',
                  now: widget.clock?.call() ?? DateTime.now(),
                  selectedKey:
                      selectedSearchKey ??
                      currentSearchEntities.firstOrNull?.key,
                  onMessage: (row) => openSearchMessage(row, scope),
                  onEntity: (entity) => openSearchEntity(entity, scope),
                  hasMore: hasMore,
                  onMore: () => load(append: true),
                )
              : widget.section == 'tasks' && taskLayout == 'board'
              ? taskBoard()
              : widget.section == 'tasks' && rows.isNotEmpty
              ? groupedTasks()
              : rows.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    primary: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: RaftEmptyState(
                        title: widget.section == 'search'
                            ? 'Search your workspace'
                            : 'No ${widget.section}',
                        detail: widget.section == 'search'
                            ? 'Enter words to find messages.'
                            : 'There are no items in this view.',
                      ),
                    ),
                  ),
                )
              : widget.section == 'activity' && advanced.groupByChannel
              ? groupedActivity()
              : Material(
                  color: RaftTokens.of(context).brutal
                      ? RaftTokens.of(context).panel
                      : RaftTokens.of(context).sidebar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    // SavedPanel loads the next page when its sentinel comes
                    // within `rootMargin: 240px` of the scroller.
                    scrollCacheExtent: widget.section == 'saved'
                        ? const ScrollCacheExtent.pixels(240)
                        : null,
                    itemCount: visibleRows.length + (hasMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: RaftConversationCardRecipe.gap),
                    itemBuilder: (context, index) => index == visibleRows.length
                        ? widget.section == 'saved'
                              ? savedSentinel()
                              : TextButton(
                                  onPressed: () => load(append: true),
                                  child: Text(raftText(context, 'Load more')),
                                )
                        : item(visibleRows[index]),
                  ),
                ),
        ),
      ],
    );
  }

  List<SearchEntity> get currentSearchEntities => searchEntities(
    query.text,
    channels: [...w.channels, ...w.dms].map((c) => c.json).toList(),
    computers: searchComputers,
    agents: searchAgents,
    people: searchPeople,
    principal: w.client.user?.id,
  );

  Future<void> openSearchMessage(Map<String, dynamic> row, String scope) async {
    if (!accepts(scope) || !rows.any((r) => identical(r, row))) return;
    final channel = row['channelId'], message = row['id'];
    if (channel is! String || message is! String) return;
    setState(() => selectedSearchKey = 'message:$message');
    final committed = query.text;
    rememberSearchOpen(scope, queryText: committed);
    if (widget.onSearchMessage case final open?) {
      await open(row);
    } else {
      await widget.onMessage(channel, message);
    }
  }

  Future<void> openSearchEntity(SearchEntity entity, String scope) async {
    if (!accepts(scope) ||
        !([
          ...currentSearchEntities,
          if (query.text.trim().isEmpty) ...frequentEntities,
        ].any((e) => e.key == entity.key))) {
      return;
    }
    setState(() => selectedSearchKey = entity.key);
    final committed = query.text;
    if (entity.kind == 'channel') {
      rememberSearchOpen(scope, entity: entity, queryText: committed);
      await widget.onMessage(entity.id, null);
    } else if (entity.kind == 'computer') {
      if (w.can('viewMachines')) await widget.onSearchEntity?.call(entity);
    } else {
      if (!w.can(entity.kind == 'agent' ? 'viewAgents' : 'viewMembers')) return;
      if (widget.onSearchEntity != null) {
        rememberSearchOpen(scope, entity: entity, queryText: committed);
        await widget.onSearchEntity!(entity);
        return;
      }
      try {
        final result = await w.client.post(
          '/channels/dm',
          data: {entity.kind == 'agent' ? 'agentId' : 'userId': entity.id},
        );
        if (!accepts(scope)) return;
        if (result is Map && result['id'] is String) {
          rememberSearchOpen(scope, entity: entity, queryText: committed);
          await widget.onMessage(result['id'], null);
        }
      } catch (e) {
        fail(e, scope);
      }
    }
  }

  // TextField.onChanged omits an IME commit whose text is unchanged. Source's
  // composition-end effect still writes the committed query in that case.
  void searchCompositionCommitted() {
    final previous = lastSearchEditingValue, next = query.value;
    lastSearchEditingValue = next;
    if (!adoptingSearchQuery &&
        previous.text == next.text &&
        previous.composing.isValid &&
        !previous.composing.isCollapsed &&
        (!next.composing.isValid || next.composing.isCollapsed)) {
      searchChanged(next.text);
    }
  }

  void searchChanged(String text) {
    searchDebounce?.cancel();
    requestGeneration++;
    setState(() {
      rows = [];
      selectedSearchKey = null;
      hasMore = false;
    });
    if (query.value.composing.isValid && !query.value.composing.isCollapsed) {
      return;
    }
    saveSearchState();
    lastPublishedQuery = text.trim();
    widget.onSearchQueryCommitted?.call(lastPublishedQuery!);
    final scope = authority;
    searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (accepts(scope)) load();
    });
  }

  Widget searchHeader(String scope) {
    final t = RaftTokens.of(context),
        mobile =
            MediaQuery.sizeOf(context).width <
            RaftLayoutMetrics.desktopBreakpoint;
    final recipe = RaftPanelHeaderRecipe(
      t,
      viewportHeight: MediaQuery.sizeOf(context).height,
      mobile: mobile,
    );
    return Container(
      height: recipe.height,
      padding: EdgeInsets.symmetric(horizontal: RaftLayoutMetrics.panelInset),
      decoration: BoxDecoration(
        color: recipe.background,
        border: Border(bottom: recipe.border),
      ),
      child: Row(
        children: [
          if (mobile) ...[
            RaftPanelBackAction(onPressed: widget.onBack ?? () {}),
            const SizedBox(width: RaftLayoutMetrics.panelGap),
          ],
          Container(
            width: RaftLayoutMetrics.panelIcon,
            height: RaftLayoutMetrics.panelIcon,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: recipe.iconBackground,
              border: Border.all(color: t.line, width: t.border),
            ),
            child: const RaftIcon(RaftGlyph.search, size: 18),
          ),
          const SizedBox(width: RaftLayoutMetrics.panelGap),
          Expanded(
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final keys = [
                  ...(query.text.trim().isEmpty
                          ? frequentEntities
                          : currentSearchEntities)
                      .map((e) => e.key),
                  ...rows.map((r) => 'message:${r['id']}'),
                ];
                if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                    event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  if (keys.isEmpty) return KeyEventResult.ignored;
                  final index = keys.indexOf(selectedSearchKey ?? keys.first),
                      step = event.logicalKey == LogicalKeyboardKey.arrowDown
                          ? 1
                          : -1;
                  setState(
                    () => selectedSearchKey =
                        keys[(index + step).clamp(0, keys.length - 1)],
                  );
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  widget.onBack?.call();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: RaftSearchInput(
                controller: query,
                focusNode: queryFocus,
                hint: raftText(context, 'Search messages'),
                clearLabel: raftText(context, 'Clear search'),
                showEscape: !mobile,
                onClear: () {
                  query.clear();
                  searchChanged('');
                },
                onChanged: searchChanged,
                onSubmitted: (_) {
                  searchDebounce?.cancel();
                  final selected =
                      selectedSearchKey ??
                      (query.text.trim().isEmpty
                              ? frequentEntities
                              : currentSearchEntities)
                          .firstOrNull
                          ?.key ??
                      (rows.isEmpty ? null : 'message:${rows.first['id']}');
                  final entity =
                      (query.text.trim().isEmpty
                              ? frequentEntities
                              : currentSearchEntities)
                          .where((e) => e.key == selected)
                          .firstOrNull;
                  final row = rows
                      .where((r) => 'message:${r['id']}' == selected)
                      .firstOrNull;
                  if (entity != null) {
                    openSearchEntity(entity, scope);
                  } else if (row != null) {
                    openSearchMessage(row, scope);
                  } else {
                    load();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget searchFilters() {
    final scope = authority;
    final senderOptions = {
      for (final sender in senders)
        sender.key:
            '${sender.label} · ${raftText(context, sender.type == 'user' ? 'Human' : 'Agent')}',
    };
    Widget picker(
      String field,
      String tooltip,
      Map<String, String> options,
      Set<String> selected,
      void Function(String) toggle,
      VoidCallback clear, {
      String? label,
      RaftGlyph? glyph,
      bool single = false,
    }) => TaskSelectionFilter(
      key: ValueKey('$scope:$field'),
      field: field,
      tooltip: tooltip,
      label: label,
      glyph: glyph,
      options: options,
      selection: selected,
      valid: () => accepts(scope),
      closeOnSelect: single,
      picker: true,
      combobox: field == 'Channel',
      onToggle: (key) {
        if (!accepts(scope)) return;
        toggle(key);
        load();
      },
      onClear: () {
        if (!accepts(scope)) return;
        clear();
        load();
      },
      beforeOpen: (menu) {
        for (final other in filterMenus) {
          if (!identical(menu, other) && other.isOpen) other.close();
        }
      },
      onController: (menu, add) {
        add ? filterMenus.add(menu) : filterMenus.remove(menu);
      },
    );
    Widget dropdown(
      String title,
      String label,
      Map<String, String> choices,
      void Function(String) changed,
    ) => RaftDropdownMenu(
      key: ValueKey('$scope:$title'),
      tooltip: title,
      label: label,
      glyph: title == 'Search date range'
          ? RaftGlyph.calendarRange
          : RaftGlyph.arrowDownUp,
      trailingGlyph: RaftGlyph.chevronDown,
      triggerStyle: RaftDropdownTriggerStyle.picker,
      minimumTargetSize: RaftTokens.of(context).brutal
          ? RaftMetrics.buttonMd
          : RaftMetrics.buttonSm,
      // activeFilterClass when the value differs from the default.
      selected: title == 'Search date range'
          ? advanced.timeRange != 'any'
          : advanced.searchSort != 'relevance',
      enabled: title != 'Sort search results' || query.text.trim().isNotEmpty,
      entries: [
        for (final entry in choices.entries)
          RaftMenuEntry(
            label: raftText(context, entry.value),
            onPressed: () {
              if (accepts(scope)) {
                changed(entry.key);
                load();
              }
            },
          ),
      ],
    );
    // MessageSearchPage filters row: `px-4 py-3 border-b theme-brutal:border-b-2`.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: RaftTokens.of(context).line,
            width: RaftTokens.of(context).border,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            picker(
              'From',
              'Filter by sender',
              senderOptions,
              {if (advanced.sender != null) advanced.sender!.key},
              (key) => advanced.selectSender(
                senders.where((s) => s.key == key).firstOrNull,
              ),
              () => advanced.selectSender(null),
              single: true,
              label: advanced.sender == null
                  ? raftText(context, 'From')
                  : '${raftText(context, 'From')}: ${advanced.sender!.label}',
              glyph: RaftGlyph.userCircle2,
            ),
            picker(
              'Scope',
              'Search scope',
              const {
                'mentioned': 'Mentions me',
                'humans': 'Humans',
                'agents': 'Agents',
              },
              advanced.scopes,
              advanced.toggleScope,
              advanced.scopes.clear,
              glyph: RaftGlyph.atSign,
            ),
            picker(
              'Channel',
              'Filter by channel',
              {
                for (final c in [
                  ...w.channels,
                  ...w.dms,
                ].where((c) => c.type != 'thread'))
                  c.id: '${c.type == 'dm' ? '@' : '#'}${c.name}',
              },
              {if (advanced.channelId != null) advanced.channelId!},
              (id) => advanced.channelId = id,
              () => advanced.channelId = null,
              single: true,
              glyph: RaftGlyph.hash,
            ),
            dropdown(
              'Search date range',
              const {
                'any': 'Any Time',
                'today': 'Today',
                '7d': 'Last 7 Days',
                '30d': 'Last 30 Days',
              }[advanced.timeRange]!,
              const {
                'any': 'Any Time',
                'today': 'Today',
                '7d': 'Last 7 Days',
                '30d': 'Last 30 Days',
              },
              (value) => advanced.timeRange = value,
            ),
            dropdown(
              'Sort search results',
              advanced.searchSort == 'recent' ? 'Recent' : 'Relevant',
              const {'relevance': 'Relevant', 'recent': 'Recent'},
              (value) => advanced.searchSort = value,
            ),
            if (advanced.hasSearchFilter)
              // Button ghost xs "Clear All".
              RaftTextButton(
                label: 'Clear All',
                variant: RaftControlVariant.ghost,
                visualHeight: RaftMetrics.buttonXs,
                minimumTargetSize: RaftMetrics.buttonXs,
                onPressed: () {
                  if (accepts(scope)) {
                    final sort = advanced.searchSort;
                    advanced = ResourceFilters()..searchSort = sort;
                    load();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget activityToolbar(String scope) {
    final t = RaftTokens.of(context);
    // ThreadsInbox `inbox-toolbar`: `flex h-[54px] items-center
    // justify-between gap-3 px-4 border-b theme-brutal:border-b-2`.
    return Container(
      height: RaftResourceMetrics.activityToolbarHeight,
      padding: RaftResourceMetrics.activityToolbarInset,
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(
          bottom: BorderSide(color: t.line, width: t.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              primary: false,
              scrollDirection: Axis.horizontal,
              child: RaftSegmentedControl<String>(
                // ThreadsInbox uses the raft-ui SegmentedControl recipe,
                // rather than the older 11px tab-button presentation.
                style: RaftSegmentedStyle.buttons,
                value: ['all', 'unread', 'mentions'].contains(filter)
                    ? filter
                    : '',
                visualHeight: RaftMetrics.buttonMd,
                minimumTargetSize: RaftMetrics.buttonMd,
                label: raftText(context, 'Activity filters'),
                items: [
                  for (final value in ['all', 'unread', 'mentions'])
                    RaftSegmentedOption(
                      value: value,
                      label: raftText(context, switch (value) {
                        'all' => 'All',
                        'unread' => 'Unread',
                        _ => 'Mentions',
                      }),
                    ),
                ],
                onChanged: (value) {
                  if (accepts(scope) && filter != value) {
                    filter = value;
                    load();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: RaftResourceMetrics.activityToolbarGap),
          // Button sm outline `h-8 px-2 text-xs font-bold`.
          RaftInteractive(
            semanticLabel: raftText(context, 'Mark all read'),
            onPressed: () =>
                command('POST', '/channels/inbox/read-all', sourceScope: scope),
            builder: (context, state) => RaftRecipeBox(
              style: RaftButtonRecipe.resolve(
                theme: t.recipeTheme,
                variant: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.sm,
                states: t.recipeStates(
                  hovered: state.hovered,
                  pressed: state.pressed,
                  focusVisible: state.focusVisible,
                ),
                tokens: t.recipeTokens,
              ).root,
              tokens: t.recipeTokens,
              height: RaftResourceMetrics.activityToolbarActionHeight,
              padding: RaftResourceMetrics.activityToolbarActionInset,
              alignment: Alignment.center,
              child: RaftCssText(
                raftText(context, 'Mark all read'),
                style: RaftResourceMetrics.activityToolbarActionLabel,
              ),
            ),
          ),
          if (extraFilters)
            PopupMenuButton<String>(
              tooltip: raftText(context, 'Activity actions'),
              onSelected: (value) {
                if (accepts(scope)) {
                  filter = value;
                  load();
                }
              },
              itemBuilder: (_) => [
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
    );
  }

  Widget resourceHeader(String scope) {
    final mobile =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    final count = totalCount ?? rows.length;
    return RaftPageHeader(
      title: raftText(context, switch (widget.section) {
        'tasks' => 'Tasks',
        'saved' => 'Saved',
        'activity' => 'Activity',
        'search' => 'Search',
        _ => widget.section,
      }),
      subtitle: switch (widget.section) {
        'tasks' => '$count ${raftText(context, 'channel tasks')}',
        'saved' =>
          '$count ${raftText(context, count == 1 ? 'saved item' : 'saved items')}',
        'activity' =>
          '$count ${raftText(context, 'active')}${(totalUnreadCount ?? 0) > 0 ? ' · $totalUnreadCount ${raftText(context, 'unread')}' : ''}',
        _ => null,
      },
      height: raftPageHeaderHeight(context),
      mobile: mobile,
      variant: widget.section == 'tasks'
          ? RaftPanelHeaderVariant.tasks
          : RaftPanelHeaderVariant.canonical,
      icon: RaftIcon(switch (widget.section) {
        'tasks' => RaftGlyph.checkSquare,
        'saved' => RaftGlyph.bookmark,
        'activity' => RaftGlyph.activity,
        _ => RaftGlyph.search,
      }),
      // TasksPanel's server-mode header has no back button or actions; the
      // Saved/Activity PanelHeaders only carry onMobileBack.
      leading: mobile && widget.section != 'tasks'
          ? RaftPanelBackAction(onPressed: widget.onBack ?? () {})
          : null,
    );
  }

  void activateActivity(Map<String, dynamic> row, String scope, int detail) {
    if (!accepts(scope)) return;
    activityActivation?.cancel();
    final canonical = widget.onActivityCanonical;
    if (canonical == null) {
      unawaited(openConversation(row, scope));
      return;
    }
    if (detail >= 2) {
      unawaited(canonical(Map<String, dynamic>.from(row)));
      return;
    }
    final revision = w.navigationRevision;
    activityActivation = Timer(const Duration(milliseconds: 220), () {
      activityActivation = null;
      if (accepts(scope) && revision == w.navigationRevision) {
        unawaited(openConversation(row, scope));
      }
    });
  }

  Future<void> openConversation(Map<String, dynamic> row, String scope) async {
    if (!accepts(scope)) return;
    if (widget.section == 'activity' && widget.onActivityItem != null) {
      await widget.onActivityItem!(Map<String, dynamic>.from(row));
      return;
    }
    final id = row['parentChannelId'] ?? row['channelId'];
    if (id is! String) return;
    final unread = (row['unreadCount'] as num? ?? 0) > 0;
    final message = widget.section == 'saved'
        ? row['messageId']
        : row['firstMentionMessageId'] ??
              (unread ? row['firstUnreadMessageId'] : null) ??
              row['latestActivityMessageId'] ??
              row['lastMessageId'];
    await widget.onMessage(id, message as String?);
  }

  String relativeTime(dynamic value) => resourceRelativeTime(
    value is String ? value : null,
    now: widget.clock?.call(),
    chinese: Localizations.localeOf(context).languageCode == 'zh',
  );

  Widget savedCard(Map<String, dynamic> row, String scope) {
    final recipe = RaftConversationCardRecipe(
      RaftTokens.of(context),
      saved: true,
    );
    final thread = row['channelType'] == 'thread';
    final dm = (thread ? row['parentChannelType'] : row['channelType']) == 'dm';
    final senderId = '${row['senderId'] ?? ''}';
    final agent = row['senderType'] == 'agent'
        ? searchAgents.where((a) => a['id'] == senderId).firstOrNull
        : null;
    final person = row['senderType'] == 'user'
        ? searchPeople
              .where((m) => (m['userId'] ?? m['id']) == senderId)
              .firstOrNull
        : null;
    final sender =
        '${agent?['displayName'] ?? agent?['name'] ?? person?['displayName'] ?? person?['name'] ?? row['senderName'] ?? ''}';
    final projection = projectSenderAvatar(
      origin: w.client.origin,
      senderId: senderId,
      senderType: row['senderType'] == 'external_projection'
          ? 'external_projection'
          : agent != null
          ? 'agent'
          : 'user',
      agents: searchAgents,
      members: searchPeople,
      currentUser: w.client.user?.json,
      externalAuthor: {'avatarUrl': row['senderAvatarUrl']},
      requestSize: 14,
    );
    final label = dm
        ? '@$sender'
        : '#${thread ? row['parentChannelName'] : row['channelName']}';
    // SavedItem (packages/web/src/components/saved/SavedPanel.tsx): meta row
    // `flex items-center gap-2 mb-1 text-xs`, content `text-sm line-clamp-3`,
    // PanelToggleAction on the right (`ml-auto shrink-0 self-center`, gap-3).
    return RaftConversationCard(
      key: ValueKey('saved-${row['messageId']}'),
      saved: true,
      onOpen: () => openConversation(row, scope),
      onContextMenu: () => savedMenu(row, scope),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftSavedItemMeta(
                  channelLabel: label,
                  thread: thread,
                  sender: sender,
                  time: relativeTime(row['createdAt']),
                  avatar: RaftAvatarSlot(
                    name: sender,
                    slot: RaftAvatarSlotContext.previewMini,
                    agent: projection.kind == 'agent',
                    avatarUrl: projection.uploadedUrl,
                    content: RaftAvatarContent(
                      name: sender,
                      kind: switch (projection.kind) {
                        'agent' => RaftAvatarContentKind.agent,
                        'app' => RaftAvatarContentKind.app,
                        _ => RaftAvatarContentKind.human,
                      },
                      pixelKey: projection.pixelKey,
                      uploadedUrl: projection.uploadedUrl,
                      gravatarUrl: projection.gravatarUrl,
                      fallback: projection.kind == 'human'
                          ? Center(
                              child: RaftIcon(
                                RaftGlyph.user,
                                size: 10,
                                color: RaftTokens.of(context).brutal
                                    ? RaftTokens.of(context).ink
                                    : RaftTokens.of(context).muted,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${row['content'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.body,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RaftSavedToggle(
            label: 'Remove saved message',
            onPressed: () => command(
              'DELETE',
              '/channels/saved/${row['messageId']}',
              sourceScope: scope,
            ),
          ),
        ],
      ),
    );
  }

  /// SavedPanel `saved-infinite-scroll-sentinel`: `flex min-h-10
  /// items-center justify-center py-3`, "Loading" while a page is in flight.
  Widget savedSentinel() {
    if (!loading && hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !loading && hasMore) load(append: true);
      });
    }
    return RaftInfiniteScrollSentinel(loading: loading);
  }

  Future<void> savedMenu(Map<String, dynamic> row, String scope) async {
    await scopedDialog<void>(
      scope,
      (context) => rowMenu(context, scope, [
        RaftMenuItem(
          label: raftText(context, 'Copy link'),
          glyph: RaftGlyph.link,
          onPressed: w.server?.string('slug').isEmpty != false
              ? null
              : () async {
                  if (!accepts(scope)) return;
                  final thread = row['channelType'] == 'thread';
                  final text = ContentLinks.messageUrl(
                    origin: ContentLinks.originFor(w.client.origin),
                    slug: w.server!.string('slug'),
                    channelId: '${row['parentChannelId'] ?? row['channelId']}',
                    messageId: '${row['messageId']}',
                    kind:
                        '${thread ? row['parentChannelType'] : row['channelType']}',
                    parentMessageId: thread
                        ? row['parentMessageId'] as String?
                        : null,
                  ).toString();
                  closeOwnedDialog(context, scope);
                  if (accepts(scope)) {
                    await Clipboard.setData(ClipboardData(text: text));
                  }
                },
        ),
        RaftMenuItem(
          label: raftText(context, 'Copy Markdown'),
          glyph: RaftGlyph.copy,
          onPressed: () async {
            if (!accepts(scope)) return;
            closeOwnedDialog(context, scope);
            if (accepts(scope)) {
              await Clipboard.setData(
                ClipboardData(text: '${row['content'] ?? ''}'),
              );
            }
          },
        ),
        RaftMenuItem(
          label: raftText(context, 'Remove saved message'),
          glyph: RaftGlyph.bookmark,
          onPressed: () {
            if (!accepts(scope)) return;
            closeOwnedDialog(context, scope);
            command(
              'DELETE',
              '/channels/saved/${row['messageId']}',
              sourceScope: scope,
            );
          },
        ),
      ]),
    );
  }

  /// ThreadsInbox context menu: Done (Check 14) and, for threads,
  /// Unfollow (BellOff 14) / Follow (Bell 14).
  Future<void> activityMenu(Map<String, dynamic> row, String scope) async {
    final thread = row['kind'] == 'thread';
    final following = row['isFollowing'] != false;
    await scopedDialog<void>(
      scope,
      (context) => rowMenu(context, scope, [
        RaftMenuItem(
          label: raftText(context, 'Done'),
          glyph: RaftGlyph.check,
          onPressed: () {
            if (!accepts(scope)) return;
            closeOwnedDialog(context, scope);
            activityAction(row, 'done', scope);
          },
        ),
        if (thread)
          RaftMenuItem(
            label: raftText(context, following ? 'Unfollow' : 'Follow'),
            // BellOff is not in the glyph set yet.
            glyph: RaftGlyph.bell,
            onPressed: () {
              if (!accepts(scope)) return;
              closeOwnedDialog(context, scope);
              activityAction(row, following ? 'unfollow' : 'follow', scope);
            },
          ),
      ]),
    );
  }

  /// Context-menu dialog shared by the Saved and Activity rows.
  Widget rowMenu(BuildContext context, String scope, List<Widget> children) =>
      Dialog(
        backgroundColor: Colors.transparent,
        child: RaftMenuPanel(
          width: 240,
          onDismiss: () => closeOwnedDialog(context, scope),
          children: children,
        ),
      );

  Widget activityCard(Map<String, dynamic> row, String scope) {
    final recipe = RaftConversationCardRecipe(RaftTokens.of(context));
    final thread = row['kind'] == 'thread';
    final dm = row['kind'] == 'dm' || row['channelType'] == 'dm';
    final unread = (row['unreadCount'] as num? ?? 0).toInt();
    final title = thread
        ? '${row['parentMessagePreview'] ?? ''}'
        : '${row['channelName'] ?? row['peerDisplayName'] ?? row['peerName'] ?? row['messagePreview'] ?? 'Conversation'}';
    final senderType =
        row[thread ? 'latestActivitySenderType' : 'lastMessageSenderType'];
    final senderId =
        row[thread ? 'latestActivitySenderId' : 'lastMessageSenderId'];
    final sender = senderType == 'system' || senderId == 'system'
        ? raftText(context, 'System')
        : '${row[thread ? 'latestActivitySenderName' : 'lastMessageSenderName'] ?? senders.where((s) => s.id == senderId && s.type == senderType).firstOrNull?.label ?? ''}';
    final preview =
        '${thread ? row['latestActivityPreview'] ?? '' : row['lastMessagePreview'] ?? row['messagePreview'] ?? ''}';
    return RaftConversationCard(
      key: thread
          ? ValueKey('activity-thread-${row['threadChannelId']}')
          : ValueKey(
              'activity-${row['kind']}-${row['channelId'] ?? row['messageId']}',
            ),
      onOpen: () => openConversation(row, scope),
      onActivate: widget.onActivityCanonical == null
          ? null
          : (detail) => activateActivity(row, scope, detail),
      onContextMenu: row['kind'] == 'mention_action'
          ? null
          : () => activityMenu(row, scope),
      actions: row['kind'] == 'mention_action'
          ? null
          // ThreadsInbox row action: ghost icon-sm Check 14 (RotateCcw 14 to
          // restore). Follow/unfollow is only in the context menu.
          : RaftIconButton(
              glyph: filter == 'done' ? RaftGlyph.rotateCcw : RaftGlyph.check,
              visualSize: 28,
              minimumTargetSize: 28,
              tooltip: filter == 'done'
                  ? 'Restore conversation'
                  : 'Mark conversation done',
              onPressed: () => activityAction(
                row,
                filter == 'done' ? 'undone' : 'done',
                scope,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thread)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: RaftCssText(
                '#${row['parentChannelName'] ?? ''}',
                style: recipe.metadata.copyWith(
                  fontSize: 11,
                  height: 12 / 11,
                  color: recipe.titleIconColor,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RaftCssText.rich(
                  TextSpan(
                    children: [
                      // ThreadsInbox's icon is inline, not a separate flex
                      // column: wrapped title lines return to the row's edge.
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Transform.translate(
                          offset: const Offset(0, 2),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: thread
                                ? RaftThreadIcon(
                                    size: 13,
                                    color: recipe.titleIconColor,
                                  )
                                : dm
                                ? RaftDirectMessageIcon(
                                    size: 13,
                                    color: recipe.titleIconColor,
                                  )
                                : RaftIcon(
                                    RaftGlyph.hash,
                                    size: 13,
                                    color: recipe.titleIconColor,
                                  ),
                          ),
                        ),
                      ),
                      TextSpan(text: title),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.titleStyle(unread > 0),
                ),
              ),
              const SizedBox(width: 8),
              RaftConversationTimestamp(
                child: RaftCssText(
                  relativeTime(row['lastActivityAt'] ?? row['lastMessageAt']),
                  style: recipe.timestamp,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          RaftCssText.rich(
            TextSpan(
              children: [
                if (sender.isNotEmpty)
                  TextSpan(
                    text: '$sender: ',
                    style: recipe.body.copyWith(
                      color: recipe.senderColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                TextSpan(text: preview),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: recipe.body.copyWith(color: recipe.titleColor(unread > 0)),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (row['taskNumber'] != null && row['taskStatus'] is String)
                  RaftTaskStatus(status: row['taskStatus']),
                if (thread)
                  RaftResourceBadge(
                    label:
                        '${row['replyCount'] ?? 0} ${raftText(context, 'replies')}',
                    appearance: RaftBadgeRecipeAppearance.outline,
                    variant: RaftBadgeRecipeVariant.muted,
                  ),
                if (thread && row['isFollowing'] == false)
                  RaftResourceBadge(
                    label: raftText(context, 'Unfollowed'),
                    appearance: RaftBadgeRecipeAppearance.outline,
                    variant: RaftBadgeRecipeVariant.muted,
                  ),
                // shouldShowMentionBadge: mention with unread messages.
                if (row['hasMention'] == true && unread > 0)
                  RaftResourceBadge(
                    label: raftText(context, 'you'),
                    glyph: RaftGlyph.atSign,
                    variant: RaftBadgeRecipeVariant.primary,
                  ),
                if (unread > 0)
                  RaftResourceBadge(
                    label: '$unread ${raftText(context, 'new')}',
                    variant: RaftBadgeRecipeVariant.accent,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget groupedTasks() {
    final t = RaftTokens.of(context), scope = authority;
    // TasksPanelViewport + `bg-layer-canvas-muted p-4 theme-brutal:bg-white`;
    // list view is TaskVirtualLayout `space-y-6` of TaskSections.
    return ColoredBox(
      color: t.colors[t.brutal ? 'color-white' : 'layer-canvas-muted']!,
      child: ListView(
        padding: RaftTaskSectionRecipe(t).viewportInset,
        children: [
          for (final status in raftTaskStatuses.where(
            (s) => filter == 'all' || filter == s,
          )) ...[
            RaftTaskSection(
              status: status,
              count: visibleRows.where((r) => r['status'] == status).length,
              collapsed: collapsedTaskStatuses.contains(status),
              triggerKey: ValueKey('task-group-$status'),
              emptyLabel:
                  '${raftText(context, 'No tasks')} · ${raftTaskStatusLabel(status)}',
              onToggle: () {
                if (accepts(scope)) {
                  setState(() {
                    if (!collapsedTaskStatuses.remove(status)) {
                      collapsedTaskStatuses.add(status);
                    }
                  });
                }
              },
              children: [
                for (final row in visibleRows.where(
                  (r) => r['status'] == status,
                ))
                  SourceTaskRowExtent(child: item(row)),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (hasMore)
            TextButton(
              onPressed: () => load(append: true),
              child: Text(raftText(context, 'Load more')),
            ),
        ],
      ),
    );
  }

  Future<void> loadSenders(String scope) async {
    if (!accepts(scope) || catalogScope == scope || w.server == null) return;
    catalogScope = scope;
    final ticket = ++catalogRequest;
    final paths = [
      if (w.can('viewMembers')) '/servers/${w.server!.id}/members',
      if (w.can('viewAgents')) '/agents',
      if (widget.section == 'search' && w.can('viewMachines'))
        '/servers/${w.server!.id}/machines',
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
      final people = <Map<String, dynamic>>[],
          agents = <Map<String, dynamic>>[],
          computers = <Map<String, dynamic>>[];
      for (var i = 0; i < paths.length; i++) {
        if (paths[i].endsWith('/machines')) {
          final data = values[i];
          final machines = data is Map ? data['machines'] : data;
          if (machines is List) {
            computers.addAll(
              machines.whereType<Map>().map(
                (r) => Map<String, dynamic>.from(r),
              ),
            );
          }
          continue;
        }
        final type = paths[i] == '/agents' ? 'agent' : 'user';
        final value = values[i];
        final list = value is List
            ? value
            : value is Map
            ? value['members'] ?? value['agents'] ?? []
            : [];
        for (final row in (list as List).whereType<Map>()) {
          final id = type == 'user' ? row['userId'] ?? row['id'] : row['id'];
          (type == 'user' ? people : agents).add(
            Map<String, dynamic>.from(row),
          );
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
      final restoring = restoringSenderKey != null;
      setState(() {
        senders = options.values.toList();
        searchPeople = people;
        searchAgents = agents;
        searchComputers = computers;
        resolveRestoredSender();
      });
      if (widget.section == 'search') {
        saveSearchState();
        if (restoring && accepts(scope)) unawaited(load());
      }
    } catch (e) {
      if (!accepts(scope) || ticket != catalogRequest) return;
      catalogScope = null;
      if (widget.section == 'saved') {
        // Saved entries are authorized by their own endpoint. The optional
        // identity directory can fail independently (Source falls back to the
        // entry name); it must not finish a pending saved-page request or
        // restart its infinite-scroll sentinel.
        setState(() {
          searchPeople = [];
          searchAgents = [];
          senders = [];
        });
        return;
      }
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
              const RaftIcon(RaftGlyph.chevronDown, size: 18),
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
                  prefixIcon: const RaftIcon(RaftGlyph.search),
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
              advanced.searchSort == 'recent' ? 'Recent' : 'Relevant',
              const {'relevance': 'Relevant', 'recent': 'Recent'},
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
    if (action == 'follow' || action == 'unfollow') {
      final acceptWindow = widget.onActivityWindowAccepted;
      final acceptUnread = widget.onActivityUnreadAccepted;
      final id = row['threadChannelId'] as String;
      final ticket = activityFollowState.begin(id);
      try {
        await w.client.request('POST', mutation.path, data: mutation.data);
        if (!accepts(scope) || !activityFollowState.accepts(id, ticket)) return;
        final current = rows
            .where(
              (item) =>
                  item['kind'] == 'thread' && item['threadChannelId'] == id,
            )
            .firstOrNull;
        final cleared = action == 'unfollow'
            ? (current?['unreadCount'] as num? ??
                      row['unreadCount'] as num? ??
                      0)
                  .toInt()
            : 0;
        // ThreadsInbox success keeps this row; it does not immediately reload
        // an eventually consistent inbox and undo the accepted POST.
        setState(() {
          activityFollowState.acknowledge(
            current ?? row,
            following: action == 'follow',
          );
          rows = rows.map(activityFollowState.project).toList();
          if (totalUnreadCount != null) {
            totalUnreadCount = (totalUnreadCount! - cleared).clamp(0, 1 << 53);
          }
          loading = false;
        });
        if (totalUnreadCount != null) {
          acceptUnread?.call(totalUnreadCount);
          acceptWindow?.call({
            'items': rows,
            'totalUnreadCount': totalUnreadCount,
          });
        }
      } catch (e) {
        if (!accepts(scope) || !activityFollowState.accepts(id, ticket)) return;
        activityFollowState.finish(id, ticket);
        if (e is RaftApiException && [401, 403].contains(e.status)) {
          fail(e, scope);
        } else {
          // Source preserves the previous follow state and reconciles failure.
          await load();
        }
      } finally {
        activityFollowState.finish(id, ticket);
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

  List<Map<String, dynamic>> get visibleRows {
    if (widget.section != 'tasks') return rows;
    return rows.where(matchesTask).toList()..sort((a, b) {
      final order = raftTaskStatuses
          .indexOf('${a['status']}')
          .compareTo(raftTaskStatuses.indexOf('${b['status']}'));
      return order != 0
          ? order
          : (b['taskNumber'] as num? ?? 0).compareTo(
              a['taskNumber'] as num? ?? 0,
            );
    });
  }

  bool matchesTask(Map<String, dynamic> row) => taskAdvanced.matches(row);
  Widget privateMenuLabel(String scope, String value) => Builder(
    builder: (context) {
      final route = ModalRoute.of(context);
      dialogs.removeWhere((r) => !r.isActive);
      if (route != null) dialogs.add(route);
      return accepts(scope) ? Text(value) : const SizedBox.shrink();
    },
  );
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
    final t = RaftTokens.of(context), rt = RaftRecipeTokens(t);
    final toolbar = RaftTasksPanelRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
      }, MediaQuery.sizeOf(context).width),
      tokens: rt,
    ).toolbar;
    // TasksPanelToolbar > `flex flex-wrap items-center gap-2`.
    return Container(
      padding: toolbar.padding,
      decoration: toolbar.decoration(rt),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          // The mobile CSS grid keeps its 8px column gap even with an empty
          // auto track. Desktop switches to flex and has no reserved track.
          padding: EdgeInsets.only(
            right:
                MediaQuery.sizeOf(context).width <
                    RaftLayoutMetrics.desktopBreakpoint
                ? toolbar.columnGap ?? 0
                : 0,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final field in [
                if (widget.channelId == null) 'Channel',
                'Creator',
                'Assignee',
              ])
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
                    return TaskSelectionFilter(
                      key: ValueKey('$scope:$field'),
                      field: field,
                      options: options,
                      selection: selection,
                      beforeOpen: (active) {
                        for (final menu in filterMenus) {
                          if (!identical(menu, active) && menu.isOpen) {
                            menu.close();
                          }
                        }
                      },
                      valid: () => accepts(scope),
                      aliases: {
                        for (final person in senders)
                          person.key: '${person.handle} ${person.label}',
                      },
                      onController: (menu, add) {
                        if (add) {
                          filterMenus.add(menu);
                        } else {
                          filterMenus.remove(menu);
                        }
                      },
                      onToggle: (key) {
                        if (accepts(scope)) {
                          setState(() {
                            if (!selection.remove(key)) selection.add(key);
                          });
                        }
                      },
                      onClear: () {
                        if (accepts(scope)) setState(selection.clear);
                      },
                    );
                  },
                ),
              // TasksPanel.tsx: "New Task" (Plus 12) is channel mode only.
              if (widget.channelId != null &&
                  w.server?.string('role') != 'guest')
                RaftNewTaskButton(
                  onPressed: () => createTask(sourceScope: scope),
                ),
              RaftSegmentedControl<String>(
                style: RaftSegmentedStyle.taskViews,
                value: taskLayout,
                visualHeight: RaftMetrics.buttonMd,
                minimumTargetSize: RaftMetrics.buttonMd,
                label: raftText(context, 'Task view'),
                items: const [
                  RaftSegmentedOption(
                    value: 'board',
                    label: 'Board',
                    tooltip: 'Show task board',
                    glyph: RaftGlyph.columns3,
                  ),
                  RaftSegmentedOption(
                    value: 'list',
                    label: 'List',
                    tooltip: 'Show task list',
                    glyph: RaftGlyph.layoutList,
                  ),
                ],
                onChanged: (layout) {
                  if (accepts(scope) && taskLayout != layout) {
                    taskLayout = layout;
                    load();
                  }
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
        ),
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
        taskPath,
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

  bool canMoveTask(Map<String, dynamic> row, String scope, String next) {
    if (!accepts(scope) ||
        !rows.any((current) => identical(current, row)) ||
        row['status'] == next ||
        !raftTaskStatuses.contains(next) ||
        row['readOnlyReason'] != null ||
        w.server?.string('role') == 'guest' ||
        !w.channels.any(
          (c) => c.id == row['channelId'] && c.joined && !c.archived,
        )) {
      return false;
    }
    final role = w.server?.string('role');
    return ['owner', 'admin'].contains(role) ||
        (raftTaskTransitions[row['status']] ?? []).contains(next);
  }

  Widget draggableTask(Map<String, dynamic> row, String scope) {
    final card = item(row);
    if (!raftTaskStatuses.any((s) => canMoveTask(row, scope, s))) return card;
    final payload = _TaskDrag(row, scope);
    final feedback = AnimatedBuilder(
      animation: dragFeedbackRevision,
      builder: (context, _) =>
          accepts(scope) && rows.any((current) => identical(current, row))
          ? Material(
              color: Colors.transparent,
              child: SizedBox(width: 292, child: item(row)),
            )
          : const SizedBox.shrink(),
    );
    return RaftDensityScope.of(context) == RaftDensity.touch
        ? LongPressDraggable<_TaskDrag>(
            data: payload,
            delay: const Duration(milliseconds: 200),
            feedback: feedback,
            childWhenDragging: Opacity(opacity: .4, child: card),
            child: card,
          )
        : Draggable<_TaskDrag>(
            data: payload,
            feedback: feedback,
            childWhenDragging: Opacity(opacity: .4, child: card),
            child: card,
          );
  }

  Widget taskBoard() {
    final t = RaftTokens.of(context), scope = authority;
    return ColoredBox(
      color: t.brutal ? t.panel : t.sidebar,
      child: SingleChildScrollView(
        primary: false,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final status in raftTaskStatuses.where(
              (s) => filter == 'all' || filter == s,
            ))
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: DragTarget<_TaskDrag>(
                  key: ValueKey('task-drop-$status'),
                  onWillAcceptWithDetails: (details) =>
                      canMoveTask(details.data.row, details.data.scope, status),
                  onAcceptWithDetails: (details) {
                    final payload = details.data;
                    if (canMoveTask(payload.row, payload.scope, status)) {
                      command(
                        'PATCH',
                        '/tasks/${payload.row['id']}/status',
                        data: {'status': status},
                        sourceScope: payload.scope,
                      );
                    }
                  },
                  builder: (context, candidates, rejected) => SizedBox(
                    width: 320,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: candidates.isNotEmpty
                            ? t.colors['primary-soft']
                            : t.brutal
                            ? t.panel.withValues(alpha: .3)
                            : t.colors['fill-muted']!.withValues(alpha: .3),
                        border: Border.all(
                          color: candidates.isNotEmpty
                              ? t.strong
                              : t.brutal
                              ? t.strong.withValues(alpha: .2)
                              : t.colors['line-muted']!,
                          width: t.border,
                        ),
                        borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              RaftTaskStatus(status: status),
                              const SizedBox(width: 8),
                              Text(
                                '${(lanes[status] ?? []).where(matchesTask).length}${laneCursors[status] != null ? '+' : ''}',
                                style: RaftTypography.mono(t),
                              ),
                              const Spacer(),
                              RaftIconButton(
                                glyph: collapsedTaskStatuses.contains(status)
                                    ? RaftGlyph.chevronRight
                                    : RaftGlyph.chevronDown,
                                key: ValueKey('task-group-$status'),
                                tooltip:
                                    '${collapsedTaskStatuses.contains(status) ? 'Show' : 'Hide'} ${raftTaskStatusLabel(status)} tasks',
                                onPressed: () {
                                  if (accepts(scope)) {
                                    setState(() {
                                      if (!collapsedTaskStatuses.remove(
                                        status,
                                      )) {
                                        collapsedTaskStatuses.add(status);
                                      }
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          if (!collapsedTaskStatuses.contains(status)) ...[
                            const SizedBox(height: 12),
                            Flexible(
                              child: SingleChildScrollView(
                                primary: false,
                                child: Column(
                                  spacing: RaftResourceMetrics
                                      .gap2_5, // taskBoardColumn items
                                  children: [
                                    for (final row
                                        in (lanes[status] ?? []).where(
                                          matchesTask,
                                        ))
                                      draggableTask(row, scope),
                                    if (!(lanes[status] ?? []).any(matchesTask))
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Text(
                                          '${raftText(context, 'No tasks')} · ${raftTaskStatusLabel(status)}',
                                          style: TextStyle(color: t.muted),
                                        ),
                                      ),
                                    if (laneCursors[status] != null)
                                      RaftTextButton(
                                        label: laneBusy.contains(status)
                                            ? 'Loading…'
                                            : 'Load more ${raftTaskStatusLabel(status)}',
                                        onPressed: laneBusy.contains(status)
                                            ? null
                                            : () => moreLane(status),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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
    if (section == 'tasks') {
      final status = '${row['status'] ?? 'todo'}';
      final role = w.server?.string('role');
      final allowed = ['owner', 'admin'].contains(role)
          ? raftTaskStatuses
          : [status, ...?raftTaskTransitions[status]];
      return RaftTaskCard(
        key: ValueKey('task-${row['id']}'),
        title: name,
        number: '${row['taskNumber'] ?? row['number'] ?? ''}',
        channel: '${row['channelName'] ?? ''}',
        status: status,
        description: '${row['descriptionPreview'] ?? row['description'] ?? ''}',
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
      );
    }
    if (section == 'saved') return savedCard(row, scope);
    if (section == 'activity') return activityCard(row, scope);
    return const SizedBox.shrink();
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
    final knownParent = [
      ...w.channels,
      ...w.dms,
    ].any((c) => c.id == row['channelId']);
    if (widget.onTask != null && (row['isLegacy'] == true || knownParent)) {
      final open = widget.onTask!;
      open(row, () async {
        if (accepts(scope)) await load();
      });
      return;
    }
    final owner = TaskSurfaceController(
      parent: w,
      row: row,
      valid: () => accepts(scope),
      // The resource bucket gets its authoritative order/filter result again;
      // task mutations cannot leave a closed modal's card at the old status.
      onMutationAccepted: () async {
        if (accepts(scope)) await load();
      },
      onFailure: (cause) {
        // Authorization failures revoke the entire accepted resource scope.
        if (cause is RaftApiException && [401, 403].contains(cause.status)) {
          fail(cause, scope);
        }
      },
    );
    unawaited(owner.start());
    String? result;
    Map<String, dynamic> task;
    try {
      result = await scopedDialog<String>(scope, (context) {
        return SourceTaskSurface(
          owner: owner,
          onClose: () => closeOwnedDialog(context, scope),
          onCleanupDelete: () {
            if (owner.canCleanupDelete) {
              closeOwnedDialog(context, scope, 'delete');
            }
          },
        );
      }, sourceModal: true);
      task = {...owner.task};
    } finally {
      owner.dispose();
    }
    if (!accepts(scope)) return;
    if (result == 'delete' && mounted) {
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

class _TaskDrag {
  const _TaskDrag(this.row, this.scope);
  final Map<String, dynamic> row;
  final String scope;
}
