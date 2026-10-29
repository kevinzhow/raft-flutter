import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/saved_sidebar_entry.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

/// Web v1.21.23 MessageItem on a channel timeline: the Saved badge in the
/// footer, the sender menu, the read marker on an @mentioned agent, and
/// Follow Thread on the thread panel's root message.
int calls(MessageAdapter a, String method, String path) =>
    a.calls.where((o) => o.method == method && o.path == path).length;

void main() {
  Future<void> mount(WidgetTester t, Widget view) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: view),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pumpAndSettle();
  }

  Future<void> rightClick(WidgetTester t, Finder at) async {
    await t.tapAt(
      t.getCenter(at),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await t.pump();
  }

  Map<String, dynamic> message(
    String id,
    int seq, {
    String sender = 'bob',
    String content = 'hello',
    List<Map<String, dynamic>>? mentions,
  }) => {
    'id': id,
    'channelId': 'c1',
    'seq': seq,
    'senderId': sender,
    'senderType': 'user',
    'senderName': sender == 'bob' ? 'Bob' : 'Alice',
    'content': content,
    'createdAt': '2026-06-22T02:30:00Z',
    'mentions': ?mentions,
  };

  testWidgets('a saved message shows the Saved badge; it unsaves from there', (
    t,
  ) async {
    final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      message('m1', 1),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    transport.routes['DELETE /channels/saved/m1'] = (_) => {'ok': true};
    SavedCountStore.of(w).know(['m1']);
    await mount(t, RaftChatView(controller: w));
    expect(find.byKey(const Key('message-saved-badge')), findsOneWidget);
    expect(find.text('Saved'), findsWidgets);
    await t.tap(find.byKey(const Key('message-saved-badge')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('message-saved-badge')), findsNothing);
    expect(calls(transport, 'DELETE', '/channels/saved/m1'), 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'right-click on the sender name offers Copy Name and Copy Handle',
    (t) async {
      final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.ledger.ingest([
        message('m1', 1),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {'m1'};
      transport.routes['GET /agents'] = (_) => [];
      transport.routes['GET /servers/s1/members'] = (_) => [
        {'userId': 'bob', 'name': 'bobby', 'role': 'member'},
      ];
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(t, RaftChatView(controller: w));
      await rightClick(t, find.text('Bob'));
      expect(find.byKey(const ValueKey('sender-menu-name')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('message-menu-copy-link')),
        findsNothing,
        reason: 'not the message menu',
      );
      await t.tap(find.byKey(const ValueKey('sender-menu-handle')));
      await t.pumpAndSettle();
      expect(copied, '@bobby');
      await rightClick(t, find.text('Bob'));
      await t.tap(find.byKey(const ValueKey('sender-menu-name')));
      await t.pumpAndSettle();
      expect(copied, 'Bob');
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('an @mentioned agent shows whether it has read my message', (
    t,
  ) async {
    final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      message(
        'm1',
        10,
        sender: 'alice',
        content: '@Ada please look',
        mentions: [
          {'type': 'agent', 'id': 'ada-id', 'name': 'Ada'},
        ],
      ),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    transport.routes['GET /agents'] = (_) => [];
    transport.routes['GET /servers/s1/members'] = (_) => [];
    transport.routes['GET /channels/c1'] = (_) => {
      'id': 'c1',
      'peerReadStates': [
        {'peerKind': 'agent', 'peerId': 'ada-id', 'maxReadSeq': 12},
      ],
    };
    await mount(t, RaftChatView(controller: w));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('mention-read-read')), findsOneWidget);
    expect(calls(transport, 'GET', '/channels/c1'), 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'the thread panel root offers Follow Thread, its replies do not',
    (t) async {
      final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.state.threadParent = RaftMessage({
        'id': 'parent',
        'channelId': 'c1',
        'seq': 1,
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'content': 'Parent body',
        'createdAt': '2026-06-22T02:30:00Z',
      });
      w.threadChannelId = 'thread-c1';
      w.messageDomain.ledger.ingest([
        {
          ...message('reply', 2),
          'channelId': 'thread-c1',
          'content': 'Reply body',
        },
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['thread-c1'] = {'reply'};
      transport.routes['GET /channels/threads/followed'] = (_) => {
        'threads': [],
      };
      transport.routes['GET /agents'] = (_) => [];
      transport.routes['GET /servers/s1/members'] = (_) => [];
      await mount(
        t,
        RaftConversationSurface(
          role: RaftConversationSurfaceRole.threadTimeline,
          child: RaftChatView(controller: w, thread: true),
        ),
      );
      await rightClick(t, find.text('Parent body'));
      expect(find.byKey(const ValueKey('message-menu-follow')), findsOneWidget);
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      await rightClick(t, find.text('Reply body'));
      expect(find.byKey(const ValueKey('message-menu-follow')), findsNothing);
      expect(
        find.byKey(const ValueKey('message-menu-copy-link')),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
}
