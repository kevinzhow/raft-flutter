import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'flutter_test_config.dart' show leakDebt;
import 'incoming_share_handoff_test.dart' show flushUntil, pickerOpen, scratch;

/// Kevin, 2026-11-08: text shared into a DM from another app reached the
/// server, but the message did not show in the conversation the share opened
/// (it did after leaving and coming back); a reply in a thread did show.
///
/// The hand-off navigated to the chat a second time after selectChannel had
/// started that conversation's history read; the navigation retired the read,
/// so the page stayed loading and never showed its rows or the accepted send.
/// Thread replies use their own window request, which nothing retired.
void main() {
  leakDebt(const [
    'IncomingShareStaging',
    'ValueNotifier<RaftTransferProgress?>',
  ]);

  Map<String, dynamic> dmRow(String id) => {
    'id': id,
    'name': 'dm-$id',
    'type': 'dm',
    'joined': true,
    'serverId': 'b',
    'peerDisplayName': 'Bob',
    'peerUserId': 'bob',
    'latestSeq': '1',
  };

  // Phone (the shared window) and wide (the controller projection) layouts.
  for (final (pending, width) in [
    for (final pending in [false, true])
      for (final width in [412.0, 1280.0]) (pending, width),
  ]) {
    testWidgets(
      'a message sent from a share into ${pending ? 'a new' : 'an existing'} '
      'DM shows in the opened conversation at $width',
      (t) async {
        final directory = await scratch(t, 'raft-share-sent-visible-');
        final sharing = NativeSharing(
          supported: false,
          incomingDirectory: () async => directory,
        );
        sharing.receive(const IncomingShare(text: 'Shared hello'));
        final f = RootFixture(sharing: sharing);
        final dmId = pending ? 'db-new' : 'db';
        final sent = <Map<String, dynamic>>[];
        var created = false;
        f.overrides['GET /channels/dm'] = (o) =>
            o.headers['X-Server-Id'] == 'b' && (!pending || created)
            ? [dmRow(dmId)]
            : [];
        if (pending) {
          f.overrides['GET /servers/b/members'] = (_) => [
            {
              'userId': 'bob',
              'user': {'id': 'bob', 'name': 'Bob', 'displayName': 'Bob'},
            },
          ];
          f.overrides['POST /channels/dm'] = (_) {
            created = true;
            return {'id': dmId};
          };
        }
        f.overrides['GET /channels/$dmId'] = (_) => dmRow(dmId);
        f.overrides['GET /channels/$dmId/members'] = (_) => [];
        f.overrides['POST /channels/$dmId/read'] = (_) => {};
        f.overrides['GET /messages/channel/$dmId'] = (_) => {
          'messages': [
            {
              'id': 'older',
              'channelId': dmId,
              'seq': '1',
              'senderId': 'bob',
              'senderName': 'Bob',
              'content': 'Earlier in this DM',
              'createdAt': '2026-11-08T00:00:00Z',
            },
            for (final row in sent) row,
          ],
          'hasMore': false,
          'hasNewer': false,
        };
        f.overrides['POST /v2/messages'] = (RequestOptions o) {
          final data = o.data as Map;
          final row = <String, dynamic>{
            'id': 'sent-${sent.length + 1}',
            'channelId': data['channelId'],
            'seq': '${sent.length + 2}',
            'senderId': 'alice',
            'senderName': 'alice',
            'senderType': 'user',
            'content': data['content'],
            'randomId': data['randomId'],
            'createdAt': '2026-11-08T00:01:00Z',
          };
          sent.add(row);
          return {'message': row};
        };
        await f.mount(t, 'light', width);
        await flushUntil(t, f, pickerOpen, what: 'the shared picker');
        await t.tap(find.text('Beta').last);
        final target = pending ? 'user:bob:agent:null' : dmId;
        await flushUntil(
          t,
          f,
          () => find
              .byKey(ValueKey('incoming-target-$target'))
              .evaluate()
              .isNotEmpty,
          what: 'the DM destination row',
        );
        await t.tap(find.byKey(ValueKey('incoming-target-$target')));
        await t.pump();
        await t.tap(find.byKey(const Key('incoming-share-continue')));
        await flushUntil(t, f, () => !pickerOpen(), what: 'the hand-off');
        final WorkspaceController w = t
            .widget<WorkspaceView>(find.byType(WorkspaceView))
            .controller;
        await flushUntil(
          t,
          f,
          () => w.channel?.id == dmId && !w.sharedBlocked(),
          what: 'the destination check to release Send',
        );
        expect(w.drafts[dmId], 'Shared hello');
        await t.tap(
          find.byWidgetPredicate(
            (x) => x is RaftComposerAction && x.glyph == RaftGlyph.send,
          ),
        );
        await flushUntil(t, f, () => sent.isNotEmpty, what: 'the send');
        for (var i = 0; i < 3; i++) {
          await f.flush(t);
        }
        expect(sent.single['channelId'], dmId);
        // The accepted message is in the conversation the share opened.
        expect(w.channel?.id, dmId);
        expect(
          w.messageDomain.timeline().map((m) => m.json['content']),
          contains('Shared hello'),
        );
        expect(find.text('Shared hello'), findsOneWidget);
        expect(find.text('Earlier in this DM'), findsOneWidget);
        expect(find.text('Loading messages…'), findsNothing);

        // A reply in the thread under a DM message shows, as it did before.
        f.adapter.routes['POST /channels/$dmId/threads'] = (_) => {
          'threadChannelId': 'thread-$dmId',
        };
        f.adapter.routes['GET /messages/channel/thread-$dmId'] = (_) => {
          'messages': const [],
          'hasMore': false,
          'hasNewer': false,
        };
        final parent = w.messageDomain.messages.firstWhere(
          (m) => m.id == 'older',
        );
        unawaited(w.messageDomain.threads.openThread(parent));
        await f.flush(t);
        final replied = w.send('Reply in thread', thread: true);
        await flushUntil(t, f, () => sent.length == 2, what: 'the reply');
        expect(await replied, isTrue);
        await f.flush(t);
        expect(sent.last['channelId'], 'thread-$dmId');
        expect(
          w.messageDomain.timeline(thread: true).map((m) => m.json['content']),
          contains('Reply in thread'),
        );
        expect(find.text('Reply in thread'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
