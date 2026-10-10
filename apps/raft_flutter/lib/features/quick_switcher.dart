import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' as rui;

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
  static Rect cardRect(Size viewport) {
    final width = math.min(720.0, viewport.width * .92);
    final natural = math.min(680.0, viewport.height * .8);
    final top = math.max(
      viewport.height * .08 + 16,
      (viewport.height - natural) / 2,
    );
    final height = math.max(0.0, math.min(natural, viewport.height - top - 24));
    return Rect.fromLTWH((viewport.width - width) / 2, top, width, height);
  }

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
    final t = RaftTokens.of(context);
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
    final line = t.colors['line-muted']!;
    final recipe = RaftSearchRecipe(t, mobile: false);
    return Focus(
      onKeyEvent: (_, event) => keyEvent(rows, selected, event),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        namesRoute: true,
        scopesRoute: true,
        label: raftText(context, 'Search'),
        child: RaftPopoverSurface(
          child: ColoredBox(
            color: t.popover,
            child: Column(
              key: const Key('quick-switcher'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, t, line),
                Expanded(
                  child: _body(
                    context,
                    t,
                    recipe,
                    data,
                    rows,
                    selectedRow,
                    exact,
                  ),
                ),
                _footer(context, t, recipe, line),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, RaftTokens t, Color line) =>
      DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: t.brutal ? t.strong : line,
              width: t.brutal ? 2 : 1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              RaftIcon(RaftGlyph.search, size: 16, color: t.muted),
              const SizedBox(width: 8),
              Expanded(
                child: RaftSearchInput(
                  key: const Key('quick-switcher-input'),
                  controller: controller,
                  focusNode: focus,
                  hint: raftText(context, 'Channels, people, messages…'),
                  clearLabel: raftText(context, 'Clear search'),
                  showEscape: true,
                  onClear: () {
                    controller.clear();
                    focus.requestFocus();
                  },
                ),
              ),
            ],
          ),
        ),
      );

  Widget _body(
    BuildContext context,
    RaftTokens t,
    RaftSearchRecipe recipe,
    QuickSwitcherData data,
    List<_Row> rows,
    _Row? selectedRow,
    SearchEntity? exact,
  ) {
    Widget heading(String label, RaftGlyph? glyph) => Padding(
      padding: RaftSearchHomeRecipe.headingInset,
      child: Row(
        children: [
          if (glyph != null) ...[
            RaftIcon(glyph, size: 12, color: t.muted),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(raftText(context, label), style: recipe.sectionTitle),
          ),
        ],
      ),
    );
    Widget entityRow(_Row row, {bool hint = false}) => KeyedSubtree(
      key: keyFor(row.key),
      child: _EntityRow(
        entity: row.entity!,
        data: data,
        selected: selectedRow?.key == row.key,
        returnHint: hint,
        onPressed: () => openRow(row),
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
      return ListView(
        key: const Key('quick-switcher-recent'),
        controller: scroll,
        primary: false,
        padding: const EdgeInsets.all(12),
        children: [
          heading('Recent conversations', RaftGlyph.clock3),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: entityRow(row, hint: true),
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
    return ListView(
      controller: scroll,
      primary: false,
      padding: const EdgeInsets.all(16),
      children: [
        // Overlay head: the exact destination, then "Search for".
        if (exact != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: entityRow(rows.first),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KeyedSubtree(
            key: keyFor(_allKey),
            child: _AllResultsRow(
              query: query,
              selected: selectedRow?.key == _allKey,
              onPressed: () => openRow(allRow),
            ),
          ),
        ),
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              key: const Key('quick-switcher-no-results'),
              children: [
                RaftIcon(RaftGlyph.search, size: 32, color: t.muted),
                const SizedBox(height: 12),
                Text(
                  raftFormat(context, 'No results for "{query}"', {
                    'query': query,
                  }),
                  textAlign: TextAlign.center,
                  style: recipe.entityTitle.copyWith(color: t.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  raftText(
                    context,
                    'Try different keywords or a shorter phrase.',
                  ),
                  textAlign: TextAlign.center,
                  style: recipe.metadata,
                ),
              ],
            ),
          ),
        if (remaining.isNotEmpty) ...[
          heading('Server entities', null),
          for (final row in remaining)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: entityRow(row),
            ),
          const SizedBox(height: 6),
        ],
        if (messageRows.isNotEmpty || searching) heading('Messages', null),
        for (final row in messageRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: KeyedSubtree(
              key: keyFor(row.key),
              child: _MessageRow(
                row: row.message!,
                query: query,
                selected: selectedRow?.key == row.key,
                now: widget.clock?.call(),
                onPressed: () => openRow(row),
              ),
            ),
          ),
        if (searching && messageRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              raftText(context, 'Searching…'),
              key: const Key('quick-switcher-searching'),
              style: recipe.metadata,
            ),
          ),
      ],
    );
  }

  Widget _footer(
    BuildContext context,
    RaftTokens t,
    RaftSearchRecipe recipe,
    Color line,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: t.brutal ? t.strong : line,
          width: t.brutal ? 2 : 1,
        ),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        key: const Key('quick-switcher-footer'),
        children: [
          const _Kbd('↑'),
          const SizedBox(width: 4),
          const _Kbd('↓'),
          const SizedBox(width: 4),
          Text(
            raftText(context, 'Select'),
            style: recipe.metadata.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 16),
          const _Kbd('↵'),
          const SizedBox(width: 4),
          Text(
            raftText(context, 'Open'),
            style: recipe.metadata.copyWith(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.glyph);
  final String glyph;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    return ExcludeSemantics(
      child: RaftRecipeBox(
        style: rui.RaftKbdRecipe.resolve(theme: t.recipeTheme, tokens: rt).root,
        tokens: rt,
        child: Text(
          glyph,
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: t.muted,
          ),
        ),
      ),
    );
  }
}

class _AllResultsRow extends StatelessWidget {
  const _AllResultsRow({
    required this.query,
    required this.selected,
    required this.onPressed,
  });
  final String query;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(t, mobile: false);
    return RaftSearchResultSurface(
      key: const Key('quick-switcher-all-results'),
      entity: true,
      selected: selected,
      onPressed: onPressed,
      child: Row(
        children: [
          _IconBox(glyph: RaftGlyph.search, tokens: t),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  raftFormat(context, 'Search for “{query}”', {'query': query}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.entityTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  raftText(
                    context,
                    'Open the full results page with filters and context preview',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.metadata.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _Kbd('↵'),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.glyph, required this.tokens});
  final RaftGlyph glyph;
  final RaftTokens tokens;
  @override
  Widget build(BuildContext context) {
    final t = tokens, rt = t.recipeTokens;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: rui.RaftSearchEntityRecipe.resolve(
        theme: t.recipeTheme,
        tokens: rt,
      ).entityIcon.decoration(rt),
      child: RaftIcon(glyph, size: 16),
    );
  }
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({
    required this.entity,
    required this.data,
    required this.selected,
    required this.returnHint,
    required this.onPressed,
  });
  final SearchEntity entity;
  final QuickSwitcherData data;
  final bool selected, returnHint;
  final VoidCallback onPressed;

  Widget leading(BuildContext context, RaftTokens t) {
    if (entity.kind == 'channel') {
      return _IconBox(
        glyph: entity.row['type'] == 'private'
            ? RaftGlyph.lock
            : RaftGlyph.hash,
        tokens: t,
      );
    }
    if (entity.kind == 'computer') {
      return _IconBox(glyph: RaftGlyph.monitor, tokens: t);
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
    return SizedBox(
      width: 32,
      height: 32,
      child: RaftAvatar(
        name: entity.title,
        kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
        mountedContext: RaftMountedAvatarContext.sidebarList,
        content: RaftAvatarContent(
          name: entity.title,
          kind: agent
              ? RaftAvatarContentKind.agent
              : RaftAvatarContentKind.human,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(t, mobile: false);
    final badge = switch (entity.kind) {
      'channel' => 'Channel',
      'computer' => 'Computer',
      'agent' => 'Agent',
      _ => 'Human',
    };
    final archived = entity.row['archivedAt'] != null;
    return RaftSearchResultSurface(
      key: ValueKey('quick-switcher-${entity.key}'),
      entity: true,
      selected: selected,
      onPressed: onPressed,
      child: Row(
        children: [
          leading(context, t),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: recipe.entityTitle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RaftBadge(
                      label: raftText(context, badge),
                      appearance: RaftBadgeRecipeAppearance.soft,
                      variant: RaftBadgeRecipeVariant.muted,
                      uppercase: true,
                    ),
                    if (archived) ...[
                      const SizedBox(width: 4),
                      RaftBadge(
                        label: raftText(context, 'Archived'),
                        appearance: RaftBadgeRecipeAppearance.soft,
                        variant: RaftBadgeRecipeVariant.warning,
                        uppercase: true,
                      ),
                    ],
                  ],
                ),
                Text(
                  raftText(context, entity.subtitle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.metadata.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          if (returnHint && selected) ...[
            const SizedBox(width: 8),
            const _Kbd('↵'),
          ],
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.row,
    required this.query,
    required this.selected,
    required this.onPressed,
    this.now,
  });
  final Map<String, dynamic> row;
  final String query;
  final bool selected;
  final DateTime? now;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(t, mobile: false);
    final thread = row['channelType'] == 'thread';
    final name = thread ? row['parentChannelName'] : row['channelName'];
    final dm = (thread ? row['parentChannelType'] : row['channelType']) == 'dm';
    final sender = '${row['senderName'] ?? ''}';
    final time = resourceRelativeTime(
      row['createdAt'] as String?,
      now: now,
      chinese: Localizations.localeOf(context).languageCode == 'zh',
    );
    return RaftSearchResultSurface(
      key: ValueKey('quick-switcher-message:${row['id']}'),
      selected: selected,
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${dm ? '@' : '#'}${name ?? ''}', style: recipe.metadata),
                if (thread)
                  Text(
                    raftText(context, 'Thread').toLowerCase(),
                    style: recipe.metadata,
                  ),
                if (sender.isNotEmpty) Text(sender, style: recipe.sender),
                if (time.isNotEmpty) Text(time, style: recipe.timestamp),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SearchHighlight(
              text: '${row['snippet'] ?? row['content'] ?? ''}',
              query: query,
              style: recipe.snippet,
            ),
          ),
        ],
      ),
    );
  }
}
