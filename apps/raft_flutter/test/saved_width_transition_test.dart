import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';

import 'workspace_source_location_contract_test.dart'
    show pageFixture, mountPage, frames;
import 'workspace_activity_activation_test.dart' show message;

void main() {
  for (final dm in [false, true]) {
    testWidgets(
      'Saved ${dm ? 'DM' : 'channel'} pending message remains current through width changes',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'saved');
        final channel = dm ? 'd1' : 'c1';
        if (dm) {
          w.dms = [
            RaftChannel({
              'id': 'd1',
              'name': 'Alice',
              'type': 'dm',
              'joined': true,
            }),
          ];
        }
        final pending = Completer<Map<String, dynamic>>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete({'messages': []});
        });
        api.routes['GET /channels/saved'] = (_) => {
          'globalTotal': 1,
          'total': 1,
          'saved': [
            {
              'messageId': 'saved-target',
              'channelId': channel,
              'channelType': dm ? 'dm' : 'channel',
              'channelName': dm ? 'Alice' : 'test',
              'senderType': 'user',
              'senderId': 'alice',
              'senderName': 'Alice',
              'content': 'Saved accepted target',
              'createdAt': '2026-10-28T01:00:00Z',
            },
          ],
        };
        api.routes['GET /messages/context/saved-target'] = (_) =>
            pending.future;
        api.routes['GET /channels/$channel'] = (_) => {
          'id': channel,
          'name': 'test',
          'type': dm ? 'dm' : 'channel',
          'joined': true,
        };
        api.routes['GET /messages/channel/$channel'] = (_) => {'messages': []};
        api.routes['POST /channels/$channel/read'] = (_) => {};
        await mountPage(t, w, false, width: 1440);
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.pump();
        });
        await t.tap(find.byKey(const ValueKey('saved-saved-target')));
        await frames(t, () {});
        expect(w.location.route, dm ? RaftRoute.dm : RaftRoute.channel);
        t.view.physicalSize = const Size(390, 844);
        await t.pumpAndSettle();
        await t.runAsync(() async {
          pending.complete({
            'messages': [message('saved-target', channel)],
          });
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await t.pumpAndSettle();
        final accepted = find.byKey(const ValueKey('message-saved-target'));
        for (final size in [
          const Size(390, 844),
          const Size(1440, 900),
          const Size(767, 900),
        ]) {
          t.view.physicalSize = size;
          await t.pumpAndSettle();
          expect(accepted, findsOneWidget);
          expect(w.channel?.id, channel);
          expect(t.getRect(accepted).overlaps(Offset.zero & size), isTrue);
          expect(t.takeException(), isNull);
        }
        await t.tap(find.byKey(const Key('mobile-detail-back')));
        await t.pumpAndSettle();
        expect(w.location.route, RaftRoute.saved);
        expect(
          find.byKey(const ValueKey('saved-saved-target')),
          findsOneWidget,
        );
      },
    );
  }
}
