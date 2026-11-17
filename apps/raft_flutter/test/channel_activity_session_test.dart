import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_activity_session.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;
import 'message_presentation_test.dart' show fixture;
import 'channel_activity_chat_test.dart' show activityRow;

void main() {
  testWidgets(
    'matching feature notices switch activity off and back on without reconnect',
    (t) async {
      final client = ActivityClient();
      await client.login('fixture', 'fixture');
      client.selectServer('s1');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channel = RaftChannel({
          'id': 'c1',
          'type': 'channel',
          'threadSort': 'activity',
        });
      addTearDown(w.dispose);
      void flag(bool enabled) {
        client.responses['POST /feature-flags/evaluate'] = {
          'evaluations': [
            {'key': 'channel_thread_sort_v0', 'enabled': enabled},
          ],
        };
      }

      flag(true);
      client.responses['GET /messages/channel/c1/by-activity'] = {
        'messages': [],
      };
      final p = ChannelActivityPresentation(w, thread: false);
      addTearDown(p.dispose);
      await p.session.ready;
      await t.pump();
      expect(p.mode, isTrue);
      flag(false);
      client.emit('server:features-changed', {
        'serverId': 's2',
        'keys': ['channel_thread_sort_v0'],
      });
      client.emit('server:features-changed', {
        'serverId': 's1',
        'keys': ['unrelated'],
      });
      await t.pump();
      expect(p.mode, isTrue);
      client.emit('server:features-changed', {
        'serverId': 's1',
        'keys': ['channel_thread_sort_v0'],
      });
      await p.session.ready;
      await t.pump();
      expect(p.mode, isFalse);
      expect(p.session.store.windows, isEmpty);
      flag(true);
      client.emit('server:features-changed', {'serverId': 's1'});
      await p.session.ready;
      await t.pump();
      expect(p.mode, isTrue);
      expect(
        client.posts.where((s) => s.endsWith('/by-activity')),
        hasLength(2),
      );
    },
  );
  testWidgets('flag and regular channel type gate activity requests', (
    t,
  ) async {
    for (final (enabled, type, sort, expected) in [
      (false, 'channel', 'activity', false),
      (true, 'channel', 'time', false),
      (true, 'joint', 'activity', false),
      (true, 'dm', 'activity', false),
      (true, 'private', 'activity', true),
      (true, 'channel', 'activity', true),
    ]) {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'channel_thread_sort_v0', 'enabled': enabled},
        ],
      };
      api.routes['GET /messages/channel/c1/by-activity'] = (_) => {
        'messages': [],
      };
      w.channel = RaftChannel({'id': 'c1', 'type': type, 'threadSort': sort});
      late ChannelActivityPresentation p;
      await t.runAsync(() async {
        p = ChannelActivityPresentation(w, thread: false);
        await p.session.ready;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      addTearDown(p.dispose);
      await t.pumpAndSettle();
      expect(p.mode, expected, reason: '$enabled/$type/$sort');
      final calls = api.calls
          .where((call) => call.path.endsWith('/by-activity'))
          .toList();
      expect(calls.length, expected ? 1 : 0, reason: '$enabled/$type/$sort');
      if (expected) expect(calls.single.queryParameters, {'limit': 50});
    }
  });

  testWidgets(
    'context jumps retain pages but show seq order; time sort releases pages',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'channel_thread_sort_v0', 'enabled': true},
        ],
      };
      final first = activityRow('first', 1, '2026-11-01T00:00:00Z');
      final second = activityRow('second', 2, '2026-11-02T00:00:00Z');
      api.routes['GET /messages/channel/c1/by-activity'] = (_) => {
        'messages': [
          {...first, 'activityAt': '2026-11-03T00:00:00Z'},
          second,
        ],
      };
      w.channel = RaftChannel({
        'id': 'c1',
        'type': 'channel',
        'threadSort': 'activity',
      });
      late ChannelActivityPresentation p;
      await t.runAsync(() async {
        p = ChannelActivityPresentation(w, thread: false);
        await p.session.ready;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      addTearDown(p.dispose);
      await t.pumpAndSettle();
      final seq = [RaftMessage(first), RaftMessage(second)];
      expect(p.rows(seq).map((m) => m.id), ['second', 'first']);
      w.messageDomain.state.hasNewer = true;
      expect(p.mode, isFalse);
      expect(p.rows(seq), same(seq));
      expect(p.session.store.windows, contains('c1'));
      w.messageDomain.state.hasNewer = false;
      expect(p.rows(seq).map((m) => m.id), ['second', 'first']);
      w.channel = RaftChannel({
        'id': 'c1',
        'type': 'channel',
        'threadSort': 'time',
      });
      p.update();
      expect(p.rows(seq), same(seq));
      expect(p.session.store.windows, isEmpty);
    },
  );

  testWidgets('late activity page cannot cross a server authority change', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    final pending = Completer<dynamic>();
    api.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'channel_thread_sort_v0', 'enabled': w.server?.id == 's1'},
      ],
    };
    api.routes['GET /messages/channel/c1/by-activity'] = (_) => pending.future;
    w.channel = RaftChannel({
      'id': 'c1',
      'type': 'channel',
      'threadSort': 'activity',
    });
    late ChannelActivityPresentation p;
    await t.runAsync(() async {
      p = ChannelActivityPresentation(w, thread: false);
      await p.session.ready;
    });
    addTearDown(p.dispose);
    expect(p.session.store.windows, contains('c1'));
    await t.runAsync(() async {
      w.client.selectServer('s2');
      w.server = RaftRecord({'id': 's2', 'role': 'owner'});
      w.notifyListeners();
      await p.session.ready;
      pending.complete({
        'messages': [activityRow('private-old', 1, '2026-11-01T00:00:00Z')],
      });
      await Future<void>.delayed(Duration.zero);
    });
    expect(p.mode, isFalse);
    expect(p.session.store.windows, isEmpty);
  });

  testWidgets(
    'socket replies bump the retained parent and reconnect refreshes once',
    (t) async {
      final client = ActivityClient();
      await client.login('fixture', 'fixture');
      client.selectServer('s1');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channel = RaftChannel({
          'id': 'c1',
          'type': 'channel',
          'threadSort': 'activity',
        });
      addTearDown(w.dispose);
      client.responses['POST /feature-flags/evaluate'] = {
        'evaluations': [
          {'key': 'channel_thread_sort_v0', 'enabled': true},
        ],
      };
      client.responses['GET /messages/channel/c1/by-activity'] = {
        'messages': [activityRow('parent', 1, '2026-11-01T00:00:00Z')],
      };
      final p = ChannelActivityPresentation(w, thread: false);
      addTearDown(p.dispose);
      await p.session.ready;
      await t.pump();
      final initial = client.posts
          .where((s) => s.endsWith('/by-activity'))
          .length;
      client.emit('thread:updated', {
        'parentMessageId': 'parent',
        'threadChannelId': 't1',
        'lastReplyAt': '2026-11-03T00:00:00Z',
        'replyCount': 1,
        'latestReply': {
          'conversationContext': {'parentChannelId': 'c1'},
        },
      });
      await t.pump();
      expect(p.window!.bumps['parent'], '2026-11-03T00:00:00Z');
      expect(
        client.posts.where((s) => s.endsWith('/by-activity')),
        hasLength(initial),
      );
      client.emit('rooms:joined', {});
      await t.pump();
      expect(
        client.posts.where((s) => s.endsWith('/by-activity')),
        hasLength(initial + 1),
      );
    },
  );
}
