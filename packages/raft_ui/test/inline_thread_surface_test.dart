import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/inline_thread_surface.dart';
import 'package:raft_ui/src/theme.dart';

const publicReplies = [
  RaftInlineReply(
    id: 'system-event',
    author: 'System',
    preview: 'Joined',
    senderType: 'system',
  ),
  RaftInlineReply(
    id: 'one',
    author: 'artin',
    preview: 'Looks good',
    senderType: 'user',
    timestamp: '14:29',
  ),
  RaftInlineReply(
    id: 'two',
    author: 'Cindy',
    preview: 'Ready for review',
    senderType: 'agent',
    timestamp: '14:30',
  ),
  RaftInlineReply(
    id: 'three',
    author: 'Designer',
    preview: 'Checked',
    senderType: 'user',
  ),
  RaftInlineReply(
    id: 'four',
    author: 'Cody',
    preview: 'Fourth preview',
    senderType: 'agent',
  ),
];

Widget host({
  RaftFamily family = RaftFamily.elegant,
  bool dark = false,
  double width = 390,
  List<RaftInlineReply> replies = publicReplies,
  int count = 5,
  VoidCallback? onOpen,
  FocusNode? focus,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: RaftInlineThreadSurface(
          replyCount: count,
          replies: replies,
          summary: Text('$count replies ›'),
          semanticLabel: 'Open $count replies in parent thread',
          onOpen: onOpen,
          focusNode: focus,
        ),
      ),
    ),
  ),
);

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('one parent surface uses source row geometry $family/$dark', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        host(family: family, dark: dark, onOpen: () => calls++),
      );
      expect(find.text('5 replies ›'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inline-reply-system-event')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('inline-reply-four')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('inline-reply-one'))).height,
        20,
      );
      final first = tester.getTopLeft(
        find.byKey(const ValueKey('inline-reply-one')),
      );
      final second = tester.getTopLeft(
        find.byKey(const ValueKey('inline-reply-two')),
      );
      expect(second.dy - first.dy, 24);
      expect(first.dx, family == RaftFamily.brutal ? 10 : 10.5);
      await tester.tap(find.text('Looks good'));
      await tester.pump();
      expect(calls, 1);
      await tester.tap(find.text('5 replies ›'));
      await tester.pump();
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('whole surface has one enabled keyboard action', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var calls = 0;
    await tester.pumpWidget(host(focus: focus, onOpen: () => calls++));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // No independent reply-row focus stops were introduced.
    final descendants = find.descendant(
      of: find.byType(RaftInlineThreadSurface),
      matching: find.byType(FocusableActionDetector),
    );
    expect(descendants, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('system-only or zero authoritative count creates no action', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(replies: [publicReplies.first], onOpen: () {}),
    );
    expect(find.byType(FocusableActionDetector), findsNothing);
    await tester.pumpWidget(host(count: 0, onOpen: () {}));
    expect(find.byType(FocusableActionDetector), findsNothing);
  });
  testWidgets('narrow long identities truncate without changing clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        width: 160,
        replies: const [
          RaftInlineReply(
            id: 'long',
            author: 'A long public display name that must shrink',
            preview: 'A long preview that must remain on one line',
            timestamp: '14:30',
            senderType: 'user',
          ),
        ],
        onOpen: () {},
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('inline-reply-long'))).height,
      20,
    );
    expect(find.text('14:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('read-only surface preserves normal paint and removes action', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final detector = tester.widget<FocusableActionDetector>(
      find.byType(FocusableActionDetector),
    );
    expect(detector.enabled, isFalse);
    final semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byType(FocusableActionDetector),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.onTap, isNull);
    expect(find.text('Looks good'), findsOneWidget);
  });
  testWidgets('changed parent callback is used after update and mouse hover', (
    tester,
  ) async {
    var oldCalls = 0, newCalls = 0;
    await tester.pumpWidget(host(onOpen: () => oldCalls++));
    await tester.pumpWidget(host(onOpen: () => newCalls++));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: const Offset(2, 400));
    await pointer.moveTo(tester.getCenter(find.text('Cindy')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('Cindy'));
    await tester.pump();
    expect(oldCalls, 0);
    expect(newCalls, 1);
    await pointer.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('retained surface reparenting never invokes the user action', (
    tester,
  ) async {
    final key = GlobalKey();
    var calls = 0;
    Widget app(bool right) => MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: Row(
          children: [
            for (final atRight in [false, true])
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: atRight == right
                      ? RaftInlineThreadSurface(
                          key: key,
                          replyCount: 5,
                          replies: publicReplies,
                          summary: const Text('5 replies ›'),
                          semanticLabel: 'Open thread',
                          onOpen: () => calls++,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    final state = tester.state(find.byKey(key));
    await tester.pumpWidget(app(true));
    expect(tester.state(find.byKey(key)), same(state));
    expect(calls, 0);
    await tester.tap(find.text('Looks good'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
