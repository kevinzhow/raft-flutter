import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../icu_message.dart';
import 'artifact_dashboard_data.dart';
import 'artifact_models.dart';
import 'artifact_text.dart';

class ArtifactDashboardRows extends StatelessWidget {
  const ArtifactDashboardRows({
    super.key,
    required this.rows,
    required this.compact,
    required this.preferences,
    required this.opened,
    required this.onOpen,
    required this.onColumnResize,
    required this.onColumnResizeEnd,
    this.footer,
  });

  final List<ArtifactDashboardRow> rows;
  final bool compact, opened;
  final ArtifactDashboardPreferences preferences;
  final ValueChanged<ArtifactCard> onOpen;
  final void Function(ArtifactDashboardColumn, double) onColumnResize;
  final VoidCallback onColumnResizeEnd;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final table = !compact && !preferences.grid;
    final tiles = !compact && preferences.grid;
    final scroll = CustomScrollView(
      key: ValueKey(
        tiles
            ? 'artifact-grid'
            : table
            ? 'artifact-table'
            : 'artifact-list',
      ),
      slivers: [
        if (table)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RaftSpace.x5 + RaftSpace.x4,
                vertical: RaftSpace.x2,
              ),
              child: tableCells([
                Text(raftText(context, 'Title')),
                heading(context, 'Author', ArtifactDashboardColumn.author),
                heading(
                  context,
                  opened ? 'Opened' : 'Updated',
                  ArtifactDashboardColumn.updated,
                ),
                heading(context, 'Comments', ArtifactDashboardColumn.comments),
                heading(
                  context,
                  'Who can see it',
                  ArtifactDashboardColumn.visibility,
                ),
              ]),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: RaftSpace.x5,
            vertical: RaftSpace.x2,
          ),
          sliver: tiles
              ? SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    crossAxisSpacing: RaftSpace.x3,
                    mainAxisSpacing: RaftSpace.x3,
                    childAspectRatio: 1.7,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, index) => tile(context, rows[index]),
                )
              : SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) =>
                      row(context, rows[index], table, index > 0),
                ),
        ),
        if (footer case final action?)
          SliverToBoxAdapter(child: Center(child: action)),
        SliverPadding(
          padding: raftScrollPadding(
            context,
            const EdgeInsets.only(bottom: RaftSpace.x3),
          ),
        ),
      ],
    );
    if (!table) return scroll;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ArtifactDashboardColumn.values
            .map(preferences.width)
            .reduce((left, right) => left + right);
        final minimum = columns + RaftSpace.x6 * 9;
        if (constraints.maxWidth >= minimum) return scroll;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minimum,
            height: constraints.maxHeight,
            child: scroll,
          ),
        );
      },
    );
  }

  Widget heading(
    BuildContext context,
    String text,
    ArtifactDashboardColumn column,
  ) {
    final label = text == 'Updated'
        ? raftTextZh(context, 'Updated', '更新时间')
        : raftText(context, text);
    return Row(
      children: [
        if (RaftInteraction.of(context).pointer)
          SizedBox(
            height: RaftMetrics.buttonMd,
            child: RaftPanelResizeHandle(
              label: raftFormat(context, 'Resize {column}', {'column': label}),
              value: preferences.width(column),
              min: ArtifactDashboardColumn.minWidth,
              max: ArtifactDashboardColumn.maxWidth,
              defaultValue: column.defaultWidth,
              reversed: true,
              seamLine: true,
              onChanged: (value) => onColumnResize(
                column,
                value.clamp(
                  ArtifactDashboardColumn.minWidth,
                  ArtifactDashboardColumn.maxWidth,
                ),
              ),
              onChangeEnd: onColumnResizeEnd,
            ),
          ),
        Expanded(child: Text(label)),
      ],
    );
  }

  Widget row(
    BuildContext context,
    ArtifactDashboardRow item,
    bool table,
    bool rule,
  ) {
    final card = item.card;
    final author = artifactActorName(context, card.author);
    final time = artifactRelativeTime(
      context,
      opened ? item.openedAt : card.updatedAt,
    );
    final audience = artifactScopeLabel(
      context,
      card.home,
      fromAnotherServer: card.fromAnotherServer,
    );
    final icon = RaftIcon(artifactKindGlyph(card.kind), size: 18);
    return RaftListRow(
      key: ValueKey('artifact-dashboard-open-${card.id}'),
      variant: RaftListRowVariant.plain,
      onPressed: () => onOpen(card),
      topRule: rule,
      children: [
        if (!table) RaftListRowIcon(artifactKindGlyph(card.kind)),
        Expanded(
          child: table
              ? tableCells([
                  Row(
                    children: [
                      icon,
                      const SizedBox(width: RaftSpace.x2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RaftListRowTitle(card.title),
                            ?newsBadge(context, item.news),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(author),
                  Text(time),
                  Text('${card.commentCount}'),
                  Text(audience),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RaftListRowTitle(card.title),
                    ?newsBadge(context, item.news),
                    Text(
                      [
                        author,
                        time,
                        audience,
                      ].where((part) => part.isNotEmpty).join(' · '),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget tableCells(List<Widget> cells) => Row(
    children: [
      for (final (index, cell) in cells.indexed)
        if (index == 0)
          Expanded(child: cell)
        else
          SizedBox(
            width: preferences.width(ArtifactDashboardColumn.values[index - 1]),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: RaftSpace.x2),
              child: cell,
            ),
          ),
    ],
  );

  Widget tile(BuildContext context, ArtifactDashboardRow item) {
    final card = item.card;
    return RaftCard.item(
      key: ValueKey('artifact-dashboard-open-${card.id}'),
      onTap: () => onOpen(card),
      padding: const EdgeInsets.all(RaftSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: RaftIcon(artifactKindGlyph(card.kind), size: 32),
            ),
          ),
          RaftListRowTitle(card.title),
          ?newsBadge(context, item.news),
          Flexible(child: Text(artifactActorName(context, card.author))),
        ],
      ),
    );
  }

  Widget? newsBadge(BuildContext context, ArtifactDashboardNews news) {
    final labels = [
      if (news.mentioned) raftText(context, 'Mentions you'),
      if (news.updated) raftText(context, 'Updated'),
      if (news.comments > 0)
        icuText(
          context,
          '{count, plural, one {# new comment} other {# new comments}}',
          {'count': news.comments},
        ),
    ];
    if (labels.isEmpty) return null;
    return RaftBadge(
      label: labels.join(' · '),
      variant: RaftBadgeRecipeVariant.accent,
      wrap: true,
    );
  }
}
