// Web v1.24 components/agent/RefText.tsx + utils/refTarget.ts: the raw log's
// reference pills. `#channel:#7` and `dm:@peer:#7` open that conversation's
// task, `dm:@peer` / `dm:@peer:shortid` resolve against the DMs, and anything
// that does not resolve (an unknown channel, a task ref with no way to open
// tasks, a malformed peer kind) stays verbatim text, never a dead link.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_activity_refs.dart';
import 'package:raft_ui/raft_ui.dart';

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final selected = <String>[];
  @override
  List<RaftChannel> get channels => [
    RaftChannel({'id': 'c-proj', 'type': 'channel', 'name': 'proj'}),
  ];
  @override
  List<RaftChannel> get dms => [
    RaftChannel({
      'id': 'dm-bob',
      'type': 'dm',
      'name': 'bob',
      'peerName': 'bob',
      'peerType': 'user',
    }),
    RaftChannel({
      'id': 'dm-bob-agent',
      'type': 'dm',
      'name': 'bob',
      'peerName': 'bob',
      'peerType': 'agent',
    }),
  ];
  @override
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  }) async {
    selected.add(next.id);
  }
}

Future<(_Workspace, List<(String, int)>)> _pump(
  WidgetTester t,
  String text, {
  bool withOpener = true,
}) async {
  final c = RaftClient(
    origin: 'https://fixture.test',
    sessionStore: MemorySessionStore(),
  );
  final w = _Workspace(c);
  final opened = <(String, int)>[];
  addTearDown(w.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Text.rich(
            TextSpan(
              children: linkifyActivityRefs(
                context,
                w,
                text,
                const TextStyle(fontSize: 12),
                onOpenTask: withOpener
                    ? (channelId, number) async =>
                          opened.add((channelId, number))
                    : null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return (w, opened);
}

void main() {
  testWidgets('a channel task ref #proj:#7 is a pill that opens that task', (
    t,
  ) async {
    final (_, opened) = await _pump(t, 'claimed #proj:#7 just now');
    final pill = find.text('#proj:#7');
    expect(pill, findsOneWidget);
    await t.tap(pill);
    await t.pump();
    expect(opened, [('c-proj', 7)]);
  });

  testWidgets('a DM task ref dm:@bob:#12 opens the task of that DM', (t) async {
    final (_, opened) = await _pump(t, 'see dm:@bob:#12');
    await t.tap(find.text('dm:@bob:#12'));
    await t.pump();
    expect(opened, [('dm-bob', 12)]);
  });

  testWidgets('without a way to open tasks a task ref is plain text', (
    t,
  ) async {
    final (_, opened) = await _pump(t, 'claimed #proj:#7', withOpener: false);
    expect(find.textContaining('#proj:#7', findRichText: true), findsOneWidget);
    await t.tap(find.textContaining('#proj:#7', findRichText: true));
    await t.pump();
    expect(opened, isEmpty);
    expect(find.byType(RaftReferenceChip), findsNothing);
  });

  testWidgets('a task ref of an unknown channel stays verbatim', (t) async {
    await _pump(t, 'claimed #nowhere:#7');
    expect(find.byType(RaftReferenceChip), findsNothing);
    expect(
      find.textContaining('#nowhere:#7', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('the task number must end the token: #proj:#7a is no task ref', (
    t,
  ) async {
    final (_, opened) = await _pump(t, 'x #proj:#7a');
    // `#proj` still resolves as the channel; the rest stays text.
    await t.tap(find.text('#proj'));
    await t.pump();
    expect(opened, isEmpty);
  });

  testWidgets('dm:@bob opens the DM; ~agent picks the agent peer', (t) async {
    final (w, _) = await _pump(t, 'to dm:@bob~agent and dm:@bob');
    await t.tap(find.text('dm:@bob~agent'));
    await t.pump();
    await t.tap(find.text('dm:@bob'));
    await t.pump();
    expect(w.selected, ['dm-bob-agent', 'dm-bob']);
  });

  testWidgets('an unknown peer kind or an unknown peer stays verbatim', (
    t,
  ) async {
    await _pump(t, 'dm:@bob~bot and dm:@carol');
    expect(find.byType(RaftReferenceChip), findsNothing);
  });

  testWidgets('a channel ref still opens the channel', (t) async {
    final (w, _) = await _pump(t, 'posted in #proj');
    await t.tap(find.text('#proj'));
    await t.pump();
    expect(w.selected, ['c-proj']);
  });

  test('activityRefLineExtra counts only lines with a resolvable pill', () {
    final c = RaftClient(
      origin: 'https://fixture.test',
      sessionStore: MemorySessionStore(),
    );
    final w = _Workspace(c);
    addTearDown(w.dispose);
    expect(activityRefLineExtra(w, '#proj\nplain\n#proj:#3'), 0.41);
    expect(
      activityRefLineExtra(w, '#proj\nplain\n#proj:#3', canOpenTask: true),
      closeTo(0.82, 1e-9),
    );
    expect(activityRefLineExtra(w, '#nowhere'), 0);
  });
}
