import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/agent_trajectory_log.dart';
import 'package:raft_ui/raft_ui.dart';

Map<String, dynamic> row(
  int time,
  String text, {
  int? seq,
  bool primed = false,
  String? fact,
}) => {
  'timestamp': time,
  'serverSeq': ?seq,
  'entry': {
    'kind': 'status',
    'activity': 'working',
    'detail': text,
    if (primed) ...{'activityKind': 'working', 'detailKind': 'other'},
    'producerFactId': ?fact,
  },
};

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final reads = <Completer<dynamic>>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) {
    expect(path, startsWith('/agents/'));
    expect(query, {'limit': '50'});
    final next = Completer<dynamic>();
    reads.add(next);
    return next.future;
  }
}

void main() {
  test('empty hydrate retains exact admitted window', () {
    final existing = [row(1, 'one')];
    expect(identical(mergeAgentTrajectoryLog(existing, []), existing), true);
  });
  test('warm and HTTP status with different source fields remain distinct', () {
    final merged = mergeAgentTrajectoryLog(
      [row(1, 'same', primed: true)],
      [row(1, 'same')],
    );
    expect(merged, hasLength(2));
    expect((merged.first['entry'] as Map)['detailKind'], 'other');
  });
  test('identical entries ignore key insertion order', () {
    final old = row(1, 'one');
    final reordered = {
      'timestamp': 1,
      'entry': {'detail': 'one', 'activity': 'working', 'kind': 'status'},
    };
    expect(mergeAgentTrajectoryLog([old], [reordered]), [old]);
  });
  test(
    'durable visible fact adopts real socket identity without duplicate',
    () {
      final socket = row(1, 'one', seq: 3);
      expect(mergeAgentTrajectoryLog([row(1, 'one')], [socket]), [socket]);
      expect(mergeAgentTrajectoryLog([socket], [row(1, 'one')]), [socket]);
    },
  );
  test('different producer facts retain identity unless fact id matches', () {
    expect(
      mergeAgentTrajectoryLog([row(1, 'one', seq: 1)], [row(1, 'one', seq: 2)]),
      hasLength(2),
    );
    expect(
      mergeAgentTrajectoryLog(
        [row(1, 'one', seq: 1, fact: 'fact')],
        [row(1, 'one', seq: 2, fact: 'fact')],
      ),
      hasLength(1),
    );
  });
  test('stable timestamp/sequence order and bounded latest 500 rows', () {
    final result = mergeAgentTrajectoryLog(
      [for (var i = 0; i < 505; i++) row(i, '$i')],
      [row(506, 'new')],
    );
    expect(result, hasLength(500));
    expect(result.first['timestamp'], 6);
    expect(result.last['timestamp'], 506);
    final ties = mergeAgentTrajectoryLog([row(1, 'a')], [row(1, 'b')]);
    expect((ties.first['entry'] as Map)['detail'], 'a');
  });
  test('malformed rows never enter the public rendering window', () {
    expect(
      admittedAgentTrajectoryRows([
        null,
        {},
        {'timestamp': double.nan, 'entry': {}},
        {'timestamp': 1, 'serverSeq': '3', 'entry': {}},
        {'timestamp': 1, 'serverSeq': double.infinity, 'entry': {}},
        {
          'timestamp': 1,
          'entry': {4: 'invalid key'},
        },
        {'timestamp': 1, 'launchId': 4, 'entry': {}},
        row(1, 'valid'),
      ]),
      [row(1, 'valid')],
    );
  });
  for (final (family, mode) in [
    (RaftFamily.brutal, ThemeMode.light),
    (RaftFamily.elegant, ThemeMode.light),
    (RaftFamily.elegant, ThemeMode.dark),
  ]) {
    testWidgets(
      'activity inline paragraph ignores host 24px line $family $mode',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family),
            darkTheme: raftTheme(family, dark: true),
            themeMode: mode,
            home: Scaffold(
              body: DefaultTextStyle(
                style: const TextStyle(fontSize: 16, height: 24 / 16),
                child: RaftActivityLogView(
                  entries: const [
                    RaftActivityLogEntry(
                      time: '10:00:00',
                      dot: Colors.amber,
                      title: 'Working',
                      inlineDetail: 'first\nsecond',
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final paragraph = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().startsWith('Working'),
        );
        expect(paragraph, findsOneWidget);
        final style = (t.widget<RichText>(paragraph).text as TextSpan).style!;
        expect(style.fontSize, 14);
        expect(style.height! * style.fontSize!, closeTo(20, .001));
        expect(t.getSize(paragraph).height, closeTo(40, .001));
      },
    );
  }
  late _Client c;
  late _Workspace w;
  setUp(() {
    c = _Client()..user = RaftRecord({'id': 'viewer'});
    c.selectServer('s');
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
  });
  tearDown(() async {
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });
  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(RaftFamily.brutal),
    home: Scaffold(body: child),
  );
  testWidgets(
    'mounted activity adopts warm input then merges real HTTP independently',
    (t) async {
      await t.pumpWidget(
        host(
          AgentActivityTab(
            controller: w,
            agentId: 'agent',
            initialEntries: [row(1, 'same', primed: true)],
          ),
        ),
      );
      expect(w.reads, hasLength(1));
      w.reads.single.complete([row(1, 'same')]);
      await t.pumpAndSettle();
      expect(find.textContaining('same', findRichText: true), findsNWidgets(2));
    },
  );
  testWidgets(
    'socket entries survive a late hydrate and heartbeat causes no HTTP',
    (t) async {
      await t.pumpWidget(
        host(AgentActivityTab(controller: w, agentId: 'agent')),
      );
      c.stream.add(
        RaftEvent('agent:activity', {
          'agentId': 'agent',
          'timestamp': 2,
          'serverSeq': 1,
          'entries': [
            {'kind': 'text', 'text': 'Fresh socket output'},
          ],
        }),
      );
      await t.pump();
      w.reads.single.complete([row(1, 'old')]);
      await t.pumpAndSettle();
      expect(find.text('Fresh socket output'), findsOneWidget);
      c.stream.add(
        RaftEvent('agent:activity', {'agentId': 'agent', 'isHeartbeat': true}),
      );
      await t.pump(const Duration(seconds: 1));
      expect(w.reads, hasLength(1));
    },
  );
  testWidgets('authority change drops old window and rejects late old HTTP', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        AgentActivityTab(
          controller: w,
          agentId: 'agent',
          initialEntries: [row(1, 'private old')],
        ),
      ),
    );
    w.server = RaftRecord({'id': 'new-server', 'role': 'member'});
    w.notifyListeners();
    await t.pump();
    expect(find.textContaining('private old'), findsNothing);
    expect(w.reads, hasLength(2));
    w.reads[1].complete([row(3, 'current')]);
    await t.pumpAndSettle();
    w.reads[0].complete([row(2, 'stale')]);
    await t.pumpAndSettle();
    expect(find.textContaining('stale'), findsNothing);
    expect(find.textContaining('current'), findsOneWidget);
  });
  testWidgets(
    'reconnect reload is debounced and dispose rejects pending result',
    (t) async {
      await t.pumpWidget(
        host(AgentActivityTab(controller: w, agentId: 'agent')),
      );
      w.reads[0].complete([row(1, 'first')]);
      await t.pumpAndSettle();
      c.stream.add(RaftEvent('connected', {}));
      c.stream.add(RaftEvent('connected', {}));
      await t.pump(const Duration(milliseconds: 499));
      expect(w.reads, hasLength(1));
      await t.pump(const Duration(milliseconds: 1));
      expect(w.reads, hasLength(2));
      await t.pumpWidget(const SizedBox.shrink());
      w.reads[1].complete([row(2, 'late')]);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
