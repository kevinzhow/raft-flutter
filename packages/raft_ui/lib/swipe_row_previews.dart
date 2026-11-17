import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

RaftSwipeActions _trailing() => RaftSwipeActions(
  actions: [
    RaftSwipeAction(
      label: 'Done',
      glyph: RaftGlyph.checkCircle2,
      tone: RaftSwipeActionTone.success,
      onPressed: () {},
    ),
    RaftSwipeAction(label: 'Mute', glyph: RaftGlyph.bellOff, onPressed: () {}),
  ],
);

RaftSwipeActions _leading() => RaftSwipeActions(
  full: RaftSwipeFull.keep,
  actions: [
    RaftSwipeAction(
      label: 'Read',
      glyph: RaftGlyph.messageSquareCheck,
      onPressed: () {},
    ),
  ],
);

/// Touch-only: on a touch device drag a row; the preview also shows each
/// resting state (closed, open on the trailing buttons, open on the leading).
@RaftPreviews('Swipe row', size: Size(390, 260))
Widget swipeRowPreview() => Builder(
  builder: (context) {
    final bg = RaftTokens.of(context).ui.layerCanvas;
    Widget row(String title, RaftSwipeEdge? open) => RaftSwipeRow(
      enabled: true,
      open: open,
      onOpenChange: (_) {},
      leading: _leading(),
      trailing: _trailing(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: AlignmentDirectional.centerStart,
        color: bg,
        child: Text(title),
      ),
    );
    return Column(
      children: [
        row('Closed', null),
        row('Open on Done and Mute', RaftSwipeEdge.end),
        row('Open on Read', RaftSwipeEdge.start),
      ],
    );
  },
);
