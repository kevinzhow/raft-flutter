import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/conversation_surface.dart';
import 'src/timeline_composition.dart';

@RaftPreviews('Timeline sparse Main bottom', size: Size(390, 560))
Widget timelineSparseMainPreview() =>
    const _TimelinePreview(RaftTimelineSparseAnchor.bottom);

@RaftPreviews('Timeline sparse Thread top', size: Size(390, 560))
Widget timelineSparseThreadPreview() =>
    const _TimelinePreview(RaftTimelineSparseAnchor.top);

class _TimelinePreview extends StatefulWidget {
  const _TimelinePreview(this.anchor);
  final RaftTimelineSparseAnchor anchor;
  @override
  State<_TimelinePreview> createState() => _TimelinePreviewState();
}

class _TimelinePreviewState extends State<_TimelinePreview> {
  var long = false;
  @override
  Widget build(BuildContext context) => RaftConversationSurface(
    role: widget.anchor == RaftTimelineSparseAnchor.bottom
        ? RaftConversationSurfaceRole.channelTimeline
        : RaftConversationSurfaceRole.threadTimeline,
    child: Column(
      children: [
        TextButton(
          onPressed: () => setState(() => long = !long),
          child: Text(long ? 'Show sparse rows' : 'Show long rows'),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              RaftTimelineCompositionSliver(
                anchor: widget.anchor,
                header: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Header remains before the spacer'),
                ),
                messagesSliver: SliverList.builder(
                  itemCount: long ? 48 : 2,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Public message ${index + 1}'),
                  ),
                ),
                footer: const RaftTimelineFooter(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
