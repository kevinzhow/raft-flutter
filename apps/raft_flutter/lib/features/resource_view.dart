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
import '../data/activity_done_state.dart';
import '../data/source_read_all_transport.dart';
import '../data/resource_row_reconcile.dart';
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
    this.activitySidebarEnabled = false,
    this.compactActivitySidebar = false,
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
  final bool activitySidebarEnabled, compactActivitySidebar;

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
  final activityDoneState = ActivityDoneState();
  bool loading = true;
  String? error;
  String filter = 'all';
  ResourceFilters advanced = ResourceFilters();
  List<ResourceSender> senders = [];
  List<Map<String, dynamic>> activityGroups = [];
  List<Map<String, dynamic>> acceptedActivityItems = [];
  String activeActivityFilter = 'all';
  int? activityAllCount;
  int savedActivityTotal = 0;
  List<Map<String, dynamic>> savedActivityItems = [], doneActivityItems = [];
  bool activitySearchVisible = false;
  int activityFacetRequest = 0;
  bool get enabledActivity =>
      widget.section == 'activity' && widget.activitySidebarEnabled;
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

  /// The list request currently owning [rows]; a realtime reconcile queues one
  /// trailing request behind it rather than superseding its ready response.
  int? activeLoad;
  bool trailingReconcile = false;

  /// Request shape (path and filters, without the window) of accepted [rows].
  String? rowsView;

  /// Activity rows advanced by live messages beyond their accepted window.
  final activityLocalFrontiers = <String, BigInt>{};
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
  static const channelAccessKeys = [
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
  ];
  Map<String, dynamic> channelAccessFacts(RaftChannel c) => {
    'id': c.id,
    'type': c.type,
    'joined': c.joined,
    'archived': c.archived,
    for (final key in channelAccessKeys)
      if (c.json.containsKey(key)) key: c.json[key],
  };

  /// Principal, server, role and page identity. A change here retires every
  /// accepted row; a channel-only change re-filters rows in place instead.
  String get identityAuthority => jsonEncode([
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.client.serverId,
    w.server?.id,
    w.server?.string('role'),
    widget.section,
    widget.channelId,
  ]);
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
      for (final c in channels) channelAccessFacts(c),
    ]);
  }

  String? acceptedIdentity;
  Map<String, Map<String, dynamic>> acceptedAccess = {};
  Map<String, Map<String, dynamic>> get channelAccess => {
    for (final c in [...w.channels, ...w.dms]) c.id: channelAccessFacts(c),
  };

  bool privateLike(Map<String, dynamic>? facts) =>
      facts == null ||
      facts['isPrivate'] == true ||
      facts['visibility'] == 'private' ||
      ['private', 'dm', 'joint', 'thread'].contains(facts['type']);

  /// Channels whose rows can no longer be shown: removed from the directory,
  /// denied by capability, or a private conversation the principal left.
  Set<String> lostChannels(
    Map<String, Map<String, dynamic>> previous,
    Map<String, Map<String, dynamic>> next,
  ) {
    final all = [...w.channels, ...w.dms];
    final lost = <String>{};
    for (final MapEntry(key: id, value: before) in previous.entries) {
      final after = next[id];
      if (after == null) {
        lost.add(id);
      } else if (!rowDeepEquals(before, after) &&
          (!w.can(
                'viewChannel',
                resource: all.where((c) => c.id == id).firstOrNull,
              ) ||
              privateLike(after) &&
                  before['joined'] == true &&
                  after['joined'] != true)) {
        lost.add(id);
      }
    }
    return lost;
  }

  /// Drop exactly the rows that disclose a lost channel; keep every other row
  /// object (and the scroll position, loaded pages and open row state).
  void refilterRows(Set<String> lost) {
    if (lost.isEmpty) return;
    bool keep(Map row) => !rowChannelIds(row).any(lost.contains);
    rows = rows.where(keep).toList();
    acceptedActivityItems = acceptedActivityItems.where(keep).toList();
    savedActivityItems = savedActivityItems.where(keep).toList();
    doneActivityItems = doneActivityItems.where(keep).toList();
    activityGroups = activityGroups
        .where((g) => !lost.contains(g['channelId']))
        .toList();
    if (lost.contains(advanced.channelId)) advanced.channelId = null;
    dragFeedbackRevision.value++;
  }

  bool accepts(String scope, [int? request]) =>
      mounted &&
      scope == authority &&
      scope == acceptedAuthority &&
      (request == null || request == requestGeneration);
  void clearRows() {
    activityFollowState.clear();
    activityDoneState.clear();
    activityActivation?.cancel();
    dragFeedbackRevision.value++;
    rows = [];
    rowsView = null;
    trailingReconcile = false;
    activityLocalFrontiers.clear();
    lanes.clear();
    laneCursors.clear();
    laneBusy.clear();
    cursor = null;
    hasMore = false;
    activityGroups = [];
    acceptedActivityItems = [];
    activityAllCount = null;
    savedActivityTotal = 0;
    savedActivityItems = [];
    doneActivityItems = [];
    activeActivityFilter = 'all';
    activitySearchVisible = false;
    ++activityFacetRequest;
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
      acceptedIdentity = identityAuthority;
      acceptedAccess = channelAccess;
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

  void authorityChanged({Set<String> revoked = const {}}) {
    if (!mounted || acceptedAuthority == authority) return;
    final identity = identityAuthority, access = channelAccess;
    final sameIdentity = identity == acceptedIdentity;
    final previousAccess = acceptedAccess;
    acceptedAuthority = authority;
    acceptedIdentity = identity;
    acceptedAccess = access;
    requestGeneration++;
    refreshTimer?.cancel();
    closeDialogs();
    if (sameIdentity && ['activity', 'saved'].contains(widget.section)) {
      // Channel facts changed under the same principal and role. Only rows of
      // a channel that is actually no longer visible leave; the rest stay on
      // screen while the window reconciles in the background.
      setState(() {
        refilterRows({...revoked, ...lostChannels(previousAccess, access)});
      });
      // A first window still in flight keeps its skeleton until this
      // replacement request settles.
      unawaited(load(keep: true, quietErrors: rows.isNotEmpty));
      return;
    }
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
        final payload = event.payload;
        final id = payload is Map
            ? payload['channelId'] ?? payload['id']
            : null;
        var revoked = const <String>{};
        if (event.name != 'channel:updated') {
          if (id is String) {
            // Fail closed before the directory refresh lands, but only for a
            // conversation whose visibility depends on membership.
            if (privateLike(acceptedAccess[id])) revoked = {id};
          } else {
            acceptedIdentity = null;
          }
        }
        authorityRevision++;
        authorityChanged(revoked: revoked);
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
        if (widget.section == 'activity') patchActivity(event);
        final scope = authority;
        refreshTimer?.cancel();
        refreshTimer = Timer(const Duration(milliseconds: 150), () {
          if (accepts(scope)) unawaited(reconcile());
        });
      }
    });
  }

  /// Source socketBridge background reset: never blanks accepted rows and
  /// never supersedes a list request in flight; one trailing reconcile runs
  /// after it with the then-loaded window width.
  Future<void> reconcile() {
    if (activeLoad != null) {
      trailingReconcile = true;
      return Future.value();
    }
    return load(keep: true, quietErrors: true);
  }

  bool get activityRowsLive =>
      widget.section == 'activity' &&
      !['saved', 'done'].contains(filter) &&
      rows.isNotEmpty;

  /// Apply live socket facts to the accepted Activity rows before the
  /// debounced canonical reconcile (Source receiveThreadReply and
  /// applyReadStateProjection).
  void patchActivity(RaftEvent event) {
    final payload = event.payload;
    if (!activityRowsLive || payload is! Map) return;
    if (payload['serverId'] is String &&
        payload['serverId'] != w.client.serverId) {
      return;
    }
    if (event.name == 'message:new') {
      advanceActivity(payload);
    } else if (event.name == 'thread:updated' &&
        payload['latestReply'] is Map) {
      advanceActivity(payload['latestReply'] as Map);
    } else if (event.name.startsWith('read_state:')) {
      // The ledger may not have folded this frame yet; the frame itself is
      // the newest read fact for its scopes.
      final facts = <String, int>{
        for (final update in [
          if (payload['scopes'] is List) ...payload['scopes'] as List,
          if (payload['scopeId'] is String) payload,
        ])
          if (update is Map &&
              update['scopeId'] is String &&
              update['maxReadSeq'] is int)
            update['scopeId'] as String: update['maxReadSeq'] as int,
      };
      final known = applyKnownReads(rows, facts: facts);
      if (identical(known.rows, rows)) return;
      setState(() {
        rows = known.rows;
        acceptedActivityItems = applyKnownReads(
          acceptedActivityItems,
          facts: facts,
        ).rows;
        if (totalUnreadCount != null) {
          totalUnreadCount = (totalUnreadCount! - known.cleared).clamp(
            0,
            1 << 53,
          );
        }
        if (totalCount != null && known.removed > 0) {
          totalCount = (totalCount! - known.removed).clamp(0, 1 << 53);
        }
      });
    }
  }

  bool activityMuted(Map<String, dynamic> row) {
    final id = row['kind'] == 'thread'
        ? row['parentChannelId']
        : row['channelId'];
    return [
      ...w.channels,
      ...w.dms,
    ].any((c) => c.id == id && c.json['activityMuted'] == true);
  }

  void advanceActivity(Map message) {
    for (var i = 0; i < rows.length; i++) {
      final next = advanceActivityRow(rows[i], message);
      if (next == null) continue;
      if (activityMuted(rows[i])) return;
      final key = rowKey(next), frontier = activityFrontier(next);
      if (key != null && frontier != null) {
        activityLocalFrontiers[key] = frontier;
      }
      setState(() {
        final rest = [...rows]..removeAt(i);
        // Newest-first windows move the advanced conversation to the top.
        rows = advanced.direction == 'asc'
            ? ([...rows]..[i] = next)
            : [next, ...rest];
        acceptedActivityItems = [
          for (final row in acceptedActivityItems)
            rowKey(row) == key ? next : row,
        ];
      });
      return;
    }
  }

  /// Known read frontiers (Source applyKnownReadStateProjectionsToItems):
  /// rows fully read by this principal present no unread; the Unread view
  /// drops them.
  ({List<Map<String, dynamic>> rows, int cleared, int removed})
  applyKnownReads(
    List<Map<String, dynamic>> source, {
    Map<String, int> facts = const {},
  }) {
    final server = w.client.serverId, user = w.client.user?.id;
    if (server == null || user == null) {
      return (rows: source, cleared: 0, removed: 0);
    }
    var cleared = 0, removed = 0, changed = false;
    final next = <Map<String, dynamic>>[];
    for (final row in source) {
      final scope = activityScopeId(row);
      final state = scope == null
          ? null
          : w.readState.state(server, user, scope);
      final ledger = state?['maxReadSeq'], frame = facts[scope];
      final read = [
        if (ledger is int) ledger,
        ?frame,
      ].fold<int?>(null, (a, b) => a == null || b > a ? b : a);
      final projected = projectFullyRead(
        row,
        read == null ? null : BigInt.from(read),
      );
      if (!identical(projected, row)) {
        changed = true;
        cleared += (row['unreadCount'] as num? ?? 0).toInt();
        if (filter == 'unread') {
          removed++;
          continue;
        }
      }
      next.add(projected);
    }
    return (rows: changed ? next : source, cleared: cleared, removed: removed);
  }

  /// Stable per-view item identity used to merge windows and keep row objects.
  String? rowKey(Map row) => switch (widget.section) {
    'activity' when enabledActivity && filter == 'saved' =>
      row['savedMessageId'] is String ? 'saved:${row['savedMessageId']}' : null,
    'activity' => activityItemKey(row),
    'saved' => row['messageId'] is String ? 'saved:${row['messageId']}' : null,
    'search' => row['id'] is String ? 'message:${row['id']}' : null,
    _ => row['id'] is String ? '${widget.section}:${row['id']}' : null,
  };

  @override
  void initState() {
    super.initState();
    acceptedAuthority = authority;
    acceptedIdentity = identityAuthority;
    acceptedAccess = channelAccess;
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
    if (widget.section == 'activity' &&
        oldWidget.activitySidebarEnabled != widget.activitySidebarEnabled) {
      ++requestGeneration;
      ++activityFacetRequest;
      closeDialogs();
      if (!widget.activitySidebarEnabled) {
        filter = activeActivityFilter;
        advanced.channelId = null;
      }
      // The presentation gate changed, not the data authority: keep rows
      // visible until the replacement window is accepted.
      unawaited(load(keep: true));
    }
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

  /// [keep] revalidates in place: accepted rows stay on screen (no loading
  /// skeleton), the request spans the loaded window and the response merges
  /// by item key. [quietErrors] retains the accepted window on a transient
  /// failure, as Source's background reset does.
  Future<void> load({
    bool append = false,
    bool keep = false,
    bool quietErrors = false,
  }) async {
    final acceptActivityWindow = widget.onActivityWindowAccepted;
    saveSearchState();
    final request = ++requestGeneration, scope = authority;
    keep = keep && !append;
    ++activityFacetRequest;
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
    if (!keep) {
      setState(() {
        loading = true;
        error = null;
        laneBusy.clear();
        if (!append &&
            ['search', 'saved', 'activity'].contains(widget.section) &&
            !enabledActivity &&
            !(widget.section == 'activity' && activityFollowState.busy)) {
          rows = [];
          cursor = null;
          hasMore = false;
        }
      });
    }
    activeLoad = request;
    if (enabledActivity && ['saved', 'done'].contains(filter) && !append) {
      unawaited(loadActivityFacets(scope));
    }
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
          'saved' when enabledActivity => '/channels/saved',
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
      final pageSize =
          widget.section == 'saved' || enabledActivity && filter == 'saved'
          ? 20
          : 30;
      // Source requestLimit: a background reset spans the loaded window.
      final windowSize = keep
          ? rows.length.clamp(pageSize, 100).toInt()
          : pageSize;
      final params = widget.section == 'search'
            ? advanced.search(query.text, offset: append ? rows.length : 0)
            : ['saved', 'activity'].contains(widget.section)
            ? advanced.list(
                query.text,
                offset: append ? rows.length : 0,
                limit: windowSize,
                filter:
                    widget.section == 'activity' &&
                        !['saved', 'done', 'unfollowed'].contains(filter)
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
              };
      final view = jsonEncode([
        path,
        {
          for (final entry in (params ?? const {}).entries)
            if (!['limit', 'offset', 'cursor'].contains(entry.key))
              entry.key: entry.value,
        },
      ]);
      var value = await w.query(path, query: params);
      if (!accepts(scope, request)) return;
      if (widget.section == 'activity' && filter != 'saved' && value is Map) {
        value = activityFollowState.window(value);
        if (!['done', 'unfollowed'].contains(filter)) {
          value = activityDoneState.window(
            value,
            widget.clock?.call() ?? DateTime.now(),
            selectedChannelId: advanced.channelId,
          );
        }
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
        final fetched = (list as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        var accepted = enabledActivity && filter == 'saved'
            ? fetched.map(savedActivityItem).toList()
            : fetched;
        final activityWindow =
            widget.section == 'activity' &&
            !['saved', 'done'].contains(filter);
        var unreadDelta = 0;
        if (activityWindow) {
          final known = applyKnownReads(accepted);
          accepted = known.rows;
          unreadDelta -= known.cleared;
        }
        final List<Map<String, dynamic>> nextRows;
        if (append) {
          nextRows = [...rows, ...accepted];
        } else if (keep &&
            view == rowsView &&
            ['activity', 'saved'].contains(widget.section)) {
          final merged = reconcileActivityWindow(
            incoming: accepted,
            current: rows,
            hasMore: value is Map && value['hasMore'] == true,
            // Source preserveLoadedInboxTail: unfiltered newest-first only.
            preserveTail:
                rows.length > windowSize &&
                (widget.section == 'saved' ||
                    filter == 'all' &&
                        advanced.channelId == null &&
                        advanced.direction == 'desc' &&
                        query.text.trim().isEmpty),
            localFrontiers: activityWindow ? activityLocalFrontiers : {},
            keyOf: rowKey,
            newestFirst: advanced.direction != 'asc',
          );
          nextRows = merged.rows;
          unreadDelta += merged.unreadDelta;
        } else {
          nextRows = stabilizeRows(accepted, rows, rowKey);
        }
        if (unreadDelta != 0 &&
            value is Map &&
            value['totalUnreadCount'] is num) {
          // Every consumer of this window sees the locally known reads.
          value = {
            ...value,
            'totalUnreadCount':
                ((value['totalUnreadCount'] as num).toInt() + unreadDelta)
                    .clamp(0, 1 << 53),
          };
        }
        setState(() {
          rows = nextRows;
          rowsView = view;
          if (keep) error = null;
          if (enabledActivity && filter == 'saved') {
            savedActivityItems = List.of(rows);
          }
          if (enabledActivity && filter == 'done') {
            doneActivityItems = List.of(rows);
          }
          dragFeedbackRevision.value++;
          if (enabledActivity && filter == 'saved' && value is Map) {
            savedActivityTotal =
                (value['globalTotal'] as num?)?.toInt() ??
                (query.text.trim().isEmpty && advanced.channelId == null
                    ? (value['total'] as num?)?.toInt() ?? rows.length
                    : savedActivityTotal);
          }
          if (value is Map &&
              !(enabledActivity && ['saved', 'done'].contains(filter))) {
            totalCount = (value['total'] ?? value['totalCount']) as int?;
            totalUnreadCount = value['totalUnreadCount'] as int?;
          }
          if (widget.section == 'activity' &&
              !['saved', 'done'].contains(filter) &&
              value is Map) {
            acceptActivityFacets(value, rows);
          }
          cursor = value is Map ? value['next_cursor'] as String? : null;
          hasMore = widget.section == 'tasks'
              ? cursor != null
              : value is Map && value['hasMore'] == true;
        });
        if (widget.section == 'activity' &&
            !['saved', 'done'].contains(filter) &&
            value is Map &&
            value['totalUnreadCount'] is num) {
          widget.onActivityUnreadAccepted?.call(
            (value['totalUnreadCount'] as num).toInt(),
          );
        }
        if (widget.section == 'activity' &&
            !['saved', 'done'].contains(filter) &&
            value is Map) {
          acceptActivityWindow?.call(value);
        }
      }
    } catch (e) {
      final denied = e is RaftApiException && [401, 403].contains(e.status);
      if (!quietErrors || denied) fail(e, scope, request: request);
    } finally {
      if (accepts(scope, request) && loading) {
        setState(() => loading = false);
      }
      if (activeLoad == request) {
        activeLoad = null;
        if (trailingReconcile && accepts(scope)) {
          trailingReconcile = false;
          unawaited(reconcile());
        }
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
      // Revalidate in place: an accepted list never blanks behind its own
      // mutation (Mark all read, Remove saved message, task status).
      if (accepts(scope)) await load(keep: rows.isNotEmpty);
    } catch (e) {
      fail(e, scope);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // ThreadsInbox mounts ActivityInboxPanel with `theme-brutal:!border-l`.
    final activityEdge = widget.section == 'activity';
    final body = Container(
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
    return enabledActivity
        ? CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                  showActivitySearch,
              const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                  showActivitySearch,
            },
            child: body,
          )
        : body;
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
        if (widget.section == 'activity')
          enabledActivity
              ? enabledActivityToolbar(scope)
              : activityToolbar(scope),
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
              ? enabledActivity
                    ? const RaftActivityLoadingList()
                    : Center(child: CircularProgressIndicator())
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
                        title: enabledActivity
                            ? activityEmptyTitle
                            : widget.section == 'search'
                            ? 'Search your workspace'
                            : 'No ${widget.section}',
                        detail: enabledActivity
                            ? activityEmptyDetail
                            : widget.section == 'search'
                            ? 'Enter words to find messages.'
                            : 'There are no items in this view.',
                        glyph: enabledActivity
                            ? (filter == 'saved'
                                  ? RaftGlyph.bookmark
                                  : filter == 'done'
                                  ? RaftGlyph.checkCircle2
                                  : RaftGlyph.messageSquareText)
                            : null,
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

  Map<String, dynamic> savedActivityItem(Map<String, dynamic> entry) {
    final thread = entry['channelType'] == 'thread';
    final senderType =
        ['agent', 'system', 'external_projection'].contains(entry['senderType'])
        ? entry['senderType']
        : 'user';
    return {
      'kind': thread
          ? 'thread'
          : entry['channelType'] == 'dm'
          ? 'dm'
          : 'channel',
      if (thread) ...{
        'threadChannelId': entry['channelId'],
        'parentChannelId': entry['parentChannelId'] ?? entry['channelId'],
        'parentMessageId': entry['parentMessageId'] ?? entry['messageId'],
        'parentChannelName': entry['parentChannelName'] ?? entry['channelName'],
        'parentChannelType': entry['parentChannelType'] ?? 'channel',
        'parentMessagePreview':
            entry['parentMessagePreview'] ?? entry['content'],
        'parentMessageSenderType':
            [
              'agent',
              'external_projection',
            ].contains(entry['parentMessageSenderType'])
            ? entry['parentMessageSenderType']
            : 'user',
        'parentMessageSenderId':
            entry['parentMessageSenderId'] ?? entry['senderId'],
        'latestActivityPreview': entry['content'],
        'latestActivitySenderType': senderType,
        'latestActivitySenderId': entry['senderId'],
        'latestActivitySenderName': entry['senderName'],
        'latestActivityMessageId': entry['messageId'],
        'replyCount': entry['replyCount'] ?? 0,
        'lastActivityAt': entry['createdAt'],
        'lastReplyAt': entry['createdAt'],
      } else ...{
        'channelId': entry['channelId'],
        'channelName': entry['channelName'],
        'channelType': ['private', 'joint', 'dm'].contains(entry['channelType'])
            ? entry['channelType']
            : 'channel',
        'lastMessageId': entry['messageId'],
        'lastMessageAt': entry['createdAt'],
        'lastMessagePreview': entry['content'],
        'lastMessageSenderType': senderType,
        'lastMessageSenderId': entry['senderId'],
        'lastMessageSenderName': entry['senderName'],
      },
      'latestActivitySeq': null,
      'firstUnreadMessageId': null,
      'firstMentionMessageId': null,
      'unreadCount': 0,
      'hasMention': false,
      'savedMessageId': entry['messageId'],
    };
  }

  void acceptActivityFacets(Map value, List<Map<String, dynamic>> items) {
    acceptedActivityItems = List.of(items);
    totalCount = (value['totalCount'] as num?)?.toInt() ?? totalCount;
    totalUnreadCount =
        (value['totalUnreadCount'] as num?)?.toInt() ?? totalUnreadCount;
    activityAllCount =
        ((value['allCount'] ?? value['unfilteredCount']) as num?)?.toInt() ??
        (activeActivityFilter == 'all' &&
                query.text.trim().isEmpty &&
                advanced.channelId == null
            ? totalCount
            : activityAllCount);
    if (value['groups'] is! List) return;
    final selected = activityGroups
        .where((g) => g['channelId'] == advanced.channelId)
        .firstOrNull;
    activityGroups = (value['groups'] as List)
        .whereType<Map>()
        .map((g) => Map<String, dynamic>.from(g))
        .toList();
    if (selected != null &&
        !activityGroups.any((g) => g['channelId'] == advanced.channelId)) {
      activityGroups.add({...selected, 'count': 0});
    }
  }

  Future<void> loadActivityFacets(String scope) async {
    final ticket = ++activityFacetRequest;
    final acceptWindow = widget.onActivityWindowAccepted;
    try {
      var value = await w.query(
        '/channels/inbox',
        query: advanced.list(query.text, filter: activeActivityFilter),
      );
      if (!accepts(scope) || ticket != activityFacetRequest || value is! Map) {
        return;
      }
      value = activityFollowState.window(value);
      value = activityDoneState.window(
        value,
        widget.clock?.call() ?? DateTime.now(),
        selectedChannelId: advanced.channelId,
      );
      final items = (value['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() => acceptActivityFacets(value, items));
      if (value['totalUnreadCount'] is num) {
        widget.onActivityUnreadAccepted?.call(
          (value['totalUnreadCount'] as num).toInt(),
        );
      }
      acceptWindow?.call(value);
    } catch (e) {
      if (accepts(scope) && ticket == activityFacetRequest) fail(e, scope);
    }
  }

  List<RaftActivityGroup> get activitySourceGroups {
    final byId = <String, Map<String, dynamic>>{
      for (final g in activityGroups)
        if (g['channelId'] is String) g['channelId']: g,
    };
    for (final item in acceptedActivityItems) {
      final thread = item['kind'] == 'thread';
      final type = thread ? item['parentChannelType'] : item['channelType'];
      final id = thread ? item['parentChannelId'] : item['channelId'];
      if (type != 'dm' || id is! String) continue;
      byId.putIfAbsent(
        id,
        () => {
          'channelId': id,
          'channelName': thread
              ? item['parentChannelName']
              : item['channelName'],
          'channelType': 'dm',
          'count': 1,
        },
      );
    }
    final channels = [...w.channels, ...w.dms];
    final sourceGroups = [
      ...byId.values.where((g) => g['channelType'] == 'dm'),
      ...byId.values.where((g) => g['channelType'] != 'dm'),
    ];
    final indexed = sourceGroups.indexed.toList()
      ..sort((a, b) {
        int priority(Map g) => g['channelId'] == advanced.channelId
            ? 0
            : (w.unread['${g['channelId']}'] ?? 0) > 0
            ? 1
            : 2;
        final delta = priority(a.$2).compareTo(priority(b.$2));
        return delta != 0 ? delta : a.$1.compareTo(b.$1);
      });
    return indexed.map((entry) {
      final g = entry.$2;
      final label = '${g['channelName'] ?? ''}'.replaceFirst(
        RegExp(r'^[@#]+'),
        '',
      );
      final dm = g['channelType'] == 'dm';
      final channel = channels.where((c) => c.id == g['channelId']).firstOrNull;
      final agent = channel?.string('peerType') == 'agent';
      final avatar = projectSenderAvatar(
        origin: w.client.origin,
        senderId: channel?.string('peerId') ?? '',
        senderType: agent ? 'agent' : 'user',
        agents: agent
            ? [
                {
                  'id': channel?.string('peerId'),
                  'avatarUrl': channel?.string('peerAvatarUrl'),
                },
              ]
            : const [],
        members: !agent
            ? [
                {
                  'userId': channel?.string('peerId'),
                  'avatarUrl': channel?.string('peerAvatarUrl'),
                  'gravatarHash': channel?.string('peerGravatarHash'),
                },
              ]
            : const [],
        requestSize: 20,
      );
      return RaftActivityGroup(
        id: g['channelId'],
        label: label,
        count: (g['count'] as num? ?? 0).toInt(),
        dm: dm,
        icon: dm && channel != null
            ? RaftAvatar(
                name: label,
                mountedContext: RaftMountedAvatarContext.compactList,
                kind: channel.string('peerType') == 'agent'
                    ? RaftAvatarKind.agent
                    : RaftAvatarKind.human,
                content: RaftAvatarContent(
                  name: label,
                  kind: agent
                      ? RaftAvatarContentKind.agent
                      : RaftAvatarContentKind.human,
                  uploadedUrl: avatar.uploadedUrl,
                  gravatarUrl: avatar.gravatarUrl,
                  pixelKey: avatar.pixelKey,
                ),
              )
            : null,
      );
    }).toList();
  }

  void selectActivityView(RaftActivityView next, String scope) {
    if (!accepts(scope) || !enabledActivity) return;
    setState(() {
      filter = next.name;
      rows = List.of(switch (next) {
        RaftActivityView.saved => savedActivityItems,
        RaftActivityView.done => doneActivityItems,
        _ => acceptedActivityItems,
      });
      if (!['saved', 'done'].contains(filter)) activeActivityFilter = filter;
    });
    load();
  }

  Future<void> activitySwitcher(String scope) =>
      scopedDialog<void>(scope, (dialogContext) {
        void select(VoidCallback action) {
          if (!accepts(scope) || !enabledActivity) return;
          Navigator.pop(dialogContext);
          action();
        }

        return Center(
          child: RaftDialogCard(
            key: const ValueKey('activity-switcher-dialog'),
            title: 'Activity',
            onClose: () => Navigator.pop(dialogContext),
            child: RaftActivityScopePicker(
              view: RaftActivityView.values.byName(filter),
              counts: {
                RaftActivityView.all: activityAllCount ?? totalCount ?? 0,
                RaftActivityView.unread: totalUnreadCount ?? 0,
                RaftActivityView.saved: savedActivityTotal,
                RaftActivityView.done: doneActivityItems.length,
              },
              groups: activitySourceGroups,
              selectedGroup: advanced.channelId,
              onView: (value) => select(() => selectActivityView(value, scope)),
              onGroup: (id) => select(() {
                advanced.channelId = advanced.channelId == id ? null : id;
                load();
              }),
              onClearGroup: () => select(() {
                advanced.channelId = null;
                load();
              }),
            ),
          ),
        );
      });

  String get activityEmptyTitle => switch (filter) {
    'saved' => 'No saved threads yet',
    'done' => 'Nothing completed yet',
    'mentions' => 'No mentions yet',
    'unread' => 'No unread chats',
    _ =>
      advanced.channelId == null
          ? 'Activity is empty'
          : 'No activity in ${activitySourceGroups.where((g) => g.id == advanced.channelId).firstOrNull?.label ?? 'Selected channel'}',
  };
  String get activityEmptyDetail => switch (filter) {
    'saved' => 'Save a thread or message from Activity to keep it here.',
    'done' => 'Items you mark done appear here and can be restored.',
    _ when advanced.channelId != null =>
      'Try another channel or clear the channel filter.',
    'mentions' => 'Channels, DMs, and threads where someone @mentions you will appear here.',
    _ => 'Channels, DMs, and followed threads stay here until they are done.',
  };

  void showActivitySearch() {
    if (!mounted || !enabledActivity || !widget.compactActivitySidebar) return;
    setState(() => activitySearchVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && enabledActivity) {
        queryFocus.requestFocus();
      }
    });
  }

  Widget enabledActivityToolbar(String scope) {
    final selected = activitySourceGroups
        .where((g) => g.id == advanced.channelId)
        .firstOrNull;
    return RaftActivityScopeToolbar(
      compact: widget.compactActivitySidebar,
      view: RaftActivityView.values.byName(filter),
      scopeLabel: selected?.label,
      onView: (value) => selectActivityView(value, scope),
      onOpenSwitcher: () => activitySwitcher(scope),
      sort: advanced.direction,
      onSort: (value) {
        if (accepts(scope)) {
          advanced.direction = value;
          load();
        }
      },
      search:
          widget.compactActivitySidebar &&
              (activitySearchVisible || query.text.trim().isNotEmpty)
          ? RaftActivitySearchInput(
              controller: query,
              focusNode: queryFocus,
              onDismissEmpty: () =>
                  setState(() => activitySearchVisible = false),
              onChanged: (_) {
                searchDebounce?.cancel();
                searchDebounce = Timer(const Duration(milliseconds: 250), () {
                  if (accepts(scope)) load();
                });
              },
            )
          : null,
      markAllRead:
          (totalUnreadCount ?? 0) > 0 && !['saved', 'done'].contains(filter)
          ? RaftTextButton(
              label: 'Mark all read',
              variant: RaftControlVariant.outline,
              visualHeight: 32,
              minimumTargetSize: 32,
              onPressed: () => command(
                'POST',
                '/channels/inbox/read-all',
                sourceScope: scope,
              ),
            )
          : null,
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
                    activeActivityFilter = value;
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
      actions: enabledActivity && filter == 'saved'
          ? null
          : row['kind'] == 'mention_action'
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
      if (['saved', 'activity'].contains(widget.section)) {
        // Saved and Activity entries are authorized by their own endpoint. The optional
        // identity directory can fail independently (Source falls back to the
        // entry name); it must not finish a pending saved-page request or
        // restart its infinite-scroll sentinel or finish an Activity request.
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
    if (!accepts(scope)) return;
    // A menu opened on a row that was since advanced or reconciled acts on the
    // row currently accepted for the same conversation.
    final itemKey = rowKey(row);
    final current = rows
        .where(
          (candidate) =>
              identical(candidate, row) ||
              itemKey != null && rowKey(candidate) == itemKey,
        )
        .firstOrNull;
    if (current == null) return;
    row = current;
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
    if (action == 'done') {
      final key = ActivityDoneState.key(row)!;
      final ticket = activityDoneState.begin(
        row,
        widget.clock?.call() ?? DateTime.now(),
      );
      final acceptWindow = widget.onActivityWindowAccepted;
      final acceptUnread = widget.onActivityUnreadAccepted;
      final unread = (row['unreadCount'] as num? ?? 0).toInt();
      // Source intent removes the exact accepted row synchronously. Retire
      // earlier requests before they can compare or clear the pending marker.
      requestGeneration++;
      activityFacetRequest++;
      setState(() {
        rows = rows
            .where((item) => ActivityDoneState.key(item) != key)
            .toList();
        acceptedActivityItems = acceptedActivityItems
            .where((item) => ActivityDoneState.key(item) != key)
            .toList();
        activityGroups = ActivityDoneState.groups(activityGroups, [
          row,
        ], advanced.channelId);
        if (totalCount != null) {
          totalCount = (totalCount! - 1).clamp(0, 1 << 53);
        }
        if (activityAllCount != null) {
          activityAllCount = (activityAllCount! - 1).clamp(0, 1 << 53);
        }
        if (totalUnreadCount != null) {
          totalUnreadCount = (totalUnreadCount! - unread).clamp(0, 1 << 53);
        }
        loading = false;
      });
      final channelId =
          row[row['kind'] == 'thread' ? 'threadChannelId' : 'channelId']
              as String;
      w.unread[channelId] = 0;
      w.notifyListeners();
      if (totalUnreadCount != null) {
        acceptUnread?.call(totalUnreadCount);
        acceptWindow?.call({
          'items': acceptedActivityItems.isEmpty ? rows : acceptedActivityItems,
          'totalUnreadCount': totalUnreadCount,
        });
      }
      try {
        await w.client.request('POST', mutation.path, data: mutation.data);
        if (!accepts(scope) || !activityDoneState.accepts(key, ticket)) return;
        if (row['kind'] == 'thread') {
          // Source threadStore853–883 always persists the human-self read-all
          // after this fenced Done ACK. It neither waits for this write nor
          // publishes another refresh: Done owns the awaited refresh below.
          unawaited(
            SourceReadAllTransport.of(w.client)
                .threadDone(
                  channelId,
                  identity: SourceReadAllIdentity.capture(w.client),
                )
                .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          );
        }
        // Refresh first while suppression remains armed, then retire it.
        // A genuinely newer authority marker is exempt during this refresh.
        await load(keep: true);
        if (!accepts(scope) || !activityDoneState.accepts(key, ticket)) return;
        activityDoneState.finish(key, ticket);
      } catch (e) {
        if (!accepts(scope) || !activityDoneState.accepts(key, ticket)) return;
        activityDoneState.disarm(key, ticket);
        if (e is RaftApiException && [401, 403].contains(e.status)) {
          fail(e, scope);
        } else {
          await load(keep: true);
          if (!accepts(scope) || !activityDoneState.accepts(key, ticket)) {
            return;
          }
          await w.refreshUnread();
        }
        activityDoneState.finish(key, ticket);
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
          acceptedActivityItems = acceptedActivityItems
              .map(activityFollowState.project)
              .toList();
          savedActivityItems = savedActivityItems
              .map(activityFollowState.project)
              .toList();
          doneActivityItems = doneActivityItems
              .map(activityFollowState.project)
              .toList();
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
          await load(keep: true);
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
