import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_server_unread.dart';
import 'package:raft_flutter/features/workspace_menu_invite.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  testWidgets(
    'Source server summary paints only proven Activity count, accepting numeric safe integers',
    (t) async {
      final (w, api) = await pageFixture(t);
      final store = SourceServerUnreadStore(w);
      addTearDown(store.dispose);
      api.routes['GET /servers/unread-summary'] = (_) => [
        {'serverId': 'known', 'unreadCount': 100, 'activityUnreadCount': 2.0},
        {'serverId': 'legacy-only', 'unreadCount': 99},
        {'serverId': 'negative', 'unreadCount': 1, 'activityUnreadCount': -1},
        {'serverId': 'fraction', 'unreadCount': 1, 'activityUnreadCount': 1.5},
        {
          'serverId': 'string-activity',
          'unreadCount': '4',
          'activityUnreadCount': '4',
        },
        {
          'serverId': 'muted',
          'unreadCount': 10,
          'activityUnreadCount': 3,
          'serverPushMuted': true,
        },
        {
          'serverId': 'unsafe',
          'unreadCount': 1,
          'activityUnreadCount': 9007199254740992,
        },
        {'serverId': '', 'unreadCount': 1, 'activityUnreadCount': 8},
      ];
      await t.runAsync(store.refresh);
      expect(store['known']!.activityUnreadCount, 2);
      for (final id in [
        'legacy-only',
        'negative',
        'fraction',
        'string-activity',
        'unsafe',
      ]) {
        expect(store[id]!.activityUnreadCount, isNull);
      }
      expect(store['muted']!.activityUnreadCount, 3);
      expect(store['muted']!.pushMuted, isTrue);
      expect(store[''], isNull);
    },
  );
  testWidgets(
    'Source summary retains accepted values on error and rejects a late principal/role receipt',
    (t) async {
      final (w, api) = await pageFixture(t);
      final store = SourceServerUnreadStore(w);
      addTearDown(store.dispose);
      api.routes['GET /servers/unread-summary'] = (_) => [
        {'serverId': 's2', 'unreadCount': 9, 'activityUnreadCount': 4},
      ];
      await t.runAsync(store.refresh);
      expect(store['s2']!.activityUnreadCount, 4);
      api.routes['GET /servers/unread-summary'] = (_) =>
          throw StateError('held fixture failure');
      await t.runAsync(store.refresh);
      expect(store['s2']!.activityUnreadCount, 4);
      final held = Completer<dynamic>();
      api.routes['GET /servers/unread-summary'] = (_) => held.future;
      late Future<void> pending;
      await t.runAsync(() async {
        pending = store.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      w.server = RaftRecord({...w.server!.json, 'role': 'member'});
      store.synchronize();
      held.complete([
        {'serverId': 's2', 'unreadCount': 9, 'activityUnreadCount': 9},
      ]);
      await t.runAsync(() => pending);
      expect(store['s2'], isNull);
    },
  );
  test(
    'Source invite email validation retains exact limits and invalid domains',
    () {
      for (final email in [
        ' person@example.com ',
        'person+tag@sub.example.com',
      ]) {
        expect(sourceInviteEmailError(email), isNull);
      }
      for (final email in [
        '',
        'person@.example.com',
        'person@example..com',
        'person@example.com.',
        'person@@example.com',
        'person @example.com',
        '${'a' * 65}@example.com',
        'person@localhost',
      ]) {
        expect(sourceInviteEmailError(email), 'Enter a valid email address');
      }
    },
  );
}
