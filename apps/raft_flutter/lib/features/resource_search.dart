import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' as rui;

import '../data/workspace_controller.dart';
import 'activity_row_label.dart' show formatTaskConversationRef;
import 'artifacts/artifact_models.dart';
import 'quick_switcher.dart' show QuickSwitcherFailure;
import 'sender_avatar_projection.dart';
import 'resource_cards.dart';
import 'resource_filters.dart';
import 'search_app_results.dart';
import 'search_continuation.dart';
import 'search_continue_footer.dart';
import 'search_highlight.dart';
import 'search_ranking.dart';
import 'search_sections.dart';

export 'search_highlight.dart' show SearchHighlight;

enum SearchQueryDestination { currentPage, everywhere }

typedef SearchQueryCommit = void Function(
  String query, {
  SearchQueryDestination destination,
});

class SearchPageQuery extends TextEditingController {
  final _anchors = <String, GlobalKey>{};
  SearchAppResults? apps;
  String? selectedKey;
  int _selectedIndex = 0;

  void bindApps(WorkspaceController? workspace, VoidCallback onChange) {
    apps?.dispose();
    apps = workspace == null
        ? null
        : (SearchAppResults(workspace, this)..addListener(onChange));
  }

  Widget anchor(String key, Widget child) =>
      KeyedSubtree(key: _anchors.putIfAbsent(key, GlobalKey.new), child: child);

  void clearSelection() {
    selectedKey = null;
    _selectedIndex = 0;
    _anchors.clear();
  }

  String? activeKey(List<String> keys) {
    if (keys.isEmpty) return null;
    final index = keys.indexOf(selectedKey ?? '');
    _selectedIndex = index < 0
        ? _selectedIndex.clamp(0, keys.length - 1)
        : index;
    return selectedKey = keys[_selectedIndex];
  }

  void reveal(String key, List<String> keys, {required bool forwards}) {
    selectedKey = key;
    _anchors.removeWhere((id, _) => !keys.contains(id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _anchors[key]?.currentContext;
      if (anchor == null || !anchor.mounted || selectedKey != key) return;
      Scrollable.ensureVisible(
        anchor,
        alignmentPolicy: forwards
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  void dispose() {
    apps?.dispose();
    clearSelection();
    super.dispose();
  }
}

/// Source searchEntities identity: channel, durable computer, live agent, human.
class SearchEntity {
  const SearchEntity(this.kind, this.id, this.title, this.subtitle, this.row);
  final String kind, id, title, subtitle;
  final Map<String, dynamic> row;
  String get key => '$kind:$id';
}

List<SearchEntity> searchEntities(
  String query, {
  required List<Map<String, dynamic>> channels,
  required List<Map<String, dynamic>> computers,
  required List<Map<String, dynamic>> agents,
  required List<Map<String, dynamic>> people,
  String? principal,
  bool includeAll = false,
}) {
  if (query.trim().isEmpty && !includeAll) return [];
  return rankSearchEntities(
    query,
    searchEntityEntries(
      channels: channels,
      computers: computers,
      agents: agents,
      people: people,
      principal: principal,
    ),
  );
}

/// The searchable destination universe in source order (type, then title).
/// Callers that rank on every keystroke build it once and reuse it.
List<SearchRankEntry<SearchEntity>> searchEntityEntries({
  required List<Map<String, dynamic>> channels,
  required List<Map<String, dynamic>> computers,
  required List<Map<String, dynamic>> agents,
  required List<Map<String, dynamic>> people,
  String? principal,
}) {
  final entries = <SearchRankEntry<SearchEntity>>[];
  void add(
    String kind,
    Map<String, dynamic> row,
    List<({String text, int priority})> fields,
    String subtitle,
  ) {
    final id = row[kind == 'user' ? 'userId' : 'id'] ?? row['id'];
    if (id is! String) return;
    final display = '${row['displayName'] ?? ''}';
    final title = display.isEmpty ? '${row['name'] ?? ''}' : display;
    if (title.isEmpty) return;
    entries.add(
      SearchRankEntry(SearchEntity(kind, id, title, subtitle, row), fields),
    );
  }

  String value(Map<String, dynamic> row, String key) => '${row[key] ?? ''}';
  for (final row in channels.where((r) => r['type'] != 'thread')) {
    add('channel', row, [
      (text: value(row, 'name'), priority: 0),
      (text: value(row, 'description'), priority: 3),
    ], 'Channel');
  }
  for (final row in computers.where((r) => r['isComputer'] == true)) {
    add('computer', row, [
      (text: value(row, 'name'), priority: 0),
      (text: value(row, 'hostname'), priority: 1),
      (text: value(row, 'description'), priority: 3),
      (text: value(row, 'os'), priority: 4),
    ], value(row, 'hostname'));
  }
  for (final row in agents.where((r) => r['deletedAt'] == null)) {
    add(
      'agent',
      row,
      [
        (
          text: value(row, 'displayName').isEmpty
              ? value(row, 'name')
              : value(row, 'displayName'),
          priority: 0,
        ),
        (text: value(row, 'name'), priority: 1),
        (text: value(row, 'description'), priority: 3),
      ],
      value(row, 'displayName').isNotEmpty ? '@${value(row, 'name')}' : 'Agent',
    );
  }
  for (final row in people) {
    final self = row['userId'] == principal;
    add(
      'user',
      row,
      [
        (
          text: value(row, 'displayName').isEmpty
              ? value(row, 'name')
              : value(row, 'displayName'),
          priority: 0,
        ),
        (text: value(row, 'name'), priority: 1),
        (text: value(row, 'description'), priority: 3),
        if (self) ...[
          for (final alias in ['self', 'me', 'myself', 'self dm'])
            (text: alias, priority: 4),
        ],
      ],
      self
          ? 'Notes to yourself'
          : value(row, 'description').isNotEmpty
          ? value(row, 'description')
          : value(row, 'displayName').isNotEmpty
          ? value(row, 'name')
          : '',
    );
  }
  const order = {'channel': 0, 'computer': 1, 'agent': 2, 'user': 3};
  entries.sort((a, b) {
    final type = order[a.value.kind]!.compareTo(order[b.value.kind]!);
    if (type != 0) return type;
    final title = a.value.title.toLowerCase().compareTo(
      b.value.title.toLowerCase(),
    );
    return title != 0 ? title : a.value.key.compareTo(b.value.key);
  });
  return entries;
}

/// Source `filterSearchEntityEntriesForQuery` + ranking over [entries].
List<SearchEntity> rankSearchEntities(
  String query,
  List<SearchRankEntry<SearchEntity>> entries,
) {
  if (query.trim().isEmpty) return entries.map((e) => e.value).toList();
  final prefix = query.trim()[0];
  return rankSearchEntries(
    query,
    entries
        .where(
          (e) => prefix == '#'
              ? e.value.kind == 'channel'
              : prefix == '@'
              ? ['agent', 'user'].contains(e.value.kind)
              : true,
        )
        .toList(),
  );
}

/// Warning mirrors source effective free-plan limits. It never authorizes a hit;
/// the context endpoint continues to enforce history/membership admission.
bool searchBeyondHistory(String? createdAt, String plan, DateTime now) {
  final created = createdAt == null ? null : DateTime.tryParse(createdAt);
  final days = searchHistoryWindow(plan, now);
  return days != null &&
      created != null &&
      created.isBefore(now.subtract(Duration(days: days)));
}

/// The compact-row sender avatar shared by the Search page and quick switcher.
Widget searchHitSenderAvatar({
  required Map<String, dynamic> row,
  required String sender,
  required String origin,
  List<Map<String, dynamic>> agents = const [],
  List<Map<String, dynamic>> members = const [],
  Map<String, dynamic>? currentUser,
}) {
  final type = '${row['senderType'] ?? 'user'}';
  final projection = projectSenderAvatar(
    origin: origin,
    senderId: '${row['senderId']}',
    senderType: type,
    agents: agents,
    members: members,
    currentUser: currentUser,
    externalAuthor: type == 'external_projection'
        ? {...row, 'avatarUrl': row['senderAvatarUrl'] ?? row['avatarUrl']}
        : null,
    carriedAvatarUrl: row['senderAvatarUrl'] is String
        ? row['senderAvatarUrl'] as String
        : null,
  );
  return RaftAvatar(
    name: sender,
    mountedContext: RaftMountedAvatarContext.compactRow,
    kind: type == 'agent'
        ? RaftAvatarKind.agent
        : type == 'external_projection'
        ? RaftAvatarKind.app
        : RaftAvatarKind.human,
    content: RaftAvatarContent(
      name: sender,
      kind: type == 'agent'
          ? RaftAvatarContentKind.agent
          : type == 'external_projection'
          ? RaftAvatarContentKind.app
          : RaftAvatarContentKind.human,
      uploadedUrl: projection.uploadedUrl,
      pixelKey: projection.pixelKey,
      fallback: type == 'user'
          ? const Center(child: RaftIcon(RaftGlyph.user, size: 14))
          : null,
    ),
  );
}

/// Source `truncateThreadTitle` over the parent message: whitespace collapsed,
/// clipped to 80 characters, "Thread discussion" when empty.
String searchThreadTitle(BuildContext context, Object? parentContent) {
  final title = '${parentContent ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) return raftText(context, 'Thread discussion');
  return title.length > 80 ? '${title.substring(0, 77)}...' : title;
}

/// Relative time of a thread group's latest hit (Source `latestCreatedAt`).
String searchThreadTime(
  BuildContext context,
  List<Map<String, dynamic>> hits,
  DateTime? now,
) {
  DateTime? latest;
  for (final row in hits) {
    final time = DateTime.tryParse('${row['createdAt']}');
    if (time != null && (latest == null || time.isAfter(latest))) {
      latest = time;
    }
  }
  return latest == null
      ? raftText(context, 'unknown time')
      : resourceRelativeTime(
          latest.toIso8601String(),
          now: now,
          locale: Localizations.localeOf(context).toLanguageTag(),
        );
}

/// Web `search.resultsCount`: "1 result" / "# results"; Chinese has no plural.
String searchResultCount(BuildContext context, int count) =>
    count == 1 && Localizations.localeOf(context).languageCode != 'zh'
    ? '1 result'
    : '$count ${raftText(context, 'results')}';

/// Source getSourceLabel: `#channel` or `@peer`, a DM named by its peer's
/// display name (falling back to the raw channel name).
String searchSourceLabel(
  Map<String, dynamic> row,
  Iterable<Map<String, dynamic>> dms,
) {
  final task = row['channelType'] == 'task';
  final child = task || row['channelType'] == 'thread';
  final kind = child ? row['parentChannelType'] : row['channelType'];
  final dm = kind == 'dm';
  final id = child ? row['parentChannelId'] : row['channelId'];
  var name = '${(child ? row['parentChannelName'] : row['channelName']) ?? ''}';
  String? peerName;
  if (dm) {
    final peer = dms.where((c) => c['id'] == id).firstOrNull;
    final label = peer?['peerDisplayName'] ?? peer?['peerName'];
    if (label is String && label.isNotEmpty) peerName = name = label;
  }
  if (task) {
    final number = row['taskNumber'], title = row['taskTitle'];
    final ref = number is int
        ? formatTaskConversationRef(
            taskNumber: number,
            channelName: name,
            channelType: kind is String ? kind : null,
            dmPeerName: peerName,
          )
        : null;
    if (title is String && title.isNotEmpty) {
      return ref == null ? title : '$ref $title';
    }
    if (ref != null) return ref;
  }
  return '${dm ? '@' : '#'}$name';
}

/// Page composition of source SearchResultsSection/EntityResult/MessageResult.
/// Transport, keyboard selection and authority are owned by ResourceView.
class ResourceSearchResults extends StatelessWidget {
  const ResourceSearchResults({
    super.key,
    required this.query,
    required this.rows,
    required this.entities,
    required this.origin,
    required this.plan,
    required this.now,
    required this.selectedKey,
    required this.onMessage,
    required this.onEntity,
    required this.hasMore,
    required this.onMore,
    this.filters,
    this.view,
    this.loading = false,
    this.failure,
    this.onRetry,
    this.agents = const [],
    this.members = const [],
    this.dms = const [],
    this.currentUser,
    this.controller,
    this.appSearch,
    this.onArtifact,
    this.entitiesExpanded = false,
    this.onToggleEntities,
    this.onEntityMenu,
    this.historyNotice,
    this.wrapResult,
  });
  final ScrollController? controller;
  final String query, origin, plan;
  final List<Map<String, dynamic>> agents, members;
  final List<RaftChannel> dms;
  final Map<String, dynamic>? currentUser;
  final List<Map<String, dynamic>> rows;
  final List<SearchEntity> entities;
  final DateTime now;
  final String? selectedKey;
  final void Function(Map<String, dynamic>) onMessage;
  final void Function(SearchEntity) onEntity;
  final SearchAppResults? appSearch;
  final ValueChanged<ArtifactCard>? onArtifact;
  final bool entitiesExpanded;
  final VoidCallback? onToggleEntities;
  final void Function(SearchEntity, Offset)? onEntityMenu;
  final Widget? historyNotice;
  final Widget Function(String key, Widget child)? wrapResult;
  final bool hasMore;

  /// Reads the next page; completes when it is accepted or has failed.
  final FutureOr<void> Function() onMore;

  /// The page's request state and the view [rows] belong to: where an
  /// incomplete search stopped ("Continue searching") and the sort the "too
  /// broad" guidance can switch to.
  final ResourceFilters? filters;
  final String? view;

  /// The first read is in flight: "Searching…" summary and a messages skeleton.
  final bool loading;

  /// The read failed and no result is on screen: the failure card replaces the
  /// empty state; "too broad" offers the sort by recent (gone once sorted).
  final QuickSwitcherFailure? failure;
  final VoidCallback? onRetry;

  SearchContinuation get continuation =>
      filters?.searchContinuations.of(view) ?? SearchContinuation.none;

  /// The "too broad" escape: sort by recent and search again; null once the
  /// results are sorted that way.
  VoidCallback? get onSortRecent =>
      filters == null || filters!.searchSort == 'recent'
      ? null
      : () {
          filters!.searchSort = 'recent';
          onRetry?.call();
        };

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
    final action = !broad
        ? ('Retry', onRetry)
        : onSortRecent != null
        ? ('Sort by Newest', onSortRecent)
        : (null, null);
    final t = RaftTokens.of(context);
    // v1.21.23 MessageSearchPage: a warning AppBanner (`mx-4`, icon, title,
    // body and an outline sm button); the plain card shared with the quick
    // switcher is the `search.failure` alternative.
    if (t.option('search.failure', or: 'banner') == 'banner') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x4),
        child: RaftBanner(
          live: false,
          status: RaftBannerRecipeStatus.warning,
          glyph: RaftGlyph.triangleAlert,
          title: raftText(context, title),
          description: raftText(context, body),
          footer: action.$1 == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: RaftSpace.x2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RaftButton(
                      label: raftText(context, action.$1!),
                      uiVariant: RaftButtonVariant.outline,
                      uiSize: RaftButtonSize.sm,
                      onPressed: action.$2,
                    ),
                  ),
                ),
        ),
      );
    }
    return RaftQuickSwitcherErrorCard(
      title: raftText(context, title),
      body: raftText(context, body),
      actionLabel: action.$1 == null ? null : raftText(context, action.$1!),
      onAction: action.$2,
    );
  }

  Widget _senderAvatar(Map<String, dynamic> row, String sender) =>
      searchHitSenderAvatar(
        row: row,
        sender: sender,
        origin: origin,
        agents: agents,
        members: members,
        currentUser: currentUser,
      );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(
      t,
      mobile:
          MediaQuery.sizeOf(context).width <
          RaftLayoutMetrics.desktopBreakpoint,
    );
    final plain = t.option('listGroup.frame', or: 'framed') == 'plain';
    // raft-ui search recipe: SearchResultsSummary / SearchResultsSection /
    // SearchResultsSectionHeading / SearchResultsList (MessageSearchPage.tsx).
    final rt = rui.RaftRecipeTokens(t);
    final slots = rui.RaftSearchRecipe.resolve(
      states: rui.RaftRecipeStates({
        if (t.dark) rui.RaftRecipeStates.dark,
      }, MediaQuery.sizeOf(context).width),
      tokens: rt,
    );
    final highlight = SearchHighlight.pattern(query);
    Widget slotText(String text, rui.RaftSlotStyle slot) {
      final base = plain
          ? t.scale(
              RaftTypeScale.footnote,
              color: t.colors['foreground-hint'],
              weight: identical(slot, slots.sectionHeading)
                  ? FontWeight.w700
                  : FontWeight.w400,
            )
          : slot.textStyle(rt);
      return RaftCssText(
        text,
        style: base.copyWith(
          // Unset family/line-height inherit the page (font-sans, 1.5).
          fontFamily: base.fontFamily ?? t.bodyFont,
          height: base.height ?? RaftResourceMetrics.documentLineHeight,
        ),
      );
    }

    Widget section(String title, List<WidgetBuilder> children, {int? count}) {
      final decoration = plain
          ? const BoxDecoration()
          : slots.section.decoration(rt);
      return SliverPadding(
        padding: plain ? recipe.flatSectionListEndInset : slots.section.margin,
        sliver: DecoratedSliver(
          decoration: decoration,
          sliver: SliverPadding(
            padding: plain
                ? EdgeInsets.zero
                : slots.section.padding.add(decoration.padding),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: plain
                      ? recipe.flatSectionHeading(
                          raftText(context, title),
                          count,
                        )
                      : Padding(
                          padding: slots.sectionHeading.padding,
                          child: Row(
                            spacing: RaftSpace.x2,
                            children: [
                              Flexible(
                                child: slotText(
                                  raftText(context, title),
                                  slots.sectionHeading,
                                ),
                              ),
                              if (count != null)
                                RaftCssText(
                                  '$count',
                                  style: t.scale(
                                    RaftTypeScale.monoMeta,
                                    mono: true,
                                    color: t.ui.foregroundHint,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                SliverList.separated(
                  itemCount: children.length,
                  itemBuilder: (context, index) => children[index](context),
                  separatorBuilder: (_, _) => recipe.resultSeparator(
                    flat: plain,
                    framedGap: slots.list.rowGap ?? RaftResourceMetrics.gap2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget surface(
      String key,
      Widget child,
      VoidCallback open, {
      bool entity = false,
    }) {
      final row = RaftSearchResultSurface(
        pageLayout: true,
        selected: selectedKey == key,
        entity: entity,
        onPressed: open,
        child: child,
      );
      return wrapResult?.call(key, row) ?? row;
    }

    // Source groupMessageSearchResults: hits of one thread share a card, placed
    // where its first hit appears; every other hit is its own card.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final thread = row['threadId'], parent = row['parentMessageId'];
      final key =
          thread is String &&
              thread.isNotEmpty &&
              parent is String &&
              parent.isNotEmpty
          ? 'thread:$thread'
          : 'message:${row['id']}';
      (grouped[key] ??= []).add(row);
    }
    final messageGroups = grouped.values.toList(growable: false);
    final appStatus = appSearch?.status ?? SearchAppStatus.idle;
    final appCount = appSearch?.hits.length ?? 0;
    final dmRows = [for (final dm in dms) dm.json];
    Widget message(
      Map<String, dynamic> row, {
      bool nested = false,
      bool first = false,
    }) {
      final thread = row['channelType'] == 'thread';
      final sender = '${row['senderName'] ?? ''}';
      final archived =
          (thread
              ? row['parentChannelArchivedAt']
              : row['channelArchivedAt']) !=
          null;
      final key = 'message:${row['id']}';
      final hit = RaftQuickSwitcherHit(
        key: ValueKey('search-message:${row['id']}'),
        pageLayout: true,
        where: searchSourceLabel(row, dmRows),
        threadLabel: thread ? raftText(context, 'Thread').toLowerCase() : null,
        warnings: [
          if (archived) raftText(context, 'Archived'),
          if (searchBeyondHistory(row['createdAt'] as String?, plan, now))
            raftText(context, 'Upgrade to view'),
        ],
        avatar: sender.isEmpty ? null : _senderAvatar(row, sender),
        sender: sender,
        time: DateTime.tryParse('${row['createdAt']}') == null
            ? raftText(context, 'unknown time')
            : resourceRelativeTime(
                row['createdAt'] as String?,
                now: now,
                locale: Localizations.localeOf(context).toLanguageTag(),
              ),
        snippet: SearchHighlight(
          text: '${row['snippet'] ?? row['content'] ?? ''}',
          query: query,
          style: RaftQuickSwitcherHit.snippetStyle(
            t,
            selected: selectedKey == key,
          ),
        ),
        selected: selectedKey == key,
        nested: nested,
        first: first,
        onPressed: () => onMessage(row),
      );
      return wrapResult?.call(key, hit) ?? hit;
    }

    Widget messageGroup(BuildContext context, List<Map<String, dynamic>> hits) {
      final first = hits.first;
      if (!(first['threadId'] is String &&
          (first['threadId'] as String).isNotEmpty &&
          first['parentMessageId'] is String &&
          (first['parentMessageId'] as String).isNotEmpty)) {
        return message(first);
      }
      return RaftQuickSwitcherThreadGroup(
        badge: raftText(context, 'Thread'),
        where: searchSourceLabel(first, dmRows),
        hits: raftFormat(
          context,
          hits.length == 1 ? '{count} hit' : '{count} hits',
          {'count': hits.length},
        ),
        time: searchThreadTime(context, hits, now),
        title: searchThreadTitle(context, first['parentMessageContent']),
        selected: hits.any((r) => selectedKey == 'message:${r['id']}'),
        children: [
          for (final (i, row) in hits.indexed)
            message(row, nested: true, first: i == 0),
        ],
      );
    }

    return CustomScrollView(
      controller: controller,
      // SearchViewport padding plus the results `<div class="p-4">`.
      slivers: [
        SliverPadding(
          padding: raftScrollPadding(
            context,
            plain
                ? recipe.flatResultsInset
                : slots.viewport.padding.add(
                    RaftResourceMetrics.searchResultsInset,
                  ),
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              // `<div class="mb-3 px-1"><SearchResultsSummary>`; the summary's own
              // mb-3 collapses into the wrapper's.
              SliverToBoxAdapter(
                child: Padding(
                  padding: plain
                      ? EdgeInsets.zero
                      : RaftResourceMetrics.searchSummaryInset,
                  child: Padding(
                    padding: plain
                        ? recipe.flatSummaryInset
                        : slots.summary.padding.add(
                            EdgeInsets.only(
                              bottom: slots.summary.margin.bottom,
                            ),
                          ),
                    child: slotText(
                      loading
                          ? raftText(context, 'Searching…')
                          : searchResultCount(
                              context,
                              entities.length + appCount + rows.length,
                            ),
                      slots.summary,
                    ),
                  ),
                ),
              ),
              if (historyNotice case final notice?)
                SliverToBoxAdapter(child: notice),
              if (entities.isNotEmpty) ...[
                section('Server entities', count: entities.length, [
                  for (final entity in entities.take(
                    entitiesExpanded || onToggleEntities == null
                        ? entities.length
                        : searchEntityPreviewCount,
                  ))
                    (_) => GestureDetector(
                      onSecondaryTapDown:
                          entity.kind == 'channel' && onEntityMenu != null
                          ? (details) =>
                                onEntityMenu!(entity, details.globalPosition)
                          : null,
                      child: surface(
                        entity.key,
                        Row(
                          children: [
                            Container(
                              width: plain ? 27 : 32,
                              height: plain ? 27 : 32,
                              alignment: Alignment.center,
                              // SearchEntityResultIcon (searchEntity entityIcon).
                              decoration: plain
                                  ? recipe.flatEntityIconSurface
                                  : rui.RaftSearchEntityRecipe.resolve(
                                      tokens: rt,
                                    ).entityIcon.decoration(rt),
                              child: RaftIcon(
                                entity.kind == 'channel'
                                    ? searchChannelGlyph(entity.row)
                                    : entity.kind == 'computer'
                                    ? RaftGlyph.monitor
                                    : entity.kind == 'agent'
                                    ? RaftGlyph.bot
                                    : RaftGlyph.user,
                                size: plain ? 14 : 16,
                                color: plain ? t.ui.foregroundMuted : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: recipe.entityContentGap(flat: plain),
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: SearchHighlight(
                                          text: entity.title,
                                          query: query,
                                          maxLines: 1,
                                          style: plain
                                              ? recipe.flatEntityTitle
                                              : recipe.entityTitle.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _entityBadge(context, entity.kind),
                                      if (entity.row['archivedAt'] != null) ...[
                                        const SizedBox(width: 4),
                                        _badge(context, 'Archived'),
                                      ],
                                    ],
                                  ),
                                  if (plain &&
                                      entity.kind == 'channel' &&
                                      entity.row['description'] is String &&
                                      (highlight?.hasMatch(
                                            entity.row['description'] as String,
                                          ) ??
                                          false))
                                    SearchHighlight(
                                      text: entity.row['description'] as String,
                                      query: query,
                                      style: recipe.flatEntityDescription,
                                      maxLines: 1,
                                    )
                                  else
                                    RaftCssText(
                                      raftText(context, entity.subtitle),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: plain
                                          ? recipe.flatEntityDescription
                                          : recipe.metadata.copyWith(
                                              fontWeight: FontWeight.w400,
                                            ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        () => onEntity(entity),
                        entity: true,
                      ),
                    ),
                  if (onToggleEntities != null &&
                      entities.length > searchEntityPreviewCount)
                    (_) => SearchEntityToggle(
                      key: const Key('search-entity-show-all'),
                      count: entities.length,
                      expanded: entitiesExpanded,
                      onToggle: onToggleEntities!,
                    ),
                ]),
              ],
              if (appSearch case final search? when onArtifact != null)
                SliverToBoxAdapter(
                  child: SearchAppGroupSection(
                    results: search,
                    selectedKey: selectedKey,
                    onOpen: onArtifact!,
                    wrapHit: wrapResult,
                    now: now,
                    pageLayout: true,
                  ),
                ),
              // `showInitialSkeleton` needs no entity match; with one the
              // heading shows alone until the messages arrive. An incomplete
              // search with nothing found keeps its own empty state (and the
              // button) while the next page is read or fails.
              if (rows.isEmpty &&
                  entities.isEmpty &&
                  appCount == 0 &&
                  continuation.pending)
                SliverToBoxAdapter(
                  child: SearchIncompleteEmpty(
                    continuation: continuation,
                    onMore: onMore,
                    failure: failure != null,
                  ),
                )
              else if (loading && failure == null && rows.isEmpty)
                section('Messages', [
                  if (entities.isEmpty)
                    (_) => const RaftQuickSwitcherSkeleton(),
                ])
              else if (failure != null && rows.isEmpty)
                SliverToBoxAdapter(child: _failureCard(context)),
              if (rows.isNotEmpty)
                section('Messages', count: rows.length, [
                  if (continuation.relevanceFallback &&
                      filters?.searchSort != 'recent' &&
                      !loading)
                    (_) => const SearchRelevanceFallback(),
                  for (final group in messageGroups)
                    (context) => messageGroup(context, group),
                ]),
              if (rows.isEmpty &&
                  entities.isEmpty &&
                  appCount == 0 &&
                  (appStatus == SearchAppStatus.idle ||
                      appStatus == SearchAppStatus.ready) &&
                  !loading &&
                  failure == null &&
                  !continuation.pending)
                // `py-20` centred glyph, title and hint (MessageSearchPage).
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 80),
                    child: RaftQuickSwitcherEmpty(
                      iconSize: 48,
                      title: query.trim().isEmpty
                          ? raftText(context, 'No messages match your filters')
                          : raftFormat(context, 'No results for "{query}"', {
                              'query': query.trim(),
                            }),
                      detail: continuation.tooBroad
                          ? raftText(context, searchTooBroadHint)
                          : query.trim().isEmpty
                          ? raftText(context, 'Try a different filter set.')
                          : raftText(
                              context,
                              'Try different keywords or a shorter phrase.',
                            ),
                    ),
                  ),
                ),
              if ((hasMore || continuation.pending) &&
                  !(rows.isEmpty && entities.isEmpty && appCount == 0))
                SliverToBoxAdapter(
                  child: SearchContinueFooter(
                    continuation: continuation,
                    onMore: onMore,
                    failure: failure != null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entityBadge(BuildContext context, String kind) {
    final label = switch (kind) {
      'channel' => 'Channel',
      'computer' => 'Computer',
      'agent' => 'Agent',
      _ => 'Human',
    };
    return RaftBadge(
      label: raftText(context, label),
      appearance: RaftBadgeRecipeAppearance.outline,
      variant: RaftBadgeRecipeVariant.muted,
      fontFamily: RaftTokens.of(context).monoFont,
    );
  }

  Widget _badge(BuildContext context, String label) {
    final t = RaftTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.colors['warning-soft'],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        raftText(context, label),
        style: RaftTypography.body(
          t,
          size: 10,
          line: 14,
          weight: FontWeight.w700,
          color: t.colors['warning-strong'],
        ),
      ),
    );
  }
}
