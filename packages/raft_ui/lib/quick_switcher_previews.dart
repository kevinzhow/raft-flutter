import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Quick switcher', size: Size(900, 640))
Widget quickSwitcherPreview() => const _QuickSwitcherPreview();

class _QuickSwitcherPreview extends StatefulWidget {
  const _QuickSwitcherPreview();
  @override
  State<_QuickSwitcherPreview> createState() => _QuickSwitcherPreviewState();
}

class _QuickSwitcherPreviewState extends State<_QuickSwitcherPreview> {
  final controller = TextEditingController(), focus = FocusNode();
  final scroll = ScrollController();
  int selected = 0;
  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rect = RaftQuickSwitcherMetrics.cardRect(MediaQuery.sizeOf(context));
    return RaftQuickSwitcherLayer(
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: RaftQuickSwitcherFrame(
              semanticLabel: 'Search',
              selectLabel: 'Select',
              openLabel: 'Open',
              field: RaftQuickSwitcherField(
                controller: controller,
                focusNode: focus,
                hint: 'Channels, people, messages…',
                clearLabel: 'Clear Search',
                onClear: controller.clear,
              ),
              body: RaftQuickSwitcherList(
                controller: scroll,
                compact: true,
                children: [
                  RaftQuickSwitcherSection(
                    heading: 'Recent conversations',
                    glyph: RaftGlyph.clock3,
                    children: [
                      for (final (i, name) in ['design', 'ops'].indexed)
                        RaftQuickSwitcherRow(
                          leading: const RaftQuickSwitcherIconBox(
                            RaftGlyph.hash,
                          ),
                          title: name,
                          subtitle: 'Channel',
                          badges: const ['Channel'],
                          selected: selected == i,
                          returnHint: true,
                          onPressed: () => setState(() => selected = i),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@RaftPreviews('Quick switcher results', size: Size(720, 900))
Widget quickSwitcherResultsPreview() => Builder(
  builder: (context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const RaftQuickSwitcherFilterRow(
        child: RaftSearchFilterWrap(children: [Text('From'), Text('Scope')]),
      ),
      const SizedBox(height: 16),
      RaftQuickSwitcherThreadGroup(
        badge: 'Thread',
        where: '#product',
        hits: '2 hits',
        time: '25 minutes ago',
        title: 'Parity plan for the extension suite',
        selected: true,
        children: [
          for (final (i, who) in ['Cindy', 'Designer'].indexed)
            RaftQuickSwitcherHit(
              where: '#product',
              threadLabel: 'thread',
              warnings: const ['Archived', 'Upgrade to view'],
              sender: who,
              time: '1 hour ago',
              snippet: const Text('Parity captures for the overlay'),
              selected: i == 0,
              nested: true,
              first: i == 0,
              onPressed: () {},
            ),
        ],
      ),
      const SizedBox(height: 16),
      const RaftQuickSwitcherSkeleton(),
      const SizedBox(height: 16),
      RaftQuickSwitcherErrorCard(
        title: 'Search failed',
        body: 'The last search request failed.',
        actionLabel: 'Retry',
        onAction: () {},
      ),
      const SizedBox(height: 16),
      const SizedBox(
        height: 160,
        child: RaftQuickSwitcherEmpty(
          title: 'Search everything',
          detail: 'Search channels, DMs, people, agents, and message history.',
        ),
      ),
    ],
  ),
);
