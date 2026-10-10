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
                clearLabel: 'Clear search',
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
