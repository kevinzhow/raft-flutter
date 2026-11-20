import 'package:flutter/widgets.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Action card states', size: Size(390, 360))
Widget actionCardStatesPreview() => SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 12,
    children: [
      RaftSpecActionCard(
        title: 'Create Scribe',
        icon: RaftGlyph.bot,
        body: Builder(
          builder: (context) {
            final content = RaftSpecActionCardContent(context);
            return content.column([
              content.properties(const [
                RaftDescriptionEntry('Description', 'Takes meeting notes.'),
              ]),
              content.hint(
                label: 'Reason',
                body: 'You asked for a note taker.',
              ),
              content.actions([
                RaftButton(
                  label: 'Create Agent',
                  uiVariant: RaftButtonVariant.outline,
                  uiSize: RaftButtonSize.md,
                  onPressed: () {},
                ),
              ]),
            ]);
          },
        ),
      ),
      const RaftSpecActionCard(
        title: 'Move Scout',
        icon: RaftGlyph.bot,
        status: 'Done',
        statusVariant: RaftStatusVariant.success,
        expanded: false,
        description: 'Committed by Ava',
        completed: true,
        body: SizedBox.shrink(),
      ),
      const RaftSpecActionCard(
        title: 'Create launch-week',
        icon: RaftGlyph.hash,
        status: 'Expired',
        expanded: false,
        body: SizedBox.shrink(),
      ),
    ],
  ),
);
