import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' as rui;

import '../data/search_memory.dart';
import 'public_avatar_url.dart';
import 'resource_search.dart';

String searchUsageEntityKey(SearchEntity entity) =>
    '${entity.kind == 'user' ? 'human' : entity.kind}:${entity.id}';

/// Resolves stored identifiers ONLY through the currently authorized catalog.
/// Hidden DMs, archives, computers and the principal's self-DM are excluded.
List<SearchEntity> frequentSearchEntities({
  required List<SearchEntity> catalog,
  required Map<String, List<int>> usage,
  required String? principal,
  required DateTime now,
  Set<String> hiddenDmIds = const {},
  List<Map<String, dynamic>> dms = const [],
}) {
  bool hidden(SearchEntity entity) => dms.any(
    (dm) =>
        hiddenDmIds.contains(dm['id']) &&
        dm['peerId'] == entity.id &&
        dm['peerType'] == (entity.kind == 'user' ? 'user' : 'agent'),
  );
  final eligible = catalog.where(
    (e) =>
        e.kind != 'computer' &&
        e.row['archivedAt'] == null &&
        e.row['archived'] != true &&
        !(e.kind == 'user' && e.id == principal) &&
        !hidden(e),
  );
  final ranked = eligible
      .map(
        (e) => (
          entity: e,
          times: usage[searchUsageEntityKey(e)] ?? const <int>[],
          score: searchUsageScore(
            usage[searchUsageEntityKey(e)] ?? const [],
            now,
          ),
        ),
      )
      .where((r) => r.score > 0)
      .toList();
  ranked.sort((a, b) {
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    final date = (b.times.isEmpty ? 0 : b.times.first).compareTo(
      a.times.isEmpty ? 0 : a.times.first,
    );
    if (date != 0) return date;
    final title = a.entity.title.toLowerCase().compareTo(
      b.entity.title.toLowerCase(),
    );
    return title != 0 ? title : a.entity.key.compareTo(b.entity.key);
  });
  return ranked.take(10).map((r) => r.entity).toList();
}

/// Source Search home. The page owns history edit state and all scoped actions.
class ResourceSearchHome extends StatefulWidget {
  const ResourceSearchHome({
    super.key,
    required this.history,
    required this.frequent,
    required this.origin,
    required this.onQuery,
    required this.onRemove,
    required this.onClear,
    required this.onEntity,
  });
  final List<String> history;
  final List<SearchEntity> frequent;
  final String origin;
  final ValueChanged<String> onQuery, onRemove;
  final VoidCallback onClear;
  final ValueChanged<SearchEntity> onEntity;
  @override
  State<ResourceSearchHome> createState() => _ResourceSearchHomeState();
}

class _ResourceSearchHomeState extends State<ResourceSearchHome> {
  bool editing = false;
  @override
  void didUpdateWidget(ResourceSearchHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history.isEmpty) editing = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context),
        recipe = RaftSearchRecipe(
          t,
          mobile:
              MediaQuery.sizeOf(context).width <
              RaftLayoutMetrics.desktopBreakpoint,
        );
    final homeRecipe = RaftSearchHomeRecipe(t);
    final searchViewport = rui.RaftSearchRecipe.resolve(
      theme: t.brutal
          ? rui.RaftRecipeTheme.brutal
          : rui.RaftRecipeTheme.elegant,
      states: rui.RaftRecipeStates({
        if (t.dark) rui.RaftRecipeStates.dark,
      }, MediaQuery.sizeOf(context).width),
      tokens: rui.RaftRecipeTokens(t),
    ).viewport;
    final touch =
        MediaQuery.sizeOf(context).width <
        RaftSearchHomeRecipe.touchHistoryBreakpoint;
    if (widget.history.isEmpty && widget.frequent.isEmpty) {
      // Web `centeredEmptyState`: search.emptyTitle / search.emptyBody.
      return RaftQuickSwitcherEmpty(
        iconSize: 48,
        title: raftText(context, 'Search everything'),
        detail: raftText(
          context,
          'Search channels, DMs, people, agents, and message history.',
        ),
      );
    }
    Widget heading(
      String label,
      RaftGlyph glyph, {
      List<Widget> actions = const [],
    }) => RaftSearchHomeHeading(label: label, glyph: glyph, actions: actions);
    return ListView(
      key: const PageStorageKey('search-home'),
      primary: false,
      // SearchShellViewport padding plus the home `<div class="p-4">`.
      padding: raftScrollPadding(
        context,
        searchViewport.padding.add(RaftSearchHomeRecipe.inset),
      ),
      children: [
        if (widget.history.isNotEmpty) ...[
          heading(
            'Search History',
            RaftGlyph.clock3,
            actions: [
              if (touch)
                RaftSearchHomeAction(
                  label: editing ? 'Done' : 'Edit',
                  onPressed: () => setState(() => editing = !editing),
                ),
              RaftSearchHomeAction(label: 'Clear', onPressed: widget.onClear),
            ],
          ),
          Wrap(
            spacing: RaftSearchHomeRecipe.tagGap,
            runSpacing: RaftSearchHomeRecipe.tagGap,
            children: [
              for (final query in widget.history)
                RaftSearchHistoryTag(
                  key: ValueKey('search-history-$query'),
                  query: query,
                  touch: touch,
                  editing: editing,
                  onPressed: () => widget.onQuery(query),
                  onRemove: () => widget.onRemove(query),
                ),
            ],
          ),
          const SizedBox(height: RaftSearchHomeRecipe.sectionGap),
        ],
        heading('Frequently Used', RaftGlyph.star),
        if (widget.frequent.isEmpty)
          CustomPaint(
            foregroundPainter: RaftDashedBorderPainter(
              homeRecipe.tagBorder,
              t.brutal ? 2 : 1,
            ),
            child: Container(
              width: double.infinity,
              // `px-3 py-4` inside the border box.
              padding: EdgeInsets.symmetric(
                horizontal: 12.0 + (t.brutal ? 2 : 1),
                vertical: 16.0 + (t.brutal ? 2 : 1),
              ),
              child: Text(
                raftText(
                  context,
                  'Channels and contacts you open from Search will appear here.',
                ),
                style: recipe.metadata,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  MediaQuery.sizeOf(context).width >=
                      RaftSearchHomeRecipe.desktopColumnsBreakpoint
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth -
                      (columns - 1) * RaftSearchHomeRecipe.tagGap) /
                  columns;
              return Wrap(
                spacing: RaftSearchHomeRecipe.tagGap,
                runSpacing: RaftSearchHomeRecipe.tagGap,
                children: [
                  for (final entity in widget.frequent)
                    SizedBox(
                      width: width,
                      child: RaftControl(
                        key: ValueKey('search-frequent-${entity.key}'),
                        semanticLabel: 'Open ${entity.title}',
                        shadow: false,
                        visualHeight: 64,
                        onPressed: () => widget.onEntity(entity),
                        child: Row(
                          children: [
                            if (entity.kind == 'channel')
                              RaftIcon(RaftGlyph.hash, size: 14)
                            else
                              RaftAvatar(
                                name: entity.title,
                                size: 32,
                                kind: entity.kind == 'agent'
                                    ? RaftAvatarKind.agent
                                    : RaftAvatarKind.human,
                                imageUrl: raftPublicAvatarUrl(
                                  widget.origin,
                                  entity.row['avatarUrl'] as String?,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entity.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: recipe.entityTitle,
                                  ),
                                  Text(
                                    raftText(context, entity.subtitle),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: recipe.metadata,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
