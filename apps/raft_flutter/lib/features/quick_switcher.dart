import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/search_memory.dart';
import '../data/workspace_controller.dart';
import 'artifacts/artifact_models.dart';
import 'quick_switcher_model.dart';
import 'resource_cards.dart';
import 'resource_filters.dart';
import 'resource_search.dart';
import 'search_app_results.dart';
import 'search_continuation.dart';
import 'search_continue_footer.dart';
import 'search_filter_bar.dart';
import 'search_sections.dart';
import 'sender_avatar_projection.dart';

/// One immutable view of the workspace the switcher reads. The host builds it
/// from data it already holds (channels, DMs, the shared entity directory and
/// the visit history), so the switcher has results at its first frame.
class QuickSwitcherData {
  const QuickSwitcherData({
    required this.catalog,
    required this.visited,
    required this.agents,
    required this.members,
    required this.origin,
    this.excludeChannelId,
    this.currentUser,
    this.channels = const [],
    this.dms = const [],
    this.plan = 'free',
  });
  final QuickSwitcherCatalog catalog;

  /// Visited conversation ids, most recent first.
  final List<String> visited;
  final String? excludeChannelId;
  final List<Map<String, dynamic>> agents, members, channels, dms;
  final Map<String, dynamic>? currentUser;
  final String origin, plan;
}

/// What the switcher opens with. Source: the rail entry starts empty; every
/// other entry restores the saved query and filters and selects the query;
/// "search this channel" arrives with its channel filter and waits for a query.
class QuickSwitcherSeed {
  const QuickSwitcherSeed({
    this.state = const SearchStateSnapshot(),
    this.selectQuery = false,
    this.deferUntilQuery = false,
  });
  final SearchStateSnapshot state;
  final bool selectQuery, deferUntilQuery;
}

/// Last message-search answer (Source `cachedSearchSnapshot`): reopening with
/// the same request paints at once instead of waiting for the network.
class QuickSwitcherSnapshot {
  const QuickSwitcherSnapshot(
    this.authority,
    this.key,
    this.results, {
    this.continuation = SearchContinuation.none,
  });
  final String authority, key;
  final List<Map<String, dynamic>> results;
  final SearchContinuation continuation;
}

enum QuickSwitcherFailure { requestFailed, queryTooBroad, searchTimeout }

QuickSwitcherFailure classifySearchFailure(Object error) {
  final code = error is RaftApiException ? error.details['code'] : null;
  return switch (code) {
    'QUERY_TOO_BROAD' => QuickSwitcherFailure.queryTooBroad,
    'SEARCH_TIMEOUT' => QuickSwitcherFailure.searchTimeout,
    _ => QuickSwitcherFailure.requestFailed,
  };
}

/// Source SearchOverlay.tsx and the overlay mode of MessageSearchPage.tsx (the
/// Slack command palette), opened by the rail's Search button and by
/// Cmd/Ctrl+K: a fixed-size card floating over the current page, the field as
/// its header, recent conversations when nothing is typed, otherwise the
/// filter chips, the exact destination, the "Search for" row, ranked
/// destinations and a short message preview. Up/Down move the cursor, Return
/// opens it, Escape closes.
class QuickSwitcher extends StatefulWidget {
  const QuickSwitcher({
    super.key,
    required this.listenable,
    required this.data,
    required this.onClose,
    required this.onOpenEntity,
    required this.onOpenMessage,
    required this.onSearchAll,
    this.seed = const QuickSwitcherSeed(),
    this.onStateChanged,
    this.searchMessages,
    this.snapshot,
    this.onSnapshot,
    this.authority = '',
    this.clock,
    this.searchAnchor,
    this.appSearchWorkspace,
    this.onOpenArtifact,
    this.entityExpansion,
    this.onUpgrade,
  });

  /// Notifies when the workspace behind [data] changes.
  final Listenable listenable;
  final QuickSwitcherData Function() data;
  final VoidCallback onClose;
  final void Function(SearchEntity entity, String query) onOpenEntity;
  final void Function(Map<String, dynamic> row, String query) onOpenMessage;
  final void Function(String query) onSearchAll;
  final WorkspaceController? appSearchWorkspace;
  final void Function(ArtifactCard card, String query)? onOpenArtifact;
  final SearchEntityExpansion? entityExpansion;
  final VoidCallback? onUpgrade;
  final QuickSwitcherSeed seed;

  /// Committed query and filters, for the saved Search state.
  final void Function(SearchStateSnapshot state)? onStateChanged;

  /// Message search (`GET /messages/search`) for the request [params].
  final Future<Object?> Function(Map<String, dynamic> params)? searchMessages;
  final QuickSwitcherSnapshot? Function()? snapshot;
  final void Function(QuickSwitcherSnapshot snapshot)? onSnapshot;

  /// Identity of the account and workspace the snapshot belongs to.
  final String authority;
  final DateTime Function()? clock;

  /// The mounted top search field, read again when viewport layout changes.
  final Rect? Function()? searchAnchor;

  /// Source OVERLAY_MESSAGE_PREVIEW_LIMIT and MAX_ENTITY_RESULTS.
  static const messagePreviewLimit = 5;
  static const entityLimit = searchEntityLimit;
  static const debounce = Duration(milliseconds: 200);

  /// Source searchOverlayCardStyle fallback placement and size.
  static Rect cardRect(Size viewport, {Rect? anchor}) =>
      RaftQuickSwitcherMetrics.cardRect(viewport, anchor: anchor);

  @override
  State<QuickSwitcher> createState() => _QuickSwitcherState();
}

class _Row {
  const _Row(
    this.key, {
    this.entity,
    this.message,
    this.artifact,
    this.all = false,
  });
  final String key;
  final SearchEntity? entity;
  final Map<String, dynamic>? message;
  final ArtifactCard? artifact;
  final bool all;
}

const _allKey = 'quick-switcher:all-results';

class _QuickSwitcherState extends State<QuickSwitcher> {
  final controller = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  final rowKeys = <String, GlobalKey>{};
  final filterMenus = <MenuController>{};
  final filters = ResourceFilters();
  late final bool deferUntilQuery = widget.seed.deferUntilQuery;
  String? restoringSender, contextMenuKey;
  String query = '';
  String? committed;
  String? selectedKey;
  String cursorEpoch = '';
  Timer? debounceTimer;
  int ticket = 0;
  List<Map<String, dynamic>> messages = const [];
  String? messagesKey;
  bool loading = false;
  QuickSwitcherFailure? failure;
  SearchContinuation continuation = SearchContinuation.none;
  late final entityExpansion =
      widget.entityExpansion ?? SearchEntityExpansion();
  SearchAppResults? appSearch;

  // Ranking is memoized per (catalog, query); a rebuild from an unrelated
  // workspace notification never re-ranks.
  QuickSwitcherCatalog? rankedCatalog;
  String rankedQuery = '';
  List<SearchEntity> ranked = const [];

  @override
  void initState() {
    super.initState();
    final state = widget.seed.state;
    filters
      ..channelId = state.channelId
      ..scopes.addAll(state.scopes)
      ..timeRange = state.range
      ..searchSort = state.sort;
    restoringSender = state.senderKey;
    resolveSender(widget.data());
    controller.text = state.query;
    query = state.query.trim();
    committed = query;
    if (widget.seed.selectQuery && state.query.isNotEmpty) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: state.query.length,
      );
    }
    controller.addListener(textChanged);
    if (widget.appSearchWorkspace case final workspace?) {
      appSearch = SearchAppResults(
        workspace,
        controller,
        previewLimit: QuickSwitcher.messagePreviewLimit,
      )..addListener(searchAppsChanged);
    }
    // Source: the field takes focus as the overlay mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
    final cached = widget.snapshot?.call();
    final params = requestParams();
    if (cached != null &&
        params != null &&
        cached.authority == widget.authority &&
        cached.key == jsonEncode(params)) {
      messages = cached.results;
      messagesKey = cached.key;
      continuation = cached.continuation;
    } else {
      fetch();
    }
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    appSearch?.dispose();
    ticket++;
    for (final menu in filterMenus.toList()) {
      if (menu.isOpen) menu.close();
    }
    controller
      ..removeListener(textChanged)
      ..dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  void searchAppsChanged() => setState(() {});

  bool get composing =>
      controller.value.composing.isValid &&
      !controller.value.composing.isCollapsed;

  /// Source hasSearchIntent: a query, or filters unless the entry waits for a
  /// query ("search this channel").
  bool get hasIntent =>
      query.isNotEmpty || (filters.hasSearchFilter && !deferUntilQuery);

  SearchStateSnapshot get snapshotOfState => SearchStateSnapshot(
    query: committed ?? '',
    channelId: filters.channelId,
    senderKey: filters.sender?.key ?? restoringSender,
    scopes: filters.scopes.toList(),
    range: filters.timeRange,
    sort: filters.searchSort,
  );

  void resolveSender(QuickSwitcherData data) {
    final key = restoringSender;
    if (key == null) return;
    final match = quickSwitcherSenders(
      members: data.members,
      agents: data.agents,
      currentUser: data.currentUser,
    ).where((s) => s.key == key).firstOrNull;
    if (match != null) {
      filters.sender = match;
      restoringSender = null;
    }
  }

  Map<String, dynamic>? requestParams() {
    final text = committed ?? '';
    if (text.isEmpty && (!filters.hasSearchFilter || deferUntilQuery)) {
      return null;
    }
    return filters.search(text, now: widget.clock?.call());
  }

  void textChanged() {
    final next = controller.text.trim();
    if (next != query) {
      setState(() {
        query = next;
        selectedKey = null;
      });
    }
    // Source getCommittedSearchQuery: composition text is ranked but is not
    // committed to the request or the saved state.
    if (!composing && committed != next) {
      committed = next;
      stateChanged();
    }
  }

  void stateChanged() {
    widget.onStateChanged?.call(snapshotOfState);
    fetch();
  }

  void fetch({bool retry = false}) {
    debounceTimer?.cancel();
    final mine = ++ticket;
    final search = widget.searchMessages;
    final params = requestParams();
    if (search == null || params == null) {
      if (messagesKey != null || loading || failure != null) {
        setState(() {
          messages = const [];
          messagesKey = null;
          continuation = SearchContinuation.none;
          loading = false;
          failure = null;
        });
      }
      return;
    }
    final key = jsonEncode(params);
    if (!retry && key == messagesKey) {
      if (failure != null || loading) {
        setState(() {
          failure = null;
          loading = false;
        });
      }
      return;
    }
    setState(() {
      messages = const [];
      messagesKey = null;
      continuation = SearchContinuation.none;
      failure = null;
      loading = true;
    });
    Future<void> request() async {
      if (!mounted || mine != ticket) return;
      try {
        final found = await search(params);
        if (!mounted || mine != ticket) return;
        acceptMessages(found, key);
      } catch (error) {
        if (!mounted || mine != ticket) return;
        setState(() {
          failure = classifySearchFailure(error);
          loading = false;
        });
      }
    }

    if (retry) {
      unawaited(request());
    } else {
      debounceTimer = Timer(QuickSwitcher.debounce, request);
    }
    // Typing waits out the debounce; explicit retries start immediately.
  }

  void acceptMessages(Object? answer, String key, {bool append = false}) {
    final list = answer is Map ? answer['results'] : answer;
    final byId = <Object?, Map<String, dynamic>>{
      if (list is List)
        for (final row in list.whereType<Map>())
          row['id']: Map<String, dynamic>.from(row),
    };
    setState(() {
      messages = [
        if (append) ...messages,
        ...byId.values.where(
          (row) =>
              !append || !messages.any((shown) => shown['id'] == row['id']),
        ),
      ];
      continuation = SearchContinuation.read(answer);
      messagesKey = key;
      failure = null;
      loading = false;
    });
    widget.onSnapshot?.call(
      QuickSwitcherSnapshot(
        widget.authority,
        key,
        messages,
        continuation: continuation,
      ),
    );
  }

  Future<void> continueMessages() async {
    final search = widget.searchMessages, cursor = continuation.cursor;
    final key = messagesKey, params = requestParams();
    if (search == null ||
        cursor == null ||
        key == null ||
        params == null ||
        loading) {
      return;
    }
    final mine = ticket;
    setState(() => failure = null);
    try {
      final page = await search(
        {...params, 'cursor': cursor}..remove('offset'),
      );
      if (mounted && mine == ticket) acceptMessages(page, key, append: true);
    } catch (error) {
      if (mounted && mine == ticket) {
        setState(() => failure = classifySearchFailure(error));
      }
    }
  }

  void retry() => fetch(retry: true);

  void filtersChanged() {
    setState(() => selectedKey = null);
    stateChanged();
  }

  List<SearchEntity> rank(QuickSwitcherData data) {
    if (!identical(rankedCatalog, data.catalog) || rankedQuery != query) {
      rankedCatalog = data.catalog;
      rankedQuery = query;
      ranked = query.isEmpty ? const [] : data.catalog.rank(query);
    }
    return ranked;
  }

  GlobalKey keyFor(String key) => rowKeys.putIfAbsent(key, GlobalKey.new);

  void openRow(_Row row) {
    final text = query;
    if (row.all) {
      widget.onSearchAll(text);
    } else if (row.entity != null) {
      widget.onOpenEntity(row.entity!, text);
    } else if (row.artifact case final card?) {
      widget.onOpenArtifact?.call(card, text);
    } else if (row.message != null) {
      widget.onOpenMessage(row.message!, text);
    }
  }

  void select(List<_Row> rows, int index) {
    if (rows.isEmpty) return;
    final next = rows[index.clamp(0, rows.length - 1)];
    setState(() => selectedKey = next.key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rowKeys[next.key]?.currentContext;
      if (mounted && context != null) {
        Scrollable.ensureVisible(context, alignment: .5);
      }
    });
  }

  KeyEventResult keyEvent(List<_Row> rows, int selected, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final modifier = primaryShortcutModifierDown();
    // IME composition owns Return, Escape and the arrows.
    if (composing) return KeyEventResult.ignored;
    if (modifier && key == LogicalKeyboardKey.keyK) {
      focus.requestFocus();
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (rows.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      select(rows, selected + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      select(rows, selected - 1);
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      if (event is KeyDownEvent) openRow(rows[selected]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final card = QuickSwitcher.cardRect(
      size,
      anchor: widget.searchAnchor?.call(),
    );
    return Stack(
      children: [
        Positioned.fromRect(
          rect: card,
          child: ListenableBuilder(
            listenable: widget.listenable,
            builder: (context, _) => _card(context),
          ),
        ),
      ],
    );
  }

  List<SearchEntity> entityResults(List<SearchEntity> list) =>
      list.take(QuickSwitcher.entityLimit).toList();

  String get entitySearchKey => '${widget.authority}\u0000$query';
  bool get entitiesExpanded =>
      entityExpansion.isExpanded(entitySearchKey, overlay: true);

  void toggleEntities() =>
      setState(() => entityExpansion.toggle(entitySearchKey, overlay: true));

  List<Map<String, dynamic>> get visibleMessages => [
    for (final m in messages.take(QuickSwitcher.messagePreviewLimit))
      if (m['id'] != null) m,
  ];

  List<_Row> buildRows(
    QuickSwitcherData data,
    SearchEntity? exact,
    List<SearchEntity> entities,
  ) {
    if (!hasIntent) {
      return [
        for (final entity in data.catalog.recent(
          visited: data.visited,
          excludeChannelId: data.excludeChannelId,
        ))
          _Row(entity.key, entity: entity),
      ];
    }
    return [
      if (exact != null) _Row(exact.key, entity: exact),
      const _Row(_allKey, all: true),
      for (final entity in entities) _Row(entity.key, entity: entity),
      for (final card in appSearch?.hits ?? const <ArtifactCard>[])
        _Row(SearchAppResults.keyOf(card), artifact: card),
      for (final message in visibleMessages)
        _Row('message:${message['id']}', message: message),
    ];
  }

  Widget _card(BuildContext context) {
    final data = widget.data();
    if (restoringSender != null) resolveSender(data);
    final list = query.isEmpty ? const <SearchEntity>[] : rank(data);
    final exact = query.isEmpty ? null : findExactDestination(query, list);
    final entities = entityResults(list)
        .where((entity) => entity.key != exact?.key)
        .toList(growable: false);
    final shown = entitiesExpanded
        ? entities
        : entities.take(searchEntityPreviewCount).toList(growable: false);
    // The cursor returns to the top row whenever the query changes or an exact
    // destination surfaces from a later rerank (Source overlayCursorEpoch).
    final epoch = '$query\u0000${exact?.key ?? ''}';
    if (epoch != cursorEpoch) {
      cursorEpoch = epoch;
      selectedKey = null;
    }
    final rows = buildRows(data, exact, shown);
    var selected = selectedKey == null
        ? 0
        : rows.indexWhere((r) => r.key == selectedKey);
    if (selected < 0) selected = 0;
    final selectedRow = rows.isEmpty ? null : rows[selected];
    return Focus(
      key: const ValueKey('search-overlay-card'),
      onKeyEvent: (_, event) => keyEvent(rows, selected, event),
      child: RaftQuickSwitcherFrame(
        semanticLabel: raftText(context, 'Search'),
        selectLabel: raftText(context, 'Select'),
        openLabel: raftText(context, 'Open'),
        field: RaftQuickSwitcherField(
          controller: controller,
          focusNode: focus,
          hint: raftText(context, 'Channels, people, messages…'),
          clearLabel: raftText(context, 'Clear Search'),
          onClear: () {
            controller.clear();
            focus.requestFocus();
          },
        ),
        filters: hasIntent ? _filters(context, data) : null,
        body: _body(context, data, rows, selectedRow, exact, entities),
      ),
    );
  }

  Widget _filters(BuildContext context, QuickSwitcherData data) {
    final channels = searchChannelChoices(data.channels);
    return RaftQuickSwitcherFilterRow(
      child: SearchFilterBar(
        filters: filters,
        senders: quickSwitcherSenders(
          members: data.members,
          agents: data.agents,
          currentUser: data.currentUser,
        ),
        conversations: {
          for (final channel in channels) channel.id: channel.label,
        },
        channelOptions: channels,
        menus: filterMenus,
        queryIsEmpty: query.isEmpty,
        scope: widget.authority,
        valid: () => mounted,
        onChanged: filtersChanged,
        channelLabel: (id) =>
            channels.where((channel) => channel.id == id).firstOrNull?.label ??
            raftText(context, 'Channel'),
        channelGlyph: (id) =>
            channels.where((channel) => channel.id == id).firstOrNull?.glyph ??
            RaftGlyph.hash,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    QuickSwitcherData data,
    List<_Row> rows,
    _Row? selectedRow,
    SearchEntity? exact,
    List<SearchEntity> entities,
  ) {
    final status = appSearch?.status ?? SearchAppStatus.idle;
    final days = searchHistoryWindow(
      data.plan,
      widget.clock?.call() ?? DateTime.now(),
    );
    final upgrade = widget.onUpgrade;
    final notice =
        days != null &&
            upgrade != null &&
            failure == null &&
            status != SearchAppStatus.failed &&
            status != SearchAppStatus.timedOut
        ? SearchHistoryWindowBanner(days: days, onUpgrade: upgrade)
        : null;
    Widget entityRow(_Row row, {bool hint = false}) => KeyedSubtree(
      key: keyFor(row.key),
      child: _entityRow(
        context,
        row.entity!,
        data,
        selectedRow?.key == row.key,
        hint,
        () => openRow(row),
      ),
    );
    if (!hasIntent) {
      if (rows.isEmpty) {
        final empty = RaftQuickSwitcherEmpty(
          key: const Key('quick-switcher-empty'),
          title: raftText(context, 'Search everything'),
          detail: raftText(
            context,
            'Search channels, DMs, people, agents, and message history.',
          ),
        );
        return notice == null
            ? empty
            : Column(
                children: [
                  notice,
                  Expanded(child: empty),
                ],
              );
      }
      return RaftQuickSwitcherList(
        key: const Key('quick-switcher-recent'),
        controller: scroll,
        compact: true,
        children: [
          ?notice,
          RaftQuickSwitcherSection(
            heading: raftText(context, 'Recent conversations'),
            glyph: RaftGlyph.clock3,
            children: [for (final row in rows) entityRow(row, hint: true)],
          ),
        ],
      );
    }
    final remaining = [
      for (final row in rows)
        if (row.entity != null && row.entity!.key != exact?.key) row,
    ];
    final visible = visibleMessages;
    final total =
        entities.length +
        (exact == null ? 0 : 1) +
        (appSearch?.hits.length ?? 0) +
        messages.length;
    final empty =
        !loading &&
        total == 0 &&
        failure == null &&
        (status == SearchAppStatus.idle || status == SearchAppStatus.ready);
    // ignore: raft_lints/avoid_render_where_without_or_else -- rows always includes the 'all' row (built with `const _Row(_allKey, all: true)` in the same method).
    final allRow = rows.firstWhere((r) => r.all);
    final trimmed = query;
    return RaftQuickSwitcherList(
      controller: scroll,
      children: [
        RaftQuickSwitcherHead(
          children: [
            // Overlay head: the exact destination, then "Search for".
            if (exact != null) entityRow(rows.first),
            KeyedSubtree(
              key: keyFor(_allKey),
              child: RaftQuickSwitcherActionRow(
                key: const Key('quick-switcher-all-results'),
                glyph: RaftGlyph.search,
                title: trimmed.isEmpty
                    ? raftText(context, 'View All Results')
                    : raftFormat(context, 'Search for “{query}”', {
                        'query': trimmed,
                      }),
                subtitle: raftText(
                  context,
                  'Open the full results page with filters and context preview',
                ),
                selected: selectedRow?.key == _allKey,
                onPressed: () => openRow(allRow),
              ),
            ),
          ],
        ),
        ?notice,
        if (total == 0 && continuation.pending)
          SearchIncompleteEmpty(
            key: ValueKey(messagesKey),
            continuation: continuation,
            onMore: continueMessages,
            failure: failure != null,
          )
        else if (empty)
          RaftQuickSwitcherNoResults(
            key: const Key('quick-switcher-no-results'),
            title: trimmed.isEmpty
                ? raftText(context, 'No messages match your filters')
                : raftFormat(context, 'No results for "{query}"', {
                    'query': trimmed,
                  }),
            detail: raftText(
              context,
              continuation.tooBroad
                  ? searchTooBroadHint
                  : trimmed.isEmpty
                  ? 'Try a different filter set.'
                  : 'Try different keywords or a shorter phrase.',
            ),
          )
        else ...[
          if (remaining.isNotEmpty)
            RaftQuickSwitcherSection(
              heading:
                  '${raftText(context, 'Server entities')}   ${entities.length}',
              children: [
                for (final row in remaining) entityRow(row),
                if (entities.length > searchEntityPreviewCount)
                  SearchEntityToggle(
                    key: const Key('search-entity-show-all'),
                    count: entities.length,
                    expanded: entitiesExpanded,
                    onToggle: toggleEntities,
                  ),
              ],
            ),
          if (appSearch case final search?)
            SearchAppGroupSection(
              results: search,
              selectedKey: selectedRow?.key,
              onOpen: (card) => widget.onOpenArtifact?.call(card, query),
              wrapHit: (key, row) => KeyedSubtree(key: keyFor(key), child: row),
            ),
          // Source: the messages card always paints; its heading needs a
          // loading request or hits.
          RaftQuickSwitcherSection(
            heading: (loading && failure == null) || visible.isNotEmpty
                ? raftText(context, 'Messages')
                : null,
            children: [
              if (continuation.relevanceFallback &&
                  filters.searchSort != 'recent' &&
                  !loading &&
                  visible.isNotEmpty)
                const SearchRelevanceFallback(),
              if (loading &&
                  entities.isEmpty &&
                  messages.isEmpty &&
                  failure == null)
                const RaftQuickSwitcherSkeleton()
              else if (failure != null && total == 0)
                _failureCard(context)
              else
                ..._messageGroups(context, data, selectedRow),
            ],
          ),
        ],
      ],
    );
  }

  Widget _failureCard(BuildContext context) {
    final kind = failure!;
    final (title, body) = switch (kind) {
      QuickSwitcherFailure.queryTooBroad => (
        'Search is too broad',
        'Add a channel or sender filter, or switch the sort to Recent (a time range works with Recent).',
      ),
      QuickSwitcherFailure.searchTimeout => (
        'Search timed out',
        'Add a channel or sender filter, switch the sort to Recent (a time range works with Recent), or retry.',
      ),
      QuickSwitcherFailure.requestFailed => (
        'Search failed',
        'The last search request failed. Existing results are preserved when possible, but this query needs a retry.',
      ),
    };
    final broad = kind == QuickSwitcherFailure.queryTooBroad;
    return RaftQuickSwitcherErrorCard(
      title: raftText(context, title),
      body: raftText(context, body),
      actionLabel: !broad
          ? raftText(context, 'Retry')
          : filters.searchSort != 'recent'
          ? raftText(context, 'Sort by Newest')
          : null,
      onAction: !broad
          ? retry
          : filters.searchSort != 'recent'
          ? () {
              filters.searchSort = 'recent';
              filtersChanged();
            }
          : null,
    );
  }

  /// Source groupMessageSearchResults over the visible hits: a thread's hits
  /// share one card, placed where its first hit appears.
  List<Widget> _messageGroups(
    BuildContext context,
    QuickSwitcherData data,
    _Row? selectedRow,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    final order = <String>[];
    for (final row in visibleMessages) {
      final thread = row['threadId'], parent = row['parentMessageId'];
      final key = thread is String && thread.isNotEmpty && parent is String
          ? 'thread:$thread'
          : 'message:${row['id']}';
      if (!groups.containsKey(key)) order.add(key);
      (groups[key] ??= []).add(row);
    }
    Widget hit(
      Map<String, dynamic> row, {
      bool nested = false,
      bool first = false,
    }) {
      final key = 'message:${row['id']}';
      return KeyedSubtree(
        key: keyFor(key),
        child: _messageRow(
          context,
          row,
          data,
          selectedRow?.key == key,
          nested,
          first,
          () => openRow(_Row(key, message: row)),
        ),
      );
    }

    return [
      for (final key in order)
        if (!key.startsWith('thread:'))
          // ignore: raft_lints/avoid_render_index_assertion -- `order` and `groups` are built together from the same keys; each group holds at least one row.
          hit(groups[key]!.first)
        else
          // ignore: raft_lints/avoid_render_index_assertion -- `order` and `groups` are built together from the same keys.
          _threadGroup(context, data, groups[key]!, selectedRow, hit),
    ];
  }

  Widget _threadGroup(
    BuildContext context,
    QuickSwitcherData data,
    List<Map<String, dynamic>> hits,
    _Row? selectedRow,
    Widget Function(Map<String, dynamic>, {bool nested, bool first}) hit,
  ) {
    final first = hits.first;
    return RaftQuickSwitcherThreadGroup(
      badge: raftText(context, 'Thread'),
      where: _sourceLabel(first, data),
      hits: raftFormat(
        context,
        hits.length == 1 ? '{count} hit' : '{count} hits',
        {'count': hits.length},
      ),
      time: searchThreadTime(context, hits, widget.clock?.call()),
      title: searchThreadTitle(context, first['parentMessageContent']),
      selected: hits.any((r) => selectedRow?.key == 'message:${r['id']}'),
      children: [
        for (final (i, row) in hits.indexed)
          hit(row, nested: true, first: i == 0),
      ],
    );
  }

  String _sourceLabel(Map<String, dynamic> row, QuickSwitcherData data) =>
      searchSourceLabel(row, data.dms);

  Widget _leading(SearchEntity entity, QuickSwitcherData data) {
    if (entity.kind == 'channel') {
      return RaftQuickSwitcherIconBox(
        entity.row['type'] == 'private' ? RaftGlyph.lock : RaftGlyph.hash,
      );
    }
    if (entity.kind == 'computer') {
      return const RaftQuickSwitcherIconBox(RaftGlyph.monitor);
    }
    final agent = entity.kind == 'agent';
    final projection = projectSenderAvatar(
      origin: data.origin,
      senderId: entity.id,
      senderType: agent ? 'agent' : 'user',
      agents: data.agents,
      members: data.members,
      currentUser: data.currentUser,
    );
    return RaftAvatar(
      name: entity.title,
      kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
      mountedContext: RaftMountedAvatarContext.sidebarList,
      content: RaftAvatarContent(
        name: entity.title,
        kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
        uploadedUrl: projection.uploadedUrl,
        pixelKey: agent ? projection.pixelKey ?? 'robot' : null,
        fallback: RaftMountedAvatarFallback(
          avatarContext: RaftMountedAvatarContext.sidebarList,
          identity: agent
              ? RaftMountedAvatarIdentity.agent
              : RaftMountedAvatarIdentity.human,
          initials: entity.title,
        ),
      ),
    );
  }

  /// Source handleChannelResultContextMenu: right-clicking a live channel
  /// offers "Open" and keeps the row marked while the menu is up.
  Future<void> _channelMenu(
    BuildContext context,
    SearchEntity entity,
    Offset at,
  ) async {
    setState(() => contextMenuKey = entity.key);
    await showSearchChannelMenu(
      context,
      at: at,
      onOpen: () => widget.onOpenEntity(entity, query),
    );
    if (mounted) setState(() => contextMenuKey = null);
  }

  Widget _entityRow(
    BuildContext context,
    SearchEntity entity,
    QuickSwitcherData data,
    bool selected,
    bool hint,
    VoidCallback onPressed,
  ) {
    final kind = switch (entity.kind) {
      'channel' => 'Channel',
      'computer' => 'Computer',
      'agent' => 'Agent',
      _ => 'Human',
    };
    final row = RaftQuickSwitcherRow(
      key: ValueKey('quick-switcher-${entity.key}'),
      leading: _leading(entity, data),
      title: entity.title,
      subtitle: raftText(context, entity.subtitle),
      badges: [
        raftText(context, kind),
        if (entity.row['archivedAt'] != null)
          '${RaftQuickSwitcherRow.warningPrefix}${raftText(context, 'Archived')}',
      ],
      selected: selected || contextMenuKey == entity.key,
      returnHint: hint,
      onPressed: onPressed,
    );
    if (entity.kind != 'channel' || entity.row['archivedAt'] != null) {
      return row;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) =>
          _channelMenu(context, entity, details.globalPosition),
      child: row,
    );
  }

  Widget _messageRow(
    BuildContext context,
    Map<String, dynamic> row,
    QuickSwitcherData data,
    bool selected,
    bool nested,
    bool first,
    VoidCallback onPressed,
  ) {
    final thread = row['channelType'] == 'thread';
    final sender = '${row['senderName'] ?? ''}';
    final now = widget.clock?.call() ?? DateTime.now();
    final archived =
        (thread ? row['parentChannelArchivedAt'] : row['channelArchivedAt']) !=
        null;
    return RaftQuickSwitcherHit(
      key: ValueKey('quick-switcher-message:${row['id']}'),
      where: _sourceLabel(row, data),
      threadLabel: thread ? raftText(context, 'Thread').toLowerCase() : null,
      warnings: [
        if (archived) raftText(context, 'Archived'),
        if (searchBeyondHistory(row['createdAt'] as String?, data.plan, now))
          raftText(context, 'Upgrade to view'),
      ],
      avatar: sender.isEmpty
          ? null
          : searchHitSenderAvatar(
              row: row,
              sender: sender,
              origin: data.origin,
              agents: data.agents,
              members: data.members,
              currentUser: data.currentUser,
            ),
      sender: sender,
      time: DateTime.tryParse('${row['createdAt']}') == null
          ? raftText(context, 'unknown time')
          : resourceRelativeTime(
              row['createdAt'] as String?,
              now: widget.clock?.call(),
              chinese: Localizations.localeOf(context).languageCode == 'zh',
            ),
      snippet: SearchHighlight(
        text: '${row['snippet'] ?? row['content'] ?? ''}',
        query: query,
        style: RaftQuickSwitcherHit.snippetStyle(RaftTokens.of(context)),
      ),
      selected: selected,
      nested: nested,
      first: first,
      onPressed: onPressed,
    );
  }
}
