import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/app_link_models.dart';
import 'package:raft_flutter/features/app_link_view.dart';
import 'package:raft_flutter/features/artifacts/artifact_message_card.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/saved_sidebar_entry.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/task_surface_controller.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_store.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../test/support/artifact_fake_client.dart'
    show artifactCardJson, artifactId, artifactShort;
import '../../test/support/tasks_page_harness.dart' show pageTask, TasksServer;
import 'fixtures.dart';
import 'probe.dart';

part 'list_projection_replay.dart';

const listSurfaces = [
  'chat',
  'thread',
  'activity',
  'tasks-list',
  'tasks-board',
  'task-discussion',
  'search',
  'files',
  'directory',
  'apps',
  'saved',
  'sidebar',
];
const listWorkloads = ['steady', 'fling', 'live', 'idle'];

void registerSidebarArrivalTest() {
  testWidgets('the phone Sidebar fixture exposes scrollable channels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.4375;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final images = (await tester.runAsync(LabImages.start))!;
    addTearDown(() => images.server.close(force: true));
    final fixture = (await tester.runAsync(
      () => _ListFixture.open('sidebar', images),
    ))!;
    try {
      await fixture.mount(tester, dark: false);
      await tester.pumpAndSettle();
      expect(fixture.rows, isNotEmpty);
      expect(fixture.scroll?.position.maxScrollExtent, greaterThan(100));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    }
  });
}

class ListScenes {
  ListScenes({
    required this.tester,
    required this.theme,
    required this.dark,
    required this.seconds,
    required this.lab,
    required this.images,
    required this.wants,
  });

  final WidgetTester tester;
  final String theme;
  final bool dark;
  final int seconds;
  final LabRecorder lab;
  final LabImages images;
  final bool Function(String) wants;

  Future<List<String>> run() async {
    final failures = <String>[];
    for (final surface in listSurfaces) {
      final projection = _ProjectionReplay.supports(surface);
      if (projection && wants('list-$surface-live')) {
        final fixture = await _ListFixture.open(surface, images);
        try {
          final record = await lab.measure(
            tester,
            theme,
            'list-$surface-live',
            () => fixture.projection.run(tester, dark: dark),
            kind: 'projection',
            evidence: (extras) => {
              'arrival': {
                'arrived': extras['arrived'] == true,
                'visibleKeys': fixture.rows
                    .take(5)
                    .map((element) => '${element.widget.key}')
                    .toList(),
              },
            },
          );
          if (record['failure'] case final Object error) {
            failures.add('$theme/list-$surface-live: $error');
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          fixture.dispose();
        }
      }
      final workloads = listWorkloads.where(
        (work) =>
            (!projection || work != 'live') && wants('list-$surface-$work'),
      );
      if (workloads.isEmpty) continue;
      final fixture = await _ListFixture.open(surface, images);
      try {
        await fixture.mount(tester, dark: dark);
        if (surface == 'tasks-board') {
          await idle(const Duration(milliseconds: 600));
          fixture.tasksPage!.visit(serverId: 's1', userId: 'alice').params
            ..setTab(TasksPageTab.all)
            ..setView(TasksPageView.board);
        }
        await idle(const Duration(milliseconds: 600));
        final richCards = {
          if (find.byType(ArtifactMessageCard).evaluate().isNotEmpty)
            'artifact',
          if (find
              .byWidgetPredicate(
                (widget) =>
                    widget is AppLinkChip && widget.link is AppLinkPreview,
              )
              .evaluate()
              .isNotEmpty)
            'app-preview',
        };
        for (final workload in workloads) {
          if (fixture.scroll case final scroll? when workload != 'idle') {
            scroll.position.jumpTo(scroll.position.minScrollExtent);
          }
          final scene = 'list-$surface-$workload';
          final record = await lab.measure(
            tester,
            theme,
            scene,
            () async {
              final observations = await _measure(fixture, workload);
              if (tester.takeException() case final Object error) throw error;
              return observations;
            },
            kind: workload == 'idle' ? 'idle' : 'continuous',
            prepare: workload == 'idle' && fixture.replaysLive
                ? () async {
                    final position = fixture.scroll?.position;
                    position?.jumpTo(position.minScrollExtent);
                    final result = await _measure(fixture, 'live');
                    if (result['arrived'] != true) {
                      throw StateError('Post-motion replay did not arrive.');
                    }
                  }
                : null,
            evidence: (extras) => {
              'mountedRichCardsBeforeMotion': richCards.toList(),
              'arrival': {
                'arrived': extras['arrived'] == true && fixture.rows.isNotEmpty,
                'requirement': 'A visible product row, accepted motion, and accepted live updates where required.',
                'visibleKeys': fixture.rows
                    .take(12)
                    .map((element) => element.widget.key.toString())
                    .toList(),
              },
            },
          );
          if (record['failure'] case final Object error) {
            failures.add('$theme/$scene: $error');
          }
          if (tester.takeException() case final Object error) {
            failures.add('$theme/$scene: $error');
          }
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      }
    }
    return failures;
  }

  Future<Map<String, Object?>> _measure(
    _ListFixture fixture,
    String workload,
  ) async {
    final before = fixture.rows;
    if (before.isEmpty) {
      throw StateError(
        'No visible product rows. Missing routes: ${fixture.api.misses}',
      );
    }
    if (workload == 'idle') {
      final requestCounts = Map.of(fixture.api.hits);
      await idle(const Duration(seconds: 10));
      return {
        'arrived': true,
        'idleSeconds': 10,
        'fixtureRows': fixture.size,
        'requests': {
          for (final MapEntry(:key, :value) in fixture.api.hits.entries)
            if (value > (requestCounts[key] ?? 0))
              key: value - (requestCounts[key] ?? 0),
        },
      };
    }
    if (workload == 'live' && !fixture.replaysLive) {
      return {
        'arrived': false,
        'reason': 'This fixture has no accepted live update replay.',
      };
    }
    final scroll = fixture.scroll;
    if (scroll == null) {
      throw StateError('The visible rows have no vertical list.');
    }
    final position = scroll.position;
    final from = position.pixels;
    final towardsMax =
        position.maxScrollExtent - from > from - position.minScrollExtent;
    final target = towardsMax
        ? position.maxScrollExtent
        : position.minScrollExtent;
    final movement = <Map<String, int>>[];
    final accepted = <Map<String, Object?>>[];
    double last = from;
    void changed() {
      if (position.pixels == last) return;
      last = position.pixels;
      movement.add({'atUs': developer.Timeline.now, 'px': last.round()});
    }

    position.addListener(changed);
    try {
      final distance = (from - target).abs();
      if (distance < 100) {
        throw StateError('Scroll extent is only $distance px.');
      }
      if (workload == 'fling') {
        final axis = axisDirectionToAxis(position.axisDirection);
        final forward =
            towardsMax == (position.axisDirection == AxisDirection.down);
        if (axis != Axis.vertical) {
          throw StateError('Expected a vertical list.');
        }
        final lane = [
          for (final row in before)
            if (identical(Scrollable.maybeOf(row, axis: Axis.vertical), scroll))
              fixture.visibleRect(row),
        ]..sort((left, right) => left.top.compareTo(right.top));
        final first = lane.first;
        final start = fixture.surface == 'tasks-board' && lane.length > 1
            ? Offset(first.center.dx, (first.bottom + lane[1].top) / 2)
            : Offset(first.left + 12, first.center.dy);
        await tester.flingFrom(start, Offset(0, forward ? -160 : 160), 2200);
        await idle(const Duration(milliseconds: 1700));
      } else {
        final destination = (from + (towardsMax ? 1 : -1) * 900 * seconds)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
        final duration = Duration(seconds: seconds);
        await Future.wait([
          position.animateTo(
            destination,
            duration: duration,
            curve: Curves.linear,
          ),
          if (workload == 'live') _live(fixture, accepted, until: duration),
        ]);
      }
    } finally {
      position.removeListener(changed);
    }
    final moved = (last - from).abs();
    return {
      'arrived':
          moved >= 100 &&
          (workload != 'live' ||
              accepted.length == seconds * 2 - 1 &&
                  accepted.every((item) => item['accepted'] == true)),
      'fixtureRows': fixture.size,
      'movedPx': moved,
      'movement': movement,
      'live': accepted,
    };
  }

  Future<void> _live(
    _ListFixture fixture,
    List<Map<String, Object?>> accepted, {
    required Duration until,
  }) async {
    final clock = Stopwatch()..start();
    for (var tick = 1; tick * 500 < until.inMilliseconds; tick++) {
      final wait = Duration(milliseconds: tick * 500) - clock.elapsed;
      if (wait > Duration.zero) await idle(wait);
      final started = developer.Timeline.now;
      final result = await fixture.update(++fixture.liveTicks);
      accepted.add({'atUs': started, ...result});
    }
  }
}

class _ListFixture {
  _ListFixture(this.surface, this.workspace, this.api, this.client, this.feed);

  static const rowCount = 320;
  static const directoryAgentCount = 240;
  final String surface;
  final WorkspaceController workspace;
  int liveTicks = 0;
  late final projection = _ProjectionReplay(this);
  final LabAdapter api;
  final LabClient client;
  final LabChannel feed;
  TasksPageStore? tasksPage;
  TaskSurfaceController? discussion;
  late final Widget body;
  List<Map<String, dynamic>> activityRows = [];
  Iterable<Map> acceptedActivity = const [];
  List<Map<String, dynamic>> taskRows = [];
  List<Map<String, dynamic>> agentRows = [];
  int get size => surface == 'task-discussion' ? feed.rows.length : rowCount;
  bool get replaysLive => const {
    'chat',
    'thread',
    'activity',
    'task-discussion',
    'tasks-list',
    'tasks-board',
    'directory',
    'sidebar',
  }.contains(surface);

  Future<void> mount(
    WidgetTester tester, {
    required bool dark,
    bool touch = false,
  }) => tester.pumpWidget(
    AppServicesScope(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      child: MaterialApp(
        key: ValueKey(surface),
        theme: raftTheme(dark: dark),
        home: Scaffold(
          body: touch
              ? RaftInteractionScope(
                  interaction: RaftInteraction.touchMode,
                  child: body,
                )
              : body,
        ),
      ),
    ),
  );

  static Future<_ListFixture> open(String surface, LabImages images) async {
    const kinds = [
      ...mixCycle,
      'table',
      'math',
      'diagram',
      'forwarded',
      'artifact',
      'app-preview',
    ];
    final rows = List.generate(rowCount, (index) => kinds[index % kinds.length])
      ..setRange(rowCount - 4, rowCount - 2, ['artifact', 'app-preview']);
    final feed = LabChannel('list-feed', rows);
    final thread = LabChannel('list-thread', rows);
    final conversation = LabChannel('list-discussion', rows);
    for (final channel in [feed, thread, conversation]) {
      for (final (index, kind) in rows.indexed) {
        if (kind == 'artifact') {
          channel.rows[index]['content'] =
              'Lab artifact $index https://example.invalid/artifacts/$artifactShort';
        } else if (kind == 'app-preview') {
          channel.rows[index]['content'] =
              'Ticket ${_ticketUrl(channel.rows[index]['id'] as String)}';
        }
      }
    }
    final directory = [
      for (var index = 0; index < rowCount; index++)
        LabChannel('room-$index', const []),
    ];
    final (workspace, api, client) = await labWorkspace([
      feed,
      thread,
      conversation,
      ...directory,
    ], images);
    workspace.server = RaftRecord({'id': 's1', 'name': 'Lab', 'role': 'owner'});
    workspace.channel = feed.record;
    final source = switch (surface) {
      'thread' => thread,
      'task-discussion' => conversation,
      _ => feed,
    };
    final result = _ListFixture(surface, workspace, api, client, source);
    await result._install(directory, feed, thread, conversation, images);
    return result;
  }

  Future<void> _install(
    List<LabChannel> directory,
    LabChannel main,
    LabChannel thread,
    LabChannel conversation,
    LabImages images,
  ) async {
    final people = [
      for (var index = 0; index < rowCount - directoryAgentCount; index++)
        {
          'id': 'person-$index',
          'userId': 'person-$index',
          'name': 'Member $index',
          'displayName': 'Member $index',
          'role': 'member',
        },
    ];
    agentRows = [
      for (var index = 0; index < directoryAgentCount; index++)
        {
          'id': 'agent-$index',
          'name': 'Agent $index',
          'displayName': 'Agent $index',
          'activity': 'idle',
          'runtime': 'codex',
        },
    ];
    final tasks = TasksServer(
      tasks: [
        for (var index = 0; index < rowCount; index++)
          pageTask(
            'task-$index',
            number: index + 1,
            channelId: main.id,
            status: index.isEven ? 'todo' : 'in_progress',
            claimedBy: index % 4 == 0 ? 'alice' : null,
          ),
      ],
    );
    taskRows = tasks.tasks;
    const taskId = 'lab-discussion-task';
    final selectedTask = pageTask(
      taskId,
      number: 321,
      channelId: main.id,
      extra: {
        'channelType': 'channel',
        'conversationChannelId': conversation.id,
        'conversationReplyCount': conversation.rows.length,
      },
    );
    activityRows = [
      for (final (index, channel) in directory.indexed)
        {
          'kind': 'channel',
          'channelId': channel.id,
          'channelName': channel.record.name,
          'lastMessageId': '${channel.id}-1',
          'lastMessagePreview': 'Activity $index',
          'lastMessageAt': '2026-11-01T12:00:00Z',
          'unreadCount': 1,
        },
    ];
    api.routes.addAll({
      'POST /feature-flags/evaluate': (_) => {
        'evaluations': [
          {'key': 'workspace_artifacts_v0', 'enabled': true},
        ],
      },
      'POST /objects/summaries': (_) => {
        'kind': 'artifact',
        'summaries': [
          {
            'ref': {'id': artifactId},
            'ok': true,
            'summary': artifactCardJson(kind: 'csv', title: 'Lab artifact'),
          },
        ],
      },
      'GET /agents': (_) => agentRows,
      'GET /servers/s1/members': (_) => people,
      'GET /tasks/server': (request) => tasks.answer(request).$2,
      'GET /tasks/server/counts': (request) => tasks.answer(request).$2,
      'GET /tasks/channel/${main.id}/number/321': (_) => {'task': selectedTask},
      'GET /tasks/$taskId/history': (_) => {'events': []},
      'GET /integrations/clients': (_) => [],
      'GET /integrations/overview': (_) => [],
      'GET /channels/inbox': (request) => {
        ..._page(request, 'items', activityRows),
        'totalCount': activityRows.length,
        'totalUnreadCount': activityRows.length,
      },
      'GET /channels/saved': (request) => _page(request, 'saved', [
        ...projection.saved,
        for (final row in main.rows)
          {
            ...row,
            'messageId': row['id'],
            'channelName': main.record.name,
            'savedAt': row['createdAt'],
          },
      ]),
      'GET /messages/search': (request) => _page(request, 'results', [
        ...projection.search,
        for (final row in main.rows)
          {
            ...row,
            'content': 'Lab search result ${row['id']}',
            'channelName': main.record.name,
          },
      ]),
    });
    api.patterns.add((
      (request) =>
          request.method == 'GET' &&
          request.path.endsWith('/app-link-previews'),
      (request) => {
        'previews': [
          {
            'url': _ticketUrl(request.uri.pathSegments.reversed.elementAt(1)),
            'appName': 'Lab Tickets',
            'title': 'Lab ticket preview',
            'inline': {'title': 'Lab ticket'},
          },
        ],
      },
    ));
    if (_ProjectionReplay.supports(surface)) projection.bind(images);
    switch (surface) {
      case 'chat':
        await workspace.selectChannel(main.record);
        body = RaftChatView(controller: workspace);
      case 'thread':
        final parent = main.rows.last['id'] as String;
        api.routes['GET /messages/context/$parent'] = (_) => {
          'messages': [main.rows.last],
        };
        unawaited(
          workspace.openThreadIdentity(
            parentChannelId: main.id,
            parentMessageId: parent,
            initialThreadChannelId: thread.id,
            navigate: false,
          ),
        );
        body = RaftChatView(controller: workspace, thread: true);
      case 'task-discussion':
        final owner = discussion = TaskSurfaceController(
          parent: workspace,
          row: selectedTask,
          valid: () => true,
          taskKeyed: true,
        );
        unawaited(owner.start());
        body = SourceTaskSurface(
          owner: owner,
          inPlace: true,
          onClose: () {},
          onTask: null,
          onViewBilling: null,
        );
      case 'tasks-list':
      case 'tasks-board':
        final store = tasksPage = TasksPageStore.of(workspace);
        body = TasksPage(
          controller: workspace,
          currentTaskId: null,
          onOpenTask: (_) {},
          store: store,
        );
      case 'activity':
      case 'saved':
      case 'search':
        body = ResourceView(
          controller: workspace,
          section: surface,
          initialQuery: surface == 'search' ? 'Lab search result' : null,
          onMessage: (_, _) async {},
          onActivityWindowAccepted: surface == 'activity'
              ? (window, {bool firstPage = false}) {
                  if (firstPage && window?['items'] is List) {
                    acceptedActivity = (window!['items'] as List)
                        .whereType<Map>();
                  }
                }
              : null,
        );
      case 'files':
        body = SourceChannelFilesView(
          controller: workspace,
          channelId: main.id,
          formatCreatedAt: (instant) => instant.substring(0, 10),
        );
      case 'directory':
        body = DesktopDirectoryView(controller: workspace, onSelected: (_) {});
      case 'apps':
        body = IntegrationsView(controller: workspace, standalone: true);
      case 'sidebar':
        workspace.section = 'home';
        body = WorkspaceView(
          controller: workspace,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        );
    }
  }

  static Map<String, Object?> _page(
    RequestOptions request,
    String field,
    List<Map<String, dynamic>> rows,
  ) {
    final offset =
        int.tryParse(
          '${request.queryParameters['offset'] ?? request.queryParameters['cursor']}',
        ) ??
        0;
    final limit = int.tryParse('${request.queryParameters['limit']}') ?? 30;
    final slice = rows.skip(offset).take(limit).toList();
    return {
      field: slice,
      'total': rows.length,
      'globalTotal': rows.length,
      'hasMore': offset + slice.length < rows.length,
      'nextCursor': offset + slice.length < rows.length
          ? '${offset + slice.length}'
          : null,
    };
  }

  List<Element> get rows {
    final prefix = switch (surface) {
      'chat' || 'thread' || 'task-discussion' => 'message-${feed.id}-',
      'activity' => 'activity-channel-room-',
      'tasks-list' => 'tasks-page-row-cell-',
      'tasks-board' => 'task-board-card-',
      'search' => 'search-message:${feed.id}-',
      'files' => 'channel-file-file-',
      'directory' => 'desktop-directory-agent-',
      'apps' => 'connected-app-',
      'saved' => 'saved-${feed.id}-',
      'sidebar' => 'sidebar-channel-room-',
      _ => '',
    };
    return find
        .byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              (key.value.startsWith(prefix) ||
                  surface == 'directory' &&
                      key.value.startsWith('desktop-directory-human-'));
        })
        .evaluate()
        .where((row) => !visibleRect(row).isEmpty)
        .toList();
  }

  ScrollableState? get scroll => rows
      .map((element) => Scrollable.maybeOf(element, axis: Axis.vertical))
      .nonNulls
      .firstOrNull;

  static String _ticketUrl(String id) => 'https://tickets.example.org/$id';

  Rect visibleRect(Element element) {
    final box = element.renderObject;
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        box.size.isEmpty) {
      return Rect.zero;
    }
    final Object? viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport is! RenderBox || !viewport.hasSize) return Rect.zero;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return rect.intersect(viewport.localToGlobal(Offset.zero) & viewport.size);
  }

  Future<Map<String, Object?>> update(int tick) async {
    if (surface == 'activity') return _updateActivity(tick);
    if (surface == 'sidebar') {
      final id = 'room-live-$tick';
      const prefix = 'sidebar-channel-';
      final visible = rows.firstOrNull?.widget.key;
      final edited = visible is ValueKey<String>
          ? visible.value.substring(prefix.length)
          : null;
      final name = 'Renamed room $tick';
      final created = {
        'id': id,
        'serverId': 's1',
        'name': 'New room $tick',
        'joined': true,
        'type': 'public',
      };
      api.routes['GET /channels/$id'] = (_) => created;
      client.emit('channel:updated', {'channel': created});
      if (edited != null) {
        client.emit('channel:updated', {
          'channel': {'id': edited, 'serverId': 's1', 'name': name},
        });
      }
      await idle(const Duration(milliseconds: 250));
      return {
        'created': id,
        'edited': edited,
        'accepted':
            workspace.channels.any((channel) => channel.id == id) &&
            workspace.channels.any(
              (channel) => channel.id == edited && channel.name == name,
            ),
      };
    }
    if (surface == 'tasks-list' || surface == 'tasks-board') {
      final added = pageTask(
        'live-task-$tick',
        number: 1000 + tick,
        channelId: feed.id,
        claimedBy: 'alice',
      );
      taskRows.add(added);
      client.emit('task:created', {
        'channelId': feed.id,
        'tasks': [added],
      });
      final visible = rows
          .map((row) => (row.widget.key as ValueKey<String>).value)
          .map(
            (key) => key.replaceFirst(
              RegExp(r'^tasks-page-row-cell-|^task-board-card-'),
              '',
            ),
          )
          .map((id) => taskRows.where((row) => row['id'] == id).firstOrNull)
          .nonNulls
          .firstOrNull;
      if (visible != null) {
        visible['title'] = 'Edited during scroll $tick';
        client.emit('task:updated', {
          'channelId': feed.id,
          'task': Map.of(visible),
        });
      }
      final known = tasksPage!.knownById;
      return {
        'created': added['id'],
        'edited': visible?['id'],
        'accepted':
            known.containsKey(added['id']) &&
            visible != null &&
            known[visible['id']]?['title'] == visible['title'],
      };
    }
    if (surface == 'directory') {
      final id = 'live-agent-$tick';
      final agent = {...agentRows.first, 'id': id, 'name': 'Live agent $tick'};
      agentRows.add(agent);
      client.emit('agent:created', {'agent': agent});
      const prefix = 'desktop-directory-agent-';
      final visible = rows
          .map((row) => (row.widget.key as ValueKey<String>).value)
          .where((key) => key.startsWith(prefix))
          .firstOrNull;
      final edited = visible?.substring(prefix.length);
      final detail = 'Live update $tick';
      if (edited != null) {
        client.emit('agent:activity', {
          'agentId': edited,
          'activity': 'working',
          'detail': detail,
        });
      }
      return {
        'created': id,
        'edited': edited,
        'accepted':
            workspace.entityDirectory.agent(id) != null &&
            edited != null &&
            workspace.entityDirectory.agent(edited)?['activityDetail'] ==
                detail,
      };
    }
    final domain =
        discussion?.discussion?.messageDomain ?? workspace.messageDomain;
    final index = feed.rows.length;
    final added = labRow(
      feed.id,
      mixCycle[index % mixCycle.length],
      index,
      others: true,
    );
    feed.rows.add(added);
    client.emit('message:new', added);
    final visible = rows.firstOrNull?.widget.key;
    final id = visible is ValueKey<String>
        ? visible.value.substring('message-'.length)
        : null;
    final edited = feed.rows.where((row) => row['id'] == id).firstOrNull;
    final content = 'Live revision $tick';
    if (edited != null) {
      edited['content'] = content;
      client.emit('message:updated', Map.of(edited));
    }
    return {
      'created': added['id'],
      'edited': id,
      'accepted':
          domain.ledger.contains(feed.id, added['id'] as String) &&
          id != null &&
          domain.ledger.message(feed.id, id)?['content'] == content,
    };
  }

  Future<Map<String, Object?>> _updateActivity(int tick) async {
    final id = 'room-live-$tick';
    final message = 'activity-live-$tick';
    final createdAt = DateTime.utc(2026, 11, 1, 12, 0, tick).toIso8601String();
    const prefix = 'activity-channel-';
    final visible = rows.firstOrNull?.widget.key;
    final edited = visible is ValueKey<String>
        ? visible.value.substring(prefix.length)
        : null;
    final row = activityRows
        .where((row) => row['channelId'] == edited)
        .firstOrNull;
    final preview = 'Edited Activity $tick';
    if (row != null) row['lastMessagePreview'] = preview;
    activityRows.insert(0, {
      'kind': 'channel',
      'channelId': id,
      'channelName': 'New Activity $tick',
      'lastMessageId': message,
      'lastMessagePreview': 'New preview $tick',
      'lastMessageAt': createdAt,
      'latestActivitySeq': '1',
      'unreadCount': 1,
    });
    client.emit('message:new', {
      ...labRow(id, 'short', 0, others: true),
      'id': message,
      'createdAt': createdAt,
    });
    if (row != null) {
      client.emit('message:updated', {
        'id': row['lastMessageId'],
        'channelId': edited,
        'content': preview,
      });
    }
    await idle(const Duration(milliseconds: 275));
    return {
      'created': id,
      'edited': edited,
      'accepted':
          acceptedActivity.any((row) => row['lastMessageId'] == message) &&
          edited != null &&
          acceptedActivity.any(
            (row) =>
                row['channelId'] == edited &&
                row['lastMessagePreview'] == preview,
          ),
    };
  }

  void dispose() {
    discussion?.dispose();
    tasksPage?.dispose();
    workspace.dispose();
  }
}
