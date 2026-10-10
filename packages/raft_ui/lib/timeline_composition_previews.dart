import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/conversation_surface.dart';
import 'src/timeline_composition.dart';

@RaftPreviews('Timeline Main centered composition', size: Size(390, 560))
Widget timelineMainPreview() =>
    const _TimelinePreview(RaftConversationSurfaceRole.channelTimeline);

@RaftPreviews('Timeline Thread centered composition', size: Size(390, 560))
Widget timelineThreadPreview() =>
    const _TimelinePreview(RaftConversationSurfaceRole.threadTimeline);

/// The two-sided column the app mounts: header, history growing away from the
/// center, the forward rows and the natural footer.
class _TimelinePreview extends StatefulWidget {
  const _TimelinePreview(this.role);
  final RaftConversationSurfaceRole role;
  @override
  State<_TimelinePreview> createState() => _TimelinePreviewState();
}

class _TimelinePreviewState extends State<_TimelinePreview> {
  static const _center = ValueKey('timeline-preview-center');
  var long = false;
  @override
  Widget build(BuildContext context) => RaftConversationSurface(
    role: widget.role,
    child: Column(
      children: [
        TextButton(
          onPressed: () => setState(() => long = !long),
          child: Text(long ? 'Show sparse rows' : 'Show long rows'),
        ),
        Expanded(
          child: CustomScrollView(
            center: _center,
            anchor: 1,
            slivers: const RaftTimelineCompositionRecipe().centeredSlivers(
              header: const [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Header stays above the history'),
                  ),
                ),
              ],
              history: SliverList.builder(
                itemCount: long ? 24 : 0,
                itemBuilder: (_, index) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Earlier message ${index + 1}'),
                ),
              ),
              forward: SliverList.builder(
                key: _center,
                itemCount: long ? 24 : 2,
                itemBuilder: (_, index) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Public message ${index + 1}'),
                ),
              ),
              footer: const RaftTimelineFooter(),
            ),
          ),
        ),
      ],
    ),
  );
}
