// Which panes stand beside the conversation when not all of them fit
// ([ChannelSideStack.fitting]).
//
// A column too wide for the room left stopped the search, so every column
// after it waited behind the top pane even where it fitted: with the Artifact
// (480) between the Thread (360) and Tasks (280) in 1100px beside a 360px
// chat, Tasks was stacked although Thread + Tasks + the chat come to 1000.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_card.dart'
    show ChannelSideMode;
import 'package:raft_flutter/features/channel_side_layout.dart';
import 'package:raft_flutter/features/channel_side_stack.dart';
import 'package:raft_ui/raft_ui.dart' show RaftLayoutClass;

VisibleChannelSideColumn _column(
  int index,
  ChannelSideSection section,
  int width,
) => VisibleChannelSideColumn(
  column: index,
  sections: [section],
  width: width,
  minWidth: channelSideSectionMinWidth[section]!,
);

void main() {
  // Thread, Artifact, Tasks in that order (a saved layout the person moved
  // sections into), newest open last: the Thread is the pane on top.
  final visible = [
    _column(0, ChannelSideSection.thread, 400),
    _column(1, ChannelSideSection.artifact, 480),
    _column(2, ChannelSideSection.tasks, 360),
  ];
  const ticks = {
    ChannelSideSection.artifact: 1,
    ChannelSideSection.tasks: 2,
    ChannelSideSection.thread: 3,
  };

  test('a column that does not fit does not keep a later one out', () {
    final shown = const ChannelSideStack(ticks)
        .fitting(visible, width: 1100, chatFloor: channelSideChatMinWidth);
    expect(
      [for (final column in shown) column.column],
      [0, 2],
      reason: 'Tasks fits beside the Thread; only the Artifact does not',
    );
    // Still in layout order, so a pane does not move when another opens.
    expect(
      [for (final column in shown) column.sections.single],
      [ChannelSideSection.thread, ChannelSideSection.tasks],
    );
  });

  test('two of the three panes stand beside the chat at 1100', () {
    final placement = placeChannelSide(
      visible,
      width: 1100,
      compact: false,
      layout: RaftLayoutClass.wide,
      stack: const ChannelSideStack(ticks),
    );
    expect(placement.mode, ChannelSideMode.beside);
    expect(placement.columns, hasLength(2));
    expect(placement.stackedBelow, 1);
    for (final column in placement.columns) {
      expect(
        column.width,
        greaterThanOrEqualTo(
          channelSideColumnMinWidth(column.sections).toDouble(),
        ),
      );
    }
    final chat = 1100 - placement.columns.fold(0.0, (sum, c) => sum + c.width);
    expect(chat, greaterThanOrEqualTo(channelSideChatMinWidth - .01));
  });
}
