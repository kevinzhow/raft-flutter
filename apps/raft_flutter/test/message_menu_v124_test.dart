import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

/// Web v1.24 MessageItem context menu (MessageItem.tsx:4777-5000): the
/// sections keep going here (reply / follow / mark thread unread / task),
/// take it elsewhere (copy link / copy Markdown / select text / forward /
/// select), just for me (save / translate / mark the conversation unread).
void main() {
  Map<String, dynamic> message(String id, int seq, String channelId) => {
    'id': id,
    'channelId': channelId,
    'seq': seq,
    'senderId': 'bob',
    'senderType': 'user',
    'senderName': 'Bob',
    'content': '$id body',
    'createdAt': '2026-06-22T02:30:00Z',
  };

  int posts(MessageAdapter a, String path) =>
      a.calls.where((o) => o.method == 'POST' && o.path == path).length;

  void routes(
    MessageAdapter a, {
    List<Map<String, dynamic>> followed = const [],
  }) {
    a.routes['GET /channels/threads/followed'] = (_) => {'threads': followed};
    a.routes['GET /agents'] = (_) => [];
    a.routes['GET /servers/s1/members'] = (_) => [];
    a.routes['GET /channels/unread'] = (_) => {'channels': {}};
    for (final id in ['c1', 'd1', 'thread-c1']) {
      a.routes['POST /channels/$id/unread'] = (_) => {
        'unreadCount': 1,
        'readStateVersion': 2,
        'maxReadSeq': '0',
      };
    }
  }

  Future<void> mount(
    WidgetTester t,
    Widget view, {
    TargetPlatform platform = TargetPlatform.linux,
  }) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(body: view),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester t, String body) async {
    await t.tapAt(
      t.getCenter(find.text(body)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await t.pumpAndSettle();
  }

  Future<void> pick(WidgetTester t, String id) async {
    await t.tap(find.byKey(ValueKey('message-menu-$id')));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pumpAndSettle();
  }

  List<RaftMessageContextMenuItem> items(WidgetTester t) => [
    for (final section
        in t
            .widget<RaftMessageContextMenu>(find.byType(RaftMessageContextMenu))
            .sections)
      ...section,
  ];

  List<String> menuIds(WidgetTester t) => [
    for (final item in items(t))
      (item.key! as ValueKey<String>).value.substring('message-menu-'.length),
  ];

  String label(WidgetTester t, String id) =>
      items(t)
          .singleWhere((item) => item.key == ValueKey('message-menu-$id'))
          .label;

  Future<(WorkspaceController, MessageAdapter)> channel(
    WidgetTester t, {
    List<Map<String, dynamic>> followed = const [],
    Map<String, dynamic>? extra,
  }) async {
    final (w, a) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': 'acme'});
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      {...message('m1', 1, 'c1'), ...?extra},
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    routes(a, followed: followed);
    return (w, a);
  }

  testWidgets(
    'a channel row lists the Web sections and marks the channel unread',
    (t) async {
      final (w, a) = await channel(t);
      await mount(t, RaftChatView(controller: w));
      await openMenu(t, 'm1 body');
      final ids = menuIds(t);
      // Reply, then copy link / copy Markdown / forward / select, then save
      // and the conversation's Mark as Unread, last.
      expect(ids.indexOf('thread'), lessThan(ids.indexOf('copy-link')));
      expect(
        [
          for (final id in ids)
            if (id.startsWith('copy') || id == 'forward' || id == 'select') id,
        ],
        ['copy-link', 'copy-markdown', 'forward', 'select'],
      );
      expect(ids.indexOf('select'), lessThan(ids.indexOf('save')));
      expect(ids.last, 'mark-conversation-unread');
      expect(label(t, 'thread'), 'Reply in thread');
      expect(label(t, 'mark-conversation-unread'), 'Mark channel as unread');
      // Mark Thread as Unread needs a followed thread; Select text a touch.
      expect(ids, isNot(contains('mark-thread-unread')));
      expect(ids, isNot(contains('select-text')));
      await pick(t, 'mark-conversation-unread');
      expect(posts(a, '/channels/c1/unread'), 1);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Forward in the menu opens the forward composer for the row', (
    t,
  ) async {
    final (w, _) = await channel(t);
    await mount(t, RaftChatView(controller: w));
    await openMenu(t, 'm1 body');
    await pick(t, 'forward');
    expect(find.byType(ForwardComposerPage), findsOneWidget);
    expect(
      t
          .widget<ForwardComposerPage>(find.byType(ForwardComposerPage))
          .messages
          .map((m) => m.id),
      ['m1'],
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a DM row offers Mark DM as unread', (t) async {
    final (w, a) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': 'acme'});
    w.channel = RaftChannel({'id': 'd1', 'type': 'dm', 'name': 'bob'});
    w.dms = [w.channel!];
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      message('m1', 1, 'd1'),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['d1'] = {'m1'};
    routes(a);
    await mount(t, RaftChatView(controller: w));
    await openMenu(t, 'm1 body');
    expect(label(t, 'mark-conversation-unread'), 'Mark DM as unread');
    expect(menuIds(t), contains('forward'));
    await pick(t, 'mark-conversation-unread');
    expect(posts(a, '/channels/d1/unread'), 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a channel row whose thread is followed marks that thread unread',
    (t) async {
      final (w, a) = await channel(
        t,
        followed: [
          {'parentMessageId': 'm1', 'threadChannelId': 'thread-c1'},
        ],
        extra: {'threadChannelId': 'thread-c1'},
      );
      await mount(t, RaftChatView(controller: w));
      await openMenu(t, 'm1 body');
      final ids = menuIds(t);
      expect(ids, contains('mark-thread-unread'));
      // Keep going here: after Unfollow, before Copy link.
      expect(
        ids.indexOf('unfollow'),
        lessThan(ids.indexOf('mark-thread-unread')),
      );
      expect(
        ids.indexOf('mark-thread-unread'),
        lessThan(ids.indexOf('copy-link')),
      );
      expect(label(t, 'mark-thread-unread'), 'Mark thread as unread');
      await pick(t, 'mark-thread-unread');
      expect(posts(a, '/channels/thread-c1/unread'), 1);
      expect(posts(a, '/channels/c1/unread'), 0);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a reply in a followed thread panel marks the thread unread and forwards',
    (t) async {
      final (w, a) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': 'acme'});
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.state.threadParent = RaftMessage(
        message('parent', 1, 'c1'),
      );
      w.threadChannelId = 'thread-c1';
      w.messageDomain.ledger.ingest([
        message('reply', 2, 'thread-c1'),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['thread-c1'] = {'reply'};
      routes(
        a,
        followed: [
          {'parentMessageId': 'parent', 'threadChannelId': 'thread-c1'},
        ],
      );
      w.services.followedThreads.ensure();
      await mount(
        t,
        RaftConversationSurface(
          role: RaftConversationSurfaceRole.threadTimeline,
          child: RaftChatView(controller: w, thread: true),
        ),
      );
      await openMenu(t, 'reply body');
      final ids = menuIds(t);
      expect(ids, contains('mark-thread-unread'));
      expect(ids, contains('forward'));
      // The thread panel acts on the thread, not on the channel.
      expect(ids, isNot(contains('mark-conversation-unread')));
      await pick(t, 'mark-thread-unread');
      expect(posts(a, '/channels/thread-c1/unread'), 1);
      await openMenu(t, 'reply body');
      await pick(t, 'forward');
      expect(find.byType(ForwardComposerPage), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Select text is offered on touch only', (t) async {
    final (w, _) = await channel(t);
    await mount(
      t,
      RaftChatView(controller: w),
      platform: TargetPlatform.android,
    );
    // A long press on the text selects it; the menu is the row's whitespace.
    final row = t.getRect(find.byKey(const ValueKey('message-m1')).first);
    await t.longPressAt(Offset(row.right - 8, row.center.dy));
    await t.pumpAndSettle();
    final ids = menuIds(t);
    expect(
      [
        for (final id in ids)
          if (id.startsWith('copy') ||
              id.startsWith('select') ||
              id == 'forward')
            id,
      ],
      ['copy-link', 'copy-markdown', 'select-text', 'forward', 'select'],
    );
    expect(label(t, 'select-text'), 'Select text');
    await pick(t, 'select-text');
    expect(find.text('Press and hold to select text.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
