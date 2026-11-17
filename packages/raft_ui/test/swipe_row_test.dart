import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

class _Harness extends StatefulWidget {
  const _Harness({
    this.enabled = true,
    this.rows = 1,
    this.log,
    this.fullKeep = false,
    this.leading = true,
  });
  final bool enabled, fullKeep, leading;
  final int rows;
  final List<String>? log;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  RaftSwipeEdge? open;
  int? openRow;
  final removed = <int>{};
  List<String> get log => widget.log ?? [];

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('list'),
    children: [
      for (var i = 0; i < widget.rows; i++)
        if (!removed.contains(i))
          RaftSwipeRow(
            key: Key('row$i'),
            enabled: widget.enabled,
            open: openRow == i ? open : null,
            onOpenChange: (e) => setState(() {
              open = e;
              openRow = e == null ? null : i;
              log.add('open:${e?.name}');
            }),
            leading: widget.leading
                ? RaftSwipeActions(
                    full: widget.fullKeep
                        ? RaftSwipeFull.keep
                        : RaftSwipeFull.remove,
                    actions: [
                      RaftSwipeAction(
                        label: 'Read',
                        glyph: RaftGlyph.messageSquareCheck,
                        onPressed: () => log.add('read$i'),
                      ),
                    ],
                  )
                : null,
            trailing: RaftSwipeActions(
              actions: [
                RaftSwipeAction(
                  buttonKey: Key('done$i'),
                  label: 'Done',
                  glyph: RaftGlyph.checkCircle2,
                  tone: RaftSwipeActionTone.success,
                  onPressed: () {
                    log.add('done$i');
                    setState(() => removed.add(i));
                  },
                ),
                RaftSwipeAction(
                  buttonKey: Key('mute$i'),
                  label: 'Mute',
                  glyph: RaftGlyph.bellOff,
                  onPressed: () => log.add('mute$i'),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () => log.add('tap$i'),
              child: Container(
                key: Key('content$i'),
                height: 64,
                color: Colors.white,
                alignment: Alignment.centerLeft,
                child: Text('Row $i'),
              ),
            ),
          ),
    ],
  );
}

Future<void> _pump(
  WidgetTester t,
  Widget body, {
  bool dark = false,
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.android,
}) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Scaffold(body: body),
    ),
  );
}

int _clock = 1000;

/// A stroke with explicit, increasing timestamps: each step takes [stepMs]
/// (150: slow, no flick; 10: a flick).
Future<void> _swipe(
  WidgetTester t,
  Offset from,
  List<double> dxs, {
  double dy = 0,
  int stepMs = 150,
  PointerDeviceKind kind = PointerDeviceKind.touch,
  bool lift = true,
}) async {
  final g = await t.createGesture(kind: kind);
  await g.down(from, timeStamp: Duration(milliseconds: _clock));
  for (final dx in dxs) {
    _clock += stepMs;
    await g.moveBy(Offset(dx, dy), timeStamp: Duration(milliseconds: _clock));
  }
  _clock += 5;
  if (lift) await g.up(timeStamp: Duration(milliseconds: _clock));
  await t.pumpAndSettle();
}

double _x(WidgetTester t, String key) => t.getTopLeft(find.byKey(Key(key))).dx;

void main() {
  group('pure rules', () {
    test('decision follows Web rowSwipeDecision', () {
      expect(raftSwipeDecision(-12, 0), RaftSwipeDecision.undecided);
      expect(raftSwipeDecision(-20, 5), RaftSwipeDecision.claim);
      expect(raftSwipeDecision(-20, 10), RaftSwipeDecision.release);
      expect(raftSwipeDecision(-4, 12), RaftSwipeDecision.release);
      expect(raftSwipeDecision(20, 0), RaftSwipeDecision.release);
      expect(raftSwipeDecision(20, 0, right: true), RaftSwipeDecision.claim);
      expect(
        raftSwipeDecision(-30, 0, startsInEdgeZone: true),
        RaftSwipeDecision.release,
      );
      expect(
        raftSwipeDecision(-5, 0, startsInEdgeZone: true),
        RaftSwipeDecision.undecided,
      );
    });
    test('release follows Web rowSwipeRelease', () {
      expect(raftSwipeRelease(250, 0, 390, 144), RaftSwipeRelease.full);
      expect(raftSwipeRelease(80, 0, 390, 144), RaftSwipeRelease.open);
      expect(raftSwipeRelease(60, 0, 390, 144), RaftSwipeRelease.close);
      expect(raftSwipeRelease(20, 900, 390, 144), RaftSwipeRelease.open);
      expect(raftSwipeRelease(100, -900, 390, 144), RaftSwipeRelease.close);
      expect(raftSwipeRelease(0, 0, 390, 144), RaftSwipeRelease.close);
    });
  });

  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('$mode: a left swipe past half the buttons rests open', (
      t,
    ) async {
      final log = <String>[];
      await _pump(t, _Harness(log: log), dark: dark);
      await _swipe(t, const Offset(300, 32), [-30, -80]);
      expect(_x(t, 'content0'), -144);
      expect(log.last, 'open:end');
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Mute'), findsOneWidget);
      final ui = RaftTokens.of(t.element(find.byType(RaftSwipeRow))).ui;
      final done = t.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('done0')),
          matching: find.byType(Container),
        ),
      );
      final mute = t.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('mute0')),
          matching: find.byType(Container),
        ),
      );
      expect(done.color, ui.success);
      expect(mute.color, ui.fillMuted);
    });
  }

  testWidgets('swipe past the full point removes the row and runs Done', (
    t,
  ) async {
    final log = <String>[];
    await _pump(t, _Harness(log: log, rows: 2));
    await _swipe(t, const Offset(340, 32), [-30, -250]);
    expect(log, contains('done0'));
    expect(find.byKey(const Key('row0')), findsNothing);
    expect(find.byKey(const Key('row1')), findsOneWidget);
    expect(_x(t, 'content1'), 0);
  });

  testWidgets('full is a distance: a fast flick short of 60% only opens', (
    t,
  ) async {
    final log = <String>[];
    await _pump(t, _Harness(log: log));
    await _swipe(t, const Offset(340, 32), [-30, -60, -40], stepMs: 10);
    expect(log, isNot(contains('done0')));
    expect(_x(t, 'content0'), -144);
  });

  testWidgets('right swipe full with keep slides back and runs Read', (
    t,
  ) async {
    final log = <String>[];
    await _pump(t, _Harness(log: log, fullKeep: true));
    await _swipe(t, const Offset(40, 32), [30, 250]);
    expect(log, contains('read0'));
    expect(find.byKey(const Key('row0')), findsOneWidget);
    expect(_x(t, 'content0'), 0);
  });

  testWidgets('a short right pull on the one-button side springs back', (
    t,
  ) async {
    await _pump(t, const _Harness());
    await _swipe(t, const Offset(40, 32), [30, 30]);
    expect(_x(t, 'content0'), 0);
  });

  testWidgets('no leading actions: a right swipe is released', (t) async {
    final log = <String>[];
    await _pump(t, _Harness(log: log, leading: false));
    await _swipe(t, const Offset(100, 32), [30, 80]);
    expect(_x(t, 'content0'), 0);
    expect(log, isEmpty);
  });

  testWidgets('a vertical stroke in a ListView scrolls and never claims', (
    t,
  ) async {
    final log = <String>[];
    await _pump(t, _Harness(log: log, rows: 30));
    final g = await t.createGesture();
    await g.down(const Offset(300, 300));
    await g.moveBy(const Offset(-6, -14));
    await g.moveBy(const Offset(-10, -60));
    await g.moveBy(const Offset(-10, -60));
    await g.up();
    await t.pumpAndSettle();
    final pos = t
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(pos.pixels, greaterThan(0));
    expect(_x(t, 'content0'), 0);
    expect(log, isEmpty);
  });

  testWidgets('a stroke that turns vertical after the slop scrolls', (t) async {
    await _pump(t, _Harness(rows: 30));
    final g = await t.createGesture();
    await g.down(const Offset(300, 300));
    await g.moveBy(const Offset(-8, 0));
    await g.moveBy(const Offset(-4, -24));
    await g.moveBy(const Offset(-60, -40));
    await g.up();
    await t.pumpAndSettle();
    final pos = t
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(pos.pixels, greaterThan(0));
    expect(_x(t, 'content0'), 0);
  });

  testWidgets('a clear sideways stroke claims and the list does not scroll', (
    t,
  ) async {
    await _pump(t, _Harness(rows: 30));
    await _swipe(t, const Offset(300, 300), [-25, -80], dy: -10);
    final pos = t
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(pos.pixels, 0);
    expect(_x(t, 'content4'), lessThan(0));
  });

  testWidgets('a stroke starting in the 24px edge zone is never claimed', (
    t,
  ) async {
    await _pump(t, const _Harness());
    await _swipe(t, const Offset(380, 32), [-30, -110]);
    expect(_x(t, 'content0'), 0);
    await _swipe(t, const Offset(8, 32), [30, 110]);
    expect(_x(t, 'content0'), 0);
    // Just outside the zone claims.
    await _swipe(t, const Offset(360, 32), [-30, -110]);
    expect(_x(t, 'content0'), lessThan(0));
  });

  testWidgets('a short pull springs back; a fast flick opens', (t) async {
    final log = <String>[];
    await _pump(t, _Harness(log: log));
    await _swipe(t, const Offset(300, 32), [-25, -20]);
    expect(_x(t, 'content0'), 0);
    expect(log.last, 'open:null');
    // 20px after the claim, over 20ms: 1000px/s, so it opens.
    await _swipe(t, const Offset(300, 32), [-25, -20], stepMs: 10);
    expect(_x(t, 'content0'), -144);
    expect(log.last, 'open:end');
  });

  testWidgets('open row: tap on content closes it and does nothing else', (
    t,
  ) async {
    final log = <String>[];
    await _pump(t, _Harness(log: log));
    await _swipe(t, const Offset(300, 32), [-30, -90]);
    expect(_x(t, 'content0'), lessThan(0));
    log.clear();
    await t.tapAt(const Offset(30, 32));
    await t.pumpAndSettle();
    expect(log, ['open:null']);
    expect(_x(t, 'content0'), 0);
    // Closed: the content gets its tap again.
    await t.tapAt(const Offset(30, 32));
    expect(log.last, 'tap0');
  });

  testWidgets('tap on a button runs it and closes the row', (t) async {
    final log = <String>[];
    await _pump(t, _Harness(log: log, rows: 2));
    await _swipe(t, const Offset(300, 32), [-30, -120]);
    log.clear();
    await t.tap(find.byKey(const Key('mute0')));
    await t.pumpAndSettle();
    expect(log, ['mute0', 'open:null']);
    expect(_x(t, 'content0'), 0);
  });

  testWidgets('opening another row closes the first (parent owns open)', (
    t,
  ) async {
    await _pump(t, _Harness(rows: 2));
    await _swipe(t, const Offset(300, 32), [-30, -120]);
    await _swipe(t, const Offset(300, 96), [-30, -120]);
    expect(_x(t, 'content0'), 0);
    expect(_x(t, 'content1'), lessThan(0));
  });

  testWidgets('crossing into full ticks on each entry, on Android', (t) async {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (c) async {
        if (c.method == 'HapticFeedback.vibrate') calls.add('${c.arguments}');
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(t, const _Harness());
    // claim, into full, further (no tick), back out, in again.
    await _swipe(t, const Offset(340, 32), [-30, -240, -5, 60, -60]);
    expect(calls, hasLength(2));
  });

  testWidgets('no tick off Android', (t) async {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (c) async {
        if (c.method == 'HapticFeedback.vibrate') calls.add('${c.arguments}');
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(t, const _Harness(), platform: TargetPlatform.iOS);
    await _swipe(t, const Offset(340, 32), [-30, -240]);
    expect(calls, isEmpty);
  });

  testWidgets('semantics: actions are reachable without swiping', (t) async {
    final handle = t.ensureSemantics();
    final log = <String>[];
    await _pump(t, _Harness(log: log));
    final node = t.getSemantics(find.byType(RaftSwipeRow));
    final ids = node.getSemanticsData().customSemanticsActionIds!;
    final labels = ids
        .map((id) => CustomSemanticsAction.getAction(id)!.label)
        .toList();
    expect(labels, containsAll(['Read', 'Done', 'Mute']));
    final done = ids.firstWhere(
      (id) => CustomSemanticsAction.getAction(id)!.label == 'Done',
    );
    t.binding.renderViews.first.owner!.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.customAction,
      done,
    );
    await t.pumpAndSettle();
    expect(log, contains('done0'));
    handle.dispose();
  });

  testWidgets('disabled row exposes no swipe and no semantics actions', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await _pump(t, const _Harness(enabled: false));
    await _swipe(t, const Offset(300, 32), [-30, -120]);
    expect(_x(t, 'content0'), 0);
    final ids = t
        .getSemantics(find.byType(RaftSwipeRow))
        .getSemanticsData()
        .customSemanticsActionIds;
    expect(ids ?? const <int>[], isEmpty);
    handle.dispose();
  });

  for (final c in [
    ('Android fold 856x944', const Size(856, 944)),
    ('Android fold 944x856', const Size(944, 856)),
  ]) {
    testWidgets('${c.$1}: touch swipes when enabled, a mouse never drags', (
      t,
    ) async {
      await _pump(t, const _Harness(), size: c.$2);
      final w = c.$2.width;
      await _swipe(t, Offset(w - 90, 32), [
        -30,
        -120,
      ], kind: PointerDeviceKind.mouse);
      expect(_x(t, 'content0'), 0);
      await _swipe(t, Offset(w - 90, 32), [-30, -120]);
      expect(_x(t, 'content0'), lessThan(0));
    });
  }

  testWidgets('390x844 Linux mouse: the row does not swipe', (t) async {
    // The app's gate: compact width and touch, from RaftInteraction.
    await _pump(
      t,
      Builder(
        builder: (context) => _Harness(
          enabled:
              MediaQuery.sizeOf(context).width < 768 &&
              RaftInteraction.of(context).touch,
        ),
      ),
      platform: TargetPlatform.linux,
    );
    await _swipe(t, const Offset(300, 32), [
      -30,
      -120,
    ], kind: PointerDeviceKind.mouse);
    expect(_x(t, 'content0'), 0);
    // Even enabled, a mouse never drags on a narrow desktop window.
    await _pump(t, const _Harness(), platform: TargetPlatform.linux);
    await _swipe(t, const Offset(300, 32), [
      -30,
      -120,
    ], kind: PointerDeviceKind.mouse);
    expect(_x(t, 'content0'), 0);
  });

  testWidgets('reduced motion jumps instead of sliding', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: _Harness()),
      ),
    );
    final g = await t.createGesture();
    await g.down(
      const Offset(300, 32),
      timeStamp: Duration(milliseconds: _clock),
    );
    await g.moveBy(
      const Offset(-30, 0),
      timeStamp: Duration(milliseconds: _clock += 150),
    );
    await g.moveBy(
      const Offset(-90, 0),
      timeStamp: Duration(milliseconds: _clock += 150),
    );
    await g.up(timeStamp: Duration(milliseconds: _clock += 5));
    await t.pump();
    expect(_x(t, 'content0'), -144);
  });
}
