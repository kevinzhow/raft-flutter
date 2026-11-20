import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/task_surface.dart';

import 'message_context_transition_test.dart' show row;
import 'task_content_slot_test.dart'
    show card, mountTasks, settle, slot, v2Task;
import 'task_surface_test.dart' show taskRoutes;
import 'workspace_source_location_contract_test.dart'
    show frames, mountPage, pageFixture, waitForPainted;

final _task = find.byType(SourceTaskSurface);
final _bar = find.descendant(
  of: _task,
  matching: find.byKey(const ValueKey('task-modal-bar')),
);
final _toggle = find.descendant(
  of: _bar,
  matching: find.byKey(const ValueKey('task-details-toggle')),
);
final _title = find.byKey(const ValueKey('task-modal-title'));
final _drawer = find.byKey(const ValueKey('task-head-pull-down'));
final _titleInDrawer = find.descendant(of: _drawer, matching: _title);
final _back = find.byKey(const ValueKey('task-modal-mobile-back'));

Future<void> Function(WidgetTester) _disposeWorkspaceAfter(
  Future<void> Function(WidgetTester) run,
) => (tester) async {
  try {
    await run(tester);
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }
};

void main() {
  testWidgets(
    'narrow Linux Activity drawer preserves the task draft and reading position',
    _disposeWorkspaceAfter((t) async {
      final w = await mountTasks(
        t,
        const Size(390, 844),
        section: 'activity',
        platform: TargetPlatform.linux,
        discussionMessages: [
          for (var i = 1; i <= 40; i++)
            row('activity-reply-$i', 'task-conv', i),
        ],
      );
      final entry = find.byKey(const ValueKey('activity-thread-task-conv'));
      expect(entry.hitTestable(), findsOneWidget);
      await t.tap(entry, kind: PointerDeviceKind.mouse);
      await settle(t);
      expect(_task, findsOneWidget);
      expect(w.location.route, RaftRoute.activity);
      expect(w.location.query('task'), 'c1:task:task-1');
      await waitForPainted(t, 'activity-reply-40');

      expect(_title, findsNothing, reason: 'full-page details start collapsed');
      expect(_drawer, findsNothing);
      expect(_toggle.hitTestable(), findsOneWidget);

      final editor = find.descendant(
        of: _task,
        matching: find.byType(EditableText),
      );
      const draft = 'Draft from the Activity task';
      await t.enterText(editor, draft);
      await t.pump();
      final timeline = find.descendant(
        of: _task,
        matching: find.byKey(const ValueKey('timeline-focus')),
      );
      ScrollPosition position() => Scrollable.of(t.element(timeline)).position;
      final latest = position().pixels;
      await t.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: t.getCenter(timeline),
          scrollDelta: const Offset(0, -320),
        ),
      );
      await settle(t);
      final readingOffset = position().pixels;
      final readingHeight = position().viewportDimension;
      expect((readingOffset - latest).abs(), greaterThan(40));

      void expectDiscussionUnchanged() {
        expect(w.location.query('task'), 'c1:task:task-1');
        expect(t.widget<EditableText>(editor).controller.text, draft);
        expect(position().pixels, closeTo(readingOffset, 0.1));
        expect(position().viewportDimension, readingHeight);
      }

      await t.tap(_toggle, kind: PointerDeviceKind.mouse);
      await settle(t);
      expect(t.widget<Text>(_titleInDrawer).data, v2Task['title']);
      expect(_toggle.hitTestable(), findsOneWidget);
      expectDiscussionUnchanged();

      await t.tap(_toggle, kind: PointerDeviceKind.mouse);
      await settle(t);
      expect(_drawer, findsNothing);
      expect(_title, findsNothing);
      expectDiscussionUnchanged();

      await t.tap(_back, kind: PointerDeviceKind.mouse);
      await settle(t);
      expect(_task, findsNothing);
      expect(w.location.route, RaftRoute.activity);
      expect(w.location.query('task'), isNull);
      expect(entry.hitTestable(), findsOneWidget);
    }),
  );

  testWidgets(
    'Android Tasks card opens with an inline head and a single empty state',
    _disposeWorkspaceAfter((t) async {
      final w = await mountTasks(
        t,
        const Size(390, 844),
        platform: TargetPlatform.android,
      );
      final toolbar = find.byKey(const ValueKey('tasks-page-toolbar'));
      expect(t.getSize(toolbar).height, 89);
      await t.tap(card.hitTestable(), kind: PointerDeviceKind.touch);
      await settle(t);
      expect(_task, findsOneWidget);
      expect(w.location.query('task'), 'c1:task:task-1');
      expect(t.widget<Text>(_title.hitTestable()).data, v2Task['title']);
      expect(t.getSize(_bar).height, 56);
      expect(_toggle, findsNothing);
      expect(_drawer, findsNothing);
      expect(find.text('No discussion in this task yet'), findsOneWidget);
      expect(find.text('No replies yet'), findsNothing);

      await t.tap(_back.hitTestable(), kind: PointerDeviceKind.touch);
      await settle(t);
      expect(_task, findsNothing);
      expect(w.location.query('task'), isNull);
      expect(card.hitTestable(), findsOneWidget);
    }),
  );

  for (final size in [const Size(856, 944), const Size(944, 856)]) {
    testWidgets(
      'Android Search task slot starts with details collapsed at $size',
      _disposeWorkspaceAfter((t) async {
        final (w, api) = await pageFixture(t, section: 'search');
        w.navigation.navigate(
          RaftLocation.parse('/s/demo/search?q=needle'),
          kind: RaftNavigationKind.replace,
        );
        const replyId = 'matched-reply';
        final reply = row(replyId, 'task-conv', 7);
        api.routes['GET /messages/search'] = (_) => {
          'results': [
            {
              ...reply,
              'channelName': 'task-task-1',
              'channelType': 'task',
              'parentChannelId': 'c1',
              'parentChannelName': 'test',
              'parentChannelType': 'channel',
              'taskId': 'task-1',
              'taskNumber': 8,
              'taskTitle': v2Task['title'],
              'senderType': 'user',
              'senderName': 'Alice',
              'snippet': 'needle in the task',
            },
          ],
          'hasMore': false,
        };
        taskRoutes(api, v2Task);
        api.routes['GET /tasks/channel/c1'] = (_) => {
          'tasks': [v2Task],
        };
        api.routes['GET /messages/channel/task-conv'] = (_) => {
          'messages': [row('latest-reply', 'task-conv', 8)],
        };
        api.routes['GET /messages/context/$replyId'] = (_) => {
          'messages': [reply],
        };
        api.routes['POST /channels/task-conv/read'] = (_) => {};
        await mountPage(
          t,
          w,
          false,
          width: size.width,
          height: size.height,
          platform: TargetPlatform.android,
        );
        await frames(t, () {});

        final hit = find.byKey(const ValueKey('search-message:$replyId'));
        expect(hit.hitTestable(), findsOneWidget);
        await t.tap(hit, kind: PointerDeviceKind.touch);
        await waitForPainted(t, replyId);
        await settle(t);
        expect(w.location.query('open'), 'task:task-1');
        expect(w.location.query('task'), 'c1:task:task-1');
        expect(slot, findsOneWidget);
        final pinnedTitle = find.descendant(of: slot, matching: _title);
        expect(pinnedTitle, findsNothing);
        expect(_drawer, findsNothing);
        expect(_toggle.hitTestable(), findsOneWidget);

        await t.tap(_toggle, kind: PointerDeviceKind.touch);
        await settle(t);
        expect(t.widget<Text>(pinnedTitle).data, v2Task['title']);
        expect(_drawer, findsNothing);
        expect(slot, findsOneWidget);
        expect(w.location.query('task'), 'c1:task:task-1');

        await t.tap(_toggle, kind: PointerDeviceKind.touch);
        await settle(t);
        expect(pinnedTitle, findsNothing);
        expect(_drawer, findsNothing);

        await t.tap(
          find.byKey(const ValueKey('task-modal-close')),
          kind: PointerDeviceKind.touch,
        );
        await settle(t);
        expect(slot, findsNothing);
        expect(w.location.route, RaftRoute.search);
        expect(w.location.query('task'), isNull);
        expect(hit.hitTestable(), findsOneWidget);
      }),
    );
  }
}
