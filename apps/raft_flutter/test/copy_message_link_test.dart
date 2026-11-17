import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

/// Web v1.24 `MessageItem.handleCopyLink`: Copy link builds the permalink
/// locally and writes the clipboard at once. No request runs before the write,
/// so a slow or failing network can neither delay nor drop the copy.
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

  Future<String? Function()> captureClipboard(WidgetTester t) async {
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
    return () => copied;
  }

  Future<void> copyLink(WidgetTester t, Widget view, String body) async {
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
    await t.tapAt(
      t.getCenter(find.text(body)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('message-menu-copy-link')));
    await t.pump();
    await t.pump();
  }

  testWidgets(
    'Copy link writes the permalink at once while the network hangs',
    (t) async {
      final (w, a) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': 'acme'});
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.ledger.ingest([
        message('m1', 1, 'c1'),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {'m1'};
      final never = Completer<dynamic>();
      for (final route in [
        'GET /servers',
        'GET /channels/c1',
        'GET /messages/context/m1',
      ]) {
        a.routes[route] = (_) => never.future;
      }
      final copied = await captureClipboard(t);
      await copyLink(t, RaftChatView(controller: w), 'm1 body');
      expect(copied(), 'https://example.invalid/s/acme/channel/c1?msg=m1');
      expect(a.calls.where((o) => o.path.startsWith('/messages/')), isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Copy link on a thread reply copies the thread permalink', (
    t,
  ) async {
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
    a.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    a.routes['GET /agents'] = (_) => [];
    a.routes['GET /servers/s1/members'] = (_) => [];
    final copied = await captureClipboard(t);
    await copyLink(
      t,
      RaftConversationSurface(
        role: RaftConversationSurfaceRole.threadTimeline,
        child: RaftChatView(controller: w, thread: true),
      ),
      'reply body',
    );
    final url = Uri.parse(copied()!);
    expect(url.path, '/s/acme/channel/c1');
    expect(url.queryParameters, {'msg': 'reply', 'thread': 'c1:parent'});
    expect(a.calls.where((o) => o.path.startsWith('/messages/')), isEmpty);
    await t.pumpWidget(const SizedBox());
  });
}
