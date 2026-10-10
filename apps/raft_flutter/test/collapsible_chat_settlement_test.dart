import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

class _Mounts {
  final counts = <String, int>{};
  final live = <String>{};
  var disposed = 0;
  void mount(String id) {
    counts.update(id, (n) => n + 1, ifAbsent: () => 1);
    live.add(id);
  }

  void unmount(String id) {
    disposed++;
    live.remove(id);
  }
}

class _MountProbe extends StatefulWidget {
  const _MountProbe({
    super.key,
    required this.id,
    required this.stats,
    required this.child,
  });
  final String id;
  final _Mounts stats;
  final Widget child;
  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.stats.mount(widget.id);
  }

  @override
  void dispose() {
    widget.stats.unmount(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

const _heights = [24.0, 700.0, 70.0, 2400.0, 321.0, 4000.0];
String _markdown(int index) {
  if (index % 6 == 0) return 'Short message $index';
  final count = [1, 16, 2, 48, 8, 80][index % 6];
  return '${List.generate(count, (i) => '**Paragraph $i.** Message fixture with code `value` and a link [details](https://example.invalid).').join('\n\n')}\n\n'
      '```dart\nfinal fixture = $index;\n```\n\n'
      '```mermaid\nflowchart LR\nA[Draft] --> B[Review]\nB --> C[Ship]\n```';
}

List<core.Message> _messages(int rotation) => List.generate(
  48,
  (index) => core.Message.custom(
    id: 'row-$index',
    authorId: 'fixture',
    metadata: {
      'fixtureIndex': index,
      'height': _heights[(index + rotation) % _heights.length],
    },
  ),
);

Widget _host(
  List<core.Message> messages,
  RaftTimelineScrollController viewport,
  _Mounts stats, {
  required bool rich,
  double? cacheExtent,
  bool sourceComposition = false,
}) {
  final index = {for (var i = 0; i < messages.length; i++) messages[i].id: i};
  Widget row(BuildContext context, int i) {
    final message = messages[i];
    return _MountProbe(
      key: ValueKey('probe-${message.id}'),
      id: message.id,
      stats: stats,
      child: RaftMessageTile(
        key: ValueKey('tile-${message.id}'),
        author: 'Fixture ${message.id}',
        timestamp: '12:00',
        content: rich ? _markdown(i) : 'Deterministic geometry fixture',
        body: rich
            ? RaftMessageBody(content: _markdown(i))
            : SizedBox(
                height: (message.metadata!['height'] as num).toDouble(),
                child: Text('Natural ${message.id}'),
              ),
      ),
    );
  }

  const header = SliverToBoxAdapter(
    child: SizedBox(height: 32, child: Text('Load earlier')),
  );
  return MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: 500,
          child: RaftMessageTimeline(
            controller: viewport,
            messages: messages,
            // Opened at its latest end: every row is history.
            centerIndex: messages.length,
            epoch: 0,
            indexOfId: (id) => index[id],
            rowBuilder: row,
            cacheExtent: cacheExtent,
            slivers: sourceComposition
                ? (history, forward) =>
                      const RaftTimelineCompositionRecipe().centeredSlivers(
                        header: [header],
                        history: history,
                        forward: forward,
                        footer: const RaftTimelineFooter(),
                      )
                : (history, forward) => [header, history, forward],
          ),
        ),
      ),
    ),
  );
}

Map<String, Object?> _receipt(ScrollController viewport, _Mounts stats) => {
  'pixels': viewport.hasClients ? viewport.position.pixels : null,
  'max': viewport.hasClients ? viewport.position.maxScrollExtent : null,
  'liveIds': stats.live.toList()..sort(),
  'mounts': Map<String, int>.of(stats.counts),
  'disposals': stats.disposed,
};

Future<List<Map<String, Object?>>> _settle(
  WidgetTester tester,
  ScrollController viewport,
  _Mounts stats,
) async {
  final trace = <Map<String, Object?>>[];
  // A first frame-free gap is not idle. Within the unchanged180-frame budget,
  // require20 consecutive frame-free, geometrically unchanged observations.
  await tester.pump(const Duration(milliseconds: 300));
  var quietFrames = 0;
  var previous = _receipt(viewport, stats);
  for (var i = 0; i < 180 && quietFrames < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final next = _receipt(viewport, stats);
    trace.add(next);
    final unchanged = jsonEncode(next) == jsonEncode(previous);
    quietFrames = !tester.binding.hasScheduledFrame && unchanged
        ? quietFrames + 1
        : 0;
    previous = next;
  }
  final diagnostic = jsonEncode(
    trace.skip(trace.length > 12 ? trace.length - 12 : 0).toList(),
  );
  debugPrint('COLLAPSE_CHAT_TRACE $diagnostic');
  expect(
    quietFrames,
    20,
    reason:
        'The timeline must reach 20 consecutive idle frames within 180 observed frames: $diagnostic',
  );
  expect(tester.binding.hasScheduledFrame, isFalse);
  expect(tester.takeException(), isNull);
  return trace;
}

void main() {
  for (final sourceComposition in [false, true]) {
    for (final (atEnd, rich, rotation, largeCache) in [
      (true, false, 0, false),
      (true, false, 2, false),
      (true, false, 4, false),
      (false, false, 0, false),
      (true, true, 0, false),
      (false, true, 0, false),
      // Diagnostic control only: never use expanded cache as the product repair.
      (true, false, 0, true),
    ]) {
      testWidgets(
        'actual mixed timeline settles atEnd=$atEnd rich=$rich rotation=$rotation largeCache=$largeCache composition=$sourceComposition',
        (tester) async {
          final original = _messages(rotation);
          final viewport = RaftTimelineScrollController(
            bottomAnchored: true,
            initial: atEnd
                ? RaftTimelineAlignment.end
                : RaftTimelineAlignment.start,
          );
          final stats = _Mounts();
          await tester.pumpWidget(
            _host(
              original,
              viewport,
              stats,
              rich: rich,
              sourceComposition: sourceComposition,
              cacheExtent: largeCache ? 100000 : null,
            ),
          );
          // Record the initial frame without failing early: the jump/none traces
          // must still distinguish settlement from the separate first-layout rule.
          final firstClipSizes = find
              .byType(RaftCollapsible)
              .evaluate()
              .map(
                (element) => tester
                    .getSize(
                      find
                          .descendant(
                            of: find.byWidget(element.widget),
                            matching: find.byType(ClipRect),
                          )
                          .first,
                    )
                    .height,
              )
              .toList();
          await _settle(tester, viewport, stats);
          expect(viewport.position.pixels.isFinite, isTrue);
          expect(
            viewport.position.pixels,
            inInclusiveRange(
              viewport.position.minScrollExtent,
              viewport.position.maxScrollExtent,
            ),
          );
          if (atEnd) {
            expect(find.text('Fixture row-47').hitTestable(), findsOneWidget);
          } else {
            expect(viewport.position.pixels, viewport.position.minScrollExtent);
            expect(find.text('Fixture row-0').hitTestable(), findsOneWidget);
          }
          // A successful fixed-content settlement is not enough: source pending
          // content is capped during the actual first layout as well.
          expect(firstClipSizes, isNotEmpty);
          expect(
            firstClipSizes.every((height) => height <= 320),
            isTrue,
            reason: 'Initial clip sizes: $firstClipSizes',
          );
          if (!largeCache) {
            final before = Set<String>.of(stats.live);
            viewport.jumpTo(
              atEnd
                  ? viewport.position.minScrollExtent
                  : viewport.position.maxScrollExtent,
            );
            await _settle(tester, viewport, stats);
            expect(stats.disposed, greaterThan(0));
            expect(
              stats.live.difference(before),
              isNotEmpty,
              reason:
                  'Must actually recycle multiple rows, not retain one child',
            );
            final scrollable = find
                .descendant(
                  of: find.byType(RaftMessageTimeline),
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.scrollUntilVisible(
              find.text('Fixture row-47'),
              300,
              scrollable: scrollable,
              maxScrolls: 100,
            );
            await _settle(tester, viewport, stats);
            expect(find.text('Fixture row-47').hitTestable(), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 300));
          expect(stats.live, isEmpty);
          viewport.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
