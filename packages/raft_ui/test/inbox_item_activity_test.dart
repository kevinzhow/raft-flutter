import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web v1.24 Activity row additions to RaftInboxItem (rest time, time tooltip,
// task status in the marks, row menu hooks, Up/Down between rows, located,
// screen-reader action) and the Done button, at the sizes AGENTS.md names:
// 1440 and 390 with a mouse (Linux), 856x944 and 944x856 with touch (Android).
const _sizes = [
  ('linux 1440x900', Size(1440, 900), TargetPlatform.linux),
  ('linux 390x844', Size(390, 844), TargetPlatform.linux),
  ('android 856x944', Size(856, 944), TargetPlatform.android),
  ('android 944x856', Size(944, 856), TargetPlatform.android),
];

Future<void> _pump(
  WidgetTester tester,
  Size size,
  TargetPlatform platform,
  Widget child, {
  bool dark = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

RaftInboxItem _row({
  Key? key,
  String title = 'Release notes',
  bool atRest = false,
  String? tooltip,
  bool located = false,
  List<Widget> marks = const [],
  List<Widget> actions = const [],
  ValueChanged<Offset>? onLongPress,
  ValueChanged<Offset>? onSecondaryTap,
  Map<String, VoidCallback> semanticActions = const {},
  VoidCallback? onOpen,
  FocusNode? focusNode,
}) => RaftInboxItem(
  key: key,
  semanticLabel: title,
  onOpen: onOpen ?? () {},
  leading: const Icon(Icons.inbox, size: 18),
  title: Text(title),
  timestamp: const Text('3m'),
  timestampAtRest: atRest,
  timestampTooltip: tooltip,
  body: const Text('Draft is in the launch channel'),
  marks: marks,
  actions: actions,
  located: located,
  onLongPress: onLongPress,
  onSecondaryTap: onSecondaryTap,
  semanticActions: semanticActions,
  focusNode: focusNode,
);

Finder get _time => find.byKey(const ValueKey('inbox-item-timestamp'));
Finder get _trigger => find.byKey(const ValueKey('inbox-item-open'));

Future<TestGesture> _hover(WidgetTester tester, Finder at) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(at));
  await tester.pump();
  return gesture;
}

void main() {
  for (final (name, size, platform) in _sizes) {
    final touch = platform == TargetPlatform.android;

    group(name, () {
      testWidgets('timestamp rests visible only when asked; reveal otherwise', (
        tester,
      ) async {
        await _pump(tester, size, platform, _row(atRest: true));
        expect(_time, findsOneWidget, reason: 'short time shows at rest');
        await _pump(tester, size, platform, _row());
        expect(_time, findsNothing, reason: 'an older row hides its clock');
        if (!touch) {
          await _hover(tester, _trigger);
          expect(_time, findsOneWidget);
        }
      });

      testWidgets('timestamp tooltip is mouse only', (tester) async {
        await _pump(
          tester,
          size,
          platform,
          _row(atRest: true, tooltip: 'Today at 5:20 PM'),
        );
        final tip = tester.widget<RaftTooltip>(
          find.ancestor(of: _time, matching: find.byType(RaftTooltip)).first,
        );
        expect(tip.message, 'Today at 5:20 PM');
        expect(tip.enabled, !touch);
      });

      testWidgets('task status: word, or its pixel under 320 with a tooltip', (
        tester,
      ) async {
        Widget status() => const RaftInboxItemStatus(
          status: RaftMessageTaskStatus.inProgress,
          label: 'In progress',
        );
        await _pump(tester, size, platform, _row(marks: [status()]));
        final wide = size.width > 320;
        expect(
          find.byKey(const ValueKey('inbox-item-status-word')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('inbox-item-status-pixel')),
          findsNothing,
        );
        expect(wide, isTrue);
        await _pump(
          tester,
          size,
          platform,
          SizedBox(width: 300, child: _row(marks: [status()])),
        );
        expect(
          find.byKey(const ValueKey('inbox-item-status-pixel')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<RaftTooltip>(
                find.ancestor(
                  of: find.byKey(const ValueKey('inbox-item-status-pixel')),
                  matching: find.byType(RaftTooltip),
                ),
              )
              .message,
          'In progress',
        );
      });

      testWidgets('long press and right click report where they landed', (
        tester,
      ) async {
        Offset? pressed, secondary;
        await _pump(
          tester,
          size,
          platform,
          _row(
            onLongPress: (p) => pressed = p,
            onSecondaryTap: (p) => secondary = p,
          ),
        );
        final at = tester.getTopLeft(_trigger) + const Offset(120, 20);
        await tester.longPressAt(at);
        await tester.pump();
        expect(pressed, at);
        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await mouse.addPointer(location: at);
        await mouse.down(at);
        await mouse.up();
        await tester.pump();
        expect(secondary, at);
      });

      testWidgets('Up and Down move between row triggers across groups', (
        tester,
      ) async {
        final nodes = List.generate(3, (_) => FocusNode());
        addTearDown(() {
          for (final n in nodes) {
            n.dispose();
          }
        });
        final done = FocusNode();
        addTearDown(done.dispose);
        final seen = <LogicalKeyboardKey>[];
        await _pump(
          tester,
          size,
          platform,
          Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) seen.add(event.logicalKey);
              return KeyEventResult.ignored;
            },
            child: Column(
              children: [
                RaftInboxItemListGroup(
                  heading: 'Today',
                  first: true,
                  children: [
                    _row(title: 'A', focusNode: nodes[0]),
                    _row(
                      title: 'B',
                      focusNode: nodes[1],
                      actions: [
                        Focus(
                          focusNode: done,
                          child: const SizedBox(width: 30, height: 30),
                        ),
                      ],
                    ),
                  ],
                ),
                RaftInboxItemListGroup(
                  heading: 'Yesterday',
                  children: [_row(title: 'C', focusNode: nodes[2])],
                ),
              ],
            ),
          ),
        );
        nodes[1].requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(nodes[2].hasPrimaryFocus, isTrue, reason: 'across day groups');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(nodes[2].hasPrimaryFocus, isTrue, reason: 'stops at the end');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(nodes[0].hasPrimaryFocus, isTrue);
        expect(seen, isEmpty, reason: 'the row took every plain arrow');
        // With a modifier the key is not the row's: it bubbles on.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(seen, contains(LogicalKeyboardKey.arrowDown));
        seen.clear();
        // From an action inside the row the arrows are not the row's either.
        done.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(seen, contains(LogicalKeyboardKey.arrowDown));
      });

      testWidgets('located washes the row info-soft, then fades out by 2 s', (
        tester,
      ) async {
        Widget host(bool located) => _row(located: located);
        await _pump(tester, size, platform, host(false));
        final located = find.byKey(const ValueKey('inbox-item-located'));
        expect(located, findsNothing);
        await _pump(tester, size, platform, host(true), settle: false);
        Color? wash() {
          final box = find
              .descendant(of: located, matching: find.byType(DecoratedBox))
              .first;
          return ((tester.widget<DecoratedBox>(box)).decoration
                  as BoxDecoration)
              .color;
        }

        expect(located, findsOneWidget);
        final full = wash()!;
        expect(full.a, greaterThan(0));
        await tester.pump(const Duration(milliseconds: 1000));
        expect(wash()!.a, full.a, reason: 'held to 1.2 s');
        await tester.pump(const Duration(milliseconds: 600));
        expect(wash()!.a, lessThan(full.a));
        await tester.pump(const Duration(milliseconds: 500));
        expect(wash()!.a, 0);
      });

      testWidgets('semanticActions are screen-reader actions on the trigger', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        var done = 0;
        await _pump(
          tester,
          size,
          platform,
          _row(semanticActions: {'Mark Release notes as Done': () => done++}),
        );
        final node = tester.getSemantics(
          find.bySemanticsLabel('Release notes'),
        );
        final data = node.getSemanticsData();
        expect(data.customSemanticsActionIds, isNotNull);
        final action = CustomSemanticsAction.getAction(
          data.customSemanticsActionIds!.single,
        )!;
        expect(action.label, 'Mark Release notes as Done');
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.hasAction(SemanticsAction.customAction), isTrue);
        tester.binding.performSemanticsAction(
          SemanticsActionEvent(
            type: SemanticsAction.customAction,
            viewId: tester.view.viewId,
            nodeId: node.id,
            arguments: data.customSemanticsActionIds!.single,
          ),
        );
        expect(done, 1);
        handle.dispose();
      });

      testWidgets('RaftInboxRowDone: mouse ghost with tooltip, touch outline', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        await _pump(
          tester,
          size,
          platform,
          _row(
            actions: [
              RaftInboxRowDone(
                semanticLabel: 'Mark #launch-week as Done',
                tooltip: 'Mark as Done',
                onPressed: () => taps++,
              ),
            ],
          ),
        );
        final key = ValueKey(touch ? 'inbox-row-done-touch' : 'inbox-row-done');
        final button = find.byKey(key);
        expect(button, findsOneWidget);
        expect(
          find.byKey(
            ValueKey(touch ? 'inbox-row-done' : 'inbox-row-done-touch'),
          ),
          findsNothing,
        );
        final box = tester.getSize(
          find
              .descendant(of: button, matching: find.byType(DecoratedBox))
              .first,
        );
        // Mouse from 768: the 28px bar button; narrow mouse and touch: 32.
        expect(box.width, !touch && size.width >= 768 ? 28 : 32);
        expect(
          find.bySemanticsLabel(RegExp('Mark #launch-week as Done')),
          findsWidgets,
        );
        final tips = find.descendant(
          of: button,
          matching: find.byType(RaftTooltip),
        );
        if (touch) {
          expect(tips, findsNothing);
          expect(
            find.byWidgetPredicate(
              (w) => w is RaftTooltip && w.message == 'Mark as Done',
            ),
            findsNothing,
          );
        } else {
          expect(
            find.byWidgetPredicate(
              (w) => w is RaftTooltip && w.message == 'Mark as Done',
            ),
            findsOneWidget,
          );
          // Revealed with the row: hover shows it, rest hides it.
          final opacity = find.ancestor(
            of: find.byKey(const ValueKey('inbox-item-actions')),
            matching: find.byType(AnimatedOpacity),
          );
          expect(tester.widget<AnimatedOpacity>(opacity.first).opacity, 0);
          await _hover(tester, _trigger);
          await tester.pumpAndSettle();
          expect(tester.widget<AnimatedOpacity>(opacity.first).opacity, 1);
        }
        if (touch) {
          expect(
            tester
                .widget<AnimatedOpacity>(
                  find
                      .ancestor(
                        of: find.byKey(const ValueKey('inbox-item-actions')),
                        matching: find.byType(AnimatedOpacity),
                      )
                      .first,
                )
                .opacity,
            1,
            reason: 'always visible on touch',
          );
        }
        await tester.tap(button);
        await tester.pump();
        expect(taps, 1);
        handle.dispose();
      });
    });
  }

  testWidgets('dark theme: located and Done still paint', (tester) async {
    await _pump(
      tester,
      _sizes[0].$2,
      _sizes[0].$3,
      _row(
        located: true,
        actions: [
          RaftInboxRowDone(
            semanticLabel: 'Mark x as Done',
            tooltip: 'Mark as Done',
            onPressed: () {},
          ),
        ],
      ),
      dark: true,
    );
    expect(find.byKey(const ValueKey('inbox-item-located')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-row-done')), findsOneWidget);
  });
}
