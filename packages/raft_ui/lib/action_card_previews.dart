import 'package:flutter/widgets.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Action card states', size: Size(390, 360))
Widget actionCardStatesPreview() => Column(
  mainAxisSize: MainAxisSize.min,
  spacing: 12,
  children: [
    RaftSpecActionCard(
      title: 'Create Scribe',
      icon: RaftGlyph.bot,
      body: Column(
        children: [
          const RaftActionField(
            label: 'Description',
            value: 'Takes meeting notes.',
          ),
          RaftButton(
            label: 'Create Agent',
            uiVariant: RaftButtonVariant.outline,
            uiSize: RaftButtonSize.md,
            onPressed: () {},
          ),
        ],
      ),
    ),
    const RaftSpecActionCard(
      title: 'Move Scout',
      icon: RaftGlyph.bot,
      status: 'Done',
      statusVariant: RaftStatusVariant.success,
      expanded: false,
      description: 'Committed by Ava',
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
);
