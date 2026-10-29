import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_agent_presentation.dart';
import 'package:raft_flutter/features/working_agents.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';
import 'package:raft_ui/raft_ui.dart';

class _Workspace extends WorkspaceController {
  _Workspace(super.client);

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path == '/agents'
      ? [
          {'id': 'older', 'name': 'Older', 'avatarUrl': 'pixel:cat'},
          {'id': 'latest', 'name': 'Latest', 'avatarUrl': 'pixel:cat'},
        ]
      : [];
}

class _Storage implements SearchMemoryStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

Future<ChatAgentPresentation> _fixture(DateTime Function() clock) async {
  final client = RaftClient(
    origin: 'https://live-expiry-render.invalid',
    sessionStore: MemorySessionStore(),
  )..user = RaftRecord({'id': 'alice'});
  client.selectServer('s');
  final w = _Workspace(client)
    ..server = RaftRecord({'id': 's', 'role': 'owner'});
  final directory = MessageReferenceDirectory(w);
  await w.entityDirectory.preload();
  final activity = ChatAgentPresentation(w, directory, clock: clock);
  addTearDown(() async {
    activity.dispose();
    directory.dispose();
    w.dispose();
    await client.dispose();
  });
  return activity;
}

void _signal(
  ChatAgentPresentation activity,
  String id, {
  String kind = 'working',
  int? timestamp,
}) => activity.event(
  RaftEvent('agent:activity', {
    'agentId': id,
    'serverId': 's',
    'activity': kind,
    'detail': '$id task',
    'timestamp': ?timestamp,
  }),
);

Future<void> _mount(
  WidgetTester t,
  ChatAgentPresentation activity,
  PersonalPresentationStore store,
  void Function() onBuild,
) => t.pumpWidget(
  MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topRight,
        child: ListenableBuilder(
          listenable: activity,
          builder: (context, _) {
            onBuild();
            return NativeWorkingAgentsSummary(
              activities: activity,
              presentation: store,
              origin: activity.w.client.origin,
              onOpenAgent: (_) {},
            );
          },
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('expiry changes the summary only when someone leaves', (t) async {
    final start = t.binding.clock.now();
    final activity = await _fixture(
      () => DateTime.utc(
        2026,
        10,
        17,
      ).add(t.binding.clock.now().difference(start)),
    );
    final store = PersonalPresentationStore(storage: _Storage());
    await store.bind(activity.w.client.origin, 'alice');
    addTearDown(store.dispose);
    _signal(activity, 'older');
    await t.pump(const Duration(seconds: 30));
    _signal(activity, 'latest');
    var builds = 0, notifications = 0;
    activity.addListener(() => notifications++);
    await _mount(t, activity, store, () => builds++);
    await t.pumpAndSettle();
    final settledBuilds = builds;
    expect(find.text('2'), findsOneWidget);
    expect(find.byKey(const Key('working-agents-summary')), findsOneWidget);

    // The real expiry Timer runs with the injected clock following the
    // widget test's clock: 90 seconds without a signal takes the older
    // agent out, in the order they started.
    await t.pump(const Duration(seconds: 61));
    expect(activity.items.map((item) => item.agentId), ['latest']);
    expect(notifications, 1);
    expect(builds, settledBuilds + 1);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);

    await t.pump(const Duration(seconds: 30));
    expect(activity.items, isEmpty);
    expect(notifications, 2);
    expect(builds, settledBuilds + 2);
    expect(find.byKey(const Key('working-agents-summary')), findsNothing);
    expect(find.text('0'), findsNothing);

    activity.prune();
    activity.prune();
    await t.pump();
    expect(notifications, 2);
    expect(builds, settledBuilds + 2);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an idle agent stays 5 seconds, a resumed one never leaves', (
    t,
  ) async {
    final start = t.binding.clock.now();
    final activity = await _fixture(
      () => DateTime.utc(
        2026,
        10,
        17,
      ).add(t.binding.clock.now().difference(start)),
    );
    final store = PersonalPresentationStore(storage: _Storage());
    await store.bind(activity.w.client.origin, 'alice');
    addTearDown(store.dispose);
    _signal(activity, 'older');
    _signal(activity, 'latest');
    await _mount(t, activity, store, () {});
    await t.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    _signal(activity, 'older', kind: 'online');
    await t.pump(const Duration(seconds: 4));
    expect(find.text('2'), findsOneWidget, reason: 'grace period');

    // It resumes before the grace ends: nothing changed.
    _signal(activity, 'older');
    await t.pump(const Duration(seconds: 10));
    expect(find.text('2'), findsOneWidget);

    _signal(activity, 'older', kind: 'online');
    await t.pump(const Duration(seconds: 4, milliseconds: 900));
    expect(find.text('2'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('1'), findsOneWidget, reason: '5 seconds after idle');
    // The last agent goes silent: the expiry timer drains.
    await t.pump(const Duration(seconds: 100));
    expect(find.byKey(const Key('working-agents-summary')), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
