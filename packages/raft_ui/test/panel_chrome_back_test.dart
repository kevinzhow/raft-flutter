// A panel head whose host stacks it over another pane draws the host's Back in
// place of its own close, and pressing it is the host's Back (it pops this
// pane and shows the one underneath), not this panel's own close.
//
// `RaftPanelHeaderChrome.onBack` is how a host says so. The docked thread head
// ignored it and kept drawing its × at desktop widths, which made the hosts
// that pass it (`ChannelSideArea`) pass it for nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

final _back = find.byKey(const Key('thread-back'));
final _close = find.byKey(const Key('thread-close'));

void main() {
  /// The thread docked beside a conversation on a desktop window: wide enough
  /// that the head's own rule draws a close and no Back.
  Future<void> mountThread(
    WidgetTester t, {
    VoidCallback? hostBack,
    VoidCallback? ownClose,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1280, 800);
    addTearDown(t.view.reset);
    final head = RaftThreadHeader(
      presentation: RaftThreadPresentation.side,
      threadLabel: 'Thread',
      jumpLabel: 'Scroll to first message',
      backLabel: 'Close thread',
      closeLabel: 'Close thread',
      parentLabel: '#test',
      replyCount: 1,
      backKey: const Key('thread-back'),
      closeKey: const Key('thread-close'),
      // The thread's own Back and close (workspace_view passes one callback
      // for both).
      onBack: ownClose ?? () {},
      onClose: ownClose ?? () {},
    );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftThreadPlacement(
            split: true,
            focused: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: hostBack == null
                    ? head
                    : RaftPanelHeaderChrome(
                        actions: const [],
                        onBack: hostBack,
                        child: head,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 350));
  }

  testWidgets('on its own the docked thread head draws its close', (t) async {
    await mountThread(t);
    expect(_close, findsOneWidget);
    expect(_back, findsNothing);
  });

  testWidgets('stacked by its host it draws Back, and Back is the host\'s', (
    t,
  ) async {
    var popped = 0, closed = 0;
    await mountThread(t, hostBack: () => popped++, ownClose: () => closed++);
    expect(_back, findsOneWidget);
    expect(
      _close,
      findsNothing,
      reason: 'a stacked pane shows one control, not a Back and a close',
    );
    await t.tap(_back);
    await t.pump();
    expect(popped, 1);
    expect(closed, 0, reason: 'the host pops the pane, not the thread itself');
  });
}
