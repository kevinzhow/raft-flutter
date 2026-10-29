import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_agent_presentation.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path == '/agents'
      ? [
          {'id': 'a', 'name': 'Anna'},
          {'id': 'b', 'name': 'Bob'},
          {'id': 'x', 'name': 'Ext', 'runtime': 'external'},
        ]
      : [];
}

class _Clock {
  DateTime now = DateTime.utc(2026, 10, 17);
  DateTime call() => now;
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));
}

Future<(ChatAgentPresentation, _Clock)> _fixture() async {
  final client = RaftClient(
    origin: 'https://working-agents-timing.invalid',
    sessionStore: MemorySessionStore(),
  )..user = RaftRecord({'id': 'alice'});
  client.selectServer('s');
  final w = _Workspace(client)
    ..server = RaftRecord({'id': 's', 'role': 'owner'});
  final directory = MessageReferenceDirectory(w);
  await w.entityDirectory.preload();
  expect(directory.agents.map((row) => row['id']), ['a', 'b', 'x']);
  final clock = _Clock();
  final activity = ChatAgentPresentation(w, directory, clock: clock.call);
  addTearDown(() async {
    activity.dispose();
    directory.dispose();
    w.dispose();
    await client.dispose();
  });
  return (activity, clock);
}

int _seq = 0;
void _signal(
  ChatAgentPresentation activity,
  String id, {
  String kind = 'working',
  String? detail,
  Map<String, Object?> extra = const {},
}) => activity.event(
  RaftEvent('agent:activity', {
    'agentId': id,
    'serverId': 's',
    'activity': kind,
    'detail': ?detail,
    'serverSeq': '${++_seq}',
    ...extra,
  }),
);

List<String> _ids(ChatAgentPresentation a) => [
  for (final item in a.working) item.agentId,
];

void main() {
  test('agents are listed in the order they started and keep it', () async {
    final (activity, clock) = await _fixture();
    _signal(activity, 'b', detail: 'Editing Flow.tsx · #25');
    clock.advance(10);
    _signal(activity, 'a', detail: 'Drafting release notes · #31');
    expect(_ids(activity), ['b', 'a']);
    // A newer signal from the first agent (new text, heartbeat) does not move
    // its face.
    clock.advance(10);
    _signal(activity, 'b', detail: 'Editing Flow.tsx · #26');
    _signal(activity, 'b', extra: {'isHeartbeat': true});
    expect(_ids(activity), ['b', 'a']);
    expect(activity.working.first.text, 'Working…');
  });

  test('what the agent is doing, or its state when no detail comes', () async {
    final (activity, _) = await _fixture();
    _signal(activity, 'a', detail: 'Editing Flow.tsx · #25');
    _signal(activity, 'b', kind: 'thinking');
    expect(activity.working.map((i) => i.text), [
      'Editing Flow.tsx · #25',
      'Thinking…',
    ]);
  });

  test('an idle agent stays listed for 5 seconds, then leaves once', () async {
    final (activity, clock) = await _fixture();
    _signal(activity, 'a', detail: 'Editing');
    var changes = 0;
    activity.addListener(() => changes++);
    clock.advance(20);
    _signal(activity, 'a', kind: 'online');
    expect(_ids(activity), ['a'], reason: 'grace period');
    expect(changes, 0, reason: 'nothing visible changed yet');

    clock.advance(4);
    activity.prune();
    expect(_ids(activity), ['a']);
    expect(changes, 0);

    clock.advance(1);
    activity.prune();
    expect(_ids(activity), isEmpty);
    expect(changes, 1);
    activity.prune();
    expect(changes, 1, reason: 'an empty prune stays silent');
  });

  test(
    'an agent that resumes within the grace period keeps its place',
    () async {
      final (activity, clock) = await _fixture();
      _signal(activity, 'a', detail: 'Step one');
      clock.advance(1);
      _signal(activity, 'b', detail: 'Other');
      clock.advance(10);
      _signal(activity, 'a', kind: 'online');
      clock.advance(3);
      _signal(activity, 'a', detail: 'Step two');
      expect(_ids(activity), ['a', 'b']);
      clock.advance(10);
      activity.prune();
      expect(_ids(activity), ['a', 'b'], reason: 'the grace was cancelled');
      expect(activity.working.first.text, 'Step two');
    },
  );

  test('an agent that stops (error, offline) leaves at once', () async {
    final (activity, _) = await _fixture();
    _signal(activity, 'a', detail: 'Editing');
    _signal(activity, 'b', detail: 'Reading');
    _signal(activity, 'a', kind: 'error', detail: 'boom');
    expect(_ids(activity), ['b']);
    _signal(activity, 'b', kind: 'offline');
    expect(_ids(activity), isEmpty);
  });

  test('no signal for 90 seconds takes an agent out', () async {
    final (activity, clock) = await _fixture();
    _signal(activity, 'a', detail: 'Editing');
    clock.advance(30);
    _signal(activity, 'b', detail: 'Reading');
    var changes = 0;
    activity.addListener(() => changes++);

    clock.advance(59);
    activity.prune();
    expect(_ids(activity), ['a', 'b']);
    clock.advance(1);
    activity.prune();
    expect(_ids(activity), ['b'], reason: 'a: 90s without a signal');
    expect(changes, 1);

    // A heartbeat is a signal: it keeps b listed.
    clock.advance(40);
    _signal(activity, 'b', extra: {'isHeartbeat': true});
    clock.advance(60);
    activity.prune();
    expect(_ids(activity), ['b']);
    clock.advance(31);
    activity.prune();
    expect(_ids(activity), isEmpty);
  });

  test('an already expired late signal does not invent a row', () async {
    final (activity, clock) = await _fixture();
    _signal(
      activity,
      'a',
      extra: {
        'timestamp': clock.now
            .subtract(const Duration(seconds: 91))
            .millisecondsSinceEpoch,
      },
    );
    expect(activity.items, isEmpty);
  });

  test('a heartbeat with no running row does not start one', () async {
    final (activity, _) = await _fixture();
    _signal(activity, 'a', extra: {'isHeartbeat': true});
    expect(activity.working, isEmpty);
  });

  test('authority clearing cannot be published again by expiry', () async {
    final (activity, _) = await _fixture();
    _signal(activity, 'a', detail: 'Editing');
    activity.w.server = RaftRecord({'id': 's', 'role': 'guest'});
    activity.w.notifyListeners();
    expect(activity.working, isEmpty);
    var changes = 0;
    activity.addListener(() => changes++);

    activity.prune();

    expect(changes, 0);
  });

  test(
    'row text follows the agent; an external agent keeps its runtime',
    () async {
      final (activity, _) = await _fixture();
      final row = activity.rowText('a'), external = activity.rowText('x');
      expect(row.value, isNull);
      _signal(activity, 'a', detail: 'Editing Flow.tsx · #25');
      _signal(activity, 'x', detail: 'Editing elsewhere');
      expect(row.value, 'Editing Flow.tsx · #25');
      expect(external.value, isNull);
      _signal(activity, 'a', kind: 'error');
      expect(row.value, isNull);
    },
  );

  test('a real timer prunes the grace period without any signal', () async {
    // The expiry timer runs on the injected clock's deadline; the clock here
    // is real wall time so Timer and clock agree.
    final client = RaftClient(
      origin: 'https://working-agents-timer.invalid',
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'alice'});
    client.selectServer('s');
    final w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    final directory = MessageReferenceDirectory(w);
    await w.entityDirectory.preload();
    final activity = ChatAgentPresentation(w, directory);
    addTearDown(() async {
      activity.dispose();
      directory.dispose();
      w.dispose();
      await client.dispose();
    });
    _signal(activity, 'a', detail: 'Editing');
    _signal(activity, 'a', kind: 'online');
    expect(_ids(activity), ['a']);
    var changes = 0;
    activity.addListener(() => changes++);
    await Future<void>.delayed(const Duration(milliseconds: 5200));
    expect(_ids(activity), isEmpty);
    expect(changes, 1);
  });
}
