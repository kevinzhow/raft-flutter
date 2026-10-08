import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'public_avatar_url.dart';
import 'resource_cards.dart';
import 'page_component_recipes.dart';
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
    final t = RaftTokens.of(context), needle = query.trim().toLowerCase();
    final spans = <InlineSpan>[];
    var start = 0;
    while (needle.isNotEmpty) {
      final index = text.toLowerCase().indexOf(needle, start);
      if (index < 0) break;
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + needle.length),
          style: TextStyle(
            backgroundColor: RaftSearchRecipe(t, mobile: false).highlight,
            color: t.brutal ? t.strong : t.colors['primary-950'],
            fontWeight: t.brutal ? FontWeight.w700 : null,
          ),
        ),
      );
      start = index + needle.length;
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
  });
  final String query, origin, plan;
  final List<Map<String, dynamic>> rows;
  final List<SearchEntity> entities;
  final DateTime now;
  final String? selectedKey;
  final void Function(Map<String, dynamic>) onMessage;
  final void Function(SearchEntity) onEntity;
  final bool hasMore;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(
      t,
      mobile:
          MediaQuery.sizeOf(context).width <
          RaftLayoutMetrics.desktopBreakpoint,
    );
    Widget section(String title, List<Widget> children) => Container(
      padding: recipe.sectionInset,
      decoration: BoxDecoration(
        color: recipe.sectionFill,
        borderRadius: BorderRadius.circular(recipe.sectionRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(raftText(context, title), style: recipe.sectionTitle),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
    Widget surface(
      String key,
      Widget child,
      VoidCallback open, {
      bool entity = false,
    }) => Padding(
      padding: EdgeInsets.only(bottom: recipe.gap),
      child: Material(
        color: t.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(recipe.cardRadius),
          side: selectedKey == key
              ? BorderSide(color: recipe.selectedLine, width: t.brutal ? 2 : 1)
              : recipe.border,
        ),
        child: InkWell(
          onTap: open,
          borderRadius: BorderRadius.circular(recipe.cardRadius),
          child: Padding(
            padding: entity ? recipe.entityInset : EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final parent = row['channelType'] == 'thread'
          ? row['parentMessageId']
          : null;
      final key = parent is String ? 'thread:$parent' : 'message:${row['id']}';
      (grouped[key] ??= []).add(row);
    }
    Widget message(Map<String, dynamic> row) {
      final thread = row['channelType'] == 'thread';
      final name = thread ? row['parentChannelName'] : row['channelName'];
      final dm =
          (thread ? row['parentChannelType'] : row['channelType']) == 'dm';
      final sender = '${row['senderName'] ?? ''}';
      return surface(
        'message:${row['id']}',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: recipe.messageHeaderInset,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${dm ? '@' : '#'}${name ?? ''}',
                    style: RaftTypography.body(
                      t,
                      size: 12,
                      line: 16,
                      color: t.muted,
                    ),
                  ),
                  if (thread)
                    Text(
                      raftText(context, 'Thread'),
                      style: RaftTypography.body(
                        t,
                        size: 12,
                        line: 16,
                        color: t.muted,
                      ),
                    ),
                  if ((thread
                          ? row['parentChannelArchivedAt']
                          : row['channelArchivedAt']) !=
                      null)
                    _badge(context, 'Archived'),
                  if (searchBeyondHistory(
                    row['createdAt'] as String?,
                    plan,
                    now,
                  ))
                    _badge(context, 'Upgrade to view'),
                  if (sender.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RaftAvatar(
                          name: sender,
                          size: 16,
                          kind: row['senderType'] == 'agent'
                              ? RaftAvatarKind.agent
                              : row['senderType'] == 'external_projection'
                              ? RaftAvatarKind.app
                              : RaftAvatarKind.human,
                          imageUrl: raftPublicAvatarUrl(
                            origin,
                            row['senderAvatarUrl'] as String?,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: recipe.sender,
                          ),
                        ),
                      ],
                    ),
                  Text(
                    resourceRelativeTime(
                      row['createdAt'] as String?,
                      now: now,
                      chinese:
                          Localizations.localeOf(context).languageCode == 'zh',
                    ),
                    style: RaftTypography.body(
                      t,
                      size: 12,
                      line: 16,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: recipe.messageBodyInset,
              child: SearchHighlight(
                text: '${row['snippet'] ?? row['content'] ?? ''}',
                query: query,
                style: recipe.snippet,
              ),
            ),
          ],
        ),
        () => onMessage(row),
      );
    }

    return ListView(
      padding: recipe.viewportInset,
      children: [
        Text(
          '${entities.length + rows.length} ${raftText(context, 'results')}',
          style: recipe.summary,
        ),
        const SizedBox(height: 12),
        if (entities.isNotEmpty) ...[
          section('Server entities', [
            for (final entity in entities)
              surface(
                entity.key,
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.colors['fill-muted'],
                        borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
                      ),
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
          const SizedBox(height: 12),
        ],
        if (rows.isNotEmpty)
          section('Messages', [
            for (final group in grouped.values)
              if (group.length < 2)
                message(group.first)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: SearchHighlight(
                        text: '${group.first['parentMessageContent'] ?? ''}',
                        query: query,
                        style: RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ...group.map(message),
                  ],
                ),
          ]),
        if (rows.isEmpty && entities.isEmpty)
          RaftEmptyState(
            title: query.isEmpty ? 'Search your workspace' : 'No results',
            detail: query.isEmpty
                ? 'Enter words to find messages.'
                : 'Try different keywords or filters.',
            icon: Icons.search,
          ),
        if (hasMore) RaftTextButton(label: 'Load more', onPressed: onMore),
      ],
    );
  }

  Widget _entityBadge(BuildContext context, String kind) {
    final t = RaftTokens.of(context);
    final label = switch (kind) {
      'channel' => 'Channel',
      'computer' => 'Computer',
      'agent' => 'Agent',
      _ => 'Human',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.colors['fill-muted'],
        borderRadius: BorderRadius.circular(t.brutal ? 0 : 99),
      ),
      child: Text(
        raftText(context, label),
        style: RaftTypography.body(
          t,
          size: 10,
          line: 14,
          weight: FontWeight.w700,
          color: t.muted,
        ),
      ),
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
