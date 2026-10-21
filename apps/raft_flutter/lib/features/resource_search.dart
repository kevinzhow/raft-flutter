import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' as rui;

import 'quick_switcher.dart' show QuickSwitcherFailure;
import 'sender_avatar_projection.dart';
import 'resource_cards.dart';
import 'search_ranking.dart';

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
  if (created == null || plan != 'free') return false;
  final trialStart = DateTime.utc(2026, 4, 18),
      trialEnd = DateTime.utc(2026, 6, 23, 12);
  if (!now.isBefore(trialStart) && now.isBefore(trialEnd)) return false;
  return created.isBefore(now.subtract(const Duration(days: 30)));
}

/// Literal query highlighting follows SearchHighlight; brackets are ordinary
/// text and cannot alter a regular expression or expose another row.
class SearchHighlight extends StatelessWidget {
  const SearchHighlight({
    super.key,
    required this.text,
    required this.query,
    required this.style,
  });
  final String text, query;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final pattern = tokens.isEmpty
        ? null
        : RegExp(tokens.map(RegExp.escape).join('|'), caseSensitive: false);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in pattern?.allMatches(text) ?? const <RegExpMatch>[]) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            backgroundColor: RaftSearchRecipe(t, mobile: false).highlight,
            color: t.brutal ? t.strong : t.colors['primary-950'],
            fontWeight: t.brutal ? FontWeight.w700 : null,
          ),
        ),
      );
      start = match.end;
    }
    spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The 14px sender avatar of a message hit (Source `AvatarSlot
/// context="preview-mini"`), shared by the Search page and the quick switcher.
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
    requestSize: 14,
  );
  return RaftAvatar(
    name: sender,
    size: 14,
    mountedContext: RaftMountedAvatarContext.previewMini,
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
      gravatarUrl: projection.gravatarUrl,
      pixelKey: type == 'agent' ? projection.pixelKey ?? 'robot' : null,
      fallback: RaftMountedAvatarFallback(
        avatarContext: RaftMountedAvatarContext.previewMini,
        identity: type == 'agent'
            ? RaftMountedAvatarIdentity.agent
            : type == 'external_projection'
            ? RaftMountedAvatarIdentity.app
            : RaftMountedAvatarIdentity.human,
        gravatar: projection.gravatarUrl != null,
        initials: sender,
      ),
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
          chinese: Localizations.localeOf(context).languageCode == 'zh',
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
  final thread = row['channelType'] == 'thread';
  final dm = (thread ? row['parentChannelType'] : row['channelType']) == 'dm';
  final id = thread ? row['parentChannelId'] : row['channelId'];
  var name =
      '${(thread ? row['parentChannelName'] : row['channelName']) ?? ''}';
  if (dm) {
    final peer = dms.where((c) => c['id'] == id).firstOrNull;
    final label = peer?['peerDisplayName'] ?? peer?['peerName'];
    if (label is String && label.isNotEmpty) name = label;
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
    this.loading = false,
    this.failure,
    this.onRetry,
    this.onSortRecent,
    this.agents = const [],
    this.members = const [],
    this.dms = const [],
    this.currentUser,
  });
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
  final bool hasMore;
  final VoidCallback onMore;

  /// The first read is in flight: "Searching…" summary and a messages skeleton.
  final bool loading;

  /// The read failed and no result is on screen: the failure card replaces the
  /// empty state. [onSortRecent] is the "too broad" escape (null once sorted
  /// by recent).
  final QuickSwitcherFailure? failure;
  final VoidCallback? onRetry, onSortRecent;

  Widget _failureCard(BuildContext context) {
    final kind = failure!;
    final (title, body) = switch (kind) {
      QuickSwitcherFailure.queryTooBroad => (
        'Search is too broad',
        'Add a channel, sender, or time filter, or switch the sort to Recent.',
      ),
      QuickSwitcherFailure.searchTimeout => (
        'Search timed out',
        'Add a channel, sender, or time filter, switch the sort to Recent, or retry.',
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
        ? ('Sort by newest', onSortRecent)
        : (null, null);
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
    // raft-ui search recipe: SearchResultsSummary / SearchResultsSection /
    // SearchResultsSectionHeading / SearchResultsList (MessageSearchPage.tsx).
    final rt = rui.RaftRecipeTokens(t);
    final slots = rui.RaftSearchRecipe.resolve(
      theme: t.brutal
          ? rui.RaftRecipeTheme.brutal
          : rui.RaftRecipeTheme.elegant,
      states: rui.RaftRecipeStates({
        if (t.dark) rui.RaftRecipeStates.dark,
      }, MediaQuery.sizeOf(context).width),
      tokens: rt,
    );
    Widget slotText(String text, rui.RaftSlotStyle slot) {
      final base = slot.textStyle(rt);
      return Text(
        slot.textTransform == 'uppercase' ? text.toUpperCase() : text,
        style: base.copyWith(
          // Unset family/line-height inherit the page (font-sans, 1.5).
          fontFamily: base.fontFamily ?? t.bodyFont,
          height: base.height ?? RaftResourceMetrics.documentLineHeight,
        ),
      );
    }

    Widget section(String title, List<WidgetBuilder> children) {
      final decoration = slots.section.decoration(rt);
      return SliverPadding(
        padding: slots.section.margin,
        sliver: DecoratedSliver(
          decoration: decoration,
          sliver: SliverPadding(
            padding: slots.section.padding.add(decoration.padding),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: slots.sectionHeading.padding,
                    child: slotText(
                      raftText(context, title),
                      slots.sectionHeading,
                    ),
                  ),
                ),
                SliverList.separated(
                  itemCount: children.length,
                  itemBuilder: (context, index) => children[index](context),
                  separatorBuilder: (_, _) => SizedBox(
                    height: slots.list.rowGap ?? RaftResourceMetrics.gap2,
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
      return RaftSearchResultSurface(
        selected: selectedKey == key,
        entity: entity,
        onPressed: open,
        child: child,
      );
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
      return RaftQuickSwitcherHit(
        key: ValueKey('search-message:${row['id']}'),
        where: searchSourceLabel(row, dmRows),
        threadLabel: thread ? raftText(context, 'Thread').toLowerCase() : null,
        warnings: [
          if (archived) raftText(context, 'Archived'),
          if (searchBeyondHistory(row['createdAt'] as String?, plan, now))
            raftText(context, 'Upgrade to view'),
        ],
        uppercaseWarnings: {raftText(context, 'Archived')},
        avatar: sender.isEmpty ? null : _senderAvatar(row, sender),
        sender: sender,
        time: DateTime.tryParse('${row['createdAt']}') == null
            ? raftText(context, 'unknown time')
            : resourceRelativeTime(
                row['createdAt'] as String?,
                now: now,
                chinese: Localizations.localeOf(context).languageCode == 'zh',
              ),
        snippet: SearchHighlight(
          text: '${row['snippet'] ?? row['content'] ?? ''}',
          query: query,
          style: RaftQuickSwitcherHit.snippetStyle(t),
        ),
        selected: selectedKey == 'message:${row['id']}',
        nested: nested,
        first: first,
        onPressed: () => onMessage(row),
      );
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
      // SearchViewport padding plus the results `<div class="p-4">`.
      slivers: [
        SliverPadding(
          padding: raftScrollPadding(
            context,
            slots.viewport.padding.add(RaftResourceMetrics.searchResultsInset),
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              // `<div class="mb-3 px-1"><SearchResultsSummary>`; the summary's own
              // mb-3 collapses into the wrapper's.
              SliverToBoxAdapter(
                child: Padding(
                  padding: RaftResourceMetrics.searchSummaryInset,
                  child: Padding(
                    padding: slots.summary.padding.add(
                      EdgeInsets.only(bottom: slots.summary.margin.bottom),
                    ),
                    child: slotText(
                      loading
                          ? raftText(context, 'Searching…')
                          : searchResultCount(
                              context,
                              entities.length + rows.length,
                            ),
                      slots.summary,
                    ),
                  ),
                ),
              ),
              if (entities.isNotEmpty) ...[
                section('Server entities', [
                  for (final entity in entities)
                    (_) => surface(
                      entity.key,
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            // SearchEntityResultIcon (searchEntity entityIcon).
                            decoration: rui.RaftSearchEntityRecipe.resolve(
                              theme: t.brutal
                                  ? rui.RaftRecipeTheme.brutal
                                  : rui.RaftRecipeTheme.elegant,
                              tokens: rt,
                            ).entityIcon.decoration(rt),
                            child: RaftIcon(
                              entity.kind == 'channel'
                                  ? RaftGlyph.hash
                                  : entity.kind == 'computer'
                                  ? RaftGlyph.monitor
                                  : entity.kind == 'agent'
                                  ? RaftGlyph.bot
                                  : RaftGlyph.user,
                              size: 16,
                            ),
                          ),
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
                                    _entityBadge(context, entity.kind),
                                    if (entity.row['archivedAt'] != null) ...[
                                      const SizedBox(width: 4),
                                      _badge(context, 'Archived'),
                                    ],
                                  ],
                                ),
                                Text(
                                  raftText(context, entity.subtitle),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: recipe.metadata.copyWith(
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
                ]),
              ],
              // `showInitialSkeleton` needs no entity match; with one the
              // heading shows alone until the messages arrive.
              if (loading && failure == null && rows.isEmpty)
                section('Messages', [
                  if (entities.isEmpty)
                    (_) => const RaftQuickSwitcherSkeleton(),
                ])
              else if (failure != null && rows.isEmpty)
                SliverToBoxAdapter(child: _failureCard(context)),
              if (rows.isNotEmpty)
                section('Messages', [
                  for (final group in messageGroups)
                    (context) => messageGroup(context, group),
                ]),
              if (rows.isEmpty &&
                  entities.isEmpty &&
                  !loading &&
                  failure == null)
                // `py-20` centred glyph, title and hint (MessageSearchPage).
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 80),
                    child: RaftQuickSwitcherEmpty(
                      iconSize: 48,
                      title: query.trim().isEmpty
                          ? raftText(context, 'No matching messages')
                          : raftFormat(context, 'No results for "{query}"', {
                              'query': query.trim(),
                            }),
                      detail: query.trim().isEmpty
                          ? raftText(context, 'Try a different filter set.')
                          : raftText(
                              context,
                              'Try different keywords or a shorter phrase.',
                            ),
                    ),
                  ),
                ),
              if (hasMore)
                SliverToBoxAdapter(
                  child: RaftSearchLoadMore(onPressed: onMore),
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
      appearance: RaftBadgeRecipeAppearance.soft,
      variant: RaftBadgeRecipeVariant.muted,
      uppercase: true,
    );
  }

  Widget _badge(BuildContext context, String label) {
    final t = RaftTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.colors['warning-soft'],
        borderRadius: BorderRadius.circular(t.brutal ? 0 : 12),
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
