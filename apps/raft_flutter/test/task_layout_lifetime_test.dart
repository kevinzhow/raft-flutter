import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_activity_activation_test.dart' show message;
import 'workspace_source_location_contract_test.dart'
    show pageFixture, mountPage;

final _other = <String, dynamic>{
  ...modernTask,
  'id': 'task-2',
  'taskNumber': 9,
  'messageId': 'other-parent',
  'threadChannelId': 'other-thread',
  'title': 'Other actual task',
};

Future<(WorkspaceController, MessageAdapter)> _fixture(WidgetTester t) async {
  final (w, api) = await pageFixture(t, section: 'tasks');
  taskRoutes(api, modernTask);
  final tasks = [modernTask, _other];
  for (final endpoint in ['/tasks/server', '/tasks/channel/c1']) {
    api.routes['GET $endpoint'] = (r) => {
      'tasks': tasks
          .where(
            (task) =>
                r.queryParameters['status'] == null ||
                r.queryParameters['status'] == task['status'],
          )
          .toList(),
      'next_cursor': null,
    };
  }
  api.routes['GET /tasks/channel/c1/number/9'] = (_) => {'task': _other};
  api.routes['GET /tasks/task-2/history'] = (_) => {'events': []};
  api.routes['GET /messages/context/other-parent'] = (_) => {
    'messages': [message('other-parent', 'c1')],
  };
  api.routes['GET /messages/channel/other-thread'] = (_) => {'messages': []};
  api.routes['POST /channels/other-thread/read'] = (_) => {};
  api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
  api.routes['GET /announcements/active'] = (_) => {'announcements': []};
  return (w, api);
}

Finder _editor() => find.descendant(
  of: find.descendant(
    of: find.byType(SourceTaskSurface),
    matching: find.byType(RaftComposer),
  ),
  matching: find.byType(TextField),
);

Future<void> _open(WidgetTester t, String title) async {
  await t.tap(find.text(title));
  await flush(t);
  await t.pumpAndSettle();
  expect(find.byType(SourceTaskSurface), findsOneWidget);
  expect(_editor(), findsOneWidget);
}

Future<void> _close(WidgetTester t) async {
  await t.tap(find.byTooltip('Close Task'));
  await flush(t);
  await t.pumpAndSettle();
  expect(find.byType(SourceTaskSurface), findsNothing);
}

void main() {
  testWidgets(
    'Task close, reopen, task switch and system Back keep drafts scoped',
    (t) async {
      final (w, _) = await _fixture(t);
      w.drafts['c1'] = 'Existing main conversation draft';
      await mountPage(t, w, false, width: 1440);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pump();
      });
      await _open(t, 'Scoped actual task');
      await t.enterText(_editor(), 'Draft for first task');
      await flush(t);
      await _close(t);
      await _open(t, 'Other actual task');
      expect(t.widget<TextField>(_editor()).controller!.text, isEmpty);
      await t.enterText(_editor(), 'Draft for second task');
      await flush(t);
      await _close(t);
      await _open(t, 'Scoped actual task');
      expect(
        t.widget<TextField>(_editor()).controller!.text,
        'Draft for first task',
      );
      t.view.physicalSize = const Size(390, 844);
      await t.pumpAndSettle();
      await flush(t);
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(_editor()).controller!.text,
        'Draft for first task',
      );
      await t.binding.handlePopRoute();
      await flush(t);
      await t.pumpAndSettle();
      expect(find.byType(SourceTaskSurface), findsNothing);
      await _open(t, 'Other actual task');
      expect(
        t.widget<TextField>(_editor()).controller!.text,
        'Draft for second task',
      );
      t.view.physicalSize = const Size(1440, 900);
      await t.pumpAndSettle();
      await flush(t);
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(_editor()).controller!.text,
        'Draft for second task',
      );
      expect(w.drafts['c1'], 'Existing main conversation draft');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Pending task metadata accepts its result after phone to wide resize',
    (t) async {
      final (w, api) = await _fixture(t);
      final pending = Completer<Map<String, dynamic>>();
      api.routes['GET /tasks/channel/c1/number/8'] = (_) => pending.future;
      addTearDown(() {
        if (!pending.isCompleted) pending.complete({'task': modernTask});
      });
      await mountPage(t, w, false, width: 390);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pump();
      });
      await t.tap(find.text('Scoped actual task'));
      await flush(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(_editor(), findsOneWidget);
      await t.enterText(_editor(), 'Typed while metadata is loading');
      await flush(t);
      expect(
        t.widget<TextField>(_editor()).controller!.text,
        'Typed while metadata is loading',
      );
      expect(
        api.calls.any((r) => r.path == '/tasks/channel/c1/number/8'),
        isTrue,
      );
      expect(pending.isCompleted, isFalse);
      t.view.physicalSize = const Size(1440, 900);
      await t.pump();
      await flush(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(
        t.widget<TextField>(_editor()).controller!.text,
        'Typed while metadata is loading',
      );
      await t.runAsync(() async {
        pending.complete({
          'task': {...modernTask, 'title': 'Fresh metadata after resize'},
        });
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await flush(t);
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SourceTaskSurface),
          matching: find.text('Fresh metadata after resize'),
        ),
        findsOneWidget,
      );
      expect(
        t.widget<TextField>(_editor()).controller!.text,
        'Typed while metadata is loading',
      );
      await _close(t);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('A retired task edit cannot write into a reset server composer', (
    t,
  ) async {
    final (w, _) = await _fixture(t);
    await mountPage(t, w, false, width: 1440);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });
    await _open(t, 'Scoped actual task');
    await t.enterText(_editor(), 'Draft before authority changed');
    await flush(t);
    final composer = t.widget<RaftComposer>(
      find.descendant(
        of: find.byType(SourceTaskSurface),
        matching: find.byType(RaftComposer),
      ),
    );
    final queuedEdit = composer.onDraftChanged;
    await t.runAsync(() async {
      final selecting = w.selectServer(
        RaftRecord({...w.server!.json, 'role': 'removed'}),
      );
      expect(w.composer.drafts, isEmpty);
      // A callback captured by the old visible editor may already be queued
      // when the server selection resets its owner, before the next UI frame.
      queuedEdit?.call('Late edit from the retired task');
      expect(w.composer.drafts, isEmpty);
      await selecting;
    });
    await flush(t);
    expect(find.byType(SourceTaskSurface), findsNothing);
    expect(t.takeException(), isNull);
  });
}
