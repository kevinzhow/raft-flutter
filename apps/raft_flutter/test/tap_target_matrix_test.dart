import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/tap_target_registry.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/profile_side_panel.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'task_surface_test.dart' show flush, modernTask, taskRoutes;
import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'support/app_services_fixture.dart';

// Tap-target matrix: every message container (host) x every element Web makes
// interactive. Each cell taps the real widget and asserts the visible effect
// (a panel, a location, a dialog route, a request). A tap that changes nothing
// fails, unless TapTargetRegistry documents the Web no-op for that cell.
// docs/tap-targets.md is generated from the same registry.

class TapObserver extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

Map<String, dynamic> msg(
  String id,
  String channel,
  int seq,
  String content, {
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'channelId': channel,
  'seq': '$seq',
  'senderId': 'bob',
  'senderType': 'user',
  'senderName': 'Bob',
  'content': content,
  'createdAt': '2026-10-08T00:00:00Z',
  ...extra,
};

final channelMessages = [
  msg(
    'parent',
    'c1',
    1,
    'Hello [@Alice](raft-ref://mention/user/alice) see '
        '[#random](raft-ref://channel/c2)',
    extra: {
      'reactions': [
        {
          'emoji': '\u{1F44D}',
          'count': 1,
          'reactorIds': ['u2'],
          'reactorNames': ['Dana'],
        },
      ],
    },
  ),
  msg('badge', 'c1', 2, 'Replies without a preview'),
  msg(
    'att',
    'c1',
    3,
    'File attached',
    extra: {
      'attachments': [
        {
          'id': 'file-1',
          'filename': 'notes.md',
          'mimeType': 'text/markdown',
          'size': 12,
        },
      ],
    },
  ),
  msg('task-parent', 'c1', 4, 'A task message'),
  msg('tref', 'c1', 5, 'See [#8](raft-ref://task/8)'),
];
final channelPage = {
  'messages': channelMessages,
  'threadSummariesByParentMessageId': {
    'parent': {
      'replyCount': 1,
      'latestReplies': [
        {
          'messageId': 'r1',
          'senderType': 'user',
          'senderName': 'Cindy',
          'preview': 'cindy reply',
        },
      ],
    },
    'badge': {'replyCount': 2},
  },
};

final threadReplies = {
  'messages': [
    msg(
      'r1',
      't1',
      1,
      'Reply [@Alice](raft-ref://mention/user/alice)',
      extra: {'senderName': 'Cindy', 'senderId': 'cindy'},
    ),
  ],
};

void channelRoutes(MessageAdapter api) {
  taskRoutes(api, modernTask);
  api.routes['GET /tasks/channel/c1'] = (_) => {
    'tasks': [modernTask],
    'nextCursor': null,
  };
  api.routes['GET /messages/channel/c1'] = (_) => channelPage;
  for (final id in ['first-channel', 'parent']) {
    api.routes['GET /messages/context/$id'] = (_) => channelPage;
  }
  api.routes['GET /channels/c1/threads/parent'] = (_) => {
    'threadChannelId': 't1',
  };
  api.routes['GET /channels/c1/threads/badge'] = (_) => {
    'threadChannelId': 't1',
  };
  api.routes['GET /messages/channel/t1'] = (_) => threadReplies;
  api.routes['GET /messages/context/r1'] = (_) => threadReplies;
  api.routes['POST /channels/c1/read'] = (_) => {};
  api.routes['POST /channels/c2/read'] = (_) => {};
  api.routes['POST /channels/t1/read'] = (_) => {};
  api.routes['POST /channels/thread-1/read'] = (_) => {};
  api.routes['GET /messages/attachment-preview/enabled'] = (_) => {
    'enabled': true,
  };
  api.routes['GET /attachments/file-1/preview'] = (_) => {
    'status': 'ok',
    'data': {'kind': 'text', 'text': 'Fixture document'},
  };
  api.routes['PUT /messages/parent/reactions'] = (_) => {};
  api.routes['POST /messages/parent/reactions'] = (_) => {};
}

class Ctx {
  Ctx(this.t, this.w, this.api, this.observer, this.host);
  final WidgetTester t;
  final WorkspaceController w;
  final MessageAdapter api;
  final TapObserver observer;
  final TapHost host;

  Finder get threadView => find.byWidgetPredicate(
    (x) => x is RaftChatView && x.thread,
    description: 'thread RaftChatView',
  );
  Finder get profilePanel => find.byType(ProfileSidePanel);
  Finder row(String id) => find.byKey(ValueKey('message-$id'));
}

Future<Ctx> mount(WidgetTester t, TapHost host) async {
  t.view.physicalSize = Size(host.width, host.width < 768 ? 844 : 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final section = switch (host.surface) {
    TapSurface.activityChannel || TapSurface.activityThread => 'activity',
    TapSurface.searchChannel => 'search',
    _ => 'chat',
  };
  final (w, api) = await pageFixture(t, section: section);
  w.channels = [
    RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
    RaftChannel({'id': 'c2', 'name': 'random', 'joined': true}),
  ];
  w.channel = w.channels.first;
  channelRoutes(api);
  api.routes['GET /channels/inbox'] = (_) => {
    'items': [
      if (host.surface == TapSurface.activityThread)
        {
          'kind': 'thread',
          'threadChannelId': 't1',
          'parentChannelId': 'c1',
          'parentMessageId': 'parent',
          'parentMessagePreview': 'Parent',
          'latestActivityPreview': 'A reply',
          'unreadCount': 1,
          'firstUnreadMessageId': 'r1',
          'latestActivityMessageId': 'r1',
        }
      else
        {
          'kind': 'channel',
          'channelId': 'c1',
          'channelName': 'test',
          'lastMessagePreview': 'Open channel',
          'unreadCount': 1,
          'firstUnreadMessageId': 'first-channel',
          'lastMessageId': 'task-parent',
        },
    ],
  };
  if (section == 'chat') {
    // The chat route shows the accepted window of the open channel.
    w.messageDomain.ledger.ingest(
      channelMessages,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final m in channelMessages) m['id'] as String,
    };
    w.messageDomain.threadSummaries = Map<String, dynamic>.from(
      channelPage['threadSummariesByParentMessageId'] as Map,
    );
    w.navigation.navigate(
      RaftLocation.at(
        serverSlug: 'demo',
        route: RaftRoute.channel,
        entityId: 'c1',
      ),
    );
  }
  if (host.surface == TapSurface.searchChannel) {
    api.routes['GET /messages/search'] = (_) => {
      'results': [
        {
          ...channelMessages.first,
          'content': 'Search hit text',
          'channelName': 'test',
          'channelType': 'channel',
        },
      ],
      'hasMore': false,
    };
    w.navigation.navigate(w.location.withQuery({'q': 'hit'}));
  }
  final observer = TapObserver();
  await t.pumpWidget(
    MaterialApp(
      // Density follows the platform: a 1280 / 816 window is a desktop
      // (mouse, hover toolbar), 390 a phone.
      theme: raftTheme(RaftFamily.elegant).copyWith(
        platform: host.touch ? TargetPlatform.android : TargetPlatform.macOS,
      ),
      navigatorObservers: [observer],
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await flush(t);
  await t.pumpAndSettle();
  final ctx = Ctx(t, w, api, observer, host);
  switch (host.surface) {
    case TapSurface.activityChannel:
      await t.tap(find.byKey(const ValueKey('activity-channel-c1')));
      await flush(t);
      await t.pumpAndSettle();
    case TapSurface.activityThread:
      await t.tap(find.byKey(const ValueKey('activity-thread-t1')));
      await flush(t);
      await t.pumpAndSettle();
    case TapSurface.searchChannel:
      await flush(t);
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Search hit text'));
      await flush(t);
      await t.pumpAndSettle();
    case TapSurface.chatThreadPanel:
      await t.tap(find.byKey(const ValueKey('thread-replies-badge-badge')));
      await flush(t);
      await t.pumpAndSettle();
    case TapSurface.chat:
      break;
  }
  return ctx;
}

class Snap {
  Snap(Ctx c)
    : uri = '${c.w.location.uri}',
      thread = c.threadView.evaluate().isNotEmpty,
      profile = c.profilePanel.evaluate().isNotEmpty,
      task = find.byType(SourceTaskSurface).evaluate().isNotEmpty,
      pushes = c.observer.pushes,
      calls = c.api.calls.length;
  final String uri;
  final bool thread, profile, task;
  final int pushes, calls;
  bool sameAs(Snap o) =>
      uri == o.uri &&
      thread == o.thread &&
      profile == o.profile &&
      task == o.task &&
      pushes == o.pushes &&
      calls == o.calls;
  @override
  String toString() =>
      '$uri thread=$thread profile=$profile task=$task pushes=$pushes calls=$calls';
}

Future<void> hover(Ctx c, String id) async {
  final gesture = await c.t.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  final center = c.t.getCenter(c.row(id));
  await gesture.moveTo(center);
  await c.t.pump(const Duration(milliseconds: 200));
  await gesture.moveTo(center + const Offset(3, 2));
  await c.t.pump(const Duration(milliseconds: 200));
}

Finder? find$(Ctx c, TapElement e) => switch (e) {
  TapElement.inlineThreadCard => find.byKey(
    const ValueKey('inline-thread-parent'),
  ),
  TapElement.repliesBadge => find.byKey(
    const ValueKey('thread-replies-badge-badge'),
  ),
  TapElement.toolbarReply => find.byKey(
    const ValueKey('message-thread-parent'),
  ),
  TapElement.rowTap => find.descendant(
    of: c.row('task-parent'),
    matching: find.text('A task message'),
  ),
  TapElement.taskRef => null,
  TapElement.avatar =>
    c.host.threadDetail
        ? find.byKey(const ValueKey('sender-avatar-r1'))
        : find.byKey(const ValueKey('sender-avatar-parent')),
  TapElement.mention => null,
  TapElement.channelLink => null,
  TapElement.taskChip => find.byKey(const ValueKey('message-task-task-parent')),
  TapElement.reaction => find.byKey(const ValueKey('reaction-\u{1F44D}')),
  TapElement.attachment => find.byKey(const ValueKey('attachment-file-1')),
};

Future<void> tapElement(Ctx c, TapElement e) async {
  final t = c.t;
  if (e == TapElement.toolbarReply) await hover(c, 'parent');
  if (e == TapElement.mention ||
      e == TapElement.channelLink ||
      e == TapElement.taskRef) {
    final text = switch (e) {
      TapElement.mention => '@Alice',
      TapElement.channelLink => '#random',
      _ => '#8',
    };
    final scope = c.host.threadDetail
        ? 'r1'
        : e == TapElement.taskRef
        ? 'tref'
        : 'parent';
    final target = find.descendant(
      of: c.row(scope),
      matching: find.textContaining(text, findRichText: true),
    );
    expect(target, findsWidgets, reason: '${c.host.id}: $text not on screen');
    await t.tap(target.first, warnIfMissed: false);
    return;
  }
  final finder = find$(c, e)!;
  expect(
    finder,
    findsWidgets,
    reason: '${c.host.id}: element ${e.name} is not on screen',
  );
  await t.tap(finder.first, warnIfMissed: false);
}

void main() {
  for (final host in TapTargetRegistry.hosts) {
    for (final element in TapElement.values) {
      final expectation = TapTargetRegistry.expectation(host, element);
      if (expectation.kind == TapEffect.absent) continue;
      testWidgets('${host.id} x ${element.name}: ${expectation.kind.name}', (
        t,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final c = await mount(t, host);
        final before = Snap(c);
        await tapElement(c, element);
        await flush(t);
        await t.pumpAndSettle();
        final after = Snap(c);
        final why = 'before: $before\nafter:  $after';
        // Invariant: a location slot that a tap wrote must be on screen.
        if (c.w.location.thread != null && !host.threadDetail) {
          expect(
            c.threadView,
            findsWidgets,
            reason: 'location has ?thread= but no host renders it\n$why',
          );
        }
        if (c.w.location.profile != null) {
          expect(
            c.profilePanel,
            findsWidgets,
            reason: 'location has ?profile= but no host renders it\n$why',
          );
        }
        switch (expectation.kind) {
          case TapEffect.threadPanel:
            expect(c.w.location.thread?.itemId, isNotNull, reason: why);
            expect(c.threadView, findsWidgets, reason: why);
          case TapEffect.profilePanel:
            expect(c.w.location.profile, isNotNull, reason: why);
            expect(c.profilePanel, findsWidgets, reason: why);
          case TapEffect.location:
            expect(after.uri, isNot(before.uri), reason: why);
          case TapEffect.taskSlot:
            expect(c.w.location.query('task'), isNotNull, reason: why);
          case TapEffect.request:
            expect(after.calls, greaterThan(before.calls), reason: why);
          case TapEffect.route:
            expect(after.pushes, greaterThan(before.pushes), reason: why);
          case TapEffect.documentedNoop || TapEffect.knownGap:
            expect(after.sameAs(before), isTrue, reason: why);
          case TapEffect.absent:
            break;
        }
        expect(t.takeException(), isNull);
      });
    }
  }

  // List containers: the rows are not message tiles, but each row and each
  // control inside it is a tap target Web wires (SavedPanel.openSavedEntry,
  // the bookmark button).
  for (final width in [1280.0, 390.0]) {
    for (final remove in [false, true]) {
      testWidgets(
        'saved-${width.toInt()} x ${remove ? 'remove button' : 'row'}: '
        '${remove ? 'request' : 'location'}',
        (t) async {
          SharedPreferences.setMockInitialValues({});
          t.view.physicalSize = Size(width, width < 768 ? 844 : 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await pageFixture(t, section: 'saved');
          channelRoutes(api);
          api.routes['GET /channels/saved'] = (_) => {
            'globalTotal': 1,
            'total': 1,
            'saved': [
              {
                'messageId': 'parent',
                'channelId': 'c1',
                'channelName': 'test',
                'channelType': 'channel',
                'content': 'Saved text',
                'senderId': 'bob',
                'senderType': 'user',
                'senderName': 'Bob',
                'createdAt': '2026-10-08T00:00:00Z',
              },
            ],
          };
          api.routes['DELETE /channels/saved/parent'] = (_) => {'ok': true};
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(RaftFamily.elegant).copyWith(
                platform: width < 768
                    ? TargetPlatform.android
                    : TargetPlatform.macOS,
              ),
              home: withAppServices(
                WorkspaceView(
                  controller: w,
                  appearance: const RaftAppearance(),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                ),
              ),
            ),
          );
          await flush(t);
          await t.pumpAndSettle();
          final before = '${w.location.uri}';
          final calls = api.calls.length;
          if (remove) {
            await t.tap(find.bySemanticsLabel('Remove saved message'));
          } else {
            await t.tap(find.byKey(const ValueKey('saved-parent')));
          }
          await flush(t);
          await t.pumpAndSettle();
          if (remove) {
            expect(
              api.calls.skip(calls).any((r) => r.method == 'DELETE'),
              isTrue,
              reason: 'remove button sent no DELETE',
            );
          } else {
            expect('${w.location.uri}', isNot(before));
            expect(w.location.messageId, 'parent');
          }
        },
      );
    }
  }

  testWidgets(
    'task discussion: the borrowed timeline carries the host handlers',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final c = await mount(
        t,
        const TapHost('chat-1280', TapSurface.chat, 1280, 'Chat, desktop 1280'),
      );
      await t.tap(find.byKey(const ValueKey('message-task-task-parent')));
      await flush(t);
      await t.pumpAndSettle();
      expect(find.byType(SourceTaskSurface), findsOneWidget);
      final discussion = find.descendant(
        of: find.byType(SourceTaskSurface),
        matching: find.byType(RaftChatView),
      );
      expect(discussion, findsWidgets);
      for (final view in t.widgetList<RaftChatView>(discussion)) {
        expect(
          view.onTask,
          isNotNull,
          reason: 'in-body #N would open a dialog',
        );
        expect(
          view.onViewBilling,
          isNotNull,
          reason: 'billing link would hide',
        );
      }
      expect(c.w.location.query('task'), isNotNull);
    },
  );
}
