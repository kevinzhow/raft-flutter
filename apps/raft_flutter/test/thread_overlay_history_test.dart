import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;

// Mounted thread / task-overlay history contracts (Web rightPanelUrlSync and
// mobileBackNavigation). The fake client answers every REST read from
// in-memory routes, so each request resolves in the test's fake-async zone.
class OverlayClient extends RaftClient {
  OverlayClient()
    : super(
        origin: 'https://overlay-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  final routes = <String, FutureOr<dynamic> Function(Map<String, dynamic>?)>{};
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's1', 'slug': 'demo', 'name': 'Demo', 'role': 'owner'}),
  ];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    final key = '$method $path';
    calls.add(key);
    final route = routes[key];
    if (route != null) return await route(query);
    if (method == 'POST' && path.endsWith('/read')) {
      return {'maxReadSeq': '9', 'readStateVersion': '1'};
    }
    if (key == 'POST /feature-flags/evaluate') return {'evaluations': []};
    if (key == 'GET /channels/threads/followed') return {'threads': []};
    if (key == 'GET /channels/inbox') return {'items': []};
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    throw RaftApiException('No fixture for $key', status: 404);
  }

  int count(String key) => calls.where((call) => call == key).length;
}

Map<String, dynamic> message(String id, String channel, int seq) => {
  'id': id,
  'channelId': channel,
  'serverId': 's1',
  'seq': '$seq',
  'senderId': 'alice',
  'senderType': 'user',
  'content': 'Message $id',
  'createdAt': '2026-10-08T00:00:${seq.toString().padLeft(2, '0')}Z',
};

Map<String, dynamic> taskRow(String messageId, {String? threadChannelId}) => {
  'id': 'task-$messageId',
  'taskNumber': 8,
  'title': 'Overlay task',
  'description': 'Task over a thread',
  'channelId': 'c1',
  'channelName': 'general',
  'messageId': messageId,
  'threadChannelId': ?threadChannelId,
  'status': 'todo',
  'createdByType': 'user',
  'createdById': 'alice',
  'createdByName': 'Alice',
};

class Fixture {
  Fixture(this.w, this.client);
  final WorkspaceController w;
  final OverlayClient client;
}

/// Channel c1 holds the thread parent p1 ([replyCount] replies in t1) and an
/// independent task message. [task] is the channel's accepted task row.
Future<Fixture> overlayFixture(
  WidgetTester t, {
  required double width,
  required Map<String, dynamic> task,
  RaftFamily family = RaftFamily.elegant,
  int replyCount = 3,
  Map<String, dynamic>? summary,
  Completer<Map<String, dynamic>>? heldReplies,
}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = Size(width, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = OverlayClient()..selectServer('s1');
  final general = RaftChannel({
    'id': 'c1',
    'name': 'general',
    'type': 'channel',
    'joined': true,
  });
  final w = WorkspaceController(client)
    ..server = RaftRecord({
      'id': 's1',
      'slug': 'demo',
      'name': 'Demo',
      'role': 'owner',
    })
    ..channels = [general]
    ..channel = general
    ..loading = false;
  w.ledger.switchServer('s1');
  w.section = 'chat';
  final mainRows = [
    message('p1', 'c1', 1),
    message('task-parent', 'c1', 2),
    message('tail', 'c1', 3),
  ];
  w.ledger.ingest(mainRows, expectedGeneration: w.ledger.generation);
  w.visibleIds['c1'] = {for (final row in mainRows) row['id'] as String};
  w.threadSummaries = {
    'p1': summary ?? {'replyCount': replyCount, 'unreadCount': 0},
  };
  final replies = [
    for (var i = 1; i <= replyCount; i++) message('r$i', 't1', i),
  ];
  client.routes['GET /messages/channel/c1'] = (_) => {'messages': mainRows};
  client.routes['GET /messages/context/p1'] = (_) => {
    'messages': mainRows,
    'targetMessageId': 'p1',
  };
  client.routes['GET /channels/c1/threads/p1'] = (_) => {
    'threadChannelId': 't1',
  };
  client.routes['GET /messages/channel/t1'] = (_) =>
      heldReplies?.future ?? {'messages': replies};
  for (final reply in replies) {
    client.routes['GET /messages/context/${reply['id']}'] = (_) => {
      'messages': replies,
      'targetMessageId': reply['id'],
    };
  }
  client.routes['GET /tasks/channel/c1'] = (_) => {
    'tasks': [task],
    'nextCursor': null,
  };
  client.routes['GET /tasks/channel/c1/number/8'] = (_) => {'task': task};
  client.routes['GET /tasks/${task['id']}/history'] = (_) => {
    'events': <dynamic>[],
  };
  client.routes['GET /servers/s1/members'] = (_) => <dynamic>[];
  client.routes['GET /agents'] = (_) => <dynamic>[];
  final taskThread = task['threadChannelId'];
  if (taskThread is String && taskThread != 't1') {
    client.routes['GET /messages/channel/$taskThread'] = (_) => {
      'messages': <dynamic>[],
    };
  }
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family),
      home: WorkspaceView(
        controller: w,
        appearance: RaftAppearance(light: family),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
  await frames(t);
  return Fixture(w, client);
}

/// Fixed-duration frames: no real time passes, every fake-async microtask and
/// short UI timer runs.
Future<void> frames(
  WidgetTester t, {
  int count = 8,
  void Function()? check,
}) async {
  for (var i = 0; i < count; i++) {
    await t.pump(const Duration(milliseconds: 16));
    check?.call();
  }
}

/// The workspace's own side/mobile thread timeline (not a task discussion).
Finder threadTimeline() => find.byWidgetPredicate(
  (widget) =>
      widget is RaftChatView && widget.thread && widget.selectionHandle != null,
);

ScrollPosition threadScroll(WidgetTester t) => t
    .state<ScrollableState>(
      find
          .descendant(of: threadTimeline(), matching: find.byType(Scrollable))
          .first,
    )
    .position;

/// Opens p1's thread with the actual replies badge in the channel timeline.
Future<void> openThreadFromBadge(WidgetTester t, Fixture f) async {
  await t.tap(find.byKey(const ValueKey('thread-replies-badge-p1')));
  await frames(t);
  expect(f.w.location.thread?.itemId, 'p1');
  expect(threadTimeline(), findsOneWidget);
  expect(paintedMessage(t, 'r1'), isNotNull);
}

const families = [RaftFamily.brutal, RaftFamily.elegant];

void main() {
  for (final family in families) {
    for (final width in [1280.0, 390.0]) {
      final mobile = width < 768;
      final name = '${family.name}/${mobile ? 'phone' : 'desktop'}';
      testWidgets(
        '[N04] $name task card over an open thread keeps the thread and pushes one entry',
        (t) async {
          // Web rightPanelUrlSyncContract 385–448: the task slot is written
          // next to the side thread (PUSH); the thread anchor stays.
          final f = await overlayFixture(
            t,
            width: width,
            family: family,
            // Phone: the only visible task chip is the thread parent's own;
            // desktop: an independent message in the channel beside it.
            task: mobile
                ? taskRow('p1', threadChannelId: 't1')
                : taskRow('task-parent', threadChannelId: 'task-thread'),
          );
          final w = f.w;
          await openThreadFromBadge(t, f);
          final origin = w.location,
              originIndex = w.navigation.index,
              originEntries = w.navigation.entries.length,
              timeline = t.state(threadTimeline()),
              generation = w.threadGeneration,
              lookups = f.client.count('GET /channels/c1/threads/p1'),
              tails = f.client.count('GET /messages/channel/t1');
          expect(origin.task, isNull);
          final chip = find
              .byKey(ValueKey('message-task-${mobile ? 'p1' : 'task-parent'}'))
              .hitTestable();
          expect(chip, findsOneWidget);
          await t.tap(chip);
          await frames(
            t,
            check: () {
              // The thread is never retired or re-presented while the task
              // card opens over it.
              expect(w.threadGeneration, generation);
              expect(w.threadLoading, isFalse);
              expect(t.state(threadTimeline()), same(timeline));
            },
          );
          expect(find.byType(SourceTaskSurface), findsOneWidget);
          expect(
            w.location.task?.toString(),
            mobile ? 'c1:p1' : 'c1:task-parent',
          );
          expect(w.location.thread?.toString(), 'c1:p1');
          // Exactly one new history entry; the thread entry is untouched.
          expect(w.navigation.entries.length, originEntries + 1);
          expect(w.navigation.index, originIndex + 1);
          expect(w.navigation.entries[originIndex], origin);
          expect(w.location.withQuery({'task': null}), origin);
          expect(w.threadChannelId, 't1');
          expect(f.client.count('GET /channels/c1/threads/p1'), lookups);
          if (!mobile) {
            // Phone's task discussion is this same thread channel; it
            // reads it through its own controller.
            expect(f.client.count('GET /messages/channel/t1'), tails);
            expect(paintedMessage(t, 'r1'), isNotNull);
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      '[N05] ${family.name}/desktop closing the task card keeps the thread in place without history',
      (t) async {
        // Web rightPanelUrlSyncContract 492–511: dropping task closes only the
        // task slot; the side thread stays open and is not re-opened.
        final f = await overlayFixture(
          t,
          width: 1280,
          family: family,
          replyCount: 40,
          task: taskRow('task-parent', threadChannelId: 'task-thread'),
        );
        final w = f.w;
        await t.tap(find.byKey(const ValueKey('thread-replies-badge-p1')));
        await frames(t);
        expect(threadTimeline(), findsOneWidget);
        // Move the thread away from its initial position so a reload or a
        // re-anchor would be visible as a jump.
        final initial = threadScroll(t).pixels;
        await t.drag(threadTimeline(), const Offset(0, 300));
        await frames(t);
        final scrolled = threadScroll(t).pixels;
        expect(scrolled, isNot(initial));
        final visible = [
          for (var i = 1; i <= 40; i++)
            if (paintedMessage(t, 'r$i') != null) 'r$i',
        ];
        expect(visible, isNotEmpty);
        final anchor = visible[visible.length ~/ 2];
        final anchorRect = paintedMessage(t, anchor);
        final timeline = t.state(threadTimeline()),
            generation = w.threadGeneration,
            calls = f.client.calls.length;
        void unchanged() {
          expect(t.state(threadTimeline()), same(timeline));
          expect(w.threadGeneration, generation);
          expect(w.threadLoading, isFalse);
          expect(w.threadChannelId, 't1');
          expect(threadScroll(t).pixels, scrolled);
          expect(paintedMessage(t, anchor), anchorRect);
        }

        await t.tap(
          find.byKey(const ValueKey('message-task-task-parent')).hitTestable(),
        );
        await frames(t, check: unchanged);
        expect(find.byType(SourceTaskSurface), findsOneWidget);
        final withTask = w.location,
            entries = w.navigation.entries.length,
            index = w.navigation.index;
        expect(withTask.task?.toString(), 'c1:task-parent');

        await t.tap(find.byTooltip('Close task').hitTestable().first);
        await frames(t, check: unchanged);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(w.location, withTask.withQuery({'task': null}));
        expect(w.location.thread?.toString(), 'c1:p1');
        // Close replaces its own slot: no new entry, same position.
        expect(w.navigation.entries.length, entries);
        expect(w.navigation.index, index);
        // Nothing about the thread was requested again.
        final after = f.client.calls.sublist(calls);
        expect(
          after.where(
            (c) =>
                c.contains('/threads/p1') ||
                c == 'GET /messages/channel/t1' ||
                c.startsWith('GET /messages/context/r'),
          ),
          isEmpty,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );

    for (final systemBack in [false, true]) {
      testWidgets(
        '[N17] ${family.name}/phone ${systemBack ? 'system Back' : 'task Back control'} closes the task first and restores the exact thread entry',
        (t) async {
          // Web mobileBackNavigation.behavior 389–428: the task sheet owns a
          // PUSH over the thread; Back restores the exact origin URL.
          final f = await overlayFixture(
            t,
            width: 390,
            family: family,
            task: taskRow('p1', threadChannelId: 't1'),
          );
          final w = f.w;
          await openThreadFromBadge(t, f);
          final origin = w.location,
              originIndex = w.navigation.index,
              timeline = t.state(threadTimeline()),
              generation = w.threadGeneration,
              lookups = f.client.count('GET /channels/c1/threads/p1');
          await t.tap(
            find.byKey(const ValueKey('message-task-p1')).hitTestable(),
          );
          await frames(t);
          expect(find.byType(SourceTaskSurface), findsOneWidget);
          expect(w.navigation.index, originIndex + 1);
          if (systemBack) {
            await t.binding.handlePopRoute();
          } else {
            await t.tap(find.byKey(const ValueKey('task-back')).hitTestable());
          }
          await frames(t);
          expect(find.byType(SourceTaskSurface), findsNothing);
          // Back returned to the exact origin entry, not a rewritten copy.
          expect(w.location, origin);
          expect(w.navigation.index, originIndex);
          expect(w.navigation.entries[originIndex], origin);
          // The thread underneath is still the same mounted, loaded thread.
          expect(t.state(threadTimeline()), same(timeline));
          expect(w.threadGeneration, generation);
          expect(w.threadChannelId, 't1');
          expect(paintedMessage(t, 'r1'), isNotNull);
          expect(f.client.count('GET /channels/c1/threads/p1'), lookups);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    for (final width in [1280.0, 390.0]) {
      final mobile = width < 768;
      testWidgets(
        '[N18] ${family.name}/${mobile ? 'phone replaces' : 'desktop pushes'} on View in channel and the held thread never reopens',
        (t) async {
          // Web rightPanelUrlSyncContract 754–873 (openThreadParentMessageRoute):
          // desktop PUSH, mobile REPLACE; the thread closes and its stale
          // snapshot cannot regain ownership.
          final held = Completer<Map<String, dynamic>>();
          final f = await overlayFixture(
            t,
            width: width,
            family: family,
            task: taskRow('task-parent'),
            heldReplies: held,
          );
          final w = f.w;
          await t.tap(find.byKey(const ValueKey('thread-replies-badge-p1')));
          await frames(t);
          expect(w.location.thread?.toString(), 'c1:p1');
          expect(find.byType(RaftThreadHeader), findsOneWidget);
          final origin = w.location,
              originIndex = w.navigation.index,
              originEntries = w.navigation.entries.length;
          await t.tap(find.byKey(const Key('thread-options')).hitTestable());
          await frames(t);
          await t.tap(find.text('View in channel').hitTestable());
          await frames(t);
          final target = RaftLocation.at(
            serverSlug: 'demo',
            route: RaftRoute.channel,
            entityId: 'c1',
            query: {'msg': 'p1'},
          );
          expect(w.location, target);
          expect(w.location.thread, isNull);
          expect(find.byType(RaftThreadHeader), findsNothing);
          if (mobile) {
            // The thread entry itself becomes the channel entry.
            expect(w.navigation.entries.length, originEntries);
            expect(w.navigation.index, originIndex);
          } else {
            expect(w.navigation.entries.length, originEntries + 1);
            expect(w.navigation.index, originIndex + 1);
            expect(w.navigation.entries[originIndex], origin);
          }
          expect(w.navigation.entries[w.navigation.index], target);
          // The old thread request completes after the route change.
          held.complete({
            'messages': [message('r1', 't1', 1)],
          });
          await frames(t);
          expect(w.location, target);
          expect(find.byType(RaftThreadHeader), findsNothing);
          expect(w.threadChannelId, isNull);
          expect(paintedMessage(t, 'r1'), isNull);
          expect(paintedMessage(t, 'p1'), isNotNull);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
