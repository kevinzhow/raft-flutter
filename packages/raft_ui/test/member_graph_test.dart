import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

RaftGraphMember _m(
  String id, {
  bool agent = false,
  String? name,
  List<String> channels = const [],
}) => RaftGraphMember(
  agent: agent,
  id: id,
  name: id,
  displayName: name,
  channelIds: channels,
);

RaftMemberGraphData _data() => RaftMemberGraphData(
  humans: [
    _m('h1', name: 'Ann', channels: ['c1', 'c2']),
    _m('h2', name: 'Bob', channels: ['c1']),
  ],
  agents: [
    _m('a1', agent: true, name: 'Cindy', channels: ['c1', 'c2']),
  ],
  channels: const [
    RaftGraphChannel(
      id: 'c1',
      name: 'design',
      humanCount: 2,
      agentCount: 1,
      memberCount: 3,
    ),
    RaftGraphChannel(
      id: 'c2',
      name: 'release',
      humanCount: 1,
      agentCount: 1,
      memberCount: 2,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  RaftMemberGraphData? data, {
  bool loading = false,
  String? error,
  VoidCallback? onRefresh,
  Size size = const Size(1300, 900),
  RaftGraphNodeWrapper? wrapper,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: RaftMemberGraphView(
            data: data,
            loading: loading,
            error: error,
            onRefresh: onRefresh ?? () {},
            nodeWrapper: wrapper,
            avatar: (context, member, {required compact}) =>
                ColoredBox(color: member.agent ? Colors.cyan : Colors.purple),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _node(String key) => find.byKey(ValueKey('member-graph-node-$key'));

void main() {
  testWidgets('shows the count, tiles, ranked members and largest channels', (
    tester,
  ) async {
    await _pump(tester, _data());
    expect(
      find.textContaining('Connections', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('3'), findsWidgets); // member count and a tile
    // Humans, Agents and Links tiles (3 humans/agents/links: 2, 1, 3).
    for (final label in ['Humans', 'Agents', 'Links']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Most connected members'), findsOneWidget);
    expect(find.text('Largest channels'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('member-graph-ranked-human:h1')),
      findsOneWidget,
    );
    expect(find.text('design'), findsOneWidget);
    expect(find.text('2H/1A'), findsOneWidget);
    // Ann and Cindy share both channels: three members, three links.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('member-graph-ranked-human:h1')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    for (final key in ['human:h1', 'human:h2', 'agent:a1']) {
      expect(_node(key), findsOneWidget, reason: key);
    }
    expect(find.text('2 links'), findsWidgets);
  });

  testWidgets(
    'wide windows put the lists beside the graph, narrow ones below',
    (tester) async {
      await _pump(tester, _data());
      final wide = tester.getTopLeft(find.text('Most connected members'));
      final canvasWide = tester.getTopLeft(
        find.byKey(const ValueKey('member-graph-canvas')),
      );
      expect(wide.dx, greaterThan(canvasWide.dx + 600));
      await _pump(tester, _data(), size: const Size(700, 1600));
      final narrow = tester.getTopLeft(find.text('Most connected members'));
      final canvasNarrow = tester.getBottomLeft(
        find.byKey(const ValueKey('member-graph-canvas')),
      );
      expect(narrow.dy, greaterThan(canvasNarrow.dy));
      // 360px canvas below md, 520px from md up.
      expect(
        tester
            .getSize(find.byKey(const ValueKey('member-graph-canvas')))
            .height,
        360 + 2 * 1, // 1px border
      );
    },
  );

  testWidgets('no members or channels draws the empty state', (tester) async {
    await _pump(tester, const RaftMemberGraphData());
    expect(find.text('No members or channels to map yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('member-graph-canvas')), findsNothing);
    expect(find.text('No memberships yet.'), findsOneWidget);
    expect(find.text('No visible channels yet.'), findsOneWidget);
  });

  testWidgets('a load error shows above the graph and Refresh reloads', (
    tester,
  ) async {
    var refreshed = 0;
    await _pump(
      tester,
      _data(),
      error: 'Failed to load member graph',
      onRefresh: () => refreshed++,
    );
    expect(find.text('Failed to load member graph'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('member-graph-refresh')));
    expect(refreshed, 1);
    // Loading disables the button.
    await _pump(tester, _data(), loading: true, onRefresh: () => refreshed++);
    await tester.tap(
      find.byKey(const ValueKey('member-graph-refresh')),
      warnIfMissed: false,
    );
    expect(refreshed, 1);
  });

  testWidgets(
    'the wheel zooms about the pointer and drag pans within the extent',
    (tester) async {
      await _pump(tester, _data());
      final canvas = find.byKey(const ValueKey('member-graph-canvas'));
      final before = tester.getCenter(_node('human:h1'));
      final center = tester.getCenter(canvas);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(center);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -300)));
      await tester.pump();
      final zoomed = tester.getCenter(_node('human:h1'));
      expect(zoomed, isNot(before));
      // Zoom in moves a node away from the pointer.
      expect(
        (zoomed - center).distance,
        greaterThan((before - center).distance),
      );
      // Zooming back out past 1 returns to the identity transform.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 3000)));
      await tester.pump();
      expect(tester.getCenter(_node('human:h1')).dx, closeTo(before.dx, 1e-6));
      // Drag at 1x: nothing can move outside the translate extent.
      await tester.drag(canvas, const Offset(80, 40), warnIfMissed: false);
      await tester.pump();
      expect(tester.getCenter(_node('human:h1')).dx, closeTo(before.dx, 1e-6));
      // Zoom in, then drag moves the nodes.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -500)));
      await tester.pump();
      final zoomedAgain = tester.getCenter(_node('human:h1'));
      await tester.drag(canvas, const Offset(-30, 0), warnIfMissed: false);
      await tester.pump();
      expect(tester.getCenter(_node('human:h1')).dx, lessThan(zoomedAgain.dx));
    },
  );

  testWidgets('a double click zooms in by 2x', (tester) async {
    await _pump(tester, _data());
    final canvas = find.byKey(const ValueKey('member-graph-canvas'));
    final center = tester.getCenter(canvas);
    final before = tester.getCenter(_node('human:h1'));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(center);
    await tester.pump();
    final after = tester.getCenter(_node('human:h1'));
    expect(
      (after - center).distance,
      closeTo((before - center).distance * 2, 1.0),
    );
  });

  testWidgets('every node goes through the wrapper (the profile hover card)', (
    tester,
  ) async {
    final wrapped = <String>[];
    await _pump(
      tester,
      _data(),
      wrapper: (context, member, node) {
        wrapped.add(member.key);
        return node;
      },
    );
    expect(wrapped.toSet(), {'human:h1', 'human:h2', 'agent:a1'});
  });

  testWidgets('a large graph lays out in the background and then draws', (
    tester,
  ) async {
    final humans = [
      for (var i = 0; i < 130; i++) _m('h$i', channels: ['c${i % 9}']),
    ];
    final channels = [
      for (var i = 0; i < 9; i++)
        RaftGraphChannel(
          id: 'c$i',
          name: 'room-$i',
          humanCount: 14,
          agentCount: 0,
          memberCount: 14,
        ),
    ];
    await _pump(
      tester,
      RaftMemberGraphData(humans: humans, channels: channels),
    );
    expect(_node('human:h0'), findsNothing);
    for (var i = 0; i < 40 && _node('human:h0').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(_node('human:h0'), findsOneWidget);
  });
}
