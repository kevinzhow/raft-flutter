import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/dm_read_status.dart';

import 'dm_read_status_authority_test.dart' show sent;
import 'message_presentation_test.dart' show fixture;

Map<String, dynamic> detail({required bool enabled}) => {
  'id': 'd',
  'name': 'Public DM fixture',
  'type': 'dm',
  'joined': true,
  'serverId': 's1',
  if (enabled)
    'peerReadStates': [
      {'peerKind': 'agent', 'peerId': 'ada', 'maxReadSeq': 10},
    ],
};

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  for (final enabled in [false, true]) {
    test(
      'accepted canonical DM detail reuses its receipt gate: $enabled',
      () async {
        final (w, api) = await fixture('owner');
        addTearDown(w.dispose);
        w.channel = RaftChannel(detail(enabled: false));
        w.channels = [];
        w.dms = [w.channel!];
        api.routes['GET /channels/d'] = (_) => detail(enabled: enabled);
        await w.refreshChannel('d');
        expect(
          dmReadStatusMessageId(w, [sent()], thread: false),
          enabled ? 'm' : isNull,
        );
        await settle();
        expect(api.calls.where((r) => r.path == '/channels/d'), hasLength(1));
      },
    );
  }

  test(
    'an older receipt request cannot undo a newer canonical disabled gate',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      w.channel = RaftChannel(detail(enabled: false));
      w.channels = [];
      w.dms = [w.channel!];
      final old = Completer<Map<String, dynamic>>();
      var requests = 0;
      api.routes['GET /channels/d'] = (_) =>
          ++requests == 1 ? old.future : detail(enabled: false);
      final pending = w.readReceipts.hydrate('d');
      await settle();
      await w.refreshChannel('d');
      old.complete(detail(enabled: true));
      await pending;
      expect(dmReadStatusMessageId(w, [sent()], thread: false), isNull);
      await settle();
      expect(requests, 2);
    },
  );

  for (final change in ['gate', 'server', 'dispose', 'none']) {
    test('queued summary refresh respects $change', () async {
      final (w, api) = await fixture('owner');
      var disposed = false;
      addTearDown(() {
        if (!disposed) w.dispose();
      });
      w.channel = RaftChannel(detail(enabled: false));
      w.channels = [];
      w.dms = [w.channel!];
      final summary = {
        ...detail(enabled: false),
        'peerReadSummary': {
          'peerCount': 1,
          'readCountAtSeq': [
            {'seq': 10, 'count': 1},
          ],
        },
      };
      final held = Completer<Map<String, dynamic>>();
      var requests = 0;
      api.routes['GET /channels/d'] = (_) => switch (++requests) {
        1 => summary,
        2 => held.future,
        _ => detail(enabled: false),
      };
      await w.readReceipts.hydrate('d');
      final pending = w.readReceipts.hydrate('d');
      await settle();
      w.readReceipts.consumeEvent(
        RaftEvent('scope_read:updated', {
          'scopeId': 'd',
          'summaryChanged': true,
        }),
      );
      if (change == 'server') {
        w.client.selectServer('s2');
        w.server = RaftRecord({'id': 's2', 'role': 'owner'});
      } else if (change == 'gate') {
        await w.refreshChannel('d');
      } else if (change == 'dispose') {
        w.dispose();
        disposed = true;
      }
      final before = requests;
      held.complete(summary);
      await pending;
      await settle();
      expect(
        requests,
        change == 'none' ? before + 1 : before,
        reason: 'only a still-current summary may start its queued refresh',
      );
    });
  }
}
