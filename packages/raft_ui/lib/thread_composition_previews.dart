import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/components.dart';
import 'src/design_primitives.dart';
import 'src/thread_composition.dart';

@RaftPreviews('Mounted Thread composition desktop', size: Size(1280, 560))
Widget mountedThreadCompositionDesktopPreview() =>
    const _ThreadCompositionPreview(RaftDensity.desktop, 1280);

@RaftPreviews('Mounted Thread composition folded touch', size: Size(390, 560))
Widget mountedThreadCompositionTouchPreview() =>
    const _ThreadCompositionPreview(RaftDensity.touch, 390);

class _ThreadCompositionPreview extends StatefulWidget {
  const _ThreadCompositionPreview(this.density, this.width);
  final RaftDensity density;
  final double width;
  @override
  State<_ThreadCompositionPreview> createState() =>
      _ThreadCompositionPreviewState();
}

class _ThreadCompositionPreviewState extends State<_ThreadCompositionPreview> {
  final scroll = ScrollController();
  var actions = 0;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => RaftDensityScope(
    density: widget.density,
    child: Column(children: [
      RaftThreadHeader(
        presentation: RaftThreadPresentation.side,
        viewportWidth: widget.width,
        viewportHeight: 560,
        threadLabel: 'Thread', parentLabel: '#design',
        jumpLabel: 'Scroll thread to first message',
        backLabel: 'Back', closeLabel: 'Close thread',
        onJumpToStart: () => scroll.jumpTo(0),
        onBack: () => setState(() => actions++),
        onClose: () => setState(() => actions++),
        actions: [RaftThreadOverflowAction(
          label: 'Thread actions', onPressed: () => setState(() => actions++),
        )],
      ),
      Expanded(child: CustomScrollView(controller: scroll, slivers: [
        const RaftThreadTimelineTopSliver(
          parent: RaftMessageTile(
            author: 'Public fixture 中文 日本語', timestamp: '10:30',
            content: 'The parent scrolls with the replies.\n'
                'This is a public interactive preview, not private chat data.',
          ),
          hasMore: false, historyLimited: false, loadingOlder: false,
          loadingOlderLabel: 'Loading older replies...',
          historyLimitedLabel: 'Older replies are limited by the current plan',
          beginningLabel: 'Beginning of replies', replyCountLabel: '12 replies',
        ),
        SliverList.builder(itemCount: 12, itemBuilder: (_, index) =>
          RaftMessageTile(author: 'Public reply', timestamp: '10:31',
            content: 'Reply ${index + 1} 中文 日本語')),
      ])),
      // Fixture callback receipt; this is not part of the Web header recipe.
      Text('Preview actions: $actions'),
    ]),
  );
}
