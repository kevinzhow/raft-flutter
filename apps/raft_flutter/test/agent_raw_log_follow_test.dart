// Web v1.24 AgentActivityLog.tsx `RawActivityLog` with useFollowNewest.ts:
// the raw log opens at the newest step, follows it while the end is in view,
// keeps the row the reader reads (also when entries fall off the top at the
// 500-entry limit) and counts what arrived below in a "N new steps" pill that
// scrolls back to the bottom. Also: the freshness hold shows once, as its
// action entry.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      rows;
}

Map<String, dynamic> _text(int i) => {
  'timestamp': i,
  'entry': {'kind': 'text', 'text': 'row $i'},
};

late _Client _client;
late _Workspace _w;
var _seq = 0;

void _live(int i) => _client.stream.add(
  RaftEvent('agent:activity', {
    'agentId': 'agent',
    'timestamp': i,
    'serverSeq': ++_seq,
    'entries': [
      {'kind': 'text', 'text': 'row $i'},
    ],
  }),
);

Future<void> _open(WidgetTester t, List<Map<String, dynamic>> rows) async {
  _seq = 0;
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _client = _Client()..user = RaftRecord({'id': 'viewer'});
  _client.selectServer('s');
  _w = _Workspace(_client, rows)
    ..server = RaftRecord({'id': 's', 'role': 'owner'});
  addTearDown(() async {
    _w.dispose();
    await _client.stream.close();
    await _client.dispose();
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: AgentActivityTab(controller: _w, agentId: 'agent'),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Finder _row(int i) => find.text('row $i');

/// The pill: its words, wherever it sits.
Finder get _backToBottom => find.text('Back to bottom');
Finder _newSteps(int n) => find.text(n == 1 ? '1 new step' : '$n new steps');

/// The label of a row on screen (the list also builds rows just outside it).
String _onScreenLabel(WidgetTester t) {
  final all = find.textContaining(RegExp(r'^row \d+$')).evaluate();
  for (final e in all) {
    final text = (e.widget as Text).data!;
    final dy = t.getTopLeft(find.text(text)).dy;
    if (dy > 100 && dy < 450) return text;
  }
  throw StateError('no row on screen');
}

bool _onScreen(WidgetTester t, Finder f) =>
    f.evaluate().isNotEmpty && t.getTopLeft(f).dy < 600;

Future<void> _scrollUp(WidgetTester t, double by) async {
  final gesture = await t.startGesture(const Offset(400, 300));
  await gesture.moveBy(Offset(0, by));
  await gesture.up();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('opens at the newest step, with no pill', (t) async {
    await _open(t, [for (var i = 1; i <= 60; i++) _text(i)]);
    expect(_row(60), findsOneWidget);
    expect(_row(1), findsNothing);
    expect(_backToBottom, findsNothing);
    expect(find.textContaining('new step'), findsNothing);
  });

  testWidgets('a reader at the end follows what arrives, still no pill', (
    t,
  ) async {
    await _open(t, [for (var i = 1; i <= 60; i++) _text(i)]);
    _live(61);
    await t.pumpAndSettle();
    expect(_row(61), findsOneWidget);
    _live(62);
    await t.pumpAndSettle();
    expect(_row(62), findsOneWidget);
    expect(_backToBottom, findsNothing);
    expect(find.textContaining('new step'), findsNothing);
  });

  testWidgets(
    'a reader above the end keeps the row they read and counts arrivals',
    (t) async {
      await _open(t, [for (var i = 1; i <= 60; i++) _text(i)]);
      await _scrollUp(t, 300);
      // Scrolled away from the end: the pill says Back to bottom.
      expect(_backToBottom, findsOneWidget);
      final label = _onScreenLabel(t);
      final before = t.getTopLeft(find.text(label)).dy;
      _live(61);
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.text(label)).dy, closeTo(before, 1));
      expect(_newSteps(1), findsOneWidget);
      expect(_backToBottom, findsNothing);
      _live(62);
      _live(63);
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.text(label)).dy, closeTo(before, 1));
      expect(_newSteps(3), findsOneWidget);
    },
  );

  testWidgets('the pill takes the reader to the newest step and goes away', (
    t,
  ) async {
    await _open(t, [for (var i = 1; i <= 60; i++) _text(i)]);
    await _scrollUp(t, 300);
    _live(61);
    await t.pumpAndSettle();
    expect(_onScreen(t, _row(61)), false);
    await t.tap(_newSteps(1));
    await t.pumpAndSettle();
    expect(_onScreen(t, _row(61)), true);
    expect(_newSteps(1), findsNothing);
    expect(_backToBottom, findsNothing);
    // Following again: the next arrival is in view without a pill.
    _live(62);
    await t.pumpAndSettle();
    expect(_row(62), findsOneWidget);
    expect(_backToBottom, findsNothing);
  });

  testWidgets('Back to bottom with nothing new is the plain pill', (t) async {
    await _open(t, [for (var i = 1; i <= 60; i++) _text(i)]);
    await _scrollUp(t, 300);
    expect(_backToBottom, findsOneWidget);
    await t.tap(_backToBottom);
    await t.pumpAndSettle();
    expect(_onScreen(t, _row(60)), true);
    expect(_backToBottom, findsNothing);
  });

  testWidgets(
    'at the 500-entry limit the row the reader reads does not move as the oldest drop off',
    (t) async {
      await _open(t, [for (var i = 1; i <= 500; i++) _text(i)]);
      await _scrollUp(t, 1200);
      final label = _onScreenLabel(t);
      final before = t.getTopLeft(find.text(label)).dy;
      // Three arrivals push the three oldest entries off the top.
      _live(501);
      _live(502);
      _live(503);
      await t.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(t.getTopLeft(find.text(label)).dy, closeTo(before, 1));
      // The count follows the newest changing, not the length (unchanged).
      expect(_newSteps(3), findsOneWidget);
    },
  );

  testWidgets('a freshness hold shows once, as its action entry', (t) async {
    await _open(t, [
      {
        'timestamp': 1,
        'entry': {
          'kind': 'status',
          'activity': 'working',
          'detail': 'Send held by freshness check',
          'detailKind': 'freshness_hold',
        },
      },
      {
        'timestamp': 2,
        'entry': {
          'kind': 'slock_action',
          'title': 'Send held by freshness check',
          'text': 'target: #general\nnew messages: 3 newer messages',
        },
      },
    ]);
    // The action entry says it, in the agent's words, with how many and where.
    expect(
      find.textContaining('Reading new messages before sending'),
      findsOneWidget,
    );
    expect(find.textContaining('3 new messages in #general'), findsOneWidget);
    // Neither the daemon's title nor a second status row repeats it.
    expect(find.textContaining('Send held by freshness check'), findsNothing);
    expect(find.text('Working'), findsNothing);
  });

  testWidgets('a hold whose body does not parse keeps its text', (t) async {
    await _open(t, [
      {
        'timestamp': 1,
        'entry': {
          'kind': 'slock_action',
          'title': 'Task claim held by freshness check',
          'text': 'something else',
        },
      },
    ]);
    expect(
      find.textContaining('Reading new messages before claiming the task'),
      findsOneWidget,
    );
    expect(find.textContaining('something else'), findsOneWidget);
  });

  testWidgets('a hidden tool stays out of the rows and the arrival count', (
    t,
  ) async {
    await _open(t, [for (var i = 1; i <= 60; i++) _text(i)]);
    await _scrollUp(t, 300);
    _client.stream.add(
      RaftEvent('agent:activity', {
        'agentId': 'agent',
        'timestamp': 70,
        'serverSeq': 900,
        'entries': [
          {
            'kind': 'tool_start',
            'toolName': 'mcp__chat__send_message',
            'toolInput': '#general',
          },
        ],
      }),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Sending message'), findsNothing);
    expect(find.textContaining('new step'), findsNothing);
  });

  testWidgets('the log is a named scroll region', (t) async {
    await _open(t, [for (var i = 1; i <= 5; i++) _text(i)]);
    expect(find.bySemanticsLabel('Activity'), findsOneWidget);
  });
}
