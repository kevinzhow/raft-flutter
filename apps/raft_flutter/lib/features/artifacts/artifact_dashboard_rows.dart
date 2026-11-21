import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' show RaftTableRecipe;

import '../icu_message.dart';
import 'artifact_dashboard_data.dart';
import 'artifact_models.dart';
import 'artifact_text.dart';
import 'artifact_scope_chip.dart';

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
    this.readerId,
    this.clock,
    this.serverName,
    this.readCover,
  });

  final List<ArtifactDashboardRow> rows;
  final bool compact, opened;
  final ArtifactDashboardPreferences preferences;
  final ValueChanged<ArtifactCard> onOpen;
  final void Function(ArtifactDashboardColumn, double) onColumnResize;
  final VoidCallback onColumnResizeEnd;
  final Widget? footer;
  final String? readerId;
  final DateTime Function()? clock;
  final String? serverName;
  final Future<Uint8List> Function(ArtifactCard)? readCover;

  @override
  Widget build(BuildContext context) {
    final table = !compact && !preferences.grid;
    final tiles = preferences.grid;
    const margin = RaftArtifactCollectionLayout.columnMargin;
    final insets = table
        ? const EdgeInsets.only(
            left: margin,
            right: margin,
            bottom: RaftSpace.x2,
          )
        : tiles
        ? const EdgeInsets.symmetric(horizontal: margin, vertical: RaftSpace.x2)
        : const EdgeInsets.symmetric(vertical: RaftSpace.x2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = compact ? RaftSpace.x2 : RaftSpace.x3;
        final contentWidth = width - insets.horizontal;
        final columns = compact
            ? 2
            : ((contentWidth + gap) /
                      (RaftArtifactCollectionLayout.tileMinWidth + gap))
                  .floor()
                  .clamp(1, 100);
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
                  padding: const EdgeInsets.symmetric(horizontal: margin),
                  child: tableHeader(context),
                ),
              ),
            SliverPadding(
              padding: insets,
              sliver: tiles
                  ? SliverList.builder(
                      itemCount: (rows.length + columns - 1) ~/ columns,
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.only(bottom: gap),
                        child: IntrinsicHeight(
                          child: Row(
                            spacing: gap,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var column = 0; column < columns; column++)
                                Expanded(
                                  child: index * columns + column < rows.length
                                      ? tile(
                                          context,
                                          rows[index * columns + column],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : table
                  ? SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) => tableRow(
                        context,
                        rows[index],
                        last: index == rows.length - 1,
                      ),
                    )
                  : SliverList.separated(
                      itemCount: rows.length,
                      itemBuilder: (context, index) =>
                          phoneRow(context, rows[index]),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: RaftSpace.half),
                    ),
            ),
            if (footer case final action?)
              SliverToBoxAdapter(child: Center(child: action)),
            SliverPadding(
              padding: raftScrollPadding(
                context,
                const EdgeInsets.only(bottom: RaftSpace.x6),
              ),
            ),
          ],
        );
        if (!table) return scroll;
        final minimum =
            preferences.width(ArtifactDashboardColumn.author) +
            preferences.width(ArtifactDashboardColumn.updated) +
            preferences.width(ArtifactDashboardColumn.comments) +
            preferences.width(ArtifactDashboardColumn.visibility) +
            RaftArtifactCollectionLayout.tableTitleMinWidth +
            insets.horizontal;
        return constraints.maxWidth >= minimum
            ? scroll
            : SingleChildScrollView(
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

  Widget tableHeader(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftTableRecipe.resolve(
      states: t.recipeStates(responsive: true),
      tokens: t.recipeTokens,
    ).head;
    final labels = [
      'Title',
      'Author',
      opened ? 'Opened' : 'Updated',
      'Comments',
      'Who can see it',
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.ui.lineHairline)),
      ),
      child: DefaultTextStyle(
        style: style.text(
          t.recipeTokens,
          base: t.scale(RaftTypeScale.footnote),
        ),
        child: tableCells([
          for (final (index, label) in labels.indexed)
            if (index == 0)
              Padding(
                padding: style.padding,
                child: Text(raftText(context, label)),
              )
            else
              heading(
                context,
                label,
                ArtifactDashboardColumn.values[index - 1],
                style.padding,
              ),
        ]),
      ),
    );
  }

  Widget heading(
    BuildContext context,
    String text,
    ArtifactDashboardColumn column,
    EdgeInsets padding,
  ) {
    final label = text == 'Updated'
        ? raftTextZh(context, 'Updated', '更新时间')
        : raftText(context, text);
    return Stack(
      children: [
        Padding(
          padding: padding,
          child: Align(
            alignment: column == ArtifactDashboardColumn.comments
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (RaftInteraction.of(context).pointer)
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: RaftPanelResizeHandle(
              label: raftFormat(context, 'Resize {column}', {'column': label}),
              value: preferences.width(column),
              min: ArtifactDashboardColumn.minWidth,
              max: ArtifactDashboardColumn.maxWidth,
              defaultValue: column.defaultWidth,
              reversed: true,
              seamLine: true,
              onChanged: (value) => onColumnResize(column, value),
              onChangeEnd: onColumnResizeEnd,
            ),
          ),
      ],
    );
  }

  Widget tableRow(
    BuildContext context,
    ArtifactDashboardRow item, {
    required bool last,
  }) {
    final card = item.card;
    final t = RaftTokens.of(context);
    final cell = RaftTableRecipe.resolve(
      states: t.recipeStates(responsive: true),
      tokens: t.recipeTokens,
    ).cell;
    final cellPadding = cell.padding;
    final seam = cell.borderWidth.bottom;
    final halfSeam = seam / 2;
    return RaftInteractive(
      key: ValueKey('artifact-dashboard-open-${card.id}'),
      semanticLabel: artifactShownTitle(card.title),
      onPressed: () => onOpen(card),
      builder: (context, state) => DecoratedBox(
        decoration: BoxDecoration(color: state.hovered ? t.ui.fillMuted : null),
        child: Stack(
          children: [
            Padding(
              // The table's collapsed cell borders contribute half a seam to
              // each row, including the row whose last border is hidden.
              padding: EdgeInsets.only(bottom: halfSeam),
              child: tableCells([
                Padding(
                  padding: cellPadding,
                  child: Row(
                    spacing: RaftSpace.x2,
                    children: [
                      RaftIcon(
                        artifactKindGlyph(card.kind),
                        color: t.ui.foregroundMuted,
                        size: 16,
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: RaftSpace.x2,
                          runSpacing: RaftSpace.x1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              artifactShownTitle(card.title),
                              style: t.scale(
                                RaftTypeScale.callout,
                                weight: FontWeight.w700,
                              ),
                            ),
                            ?newsBadge(context, item.news),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(padding: cellPadding, child: author(context, card)),
                Padding(
                  padding: cellPadding,
                  child: mono(
                    context,
                    artifactRelativeTime(
                      context,
                      item.openedAt ?? card.updatedAt,
                      now: clock?.call(),
                    ),
                  ),
                ),
                Padding(
                  padding: cellPadding,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: RaftSpace.x1,
                      children: [
                        if (card.commentCount > 0)
                          const RaftIcon(RaftGlyph.messageSquare, size: 14),
                        mono(context, '${card.commentCount}'),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: cellPadding,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ArtifactScopeChip(
                      card: card,
                      serverName: serverName,
                    ),
                  ),
                ),
              ]),
            ),
            if (!last)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RaftCssTopBorder(
                  color: t.ui.lineHairline,
                  width: seam,
                  child: SizedBox(height: seam),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget phoneRow(BuildContext context, ArtifactDashboardRow item) {
    final card = item.card;
    final title = artifactShownTitle(card.title);
    final scope = artifactScopeLabel(
      context,
      card.home,
      fromAnotherServer: card.fromAnotherServer,
      serverName: serverName,
    );
    final subtitle = [
      if (card.home.kind == 'conversation' &&
          card.home.conversationType != 'dm')
        '#$scope'
      else
        scope,
      'v${card.version}',
      if (card.commentCount > 0)
        icuText(
          context,
          '{count, plural, one {# comment} other {# comments}}',
          {'count': card.commentCount},
        ),
    ].join(' · ');
    return RaftInboxItem(
      key: ValueKey('artifact-dashboard-open-${card.id}'),
      semanticLabel: '$title, $subtitle',
      leading: RaftIconTile(glyph: artifactKindGlyph(card.kind)),
      title: Text(title),
      subtitle: Text.rich(
        TextSpan(
          children: [
            if (card.home.kind == 'public')
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: RaftSpace.x1),
                  child: RaftIcon(RaftGlyph.globe, size: 12),
                ),
              ),
            TextSpan(text: subtitle),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      metadata: Row(
        spacing: RaftSpace.x1_5,
        children: [
          Flexible(child: author(context, card)),
          ?newsBadge(context, item.news),
        ],
      ),
      timestampAtRest: true,
      timestampTrailing: true,
      timestamp: Text(
        artifactShortTime(
          context,
          item.openedAt ?? card.updatedAt,
          now: clock?.call(),
        ),
      ),
      onOpen: () => onOpen(card),
    );
  }

  Widget tableCells(List<Widget> cells) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, cell) in cells.indexed)
        if (index == 0)
          Expanded(child: cell)
        else
          SizedBox(
            width: preferences.width(ArtifactDashboardColumn.values[index - 1]),
            child: cell,
          ),
    ],
  );

  Widget tile(BuildContext context, ArtifactDashboardRow item) {
    final t = RaftTokens.of(context);
    final embed = raftMessageEmbedSlots(context);
    final card = item.card;
    final time = compact
        ? artifactShortTime(
            context,
            item.openedAt ?? card.updatedAt,
            now: clock?.call(),
          )
        : raftFormat(
            context,
            item.openedAt == null ? 'Updated {time}' : 'Opened {time}',
            {
              'time': artifactRelativeTime(
                context,
                item.openedAt ?? card.updatedAt,
                now: clock?.call(),
              ),
            },
          );
    final scope = ArtifactScopeChip(
      card: card,
      iconOnly: true,
      serverName: serverName,
    );
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: RaftSpace.x1,
      children: [
        if (card.commentCount > 0) ...[
          const RaftIcon(RaftGlyph.messageSquare, size: 12),
          mono(context, '${card.commentCount}'),
        ],
        scope,
      ],
    );
    return RaftMessageEmbedFrame(
      key: ValueKey('artifact-dashboard-open-${card.id}'),
      onPressed: () => onOpen(card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: _ArtifactTileCover(
              key: ValueKey((
                card.id,
                card.version,
                card.preview.path,
                compact,
                card.preview.screenshot(compact),
              )),
              compact: compact,
              card: card,
              read: readCover,
            ),
          ),
          Padding(
            padding: embed.header.padding,
            child: Column(
              spacing: RaftSpace.x1 + RaftSpace.half,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: RaftSpace.x1 + RaftSpace.half,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        artifactShownTitle(card.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.scale(
                          RaftTypeScale.subhead,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    RaftArtifactCollectionLayout.versionBadge(
                      context,
                      'v${card.version}',
                    ),
                  ],
                ),
                ?newsBadge(context, item.news),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: embed.footer.padding,
            child: Column(
              spacing: RaftSpace.x1 + RaftSpace.half,
              children: [
                Row(
                  spacing: RaftSpace.x2,
                  children: [
                    Expanded(child: author(context, card)),
                    if (!compact) meta,
                  ],
                ),
                Row(
                  spacing: RaftSpace.x2,
                  children: [
                    Expanded(child: mono(context, time)),
                    if (compact) meta,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget mono(BuildContext context, String text) {
    final t = RaftTokens.of(context);
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: t.scale(
        t.typeSlot('mono-meta'),
        mono: true,
        color: t.ui.foregroundHint,
      ),
    );
  }

  Widget author(BuildContext context, ArtifactCard card) {
    final t = RaftTokens.of(context);
    final actor = card.author;
    final name = artifactActorName(context, actor);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: RaftSpace.x1_5,
      children: [
        RaftAvatar(
          name: name,
          uiSize: RaftAvatarSize.xs,
          kind: actor.type == 'agent'
              ? RaftAvatarKind.agent
              : RaftAvatarKind.human,
          imageUrl: actor.avatarUrl,
        ),
        Flexible(
          child: Text(
            actor.type == 'user' && readerId != null && actor.id == readerId
                ? raftText(context, 'You')
                : name,
            style: t.scale(RaftTypeScale.footnote, color: t.ui.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

class _ArtifactTileCover extends StatefulWidget {
  const _ArtifactTileCover({
    super.key,
    required this.card,
    required this.compact,
    this.read,
  });

  final ArtifactCard card;
  final bool compact;
  final Future<Uint8List> Function(ArtifactCard)? read;

  @override
  State<_ArtifactTileCover> createState() => _ArtifactTileCoverState();
}

class _ArtifactTileCoverState extends State<_ArtifactTileCover> {
  late final image =
      widget.card.preview.kind == 'image' ||
          widget.card.preview.screenshot(widget.compact) != null
      ? widget.read?.call(widget.card)
      : null;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final card = widget.card;
    final placeholder = Center(
      child: ExcludeSemantics(
        child: RaftFilePreview(
          kind: switch (card.kind) {
            ArtifactKind.html => RaftFilePreviewKind.code,
            ArtifactKind.image ||
            ArtifactKind.video => RaftFilePreviewKind.media,
            _ => RaftFilePreviewKind.document,
          },
          label: artifactKindBadge(card.kind),
          scale: RaftArtifactCollectionLayout.tilePreviewScale,
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: card.preview.kind == 'excerpt' ? null : t.ui.fillMuted,
        border: Border(bottom: BorderSide(color: t.ui.lineHairline)),
      ),
      child: ClipRect(
        child: card.preview.kind == 'excerpt'
            ? Padding(
                padding: const EdgeInsets.all(RaftSpace.x3),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) {
                    final fade = t.size(
                      'css.fade-edge',
                      fallback: RaftSpace.x6,
                    );
                    final end = bounds.bottom - fade.clamp(0.0, bounds.height);
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        t.ui.foreground,
                        t.ui.foreground.withValues(alpha: 0),
                      ],
                    ).createShader(
                      Rect.fromLTRB(
                        bounds.left,
                        end,
                        bounds.right,
                        bounds.bottom,
                      ),
                    );
                  },
                  child: OverflowBox(
                    alignment: AlignmentDirectional.topStart,
                    maxHeight: double.infinity,
                    child: ExcludeSemantics(
                      child: _ArtifactExcerpt(preview: card.preview),
                    ),
                  ),
                ),
              )
            : FutureBuilder<Uint8List>(
                future: image,
                builder: (context, snapshot) => snapshot.data == null
                    ? placeholder
                    : RaftSizedImage.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        evictOnDispose: true,
                        alignment: Alignment.topCenter,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => placeholder,
                      ),
              ),
      ),
    );
  }
}

class _ArtifactExcerpt extends StatelessWidget {
  const _ArtifactExcerpt({required this.preview});

  final ArtifactPreview preview;

  @override
  Widget build(BuildContext context) {
    final style = RaftArtifactExcerptStyle(RaftTokens.of(context));
    if (preview.blocks.isEmpty) return Text(preview.text, style: style.body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: RaftSpace.x1_5,
      children: [
        for (final block in preview.blocks)
          Text.rich(
            TextSpan(
              children: [
                for (final span in block.spans)
                  TextSpan(
                    text: span.text,
                    style: style.inline(
                      code: span.code,
                      bold: span.bold,
                      italic: span.italic,
                    ),
                  ),
              ],
            ),
            style: block.heading == 0
                ? style.body
                : style.heading(block.heading),
          ),
      ],
    );
  }
}
