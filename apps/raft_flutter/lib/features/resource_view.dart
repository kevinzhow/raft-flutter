import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' hide RaftPanelHeaderRecipe;
import 'package:raft_ui/recipes.dart'
    as rui
    show
        RaftRecipeStates,
        RaftRecipeTheme,
        RaftRecipeTokens,
        RaftSearchRecipe,
        RaftSearchRecipeStyle;

import '../data/source_activity_unread_store.dart';
import '../data/channel_activity_scope.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_services.dart';
import '../data/search_memory.dart';
import '../data/activity_follow_state.dart';
import '../data/activity_done_state.dart';
import '../data/source_read_all_transport.dart';
import '../data/resource_row_reconcile.dart';
import '../data/resource_snapshot_cache.dart';
import '../data/server_page_window.dart';
import '../data/server_task_window.dart';
import '../data/server_saved_window.dart';
import 'server_task_scope.dart';
import 'saved_page_scope.dart';
import '../data/task_board_reconcile.dart';
import 'activity_find_scope.dart';
import 'create_task_dialog.dart';
import 'desktop_navigation_policy.dart'
    show DesktopContentKind, DesktopContentTarget;
import 'search_home.dart';
import 'search_snapshot.dart';
import 'task_surface.dart';
import 'task_surface_controller.dart';
import 'resource_filters.dart';
import 'resource_authority_cache.dart';
import 'activity_context_menu.dart';
import 'page_layout.dart';
import 'resource_cards.dart';
import 'search_filter_bar.dart';
import 'task_selection_filter.dart';
import 'sender_avatar_projection.dart';
import 'message_reference_directory.dart';
import 'private_route_guard.dart';
import 'quick_switcher.dart' show QuickSwitcherFailure, classifySearchFailure;
import 'resource_search.dart';
import 'resource_list_updates.dart';
import 'saved_sidebar_entry.dart';
import 'reading_anchor.dart';
import '../platform/content_links.dart';
import '../platform/interaction_timing.dart';

class ResourceView extends StatefulWidget {
  const ResourceView({
    super.key,
    required this.controller,
    required this.section,
    required this.onMessage,
    this.onBack,
    this.mobileRoot = false,
    this.clock,
    this.initialQuery,
    this.initialSearchChannelId,
    this.initialSearchDeferUntilQuery = false,
    this.onSearchEntity,
    this.onSearchMessage,
    this.onSearchQueryCommitted,
    this.onActivityItem,
    this.onActivityCanonical,
    this.activitySelectedTarget,
    this.activitySidebarEnabled = false,
    this.compactActivitySidebar = false,
    this.onActivityUnreadAccepted,
    this.onActivityWindowAccepted,
    this.searchMemory,
    this.restoreSearchState = true,
    this.searchFocusRequests,
    this.channelId,
    this.onTask,
  });
  final WorkspaceController controller;
  final String? channelId;
  final void Function(Map<String, dynamic>, Future<void> Function())? onTask;
  final String section;
  final Future<void> Function(String, String?) onMessage;
  final VoidCallback? onBack;

  /// A bottom-bar tab root on a phone: the tab root header, no back action.
  final bool mobileRoot;
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

  /// Cmd/Ctrl+K while this Search page is showing (Source
  /// `SEARCH_FOCUS_REQUEST_EVENT`): focus the field and select its text.
  final Listenable? searchFocusRequests;
  final Future<void> Function(SearchEntity)? onSearchEntity;

  /// Typed Source search hits retain thread and parent identities for the
  /// owning route. Embedded consumers may keep the ordinary message callback.
  final Future<void> Function(Map<String, dynamic>)? onSearchMessage;

  /// Source's committed query URL writer. IME composition stays in the input;
  /// embedded search consumers may omit URL ownership.
  final ValueChanged<String>? onSearchQueryCommitted;
  final Future<void> Function(Map<String, dynamic>)? onActivityItem;

  /// Canonical navigation for a second pointer click on the same Activity item.
  ///
  /// The first click opens the preview immediately. A second list click within
  /// the system double-click window upgrades that original conversation only
  /// when both clicks identify the same item. A different item opens at once.
  /// Custom embedded consumers without this callback keep immediate onOpen.
  final Future<void> Function(Map<String, dynamic>)? onActivityCanonical;

  /// The item currently open in the desktop master-detail preview (the
  /// location's content target); null on a phone or when nothing is open.
  /// The matching Activity row paints the persistent selected state, which
  /// therefore follows the location, not click timing or list order.
  final DesktopContentTarget? activitySelectedTarget;
  final bool activitySidebarEnabled, compactActivitySidebar;

  /// Server-wide Activity total from an accepted window, independent of filter.
  /// Null retires the projection after an explicit authority denial.
  final ValueChanged<int?>? onActivityUnreadAccepted;

  /// Accepted Activity response for an independent scoped unread data owner.
  /// Includes real row frontiers; null retires it after an authority denial.
  final void Function(Map? window, {bool firstPage})? onActivityWindowAccepted;
  @override
  State<ResourceView> createState() => _ResourceViewState();
}

class _ResourceViewState extends State<ResourceView> {
  final query = TextEditingController();
  String? lastPublishedQuery;
  TextEditingValue lastSearchEditingValue = TextEditingValue.empty;
  bool adoptingSearchQuery = false;
  Timer? searchDebounce, activityActivation;
  Duration doubleClickInterval = const Duration(milliseconds: 300);
  Duration? activityGestureInterval;
  String? activityGestureScope, activityGestureView, activityGestureKey;
  int? activityGestureRevision;
  Map<String, dynamic>? activityGestureRow;
  List<Map<String, dynamic>>? activityGestureRows;
  Map<String, double> activityGestureHeights = {};

  bool get activityGestureCurrent =>
      activityGestureRows != null && activityGestureMatches(authority);

  bool activityGestureMatches(String scope) =>
      activityGestureRows != null &&
      mounted &&
      activityGestureScope == scope &&
      scope == acceptedAuthority &&
      activityGestureView == listView &&
      activityGestureRevision == w.navigationRevision;

  void clearActivityGesture() {
    activityActivation?.cancel();
    activityActivation = null;
    activityGestureRows = null;
    activityGestureRow = null;
    activityGestureKey = null;
    activityGestureScope = null;
    activityGestureView = null;
    activityGestureRevision = null;
    activityGestureHeights = {};
    activityGestureInterval = null;
  }

  String? selectedSearchKey;
  List<Map<String, dynamic>> searchPeople = [],
      searchAgents = [],
      searchComputers = [];

  /// Row presentation (Saved/Activity/Search senders) reads the workspace's
  /// shared, preloaded author directory: rows paint their final author at
  /// once and a page reset or catalog refresh never blanks them.
  MessageReferenceDirectory? authorDirectory;
  List<Map<String, dynamic>> get rowAgents =>
      authorDirectory?.agents ?? searchAgents;
  List<Map<String, dynamic>> get rowPeople =>
      authorDirectory?.members ?? searchPeople;

  /// A row first painted before the directory settled keeps the label it was
  /// painted with (no author-name swap), until the directory identity changes.
  final paintedSenders = <String, String>{};
  String? paintedSendersAuthority;

  void bindAuthors() {
    authorDirectory?.removeListener(authorsChanged);
    authorDirectory?.dispose();
    authorDirectory = ['saved', 'activity', 'search'].contains(widget.section)
        ? (MessageReferenceDirectory(w)..addListener(authorsChanged))
        : null;
  }

  void authorsChanged() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  String stableSender(String key, String Function() resolve) {
    final authority = directoryAuthority(w);
    if (paintedSendersAuthority != authority) {
      paintedSendersAuthority = authority;
      paintedSenders.clear();
    }
    final locked = paintedSenders[key];
    if (locked != null) return locked;
    final value = resolve();
    if (authorDirectory?.loading == true) paintedSenders[key] = value;
    return value;
  }

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

  /// Applies the stored Search state before the first frame when the device
  /// store can answer synchronously, so a revisit opens on its query (and the
  /// results it already holds) instead of the home page. Returns false when
  /// nothing is restored here; [activateSearchMemory] then restores it once
  /// the store has been read. A restored sender needs the people catalog, so
  /// it takes the asynchronous path.
  bool restoreSearchMemorySync() {
    final personal = memoryScope;
    if (personal == null ||
        !widget.restoreSearchState ||
        widget.initialQuery != null ||
        widget.initialSearchChannelId != null) {
      return false;
    }
    final snapshot = searchMemory.loadSync(personal).state;
    final empty = jsonEncode(const SearchStateSnapshot().toJson());
    if (snapshot.senderKey != null || jsonEncode(snapshot.toJson()) == empty) {
      return false;
    }
    query.text = snapshot.query;
    advanced.scopes.addAll(snapshot.scopes);
    advanced.timeRange = snapshot.range;
    advanced.searchSort = snapshot.sort;
    advanced.channelId =
        [...w.channels, ...w.dms].any((c) => c.id == snapshot.channelId)
        ? snapshot.channelId
        : null;
    memoryReadyKey = personal.key;
    return true;
  }

  Future<void> activateSearchMemory({
    required bool restore,
    bool restored = false,
  }) async {
    final personal = memoryScope, scope = authority;
    if (personal == null) return;
    final before = jsonEncode(currentSearchState.toJson());
    final data = await searchMemory.load(personal);
    if (!accepts(scope) || memoryScope?.key != personal.key) return;
    final untouched = before == jsonEncode(currentSearchState.toJson());
    if (restored) {
      // The first frame already carries the restored state and its load.
      setState(() => memoryReadyKey = personal.key);
      saveSearchState();
      if (untouched) {
        lastPublishedQuery = query.text.trim();
        widget.onSearchQueryCommitted?.call(lastPublishedQuery!);
      }
      return;
    }
    final restoring =
        restore &&
        untouched &&
        widget.initialQuery == null &&
        widget.initialSearchChannelId == null;
    setState(() {
      memoryReadyKey = personal.key;
      if (restoring) {
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
    if (restoring) {
      lastPublishedQuery = query.text.trim();
      widget.onSearchQueryCommitted?.call(lastPublishedQuery!);
      // Only a restored state asks for its own read; a page that already
      // loaded what it was opened with keeps it (and its cached window).
      if (jsonEncode(currentSearchState.toJson()) != before) await load();
    }
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

  /// The failure came from the blocking first read (no list on screen yet).
  bool errorWhileLoading = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when a load starts or succeeds, on authority change and on initialQuery change; set only for the accepted scope/request.
  String? error;

  /// Why the last Search read failed (Source `classifySearchFailure`).
  QuickSwitcherFailure? searchFailureKind;
  String filter = 'all';
  ResourceFilters advanced = ResourceFilters();
  List<ResourceSender> senders = [];
  List<Map<String, dynamic>> activityGroups = [];
  List<Map<String, dynamic>> acceptedActivityItems = [];
  String activeActivityFilter = 'all';
  int? activityAllCount;
  int savedActivityTotal = 0;
  int get directMessagesTotal => ChannelActivityScope.directMessagesTotal(
    rowsView,
    totalCount,
    viewWindows,
  );
  ChannelActivityScope get activityScope =>
      ChannelActivityScope(filter, savedEnabled: enabledActivity);
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

  /// Bumped whenever the lanes are replaced rather than revalidated; a lane
  /// page requested before that never appends to the replacement.
  int laneGeneration = 0;

  /// Live task facts (by id; null = deleted) received while a task window was
  /// in flight. They are newer than that response and are applied over it.
  final taskTouched = <String, Map<String, dynamic>?>{};
  String? cursor;
  bool hasMore = false;
  int requestGeneration = 0;

  /// The list request currently owning [rows]; a realtime reconcile queues one
  /// trailing request behind it rather than superseding its ready response.
  int? activeLoad;
  bool activeAppend = false;
  bool trailingReconcile = false;

  /// Request shape (path and filters, without the window) of accepted [rows].
  String? rowsView;

  /// Legacy Activity, Saved and Search keep the accepted window of each
  /// recently visited filter/query, so switching back shows it at once and
  /// revalidates it in place instead of blanking (Source keeps these stores).
  final viewWindows = <String, ResourceViewWindow>{};
  static const maxViewWindows = 8;

  bool get cachesViewWindows =>
      ['search', 'saved', 'activity'].contains(widget.section) &&
      widget.channelId == null;

  /// Request shape (path and filters, without the window) the list would load
  /// now; the same key [rowsView] records for accepted rows.
  String? get listView => listViewFor(filter);

  String? listViewFor(String filter) {
    if (!cachesViewWindows) return null;
    final path = switch (widget.section) {
      'activity' => ChannelActivityScope(
        filter,
        savedEnabled: enabledActivity,
      ).path,
      'saved' => '/channels/saved',
      _ => '/messages/search',
    };
    final params = widget.section == 'search'
        ? advanced.search(query.text)
        : advanced.list(
            query.text,
            activityView: widget.section == 'activity' ? filter : null,
          );
    if (params == null) return null;
    return ResourceFilters.viewKey(path, params);
  }

  /// [listView] with the relative time window's clock-derived `after`/`before`
  /// replaced by the chosen range, so the identity of a view (and the scroll
  /// offset stored under it) survives rebuilds while the clock moves.
  String? get scrollView {
    final view = listView;
    if (view == null || widget.section != 'search') return view;
    final decoded = jsonDecode(view) as List;
    final params = {...(decoded[1] as Map<String, dynamic>)}
      ..remove('after')
      ..remove('before');
    return jsonEncode([decoded[0], params, advanced.timeRange]);
  }

  /// Remember the accepted [rows] under [rowsView] before another view
  /// replaces them.
  void stashViewWindow() {
    final view = rowsView;
    if (!cachesViewWindows || view == null) return;
    viewWindows.remove(view);
    viewWindows[view] = ResourceViewWindow(
      rows: rows,
      hasMore: hasMore,
      totalCount: totalCount,
      totalUnreadCount: totalUnreadCount,
    );
    while (viewWindows.length > maxViewWindows) {
      viewWindows.remove(ChannelActivityScope.evictionKey(viewWindows));
    }
  }

  /// Activity rows advanced by live messages beyond their accepted window.
  final activityLocalFrontiers = <String, BigInt>{};

  /// Source inboxStore inboxLocalReadSuppressedMarkers: rows this principal
  /// just opened present read against any response that predates the read.
  final activityReadMarkers = <String, ({BigInt frontier, DateTime until})>{};

  /// Activity and Saved keep their accepted list in the workspace across
  /// navigation, including where the list was scrolled.
  bool get snapshotted =>
      ['activity', 'saved'].contains(widget.section) &&
      widget.channelId == null;
  ScrollController? listScroll;
  double listOffset = 0;
  final activityScrollOffsets = <String, double>{};
  final activityScrolls = <String, ScrollController>{};

  ScrollController newActivityScroll() {
    final scroll = RaftAnchoredScrollController(
      listUpdates.anchor,
      initialScrollOffset: listOffset,
    );
    scroll.addListener(() {
      if (identical(scroll, listScroll)) trackListScroll();
    });
    return scroll;
  }

  void trackListScroll() {
    final scroll = listScroll;
    if (scroll == null || scroll.positions.length != 1) return;
    listOffset = scroll.offset;
    if (widget.section == 'activity') {
      activityScrollOffsets[filter] = listOffset;
    }
    if (listUpdates.scrolled(scroll.position) && mounted) setState(() {});
  }

  /// Reading position and "N new updates" pill of the Activity/Saved list.
  final listUpdates = ResourceListUpdates();

  void observeListUpdates() {
    final scroll = listScroll;
    listUpdates.observe(
      view: (widget.section, filter, rowsView, advanced.groupByChannel),
      keys: [for (final row in visibleRows) rowKey(row)],
      position:
          scroll != null && scroll.hasClients && scroll.positions.length == 1
          ? scroll.position
          : null,
    );
  }

  void revealListUpdates() {
    final scroll = listScroll;
    if (scroll == null || !scroll.hasClients) return;
    setState(
      () => listUpdates.reveal(
        scroll.position,
        animate: !MediaQuery.disableAnimationsOf(context),
      ),
    );
  }

  /// The server Tasks page and each channel's Tasks tab keep their board and
  /// list across navigation (Source's task store is per server and channel).
  bool get taskSnapshotted => widget.section == 'tasks';

  /// Workspace Tasks only. Its accepted board is the session window, not the
  /// `tasks` snapshot slot. A channel tab keeps `tasks:<channelId>`.
  bool get serverTaskPage =>
      widget.section == 'tasks' && widget.channelId == null;

  bool get savedPage => widget.section == 'saved' && widget.channelId == null;

  /// Snapshot slot of this page; the identity binding includes the channel.
  String get snapshotSection => widget.channelId == null
      ? widget.section
      : '${widget.section}:${widget.channelId}';
  ScrollController? taskListScroll, taskBoardScroll;
  double taskListOffset = 0, taskBoardOffset = 0;

  bool restoreTaskSnapshot() {
    TaskSnapshot? snapshot;
    if (serverTaskPage) {
      // The workspace page no longer reads the `tasks` slot.
      snapshot = takeServerPage<TaskSnapshot>(
        w.resourceSnapshots,
        serverTasksPage,
        identityAuthority,
        accept: (_) => acceptsTaskChannel,
      );
    } else {
      snapshot = w.resourceSnapshots.read<TaskSnapshot>(
        snapshotSection,
        identityAuthority,
      );
      if (snapshot != null && !acceptsTaskChannel) {
        // A channel lost while the tab was away never shows its cached tasks.
        w.resourceSnapshots.remove(snapshotSection);
        snapshot = null;
      }
    }
    taskListOffset = snapshot?.listOffset ?? 0;
    taskBoardOffset = snapshot?.boardOffset ?? 0;
    // Children unmount before this state disposes; track the offsets live.
    taskListScroll = ScrollController(initialScrollOffset: taskListOffset)
      ..addListener(() {
        final scroll = taskListScroll;
        if (scroll != null && scroll.positions.length == 1) {
          taskListOffset = scroll.offset;
        }
      });
    taskBoardScroll = ScrollController(initialScrollOffset: taskBoardOffset)
      ..addListener(() {
        final scroll = taskBoardScroll;
        if (scroll != null && scroll.positions.length == 1) {
          taskBoardOffset = scroll.offset;
        }
      });
    if (snapshot == null) return false;
    // The user's layout survives; the viewport default applies only once.
    initializedTaskLayout = true;
    taskLayout = snapshot.layout;
    filter = snapshot.filter;
    rowsView = snapshot.view;
    rows = snapshot.rows;
    cursor = snapshot.cursor;
    hasMore = snapshot.hasMore;
    totalCount = snapshot.totalCount;
    lanes
      ..clear()
      ..addAll(snapshot.lanes);
    laneCursors
      ..clear()
      ..addAll(snapshot.laneCursors);
    taskAdvanced
      ..clear()
      ..channels.addAll(snapshot.channels)
      ..creators.addAll(snapshot.creators)
      ..assignees.addAll(snapshot.assignees);
    collapsedTaskStatuses
      ..clear()
      ..addAll(snapshot.collapsed);
    loading = false;
    // Channels lost while the page was away never reappear from the cache.
    refilterRows(lostChannels(snapshot.channelAccess, acceptedAccess));
    return true;
  }

  void saveTaskSnapshot() {
    if (identityAuthority != acceptedIdentity ||
        loading ||
        error != null ||
        rowsView == null) {
      w.resourceSnapshots.remove(snapshotSection);
      if (serverTaskPage) w.resourceSnapshots.dropServerPage(serverTasksPage);
      return;
    }
    final snapshot = TaskSnapshot(
      identity: acceptedIdentity!,
      layout: taskLayout,
      view: rowsView,
      filter: filter,
      rows: rows,
      cursor: cursor,
      hasMore: hasMore,
      totalCount: totalCount,
      lanes: Map.of(lanes),
      laneCursors: Map.of(laneCursors),
      channels: Set.of(taskAdvanced.channels),
      creators: Set.of(taskAdvanced.creators),
      assignees: Set.of(taskAdvanced.assignees),
      collapsed: Set.of(collapsedTaskStatuses),
      channelAccess: acceptedAccess,
      listOffset: taskListOffset,
      boardOffset: taskBoardOffset,
    );
    if (!serverTaskPage) {
      w.resourceSnapshots.write(snapshotSection, snapshot);
      return;
    }
    w.resourceSnapshots.remove(snapshotSection);
    final controller = w;
    final window = holdServerTaskWindow(
      controller.resourceSnapshots,
      client: controller.client,
      events: controller.client.events,
      snapshot: snapshot,
      belongs: (task) => serverTaskBelongs(controller, task),
      channelName: (id) => serverTaskChannelName(controller, id),
      serverId: () => controller.client.serverId,
      identity: () => serverTaskIdentity(controller),
    );
    if (window.attached > 0) window.detach();
  }

  /// Search keeps the results of its recently used queries across visits.
  bool get searchSnapshotted =>
      widget.section == 'search' && widget.channelId == null;

  void restoreSearchWindows() {
    final snapshot = w.resourceSnapshots.read<SearchSnapshot>(
      widget.section,
      identityAuthority,
    );
    if (snapshot == null) return;
    viewWindows
      ..clear()
      ..addAll(snapshot.windows);
    // Channels lost while the page was away never reappear from the cache.
    refilterRows(lostChannels(snapshot.channelAccess, acceptedAccess));
  }

  void saveSearchWindows() {
    if (identityAuthority != acceptedIdentity || error != null) {
      w.resourceSnapshots.remove(widget.section);
      return;
    }
    stashViewWindow();
    if (viewWindows.isEmpty) {
      w.resourceSnapshots.remove(widget.section);
      return;
    }
    w.resourceSnapshots.write(
      widget.section,
      SearchSnapshot(
        identity: acceptedIdentity!,
        windows: Map.of(viewWindows),
        channelAccess: acceptedAccess,
      ),
    );
  }

  bool restoreSnapshot() {
    if (searchSnapshotted) {
      restoreSearchWindows();
      return false;
    }
    if (taskSnapshotted) return restoreTaskSnapshot();
    if (!snapshotted) return false;
    final snapshot = savedPage
        ? takeServerSavedPage(w.resourceSnapshots, identityAuthority)
        : w.resourceSnapshots.read<ResourceSnapshot>(
            widget.section,
            identityAuthority,
          );
    final usable =
        snapshot != null && snapshot.enabledActivity == enabledActivity;
    listOffset = usable ? snapshot.scrollOffset : 0;
    // Track live offsets: children unmount before the owner is disposed.
    if (usable && widget.section == 'activity') {
      filter = snapshot.filter;
      activityScrollOffsets.addAll(snapshot.sectionScrollOffsets);
    }
    listScroll = newActivityScroll();
    if (widget.section == 'activity') activityScrolls[filter] = listScroll!;
    if (!usable) return false;
    rows = snapshot.rows;
    rowsView = snapshot.view;
    hasMore = snapshot.hasMore;
    filter = snapshot.filter;
    activeActivityFilter = snapshot.activeActivityFilter;
    query.text = snapshot.query;
    advanced.channelId = snapshot.channelId;
    advanced.direction = snapshot.direction;
    totalCount = snapshot.totalCount;
    totalUnreadCount = snapshot.totalUnreadCount;
    activityAllCount = snapshot.activityAllCount;
    savedActivityTotal = snapshot.savedActivityTotal;
    activityGroups = snapshot.activityGroups;
    acceptedActivityItems = snapshot.acceptedActivityItems;
    savedActivityItems = snapshot.savedActivityItems;
    doneActivityItems = snapshot.doneActivityItems;
    viewWindows
      ..clear()
      ..addAll(snapshot.viewWindows);
    inboxSerial = snapshot.inboxSerial;
    loading = false;
    // Channels lost while the page was away never reappear from the cache.
    refilterRows(lostChannels(snapshot.channelAccess, acceptedAccess));
    return true;
  }

  void saveSnapshot() {
    if (searchSnapshotted) return saveSearchWindows();
    if (taskSnapshotted) return saveTaskSnapshot();
    if (!snapshotted) return;
    if (identityAuthority != acceptedIdentity ||
        loading ||
        error != null ||
        rowsView == null) {
      w.resourceSnapshots.remove(widget.section);
      if (savedPage) w.resourceSnapshots.dropServerPage(serverSavedPage);
      return;
    }
    viewWindows.remove(rowsView);
    final snapshot = ResourceSnapshot(
      identity: acceptedIdentity!,
      enabledActivity: enabledActivity,
      view: rowsView,
      rows: rows,
      hasMore: hasMore,
      filter: filter,
      activeActivityFilter: activeActivityFilter,
      query: query.text,
      channelId: advanced.channelId,
      direction: advanced.direction,
      totalCount: totalCount,
      totalUnreadCount: totalUnreadCount,
      activityAllCount: activityAllCount,
      savedActivityTotal: savedActivityTotal,
      activityGroups: activityGroups,
      acceptedActivityItems: acceptedActivityItems,
      savedActivityItems: savedActivityItems,
      doneActivityItems: doneActivityItems,
      channelAccess: acceptedAccess,
      scrollOffset: listOffset,
      sectionScrollOffsets: Map.of(activityScrollOffsets),
      viewWindows: Map.of(viewWindows),
      inboxSerial: inboxSerial,
    );
    if (savedPage) {
      keepServerSavedPage(w, snapshot);
      return;
    }
    w.resourceSnapshots.write(widget.section, snapshot);
  }

  /// Id of the newest shared-inbox window this page has presented.
  int inboxSerial = 0;

  /// The window the Activity badge's store accepted since this page last
  /// presented one, when it answers this page's current request shape. Web's
  /// list reads the same inboxStore `items` the badge counts, so opening
  /// Activity paints the arrival that lit the badge on the first frame.
  Map<String, dynamic>? sharedInboxSeed() {
    if (!activityPage ||
        listView != SourceActivityUnreadStore.defaultInboxView) {
      return null;
    }
    return _services.activityUnreadIfBound?.windowSince(inboxSerial);
  }

  /// The Activity badge's store, whose own reads (the retries that wait for
  /// the server's inbox to list a new message, and the immediate read on
  /// return to the foreground) are presented here as they are accepted, rather
  /// than read a second time.
  SourceActivityUnreadStore? sharedInbox;

  void bindSharedInbox() {
    sharedInbox?.removeListener(sharedInboxChanged);
    sharedInbox = activityPage
        ? (_services.activityUnreadIfBound?..addListener(sharedInboxChanged))
        : null;
  }

  void sharedInboxChanged() {
    // A read of this page in flight is at least as new as the store's.
    if (!mounted || activeLoad != null) return;
    final seed = sharedInboxSeed();
    if (seed != null) {
      unawaited(load(keep: true, quietErrors: true, seed: seed));
    }
  }

  StreamSubscription<RaftEvent>? events;
  Timer? refreshTimer, catalogTimer;
  WorkspaceController get w => widget.controller;
  bool get activityPage => widget.section == 'activity';
  WorkspaceServices get _services => w.services;

  /// Source serverTaskPages: the server-wide Tasks page (board and list alike)
  /// walks one cursor per status lane; only a channel's tasks load whole.
  bool get lanePaged =>
      widget.section == 'tasks' &&
      (taskLayout == 'board' || widget.channelId == null);
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
  String? menuRowKey;
  final Set<MenuController> filterMenus = {};
  final dragFeedbackRevision = ValueNotifier<int>(0);
  final _authorityCache = ResourceAuthorityCache();

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
  String get authority => _authorityCache.read(
    identity: (
      origin: w.client.origin,
      generation: w.client.generation,
      principal: w.client.user?.id,
      clientServer: w.client.serverId,
      server: w.server?.id,
      role: w.server?.string('role'),
      section: widget.section,
      channel: widget.channelId,
    ),
    revision: authorityRevision,
    channels: w.channels,
    dms: w.dms,
  );

  String? acceptedIdentity;
  Map<String, Map<String, dynamic>> acceptedAccess = {};
  Map<String, Map<String, dynamic>> get channelAccess => _authorityCache.access;

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
    for (final MapEntry(key: view, value: window)
        in viewWindows.entries.toList()) {
      if (window.rows.any((row) => !keep(row))) {
        viewWindows[view] = ResourceViewWindow(
          rows: window.rows.where(keep).toList(),
          hasMore: window.hasMore,
          totalCount: window.totalCount,
          totalUnreadCount: window.totalUnreadCount,
        );
      }
    }
    for (final MapEntry(key: status, value: lane) in lanes.entries.toList()) {
      if (lane.any((row) => !keep(row))) {
        lanes[status] = lane.where(keep).toList();
      }
    }
    if (selectedSearchKey case final key?
        when key.startsWith('message:') &&
            !rows.any((row) => 'message:${row['id']}' == key)) {
      selectedSearchKey = null;
    }
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
    if (widget.section == 'activity') {
      final retired = activityScrolls.values.toList();
      activityScrolls.clear();
      activityScrollOffsets.clear();
      listOffset = 0;
      listScroll = newActivityScroll();
      activityScrolls['all'] = listScroll!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final scroll in retired) {
          scroll.dispose();
        }
      });
    }
    activityFollowState.clear();
    activityDoneState.clear();
    clearActivityGesture();
    dragFeedbackRevision.value++;
    rows = [];
    rowsView = null;
    viewWindows.clear();
    trailingReconcile = false;
    activityLocalFrontiers.clear();
    activityReadMarkers.clear();
    lanes.clear();
    laneCursors.clear();
    laneBusy.clear();
    laneGeneration++;
    taskTouched.clear();
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
      errorWhileLoading = loading;
      error = userErrorText(cause, where: widget.section);
      searchFailureKind = widget.section == 'search'
          ? classifySearchFailure(cause)
          : null;
      loading = false;
    });
  }

  void authorityChanged({
    Set<String> revoked = const {},
    bool forceAccess = false,
  }) {
    if (!mounted) return;
    _authorityCache.synchronize(w.channels, w.dms, force: forceAccess);
    if (acceptedAuthority == authority) return;
    final identity = identityAuthority, access = channelAccess;
    final sameIdentity = identity == acceptedIdentity;
    final previousAccess = acceptedAccess;
    // A replacement window in flight under the previous facts is retired
    // below; it is reissued where its view is still wanted.
    final replacing = activeLoad != null && !activeAppend;
    acceptedAuthority = authority;
    acceptedIdentity = identity;
    acceptedAccess = access;
    requestGeneration++;
    refreshTimer?.cancel();
    closeDialogs();
    if (sameIdentity &&
        ['activity', 'saved', 'tasks', 'search'].contains(widget.section)) {
      // Channel facts changed under the same principal and role. Only rows of
      // a channel that is actually no longer visible leave; the rest (and the
      // query, filters, loaded pages and scroll position) stay on screen.
      final lost = {...revoked, ...lostChannels(previousAccess, access)};
      if (widget.section == 'search') {
        searchAuthorityChanged(lost, replacing: replacing);
        return;
      }
      setState(() => refilterRows(lost));
      if (widget.section == 'tasks' &&
          !replacing &&
          rowsView != null &&
          acceptsTaskChannel &&
          !channelsGained(previousAccess, access)) {
        // Source keeps the task store live through task events; a channel
        // that only changed or left needs no lane reload.
        return;
      }
      // A first window still in flight keeps its skeleton until this
      // replacement request settles.
      unawaited(load(keep: true, quietErrors: rows.isNotEmpty));
      return;
    }
    if (serverTaskPage) w.resourceSnapshots.dropServerPage(serverTasksPage);
    if (savedPage) w.resourceSnapshots.dropServerPage(serverSavedPage);
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

  /// A channel newly listed or joined can add rows no loaded window has.
  bool channelsGained(
    Map<String, Map<String, dynamic>> previous,
    Map<String, Map<String, dynamic>> next,
  ) => next.entries.any((entry) {
    final before = previous[entry.key];
    return before == null ||
        before['joined'] != true && entry.value['joined'] == true;
  });

  /// Source MessageSearchPage keeps its query, filters and results across
  /// channel directory changes (they are not inputs of its search request).
  /// Only hits in channels that can no longer be seen leave.
  void searchAuthorityChanged(Set<String> lost, {required bool replacing}) {
    final filtered = advanced.channelId;
    final filterLost = filtered != null && lost.contains(filtered);
    setState(() {
      refilterRows(lost);
      if (filterLost && widget.initialSearchChannelId == filtered) {
        // An explicit channel search never falls back to a global one.
        initialSearchUnavailable = true;
      }
    });
    if (filterLost || replacing) {
      unawaited(load(keep: rows.isNotEmpty, quietErrors: rows.isNotEmpty));
    } else if (searchDebounce?.isActive ?? false) {
      scheduleSearch();
    }
  }

  Future<V?> scopedDialog<V>(
    String scope,
    Widget Function(BuildContext) builder, {
    bool sourceModal = false,
    bool form = false,
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
      return await showRaftWindow<V>(
        context,
        buildOwned,
        modal: sourceModal,
        form: form,
      );
    } finally {
      dialogs.remove(owned);
    }
  }

  /// The Web `ContextMenuPopup` / base-ui ContextMenu: a transparent dismiss
  /// backdrop and a popup placed at the pointer, never a centred modal.
  /// [rowKey] keeps that row in its popup-open state while the menu is up.
  Future<V?> scopedMenu<V>(
    String scope,
    Offset at,
    Widget Function(BuildContext) builder, {
    String? rowKey,
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

    setState(() => menuRowKey = rowKey);
    try {
      return await showRaftMessageContextMenu<V>(
        context: context,
        anchor: at,
        builder: buildOwned,
      );
    } finally {
      dialogs.remove(owned);
      if (mounted && menuRowKey == rowKey) setState(() => menuRowKey = null);
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
    final inbox = activityPage ? _services.activityUnreadIfBound : null;
    events = (inbox?.pageEvents ?? client.events).listen((event) {
      if (!mounted || !identical(client, w.client)) return;
      if (SourceActivityUnreadStore.changesAuthority(event.name)) {
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
        authorityChanged(revoked: revoked, forceAccess: true);
        return;
      }
      if (['search', 'saved'].contains(widget.section) &&
          catalogEvent(event.name, machines: widget.section == 'search')) {
        // Refresh the identity directory without clearing it or the user's
        // sender filter; high-frequency presence events do not touch it.
        final scope = authority;
        catalogTimer?.cancel();
        catalogTimer = Timer(const Duration(milliseconds: 150), () {
          if (!accepts(scope)) return;
          catalogScope = null;
          unawaited(loadSenders(scope));
        });
      }
      if (['search', 'saved'].contains(widget.section) &&
          event.name == 'message:updated') {
        patchMessage(event.payload);
        return;
      }
      if (widget.section == 'saved' && event.name == 'message:deleted') {
        dropSavedMessage(event.payload);
        return;
      }
      if (activityPage &&
          (event.name == 'task:updated' || event.name == 'task:created')) {
        patchActivityTasks(event.payload);
        return;
      }
      final relevant = switch (widget.section) {
        'activity' => SourceActivityUnreadStore.reconcilesPage(event.name),
        // Source catchUpServerTasksOnReconnect: events missed while the
        // socket was down are recovered by revalidating the loaded lanes.
        'tasks' => event.name.startsWith('task:') || event.name == 'connected',
        'agents' => event.name.startsWith('agent:'),
        'computers' =>
          event.name.startsWith('machine:') || event.name.startsWith('daemon:'),
        'members' => event.name.startsWith('server:member'),
        _ => false,
      };
      if (relevant) {
        if (activityPage) patchActivity(event);
        if (widget.section == 'tasks' && patchTasks(event)) return;
        if (inbox?.ownsPageRefresh(
              event,
              view: listView,
              loadedRows: rows.length,
            ) ==
            true) {
          return;
        }
        final scope = authority;
        refreshTimer?.cancel();
        refreshTimer = Timer(const Duration(milliseconds: 150), () {
          if (accepts(scope)) unawaited(reconcile());
        });
      }
    });
  }

  static const presenceEvents = {
    'agent:activity',
    'agent:session',
    'agent:seen',
    'agent:read',
    'machine:status',
  };

  /// Events that can change the sender catalog: agent and member identities,
  /// and (Search only, whose catalog lists computers by name, hostname and
  /// OS) the machine list. Presence and machine status never change them.
  bool catalogEvent(String name, {required bool machines}) =>
      !presenceEvents.contains(name) &&
      (name.startsWith('agent:') ||
          (machines && name.startsWith('machine:')) ||
          name.startsWith('server:member'));

  /// message:updated is merge-only: patch the matching saved/search row by
  /// message id instead of reloading the page.
  void patchMessage(Object? payload) {
    final next = mergeSavedRow(
      rows,
      payload,
      byMessageId: widget.section == 'saved',
    );
    if (next != null) setState(() => rows = next);
  }

  void dropSavedMessage(Object? payload) {
    final next = omitSavedMessage(
      rows: rows,
      windows: viewWindows,
      totalCount: totalCount,
      payload: payload,
    );
    if (next == null) return;
    setState(() {
      rows = next.rows;
      totalCount = next.totalCount;
      viewWindows
        ..clear()
        ..addAll(next.windows);
    });
  }

  /// Source taskRealtimeSync: task:created/updated/deleted upsert, move or
  /// remove the single task by id. False when the payload does not identify
  /// a task, so the caller revalidates the loaded windows instead.
  bool patchTasks(RaftEvent event) {
    switch (classifyTaskEvent(event, serverId: w.client.serverId)) {
      case TaskEventIgnored():
        return true;
      case TaskEventUnrecognized():
        return false;
      case TaskEventPatch(:final patches):
        // A window in flight predates these facts; they are applied over it.
        taskTouched.addAll(patches);
        final before = rows;
        applyTaskPatches(patches);
        if (!identical(before, rows)) setState(() {});
        return true;
    }
  }

  /// Whether [task] belongs to this page and its current view.
  bool taskBelongs(Map<String, dynamic> task) {
    if (!raftTaskStatuses.contains(task['status'])) return false;
    if (!lanePaged && filter != 'all' && task['status'] != filter) {
      return false;
    }
    if (widget.channelId != null) return task['channelId'] == widget.channelId;
    return serverTaskBelongs(w, task);
  }

  /// The accepted task with [id], wherever it is shown.
  Map<String, dynamic>? taskById(Object? id) =>
      id is! String ? null : rows.where((row) => row['id'] == id).firstOrNull;

  /// Apply live task facts (null = deleted) to the board lanes or the list
  /// in place. Unchanged rows keep their objects. Callers rebuild.
  void applyTaskPatches(Map<String, Map<String, dynamic>?> patches) {
    final slice = TaskBoardSlice(
      lanes: lanes,
      laneCursors: laneCursors,
      rows: rows,
      totalCount: totalCount,
      board: lanePaged,
    );
    if (!patchTaskBoard(
      patches,
      slice,
      belongs: taskBelongs,
      channelName: (id) => serverTaskChannelName(w, id),
    )) {
      return;
    }
    rows = slice.rows;
    totalCount = slice.totalCount;
    dragFeedbackRevision.value++;
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

  /// Source applyTaskToInboxItems: a task fact overlays the thread rows whose
  /// parent message is the task's message.
  void patchActivityTasks(Object? payload) {
    if (!activityRowsLive || payload is! Map) return;
    final tasks = [
      if (payload['tasks'] is List) ...payload['tasks'] as List,
      if (payload['task'] is Map) payload['task'],
    ];
    var next = rows, accepted = acceptedActivityItems;
    for (final task in tasks) {
      if (task is! Map) continue;
      next = applyTaskToActivityRows(next, task);
      accepted = applyTaskToActivityRows(accepted, task);
    }
    if (identical(next, rows) && identical(accepted, acceptedActivityItems)) {
      return;
    }
    setState(() {
      rows = next;
      acceptedActivityItems = accepted;
    });
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
  ({List<Map<String, dynamic>> rows, int cleared, int removed}) applyKnownReads(
    List<Map<String, dynamic>> source, {
    Map<String, int> facts = const {},
  }) {
    final server = w.client.serverId, user = w.client.user?.id;
    if (server == null || user == null) {
      return (rows: source, cleared: 0, removed: 0);
    }
    var cleared = 0, removed = 0, changed = false;
    final next = <Map<String, dynamic>>[];
    final now = widget.clock?.call() ?? DateTime.now();
    activityReadMarkers.removeWhere((_, marker) => now.isAfter(marker.until));
    for (final row in source) {
      final scope = activityScopeId(row);
      final marker = activityReadMarkers[rowKey(row)]?.frontier;
      final state = scope == null
          ? null
          : w.readState.state(server, user, scope);
      final ledger = state?['maxReadSeq'], frame = facts[scope];
      final read = [
        if (ledger is int) ledger,
        ?frame,
      ].fold<int?>(null, (a, b) => a == null || b > a ? b : a);
      final readSeq = read == null ? null : BigInt.from(read);
      final projected = projectFullyRead(
        row,
        marker != null && (readSeq == null || marker > readSeq)
            ? marker
            : readSeq,
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
    unawaited(
      platformDoubleClickInterval().then((interval) {
        if (mounted) setState(() => doubleClickInterval = interval);
      }),
    );
    bindAuthors();
    acceptedAuthority = authority;
    acceptedIdentity = identityAuthority;
    acceptedAccess = channelAccess;
    query.text = widget.initialQuery ?? '';
    lastPublishedQuery = widget.initialQuery ?? '';
    lastSearchEditingValue = query.value;
    // The Search page re-queries when an IME composition commits. Every other
    // section shares `query` for its own filter field (Activity find, Saved,
    // Tasks); there the listener would drop the rows and queue a second load.
    if (widget.section == 'search') {
      query.addListener(searchCompositionCommitted);
    }
    if (widget.section == 'search') {
      widget.searchFocusRequests?.addListener(focusSearchField);
      // Source MessageSearchPage focuses the field on mount (and selects a
      // restored query). A phone keeps the keyboard down until a tap.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            MediaQuery.sizeOf(context).width >=
                RaftLayoutMetrics.desktopBreakpoint) {
          focusSearchField();
        }
      });
    }
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
    final restoredMemory = restoreSearchMemorySync();
    if (restoredMemory) {
      lastPublishedQuery = query.text.trim();
      lastSearchEditingValue = query.value;
    }
    w.addListener(authorityChanged);
    subscribeEvents();
    bindSharedInbox();
    unawaited(
      activateSearchMemory(
        restore: widget.restoreSearchState,
        restored: restoredMemory,
      ),
    );
    final restored = restoreSnapshot();
    final seed = sharedInboxSeed();
    if (seed != null) {
      // The badge's window is accepted data: present it before any request,
      // then revalidate in place.
      unawaited(load(keep: true, quietErrors: true, seed: seed));
      unawaited(load(keep: true, quietErrors: true));
    } else if (restored) {
      // Cached rows are on screen at once; revalidate them in place.
      unawaited(load(keep: true, quietErrors: true));
    } else {
      load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bindSectionActivity();
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

  ValueListenable<TickerModeData>? sectionActivity;
  void bindSectionActivity() {
    final next = TickerMode.getValuesNotifier(context);
    if (!identical(next, sectionActivity)) {
      sectionActivity?.removeListener(sectionActivityChanged);
      sectionActivity = next;
      next.addListener(sectionActivityChanged);
    }
    sectionActivityChanged();
  }

  void sectionActivityChanged() {
    // Activity gates reads, not task-list presentation. Observe the notifier
    // directly so switching sections does not rebuild this unchanged list.
    tabActive = sectionActivity?.value.enabled ?? true;
    if (tabActive && reloadWhenActive) {
      reloadWhenActive = false;
      unawaited(load(keep: true, quietErrors: true));
    }
  }

  @override
  void activate() {
    super.activate();
    bindSectionActivity();
  }

  @override
  void didUpdateWidget(covariant ResourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, w) ||
        oldWidget.section != widget.section) {
      bindAuthors();
    }
    if (!identical(oldWidget.controller, w)) {
      final section = oldWidget.section;
      if (oldWidget.channelId == null &&
          (section == serverTasksPage || section == serverSavedPage)) {
        final previous = oldWidget.controller.resourceSnapshots.serverPage(
          section,
        );
        if (previous != null && previous.attached > 0) previous.detach();
      }
      oldWidget.controller.removeListener(authorityChanged);
      w.addListener(authorityChanged);
    }
    if (!identical(oldWidget.controller, w) ||
        oldWidget.section != widget.section) {
      events?.cancel();
      bindSharedInbox();
      subscribeEvents();
    }
    authorityChanged();
    if (activityPage &&
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
    sectionActivity?.removeListener(sectionActivityChanged);
    events?.cancel();
    events = null;
    saveSnapshot();
    if (widget.section == 'activity') {
      for (final scroll in activityScrolls.values) {
        scroll.dispose();
      }
    } else {
      listScroll?.dispose();
    }
    taskListScroll?.dispose();
    taskBoardScroll?.dispose();
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
    authorDirectory?.removeListener(authorsChanged);
    authorDirectory?.dispose();
    authorDirectory = null;
    searchDebounce?.cancel();
    clearActivityGesture();
    widget.searchFocusRequests?.removeListener(focusSearchField);
    queryFocus.dispose();
    query.dispose();
    events?.cancel();
    sharedInbox?.removeListener(sharedInboxChanged);
    refreshTimer?.cancel();
    catalogTimer?.cancel();
    super.dispose();
  }

  /// [keep] revalidates in place: accepted rows stay on screen (no loading
  /// skeleton), the request spans the loaded window and the response merges
  /// by item key. [quietErrors] retains the accepted window on a transient
  /// failure, as Source's background reset does.
  bool tabActive = true, reloadWhenActive = false;

  Future<void> load({
    bool append = false,
    bool keep = false,
    bool quietErrors = false,
    Map<String, dynamic>? seed,
  }) async {
    if (widget.section == 'tasks' && widget.channelId != null && !tabActive) {
      reloadWhenActive = true;
      return;
    }
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
        searchFailureKind = null;
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
    if (seed == null &&
        ['search', 'tasks', 'activity', 'saved'].contains(widget.section)) {
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
    final wanted = !keep && !append ? listView : null;
    final cached = wanted == null ? null : viewWindows[wanted];
    if (cached != null &&
        !(widget.section == 'activity' && activityFollowState.busy)) {
      // A view shown before returns at once and revalidates in place.
      setState(() {
        stashViewWindow();
        viewWindows.remove(wanted);
        rows = cached.rows;
        rowsView = wanted;
        hasMore = cached.hasMore;
        totalCount = cached.totalCount;
        if (!activityScope.directMessages) {
          totalUnreadCount = cached.totalUnreadCount;
        }
        loading = false;
        error = null;
        laneBusy.clear();
        laneGeneration++;
      });
      keep = true;
    } else if (!keep) {
      setState(() {
        loading = true;
        error = null;
        laneBusy.clear();
        laneGeneration++;
        if (!append &&
            ['search', 'saved', 'activity'].contains(widget.section) &&
            !enabledActivity &&
            !(widget.section == 'activity' && activityFollowState.busy)) {
          stashViewWindow();
          rows = [];
          rowsView = null;
          cursor = null;
          hasMore = false;
        }
      });
    }
    activeLoad = request;
    activeAppend = append;
    if (widget.section == 'tasks' && !append) taskTouched.clear();
    if (enabledActivity && !activityScope.globalInbox && !append) {
      unawaited(loadActivityFacets(scope));
    }
    try {
      if (lanePaged) {
        final boardView = jsonEncode([taskPath, 'board']);
        // Source loadServerTaskStatusPage: a background revalidation spans
        // each lane's loaded window instead of resetting it to one page.
        final revalidate = keep && rowsView == boardView;
        final windows = {
          for (final status in raftTaskStatuses)
            status: revalidate
                ? (lanes[status]?.length ?? 0).clamp(30, 100).toInt()
                : 30,
        };
        final pages = await Future.wait(
          raftTaskStatuses.map(
            (status) => w.query(
              taskPath,
              query: {
                'status': status,
                'detail': 'summary',
                'limit': windows[status],
              },
            ),
          ),
        );
        if (!accepts(scope, request)) return;
        // A lane holds only its own status (`moreLane` applies the same rule).
        final fetched = {
          for (var i = 0; i < raftTaskStatuses.length; i++)
            raftTaskStatuses[i]: (pages[i]['tasks'] as List)
                .map((r) => Map<String, dynamic>.from(r))
                .where(
                  (r) =>
                      (r['status'] ?? raftTaskStatuses[i]) ==
                      raftTaskStatuses[i],
                )
                .toList(),
        };
        final fetchedIds = {
          for (final lane in fetched.values)
            for (final row in lane) row['id'],
        };
        setState(() {
          for (var i = 0; i < raftTaskStatuses.length; i++) {
            final status = raftTaskStatuses[i];
            final window = reconcileTaskWindow(
              fetched: fetched[status]!,
              current: lanes[status] ?? const [],
              fetchedCursor: pages[i]['next_cursor'] as String?,
              currentCursor: laneCursors[status],
              window: revalidate ? windows[status]! : 1 << 30,
              fetchedIds: fetchedIds,
            );
            lanes[status] = window.rows;
            laneCursors[status] = window.cursor;
          }
          rowsView = boardView;
          if (keep) error = null;
          applyTaskPatches(taskTouched);
          taskTouched.clear();
          rows = lanes.values.expand((r) => r).toList();
          dragFeedbackRevision.value++;
        });
        return;
      }
      final path = switch (widget.section) {
        'activity' => activityScope.path,
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
      final windowSize = keep && seed == null
          ? rows.length.clamp(pageSize, 100).toInt()
          : pageSize;
      // A background revalidation of the task list spans its loaded pages.
      final taskListWindow = widget.section == 'tasks' && keep
          ? rows.length.clamp(50, 100).toInt()
          : 50;
      final params = widget.section == 'search'
          ? advanced.search(query.text, offset: append ? rows.length : 0)
          : ['saved', 'activity'].contains(widget.section)
          ? advanced.list(
              query.text,
              offset: append ? rows.length : 0,
              limit: windowSize,
              activityView: widget.section == 'activity' ? filter : null,
            )
          : {
              if (widget.section == 'tasks' && filter != 'all')
                'status': filter,
              if (widget.section == 'tasks') 'detail': 'summary',
              if (query.text.trim().isNotEmpty && widget.section != 'tasks')
                'q': query.text.trim(),
              'limit': taskListWindow,
              if (append && widget.section == 'tasks' && cursor != null)
                'cursor': cursor,
              if (widget.section != 'tasks') 'offset': append ? rows.length : 0,
            };
      final view = ResourceFilters.viewKey(path, params ?? const {});
      final sharedSerial = _services.activityUnreadIfBound?.windowSerial ?? 0;
      var value =
          seed ??
          (path == '/channels/inbox'
              ? await w.sharedQuery(path, query: params)
              : await w.query(path, query: params));
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
            widget.section == 'activity' && !['saved', 'done'].contains(filter);
        var unreadDelta = 0;
        if (activityWindow) {
          final known = applyKnownReads(accepted);
          accepted = known.rows;
          unreadDelta -= known.cleared;
        }
        final List<Map<String, dynamic>> nextRows;
        var nextCursor = value is Map ? value['next_cursor'] as String? : null;
        if (append) {
          final known = {for (final row in rows) rowKey(row)};
          nextRows = [
            ...rows,
            // A live-inserted task may also arrive on its page.
            ...accepted.where(
              (row) =>
                  widget.section != 'tasks' || !known.contains(rowKey(row)),
            ),
          ];
        } else if (keep && view == rowsView && widget.section == 'tasks') {
          final window = reconcileTaskWindow(
            fetched: accepted,
            current: rows,
            fetchedCursor: nextCursor,
            currentCursor: cursor,
            window: taskListWindow,
            fetchedIds: {for (final row in accepted) row['id']},
          );
          nextRows = window.rows;
          nextCursor = window.cursor;
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
                    (filter == 'all' || activityScope.directMessages) &&
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
          if (widget.section == 'activity' &&
              !append &&
              view == SourceActivityUnreadStore.defaultInboxView) {
            inboxSerial = sharedSerial;
          }
          if (keep) error = null;
          if (enabledActivity && filter == 'saved') {
            savedActivityItems = List.of(rows);
          }
          if (widget.section == 'saved' ||
              enabledActivity && filter == 'saved') {
            SavedCountStore.of(w).know([
              for (final row in rows)
                if (row['messageId'] is String) row['messageId'] as String,
            ]);
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
            totalCount = ((value['total'] ?? value['totalCount']) as num?)
                ?.toInt();
            if (widget.section != 'activity' || !activityScope.directMessages) {
              totalUnreadCount = (value['totalUnreadCount'] as num?)?.toInt();
            }
          }
          if (widget.section == 'activity' &&
              activityScope.globalInbox &&
              value is Map) {
            acceptActivityFacets(value, rows);
          }
          cursor = nextCursor;
          hasMore = widget.section == 'tasks'
              ? cursor != null
              : value is Map && value['hasMore'] == true;
          if (widget.section == 'tasks' && !append) {
            applyTaskPatches(taskTouched);
            taskTouched.clear();
          }
        });
        if (seed == null &&
            widget.section == 'activity' &&
            activityScope.globalInbox &&
            value is Map &&
            value['totalUnreadCount'] is num) {
          widget.onActivityUnreadAccepted?.call(
            (value['totalUnreadCount'] as num).toInt(),
          );
        }
        if (seed == null &&
            widget.section == 'activity' &&
            activityScope.globalInbox &&
            value is Map) {
          acceptActivityWindow?.call(
            value,
            firstPage:
                !append && view == SourceActivityUnreadStore.defaultInboxView,
          );
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
      final result = await w.client.request(method, path, data: data);
      if (!accepts(scope)) return;
      await w.refreshUnread();
      if (!accepts(scope)) return;
      // Source taskStore applies the task a mutation returns (or removes the
      // deleted one) instead of reloading every lane.
      final deleted = RegExp(r'^/tasks/([^/]+)$').firstMatch(path)?.group(1);
      final task = result is Map && result['task'] is Map
          ? Map<String, dynamic>.from(result['task'] as Map)
          : null;
      if (widget.section == 'tasks' &&
          rows.isNotEmpty &&
          (method == 'DELETE' && deleted != null ||
              task != null && task['id'] is String)) {
        final patch = method == 'DELETE' && deleted != null
            ? <String, Map<String, dynamic>?>{deleted: null}
            : {task!['id'] as String: task};
        taskTouched.addAll(patch);
        setState(() => applyTaskPatches(patch));
        return;
      }
      // Revalidate in place: an accepted list never blanks behind its own
      // mutation (Mark all read, Remove saved message, task status).
      await load(keep: rows.isNotEmpty);
    } catch (e) {
      fail(e, scope);
    }
  }

  /// Source savedStore `unsaveMessage`: the row, the page totals and the
  /// sidebar badge go at once; a failed request restores them (Source then
  /// reloads, which also reconciles the list).
  Future<void> removeSaved(Map<String, dynamic> row, String scope) {
    return unsaveSavedRow(
      accepts: () => accepts(scope),
      row: row,
      readRows: () => rows,
      readSavedActivityItems: () => savedActivityItems,
      readTotalCount: () => totalCount,
      readSavedActivityTotal: () => savedActivityTotal,
      activitySaved: () => enabledActivity && filter == 'saved',
      apply: (next) => setState(() {
        rows = next.rows;
        savedActivityItems = next.savedActivityItems;
        totalCount = next.totalCount;
        savedActivityTotal = next.savedActivityTotal;
      }),
      store: SavedCountStore.of(w),
      refreshUnread: w.refreshUnread,
      reload: () => load(keep: true),
      fail: (cause) => fail(cause, scope),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (snapshotted) observeListUpdates();
    // ThreadsInbox mounts ActivityInboxPanel with `theme-brutal:!border-l`.
    final activityEdge = widget.section == 'activity';
    // Shared edge rule (RaftPanelEdge): the Activity panel keeps its line
    // beside the navigation column, except on the full-width phone page and
    // when the column is on the right (it draws that line).
    final BoxDecoration? surface = activityEdge
        ? BoxDecoration(
            color: t.brutal ? t.panel : t.sidebar,
            border: RaftPanelEdge.besideNavigation(
              context,
              RaftPanelEdgeStyle.activityInbox,
            ),
          )
        // SavedPanel: `bg-layer-canvas-muted theme-brutal:bg-white`.
        : widget.section == 'saved'
        ? BoxDecoration(color: t.brutal ? t.panel : t.sidebar)
        : widget.section == 'search'
        ? searchSlots(context).frame.decoration(rui.RaftRecipeTokens(t))
        // TasksPanelViewport is `dark:bg-transparent`: Elegant dark shows the
        // mounted ancestor, ConversationPanelContent's card in a channel tab
        // and the canvas-muted page surface on the Tasks page.
        : widget.section == 'tasks' && t.dark && !t.brutal
        ? BoxDecoration(
            color: widget.channelId != null
                ? t.card
                : t.colors['layer-canvas-muted']!,
          )
        : null;
    final bodyChild = widget.section == 'tasks'
        ? DefaultTextStyle.merge(
            style: RaftTaskSectionRecipe(t).documentStyle,
            child: buildBody(context),
          )
        : buildBody(context);
    final box = Container(decoration: surface, child: bodyChild);
    // The page surface (and the Activity edge) is the column's top surface
    // under a transparent header, so it continues under the status bar.
    final body = surface == null
        ? box
        : RaftStatusBarSource(
            color: surface.color ?? Colors.transparent,
            border: surface.border is Border ? surface.border as Border : null,
            child: box,
          );
    // Activity find: Cmd+F on Apple platforms, Ctrl+F elsewhere, while the
    // keyboard scope is the Activity panel (ActivityFindScope).
    return widget.section == 'activity'
        ? ActivityFindScope(
            enabled: enabledActivity && widget.compactActivitySidebar,
            onFind: showActivitySearch,
            child: body,
          )
        : body;
  }

  Widget buildBody(BuildContext context) {
    final scope = authority;
    final body = buildBodyColumn(context, scope);
    return widget.section == 'search'
        ? Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: searchKeyEvent,
            child: body,
          )
        : body;
  }

  Widget buildBodyColumn(BuildContext context, String scope) {
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
                      contextMenuBuilder: RaftTextSelectionToolbar.editableText,
                      autofillHints: null,
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
                  RaftTooltip(
                    message: raftText(
                      context,
                      taskLayout == 'board'
                          ? 'Show task list'
                          : 'Show task board',
                    ),
                    child: IconButton(
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
                  ),
                if (widget.section == 'tasks')
                  RaftTooltip(
                    message: raftText(context, 'Create task'),
                    child: IconButton(
                      onPressed: w.server?.string('role') == 'guest'
                          ? null
                          : () => createTask(sourceScope: scope),
                      icon: const RaftIcon(RaftGlyph.plus, size: 12),
                    ),
                  ),
                if (widget.section == 'activity')
                  RaftTooltip(
                    message: raftText(context, 'Activity actions'),
                    child: PopupMenuButton<String>(
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
        // Web Inbox and Saved render no error line when the first read fails:
        // the (empty) list stays as is.
        // Search shows its failure as a card inside the results instead.
        if (error != null &&
            !(widget.section == 'search' && searchFailureKind != null) &&
            !(errorWhileLoading &&
                rows.isEmpty &&
                (widget.section == 'activity' || widget.section == 'saved')))
          Padding(
            padding: const EdgeInsets.all(16),
            child: RaftErrorBanner(error!, small: true),
          ),
        Expanded(
          child:
              widget.section == 'activity' &&
                  !widget.compactActivitySidebar &&
                  MediaQuery.sizeOf(context).width <
                      RaftLayoutMetrics.desktopBreakpoint &&
                  activitySections.contains(filter)
              ? RaftSectionPager<String>(
                  key: ValueKey(identityAuthority),
                  sections: activitySections,
                  value: filter,
                  onChanged: (value) => selectActivitySection(value, scope),
                  unvisitedBuilder: (_) => const RaftActivityLoadingList(),
                  builder: (context, value) => value == filter
                      ? resourceResults(context)
                      : inactiveActivitySection(value),
                )
              : resourceResults(context),
        ),
      ],
    );
  }

  List<String> get activitySections => enabledActivity
      ? [for (final view in RaftActivityView.values) view.name]
      : const ['all', 'unread', 'mentions'];

  Widget resourceResults(BuildContext context) {
    final results = resourceResultsPager(context);
    if (widget.section != 'search') return results;
    // SearchShellViewport: `bg-layer-panel` (transparent in dark, Brutal white).
    final fill = searchSlots(context).viewport
        .decoration(rui.RaftRecipeTokens(RaftTokens.of(context)));
    return DecoratedBox(decoration: fill, child: results);
  }

  Widget resourceResultsPager(BuildContext context) {
    final scope = authority, view = filter;
    // Inside each pager page: a wrapper outside PageView would receive the
    // horizontal pager's notifications instead of this vertical list's.
    return RaftPullToRefresh(
      enabled: mobileActivityRefresh,
      onRefresh: () =>
          accepts(scope) && filter == view ? load(keep: true) : Future.value(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // A blank tap has no item identity and ends double-click recognition.
        // Nested card actions win their tap arena; filters/details are outside.
        onTap: widget.section == 'activity' && activityGestureCurrent
            ? () => setState(clearActivityGesture)
            : null,
        child: resourceResultsBody(context),
      ),
    );
  }

  bool get mobileActivityRefresh =>
      widget.section == 'activity' && RaftAdaptiveWorkspace.compactOf(context);

  Widget resourceResultsBody(BuildContext context) {
    final scope = authority;
    final searchHomeNow = atSearchHome;
    // Search keeps its summary, entity matches and a messages skeleton while
    // the first read is in flight (Source `showInitialSkeleton`).
    final searching = loading && visibleRows.isEmpty;
    return searching && !(widget.section == 'search' && !searchHomeNow)
        // ConversationCardSkeleton: Inbox and Saved share the card
        // placeholder list.
        ? enabledActivity ||
                  widget.section == 'activity' ||
                  widget.section == 'saved'
              ? const RaftActivityLoadingList()
              : widget.section == 'tasks'
              ? const RaftTaskLoadingList()
              : Center(child: CircularProgressIndicator())
        : searchHomeNow
        ? searchHome(scope)
        : widget.section == 'search'
        ? ResourceSearchResults(
            key: PageStorageKey(('search-results', scrollView)),
            query: query.text,
            rows: rows,
            entities: currentSearchEntities,
            origin: w.client.origin,
            agents: rowAgents,
            members: rowPeople,
            currentUser: w.client.user?.json,
            plan: w.server?.string('plan', 'free') ?? 'free',
            now: widget.clock?.call() ?? DateTime.now(),
            selectedKey: selectedSearchKey ?? firstSearchKey,
            onMessage: (row) => openSearchMessage(row, scope),
            onEntity: (entity) => openSearchEntity(entity, scope),
            hasMore: hasMore,
            onMore: () => load(append: true),
            loading: searching,
            failure: error == null ? null : searchFailureKind,
            onRetry: () => load(),
            onSortRecent: advanced.searchSort == 'recent'
                ? null
                : () {
                    advanced.searchSort = 'recent';
                    load();
                  },
          )
        : widget.section == 'tasks' &&
              widget.channelId != null &&
              !loading &&
              (taskLayout == 'board'
                  ? lanes.values.every((lane) => lane.isEmpty)
                  : rows.isEmpty)
        ? channelTasksEmpty()
        : widget.section == 'tasks' && taskLayout == 'board'
        ? taskBoard()
        : widget.section == 'tasks' && rows.isNotEmpty
        ? groupedTasks()
        : visibleRows.isEmpty
        ? LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              primary: false,
              physics: mobileActivityRefresh
                  ? const AlwaysScrollableScrollPhysics()
                  : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: widget.section == 'activity' || widget.section == 'saved'
                    // ui/EmptyState: Inbox and Saved share the product empty
                    // state (recipe icon tile, title, copy).
                    ? RaftProductEmptyState(
                        title: widget.section == 'saved'
                            ? raftText(context, 'No saved messages yet')
                            : raftText(context, activityEmptyTitle),
                        description: widget.section == 'saved'
                            ? raftText(
                                context,
                                'Save a message by selecting its bookmark icon.',
                              )
                            : raftText(context, activityEmptyDetail),
                        icon: (context, size, color) => RaftIcon(
                          widget.section == 'saved' || filter == 'saved'
                              ? RaftGlyph.bookmark
                              : filter == 'done'
                              ? RaftGlyph.checkCircle2
                              : RaftGlyph.messageSquareText,
                          size: size,
                          color: color,
                        ),
                      )
                    : RaftEmptyState(
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
            child: Stack(
              children: [
                Positioned.fill(child: resourceList()),
                if (snapshotted && listUpdates.count > 0)
                  RaftNewUpdatesButton(
                    label: raftFormat(
                      context,
                      listUpdates.count == 1
                          ? '{count} new update'
                          : '{count} new updates',
                      {'count': listUpdates.count},
                    ),
                    onPressed: revealListUpdates,
                  ),
              ],
            ),
          );
  }

  /// A neighboring page is a pure projection of its accepted window. It
  /// never issues reads, appends pages or registers another data owner.
  Widget inactiveActivitySection(String value) {
    final window = viewWindows[listViewFor(value)];
    if (window == null) return const RaftActivityLoadingList();
    if (window.rows.isEmpty) {
      return RaftEmptyState(
        title: activityEmptyState(value).title,
        detail: activityEmptyState(value).detail,
      );
    }
    if (advanced.groupByChannel) {
      return groupedActivity(viewFilter: value, windowRows: window.rows);
    }
    return ListView.separated(
      key: PageStorageKey(('resource-list', 'activity', value)),
      primary: false,
      padding: raftScrollPadding(
        context,
        RaftResourceMetrics.activityListInset,
      ),
      controller: activityScrolls[value],
      itemCount: window.rows.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: RaftConversationCardRecipe.gap),
      itemBuilder: (_, i) =>
          activityCard(window.rows[i], authority, viewFilter: value),
    );
  }

  /// Activity/Saved rows newest first. Rows keep their element when rows land
  /// above them, and the reading anchor keeps the reader's row in place.
  Widget resourceList() {
    final shown = visibleRows;
    final list = ListView.separated(
      key: snapshotted
          ? PageStorageKey(('resource-list', widget.section, filter))
          : PageStorageKey((
              'resource-list',
              widget.section,
              widget.channelId,
              listView,
            )),
      controller: listScroll,
      physics: mobileActivityRefresh
          ? const AlwaysScrollableScrollPhysics()
          : null,
      padding: raftScrollPadding(context, const EdgeInsets.all(16)),
      // SavedPanel loads the next page when its sentinel comes
      // within `rootMargin: 240px` of the scroller.
      scrollCacheExtent: widget.section == 'saved'
          ? const ScrollCacheExtent.pixels(240)
          : null,
      itemCount: shown.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) =>
          const SizedBox(height: RaftConversationCardRecipe.gap),
      itemBuilder: (context, index) => index == shown.length
          ? widget.section == 'saved'
                ? savedSentinel()
                : TextButton(
                    onPressed: () => load(append: true),
                    child: Text(raftText(context, 'Load more')),
                  )
          : KeyedSubtree(
              key: listUpdates.keyOf(rowKey(shown[index])),
              child: item(shown[index]),
            ),
      findItemIndexCallback: listUpdates.indexOf,
    );
    return snapshotted
        ? RaftReadingAnchor(controller: listUpdates.anchor, child: list)
        : list;
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
    if (!accepts(scope) ||
        !rows.any((r) => identical(r, row) || r['id'] == row['id'])) {
      return;
    }
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
      // The DM is usually already in the sidebar: open it at once; only a
      // first conversation asks the server to create it.
      final existing = w.dms
          .where(
            (c) =>
                c.json['peerId'] == entity.id &&
                c.json['peerType'] ==
                    (entity.kind == 'agent' ? 'agent' : 'user'),
          )
          .firstOrNull;
      if (existing != null) {
        rememberSearchOpen(scope, entity: entity, queryText: committed);
        await widget.onMessage(existing.id, null);
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
    scheduleSearch();
  }

  void scheduleSearch() {
    searchDebounce?.cancel();
    final scope = authority;
    searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (accepts(scope)) load();
    });
  }

  /// No query and no filter yet: history and frequent destinations.
  bool get atSearchHome =>
      widget.section == 'search' &&
      query.text.trim().isEmpty &&
      (!advanced.hasSearchFilter || widget.initialSearchDeferUntilQuery);

  /// Selectable results in order: destinations, then messages (Source
  /// `selectableResults`).
  List<String> get searchKeys => [
    ...(atSearchHome ? frequentEntities : currentSearchEntities).map(
      (e) => e.key,
    ),
    ...rows.map((r) => 'message:${r['id']}'),
  ];

  /// The cursor before any arrow key: the first selectable result.
  String? get firstSearchKey => searchKeys.firstOrNull;

  /// Cmd/Ctrl+K on the Search page and its first frame (Source
  /// `focusSearchInput`): focus the field and select what it holds.
  void focusSearchField() {
    if (!mounted) return;
    queryFocus.requestFocus();
    if (query.text.isNotEmpty) {
      query.selection = TextSelection(
        baseOffset: 0,
        extentOffset: query.text.length,
      );
    }
  }

  /// Source `handleRailKeyDown`, scoped to the Search page subtree so it runs
  /// wherever focus sits inside it (field, filter chips, a result), and never
  /// once focus moves to a conversation beside it. Up/Down move the cursor
  /// (repeating while held), Escape leaves Search. IME composition owns every
  /// key it is using.
  KeyEventResult searchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (query.value.composing.isValid && !query.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      widget.onBack?.call();
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final keys = searchKeys;
    if (keys.isEmpty) return KeyEventResult.ignored;
    final index = keys.indexOf(selectedSearchKey ?? keys.first);
    final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
    setState(
      () => selectedSearchKey = keys[(index + step).clamp(0, keys.length - 1)],
    );
    return KeyEventResult.handled;
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
    final row = Row(
      children: [
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
          child: RaftSearchInput(
            controller: query,
            focusNode: queryFocus,
            // search.placeholder: the shortcut hint follows on desktop.
            hint: mobile
                ? raftText(context, 'Search channels, DMs, messages…')
                : '${raftText(context, 'Search channels, DMs, messages…')}   '
                      '${globalSearchShortcutLabel()}',
            clearLabel: raftText(context, 'Clear search'),
            showEscape: !mobile,
            onClear: () {
              query.clear();
              searchChanged('');
            },
            onChanged: searchChanged,
            onSubmitted: (_) {
              searchDebounce?.cancel();
              final selected = selectedSearchKey ?? firstSearchKey;
              final entity =
                  (atSearchHome ? frequentEntities : currentSearchEntities)
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
      ],
    );
    return mobile
        ? RaftPanelHeaderBar(
            title: raftText(context, 'Search'),
            titleSlot: row,
            onBack: widget.onBack ?? () {},
            backTooltip: raftText(context, 'Back'),
          )
        : Container(
            height: recipe.height,
            padding: EdgeInsets.symmetric(
              horizontal: RaftLayoutMetrics.panelInset,
            ),
            decoration: BoxDecoration(
              color: recipe.background,
              border: Border(bottom: recipe.border),
            ),
            child: row,
          );
  }

  /// raft-ui `search` recipe slots (SearchShellRoot / Filters / Viewport).
  rui.RaftSearchRecipeStyle searchSlots(BuildContext context) {
    final t = RaftTokens.of(context);
    return rui.RaftSearchRecipe.resolve(
      theme: t.brutal
          ? rui.RaftRecipeTheme.brutal
          : rui.RaftRecipeTheme.elegant,
      states: rui.RaftRecipeStates({
        if (t.dark) rui.RaftRecipeStates.dark,
      }, MediaQuery.sizeOf(context).width),
      tokens: rui.RaftRecipeTokens(t),
    );
  }

  Widget searchFilters() {
    final scope = authority;
    // SearchShellFilters (raft-ui search `filtersRow`): brutal `px-4 py-3
    // border-b-2 border-black bg-white`, elegant `border-b bg-layer-panel px-3
    // py-2 max-md:pl-5 max-md:pr-3.5` (transparent in dark).
    final row = searchSlots(context).filtersRow;
    final rowDecoration = row.decoration(
      rui.RaftRecipeTokens(RaftTokens.of(context)),
    );
    return Container(
      padding: row.padding,
      decoration: rowDecoration,
      child: SizedBox(
        width: double.infinity,
        child: SearchFilterBar(
          filters: advanced,
          senders: senders,
          conversations: {
            for (final c in [
              ...w.channels,
              ...w.dms,
            ].where((c) => c.type != 'thread'))
              c.id: '${c.type == 'dm' ? '@' : '#'}${c.name}',
          },
          menus: filterMenus,
          queryIsEmpty: query.text.trim().isEmpty,
          scope: scope,
          valid: () => accepts(scope),
          onChanged: load,
          channelLabel: (id) =>
              '#${[...w.channels, ...w.dms].where((c) => c.id == id).firstOrNull?.name ?? raftText(context, 'Channel')}',
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
    if (!activityScope.directMessages) {
      totalCount = (value['totalCount'] as num?)?.toInt() ?? totalCount;
    }
    totalUnreadCount =
        (value['totalUnreadCount'] as num?)?.toInt() ?? totalUnreadCount;
    activityAllCount =
        ((value['allCount'] ?? value['unfilteredCount']) as num?)?.toInt() ??
        (activeActivityFilter == 'all' &&
                query.text.trim().isEmpty &&
                advanced.channelId == null
            ? (value['totalCount'] as num?)?.toInt() ?? totalCount
            : activityAllCount);
    activityGroups = ChannelActivityScope.groups(
      value,
      activityGroups,
      advanced.channelId,
    );
  }

  Future<void> loadActivityFacets(String scope) async {
    final ticket = ++activityFacetRequest;
    final view = listView;
    final acceptWindow = widget.onActivityWindowAccepted;
    try {
      var value = await w.query(
        '/channels/inbox',
        query: advanced.list(query.text, filter: activeActivityFilter),
      );
      if (!accepts(scope) ||
          view != listView ||
          ticket != activityFacetRequest ||
          value is! Map) {
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
      if (view != listView) return;
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

  void selectActivityView(RaftActivityView next, String scope) =>
      selectActivitySection(next.name, scope);

  void selectActivitySection(String next, String scope) {
    if (!accepts(scope) || filter == next) return;
    stashViewWindow();
    activityScrollOffsets[filter] = listOffset;
    clearActivityGesture();
    setState(() {
      filter = next;
      rows = [];
      rowsView = null;
      hasMore = false;
      listOffset = activityScrollOffsets[next] ?? 0;
      listScroll = activityScrolls.putIfAbsent(next, newActivityScroll);
      if (activityScope.globalInbox) activeActivityFilter = filter;
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
                RaftActivityView.dms: directMessagesTotal,
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

  String get activityEmptyTitle => activityEmptyState(filter).title;
  String get activityEmptyDetail => activityEmptyState(filter).detail;
  ({String title, String detail}) activityEmptyState(String filter) {
    final selected = activitySourceGroups
        .where((g) => g.id == advanced.channelId)
        .firstOrNull;
    return ChannelActivityScope(filter).emptyState(
      channelLabel: advanced.channelId == null
          ? null
          : selected?.label ?? 'Selected channel',
    );
  }

  void showActivitySearch() {
    if (!mounted || !enabledActivity || !widget.compactActivitySidebar) return;
    setState(() => activitySearchVisible = true);
    // keydown-focus-on-open: focus the field and select its text, so the next
    // keystroke replaces the previous query.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && enabledActivity) {
        queryFocus.requestFocus();
        query.selection = TextSelection(
          baseOffset: 0,
          extentOffset: query.text.length,
        );
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
      markAllRead: (totalUnreadCount ?? 0) > 0 && activityScope.globalInbox
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
          bottom: BorderSide(
            color: t.brutal ? t.colors['color-black']! : t.line,
            width: t.border,
          ),
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
                    selectActivitySection(value, scope);
                  }
                },
              ),
            ),
          ),
          // `showMarkAllRead`: only while something is unread.
          if ((totalUnreadCount ?? 0) > 0 && activityScope.globalInbox) ...[
            const SizedBox(width: RaftResourceMetrics.activityToolbarGap),
            // Button sm outline `h-8 px-2 text-xs font-bold`.
            RaftInteractive(
              semanticLabel: raftText(context, 'Mark all read'),
              onPressed: () => command(
                'POST',
                '/channels/inbox/read-all',
                sourceScope: scope,
              ),
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
                  controlLabel: true,
                ),
              ),
            ),
          ],
          if (extraFilters)
            RaftTooltip(
              message: raftText(context, 'Activity actions'),
              child: PopupMenuButton<String>(
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
            ),
        ],
      ),
    );
  }

  Widget resourceHeader(String scope) {
    final mobile =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    final count = totalCount ?? rows.length;
    if (widget.mobileRoot && mobile && widget.section == 'activity') {
      return const RaftMobileRootHeader(title: 'Activity');
    }
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
      leftInset: widget.section == 'activity' ? 12 : null,
      bottomRule: widget.section == 'activity',
      iconBackground: widget.section == 'saved'
          ? RaftTokens.of(context).colors['primary-soft']
          : null,
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
      onBack: mobile && widget.section != 'tasks'
          ? (widget.onBack ?? () {})
          : null,
    );
  }

  /// Whether [row] is the item open in the preview. Identity is the content
  /// target's id (thread channel / channel), never the target's message focus:
  /// that moves with unread state and refreshes, the row's identity does not.
  /// A mention action additionally requires its own message, so opening an
  /// ordinary channel row never lights up a mention row of that channel.
  bool activityRowSelected(Map<String, dynamic> row) {
    final target = widget.activitySelectedTarget;
    if (widget.section != 'activity' || target == null) return false;
    final kind = row['kind'];
    if (kind == 'thread') {
      return target.kind == DesktopContentKind.thread &&
          target.id == row['threadChannelId'];
    }
    if (target.kind != DesktopContentKind.channel ||
        target.id != row['channelId']) {
      return false;
    }
    return kind != 'mention_action' || target.messageId == row['messageId'];
  }

  void activateActivity(
    Map<String, dynamic> row,
    String scope,
    int detail,
    double? height, {
    bool pointer = false,
  }) {
    if (!accepts(scope)) return;
    final canonical = widget.onActivityCanonical;
    if (canonical == null) {
      unawaited(openConversation(row, scope));
      return;
    }
    final key = rowKey(row);
    if (pointer &&
        activityGestureCurrent &&
        key != null &&
        key == activityGestureKey) {
      upgradeActivityGesture(key);
      return;
    }
    // Restart from what is displayed, so read rows above the new item do not
    // collapse and move its second-click target during the new time window.
    final shown = List<Map<String, dynamic>>.of(visibleRows);
    final heights = activityGestureCurrent
        ? Map<String, double>.of(activityGestureHeights)
        : <String, double>{};
    clearActivityGesture();
    if (!pointer) {
      // Keyboard and semantic activation never continue a mouse gesture.
      unawaited(openConversation(row, scope));
      return;
    }
    activityGestureRows = shown;
    activityGestureRow = Map<String, dynamic>.from(row);
    activityGestureKey = key;
    activityGestureScope = scope;
    activityGestureView = listView;
    activityGestureHeights = heights;
    if (key != null && height != null) activityGestureHeights[key] = height;
    activityGestureInterval = doubleClickInterval;
    // Preview selects its detail synchronously. Only list retention expires;
    // neither cache restoration nor a request waits for this timer.
    unawaited(openConversation(row, scope));
    activityGestureRevision = w.navigationRevision;
    activityActivation = Timer(activityGestureInterval!, () {
      if (!mounted) return;
      setState(clearActivityGesture);
    });
    setState(() {});
  }

  void upgradeActivityGesture(String key) {
    if (!activityGestureCurrent || activityGestureKey != key) return;
    final canonical = widget.onActivityCanonical;
    if (canonical == null) return;
    // The item identity owns the double click, independent of changed bounds.
    // Keep the original unread/mention focus even after its read badge clears.
    final original = activityGestureRow!;
    setState(clearActivityGesture);
    unawaited(canonical(Map<String, dynamic>.from(original)));
  }

  /// Source ThreadsInbox handleOpen / double-click: opening an unread row
  /// marks its scope read. The row presents read at once; the persisted
  /// read-all and its ledger receipt follow.
  void markActivityRead(Map<String, dynamic> row, String scope) {
    if (widget.section != 'activity' ||
        !accepts(scope) ||
        ['saved', 'done'].contains(filter)) {
      return;
    }
    final key = rowKey(row);
    if (key == null) return;
    final current =
        rows.where((candidate) => rowKey(candidate) == key).firstOrNull ?? row;
    final scopeId = activityScopeId(current);
    final unread = (current['unreadCount'] as num? ?? 0).toInt();
    if (scopeId == null || unread <= 0) return;
    final frontier = activityFrontier(current);
    if (frontier != null) {
      activityReadMarkers[key] = (
        frontier: frontier,
        until: (widget.clock?.call() ?? DateTime.now()).add(
          const Duration(seconds: 3),
        ),
      );
    }
    Map<String, dynamic> read(Map<String, dynamic> item) => {
      ...item,
      'unreadCount': 0,
      'firstUnreadMessageId': null,
      'hasMention': false,
    };
    if (activityGestureRows != null) {
      activityGestureRows = [
        for (final item in activityGestureRows!)
          rowKey(item) == key ? read(item) : item,
      ];
    }
    final unreadView = filter == 'unread';
    final acceptWindow = widget.onActivityWindowAccepted;
    final acceptUnread = widget.onActivityUnreadAccepted;
    // The read marker above keeps a response that predates this read from
    // re-presenting the row; in-flight windows stay valid.
    setState(() {
      rows = unreadView
          ? rows.where((item) => rowKey(item) != key).toList()
          : [for (final item in rows) rowKey(item) == key ? read(item) : item];
      acceptedActivityItems = [
        for (final item in acceptedActivityItems)
          rowKey(item) == key ? read(item) : item,
      ];
      if (unreadView) {
        activityGroups = ActivityDoneState.groups(activityGroups, [
          current,
        ], advanced.channelId);
        if (totalCount != null) {
          totalCount = (totalCount! - 1).clamp(0, 1 << 53);
        }
      }
      if (totalUnreadCount != null) {
        totalUnreadCount = (totalUnreadCount! - unread).clamp(0, 1 << 53);
      }
    });
    if ((w.unread[scopeId] ?? 0) != 0) {
      w.unread = {...w.unread, scopeId: 0};
      w.notifyListeners();
    }
    if (totalUnreadCount != null) {
      acceptUnread?.call(totalUnreadCount);
      if (activityScope.globalInbox) {
        acceptWindow?.call({
          'items': acceptedActivityItems.isEmpty ? rows : acceptedActivityItems,
          'totalUnreadCount': totalUnreadCount,
        });
      }
    }
    unawaited(persistActivityRead(key, scopeId, scope));
  }

  Future<void> persistActivityRead(
    String key,
    String scopeId,
    String scope,
  ) async {
    final controller = w;
    final identity = SourceReadAllIdentity.capture(controller.client);
    try {
      await controller.conversationReads.markAllRead(
        scopeId,
        identity: identity,
      );
    } catch (_) {
      if (!identity.current(controller.client)) return;
      // Source forgets the suppression and refreshes the inbox in background.
      if (mounted) activityReadMarkers.remove(key);
      await controller.conversationReads.reconcileUnread();
      if (mounted && accepts(scope)) await load(keep: true, quietErrors: true);
    }
  }

  Future<void> openConversation(Map<String, dynamic> row, String scope) async {
    if (!accepts(scope)) return;
    markActivityRead(row, scope);
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
    final senderType = switch (row['senderType']) {
      'agent' => 'agent',
      'external_projection' => 'external_projection',
      _ => 'user',
    };
    final sender = stableSender('saved:${row['messageId']}', () {
      final agent = senderType == 'agent'
          ? rowAgents.where((a) => a['id'] == senderId).firstOrNull
          : null;
      final person = senderType == 'user'
          ? rowPeople
                .where((m) => (m['userId'] ?? m['id']) == senderId)
                .firstOrNull
          : null;
      return '${agent?['displayName'] ?? agent?['name'] ?? person?['displayName'] ?? person?['name'] ?? row['senderDisplayName'] ?? row['senderName'] ?? ''}';
    });
    // The avatar kind is the message-carried sender type, never "found in the
    // directory yet".
    final projection = projectSenderAvatar(
      origin: w.client.origin,
      senderId: senderId,
      senderType: senderType,
      agents: rowAgents,
      members: rowPeople,
      currentUser: w.client.user?.json,
      externalAuthor: {'avatarUrl': row['senderAvatarUrl']},
      carriedAvatarUrl: row['senderAvatarUrl'] is String
          ? row['senderAvatarUrl'] as String
          : null,
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
      onContextMenu: (at) => savedMenu(row, scope, at),
      popupOpen: menuRowKey == '${row['messageId']}',
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
            onPressed: () => removeSaved(row, scope),
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

  /// SavedPanel `ContextMenuContent`: Copy link, Copy Markdown, a separator,
  /// Remove from Saved.
  Future<void> savedMenu(
    Map<String, dynamic> row,
    String scope,
    Offset at,
  ) async {
    await scopedMenu<void>(
      scope,
      at,
      (context) => RaftContextMenuContent(
        onDismiss: () => closeOwnedDialog(context, scope),
        entries: [
          RaftContextMenuContentItem(
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
                      channelId:
                          '${row['parentChannelId'] ?? row['channelId']}',
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
          RaftContextMenuContentItem(
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
          const RaftContextMenuContentSeparator(),
          RaftContextMenuContentItem(
            label: raftText(context, 'Remove from Saved'),
            glyph: RaftGlyph.bookmark,
            onPressed: () {
              if (!accepts(scope)) return;
              closeOwnedDialog(context, scope);
              removeSaved(row, scope);
            },
          ),
        ],
      ),
      rowKey: '${row['messageId']}',
    );
  }

  /// ThreadsInbox `activity-context-menu` (`ContextMenuPopup`, w-184): Mark as
  /// Read / Mark as Unread (not for an unfollowed thread), Done and, for
  /// threads, Unfollow (BellOff 14) / Follow (Bell 14).
  Future<void> activityMenu(
    Map<String, dynamic> row,
    String scope,
    Offset at,
  ) async {
    final unread = (row['unreadCount'] as num? ?? 0) > 0;
    await scopedMenu<void>(scope, at, (context) {
      void close() => closeOwnedDialog(context, scope);
      return buildActivityContextMenu(
        context,
        row,
        onDismiss: close,
        onAction: (action) {
          if (!accepts(scope)) return;
          close();
          if (action == ActivityContextAction.toggleRead) {
            unawaited(toggleActivityRead(row, scope, unread));
          } else {
            unawaited(activityAction(row, action.name, scope));
          }
        },
      );
    }, rowKey: rowKey(row));
  }

  /// Menu "Mark as Read" reads the row's scope; "Mark as Unread" POSTs
  /// `/channels/:id/unread` (errors ignored) and both refresh the inbox.
  Future<void> toggleActivityRead(
    Map<String, dynamic> row,
    String scope,
    bool unread,
  ) async {
    if (unread) {
      markActivityRead(row, scope);
      return;
    }
    final id = row['kind'] == 'thread'
        ? row['threadChannelId']
        : row['channelId'];
    if (id is! String) return;
    final controller = w;
    try {
      await controller.conversationReads.markUnread(id);
    } catch (_) {}
    if (!mounted || !accepts(scope)) return;
    await load(keep: true, quietErrors: true);
  }

  Widget activityCard(
    Map<String, dynamic> row,
    String scope, {
    String? viewFilter,
  }) {
    final filter = viewFilter ?? this.filter;
    final pin = activityGestureMatches(scope);
    final recipe = RaftConversationCardRecipe(RaftTokens.of(context));
    final thread = row['kind'] == 'thread';
    final dm = row['kind'] == 'dm' || row['channelType'] == 'dm';
    final unread = (row['unreadCount'] as num? ?? 0).toInt();
    final title = thread
        ? '${row['parentMessagePreview'] ?? ''}'
        : activityRowTitle(row, w.dms);
    final senderType =
        row[thread ? 'latestActivitySenderType' : 'lastMessageSenderType'];
    final senderId =
        row[thread ? 'latestActivitySenderId' : 'lastMessageSenderId'];
    final sender = senderType == 'system' || senderId == 'system'
        ? raftText(context, 'System')
        : '${row[thread ? 'latestActivitySenderName' : 'lastMessageSenderName'] ?? stableSender('activity:$senderType:$senderId', () => directorySenderLabel(senderId, senderType))}';
    final preview =
        '${thread ? row['latestActivityPreview'] ?? '' : row['lastMessagePreview'] ?? row['messagePreview'] ?? ''}';
    return Builder(
      builder: (cardContext) => ConstrainedBox(
        constraints: pin && activityGestureHeights[rowKey(row)] != null
            // ignore: raft_lints/avoid_render_index_assertion -- Guarded by `activityGestureHeights[rowKey(row)] != null` on the line above.
            ? BoxConstraints(minHeight: activityGestureHeights[rowKey(row)]!)
            : const BoxConstraints(),
        child: RaftConversationCard(
          key: thread
              ? ValueKey('activity-thread-${row['threadChannelId']}')
              : ValueKey(
                  'activity-${row['kind']}-${row['channelId'] ?? row['messageId']}',
                ),
          selected: activityRowSelected(row),
          onOpen: () => openConversation(row, scope),
          onActivate: widget.onActivityCanonical == null
              ? null
              : (detail) => activateActivity(
                  row,
                  scope,
                  detail,
                  (cardContext.findRenderObject() as RenderBox?)?.size.height,
                ),
          onPointerActivate: widget.onActivityCanonical == null
              ? null
              : (detail) => activateActivity(
                  row,
                  scope,
                  detail,
                  (cardContext.findRenderObject() as RenderBox?)?.size.height,
                  pointer: true,
                ),
          doubleClickInterval: pin
              ? activityGestureInterval!
              : doubleClickInterval,
          onContextMenu: (at) => activityMenu(row, scope, at),
          popupOpen: menuRowKey != null && menuRowKey == rowKey(row),
          actions: enabledActivity && filter == 'saved'
              ? null
              : row['kind'] == 'mention_action'
              ? null
              // ThreadsInbox row action: ghost icon-sm Check 14 (RotateCcw 14 to
              // restore). Follow/unfollow is only in the context menu.
              : RaftIconButton(
                  glyph: filter == 'done'
                      ? RaftGlyph.rotateCcw
                      : RaftGlyph.check,
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
                    activityThreadSubtitle(row, [...w.channels, ...w.dms]),
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
                      relativeTime(
                        row['lastActivityAt'] ?? row['lastMessageAt'],
                      ),
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
                style: recipe.body.copyWith(
                  color: recipe.titleColor(unread > 0),
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 20),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (row['taskNumber'] != null &&
                        row['taskStatus'] is String) ...[
                      RaftTaskStatus(status: row['taskStatus']),
                      if (thread)
                        RaftCssText(
                          activityTaskLabel(row),
                          style: recipe.metadata,
                        ),
                    ],
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
        ),
      ),
    );
  }

  /// `task.status.emptyGroup`: "No {status} tasks."
  String _emptyLaneLabel(BuildContext context, String status) => raftFormat(
    context,
    'No {status} tasks.',
    {'status': raftText(context, raftTaskStatusLabel(status))},
  );

  Widget groupedTasks() {
    final t = RaftTokens.of(context), scope = authority;
    final groups = {
      for (final status in raftTaskStatuses) status: <Map<String, dynamic>>[],
    };
    for (final row in visibleRows) {
      groups[row['status']]?.add(row);
    }
    // Virtualize individual cards, not entire status groups. A large group
    // otherwise rebuilds and lays out hundreds of offscreen cards when the
    // pager changes its accepted selection/TickerMode.
    return ColoredBox(
      color: taskViewportFill(t),
      child: CustomScrollView(
        controller: taskListScroll,
        slivers: [
          SliverPadding(
            // Elegant tasksPanel viewport `max-md:pl-5 max-md:pr-3.5` on top
            // of `p-4` (Brutal resets it).
            padding: raftScrollPadding(
              context,
              !t.brutal && MediaQuery.sizeOf(context).width < 768
                  ? const EdgeInsets.fromLTRB(20, 16, 14, 16)
                  : RaftTaskSectionRecipe(t).viewportInset,
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                for (final status in raftTaskStatuses.where(
                  (s) => filter == 'all' || filter == s,
                )) ...[
                  // ignore: raft_lints/avoid_render_index_assertion -- `groups` is initialised with one list per raftTaskStatuses entry and `status` iterates raftTaskStatuses.
                  taskSection(status, groups[status]!, scope),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
                if (hasMore && !lanePaged)
                  SliverToBoxAdapter(
                    child: TextButton(
                      onPressed: () => load(append: true),
                      child: Text(raftText(context, 'Load more')),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget taskSection(
    String status,
    List<Map<String, dynamic>> tasks,
    String scope,
  ) {
    final indices = {
      for (final (i, row) in tasks.indexed) 'task-${row['id']}': i,
    };
    return RaftSliverTaskSection(
      key: ValueKey('task-section-$status'),
      status: status,
      count: tasks.length,
      collapsed: collapsedTaskStatuses.contains(status),
      triggerKey: ValueKey('task-group-$status'),
      emptyLabel: _emptyLaneLabel(context, status),
      onToggle: () {
        if (accepts(scope)) {
          setState(() {
            if (!collapsedTaskStatuses.remove(status)) {
              collapsedTaskStatuses.add(status);
            }
          });
        }
      },
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? indices[key.value] : null,
      footer: laneCursors[status] == null
          ? null
          : RaftTaskLoadMoreButton(
              key: ValueKey('task-load-more-$status'),
              loading: laneBusy.contains(status),
              onPressed: () => moreLane(status),
            ),
      itemBuilder: (_, i) => SourceTaskRowExtent(
        key: ValueKey('task-${tasks[i]['id']}'),
        child: item(tasks[i], sourceScope: scope),
      ),
    );
  }

  /// Shared-directory label for an entry that carries no sender name.
  String directorySenderLabel(dynamic id, dynamic type) {
    final row = type == 'agent'
        ? rowAgents.where((a) => a['id'] == id).firstOrNull
        : rowPeople.where((m) => (m['userId'] ?? m['id']) == id).firstOrNull;
    if (row != null) return '${row['displayName'] ?? row['name'] ?? ''}';
    return senders
            .where((s) => s.id == id && s.type == type)
            .firstOrNull
            ?.label ??
        '';
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
        // A refreshed directory keeps the user's sender filter (with the
        // current label when that sender is still listed).
        if (advanced.sender case final selected?) {
          advanced.sender = options[selected.key] ?? advanced.sender;
        }
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
    return RaftTooltip(
      message: raftText(context, title),
      child: PopupMenuButton<String>(
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
                contextMenuBuilder: RaftTextSelectionToolbar.editableText,
                autofillHints: null,
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
              // ignore: raft_lints/avoid_render_index_assertion -- timeRange is validated against the four known values when restored (search_memory.dart) and only set from the dropdown.
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
          RaftTouchTargetExpander(
            minSize: const Size.square(RaftMetrics.touchTarget),
            child: RaftTaskFilterButton(
              onPressed: () {
                if (!accepts(scope)) return;
                advanced = ResourceFilters();
                query.clear();
                load();
              },
              child: Text(raftText(context, 'Clear All')),
            ),
          ),
        ],
      ),
    );
  }

  Widget groupedActivity({
    String? viewFilter,
    List<Map<String, dynamic>>? windowRows,
  }) {
    final value = viewFilter ?? filter;
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in windowRows ?? visibleRows) {
      final id =
          '${row['kind'] == 'thread' ? row['parentChannelId'] : row['channelId']}';
      (groups[id] ??= []).add(row);
    }
    return ListView(
      key: PageStorageKey(('activity-grouped-list', value)),
      controller: viewFilter == null ? listScroll : activityScrolls[value],
      physics: mobileActivityRefresh
          ? const AlwaysScrollableScrollPhysics()
          : null,
      padding: raftScrollPadding(
        context,
        const EdgeInsets.symmetric(horizontal: 16),
      ),
      children: [
        for (final group in groups.values) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${activityGroupTitle(group.first, [...w.channels, ...w.dms]) ?? raftText(context, 'Conversation')} · ${group.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final row in group)
            viewFilter == null
                ? item(row)
                : activityCard(row, authority, viewFilter: value),
        ],
        if (viewFilter == null && hasMore)
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
    if (row['kind'] == 'mention_action' && action == 'done') {
      setState(() {
        rows = rows.where((item) => rowKey(item) != itemKey).toList();
        acceptedActivityItems = acceptedActivityItems
            .where((item) => rowKey(item) != itemKey)
            .toList();
        activityGestureRows = activityGestureRows
            ?.where((item) => rowKey(item) != itemKey)
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
      });
      widget.onActivityWindowAccepted?.call({
        'items': acceptedActivityItems.isEmpty ? rows : acceptedActivityItems,
        'totalCount': totalCount,
        'allCount': activityAllCount,
        'groups': activityGroups,
        'totalUnreadCount': totalUnreadCount,
      });
      saveSnapshot();
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
        if (activityScope.globalInbox) {
          acceptWindow?.call({
            'items': acceptedActivityItems.isEmpty
                ? rows
                : acceptedActivityItems,
            'totalUnreadCount': totalUnreadCount,
          });
        }
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
        // Source ThreadsInbox mutates through threadStore.followedThreads.
        final parentId = row['parentMessageId'];
        if (parentId is String) {
          _services.followedThreads.acknowledge(
            parentMessageId: parentId,
            threadChannelId: id,
            following: action == 'follow',
          );
        }
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
          if (activityScope.globalInbox) {
            acceptWindow?.call({
              'items': rows,
              'totalUnreadCount': totalUnreadCount,
            });
          }
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
    if (widget.section == 'activity' && activityGestureCurrent) {
      final current = {for (final row in rows) rowKey(row): row};
      return [
        for (final row in activityGestureRows!) current[rowKey(row)] ?? row,
      ];
    }
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
                            // IdentityFilterChip: "me" first, then Unassigned.
                            if (self != null)
                              'user:${self.id}': raftText(
                                context,
                                field == 'Creator'
                                    ? 'Created by me'
                                    : 'Assigned to me',
                              ),
                            if (field == 'Assignee')
                              'unassigned': raftTextZh(
                                context,
                                'Unassigned',
                                '未分配',
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
                RaftTouchTargetExpander(
                  minSize: const Size.square(RaftMetrics.touchTarget),
                  child: RaftTaskFilterButton(
                    onPressed: () {
                      if (accepts(scope)) setState(taskAdvanced.clear);
                    },
                    child: Text(raftText(context, 'Clear All')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> moreLane(String status) async {
    final cursor = laneCursors[status],
        lane = laneGeneration,
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
      // A background revalidation keeps the lane's cursor; a replaced lane
      // (or a new authority) never receives this page.
      if (!accepts(scope) ||
          lane != laneGeneration ||
          laneCursors[status] != cursor) {
        return;
      }
      setState(() {
        final ids = {
          for (final rows in lanes.values)
            for (final row in rows) row['id'],
        };
        lanes[status] = [
          ...?lanes[status],
          ...(page['tasks'] as List)
              .map((r) => Map<String, dynamic>.from(r))
              // Newer live facts win over this page.
              .where(
                (r) =>
                    !taskTouched.containsKey(r['id']) ||
                    taskTouched[r['id']] != null,
              )
              .map(
                (r) => switch (taskTouched[r['id']]) {
                  final live? => mergeTaskFields(r, live),
                  _ => r,
                },
              )
              .where(
                (r) => (r['status'] ?? status) == status && ids.add(r['id']),
              ),
        ];
        laneCursors[status] = page['next_cursor'];
        rows = lanes.values.expand((r) => r).toList();
        dragFeedbackRevision.value++;
      });
    } catch (e) {
      if (lane == laneGeneration) fail(e, scope);
    } finally {
      if (mounted && laneBusy.contains(status)) {
        setState(() => laneBusy.remove(status));
      }
    }
  }

  /// Task actions resolve the accepted task by id: a background refresh
  /// replaces row objects, never the task a drag or menu refers to.
  bool canMoveTask(Map<String, dynamic> row, String scope, String next) {
    final current = taskById(row['id']);
    if (!accepts(scope) ||
        current == null ||
        current['status'] == next ||
        !raftTaskStatuses.contains(next) ||
        current['readOnlyReason'] != null ||
        w.server?.string('role') == 'guest' ||
        !w.channels.any(
          (c) => c.id == current['channelId'] && c.joined && !c.archived,
        )) {
      return false;
    }
    final role = w.server?.string('role');
    return ['owner', 'admin'].contains(role) ||
        (raftTaskTransitions[current['status']] ?? []).contains(next);
  }

  Widget draggableTask(Map<String, dynamic> row, String scope) {
    final card = item(row);
    if (!raftTaskStatuses.any((s) => canMoveTask(row, scope, s))) return card;
    final payload = _TaskDrag(row, scope);
    final feedback = AnimatedBuilder(
      animation: dragFeedbackRevision,
      builder: (context, _) {
        final current = accepts(scope) ? taskById(row['id']) : null;
        return current != null
            ? Material(
                color: Colors.transparent,
                child: SizedBox(width: 292, child: item(current)),
              )
            : const SizedBox.shrink();
      },
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

  /// TasksPanelViewport `bg-layer-canvas-muted theme-brutal:bg-white
  /// dark:bg-transparent`: dark shows the ancestor surface (see build).
  Color taskViewportFill(RaftTokens t) =>
      t.brutal ? t.panel : (t.dark ? t.sidebar.withAlpha(0) : t.sidebar);

  /// TasksPanel channel mode with no task at all: the centred EmptyState
  /// (`sortedTasks.length === 0 && isChannelMode`) instead of empty lanes.
  Widget channelTasksEmpty() {
    final filtered = !taskAdvanced.isEmpty;
    return RaftProductEmptyPanel(
      title: raftText(
        context,
        filtered ? 'No tasks match this filter' : 'No tasks yet',
      ),
      description: raftText(
        context,
        filtered
            ? 'Try a different combination or clear the current selection.'
            : 'Create one with the New Task button.',
      ),
      icon: (context, size, color) =>
          RaftIcon(RaftGlyph.checkSquare, size: size, color: color),
    );
  }

  Widget taskBoard() {
    final t = RaftTokens.of(context), scope = authority;
    return ColoredBox(
      color: taskViewportFill(t),
      child: SingleChildScrollView(
        controller: taskBoardScroll,
        primary: false,
        scrollDirection: Axis.horizontal,
        padding: raftScrollPadding(context, const EdgeInsets.all(16)),
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
                  builder: (context, candidates, rejected) =>
                      RaftTaskBoardColumn(
                        status: status,
                        count:
                            '${(lanes[status] ?? []).where(matchesTask).length}',
                        collapsed: collapsedTaskStatuses.contains(status),
                        dropActive: candidates.isNotEmpty,
                        triggerKey: ValueKey('task-group-$status'),
                        onToggle: () {
                          if (accepts(scope)) {
                            setState(() {
                              if (!collapsedTaskStatuses.remove(status)) {
                                collapsedTaskStatuses.add(status);
                              }
                            });
                          }
                        },
                        body: taskBoardLane(status, scope),
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget taskBoardLane(String status, String scope) {
    final tasks = sortedLane((lanes[status] ?? []).where(matchesTask).toList());
    final indices = {
      for (final (index, row) in tasks.indexed) 'task-drag-${row['id']}': index,
    };
    final more = laneCursors[status] != null;
    final empty = tasks.isEmpty;
    return ListView.separated(
      key: PageStorageKey(('task-lane', snapshotSection, status)),
      primary: false,
      // The column supplies a finite maximum height. Shrinking preserves the
      // short-lane geometry while the sliver still mounts only visible cards.
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: (empty ? 1 : tasks.length) + (more ? 1 : 0),
      separatorBuilder: (_, _) =>
          const SizedBox(height: RaftResourceMetrics.gap2_5),
      findItemIndexCallback: (key) =>
          key is ValueKey<String> ? indices[key.value] : null,
      itemBuilder: (context, index) {
        if (more && index == (empty ? 1 : tasks.length)) {
          return RaftTaskLoadMoreButton(
            loading: laneBusy.contains(status),
            onPressed: () => moreLane(status),
          );
        }
        if (empty) {
          return RaftTaskLaneEmpty(
            board: true,
            label: _emptyLaneLabel(context, status),
          );
        }
        return KeyedSubtree(
          key: ValueKey('task-drag-${tasks[index]['id']}'),
          child: draggableTask(tasks[index], scope),
        );
      },
    );
  }

  Widget item(Map<String, dynamic> row, {String? sourceScope}) {
    final section = widget.section, scope = sourceScope ?? authority;
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
      // A task row always carries its status (TaskCard requires it); a row
      // without one is skipped rather than rendered as Todo.
      final rowStatus = row['status'];
      if (rowStatus is! String || rowStatus.isEmpty) {
        return const SizedBox.shrink();
      }
      final status = rowStatus;
      final role = w.server?.string('role');
      final allowed = ['owner', 'admin'].contains(role)
          ? raftTaskStatuses
          : [status, ...?raftTaskTransitions[status]];
      return RaftTaskCard(
        key: ValueKey('task-${row['id']}'),
        title: name,
        number: '${row['taskNumber'] ?? row['number'] ?? ''}',
        // TaskCard shows the channel chip only on the server-wide page.
        channel: widget.channelId != null ? '' : '${row['channelName'] ?? ''}',
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
    final channelId = widget.channelId;
    if (channelId != null &&
        w.channels.any((c) => c.id == channelId && c.joined && !c.archived)) {
      // TasksPanel channel mode: CreateTaskDialog (title rows, no channel
      // picker or description).
      await scopedDialog<void>(
        scope,
        (dialogContext) => CreateTaskDialog(
          controller: w,
          channelId: channelId,
          onCreated: () async {
            if (!accepts(scope)) return;
            await w.refreshUnread();
            if (accepts(scope)) await load(keep: rows.isNotEmpty);
          },
        ),
        form: true,
      );
      return;
    }
    final available = w.channels.where((c) => c.joined && !c.archived).toList();
    if (available.isEmpty) {
      setState(() => error = 'Join a channel before creating a task.');
      return;
    }
    await scopedDialog<bool>(
      scope,
      form: true,
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
            if (accepts(scope)) await load(keep: rows.isNotEmpty);
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
        if (accepts(scope)) await load(keep: rows.isNotEmpty);
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
        if (accepts(scope)) await load(keep: rows.isNotEmpty);
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
          // The board dialog is its own modal: no task slot / billing page
          // behind it (references fall back to their read-only summary).
          onTask: null,
          onViewBilling: null,
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

/// Web `peerDisplayName || peerName` of the DM/channel [id] in [channels];
/// null when the channel is unknown or carries neither (ThreadsInbox.tsx:324).
String? _peerLabelFor(Iterable<RaftChannel> channels, Object? id) {
  if (id == null) return null;
  for (final c in channels) {
    if (c.id != id) continue;
    final label = c.firstNonEmpty(const ['peerDisplayName', 'peerName']);
    if (label.isNotEmpty) return label;
  }
  return null;
}

/// Activity channel/DM card title. A DM row resolves the peer through the DM
/// channel list (the inbox `channelName` is only the other user's handle);
/// everything else keeps `channelName`.
String activityRowTitle(Map<String, dynamic> row, Iterable<RaftChannel> dms) {
  final fallback =
      row['channelName'] ??
      row['peerDisplayName'] ??
      row['peerName'] ??
      row['messagePreview'] ??
      'Conversation';
  if (row['kind'] != 'dm') return '$fallback';
  final peer = _peerLabelFor(dms, row['channelId']);
  final name = row['channelName'];
  return peer ?? (name is String && name.isNotEmpty ? name : '$fallback');
}

/// Thread card subtitle: `@peer` for a thread under a DM, `#parent` otherwise
/// (inboxChannelFilter.ts itemFilterChannelLabel).
String activityThreadSubtitle(
  Map<String, dynamic> row,
  Iterable<RaftChannel> channels,
) {
  final name = '${row['parentChannelName'] ?? ''}';
  if (row['parentChannelType'] != 'dm') return '#$name';
  final peer = _peerLabelFor(channels, row['parentChannelId']);
  return '@${peer ?? name}';
}

/// Grouped Activity header title: the parent channel (peer name for a DM).
String? activityGroupTitle(
  Map<String, dynamic> first,
  Iterable<RaftChannel> channels,
) {
  final thread = first['kind'] == 'thread';
  final dm = thread
      ? first['parentChannelType'] == 'dm'
      : first['kind'] == 'dm';
  if (dm) {
    final peer = _peerLabelFor(
      channels,
      thread ? first['parentChannelId'] : first['channelId'],
    );
    if (peer != null) return peer;
  }
  final name =
      first['parentChannelName'] ??
      first['channelName'] ??
      first['peerDisplayName'] ??
      first['peerName'];
  return name == null ? null : '$name';
}

/// Thread-row task label `#N @claimant` (ThreadsInbox.tsx task badge).
String activityTaskLabel(Map<String, dynamic> row) {
  final claimant = row['taskClaimedByName'];
  return '#${row['taskNumber']}'
      '${claimant is String && claimant.isNotEmpty ? ' @$claimant' : ''}';
}

/// Source applyTaskToInboxItems / normalizeTaskMetadataUpdate: overlay
/// `taskNumber`, `taskStatus`, `taskClaimedByName` (null when unclaimed) on
/// thread rows whose `parentMessageId` is the task's `messageId`. Returns
/// [rows] itself when nothing changed.
List<Map<String, dynamic>> applyTaskToActivityRows(
  List<Map<String, dynamic>> rows,
  Map task,
) {
  final messageId = task['messageId'], status = task['status'];
  final number = task['taskNumber'];
  if (messageId is! String || status is! String || number is! num) return rows;
  final claimant = task['claimedByName'];
  final name = claimant is String ? claimant : null;
  var changed = false;
  final next = [
    for (final row in rows)
      if (row['kind'] != 'thread' || row['parentMessageId'] != messageId)
        row
      else if (row['taskNumber'] == number &&
          row['taskStatus'] == status &&
          row['taskClaimedByName'] == name)
        row
      else ...[
        () {
          changed = true;
          return {
            ...row,
            'taskNumber': number,
            'taskStatus': status,
            'taskClaimedByName': name,
          };
        }(),
      ],
  ];
  return changed ? next : rows;
}

class _TaskDrag {
  const _TaskDrag(this.row, this.scope);
  final Map<String, dynamic> row;
  final String scope;
}
