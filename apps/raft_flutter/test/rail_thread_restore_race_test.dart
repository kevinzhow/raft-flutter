import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/rail_location_memory.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  tearDown(DevicePreferences.reset);
  for (final next in ['channel', 'members', 'same-channel', 'unchanged']) {
    testWidgets('rail thread restoration respects $next navigation', (t) async {
      final (w, api) = await pageFixture(t, section: 'chat');
      final second = RaftChannel({
        'id': 'c2',
        'name': 'second',
        'joined': true,
      });
      w.channels = [...w.channels, second];
      final memory = RailLocationMemory();
      w.navigation.navigate(
        RaftLocation.parse('/s/demo/channel/c1?thread=c1:root'),
      );
      memory.record(w);
      w.setSection('settings');
      final response = Completer<Map<String, dynamic>>();
      addTearDown(() async {
        if (!response.isCompleted) response.complete({'messages': []});
        for (var i = 0; i < 5; i++) {
          await t.pump(const Duration(milliseconds: 50));
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
      });
      api.routes['GET /messages/channel/c1'] = (_) => response.future;
      api.routes['GET /messages/channel/c2'] = (_) => {'messages': []};
      api.routes['GET /channels/c1/available-mentions'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['GET /channels/c2/available-mentions'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['POST /channels/c2/read'] = (_) => {};
      api.routes['GET /channels/c1/threads/root'] = (_) => {
        'threadChannelId': 'old-thread',
      };
      api.routes['GET /messages/channel/old-thread'] = (_) => {'messages': []};
      api.routes['GET /messages/context/root'] = (_) => {'messages': []};
      expect(memory.enter(w, 'chat'), isTrue);
      for (
        var i = 0;
        i < 30 && !api.calls.any((r) => r.path == '/messages/channel/c1');
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(
        api.calls.any((r) => r.path == '/messages/channel/c1'),
        isTrue,
        reason:
            'requests=${api.calls.map((r) => r.path).toList()}, location=${w.location}, error=${w.error}',
      );
      // A new explicit navigation retires the pending rail restoration, even
      // when it selects the same channel. A background result is not a click.
      if (next == 'members') {
        w.setSection('members');
      } else if (next == 'same-channel') {
        w.setSection('chat');
      } else if (next == 'channel') {
        await t.runAsync(() => w.selectChannel(second));
      }
      final accepted = w.location.uri;
      response.complete({'messages': []});
      for (var i = 0; i < 12; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
      if (next == 'unchanged') {
        expect(w.location.thread?.channelId, 'c1');
        expect(w.location.thread?.itemId, 'root');
        expect(w.messageDomain.threadIdentity?.parentMessageId, 'root');
      } else {
        expect(w.location.uri, accepted);
        expect(w.location.thread, isNull);
        expect(w.messageDomain.threadIdentity, isNull);
        expect(
          api.calls.where((r) => r.path == '/channels/c1/threads/root'),
          isEmpty,
        );
      }
      expect(t.takeException(), isNull);
    });
  }
}
