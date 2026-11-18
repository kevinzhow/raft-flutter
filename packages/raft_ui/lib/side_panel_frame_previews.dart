import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Side panel frame', size: Size(856, 520))
Widget sidePanelFramePreview() => const _SidePanelFramePreview();

class _SidePanelFramePreview extends StatelessWidget {
  const _SidePanelFramePreview();

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.canvas,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final placement in RaftSidePanelPlacement.values) ...[
              if (placement != RaftSidePanelPlacement.values.first)
                const SizedBox(width: 20),
              Expanded(
                child: RaftSidePanelFrame(
                  placement: placement,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: RaftSidePanelFrame.headerRule(t),
                        ),
                        child: Text(placement.name),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Side-panel content'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
