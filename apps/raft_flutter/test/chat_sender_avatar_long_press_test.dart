// Web SenderAvatar `onLongPressMention` (v1.21.23): holding a sender's avatar
// with a finger inserts "@sender" into the composer, like tapping the name,
// and does not open the profile or the message menu.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets('a touch long press on the avatar mentions the sender', (
    t,
  ) async {
    final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      {
        'id': 'm1',
        'channelId': 'c1',
        'seq': 1,
        'senderId': 'owner-id',
        'senderType': 'user',
        'senderName': 'artin',
        'content': 'Public body',
        'createdAt': '2026-06-22T02:30:00Z',
      },
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    transport.routes['GET /agents'] = (_) => [];
    transport.routes['GET /servers/s1/members'] = (_) => [
      {'userId': 'owner-id', 'name': 'artin', 'role': 'owner'},
    ];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pumpAndSettle();
    final editor = find.descendant(
      of: find.byType(RaftComposer),
      matching: find.byType(TextField),
    );
    final field = t.widget<TextField>(editor);
    final avatar = find.byKey(const ValueKey('sender-avatar-m1'));
    expect(avatar, findsOneWidget);

    await t.enterText(editor, 'cc');
    final touch = await t.startGesture(
      t.getCenter(avatar),
      kind: PointerDeviceKind.touch,
    );
    await t.pump(const Duration(milliseconds: 600));
    await touch.up();
    await t.pump();
    expect(field.controller!.text, 'cc @artin ');
    expect(field.focusNode!.hasFocus, isTrue);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
  });
}
