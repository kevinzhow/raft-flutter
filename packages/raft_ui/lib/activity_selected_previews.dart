import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

/// Design preview for the persistent selected Activity row. The stack shows every row state next to each other so the
/// selected treatment can be judged against read, unread and hover.
@RaftPreviews('Activity selected row', size: Size(520, 640))
Widget activitySelectedRowsPreview() => const ActivitySelectedRows();

@RaftPreviews('Activity selected master-detail', size: Size(1180, 640))
Widget activitySelectedMasterDetailPreview() =>
    const ActivitySelectedMasterDetail();

@RaftPreviews('Resource toolbar', size: Size(390, 240))
Widget resourceToolbarPreview() => const _ResourceToolbarPreview();

class _ResourceToolbarPreview extends StatefulWidget {
  const _ResourceToolbarPreview();
  @override
  State<_ResourceToolbarPreview> createState() =>
      _ResourceToolbarPreviewState();
}

class _ResourceToolbarPreviewState extends State<_ResourceToolbarPreview> {
  String filter = 'all';
  int marked = 0;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RaftResourceFilterViewport(
                child: RaftSegmentedControl<String>(
                  value: filter,
                  shrinkFrame:
                      RaftTokens.of(context)
                          .option('resource.rows', or: 'cards') ==
                      'flat',
                  minimumTargetSize: 32,
                  items: const [
                    RaftSegmentedOption(value: 'all', label: 'All'),
                    RaftSegmentedOption(value: 'unread', label: 'Unread'),
                    RaftSegmentedOption(value: 'mentions', label: 'Mentions'),
                  ],
                  onChanged: (value) => setState(() => filter = value),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (RaftScaled.grows(context))
              Flexible(
                child: RaftResourceMarkReadButton(
                  onPressed: () => setState(() => marked++),
                ),
              )
            else
              RaftResourceMarkReadButton(
                onPressed: () => setState(() => marked++),
              ),
          ],
        ),
        const SizedBox(height: 16),
        RaftCssText('Filter: $filter; read actions: $marked'),
      ],
    ),
  );
}

class _Sample {
  const _Sample(
    this.channel,
    this.title,
    this.sender,
    this.snippet,
    this.time, {
    this.unread = 0,
    this.replies = 0,
  });
  final String channel, title, sender, snippet, time;
  final int unread, replies;
}

const _samples = [
  _Sample(
    '产品设计',
    '周会议程：本周需要确认的设计评审事项',
    'Alice',
    '评审清单已经更新到文档里，大家看一下',
    '12分钟',
    replies: 3,
  ),
  _Sample(
    '工程',
    '发布前的回归测试清单',
    'Bob',
    '桌面端的列表滚动问题已经修好了',
    '26分钟',
    unread: 2,
    replies: 5,
  ),
  _Sample(
    '产品设计',
    '新版 Activity 的选中状态怎么设计',
    'Cindy',
    '先出三套主题的预览图给你看',
    '1小时',
    replies: 8,
  ),
  _Sample('运营', '十月增长数据复盘', 'Dana', '留存曲线比上个月好了不少', '2小时', replies: 2),
  _Sample(
    '工程',
    '桌面端性能预算讨论',
    'Evan',
    '首屏时间目前在预算之内',
    '3小时',
    unread: 1,
    replies: 4,
  ),
  _Sample('设计', '图标库整理', 'Fiona', '已经合并了重复的图标', '昨天', replies: 1),
];

/// A row with the same content structure as the Activity list rows.
class ActivitySampleRow extends StatelessWidget {
  const ActivitySampleRow({
    super.key,
    required this.sample,
    this.selected = false,
  });
  final _Sample sample;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftConversationCardRecipe(t);
    final unread = sample.unread > 0;
    return RaftConversationCard(
      selected: selected,
      onOpen: () {},
      actions: RaftIconButton(
        glyph: RaftGlyph.check,
        visualSize: 28,
        minimumTargetSize: 28,
        tooltip: '标记为完成',
        onPressed: () {},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: RaftCssText(
              '#${sample.channel}',
              style: recipe.metadata.copyWith(
                fontSize: 11,
                height: 12 / 11,
                color: recipe.titleIconColor,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RaftCssText.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Transform.translate(
                          offset: const Offset(0, 2),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: RaftThreadIcon(
                              size: 13,
                              color: recipe.titleIconColor,
                            ),
                          ),
                        ),
                      ),
                      TextSpan(text: sample.title),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.titleStyle(unread),
                ),
              ),
              const SizedBox(width: 8),
              RaftConversationTimestamp(
                child: RaftCssText(sample.time, style: recipe.timestamp),
              ),
            ],
          ),
          const SizedBox(height: 2),
          RaftCssText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${sample.sender}: ',
                  style: recipe.body.copyWith(
                    color: recipe.senderColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: sample.snippet),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: recipe.body.copyWith(color: recipe.titleColor(unread)),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RaftResourceBadge(
                  label: '${sample.replies} 条回复',
                  appearance: RaftBadgeRecipeAppearance.outline,
                  variant: RaftBadgeRecipeVariant.muted,
                ),
                if (unread)
                  RaftResourceBadge(
                    label: '${sample.unread} 条新消息',
                    variant: RaftBadgeRecipeVariant.accent,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rows top to bottom: read, unread, read (hover target in the screenshots),
/// selected read, selected + unread, read.
class ActivitySelectedRows extends StatelessWidget {
  const ActivitySelectedRows({super.key});
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftDensityScope(
      density: RaftDensity.desktop,
      child: ColoredBox(
        color: t.colors['layer-canvas-muted']!,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (i, selected) in const [
              false,
              false,
              false,
              true,
              true,
              false,
            ].indexed) ...[
              ActivitySampleRow(
                key: ValueKey('activity-selected-row-$i'),
                sample: _samples[i],
                selected: selected,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Desktop master-detail: the list splits on first click and the selected row
/// stays marked while the preview is open.
class ActivitySelectedMasterDetail extends StatelessWidget {
  const ActivitySelectedMasterDetail({
    super.key,
    this.listWidth = 460,
    this.showDetail = true,
  });
  final double listWidth;
  final bool showDetail;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftConversationCardRecipe(t);
    final line = t.colors['line-muted']!;
    return RaftDensityScope(
      density: RaftDensity.desktop,
      child: Row(
        children: [
          SizedBox(
            width: listWidth,
            child: ColoredBox(
              color: t.colors['layer-canvas-muted']!,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final (i, s) in _samples.indexed) ...[
                    ActivitySampleRow(sample: s, selected: i == 2),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          Container(width: t.border, color: line),
          Expanded(
            child: ColoredBox(
              color: t.panel,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RaftCssText(
                      '#产品设计',
                      style: recipe.metadata.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: 8),
                    RaftCssText(
                      _samples[2].title,
                      style: RaftTypography.body(
                        t,
                        size: 18,
                        line: 26,
                        weight: FontWeight.w700,
                        color: t.strong,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final line in const [
                      'Cindy  先出三套主题的预览图给你看',
                      'Kevin  好的，选中态要能一眼看出来，列表在刷新的时候也不会丢',
                      'Cindy  明白，会和侧边栏、成员列表的选中语言保持一致',
                    ]) ...[
                      RaftCssText(
                        line,
                        style: RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
