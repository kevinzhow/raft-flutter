import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    hide RaftPanelHeaderRecipe, RaftSearchRecipe;
import 'package:raft_ui/recipes.dart'
    as rui
    show
        RaftRecipeStates,
        RaftRecipeTokens,
        RaftSearchRecipe,
        RaftSearchRecipeStyle;

import '../data/source_activity_unread_store.dart';
import '../data/task_conversation_row.dart';
import '../data/activity_filter_choice.dart';
import '../data/activity_object_rows.dart';
import '../data/activity_unread_snapshot.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_services.dart';
import '../data/search_memory.dart';
import '../data/activity_follow_state.dart';
import '../data/activity_done_state.dart';
import '../data/source_read_all_transport.dart';
import '../data/resource_row_reconcile.dart';
import '../data/activity_row_window.dart';
import '../data/resource_snapshot_cache.dart';
import '../data/server_page_window.dart';
import '../data/server_task_window.dart';
import '../data/server_saved_window.dart';
import 'server_task_scope.dart';
import 'saved_page_rows.dart';
import 'workspace_web_billing.dart';
import 'saved_page_scope.dart';
import '../data/task_board_reconcile.dart';
import '../data/task_view_mode_preference.dart';
import 'activity_card_row.dart';
import 'activity_first_unread.dart';
import 'activity_list_row.dart';
import 'activity_mark_unread_toast.dart';
import 'activity_pagination.dart';
import 'activity_task_rows.dart';
import 'activity_rollout_flags.dart';
import 'activity_counts_line.dart';
import 'activity_load_failed.dart';
import 'activity_mark_all_read.dart';
import 'activity_retap.dart';
import 'activity_page_state.dart';
import 'activity_unread_scope.dart';
import 'activity_list_view.dart';
import 'activity_swipe_actions.dart';
import 'activity_toolbar_mount.dart';
import 'activity_undo.dart';
import '../data/object_activity_api.dart';
import 'activity_object_text.dart' show artifactActivityTarget;
import 'artifacts/artifact_models.dart' show ArtifactCard, ArtifactLinkTarget;
import 'artifacts/artifact_viewer_page.dart' show openWorkspaceArtifact;
import 'activity_row_label.dart' show ActivityRowLookups;
import 'activity_row_time.dart' show activityRowFormatter;
import '../data/source_time_formatter.dart' show sourceTimeNow;
import 'create_task_dialog.dart';
import 'desktop_navigation_policy.dart' show DesktopContentTarget;
import 'search_home.dart';
import 'search_app_results.dart';
import 'search_sections.dart';
import 'search_snapshot.dart';
import 'task_content_slot.dart';
import 'message_task_actions.dart' show TaskV2ConversationsFlag;
import 'tasks_page/tasks_page.dart';
import 'task_surface.dart';
import 'task_status_request.dart';
import 'task_surface_controller.dart';
import 'resource_filters.dart';
import 'resource_authority_cache.dart';
import 'activity_context_menu.dart';
import 'page_layout.dart';
import 'resource_cards.dart';
import 'search_filter_bar.dart';
import 'task_selection_filter.dart';
import 'task_assignment_dialog.dart';
import 'sender_avatar_projection.dart';
import 'message_reference_directory.dart';
import 'private_route_guard.dart';
import 'quick_switcher.dart' show QuickSwitcherFailure, classifySearchFailure;
import 'resource_search.dart';
import 'resource_list_updates.dart';
import 'saved_sidebar_entry.dart';
import 'reading_anchor.dart';
import 'agent_message_collapse.dart' show captureActivityAgentCollapse;
import '../platform/content_links.dart';
import 'tab_root_retap.dart';
import '../platform/interaction_timing.dart';

export 'activity_task_rows.dart';

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
  final SearchQueryCommit? onSearchQueryCommitted;
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
  final bool compactActivitySidebar;

  /// Server-wide Activity total from an accepted window, independent of filter.
  /// Null retires the projection after an explicit authority denial.
  final ValueChanged<int?>? onActivityUnreadAccepted;

  /// Accepted Activity response for an independent scoped unread data owner.
  /// Includes real row frontiers; null retires it after an authority denial.
  final void Function(Map? window, {bool firstPage})? onActivityWindowAccepted;
  @override
  State<ResourceView> createState() => _ResourceViewState();
}

class _ResourceViewState extends State<ResourceView> with ResourcePageRetap {
  final query = SearchPageQuery();
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
    if (scopedSearch) return;
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
    if (searchScopeConversation case final conversation?) {
      return Column(
        children: [
          ?searchHistoryNotice,
          Expanded(
            child: RaftProductEmptyState(
              title: raftFormat(context, 'Search {conversation}', {
                'conversation': conversation,
              }),
              description: raftText(
                context,
                'Finds messages in this conversation only.',
              ),
              icon: (_, size, color) =>
                  RaftIcon(RaftGlyph.search, size: size, color: color),
            ),
          ),
        ],
      );
    }
    final personal = memoryScope;
    final history = personal == null || memoryReadyKey != personal.key
        ? const <String>[]
        : searchMemory.current(personal).history;
    final home = ResourceSearchHome(
      key: ValueKey('search-home-$scope'),
      controller: searchScroll,
      wrapResult: wrapSearchResult,
      selectedKey: activeSearchKey,
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
    final notice = searchHistoryNotice;
    return notice == null
        ? home
        : Column(
            children: [
              notice,
              Expanded(child: home),
            ],
          );
  }

  List<Map<String, dynamic>> rows = [];
  bool get indexedActivity => widget.section == 'activity';
  final activityFollowState = ActivityFollowState();
  final activityDoneState = ActivityDoneState();
  bool loading = true;

  /// The failure came from the blocking first read (no list on screen yet).
  bool errorWhileLoading = false;

  /// Web `showLoadFailed`: no rows and a failed load shows the failed state,
  /// never the empty one.
  bool get activityLoadFailed => error != null && rows.isEmpty && !loading;
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
  int activityFacetRequest = 0;

  /// The Filter menu's choice (Web `activityFilterOf`); Activity's [filter]
  /// holds its name, so every list identity keyed on [filter] tells a scope
  /// from the read filters.
  ActivityFilterChoice get activityChoice => ActivityFilterChoice.parse(filter);

  /// Only the unscoped inbox (All, Unread, Mentions) feeds the shared
  /// attention window; Pinned, Saved and Artifacts never do.
  bool get globalInbox => !activityChoice.isScope;

  /// The Activity facets held beside the rows (object counts, settled counts).
  ActivityPageState get activityFacets => ActivityPageState.of(this);
  ActivityUnreadSnapshotStore get activityUnreadSnapshots =>
      ActivityUnreadScope.of(w).snapshots;

  /// Done / Unfollow / Mute with their Undo, for every route to them.
  void bindActivityUndo() {
    final undo = ActivityUndo(
      ActivityUndoDeps(
        w: w,
        context: () => mounted ? context : null,
        key: rowKey,
        listed: (key) => rows.where((r) => rowKey(r) == key).firstOrNull,
        mountedAction: (row, action) => activityAction(row, action, authority),
        accepts: () => mounted,
      ),
    )..addListener(activityUndoChanged);
    activityFacets.undo = undo;
    ActivityFirstUnread.of(w).addChangeListener(activityUndoChanged);
  }

  void activityUndoChanged() {
    if (mounted) setState(() {});
  }

  void disposeActivityUndo() {
    ActivityFirstUnread.of(w).removeChangeListener(activityUndoChanged);
    activityFacets.undo
      ?..removeListener(activityUndoChanged)
      ..dispose();
    activityFacets.open.dispose();
  }

  /// Rows out of the list while their Done / Unfollow waits out its Undo.
  List<Map<String, dynamic>> activityUndoShown(
    List<Map<String, dynamic>> base,
  ) {
    final undo = activityFacets.undo;
    if (undo == null) return base;
    undo.reconcile();
    return undo.hasHidden
        ? [
            for (final row in base)
              if (!undo.hides(rowKey(row))) row,
          ]
        : base;
  }

  /// What the phone's Activity re-tap works with (Web `useActivityNextUnread`).
  ActivityRetapHost activityRetapHost() => ActivityRetapHost(
    scroll: () => listScroll,
    context: context,
    rowKeys: () => [for (final row in visibleRows) ?rowKey(row)],
    isUnread: (key) {
      final row = visibleRows.where((r) => rowKey(r) == key).firstOrNull;
      return row != null && !ActivityUnreadSnapshot.isRead(row);
    },
    totalUnreadCount: () => totalUnreadCount ?? 0,
    hasMore: () => hasMore,
    loadMore: () => load(append: true),
    locate: (key) => ActivityFirstUnread.of(w).locate(w, key),
  );
  String? catalogScope;
  int catalogRequest = 0;
  String taskLayout = 'list';
  bool initializedTaskLayout = false;
  bool extraFilters = false;
  int? totalCount;

  /// Saved rows behind the plan's history window (`historyHidden.count` of
  /// the first page); the page says how many in a banner.
  SavedPageState get savedFacets => SavedPageState.of(this);
  int get historyHiddenCount => savedFacets.hiddenCount;
  set historyHiddenCount(int value) => savedFacets.hiddenCount = value;
  bool get savedRefreshing => savedFacets.refreshing;
  set savedRefreshing(bool value) => savedFacets.refreshing = value;
  int get savedLoadFailures => savedFacets.loadFailures;
  set savedLoadFailures(int value) => savedFacets.loadFailures = value;
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
      'activity' => '/channels/inbox',
      'saved' => '/channels/saved',
      _ => '/messages/search',
    };
    final params = widget.section == 'search'
        ? advanced.search(query.text)
        : advanced.list(
            query.text,
            activityChoice: widget.section == 'activity'
                ? activityChoice
                : null,
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
      viewWindows.remove(viewWindows.keys.first);
    }
  }

  /// Activity rows advanced by live messages beyond their accepted window.
  final activityLocalFrontiers = <String, BigInt>{};

  /// Source inboxStore inboxLocalReadSuppressedMarkers: rows this principal
  /// just opened present read against any response that predates the read.
  final activityReadMarkers =
      <String, ({BigInt frontier, DateTime until, int? versionAtRead})>{};

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
    if (indexedActivity) {
      rows = ActivityRowWindow.from(rows);
      acceptedActivityItems = ActivityRowWindow.from(acceptedActivityItems);
      if (activityGestureRows != null) {
        activityGestureRows = ActivityRowWindow.from(activityGestureRows!);
      }
    }
    final scroll = listScroll;
    if (activityPage) {
      ActivityFirstUnread.of(w)
          .observe(w, visibleRows, rowKey, scroll, context);
    }
    listUpdates.observeRows(
      view: (widget.section, filter, rowsView),
      rows: visibleRows,
      keyOf: rowKey,
      indexedActivity: indexedActivity,
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
    final usable = snapshot != null;
    listOffset = usable ? snapshot.scrollOffset : 0;
    // Track live offsets: children unmount before the owner is disposed.
    if (usable && widget.section == 'activity') {
      filter = snapshot.filter;
      activityScrollOffsets.addAll(snapshot.sectionScrollOffsets);
    }
    listScroll = newActivityScroll();
    if (widget.section == 'activity') activityScrolls[filter] = listScroll!;
    if (!usable) return false;
    rows = activityPage
        ? normalizeTaskConversationRows(snapshot.rows)
        : snapshot.rows;
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
    activityGroups = snapshot.activityGroups;
    acceptedActivityItems = activityPage
        ? normalizeTaskConversationRows(snapshot.acceptedActivityItems)
        : snapshot.acceptedActivityItems;
    viewWindows
      ..clear()
      ..addAll(snapshot.viewWindows);
    inboxSerial = snapshot.inboxSerial;
    loading = false;
    // Channels lost while the page was away never reappear from the cache.
    refilterRows(lostChannels(snapshot.channelAccess, acceptedAccess));
    patchKnownActivityReads();
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
      activityGroups: activityGroups,
      acceptedActivityItems: acceptedActivityItems,
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

  void bindActivitySources() {
    if (activityPage) ActivityRolloutFlags.of(w);
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
    if (query.selectedKey case final key?
        when key.startsWith('message:') &&
            !rows.any((row) => 'message:${row['id']}' == key)) {
      query.clearSelection();
    }
    acceptedActivityItems = acceptedActivityItems.where(keep).toList();
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
    activeActivityFilter = 'all';
    ++activityFacetRequest;
    totalCount = null;
    historyHiddenCount = 0;
    totalUnreadCount = null;
    taskAdvanced.clear();
  }

  void resetAdvanced() {
    advanced = ResourceFilters();
    senders = [];
    searchPeople = [];
    searchAgents = [];
    searchComputers = [];
    query.clearSelection();
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
      activityFacets.unavailable =
          cause is RaftApiException &&
          cause.status == 503 &&
          cause.code == 'rw_unconfigured';
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
    if (widget.section == 'activity' &&
        activityFacets.reload.changed(
          choice: activityChoice,
          pinned: w.sidebarOrder['pinned'],
          savedRevision: w.savedRevision,
        )) {
      // Pinned and Saved follow the sidebar's pins and the saves made.
      unawaited(load(keep: true, quietErrors: rows.isNotEmpty));
    }
    if (acceptedAuthority == authority) {
      patchKnownActivityReads();
      return;
    }
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
      filter = widget.section == 'activity'
          ? ActivityFilterPreference.read(w.server?.id).name
          : 'all';
      if (widget.section == 'activity') {
        activityFacets.counts.reset();
        activityScrolls[filter] ??= listScroll!;
      }
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
    Size? placementSize,
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
        placementSize: placementSize,
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
        'activity' => SourceActivityUnreadStore.reconcilesPage(
          event,
          client.serverId,
        ),
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

  /// A scope's rows are the server's pick (pins, saves): live facts reach them
  /// through the reconcile that follows, not by inserting rows here.
  bool get activityRowsLive =>
      widget.section == 'activity' && globalInbox && rows.isNotEmpty;

  /// Apply live Activity facts before the canonical reconcile.
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
      patchKnownActivityReads(
        facts: activityReadFacts(
          payload,
          knownVersions: activityKnownVersions(rows, w.readState, w.client),
        ),
      );
    }
  }

  /// HTTP read receipts also advance the ledger, without a socket echo.
  void patchKnownActivityReads({Map<String, int> facts = const {}}) {
    if (!activityRowsLive) return;
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

  bool activityMuted(Map<String, dynamic> row) =>
      _authorityCache.activityMuted(row, channels: w.channels, dms: w.dms);

  void advanceActivity(Map message) {
    final next = ActivityRowWindow.from(rows).advance(
      message,
      muted: activityMuted,
      newestFirst: advanced.direction != 'asc',
      live: sharedInbox?.liveUnreadOf(message),
    );
    if (next == null) return;
    final key = next.key, frontier = activityFrontier(next.row);
    if (key != null && frontier != null) {
      activityLocalFrontiers[key] = frontier;
    }
    setState(() {
      totalUnreadCount = totalUnreadCount == null
          ? null
          : totalUnreadCount! + next.delta;
      rows = next.window;
      acceptedActivityItems = ActivityRowWindow.from(acceptedActivityItems)
          .replaceKey(key, next.row);
    });
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
    final retained = activityRowsByReadVersion([
      ...acceptedActivityItems,
      ...rows,
    ]);
    final now = widget.clock?.call() ?? DateTime.now();
    activityReadMarkers.removeWhere((_, marker) => now.isAfter(marker.until));
    for (final row in source) {
      final scope = activityScopeId(row);
      final key = rowKey(row);
      final intent = activityReadMarkers[key];
      var marker = intent?.frontier;
      final intentVersion = intent?.versionAtRead;
      final state = scope == null
          ? null
          : w.readState.state(server, user, scope);
      final stateVersion = state?['readStateVersion'];
      final ledger = state?['maxReadSeq'], frame = facts[scope];
      final read = [
        if (ledger is int) ledger,
        ?frame,
      ].fold<int?>(null, (a, b) => a == null || b > a ? b : a);
      final readSeq = read == null ? null : BigInt.from(read);
      final held = scope == null
          ? null
          : w.conversationReads.queue.receipt(scope);
      // A cursor already known when Read was pressed cannot prove that this
      // write persisted. Only a newer version/ACK can retire that local intent.
      if (marker != null &&
          (intentVersion != null &&
                  stateVersion is int &&
                  stateVersion > intentVersion ||
              intentVersion == null && readSeq != null && readSeq >= marker ||
              held != null &&
                  held.unreadCount > 0 &&
                  (state == null ||
                      state['readStateVersion'] <= held.version) &&
                  (intentVersion == null || held.version > intentVersion))) {
        activityReadMarkers.remove(key);
        marker = null;
      }
      final projected = projectFullyRead(
        w.conversationReads.projectActivityReadState(
          row,
          retained: retained[scope],
        ),
        marker != null && (readSeq == null || marker > readSeq)
            ? marker
            : readSeq,
        readStateVersion: marker != null
            ? null
            : state?['readStateVersion'] as int?,
      );
      if (!identical(projected, row)) {
        changed = true;
        cleared +=
            (row['unreadCount'] as num? ?? 0).toInt() -
            (projected['unreadCount'] as num? ?? 0).toInt();
        if (filter == 'unread' &&
            (projected['unreadCount'] as num? ?? 0) == 0) {
          // Read is a signal: the Unread list keeps the row, shown read.
          if (key != null) activityUnreadSnapshots.noteRead([key]);
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
      // restored query). A touch screen keeps the keyboard down until a tap,
      // at any width; a pointer window focuses it at any width.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && RaftInteraction.of(context).pointer) {
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
    bindSearchApps();
    if (restoredMemory) {
      lastPublishedQuery = query.text.trim();
      lastSearchEditingValue = query.value;
    }
    w.addListener(authorityChanged);
    subscribeEvents();
    bindActivitySources();
    unawaited(
      activateSearchMemory(
        restore: widget.restoreSearchState,
        restored: restoredMemory,
      ),
    );
    if (widget.section == 'activity') {
      // Web restores the server's last Filter choice (sync, so the first
      // frame is the final one) and starts the visit and the re-tap.
      filter = ActivityFilterPreference.read(w.server?.id).name;
      activityFacets.leaveVisit = ActivityUnreadScope.of(w).visit.enter();
      activityFacets.unregisterRetap = ActivityRetap.of(w)
          .register(activityRetapHost());
      bindActivityUndo();
      // The pins and saves as of now are what a later change is measured from.
      activityFacets.reload.changed(
        choice: ActivityFilterChoice.all,
        pinned: w.sidebarOrder['pinned'],
        savedRevision: w.savedRevision,
      );
    }
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
    bindRetap();
    bindSectionActivity();
    if (!initializedTaskLayout && widget.section == 'tasks') {
      initializedTaskLayout = true;
      final next = initialTaskView(MediaQuery.sizeOf(context).width);
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
      bindSearchApps();
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
      bindActivitySources();
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
      query.clearSelection();
      error = null;
      hasMore = false;
      saveSearchState();
      unawaited(load());
    }
  }

  @override
  void dispose() {
    activityFacets.leaveVisit?.call();
    activityFacets.unregisterRetap?.call();
    disposeActivityUndo();
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
    disposeRetap();
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
    if (append && activityPage && (activeLoad != null || loading || !hasMore)) {
      return;
    }
    if (widget.section == 'tasks' && widget.channelId != null && !tabActive) {
      reloadWhenActive = true;
      return;
    }
    if (tasksPageV2) return;
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
        rows = activityPage
            ? normalizeTaskConversationRows(cached.rows)
            : cached.rows;
        rowsView = wanted;
        hasMore = cached.hasMore;
        totalCount = cached.totalCount;
        totalUnreadCount = cached.totalUnreadCount;
        patchKnownActivityReads();
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
        if (!append && widget.section == 'search') {
          stashViewWindow();
          rowsView = null;
          hasMore = false;
        }
        if (!append &&
            ['saved', 'activity'].contains(widget.section) &&
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
    if (widget.section == 'activity' && !globalInbox && !append) {
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
        'activity' => '/channels/inbox',
        'saved' => '/channels/saved',
        'search' => '/messages/search',
        'tasks' => taskPath,
        'agents' => '/agents',
        'computers' => '/servers/${w.server!.id}/machines',
        'members' => '/servers/${w.server!.id}/members',
        _ => throw const RaftApiException('This page is not available.'),
      };
      final pageSize = widget.section == 'saved'
          ? 50
          : widget.section == 'activity'
          ? activityPageSize
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
          ? advanced.search(
              query.text,
              offset: append ? rows.length : 0,
              append: append,
            )
          : ['saved', 'activity'].contains(widget.section)
          ? advanced.list(
              query.text,
              offset: append ? rows.length : 0,
              limit: windowSize,
              activityChoice: widget.section == 'activity'
                  ? activityChoice
                  : null,
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
      Future<dynamic> read() => path == '/channels/inbox'
          ? w.sharedQuery(path, query: params)
          : w.query(path, query: params);
      var value =
          seed ??
          await (keep
              ? RaftClient.runRevalidating<Future<dynamic>>(read)
              : read());
      if (!accepts(scope, request)) return;
      if (widget.section == 'activity' && value is Map) {
        value = activityFollowState.window(value);
        value = activityDoneState.window(
          value,
          widget.clock?.call() ?? DateTime.now(),
          selectedChannelId: advanced.channelId,
        );
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
        var accepted = fetched;
        final activityWindow = widget.section == 'activity';
        var unreadDelta = 0;
        if (activityWindow) {
          final known = applyKnownReads(
            value is List ? normalizeTaskConversationRows(accepted) : accepted,
          );
          accepted = known.rows;
          unreadDelta -= known.cleared;
        }
        final List<Map<String, dynamic>> nextRows;
        var nextCursor = value is Map ? value['next_cursor'] as String? : null;
        if (append) {
          final known = {for (final row in rows) rowKey(row)};
          nextRows = [
            ...rows,
            ...accepted.where((row) {
              if (widget.section == 'tasks') {
                return !known.contains(rowKey(row));
              }
              if (activityWindow && row['conversationKind'] == 'task') {
                final key = rowKey(row);
                return key == null || known.add(key);
              }
              return true;
            }),
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
        if (activityWindow && value is Map) {
          // Publish the projected rows with their projected total. Sending
          // raw rows with the adjusted total would apply the same ACK twice.
          value = {...value, 'items': nextRows};
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
          if (widget.section == 'saved') {
            SavedCountStore.of(w).know([
              for (final row in rows)
                if (row['messageId'] is String) row['messageId'] as String,
            ]);
          }
          if (widget.section == 'activity') {
            unawaited(SavedCountStore.of(w).checkActivityRows(rows));
          }
          dragFeedbackRevision.value++;
          if (value is Map) {
            totalCount = ((value['total'] ?? value['totalCount']) as num?)
                ?.toInt();
            totalUnreadCount = (value['totalUnreadCount'] as num?)?.toInt();
            if (widget.section == 'saved' && !append) {
              final hidden = value['historyHidden'];
              historyHiddenCount = hidden is Map && hidden['count'] is num
                  ? (hidden['count'] as num).toInt()
                  : 0;
            }
            if (widget.section == 'activity') {
              activityFacets.objects = ActivityObjectCounts.fromWindow(value);
            }
          }
          if (widget.section == 'activity' && globalInbox && value is Map) {
            acceptActivityFacets(value, rows);
          }
          cursor = nextCursor;
          hasMore = widget.section == 'tasks'
              ? cursor != null
              : advanced.morePages(widget.section, view, value);
          if (widget.section == 'tasks' && !append) {
            applyTaskPatches(taskTouched);
            taskTouched.clear();
          }
        });
        if (seed == null &&
            widget.section == 'activity' &&
            globalInbox &&
            value is Map &&
            value['totalUnreadCount'] is num) {
          widget.onActivityUnreadAccepted?.call(
            (value['totalUnreadCount'] as num).toInt(),
          );
        }
        if (seed == null &&
            widget.section == 'activity' &&
            globalInbox &&
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
      if (widget.section == 'saved') savedLoadFailures++;
      if (!quietErrors || denied) fail(e, scope, request: request);
    } finally {
      if (accepts(scope, request) && loading) {
        setState(() => loading = false);
      }
      if (activeLoad == request) {
        activeLoad = null;
        // A failed quiet refresh has no data/loading rebuild of its own.
        if (activityPage && accepts(scope, request)) {
          setState(() {});
        }
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
    w.conversationReads.writeGoingOut(path);
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
      readTotalCount: () => totalCount,
      apply: (next) => setState(() {
        rows = next.rows;
        totalCount = next.totalCount;
      }),
      store: SavedCountStore.of(w),
      refreshUnread: w.refreshUnread,
      reload: () => load(keep: true),
      fail: (cause) => fail(cause, scope),
    );
  }

  Color get resourceSurface {
    final t = RaftTokens.of(context);
    return t.option('resource.surface', or: 'sidebar') == 'canvas'
        ? t.canvas
        : t.sidebar;
  }

  /// The server Tasks page with task v2 on is its own page (Web TasksRoute
  /// shows TasksPage, else TasksPanel): it reads through its own store, so
  /// this loader stays quiet. The flag still loading (or off): this page.
  bool get tasksPageV2 =>
      serverTaskPage && TaskV2ConversationsFlag.of(w).enabled;

  @override
  Widget build(BuildContext context) => serverTaskPage
      ? TasksPageDetailDock(
          child: TaskV2FlagBuilder(
            controller: w,
            builder: (context, v2) => v2
                ? TasksPage(
                    controller: w,
                    scroll: taskListScroll,
                    currentTaskId: TaskSlotScope.maybeOf(context)?.taskId,
                    onOpenTask: (row) => widget.onTask != null
                        ? widget.onTask!(row, () async {})
                        : unawaited(taskDetails(row)),
                  )
                : buildResource(context),
          ),
        )
      : buildResource(context);

  Widget buildResource(BuildContext context) {
    final t = RaftTokens.of(context);
    if (snapshotted) observeListUpdates();
    // ThreadsInbox mounts ActivityInboxPanel with `theme-brutal:!border-l`.
    final activityEdge = widget.section == 'activity';
    // Shared edge rule (RaftPanelEdge): the Activity panel keeps its line
    // beside the navigation column, except on the full-width phone page and
    // when the column is on the right (it draws that line).
    final BoxDecoration? surface = activityEdge
        ? BoxDecoration(
            color: resourceSurface,
            border: RaftPanelEdge.besideNavigation(
              context,
              RaftPanelEdgeStyle.activityInbox,
            ),
          )
        // SavedPanel: `bg-layer-canvas-muted theme-brutal:bg-white`.
        : widget.section == 'saved'
        ? BoxDecoration(color: resourceSurface)
        : widget.section == 'search'
        ? searchSlots(context).frame.decoration(rui.RaftRecipeTokens(t))
        // TasksPanelViewport is `dark:bg-transparent`: Elegant dark shows the
        // mounted ancestor, ConversationPanelContent's card in a channel tab
        // and the canvas-muted page surface on the Tasks page.
        : widget.section == 'tasks' && t.dark
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
    return body;
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
                    child: RaftTextInput(
                      controller: query,
                      hintText: raftText(
                        context,
                        widget.section == 'search'
                            ? 'Search messages'
                            : 'Filter saved messages',
                      ),
                      leadingGlyph: RaftGlyph.search,
                      onSubmitted: (_) => load(),
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
                                (s) => RaftSelectItem(
                                  value: s,
                                  label: raftText(
                                    context,
                                    s == 'all' ? 'All' : raftTaskStatusLabel(s),
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
                          ? 'Show Task List'
                          : 'Show Task Board',
                    ),
                    child: RaftButton.iconAction(
                      icon: RaftIcon(
                        taskLayout == 'board'
                            ? RaftGlyph.layoutList
                            : RaftGlyph.columns3,
                        size: 12,
                      ),
                      onPressed: () {
                        taskLayout = taskLayout == 'board' ? 'list' : 'board';
                        rememberTaskView(taskLayout);
                        load();
                      },
                    ),
                  ),
                if (widget.section == 'tasks')
                  RaftTooltip(
                    message: raftText(context, 'New task'),
                    child: RaftButton.iconAction(
                      onPressed: w.server?.string('role') == 'guest'
                          ? null
                          : () => createTask(sourceScope: scope),
                      icon: const RaftIcon(RaftGlyph.plus, size: 12),
                    ),
                  ),
              ],
            ),
          ),
        if (widget.section == 'activity' &&
            !(activityPhoneBar && activityShowsList))
          activityToolbar(scope),
        if (widget.section == 'search') searchFilters(),
        if (widget.section == 'saved' && extraFilters) advancedFilters(),
        if (widget.section == 'tasks') taskFilters(),
        // Web Inbox and Saved render no error line when the first read fails:
        // the (empty) list stays as is.
        // Search shows its failure as a card inside the results instead.
        if (error != null &&
            !(widget.section == 'search' && searchFailureKind != null) &&
            !(widget.section == 'activity' && rows.isEmpty) &&
            !(errorWhileLoading && rows.isEmpty && widget.section == 'saved'))
          Padding(
            padding: const EdgeInsets.all(16),
            child: RaftErrorBanner(error!, small: true),
          ),
        Expanded(child: resourceResults(context)),
      ],
    );
  }

  Widget resourceResults(BuildContext context) {
    final results = resourceResultsPager(context);
    if (widget.section != 'search') return results;
    // SearchShellViewport: `bg-layer-panel` (transparent in dark, Brutal white).
    final t = RaftTokens.of(context);
    final fill = t.option('listGroup.frame', or: 'framed') == 'plain'
        ? BoxDecoration(color: t.canvas)
        : searchSlots(context).viewport.decoration(rui.RaftRecipeTokens(t));
    final commit = widget.onSearchQueryCommitted;
    return DecoratedBox(
      decoration: fill,
      child: scopedSearch && commit != null
          ? Column(
              children: [
                SearchEverywhereRow(
                  query: query.text,
                  onPressed: () => commit(
                    query.text.trim(),
                    destination: SearchQueryDestination.everywhere,
                  ),
                ),
                Expanded(child: results),
              ],
            )
          : results,
    );
  }

  Widget resourceResultsPager(BuildContext context) {
    final scope = authority, view = filter;
    // Inside each pager page: a wrapper outside PageView would receive the
    // horizontal pager's notifications instead of this vertical list's.
    final results = RaftPullToRefresh(
      enabled:
          mobileActivityRefresh ||
          widget.section == 'search' && RaftInteraction.of(context).touch,
      onRefresh: () => savedPage
          ? refreshSaved(scope)
          : accepts(scope) && filter == view
          ? refreshResourceResults()
          : Future.value(),
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
    return activityPage
        ? ActivityPagination(
            controller: listScroll!,
            scope: (scope, listView),
            offset: rows.length,
            ready: () =>
                accepts(scope) &&
                filter == view &&
                hasMore &&
                !loading &&
                activeLoad == null &&
                error == null &&
                rowsView == listView,
            onMore: () => load(append: true),
            child: results,
          )
        : results;
  }

  bool get mobileActivityRefresh =>
      (widget.section == 'activity' || savedPage) &&
      RaftInteraction.of(context).touch;

  Future<void> refreshResourceResults() async {
    await Future.wait([
      load(keep: true),
      if (query.apps case final apps?) apps.refresh(),
    ]);
  }

  /// SavedPanel `refreshSaved`: a phone pull loads the list again in place; a
  /// failure keeps the rows and says so in a warning toast.
  Future<void> refreshSaved(String scope) async {
    if (!accepts(scope)) return;
    final failures = savedLoadFailures;
    setState(() => savedRefreshing = true);
    await load(keep: true, quietErrors: true);
    if (!mounted) return;
    setState(() => savedRefreshing = false);
    if (savedLoadFailures != failures && accepts(scope)) {
      showRaftToast(
        context,
        "Couldn't load saved messages.",
        tone: RaftToastRecipeTone.warning,
      );
    }
  }

  /// Web `firstLoad`: nothing read yet, so no count and no empty state.
  bool get savedFirstLoad =>
      loading && rows.isEmpty && historyHiddenCount == 0 && !savedRefreshing;

  Widget? savedBanner() => historyHiddenCount > 0
      ? SavedHistoryBanner(
          count: historyHiddenCount,
          listEmpty: rows.isEmpty,
          // Web HistoryWindowBanner: paywallUpgrade("history_30d", "saved").
          // Payment is on the Web; a browser that cannot open says so.
          onUpgrade: () => unawaited(
            openWebBillingOrToast(context, w, gate: WebBillingGate.history),
          ),
        )
      : null;

  Widget resourceResultsBody(BuildContext context) {
    final scope = authority;
    final searchHomeNow = atSearchHome;
    // Search keeps its summary, entity matches and a messages skeleton while
    // the first read is in flight (Source `showInitialSkeleton`).
    final searching =
        loading &&
        visibleRows.isEmpty &&
        !(savedPage && historyHiddenCount > 0);
    return searching && !(widget.section == 'search' && !searchHomeNow)
        ? widget.section == 'activity'
              ? const ActivityInboxLoadingList()
              : widget.section == 'saved'
              ? const RaftActivityLoadingList()
              : widget.section == 'tasks'
              ? const RaftTaskLoadingList()
              : const Center(child: RaftSpinner())
        : searchHomeNow
        ? searchHome(scope)
        : widget.section == 'search'
        ? ResourceSearchResults(
            key: PageStorageKey(('search-results', scrollView)),
            controller: searchScroll,
            query: query.text,
            rows: rows,
            entities: currentSearchEntities,
            entitiesExpanded: searchEntitiesExpanded,
            onToggleEntities: toggleSearchEntities,
            onEntityMenu: openSearchEntityMenu,
            historyNotice: searchHistoryNotice,
            origin: w.client.origin,
            agents: rowAgents,
            members: rowPeople,
            dms: w.dms,
            currentUser: w.client.user?.json,
            plan: w.server?.string('plan', 'free') ?? 'free',
            now: widget.clock?.call() ?? DateTime.now(),
            selectedKey: activeSearchKey,
            wrapResult: wrapSearchResult,
            onMessage: (row) => openSearchMessage(row, scope),
            onEntity: (entity) => openSearchEntity(entity, scope),
            appSearch: query.apps,
            onArtifact: openSearchArtifact,
            hasMore: hasMore,
            onMore: () => load(append: true),
            filters: advanced,
            view: rowsView,
            loading: loading,
            failure: error == null ? null : searchFailureKind,
            onRetry: () => load(),
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
        : widget.section == 'activity' && activityLoadFailed
        ? ActivityLoadFailed(
            key: const ValueKey('inbox-load-failed'),
            unavailable: activityFacets.unavailable,
            onRetry: () => load(),
          )
        : visibleRows.isEmpty && !(activityPage && hasMore)
        ? LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              primary: false,
              physics: mobileActivityRefresh
                  ? const AlwaysScrollableScrollPhysics()
                  : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: widget.section == 'saved' && historyHiddenCount > 0
                    ? savedBanner()
                    : widget.section == 'activity' || widget.section == 'saved'
                    // ui/EmptyState: Inbox and Saved share the product empty
                    // state (recipe icon tile, title, copy).
                    ? RaftProductEmptyState(
                        title: widget.section == 'saved'
                            ? raftText(context, 'No saved messages yet')
                            : raftText(context, activityChoice.emptyTitle),
                        description: widget.section == 'saved'
                            ? raftText(
                                context,
                                'Save a message to find it here later.',
                              )
                            : raftText(
                                context,
                                activityChoice.emptyDescription,
                              ),
                        icon: (context, size, color) => RaftIcon(
                          widget.section == 'saved'
                              ? RaftGlyph.bookmark
                              : RaftGlyph.messageSquareText,
                          size: size,
                          color: color,
                        ),
                      )
                    : RaftEmptyState(
                        title: widget.section == 'search'
                            ? 'Search your server'
                            : 'No ${widget.section}',
                        detail: widget.section == 'search'
                            ? 'Enter words to find messages.'
                            : 'There are no items in this view.',
                      ),
              ),
            ),
          )
        : Material(
            color: widget.section == 'activity' || widget.section == 'saved'
                ? resourceSurface
                : RaftTokens.of(context).sidebar,
            child: Stack(
              children: [
                Positioned.fill(
                  child: savedPage && historyHiddenCount > 0
                      ? Column(
                          children: [
                            savedBanner()!,
                            Expanded(child: resourceList()),
                          ],
                        )
                      : resourceList(),
                ),
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

  /// Activity/Saved rows newest first. Rows keep their element when rows land
  /// above them, and the reading anchor keeps the reader's row in place.
  Widget resourceList() {
    final shown = visibleRows;
    final list = widget.section == 'activity'
        ? activityList(shown)
        : ListView.separated(
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
            padding: raftScrollPadding(
              context,
              widget.section == 'saved'
                  ? RaftConversationCardRecipe(
                      RaftTokens.of(context),
                      saved: true,
                    ).listInset
                  : const EdgeInsets.all(16),
            ),
            // SavedPanel loads the next page when its sentinel comes
            // within `rootMargin: 240px` of the scroller.
            scrollCacheExtent: widget.section == 'saved'
                ? const ScrollCacheExtent.pixels(240)
                : null,
            itemCount: shown.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, _) => SizedBox(
              height: widget.section == 'saved'
                  ? RaftConversationCardRecipe(
                      RaftTokens.of(context),
                      saved: true,
                    ).listGap
                  : RaftConversationCardRecipe.gap,
            ),
            itemBuilder: (context, index) => index == shown.length
                ? widget.section == 'saved'
                      ? savedSentinelRow()
                      : RaftButton.text(
                          onPressed: () => load(append: true),
                          child: Text(raftText(context, 'Load more')),
                        )
                : KeyedSubtree(
                    key: listUpdates.keyOf(rowKey(shown[index])),
                    child: item(shown[index], topRule: index > 0),
                  ),
            findItemIndexCallback: listUpdates.indexOf,
          );
    return snapshotted
        ? RaftReadingAnchor(controller: listUpdates.anchor, child: list)
        : list;
  }

  /// The Activity scroller: day groups, the phone's pinned filter row, swipe.
  Widget activityList(List<Map<String, dynamic>> shown) {
    final scope = authority;
    final phone = activityPhoneBar;
    final swipe = RaftInteraction.of(context).touch && phone;
    final facets = activityFacets;
    Widget bar(Widget child) =>
        swipe ? ActivitySwipeBarGuard(open: facets.open, child: child) : child;
    final list = ActivityListView(
      key: PageStorageKey(('resource-list', widget.section, filter)),
      controller: listScroll,
      groups: facets.shown.groups(
        shown,
        formatter: activityRowFormatter(context, w.client.user?.json),
        now: sourceTimeNow(),
        stamp: (
          Localizations.localeOf(context),
          w.client.user?.json['preferredTimezone'],
          w.client.user?.json['preferredTimeFormat'],
        ),
      ),
      surface: resourceSurface,
      physics: mobileActivityRefresh
          ? const AlwaysScrollableScrollPhysics()
          : null,
      phoneBar: phone ? bar(activityToolbar(scope)) : null,
      keyFor: (row) => listUpdates.keyOf(rowKey(row)),
      indexOfKey: listUpdates.indexOf,
      rowBuilder: (context, row, index) => activityCard(row, scope),
      tail: hasMore
          ? RaftButton.text(
              onPressed: () => load(append: true),
              child: Text(raftText(context, 'Load more')),
            )
          : null,
    );
    return ActivitySwipeScope(open: facets.open, child: list);
  }

  bool get scopedSearch =>
      widget.initialSearchDeferUntilQuery &&
      widget.initialSearchChannelId != null;

  String? get searchScopeConversation {
    if (!scopedSearch) return null;
    final id = widget.initialSearchChannelId;
    final channel = [
      ...w.channels,
      ...w.dms,
    ].where((row) => row.id == id).firstOrNull;
    if (channel == null) return null;
    final prefix = channel.type == 'dm' ? '@' : '#';
    return '$prefix${channel.name}';
  }

  List<SearchEntity> get currentSearchEntities => scopedSearch
      ? []
      : searchEntities(
          query.text,
          channels: w.channels.map((c) => c.json).toList(),
          computers: searchComputers,
          agents: searchAgents,
          people: searchPeople,
          principal: w.client.user?.id,
        ).take(searchEntityLimit).toList(growable: false);

  String get entitySearchKey => '${memoryScope?.key}\u0000${query.text.trim()}';
  SearchEntityExpansion get entityExpansion =>
      SearchEntityExpansion.of(searchMemory);
  bool get searchEntitiesExpanded =>
      entityExpansion.isExpanded(entitySearchKey);
  Iterable<SearchEntity> get visibleSearchEntities => searchEntitiesExpanded
      ? currentSearchEntities
      : currentSearchEntities.take(searchEntityPreviewCount);
  void toggleSearchEntities() =>
      setState(() => entityExpansion.toggle(entitySearchKey));

  Widget? get searchHistoryNotice {
    final days = searchHistoryWindow(
      w.server?.string('plan', 'free') ?? 'free',
      widget.clock?.call() ?? DateTime.now(),
    );
    final status = query.apps?.status;
    if (days == null ||
        searchFailureKind != null ||
        status == SearchAppStatus.failed ||
        status == SearchAppStatus.timedOut) {
      return null;
    }
    return SearchHistoryWindowBanner(
      days: days,
      onUpgrade: () =>
          openWebBillingOrToast(context, w, gate: WebBillingGate.history),
    );
  }

  void openSearchEntityMenu(SearchEntity entity, Offset at) {
    final scope = authority;
    setState(() => query.selectedKey = entity.key);
    unawaited(
      showSearchChannelMenu(
        context,
        at: at,
        onOpen: () => openSearchEntity(entity, scope),
      ),
    );
  }

  bool get wide => !RaftAdaptiveWorkspace.compactOf(context);

  void bindSearchApps() => query.bindApps(
    widget.section == 'search' && !scopedSearch ? w : null,
    searchAppsChanged,
  );

  void searchAppsChanged() => setState(() {});

  void openSearchArtifact(ArtifactCard card) {
    setState(() => query.selectedKey = SearchAppResults.keyOf(card));
    rememberSearchOpen(authority, queryText: query.text);
    unawaited(
      openWorkspaceArtifact(
        context,
        w,
        ArtifactLinkTarget(card.id),
        seed: card,
      ),
    );
  }

  Future<void> openSearchMessage(Map<String, dynamic> row, String scope) async {
    if (!accepts(scope) ||
        !rows.any((r) => identical(r, row) || r['id'] == row['id'])) {
      return;
    }
    final channel = row['channelId'], message = row['id'];
    if (channel is! String || message is! String) return;
    setState(() => query.selectedKey = 'message:$message');
    final committed = query.text;
    rememberSearchOpen(scope, queryText: committed);
    if (openTaskFromList(w, row, wide: wide, focusedMessageId: message)) return;
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
    setState(() => query.selectedKey = entity.key);
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
      stashViewWindow();
      rowsView = null;
      if (atSearchHome) {
        rows = [];
        query.clearSelection();
      }
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
    ...visibleSearchEntities.map((e) => e.key),
    ...?query.apps?.hits.map(SearchAppResults.keyOf),
    ...rows.map((r) => 'message:${r['id']}'),
  ];

  String? get activeSearchKey => query.activeKey(searchKeys);

  Widget wrapSearchResult(String key, Widget child) => query.anchor(key, child);

  /// Re-tapping this page's phone tab scrolls its list to the top; Search
  /// focuses its field once it is there (Web `useTabRootScroll`). Activity's
  /// next-unread step replaces this handler (INBOX).
  void bindRetap() {
    final tab = TabRootRetapScope.of(context);
    final here =
        tab == widget.section &&
        widget.initialSearchChannelId == null &&
        (tab != 'tasks' || serverTaskPage);
    retapBinding.bind(
      here ? tab : null,
      () => switch (tab) {
        // Web activityRetap: the next unread row, then back to the top.
        'activity' => unawaited(ActivityRetap.of(w).trigger()),
        'tasks' => retapScroll(taskListScroll),
        'search' => retapScroll(searchScroll, atTop: focusSearchField),
        _ => retapScroll(listScroll),
      },
    );
  }

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
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!queryFocus.hasFocus) return KeyEventResult.ignored;
      if (event is KeyDownEvent && !HardwareKeyboard.instance.isShiftPressed) {
        submitSearch(authority);
      }
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final keys = searchKeys;
    if (keys.isEmpty) return KeyEventResult.ignored;
    final index = keys.indexOf(activeSearchKey ?? keys.first);
    final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
    final next = keys[(index + step).clamp(0, keys.length - 1)];
    setState(() => query.reveal(next, keys, forwards: step > 0));
    return KeyEventResult.handled;
  }

  void submitSearch(String scope) {
    searchDebounce?.cancel();
    final selected = activeSearchKey;
    final entity =
        (atSearchHome && !scopedSearch
                ? frequentEntities
                : visibleSearchEntities)
            .where((entry) => entry.key == selected)
            .firstOrNull;
    final row = rows
        .where((row) => 'message:${row['id']}' == selected)
        .firstOrNull;
    final artifact = query.apps?.hits
        .where((card) => SearchAppResults.keyOf(card) == selected)
        .firstOrNull;
    if (entity != null) {
      openSearchEntity(entity, scope);
    } else if (artifact != null) {
      openSearchArtifact(artifact);
    } else if (row != null) {
      openSearchMessage(row, scope);
    } else {
      load();
    }
  }

  Widget searchHeader(String scope) {
    final shortcuts = RaftInteraction.of(context).shortcutHints;
    final t = RaftTokens.of(context),
        mobile =
            MediaQuery.sizeOf(context).width <
            RaftLayoutMetrics.desktopBreakpoint;
    final recipe = RaftSearchRecipe(t, mobile: mobile);
    final plain = t.option('listGroup.frame', or: 'framed') == 'plain';
    final conversation = searchScopeConversation;
    final row = Row(
      children: [
        if (!plain)
          Container(
            width: RaftLayoutMetrics.panelIcon,
            height: RaftLayoutMetrics.panelIcon,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.colors['primary-soft'],
              border: Border.all(color: t.line, width: t.border),
            ),
            child: const RaftIcon(RaftGlyph.search, size: 18),
          ),
        if (!plain) const SizedBox(width: RaftLayoutMetrics.panelGap),
        Expanded(
          child: RaftSearchInput(
            controller: query,
            focusNode: queryFocus,
            matchCssBorderScale: true,
            phoneTabRoot: mobile && widget.mobileRoot,
            // search.placeholder: the shortcut hint follows on desktop.
            hint: conversation != null
                ? raftFormat(context, 'Search in {conversation}', {
                    'conversation': conversation,
                  })
                : !shortcuts
                ? raftText(context, 'Search channels, DMs, messages…')
                : '${raftText(context, 'Search channels, DMs, messages…')}   '
                      '${globalSearchShortcutLabel()}',
            clearLabel: raftText(context, 'Clear Search'),
            showEscape: shortcuts,
            onClear: () {
              query.clear();
              searchChanged('');
            },
            onChanged: searchChanged,
            onSubmitted: (_) => submitSearch(scope),
          ),
        ),
      ],
    );
    return widget.mobileRoot && (mobile || scopedSearch)
        ? RaftMobileRootHeader(
            key: const Key('search-tab-head'),
            title: 'Search',
            inset: mobile
                ? RaftSearchInput.phoneTabInset
                : RaftLayoutMetrics.panelInset,
            content: row,
          )
        : RaftPanelHeaderBar(
            title: raftText(context, 'Search'),
            background: plain ? t.canvas : null,
            bottomBorder: plain ? recipe.pageBorder : null,
            contentInsets: recipe.headerInsets,
            titleSlot: row,
            backKey: scopedSearch ? const Key('scoped-search-back') : null,
            onBack: mobile || scopedSearch ? widget.onBack ?? () {} : null,
            backTooltip: raftText(context, 'Back'),
          );
  }

  /// raft-ui `search` recipe slots (SearchShellRoot / Filters / Viewport).
  rui.RaftSearchRecipeStyle searchSlots(BuildContext context) {
    final t = RaftTokens.of(context);
    return rui.RaftSearchRecipe.resolve(
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
    final t = RaftTokens.of(context);
    final plain = t.option('listGroup.frame', or: 'framed') == 'plain';
    final recipe = RaftSearchRecipe(t, mobile: !t.desktop);
    final row = searchSlots(context).filtersRow;
    final rowDecoration = row.decoration(
      rui.RaftRecipeTokens(RaftTokens.of(context)),
    );
    return Container(
      padding: plain ? recipe.filterPadding : row.padding,
      decoration: plain ? recipe.pageSeam : rowDecoration,
      child: SizedBox(
        width: double.infinity,
        child: SearchFilterBar(
          filters: advanced,
          senders: senders,
          conversations: {
            for (final c in w.channels.where((c) => c.type != 'thread'))
              c.id: c.name,
          },
          channelOptions: searchChannelChoices(w.channels.map((c) => c.json)),
          scopeConversation: searchScopeConversation,
          menus: filterMenus,
          queryIsEmpty: query.text.trim().isEmpty,
          scope: scope,
          valid: () => accepts(scope),
          onChanged: load,
          channelLabel: (id) =>
              [
                ...w.channels,
                ...w.dms,
              ].where((c) => c.id == id).firstOrNull?.name ??
              raftText(context, 'Channel'),
          channelGlyph: (id) => searchChannelGlyph(
            w.channels.where((c) => c.id == id).firstOrNull?.json,
          ),
        ),
      ),
    );
  }

  /// The unscoped inbox window the shared attention owner is fed from. A
  /// scope's own totals stay the scope's: [scoped] windows only refresh the
  /// accepted items, groups and the unfiltered count.
  void acceptActivityFacets(
    Map value,
    List<Map<String, dynamic>> items, {
    bool scoped = false,
  }) {
    acceptedActivityItems = List.of(items);
    if (!scoped) {
      totalCount = (value['totalCount'] as num?)?.toInt() ?? totalCount;
      totalUnreadCount =
          (value['totalUnreadCount'] as num?)?.toInt() ?? totalUnreadCount;
    }
    activityAllCount =
        ((value['allCount'] ?? value['unfilteredCount']) as num?)?.toInt() ??
        (activeActivityFilter == 'all' &&
                query.text.trim().isEmpty &&
                advanced.channelId == null
            ? (value['totalCount'] as num?)?.toInt() ?? totalCount
            : activityAllCount);
    activityGroups = activityWindowGroups(
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
        query: advanced.list('', filter: activeActivityFilter),
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
      setState(() => acceptActivityFacets(value, items, scoped: true));
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

  /// Web `setFilter`: the Filter menu's choice. It is remembered per server,
  /// shows the choice's last accepted window at once and revalidates it.
  void chooseActivityFilter(ActivityFilterChoice next) {
    final scope = authority;
    if (!accepts(scope) || filter == next.name) return;
    ActivityFilterPreference.write(w.server?.id, next);
    ActivityRetap.of(w).dropAnchor();
    stashViewWindow();
    activityScrollOffsets[filter] = listOffset;
    clearActivityGesture();
    setState(() {
      filter = next.name;
      rows = [];
      rowsView = null;
      hasMore = false;
      listOffset = activityScrollOffsets[next.name] ?? 0;
      listScroll = activityScrolls.putIfAbsent(next.name, newActivityScroll);
      if (!next.isScope) activeActivityFilter = next.name;
    });
    load();
  }

  /// Web `isPhoneTabRoot`: the filter bar is the scroller's first child.
  bool get activityPhoneBar => RaftAdaptiveWorkspace.compactOf(context);

  /// The list (not its loading, failed or empty state) is what the body shows.
  bool get activityShowsList =>
      !(loading && visibleRows.isEmpty) &&
      !activityLoadFailed &&
      (visibleRows.isNotEmpty || hasMore);

  Widget activityToolbar(String scope) => activityFilterBar(
    context,
    choice: activityChoice,
    onChoice: (next) {
      if (accepts(scope)) chooseActivityFilter(next);
    },
    showMarkAllRead: activityShowsMarkAllRead,
    onMarkAllRead: () => unawaited(markAllRead(scope)),
  );

  /// Web `useSettledValue` of the counts line: the numbers change only when
  /// the page of the shown filter has settled.
  void settleActivityCounts() => activityFacets.counts.settle(
    // A failed load has settled too: Web reads "0 in progress · 0 unread".
    loaded:
        (rowsView != null && rowsView == listView && !loading) ||
        activityLoadFailed,
    totalCount: totalCount ?? 0,
    objects: activityFacets.objects,
    totalUnread: totalUnreadCount ?? 0,
    filter: activityChoice.readFilter,
    activeUnreadHint: totalUnreadCount ?? 0,
  );

  /// Web `showMarkAllRead`: settled unread (objects included) above zero.
  bool get activityShowsMarkAllRead =>
      (activityFacets.counts.known
          ? activityFacets.counts.unread
          : (totalUnreadCount ?? 0) +
                activityFacets.objects.objectUnreadCount) >
      0;

  /// Mark all read: after every queued Mark as Read / Unread write settled.
  Future<void> markAllRead(String scope) {
    if (!accepts(scope)) return Future.value();
    return activityMarkAllRead(w, () {
      // Read is a signal: under Unread the rows read here stay, shown read.
      activityUnreadSnapshots.noteRead([
        for (final row in rows) ?activityItemKey(row),
      ]);
      return command('POST', '/channels/inbox/read-all', sourceScope: scope);
    });
  }

  Widget resourceHeader(String scope) {
    final mobile =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    final count = totalCount ?? rows.length;
    if (widget.section == 'activity') settleActivityCounts();
    if (widget.mobileRoot && mobile && widget.section == 'activity') {
      return activityRootHeader(
        w,
        activityCountsString(context, activityFacets.counts),
        loadFailed: activityLoadFailed,
      );
    }
    final header = RaftPageHeader(
      background: widget.section == 'activity' || widget.section == 'saved'
          ? resourceSurface
          : null,
      title: raftText(context, switch (widget.section) {
        'tasks' => 'Tasks',
        'saved' => 'Saved',
        'activity' => 'Activity',
        'search' => 'Search',
        _ => widget.section,
      }),
      subtitle: switch (widget.section) {
        'tasks' => '$count ${raftText(context, 'channel tasks')}',
        // No count before the list is read: the line's box stays, empty.
        'saved' when savedFirstLoad => '\u00a0',
        'saved' =>
          '$count ${raftText(context, count == 1 ? 'saved item' : 'saved items')}',
        'activity' => activityCountsString(context, activityFacets.counts),
        _ => null,
      },
      height: raftPageHeaderHeight(context),
      mobile: mobile,
      leftInset: widget.section == 'activity'
          ? RaftInteraction.of(context).touch
                ? RaftLayoutMetrics.panelInset
                : RaftTokens.of(context).size('css.page-inset', fallback: 16)
          : null,
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
    return activityHeaderJump(
      context,
      w,
      widget.section,
      header,
      loadFailed: activityLoadFailed,
    );
  }

  /// Whether [row] is the item open in the preview, else the row a double
  /// click on the Activity entry marked as the first unread.
  bool activityRowSelected(Map<String, dynamic> row) {
    final target = widget.activitySelectedTarget;
    return widget.section == 'activity' &&
        target != null &&
        activityRowOpen(target, row);
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
  void markActivityRead(
    Map<String, dynamic> row,
    String scope, {
    bool report = false,
  }) {
    if (widget.section != 'activity' || !accepts(scope)) return;
    final key = rowKey(row);
    if (key == null) return;
    final current =
        rows.where((candidate) => rowKey(candidate) == key).firstOrNull ?? row;
    final scopeId = activityScopeId(current);
    final unread = (current['unreadCount'] as num? ?? 0).toInt();
    // A row marked unread with no count is read like any unread row (Web).
    if (scopeId == null ||
        (unread <= 0 && !activityRowMarkedUnread(w, current))) {
      return;
    }
    final frontier = activityFrontier(current);
    if (frontier != null) {
      final serverId = w.client.serverId, principal = w.client.user?.id;
      final known = serverId == null || principal == null
          ? null
          : w.readState.state(serverId, principal, scopeId);
      var versionAtRead = known?['readStateVersion'] as int?;
      final rowState = current['readState'];
      final rowVersion = rowState is Map ? rowState['readStateVersion'] : null;
      if (rowVersion is int &&
          (versionAtRead == null || rowVersion > versionAtRead)) {
        versionAtRead = rowVersion;
      }
      activityReadMarkers[key] = (
        frontier: frontier,
        versionAtRead: versionAtRead,
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
    if (unreadView) activityUnreadSnapshots.noteRead([key]);
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
    if ((w.conversationReads.unread[scopeId] ?? 0) != 0) {
      w.conversationReads.unread = {...w.conversationReads.unread, scopeId: 0};
      w.notifyListeners();
    }
    if (totalUnreadCount != null) {
      acceptUnread?.call(totalUnreadCount);
      if (globalInbox) {
        acceptWindow?.call({
          'items': acceptedActivityItems.isEmpty ? rows : acceptedActivityItems,
          'totalUnreadCount': totalUnreadCount,
        });
      }
    }
    unawaited(persistActivityRead(key, scopeId, scope, report: report));
  }

  Future<void> persistActivityRead(
    String key,
    String scopeId,
    String scope, {
    bool report = false,
  }) async {
    final controller = w;
    final identity = SourceReadAllIdentity.capture(controller.client);
    try {
      await controller.conversationReads.markAllRead(
        scopeId,
        identity: identity,
      );
    } catch (_) {
      if (!identity.current(controller.client)) return;
      // A Mark as Read the person asked for (menu, swipe) says it failed, as
      // Web's `toggleActivityRowRead` does; opening a row does not.
      if (report && mounted) {
        showRaftToast(context, "Couldn't mark it as read. Try again.");
      }
      // Source forgets the suppression and refreshes the inbox in background.
      if (mounted) activityReadMarkers.remove(key);
      await controller.conversationReads.reconcileUnread();
      if (mounted && accepts(scope)) await load(keep: true, quietErrors: true);
    }
  }

  Future<void> openConversation(Map<String, dynamic> row, String scope) async {
    if (!accepts(scope)) return;
    captureActivityAgentCollapse(w, widget.section, row);
    markActivityRead(row, scope);
    if (widget.section == 'activity' && openTaskFromList(w, row, wide: wide)) {
      return;
    }
    if (widget.section == 'saved' && row['channelType'] == 'task') {
      final reply = row['messageId'], conversationId = row['channelId'];
      if (reply is String &&
          conversationId is String &&
          openTaskFromList(
            w,
            row,
            wide: wide,
            focusedMessageId: reply,
            conversationId: conversationId,
          )) {
        return;
      }
    }
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

  Widget savedCard(
    Map<String, dynamic> row,
    String scope, {
    bool topRule = false,
  }) {
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
    );
    return SavedRowCard(
      row: row,
      label: dm
          ? '@$sender'
          : '#${thread ? row['parentChannelName'] : row['channelName']}',
      sender: sender,
      projection: projection,
      time: relativeTime(row['createdAt']),
      topRule: topRule,
      onOpen: () => openConversation(row, scope),
      onContextMenu: (at) => savedMenu(row, scope, at),
      popupOpen: menuRowKey == '${row['messageId']}',
      onRemove: () => removeSaved(row, scope),
    );
  }

  Widget savedSentinelRow() => savedSentinel(
    loading: loading,
    hasMore: hasMore,
    mounted: () => mounted && !loading && hasMore,
    loadMore: () => load(append: true),
  );

  Future<void> savedMenu(
    Map<String, dynamic> row,
    String scope,
    Offset at,
  ) async {
    await scopedMenu<void>(
      scope,
      at,
      (context) => savedMenuContent(
        context,
        onDismiss: () => closeOwnedDialog(context, scope),
        onCopyLink: w.server?.string('slug').isEmpty != false
            ? null
            : () async {
                if (!accepts(scope)) return;
                final thread = row['channelType'] == 'thread';
                final task = row['channelType'] == 'task';
                final text = ContentLinks.messageUrl(
                  origin: ContentLinks.originFor(w.client.origin),
                  slug: w.server!.string('slug'),
                  channelId:
                      '${task ? row['channelId'] : row['parentChannelId'] ?? row['channelId']}',
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
        onCopyMarkdown: () async {
          if (!accepts(scope)) return;
          closeOwnedDialog(context, scope);
          if (accepts(scope)) {
            await Clipboard.setData(
              ClipboardData(text: '${row['content'] ?? ''}'),
            );
          }
        },
        onRemove: () {
          if (!accepts(scope)) return;
          closeOwnedDialog(context, scope);
          removeSaved(row, scope);
        },
      ),
      rowKey: '${row['messageId']}',
    );
  }

  /// ThreadsInbox `activity-context-menu` (`ContextMenuPopup`, inline width 184
  /// bounded by the current recipe's 240 minimum): Mark as
  /// Read / Mark as Unread (not for an unfollowed thread), Done and, for
  /// threads, Unfollow / Follow. The list row uses `active` for the detail
  /// pane only. Opening the pointer menu leaves that row state alone.
  Future<void> activityMenu(
    Map<String, dynamic> row,
    String scope,
    Offset at,
  ) async {
    final unread = activityRowShowsUnread(w, row);
    await scopedMenu<void>(scope, at, (context) {
      void close() => closeOwnedDialog(context, scope);
      return buildActivityContextMenu(
        context,
        row,
        unread: unread,
        muteChannel: activityMuteChannel(row),
        onDismiss: close,
        onAction: (action) {
          if (!accepts(scope)) return;
          close();
          final channel = activityMuteChannel(row);
          if (action == ActivityContextAction.toggleRead) {
            unawaited(toggleActivityRead(row, scope, unread));
          } else if (action == ActivityContextAction.mute ||
              action == ActivityContextAction.unmute) {
            // The menu's Mute is immediate and silent (no Undo toast).
            if (channel != null) {
              unawaited(
                activityFacets.undo?.mute(
                  row,
                  channel,
                  '',
                  muted: action == ActivityContextAction.mute,
                ),
              );
            }
          } else {
            activityRowAction(row, action.name, scope);
          }
        },
      );
    }, placementSize: activityContextMenuPlacement);
  }

  /// Menu "Mark as read" reads the row's scope. A complete unread ACK projects
  /// through the shared owner; only an unprojectable reply needs an inbox read.
  Future<void> toggleActivityRead(
    Map<String, dynamic> row,
    String scope,
    bool unread,
  ) async {
    if (unread) return markActivityRead(row, scope, report: true);
    final id = row[row['kind'] == 'thread' ? 'threadChannelId' : 'channelId'];
    if (id is! String) return;
    var projected = false;
    try {
      projected = await w.conversationReads.markUnreadWithProjection(
        id,
        onNothingUnread: () => showNothingUnreadToast(this),
      );
    } catch (_) {
      if (mounted) {
        showRaftToast(context, "Couldn't mark it as unread. Try again.");
      }
    }
    if (!mounted || !accepts(scope)) return;
    if (!projected) await load(keep: true, quietErrors: true);
  }

  ActivityRowLookups activityLookups() => ActivityRowLookups(
    controller: w,
    agents: rowAgents,
    people: rowPeople,
    directorySenderLabel: directorySenderLabel,
    stableSender: stableSender,
  );

  /// The stored channel a row's Mute acts on (a channel, or a DM).
  RaftChannel? activityMuteChannel(Map<String, dynamic> row) {
    final id = row['channelId'];
    if (id is! String) return null;
    // A DM row's channel is a stored DM (Web `dmChannel`), never a channel.
    return switch (row['kind']) {
      'channel' => w.channels.where((c) => c.id == id).firstOrNull,
      'dm' => w.dms.where((c) => c.id == id).firstOrNull,
      _ => null,
    };
  }

  /// Done and Unfollow wait out their Undo on every route; the rest is the
  /// page's own.
  void activityRowAction(
    Map<String, dynamic> row,
    String action,
    String scope,
  ) {
    final undo = activityFacets.undo;
    if (!accepts(scope) || undo == null) {
      unawaited(activityAction(row, action, scope));
    } else if (action == 'done') {
      undo.done(row);
    } else if (action == 'unfollow') {
      undo.unfollow(
        row,
        activityConversationLabel(context, row, activityLookups(), filter),
      );
    } else {
      unawaited(activityAction(row, action, scope));
    }
  }

  /// The object (Artifact) write of a row: Done, or read on open
  /// (`ObjectActivityApi`, the one request Web sends). A refusal brings the
  /// row back with the list's own refresh and, for read, says so.
  Future<void> writeActivityObject(
    Map<String, dynamic> row,
    String scope,
    String action,
  ) async {
    try {
      final api = ObjectActivityApi(w.client);
      await (action == 'done' ? api.done(row) : api.read(row));
    } catch (_) {
      if (!mounted || !accepts(scope)) return;
      if (action == 'read') {
        showRaftToast(context, "Couldn't mark it as read. Try again.");
      }
      unawaited(load(keep: true, quietErrors: true));
    }
  }

  Future<void> markActivityObjectRead(
    Map<String, dynamic> row,
    String scope,
  ) async {
    setState(() {
      rows = [
        for (final r in rows)
          if (rowKey(r) == rowKey(row)) {...r, 'unreadCount': 0} else r,
      ];
    });
    await writeActivityObject(row, scope, 'read');
  }

  /// An Artifact row opens its viewer and reads (Web `openObjectRow`).
  void openActivityObject(Map<String, dynamic> row, String scope) {
    if (!accepts(scope)) return;
    final target = artifactActivityTarget(row);
    if (target == null) return;
    if (((row['unreadCount'] as num?) ?? 0) > 0) {
      unawaited(markActivityObjectRead(row, scope));
    }
    unawaited(openWorkspaceArtifact(context, w, target));
  }

  Widget activityCard(Map<String, dynamic> row, String scope) {
    final pin = activityGestureMatches(scope);
    final facets = activityFacets;
    final host = ActivityRowHost(
      controller: w,
      filter: filter,
      interval: pin ? activityGestureInterval! : doubleClickInterval,
      pinnedHeight: pin ? activityGestureHeights[rowKey(row)] : null,
      selected: activityRowSelected(row),
      located: ActivityFirstUnread.of(w).highlights(rowKey(row)),
      canonical: widget.onActivityCanonical != null,
      open: () => openConversation(row, scope),
      onOpenObject: (r) => openActivityObject(r, scope),
      activate: (detail, height, {bool pointer = false}) =>
          activateActivity(row, scope, detail, height, pointer: pointer),
      menu: (at) => activityMenu(row, scope, at),
      action: (action) => activityRowAction(row, action, scope),
      stableSender: stableSender,
      directorySenderLabel: directorySenderLabel,
      agents: rowAgents,
      people: rowPeople,
    );
    final undo = facets.undo;
    return ListedActivityCard(
      row: row,
      host: host,
      authority: scope,
      swipe: undo == null
          ? null
          : ActivitySwipeHooks(
              open: facets.open,
              undo: undo,
              muteChannel: activityMuteChannel,
              muted: activityMuted,
              toggleRead: (r, unread) =>
                  unawaited(toggleActivityRead(r, scope, unread)),
              key: rowKey,
            ),
    );
  }

  /// `task.status.emptyGroup`: "No {status} tasks"
  String _emptyLaneLabel(BuildContext context, String status) => raftFormat(
    context,
    'No {status} tasks',
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
              MediaQuery.sizeOf(context).width < 768 &&
                      t.option('listGroup.frame', or: 'framed') != 'plain'
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
                    child: RaftButton.text(
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
      '': 'All Channels',
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
              child: RaftTextInput(
                controller: query,
                hintText: raftText(context, 'Filter Activity'),
                leadingGlyph: RaftGlyph.search,
                onSubmitted: (_) {
                  if (accepts(scope)) load();
                },
              ),
            ),
          filterMenu(
            'Filter by Channel',
            channelOptions[advanced.channelId] ?? 'All Channels',
            channelOptions,
            (id) {
              advanced.channelId = id.isEmpty ? null : id;
              load();
            },
          ),
          if (widget.section == 'search') ...[
            filterMenu(
              'Filter by Sender',
              advanced.sender?.label ?? 'All Senders',
              {
                '': 'All Senders',
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
            RaftToggleGroup<String>(
              multiple: true,
              semanticLabel: 'Search scope',
              value: {...advanced.scopes},
              onChanged: (next) {
                if (!accepts(scope)) return;
                for (final key in const ['mentioned', 'humans', 'agents']) {
                  if (next.contains(key) != advanced.scopes.contains(key)) {
                    advanced.toggleScope(key);
                  }
                }
                load();
              },
              items: [
                for (final entry in const {
                  'mentioned': 'Mentions Me',
                  'humans': 'Humans',
                  'agents': 'Agents',
                }.entries)
                  RaftToggleGroupItem(value: entry.key, label: entry.value),
              ],
            ),
            filterMenu(
              'Search Date Range',
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
              'Sort Search Results',
              advanced.searchSort == 'recent' ? 'Recent' : 'Relevant',
              const {'relevance': 'Relevant', 'recent': 'Recent'},
              (value) {
                advanced.searchSort = value;
                load();
              },
            ),
          ] else ...[
            filterMenu(
              'Sort Conversations',
              advanced.direction == 'asc' ? 'Oldest First' : 'Newest First',
              const {'desc': 'Newest First', 'asc': 'Oldest First'},
              (value) {
                advanced.direction = value;
                load();
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
    if ((row['kind'] == 'mention_action' || isActivityObjectRow(row)) &&
        action == 'done') {
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
      if (isActivityObjectRow(row)) {
        unawaited(writeActivityObject(row, scope, 'done'));
      }
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
      // Done here takes a kept row out of the Unread list at once.
      final restoreKept = activityItemKey(row) == null
          ? null
          : activityUnreadSnapshots.take(activityItemKey(row)!);
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
      w.conversationReads.unread[channelId] = 0;
      w.notifyListeners();
      if (totalUnreadCount != null) {
        acceptUnread?.call(totalUnreadCount);
        if (globalInbox) {
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
        restoreKept?.call();
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
        if (row['conversationKind'] == 'task') {
          _services.followedThreads.acknowledgeTask(
            id,
            following: action == 'follow',
          );
        } else if (parentId is String && parentId.isNotEmpty) {
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
          if (totalUnreadCount != null) {
            totalUnreadCount = (totalUnreadCount! - cleared).clamp(0, 1 << 53);
          }
          loading = false;
        });
        if (totalUnreadCount != null) {
          acceptUnread?.call(totalUnreadCount);
          if (globalInbox) {
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

  /// Web `showActivityUnreadSnapshot`: under Unread every row the list has
  /// shown that was then read stays, shown read, until the list changes, the
  /// visit ends or it reloads.
  List<Map<String, dynamic>> unreadSnapshotRows(
    List<Map<String, dynamic>> rows,
  ) => activityUnreadSnapshots.shown(
    rows,
    list: filter == 'unread'
        ? ActivityUnreadSnapshotStore.listKey(
            serverId: w.server?.id,
            filter: filter,
          )
        : null,
    visit: ActivityUnreadScope.of(w).visit.current,
  );

  List<Map<String, dynamic>> get visibleRows {
    if (widget.section == 'activity') {
      final base = activityGestureCurrent
          ? ActivityRowWindow.from(rows).retaining(activityGestureRows!)
          : unreadSnapshotRows(rows);
      return activityFacets.shown.order(activityUndoShown(base));
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
          child: TaskV2FlagBuilder(
            controller: w,
            builder: (_, v2) => Wrap(
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
                                'user:${self.id}': raftTextZh(
                                  context,
                                  field == 'Creator'
                                      ? 'Created by me'
                                      : 'Assigned to me',
                                  field == 'Creator' ? '我创建的' : '分配给我的',
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
                        selfIdentity: self == null
                            ? null
                            : ResourceSender(self.id, 'user', self.name),
                        identityAvatars: field != 'Channel'
                            ? projectTaskFilterAvatars(
                                origin: w.client.origin,
                                identityKeys: names.keys,
                                agents: rowAgents,
                                members: rowPeople,
                                currentUser: self?.json,
                              )
                            : const {},
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
                // TasksPanel.tsx: "New Task" (Plus 12) is channel mode only;
                // task v2's Tasks page has it too (TasksPageToolbar.tsx).
                if ((widget.channelId != null || v2) &&
                    w.server?.string('role') != 'guest')
                  RaftNewTaskButton(
                    onPressed: () => createTask(sourceScope: scope),
                  ),
                RaftSegmentedControl<String>(
                  value: taskLayout,
                  visualHeight: RaftMetrics.buttonMd,
                  minimumTargetSize: RaftMetrics.buttonMd,
                  label: raftText(context, 'Task view'),
                  items: const [
                    RaftSegmentedOption(
                      value: 'board',
                      label: 'Board',
                      tooltip: 'Show Task Board',
                      glyph: RaftGlyph.columns3,
                    ),
                    RaftSegmentedOption(
                      value: 'list',
                      label: 'List',
                      tooltip: 'Show Task List',
                      glyph: RaftGlyph.layoutList,
                    ),
                  ],
                  onChanged: (layout) {
                    if (accepts(scope) && taskLayout != layout) {
                      taskLayout = layout;
                      rememberTaskView(layout);
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
      t.option('listGroup.frame', or: 'framed') == 'plain'
      ? t.canvas
      : (t.dark ? t.sidebar.withAlpha(0) : t.sidebar);

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
            : 'Create one with the Create Task button.',
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
        padding: raftScrollPadding(
          context,
          widget.section == 'activity' || widget.section == 'saved'
              ? RaftConversationCardRecipe(RaftTokens.of(context)).listInset
              : EdgeInsets.symmetric(
                  horizontal:
                      MediaQuery.sizeOf(context).width <
                          RaftLayoutMetrics.desktopBreakpoint
                      ? 16
                      : t.size('space.tasksViewportInline', fallback: 20),
                  vertical: 16,
                ),
        ),
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
                      moveTaskStatus(
                        command,
                        taskById(payload.row['id']) ?? payload.row,
                        status,
                        payload.scope,
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

  Widget item(
    Map<String, dynamic> row, {
    String? sourceScope,
    bool topRule = false,
  }) {
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
      final card = RaftTaskCard(
        key: ValueKey('task-${row['id']}'),
        title: name,
        number: '${row['taskNumber'] ?? row['number'] ?? ''}',
        // TaskCard shows the channel chip only on the server-wide page.
        channel: widget.channelId != null ? '' : '${row['channelName'] ?? ''}',
        status: status,
        description: '${row['descriptionPreview'] ?? row['description'] ?? ''}',
        assignee: row['claimedByName'] as String?,
        legacy: row['isLegacy'] == true,
        onTap: () => taskDetails(row, sourceScope: scope),
        statusOptions: allowed,
        onStatus:
            role == 'guest' ||
                row['readOnlyReason'] != null ||
                !w.channels.any(
                  (c) => c.id == row['channelId'] && c.joined && !c.archived,
                )
            ? null
            : (next) => moveTaskStatus(
                command,
                taskById(row['id']) ?? row,
                next,
                scope,
              ),
      );
      // Closing the task beside the list puts focus back on its card.
      final slotKey = ValueKey('task-slot-row-${row['id']}');
      return TaskSlotRow(key: slotKey, taskId: row['id'], child: card);
    }
    if (section == 'saved') return savedCard(row, scope, topRule: topRule);
    if (section == 'activity') {
      return activityCard(row, scope);
    }
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
        (dialogContext) => CreateTaskDialog.forChannel(
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
    await scopedDialog<void>(
      scope,
      (dialogContext) => CreateTaskDialog.forChannel(
        controller: w,
        defaultChannelId: w.channel?.id,
        onCreated: () async {
          if (!accepts(scope)) return;
          await w.refreshUnread();
          if (accepts(scope)) await load(keep: rows.isNotEmpty);
        },
      ),
      form: true,
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
        (context) => taskAssignmentDialog(
          context: context,
          choices: choices,
          claimedById: task['claimedById'],
          claimedByType: task['claimedByType'],
          onSelected: (value) => closeOwnedDialog(context, scope, value),
          onClose: () => closeOwnedDialog(context, scope),
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
        (context) => RaftAlertDialog(
          title: Text(raftText(context, 'Delete task')),
          content: Text('${task['title']}'),
          actions: [
            RaftButton.text(
              onPressed: () => closeOwnedDialog(context, scope, false),
              child: Text(raftText(context, 'Keep Task')),
            ),
            RaftButton(
              label: 'Delete task',
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

class _TaskDrag {
  const _TaskDrag(this.row, this.scope);
  final Map<String, dynamic> row;
  final String scope;
}
