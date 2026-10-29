// The thread summary under a message: at large text sizes each reply stacks and
// its preview wraps, instead of the preview being squeezed out of one line.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Future<void> pump(WidgetTester t, double factor) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = factor;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => RaftTextScaling(child: child!),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(left: 48),
              child: RaftThreadReplies(
                replyCount: 9,
                onOpen: () {},
                onOpenReply: (_) {},
                replies: const [
                  RaftThreadReplyPreview(
                    id: 'r1',
                    author: 'Alice Zhang',
                    preview: '我看了一下，问题在列表的布局阶段。',
                    senderType: 'user',
                    timestamp: '10/01 09:19 AM',
                  ),
                  RaftThreadReplyPreview(
                    id: 'r2',
                    author: 'Bob Li',
                    preview: 'Agreed, let us measure before changing it.',
                    senderType: 'user',
                    timestamp: '10/01 09:20 AM',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps one line per reply at the default text size', (t) async {
    await pump(t, 1.0);
    final row = t.getSize(find.byKey(const ValueKey('thread-preview-r1')));
    expect(row.height, lessThan(60));
    expect(t.takeException(), isNull);
  });

  for (final factor in [2.0, 3.1]) {
    testWidgets('stacks the reply and wraps the preview at ${factor}x', (
      t,
    ) async {
      await pump(t, factor);
      expect(t.takeException(), isNull);
      final preview = t.getSize(find.text('我看了一下，问题在列表的布局阶段。'));
      // The preview has room to wrap, and the author is never ellipsised.
      final author = t.widget<Text>(find.text('Alice Zhang'));
      expect(author.overflow, isNot(TextOverflow.ellipsis));
      expect(preview.width, greaterThan(150));
    });
  }

  group('RaftInlineThreadSurface', () {
    Future<void> pumpInline(WidgetTester t, double factor) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = factor;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          builder: (context, child) => RaftTextScaling(child: child!),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(left: 48),
                child: RaftInlineThreadSurface(
                  replyCount: 9,
                  summary: const Text('9 replies ›'),
                  semanticLabel: 'Open 9 replies',
                  onOpen: () {},
                  replies: const [
                    RaftInlineReply(
                      id: 'one',
                      author: 'Alice Zhang',
                      preview: '我看了一下，问题在列表的布局阶段，需要继续测量。',
                      timestamp: '10/01 09:19 AM',
                      senderType: 'user',
                      avatar: SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('keeps the 20px row at the default text size', (t) async {
      await pumpInline(t, 1.0);
      expect(
        t.getSize(find.byKey(const ValueKey('inline-reply-one'))).height,
        20,
      );
    });

    testWidgets('the preview is visible and wraps at 2.0x', (t) async {
      await pumpInline(t, 2.0);
      expect(t.takeException(), isNull);
      final preview = t.getSize(find.text('我看了一下，问题在列表的布局阶段，需要继续测量。'));
      expect(preview.width, greaterThan(150));
      expect(preview.height, greaterThan(40), reason: 'wrapped, not one line');
      expect(t.getSize(find.text('Alice Zhang')).width, greaterThan(100));
    });
  });
}
