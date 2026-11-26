import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Pull to refresh · short list', size: Size(390, 600))
Widget shortRefreshPreview() => const _RefreshPreview(empty: false);

@RaftPreviews('Pull to refresh · empty', size: Size(390, 600))
Widget emptyRefreshPreview() => const _RefreshPreview(empty: true);

class _RefreshPreview extends StatefulWidget {
  const _RefreshPreview({required this.empty});
  final bool empty;
  @override
  State<_RefreshPreview> createState() => _RefreshPreviewState();
}

class _RefreshPreviewState extends State<_RefreshPreview> {
  int refreshed = 0;
  @override
  Widget build(BuildContext context) => RaftPullToRefresh(
    onRefresh: () async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => refreshed++);
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: widget.empty
          ? [
              const RaftEmptyState(
                title: 'No activity',
                detail: 'Pull to refresh.',
              ),
              Text('Refreshes: $refreshed'),
            ]
          : [
              for (var i = 0; i < 3; i++)
                RaftListRow(
                  variant: RaftListRowVariant.plain,
                  interactive: false,
                  children: [
                    RaftListRowBody(
                      children: [
                        RaftListRowTitle(
                          'Member ${i + 1} · refresh $refreshed',
                        ),
                      ],
                    ),
                  ],
                ),
            ],
    ),
  );
}
