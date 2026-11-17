// The channel Tasks card's body (Web v1.24 ChannelTasksPanel): the All / For me
// filter with active counts, status lanes in the card's order with their
// initial folds, the compact rows, the empty states per filter, and "+" (As task
// in the composer beside the card, else the New task dialog).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_task_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_store.dart'
    show ChannelTasksFilter;
import 'package:raft_flutter/features/channel_side_tasks_panel.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes = <String, (int, Object?) Function(RequestOptions)>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final (status, body) = route == null
        ? (404, {'error': 'Unexpected endpoint'})
        : route(o);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client({
    required super.origin,
    required MemorySessionStore sessionStore,
    super.transport,
  }) : super(sessionStore: sessionStore);
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  void emit(String name, Object payload) =>
      ingress.add(RaftEvent(name, payload));
}

Map<String, dynamic> _task(
  int number,
  String status, {
  String? by = 'alice',
  String type = 'user',
  String? name,
}) => {
  'id': 't$number',
  'taskNumber': number,
  'title': 'Task $number',
  'status': status,
  'channelId': 'c1',
  'messageId': 'm$number',
  'conversationChannelId': 'conv-$number',
  'conversationReplyCount': 0,
  'isLegacy': false,
  if (by != null) ...{
    'claimedById': by,
    'claimedByType': type,
    'claimedByName': name ?? 'Name $by',
  },
};

Future<(WorkspaceController, _Adapter)> _fixture(
  List<Map<String, dynamic>> tasks, {
  bool warm = true,
  bool flag = true,
}) async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => (
    200,
    {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    },
  );
  a.routes['POST /feature-flags/evaluate'] = (_) => (
    200,
    {
      'evaluations': [
        {'key': 'task_v2_conversations_v0', 'enabled': flag},
      ],
    },
  );
  a.routes['GET /tasks/channel/c1'] = (_) => (200, {'tasks': tasks});
  final client = _Client(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channel = RaftChannel({
    'id': 'c1',
    'name': 'test',
    'type': 'channel',
    'joined': true,
  });
  w.channels = [w.channel!];
  if (warm) await MessageTaskCache.of(client).revalidate(w, 'c1');
  return (w, a);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

class _Host extends StatefulWidget {
  const _Host({
    required this.w,
    required this.opened,
    this.initial = ChannelTasksFilter.all,
    this.filters,
  });
  final WorkspaceController w;
  final List<Map<String, dynamic>> opened;
  final ChannelTasksFilter initial;
  final List<ChannelTasksFilter>? filters;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late var filter = widget.initial;
  @override
  Widget build(BuildContext context) => ChannelSideTasksPanel(
    controller: widget.w,
    channelId: 'c1',
    filter: filter,
    onFilterChanged: (next) {
      widget.filters?.add(next);
      setState(() => filter = next);
    },
    onOpenTask: widget.opened.add,
    covering: false,
  );
}

Future<List<Map<String, dynamic>>> _pump(
  WidgetTester t,
  WorkspaceController w, {
  ChannelTasksFilter filter = ChannelTasksFilter.all,
  List<ChannelTasksFilter>? filters,
  Size size = const Size(400, 800),
  Brightness brightness = Brightness.light,
  TargetPlatform? platform,
  double textScale = 1,
}) async {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(t.view.reset);
  final opened = <Map<String, dynamic>>[];
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: brightness == Brightness.dark, platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: _Host(w: w, opened: opened, initial: filter, filters: filters),
      ),
    ),
  );
  await _settle(t);
  return opened;
}

Finder _count(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

double _top(WidgetTester t, String key) =>
    t.getTopLeft(find.byKey(ValueKey(key))).dy;

void main() {
  final tasks = [
    _task(1, 'todo', by: null),
    _task(2, 'todo', by: 'alice'),
    _task(3, 'in_progress', by: 'bob', type: 'agent', name: 'Builder'),
    _task(4, 'in_review', by: 'alice'),
    // Same id as the viewer, but an agent: not "for me".
    _task(5, 'in_progress', by: 'alice', type: 'agent', name: 'Alice Bot'),
    _task(6, 'backlog', by: 'alice'),
    _task(7, 'done', by: 'alice'),
    _task(8, 'closed', by: 'alice'),
  ];

  testWidgets('the filter counts active tasks: todo, in progress, in review', (
    t,
  ) async {
    final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
    addTearDown(w.dispose);
    await _pump(t, w);
    // 1,2 todo + 3,5 in progress + 4 in review = 5; backlog/done/closed out.
    expect(_count('channel-tasks-filter-all', '5'), findsOneWidget);
    // Mine: 2 todo, 4 in review (6/7/8 are not active; 5 is an agent).
    expect(_count('channel-tasks-filter-mine', '2'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('For me'), findsOneWidget);
  });

  testWidgets('no count when nothing is active', (t) async {
    final (w, _) = (await t.runAsync(
      () => _fixture([_task(1, 'done'), _task(2, 'closed')]),
    ))!;
    addTearDown(w.dispose);
    await _pump(t, w);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('channel-tasks-filter-all')),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('lanes: in progress, in review, todo, then folded backlog, '
      'done, closed; the counts and the rows by task number', (t) async {
    final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
    addTearDown(w.dispose);
    await _pump(t, w);
    final order = [
      for (final s in [
        'in_progress',
        'in_review',
        'todo',
        'backlog',
        'done',
        'closed',
      ])
        _top(t, 'channel-tasks-group-$s'),
    ];
    expect(order, [...order]..sort());
    // Open lanes show their rows; folded ones show only the heading.
    expect(find.text('Task 3'), findsOneWidget);
    expect(find.text('Task 4'), findsOneWidget);
    expect(find.text('Task 2'), findsOneWidget);
    expect(find.text('Task 6'), findsNothing);
    expect(find.text('Task 7'), findsNothing);
    expect(find.text('Task 8'), findsNothing);
    // Newest first inside a lane.
    expect(
      t.getTopLeft(find.text('Task 5')).dy,
      lessThan(t.getTopLeft(find.text('Task 3')).dy),
    );
    expect(
      t.getTopLeft(find.text('Task 2')).dy,
      lessThan(t.getTopLeft(find.text('Task 1')).dy),
    );
    // The lane heading carries the number of tasks in it.
    expect(_count('channel-tasks-group-in_progress', '2'), findsOneWidget);
    expect(_count('channel-tasks-group-backlog', '1'), findsOneWidget);
    // The lane names the status: no badge on its rows.
    expect(find.byType(RaftTaskStatusBadge), findsNothing);
  });

  testWidgets('a lane with no tasks has no heading', (t) async {
    final (w, _) = (await t.runAsync(
      () => _fixture([_task(1, 'todo'), _task(2, 'done')]),
    ))!;
    addTearDown(w.dispose);
    await _pump(t, w);
    expect(find.byKey(const ValueKey('channel-tasks-group-todo')), findsOne);
    expect(find.byKey(const ValueKey('channel-tasks-group-done')), findsOne);
    expect(
      find.byKey(const ValueKey('channel-tasks-group-in_progress')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('channel-tasks-group-closed')),
      findsNothing,
    );
  });

  testWidgets('toggling a lane folds and unfolds it', (t) async {
    final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
    addTearDown(w.dispose);
    await _pump(t, w);
    final backlog = find.byKey(const ValueKey('channel-tasks-group-backlog'));
    expect(find.bySemanticsLabel('Show Backlog'), findsOneWidget);
    await t.tap(backlog);
    await t.pump();
    expect(find.text('Task 6'), findsOneWidget);
    expect(find.bySemanticsLabel('Hide Backlog'), findsOneWidget);
    await t.tap(backlog);
    await t.pump();
    expect(find.text('Task 6'), findsNothing);
    // An open lane folds too.
    await t.tap(find.byKey(const ValueKey('channel-tasks-group-todo')));
    await t.pump();
    expect(find.text('Task 2'), findsNothing);
    expect(find.text('Task 3'), findsOneWidget);
  });

  testWidgets('For me: tasks claimed by the viewer as a user, with the '
      'filter reported to the card', (t) async {
    final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
    addTearDown(w.dispose);
    final filters = <ChannelTasksFilter>[];
    await _pump(t, w, filters: filters);
    await t.tap(find.byKey(const ValueKey('channel-tasks-filter-mine')));
    await _settle(t);
    expect(filters, [ChannelTasksFilter.mine]);
    expect(find.text('Task 2'), findsOneWidget);
    expect(find.text('Task 4'), findsOneWidget);
    expect(find.text('Task 1'), findsNothing); // unassigned
    expect(find.text('Task 3'), findsNothing); // someone else
    expect(find.text('Task 5'), findsNothing); // an agent with the viewer's id
    // The counts are of the tasks, not of the filter.
    expect(_count('channel-tasks-filter-all', '5'), findsOneWidget);
    expect(_count('channel-tasks-filter-mine', '2'), findsOneWidget);
    // Back to All.
    await t.tap(find.byKey(const ValueKey('channel-tasks-filter-all')));
    await _settle(t);
    expect(filters.last, ChannelTasksFilter.all);
    expect(find.text('Task 3'), findsOneWidget);
  });

  testWidgets('the viewer reads as You, others by name', (t) async {
    final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
    addTearDown(w.dispose);
    await _pump(t, w);
    expect(find.text('You'), findsWidgets);
    expect(find.text('Builder'), findsOneWidget);
  });

  testWidgets('empty For me: its own title and body', (t) async {
    final (w, _) = (await t.runAsync(
      () => _fixture([_task(1, 'todo', by: 'bob')]),
    ))!;
    addTearDown(w.dispose);
    await _pump(t, w, filter: ChannelTasksFilter.mine);
    expect(find.text('Nothing is waiting on you'), findsOneWidget);
    expect(
      find.text('Tasks assigned to you in this channel show up here.'),
      findsOneWidget,
    );
    expect(find.text('Task 1'), findsNothing);
  });

  testWidgets('empty All: no tasks yet', (t) async {
    final (w, _) = (await t.runAsync(() => _fixture(const [])))!;
    addTearDown(w.dispose);
    await _pump(t, w);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(
      find.text(
        'Tasks that people and agents create in this channel show up here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('not loaded yet: no empty state until the bucket is read, and '
      'the card reads it once when nobody has', (t) async {
    final (w, api) = (await t.runAsync(() => _fixture(const [], warm: false)))!;
    addTearDown(w.dispose);
    t.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 800);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: _Host(w: w, opened: []),
        ),
      ),
    );
    expect(find.text('No tasks yet'), findsNothing);
    await _settle(t);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(api.calls.where((c) => c.path == '/tasks/channel/c1').length, 1);
  });

  testWidgets('a loaded bucket is not requested again', (t) async {
    final (w, api) = (await t.runAsync(() => _fixture(tasks)))!;
    addTearDown(w.dispose);
    final before = api.calls.where((c) => c.path == '/tasks/channel/c1').length;
    await _pump(t, w);
    expect(
      api.calls.where((c) => c.path == '/tasks/channel/c1').length,
      before,
    );
  });

  testWidgets('a task realtime event updates the open card in place', (
    t,
  ) async {
    final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
    addTearDown(w.dispose);
    await _pump(t, w);
    expect(find.text('Task 3'), findsOneWidget);
    (w.client as _Client).emit('task:updated', {
      'task': {'id': 't3', 'channelId': 'c1', 'status': 'done'},
    });
    await _settle(t);
    expect(find.text('Task 3'), findsNothing);
    expect(_count('channel-tasks-group-done', '2'), findsOneWidget);
  });

  testWidgets('tapping a row opens that task', (t) async {
    final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
    addTearDown(w.dispose);
    final opened = await _pump(t, w);
    await t.tap(find.text('Task 4'));
    await t.pump();
    expect(opened.single['id'], 't4');
    expect(opened.single['taskNumber'], 4);
  });

  for (final (name, size, platform) in [
    (
      'a folded foldable (856x944, Android)',
      const Size(856, 944),
      TargetPlatform.android,
    ),
    (
      'a narrow desktop window (390x844, Linux)',
      const Size(390, 844),
      TargetPlatform.linux,
    ),
  ]) {
    testWidgets('the rows are reachable and tappable on $name', (t) async {
      final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
      addTearDown(w.dispose);
      final opened = await _pump(t, w, size: size, platform: platform);
      await t.tap(find.text('Task 3'));
      await t.pump();
      expect(opened.single['id'], 't3');
      await t.tap(find.byKey(const ValueKey('channel-tasks-filter-mine')));
      await _settle(t);
      expect(find.text('Task 4'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('lays out in ${brightness.name} without errors, '
        'large text included', (t) async {
      final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
      addTearDown(w.dispose);
      await _pump(
        t,
        w,
        brightness: brightness,
        size: const Size(320, 640),
        textScale: 2,
      );
      expect(t.takeException(), isNull);
      expect(find.text('Task 3'), findsOneWidget);
    });
  }

  group('+ New task', () {
    testWidgets('with a composer beside the card it turns As task on there, '
        'and opens no dialog', (t) async {
      final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
      addTearDown(w.dispose);
      await t.runAsync(() => TaskV2ConversationsFlag.of(w).ensure());
      var turnedOn = 0;
      final off = ComposerTaskModeTargets.register('c1', () => turnedOn++);
      addTearDown(off);
      late BuildContext context;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      openChannelTaskCreate(
        context,
        controller: w,
        channelId: 'c1',
        covering: false,
      );
      await t.pump();
      expect(turnedOn, 1);
      expect(find.byType(RaftCreateTaskMessageDialogView), findsNothing);
    });

    for (final (why, covering, registered) in [
      ('the card covers the conversation', true, true),
      ('no composer of the channel is mounted', false, false),
    ]) {
      testWidgets('opens the New task dialog when $why', (t) async {
        final (w, _) = (await t.runAsync(() => _fixture(tasks)))!;
        addTearDown(w.dispose);
        await t.runAsync(() => TaskV2ConversationsFlag.of(w).ensure());
        var turnedOn = 0;
        if (registered) {
          final off = ComposerTaskModeTargets.register('c1', () => turnedOn++);
          addTearDown(off);
        }
        late BuildContext context;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        openChannelTaskCreate(
          context,
          controller: w,
          channelId: 'c1',
          covering: covering,
        );
        await _settle(t);
        expect(turnedOn, 0);
        expect(find.byType(RaftCreateTaskMessageDialogView), findsOneWidget);
      });
    }

    testWidgets('a composer of another channel is not the one asked', (
      t,
    ) async {
      var turnedOn = 0;
      final off = ComposerTaskModeTargets.register('c2', () => turnedOn++);
      addTearDown(off);
      expect(ComposerTaskModeTargets.request('c1'), isFalse);
      expect(ComposerTaskModeTargets.request('c2'), isTrue);
      expect(turnedOn, 1);
    });

    testWidgets('the composer asked is the one that registered last', (
      t,
    ) async {
      final calls = <String>[];
      final first = ComposerTaskModeTargets.register(
        'c1',
        () => calls.add('a'),
      );
      final second = ComposerTaskModeTargets.register(
        'c1',
        () => calls.add('b'),
      );
      expect(ComposerTaskModeTargets.request('c1'), isTrue);
      second();
      expect(ComposerTaskModeTargets.request('c1'), isTrue);
      first();
      expect(ComposerTaskModeTargets.request('c1'), isFalse);
      expect(calls, ['b', 'a']);
    });
  });
}
