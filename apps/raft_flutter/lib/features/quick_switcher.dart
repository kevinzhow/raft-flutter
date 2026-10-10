import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import 'quick_switcher_model.dart';
import 'resource_cards.dart';
import 'resource_search.dart';
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
  });
  final QuickSwitcherCatalog catalog;

  /// Visited conversation ids, most recent first.
  final List<String> visited;
  final String? excludeChannelId;
  final List<Map<String, dynamic>> agents, members;
  final Map<String, dynamic>? currentUser;
  final String origin;
}

/// Cmd/Ctrl+K. Source: SearchOverlay.tsx and the overlay mode of
/// MessageSearchPage.tsx (Slack command palette): a fixed-size card floating
/// over the current page, the field as its header, recent conversations when
/// nothing is typed, otherwise the exact destination, the "Search for" row,
/// ranked destinations and a short message preview. Up/Down move the cursor,
/// Return opens it, Escape closes.
class QuickSwitcher extends StatefulWidget {
  const QuickSwitcher({
    super.key,
    required this.listenable,
    required this.data,
    required this.onClose,
    required this.onOpenEntity,
    required this.onOpenMessage,
    required this.onSearchAll,
    this.searchMessages,
    this.clock,
  });

  /// Notifies when the workspace behind [data] changes.
  final Listenable listenable;
  final QuickSwitcherData Function() data;
  final VoidCallback onClose;
  final void Function(SearchEntity entity, String query) onOpenEntity;
  final void Function(Map<String, dynamic> row, String query) onOpenMessage;
  final void Function(String query) onSearchAll;

  /// Message preview source; null hides the Messages section.
  final Future<List<Map<String, dynamic>>> Function(String query)?
  searchMessages;
  final DateTime Function()? clock;

  /// Source OVERLAY_MESSAGE_PREVIEW_LIMIT.
  static const messagePreviewLimit = 5;
  static const debounce = Duration(milliseconds: 200);

  /// Source searchOverlayCardStyle fallback placement and size.
  static Rect cardRect(Size viewport) =>
      RaftQuickSwitcherMetrics.cardRect(viewport);

  @override
  State<QuickSwitcher> createState() => _QuickSwitcherState();
}

class _Row {
  const _Row(this.key, {this.entity, this.message, this.all = false});
  final String key;
  final SearchEntity? entity;
  final Map<String, dynamic>? message;
  final bool all;
}

const _allKey = 'quick-switcher:all-results';

class _QuickSwitcherState extends State<QuickSwitcher> {
  final controller = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  final rowKeys = <String, GlobalKey>{};
  String query = '';
  String? selectedKey;
  String cursorEpoch = '';
  Timer? debounceTimer;
  int ticket = 0;
  List<Map<String, dynamic>> messages = const [];
  String messagesFor = '';
  bool searching = false;

  // Ranking is memoized per (catalog, query); a rebuild from an unrelated
  // workspace notification never re-ranks.
  QuickSwitcherCatalog? rankedCatalog;
  String rankedQuery = '';
  List<SearchEntity> ranked = const [];

  @override
  void initState() {
    super.initState();
    controller.addListener(textChanged);
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    ticket++;
    controller
      ..removeListener(textChanged)
      ..dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  bool get composing =>
      controller.value.composing.isValid &&
      !controller.value.composing.isCollapsed;

  void textChanged() {
    final next = controller.text.trim();
    if (next == query) return;
    setState(() {
      query = next;
      selectedKey = null;
    });
    debounceTimer?.cancel();
    ticket++;
    final search = widget.searchMessages;
    if (search == null || next.isEmpty) {
      setState(() {
        messages = const [];
        messagesFor = '';
        searching = false;
      });
      return;
    }
    setState(() => searching = true);
    final mine = ticket;
    debounceTimer = Timer(QuickSwitcher.debounce, () async {
      List<Map<String, dynamic>> found;
      try {
        found = await search(next);
      } catch (_) {
        found = const [];
      }
      if (!mounted || mine != ticket) return;
      setState(() {
        messages = found.take(QuickSwitcher.messagePreviewLimit).toList();
        messagesFor = next;
        searching = false;
      });
    });
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
    final modifier =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    // IME composition owns Return, Escape and the arrows.
    if (composing) return KeyEventResult.ignored;
    if (modifier && key == LogicalKeyboardKey.keyK) {
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
    final card = QuickSwitcher.cardRect(size);
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

  List<_Row> buildRows(QuickSwitcherData data, SearchEntity? exact) {
    if (query.isEmpty) {
      return [
        for (final entity in data.catalog.recent(
          visited: data.visited,
          excludeChannelId: data.excludeChannelId,
        ))
          _Row(entity.key, entity: entity),
      ];
    }
    final list = rank(data);
    return [
      if (exact != null) _Row(exact.key, entity: exact),
      const _Row(_allKey, all: true),
      for (final entity in list)
        if (entity.key != exact?.key) _Row(entity.key, entity: entity),
      if (messagesFor == query)
        for (final message in messages)
          if (message['id'] != null)
            _Row('message:${message['id']}', message: message),
    ];
  }

  Widget _card(BuildContext context) {
    final data = widget.data();
    final list = query.isEmpty ? const <SearchEntity>[] : rank(data);
    final exact = query.isEmpty ? null : findExactDestination(query, list);
    // The cursor returns to the top row whenever the query changes or an exact
    // destination surfaces from a later rerank (Source overlayCursorEpoch).
    final epoch = '$query\u0000${exact?.key ?? ''}';
    if (epoch != cursorEpoch) {
      cursorEpoch = epoch;
      selectedKey = null;
    }
    final rows = buildRows(data, exact);
    var selected = selectedKey == null
        ? 0
        : rows.indexWhere((r) => r.key == selectedKey);
    if (selected < 0) selected = 0;
    final selectedRow = rows.isEmpty ? null : rows[selected];
    return Focus(
      onKeyEvent: (_, event) => keyEvent(rows, selected, event),
      child: RaftQuickSwitcherFrame(
        semanticLabel: raftText(context, 'Search'),
        selectLabel: raftText(context, 'Select'),
        openLabel: raftText(context, 'Open'),
        field: RaftQuickSwitcherField(
          controller: controller,
          focusNode: focus,
          hint: raftText(context, 'Channels, people, messages…'),
          clearLabel: raftText(context, 'Clear search'),
          onClear: () {
            controller.clear();
            focus.requestFocus();
          },
        ),
        body: _body(context, data, rows, selectedRow, exact),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    QuickSwitcherData data,
    List<_Row> rows,
    _Row? selectedRow,
    SearchEntity? exact,
  ) {
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
    if (query.isEmpty) {
      if (rows.isEmpty) {
        return const RaftEmptyState(
          key: Key('quick-switcher-empty'),
          title: 'Search your workspace',
          detail: 'Enter words to find messages.',
          glyph: RaftGlyph.search,
        );
      }
      return RaftQuickSwitcherList(
        key: const Key('quick-switcher-recent'),
        controller: scroll,
        compact: true,
        children: [
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
    final messageRows = [
      for (final row in rows)
        if (row.message != null) row,
    ];
    final empty =
        remaining.isEmpty && exact == null && messageRows.isEmpty && !searching;
    final allRow = rows.firstWhere((r) => r.all);
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
                title: raftFormat(context, 'Search for “{query}”', {
                  'query': query,
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
        if (empty)
          RaftQuickSwitcherNoResults(
            key: const Key('quick-switcher-no-results'),
            title: raftFormat(context, 'No results for "{query}"', {
              'query': query,
            }),
            detail: raftText(
              context,
              'Try different keywords or a shorter phrase.',
            ),
          ),
        if (remaining.isNotEmpty)
          RaftQuickSwitcherSection(
            heading: raftText(context, 'Server entities'),
            children: [for (final row in remaining) entityRow(row)],
          ),
        if (messageRows.isNotEmpty || searching)
          RaftQuickSwitcherSection(
            heading: raftText(context, 'Messages'),
            children: [
              for (final row in messageRows)
                KeyedSubtree(
                  key: keyFor(row.key),
                  child: _messageRow(
                    context,
                    row.message!,
                    selectedRow?.key == row.key,
                    () => openRow(row),
                  ),
                ),
              if (searching && messageRows.isEmpty)
                RaftQuickSwitcherStatus(
                  raftText(context, 'Searching…'),
                  key: const Key('quick-switcher-searching'),
                ),
            ],
          ),
      ],
    );
  }

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
      requestSize: 32,
    );
    return RaftAvatar(
      name: entity.title,
      kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
      mountedContext: RaftMountedAvatarContext.sidebarList,
      content: RaftAvatarContent(
        name: entity.title,
        kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
        uploadedUrl: projection.uploadedUrl,
        gravatarUrl: projection.gravatarUrl,
        pixelKey: agent ? projection.pixelKey ?? 'robot' : null,
        fallback: RaftMountedAvatarFallback(
          avatarContext: RaftMountedAvatarContext.sidebarList,
          identity: agent
              ? RaftMountedAvatarIdentity.agent
              : RaftMountedAvatarIdentity.human,
          gravatar: projection.gravatarUrl != null,
          initials: entity.title,
        ),
      ),
    );
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
    return RaftQuickSwitcherRow(
      key: ValueKey('quick-switcher-${entity.key}'),
      leading: _leading(entity, data),
      title: entity.title,
      subtitle: raftText(context, entity.subtitle),
      badges: [
        raftText(context, kind),
        if (entity.row['archivedAt'] != null)
          '${RaftQuickSwitcherRow.warningPrefix}${raftText(context, 'Archived')}',
      ],
      selected: selected,
      returnHint: hint,
      onPressed: onPressed,
    );
  }

  Widget _messageRow(
    BuildContext context,
    Map<String, dynamic> row,
    bool selected,
    VoidCallback onPressed,
  ) {
    final thread = row['channelType'] == 'thread';
    final name = thread ? row['parentChannelName'] : row['channelName'];
    final dm = (thread ? row['parentChannelType'] : row['channelType']) == 'dm';
    return RaftQuickSwitcherMessageRow(
      key: ValueKey('quick-switcher-message:${row['id']}'),
      where: '${dm ? '@' : '#'}${name ?? ''}',
      thread: thread ? raftText(context, 'Thread').toLowerCase() : null,
      sender: '${row['senderName'] ?? ''}',
      time: resourceRelativeTime(
        row['createdAt'] as String?,
        now: widget.clock?.call(),
        chinese: Localizations.localeOf(context).languageCode == 'zh',
      ),
      snippet: SearchHighlight(
        text: '${row['snippet'] ?? row['content'] ?? ''}',
        query: query,
        style: raftQuickSwitcherSnippetStyle(RaftTokens.of(context)),
      ),
      selected: selected,
      onPressed: onPressed,
    );
  }
}
