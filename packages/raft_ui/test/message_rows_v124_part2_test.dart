import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/markdown_autolink.dart' show raftBareUrls;

/// Web v1.24 message-row details, part 2: the touch time reveal
/// (useTimelineTimeReveal), the outline's headings (shared markdownHeadings),
/// bare URLs (markdownAutolink restoreTrailingUrlMarks /
/// closeEmphasisInsideBareUrls), forwarded task sources and quoted retracted
/// messages.
void main() {
  group('time reveal', () {
    test('the rows follow the finger, then the rubber band, up to 88px', () {
      expect(raftTimeRevealOffset(-5), 0);
      expect(raftTimeRevealOffset(40), 40);
      expect(raftTimeRevealOffset(64), 64);
      expect(raftTimeRevealOffset(84), closeTo(64 + 20 * .55, 1e-9));
      expect(raftTimeRevealOffset(400), 88);
    });

    Future<void> pump(WidgetTester t, {bool disableAnimations = false}) =>
        t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(600, 800),
              disableAnimations: disableAnimations,
            ),
            child: MaterialApp(
              theme: raftTheme(),
              home: Scaffold(
                body: RaftTimelineTimeReveal(
                  child: ListView(
                    children: [
                      for (final (i, time) in ['9:00', '9:01'].indexed)
                        RaftMessageRow(
                          key: ValueKey('row-$i'),
                          author: 'Alice',
                          timestamp: '9:00 AM',
                          continuationTimestamp: time,
                          continuation: i > 0,
                          content: const SizedBox(height: 40, width: 300),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    double rowShift(WidgetTester t) => t
        .widget<Transform>(
          find
              .descendant(
                of: find.byKey(const ValueKey('row-0')),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .getTranslation()
        .x;

    testWidgets('dragging left slides every row and shows its time', (t) async {
      await pump(t);
      final start = t.getCenter(find.byKey(const ValueKey('row-0')));
      final gesture = await t.startGesture(
        start,
        kind: PointerDeviceKind.touch,
      );
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-30, 0));
      await t.pump();
      expect(
        find.byKey(const ValueKey('timeline-reveal-time')),
        findsNWidgets(2),
      );
      expect(find.text('9:01'), findsWidgets);
      expect(rowShift(t), -60);
      await gesture.up();
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      expect(rowShift(t), 0);
      expect(find.byKey(const ValueKey('timeline-reveal-time')), findsNothing);
    });

    testWidgets('a vertical drag, a right drag or the screen edge do nothing', (
      t,
    ) async {
      await pump(t);
      final start = t.getCenter(find.byKey(const ValueKey('row-0')));
      var gesture = await t.startGesture(start, kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(-5, 40));
      await gesture.moveBy(const Offset(-40, 0));
      await t.pump();
      expect(rowShift(t), 0);
      await gesture.up();
      gesture = await t.startGesture(start, kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(60, 0));
      await t.pump();
      expect(rowShift(t), 0);
      await gesture.up();
      gesture = await t.startGesture(
        Offset(590, start.dy),
        kind: PointerDeviceKind.touch,
      );
      await gesture.moveBy(const Offset(-60, 0));
      await t.pump();
      expect(rowShift(t), 0);
      await gesture.up();
    });

    testWidgets('nothing slides with reduced motion, nor for a mouse', (
      t,
    ) async {
      await pump(t, disableAnimations: true);
      final start = t.getCenter(find.byKey(const ValueKey('row-0')));
      final gesture = await t.startGesture(
        start,
        kind: PointerDeviceKind.touch,
      );
      await gesture.moveBy(const Offset(-60, 0));
      await t.pump();
      expect(rowShift(t), 0);
      await gesture.up();
      await pump(t);
      final mouse = await t.startGesture(start, kind: PointerDeviceKind.mouse);
      await mouse.moveBy(const Offset(-60, 0));
      await t.pump();
      expect(rowShift(t), 0);
      await mouse.up();
    });
  });

  group('outline headings', () {
    test('setext headings count, with their start line', () {
      final outline = raftExtractMarkdownOutline(
        'Intro text\n\nTitle\n=====\n\nSub one\nline two\n---\n\n## `code` and *em*\n',
      );
      expect(
        [for (final h in outline) (h.level, h.sourceLine, h.title)],
        [(1, 3, 'Title'), (2, 6, 'Sub one line two'), (2, 10, 'code and em')],
      );
    });

    test('code fences and a rule are no headings; escapes stay', () {
      final outline = raftExtractMarkdownOutline(
        '```\n# not\n```\n\n---\n\n# A \\*star\\* [link](https://x.y) ##\n',
      );
      expect(outline.map((h) => h.title), ['A *star* link']);
    });
  });

  group('bare URLs', () {
    test('a trailing _ or ~ that closes nothing stays in the address', () {
      expect(
        raftBareUrls('login: https://x.com/?state=Ab_').single.href,
        'https://x.com/?state=Ab_',
      );
      // `_https://x.com_` is emphasis: the mark opened before the URL.
      expect(raftBareUrls('_https://x.com_').single.href, 'https://x.com');
    });

    test('a mark that closes one opened before the URL ends it', () {
      expect(raftBareUrls('**https://x.com**说明').single.href, 'https://x.com');
      expect(
        raftBareUrls('see https://x.com/a**b').single.href,
        'https://x.com/a**b',
      );
    });
  });

  testWidgets('a forwarded task discussion names the task', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftForwardedBundle(
            metadata: {
              'kind': 'forwarded-bundle',
              'version': 1,
              'forwardedItems': [
                {
                  'index': 0,
                  'contentSnapshot': 'Done',
                  'sourceAuthorSnapshot': {'type': 'agent', 'name': 'Kirby'},
                  'provenanceState': 'available',
                  'sourceTaskTitle': 'Ship the Android build',
                  'sourceTargetSnapshot': {
                    'type': 'task',
                    'label': '#android:#7',
                    'labelVisibility': 'public',
                  },
                },
              ],
            },
          ),
        ),
      ),
    );
    expect(
      find.text('from #android:#7 · Ship the Android build'),
      findsOneWidget,
    );
  });

  testWidgets('a retracted message is quoted as one muted line', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(
          body: RaftQuotedMessageCard(
            channelName: 'general',
            timestamp: 'Nov 1 · 9:00',
            authorName: 'Carol',
            avatar: SizedBox.square(dimension: 16),
            content: 'old words',
            authorDelegatedBy: '(sent by Friday)',
            unavailableText: 'This message was retracted.',
          ),
        ),
      ),
    );
    expect(find.text('This message was retracted.'), findsOneWidget);
    expect(find.textContaining('old words', findRichText: true), findsNothing);
  });
}
