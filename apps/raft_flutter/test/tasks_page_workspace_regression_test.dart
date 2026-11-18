import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/task_content_slot.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/tasks_page/tasks_list_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'support/app_services_fixture.dart';
import 'task_content_slot_test.dart' show mountTasks, settle, v2Task;
import 'task_surface_test.dart' show taskRoutes;
import 'workspace_source_location_contract_test.dart' show pageFixture;

const desktop = Size(1280, 800);
final slot = find.byKey(const ValueKey('task-content-slot'));
final topBar = find.byType(RaftWorkspaceTopBar);
final close = find.byKey(const ValueKey('task-modal-close'));
final row = find.byKey(const ValueKey('tasks-page-row-cell-task-1'));
final card = find.byKey(const ValueKey('task-board-card-task-1'));

Future<(WorkspaceController, MessageAdapter)> mount(
  WidgetTester t, {
  bool older = false,
  bool dark = false,
}) async {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = desktop;
  addTearDown(t.view.reset);
  final (w, api) = await pageFixture(t, section: 'tasks');
  final task = {
    ...v2Task,
    if (older) ...{
      'messageId': 'task-parent',
      'hostMessageId': 'task-parent',
      'sourceMessageId': 'task-parent',
      'conversationAnchored': false,
      'conversationChannelId': null,
    },
  };
  taskRoutes(api, task);
  api.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'task_v2_conversations_v0', 'enabled': true},
    ],
  };
  api.routes['GET /tasks/task-1'] = (_) => {'task': task};
  api.routes['GET /tasks/channel/c1'] = (_) => {
    'tasks': [task],
  };
  api.routes['GET /messages/channel/task-conv'] = (_) => {'messages': []};
  api.routes['POST /channels/task-conv/read'] = (_) => {};
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await settle(t);
  return (w, api);
}

void main() {
  final linux = TargetPlatformVariant({TargetPlatform.linux});
  for (final (label, older) in [('older', true), ('v2', false)]) {
    for (final board in [false, true]) {
      final view = board ? 'board' : 'list';
      testWidgets('$label task opens below the top bar from the $view', (
        t,
      ) async {
        final (w, _) = await mount(t, older: older, dark: board);
        final target = board ? card : row;
        if (board) {
          await t.tap(find.byKey(const ValueKey('tasks-page-view-board')));
          await settle(t);
        }
        expect(topBar, findsOneWidget);
        expect(target.hitTestable(), findsOneWidget);
        await t.tap(target);
        await settle(t);

        expect(w.location.query('open'), 'task:task-1');
        expect(w.location.query('task'), 'c1:task:task-1');
        expect(slot, findsOneWidget);
        expect(
          t.widget<SourceTaskSurface>(find.byType(SourceTaskSurface)).inPlace,
          isTrue,
        );
        expect(t.getTopLeft(slot).dy, t.getBottomLeft(topBar).dy);
        expect(
          t.getRect(target).right,
          lessThanOrEqualTo(t.getRect(slot).left + 1),
        );
        final seam = find.ancestor(
          of: slot,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.position == DecorationPosition.foreground &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border ==
                    RaftPanelEdge.left(t.element(slot)),
          ),
        );
        expect(seam, findsOneWidget);
        expect(t.getTopLeft(seam), t.getTopLeft(slot));
        expect(
          find
              .descendant(
                of: slot,
                matching: find.byKey(const ValueKey('task-overflow-trigger')),
              )
              .hitTestable(),
          findsOneWidget,
        );
        await t.tap(close);
        await t.pump();
        expect(slot, findsNothing);
        expect(target, findsOneWidget);
        expect(find.byType(TasksListSkeleton), findsNothing);
        await t.pumpWidget(const SizedBox());
      }, variant: linux);
    }
  }

  testWidgets('a Search task hit still opens in its detail column', (t) async {
    final w = await mountTasks(t, desktop, section: 'search');
    expect(
      openTaskFromList(w, {
        'channelType': 'task',
        'taskId': 'task-1',
        'parentChannelId': 'c1',
      }, wide: true),
      isTrue,
    );
    await settle(t);
    expect(w.location.route, RaftRoute.search);
    expect(w.location.query('open'), 'task:task-1');
    expect(slot, findsOneWidget);
    await t.tap(close);
    await settle(t);
    expect(slot, findsNothing);
    expect(w.location.route, RaftRoute.search);
    await t.pumpWidget(const SizedBox());
  }, variant: linux);

  for (final (mine, board) in [(true, false), (false, false), (true, true)]) {
    final tab = mine ? 'Mine' : 'All';
    final view = board ? 'board' : 'list';
    testWidgets('$tab $view paints held Tasks before revalidating on return', (
      t,
    ) async {
      final (w, api) = await mount(t);
      final heldTask = board ? card : row;
      final skeleton = board
          ? find.byKey(const ValueKey('tasks-page-loading'))
          : find.byType(TasksListSkeleton);
      if (board) {
        await t.tap(find.byKey(const ValueKey('tasks-page-view-board')));
        await settle(t);
      }
      if (!mine) {
        await t.tap(find.byKey(const ValueKey('tasks-page-tab-all')));
        await settle(t);
        await t.enterText(
          find.byKey(const ValueKey('tasks-page-search')),
          'Scoped',
        );
        await t.pump(const Duration(milliseconds: 500));
        await settle(t);
      }
      expect(heldTask, findsOneWidget);
      await t.tap(find.byKey(const ValueKey('rail-chat')));
      await settle(t);
      expect(w.location.route, RaftRoute.channel);
      expect(heldTask, findsNothing);
      api.calls.clear();

      const counts = '/tasks/server/counts';
      const tasks = '/tasks/server';
      final refresh = Completer<void>();
      final readCounts = api.routes['GET $counts']!;
      api.routes['GET $counts'] = (request) async {
        if (request.queryParameters.containsKey('completed_since')) {
          await refresh.future;
        }
        return readCounts(request);
      };
      Iterable<RequestOptions> reads() => api.calls.where(
        (request) => request.path == tasks || request.path == counts,
      );
      const relations = ['created_by_me', 'from_my_message'];
      List<String> signatures() => [
        for (final request in reads())
          '${request.path}:${request.queryParameters['relation']}',
      ];

      await t.tap(find.byKey(const ValueKey('rail-tasks')));
      await t.pump();
      try {
        expect(w.location.route, RaftRoute.tasks);
        expect(heldTask, findsOneWidget);
        expect(skeleton, findsNothing);
        if (!mine) {
          expect(
            t.widget<EditableText>(find.byType(EditableText)).controller.text,
            'Scoped',
          );
        }
        await settle(t);
        expect(heldTask, findsOneWidget);
        expect(skeleton, findsNothing);
        expect(
          signatures(),
          unorderedEquals([
            for (final relation in relations) '$counts:$relation',
          ]),
        );
      } finally {
        refresh.complete();
      }

      await settle(t);
      expect(heldTask, findsOneWidget);
      expect(skeleton, findsNothing);
      expect(
        signatures(),
        unorderedEquals([
          for (final relation in relations) '$counts:$relation',
          if (mine && !board)
            for (final relation in relations) '$tasks:$relation',
        ]),
      );
      expect(
        reads()
            .map((request) => request.queryParameters['completed_since'])
            .toSet(),
        hasLength(1),
      );
      expect(
        reads().every(
          (request) =>
              request.queryParameters['completed_since'] is String &&
              (request.path != tasks ||
                  request.queryParameters['limit'] == '20'),
        ),
        isTrue,
      );
      await t.pumpWidget(const SizedBox());
    }, variant: linux);
  }
}
