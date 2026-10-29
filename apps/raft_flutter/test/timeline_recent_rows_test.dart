import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_flutter/features/timeline_row_reuse.dart';
import 'package:raft_client/raft_client.dart';

void main() {
  test('retention excludes media, previews, cards and large text', () {
    bool retain(String text, [Map<String, dynamic> extra = const {}]) =>
        retainTimelineProse(RaftMessage({'content': text, ...extra}));
    expect(retain('A short reply with @member'), isTrue);
    expect(retain('```dart\nprint(1);\n```'), isTrue);
    expect(retain('[docs](https://example.invalid/reference)'), isTrue);
    for (final text in [
      'x' * 4097,
      '```mermaid\ngraph TD; A-->B\n```',
      '~~~ mermaid\ngraph TD; A-->B\n~~~',
      '![image](relative.png)',
      'https://example.invalid/preview',
    ]) {
      expect(retain(text), isFalse);
    }
    expect(
      retain('image', {
        'attachments': [<String, dynamic>{}],
      }),
      isFalse,
    );
    expect(retain('card', {'actionMetadata': <String, dynamic>{}}), isFalse);
  });
  testWidgets('nearby reversal reuses rows and long scrolling stays bounded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scroll = RaftTimelineScrollController(
      bottomAnchored: false,
      initial: RaftTimelineAlignment.start,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      scroll.dispose();
    });
    var messages = [
      for (var i = 0; i < 200; i++)
        chat.Message.text(id: '$i', authorId: 'fixture', text: 'row-$i'),
    ];
    final builds = <int, int>{};
    Widget host({int epoch = 0, bool retain = true}) => MaterialApp(
      home: RaftMessageTimeline(
        controller: scroll,
        messages: messages,
        centerIndex: 0,
        epoch: epoch,
        indexOfId: int.tryParse,
        cacheExtent: 0,
        rowRevision: (_) => 0,
        retainRow: (_) => retain,
        rowBuilder: (_, i) {
          builds.update(i, (n) => n + 1, ifAbsent: () => 1);
          return SizedBox(
            height: 100,
            child: Text((messages[i] as chat.TextMessage).text),
          );
        },
        slivers: (history, forward) => [history, forward],
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    scroll.jumpTo(800);
    await tester.pumpAndSettle();
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(builds[0], 1, reason: 'Returning nearby must not remount the row.');
    scroll.jumpTo(800);
    await tester.pumpAndSettle();
    messages = [
      chat.Message.text(id: '0', authorId: 'fixture', text: 'row-0-edited'),
      ...messages.skip(1),
    ];
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('row-0-edited'), findsOneWidget);
    expect(
      builds[0],
      2,
      reason: 'An offscreen edit must replace cached content.',
    );
    for (var offset = 800.0; offset < 16000; offset += 800) {
      scroll.jumpTo(offset);
      await tester.pumpAndSettle();
    }
    expect(
      find.textContaining('row-', skipOffstage: false).evaluate().length,
      lessThanOrEqualTo(29),
    );
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(builds[0], 3, reason: 'Rows outside the bounded cache must retire.');
    scroll.jumpTo(800);
    await tester.pumpAndSettle();
    tester.binding.handleMemoryPressure();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('row-', skipOffstage: false).evaluate().length,
      lessThanOrEqualTo(5),
      reason: 'Memory pressure must release all offscreen retained rows.',
    );
    await tester.pumpWidget(host(epoch: 1, retain: false));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('row-', skipOffstage: false).evaluate().length,
      lessThanOrEqualTo(5),
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
