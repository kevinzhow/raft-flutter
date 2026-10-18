import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/thread_agent_followers.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/thread_agent_followers_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'thread_agent_followers_test.dart' show follower, settle;

class _EventClient extends RaftClient {
  _EventClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }

  final incoming = StreamController<RaftEvent>.broadcast(sync: true);
  int followerReads = 0;
  @override
  Stream<RaftEvent> get events => incoming.stream;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    if (path == '/channels/threads/followers') followerReads++;
    return super.get(path, query: query);
  }

  void followersChanged(Object? payload) =>
      incoming.add(RaftEvent('thread:followers-updated', payload));
}

class _Fixture implements ThreadAgentFollowersAuthority {
  _Fixture() {
    client = _EventClient(api);
    api.routes['GET /channels/threads/followers'] = (o) => {
      'threads': [
        for (final id in '${o.queryParameters['threadChannelIds']}'.split(','))
          _row(id, 'Before'),
      ],
    };
    api.routes['GET /agents'] = (_) => [];
  }

  final api = MessageAdapter();
  @override
  late final _EventClient client;
  @override
  RaftRecord? server = RaftRecord({'id': 's1', 'role': 'owner'});
  ThreadAgentFollowers? _store;
  ThreadAgentFollowers get store => _store ??= ThreadAgentFollowers(this);
  int get reads => api.calls
      .where((o) => o.method == 'GET' && o.path.endsWith('/followers'))
      .length;

  Future<void> dispose() async {
    _store?.dispose();
    await client.dispose();
    await client.incoming.close();
  }
}

Map<String, dynamic> _row(String thread, String label, {bool manage = true}) =>
    {
      'threadChannelId': thread,
      'canManage': manage,
      'agents': [follower('a1', label)],
    };

Map<String, dynamic> _result(String label, {bool manage = true}) => {
  'threads': [_row('t1', label, manage: manage)],
};

// Drain the coalescing microtask and the in-memory HTTP adapter, without a
// real network, socket, timer-based refresh, or private production data.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

Widget _view(WorkspaceController w, {String thread = 't1'}) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topRight,
      child: ThreadAgentFollowersView(controller: w, threadChannelId: thread),
    ),
  ),
);

Future<WorkspaceController> _mount(WidgetTester tester, _Fixture f) async {
  final w = WorkspaceController(f.client)..server = f.server;
  addTearDown(() async {
    w.dispose();
    await f.dispose();
  });
  tester.view.physicalSize = const Size(600, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  await tester.pumpWidget(_view(w));
  await settle(tester);
  await tester.tap(find.byKey(const Key('thread-followers-header-trigger')));
  await tester.pumpAndSettle();
  return w;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'dedicated events refresh cached rosters and coalesce a burst',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.store.load(['t1']);
      final refreshed = Completer<void>();
      void accepted() {
        if (f.store.roster('t1')?.agents.single.label == 'After' &&
            !refreshed.isCompleted) {
          refreshed.complete();
        }
      }

      f.store.addListener(accepted);
      addTearDown(() => f.store.removeListener(accepted));
      f.api.routes['GET /channels/threads/followers'] = (_) => _result('After');
      for (var i = 0; i < 10; i++) {
        f.client.followersChanged({'threadChannelId': 't1'});
      }
      f.client.followersChanged({'threadChannelId': 'unopened'});
      f.client.followersChanged({'threadChannelId': 42});
      f.client.followersChanged(null);
      await refreshed.future.timeout(const Duration(seconds: 5));
      expect(f.reads, 2);
      expect(f.store.roster('t1')!.agents.single.label, 'After');
      expect(f.store.roster('unopened'), isNull);
      f.store.request('t1');
      await _flush();
      expect(f.reads, 2, reason: 'reopening consumes the refreshed cache');
    },
  );

  test(
    'a late earlier read cannot overwrite a newer roster or permission',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.store.load(['t1']);
      final old = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      f.api.routes['GET /channels/threads/followers'] = (_) {
        started.complete();
        return old.future;
      };
      final pending = f.store.load(['t1'], force: true);
      await started.future;
      f.api.routes['GET /channels/threads/followers'] = (_) =>
          _result('Current', manage: false);
      await f.store.load(['t1'], force: true);
      old.complete(_result('Stale manager'));
      await pending;
      expect(f.store.roster('t1')!.agents.single.label, 'Current');
      expect(f.store.roster('t1')!.canManage, isFalse);
    },
  );

  test(
    'bulk and realtime bursts respect the server limit of 100 IDs',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final ids = [for (var i = 0; i < 120; i++) 't$i'];
      final batches = <List<String>>[];
      var label = 'Before';
      f.api.routes['GET /channels/threads/followers'] = (o) {
        final batch = '${o.queryParameters['threadChannelIds']}'.split(',');
        if (batch.length > 100) throw StateError('server roster limit');
        batches.add(batch);
        return {
          'threads': [for (final id in batch) _row(id, label)],
        };
      };
      await f.store.load(ids);
      expect(ids.every((id) => f.store.roster(id)?.loaded == true), isTrue);
      expect(batches.map((batch) => batch.length), [100, 20]);
      batches.clear();
      label = 'After';
      final accepted = Completer<void>();
      void changed() {
        if (f.store.roster(ids.last)?.agents.single.label == 'After' &&
            !accepted.isCompleted) {
          accepted.complete();
        }
      }

      f.store.addListener(changed);
      addTearDown(() => f.store.removeListener(changed));
      for (final id in ids) {
        f.client.followersChanged({'threadChannelId': id});
      }
      await accepted.future.timeout(const Duration(seconds: 5));
      expect(batches.map((batch) => batch.length), [100, 20]);
      expect(batches.expand((batch) => batch), unorderedEquals(ids));
    },
  );

  for (final change in ['account', 'server', 'role', 'generation']) {
    test(
      'a late read after $change change is discarded without a prior getter',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        final response = Completer<Map<String, dynamic>>();
        final started = Completer<void>();
        f.api.routes['GET /channels/threads/followers'] = (_) {
          started.complete();
          return response.future;
        };
        final pending = f.store.load(['t1']);
        await started.future;
        switch (change) {
          case 'account':
            f.client.user = RaftRecord({'id': 'bob'});
          case 'server':
            f.server = RaftRecord({'id': 's2', 'role': 'owner'});
            f.client.selectServer('s2');
          case 'role':
            f.server = RaftRecord({'id': 's1', 'role': 'member'});
          case 'generation':
            f.client.selectServer(null);
            f.client.selectServer('s1');
        }
        response.complete(_result('Old identity'));
        await pending;
        expect(f.store.roster('t1'), isNull);
        f.api.routes['GET /channels/threads/followers'] = (_) =>
            _result('New identity', manage: false);
        await f.store.load(['t1']);
        expect(f.store.roster('t1')!.agents.single.label, 'New identity');
        expect(f.store.roster('t1')!.error, isFalse);
      },
    );
  }

  test('a late removal cannot change the roster of a new authority', () async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.store.load(['t1']);
    final response = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    f.api.routes['DELETE /channels/threads/t1/followers/agents/a1'] = (_) {
      started.complete();
      return response.future;
    };
    final pending = f.store.remove('t1', 'a1');
    await started.future;
    f.server = RaftRecord({'id': 's1', 'role': 'member'});
    await f.store.load(['t1'], force: true);
    response.complete({'removed': true, 'undoToken': 'fixture-undo'});
    expect(await pending, isNull);
    expect(f.store.roster('t1')!.agents.single.label, 'Before');
  });

  test('a late undo does not reload into another account', () async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.store.load(['t1']);
    final response = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    f.api.routes['POST /channels/threads/t1/followers/agents/a1/restore'] =
        (_) {
          started.complete();
          return response.future;
        };
    final pending = f.store.restore('t1', 'a1', 'fixture-undo');
    await started.future;
    f.client.user = RaftRecord({'id': 'bob'});
    response.complete({'restored': true});
    expect(await pending, isFalse);
    expect(f.reads, 1);
    expect(f.store.roster('t1'), isNull);
  });

  test('dispose cancels queued reads and the realtime subscription', () async {
    final f = _Fixture();
    f.store.request('t1');
    f.store.dispose();
    f._store = null;
    addTearDown(f.dispose);
    f.client.followersChanged({'threadChannelId': 't1'});
    await _flush();
    expect(f.reads, 0);
    expect(f.client.followerReads, 0);
    expect(f.client.incoming.hasListener, isFalse);
  });

  test(
    'overlapping bulk reads accept the newest result for each thread',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final old = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      f.api.routes['GET /channels/threads/followers'] = (_) {
        started.complete();
        return old.future;
      };
      final pending = f.store.load(['t1', 't2']);
      await started.future;
      f.api.routes['GET /channels/threads/followers'] = (_) =>
          _result('Current');
      await f.store.load(['t1'], force: true);
      old.complete({
        'threads': [_row('t1', 'Stale'), _row('t2', 'Second')],
      });
      await pending;
      expect(f.store.roster('t1')!.agents.single.label, 'Current');
      expect(f.store.roster('t2')!.agents.single.label, 'Second');
    },
  );

  test(
    'a read started before removal cannot restore the removed follower',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.store.load(['t1']);
      final old = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      f.api.routes['GET /channels/threads/followers'] = (_) {
        started.complete();
        return old.future;
      };
      final pending = f.store.load(['t1'], force: true);
      await started.future;
      f.api.routes['DELETE /channels/threads/t1/followers/agents/a1'] = (_) => {
        'removed': true,
        'undoToken': 'fixture-undo',
      };
      expect(await f.store.remove('t1', 'a1'), 'fixture-undo');
      old.complete(_result('Before'));
      await pending;
      expect(f.store.roster('t1')!.agents, isEmpty);
      expect(f.store.roster('t1')!.loading, isFalse);
    },
  );

  testWidgets('removing the last follower and undoing restores the open list', (
    tester,
  ) async {
    final f = _Fixture();
    var removed = false;
    f.api.routes['GET /channels/threads/followers'] = (_) =>
        removed ? {'threads': []} : _result('Before');
    f.api.routes['DELETE /channels/threads/t1/followers/agents/a1'] = (_) {
      removed = true;
      return {'removed': true, 'undoToken': 'fixture-undo'};
    };
    f.api.routes['POST /channels/threads/t1/followers/agents/a1/restore'] =
        (o) {
          expect(o.data, {'undoToken': 'fixture-undo'});
          removed = false;
          return {'restored': true};
        };
    final w = await _mount(tester, f);
    await tester.tap(find.byKey(const Key('thread-follower-remove')));
    await settle(tester);
    expect(
      find.byKey(const Key('thread-followers-header-trigger')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('toast-action')));
    await settle(tester);
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('Restored Before as a follower.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(_view(w));
    await settle(tester);
    await tester.tap(find.byKey(const Key('thread-followers-header-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets(
    'failed realtime refresh retries in place and stays resolved on reopen',
    (tester) async {
      final f = _Fixture();
      final w = await _mount(tester, f);
      f.api.routes['GET /channels/threads/followers'] = (_) =>
          throw StateError('fixture offline');
      f.client.followersChanged({'threadChannelId': 't1'});
      await settle(tester);
      expect(find.text("Followers couldn't be loaded."), findsOneWidget);
      f.api.routes['GET /channels/threads/followers'] = (_) =>
          _result('Recovered');
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Recovered'), findsOneWidget);
      expect(find.text("Followers couldn't be loaded."), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_view(w));
      await settle(tester);
      await tester.tap(
        find.byKey(const Key('thread-followers-header-trigger')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recovered'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'a role change reloads the mounted roster without stale controls',
    (tester) async {
      final f = _Fixture();
      final w = await _mount(tester, f);
      expect(find.byKey(const Key('thread-follower-remove')), findsOneWidget);
      f.api.routes['GET /channels/threads/followers'] = (_) =>
          _result('Viewer', manage: false);
      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      w.notifyListeners();
      await settle(tester);
      expect(find.text('Viewer'), findsOneWidget);
      expect(find.byKey(const Key('thread-follower-remove')), findsNothing);
      expect(f.reads, 2);
    },
  );

  testWidgets(
    'switching threads clears an Undo that belongs to the old thread',
    (tester) async {
      final f = _Fixture();
      f.api.routes['DELETE /channels/threads/t1/followers/agents/a1'] = (_) => {
        'removed': true,
        'undoToken': 'fixture-undo',
      };
      final w = await _mount(tester, f);
      await tester.tap(find.byKey(const Key('thread-follower-remove')));
      await settle(tester);
      expect(find.text('Undo'), findsOneWidget);
      await tester.pumpWidget(_view(w, thread: 't2'));
      await settle(tester);
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Before'), findsOneWidget);
      expect(w.services.threadFollowers.roster('t1')!.agents, isEmpty);
      expect(f.api.calls.where((o) => o.path.endsWith('/restore')), isEmpty);
    },
  );

  testWidgets(
    'replacing the controller rebinds events and rejects late removal feedback',
    (tester) async {
      final old = _Fixture();
      await _mount(tester, old);
      final removed = Completer<Map<String, dynamic>>();
      old.api.routes['DELETE /channels/threads/t1/followers/agents/a1'] = (_) =>
          removed.future;
      await tester.tap(find.byKey(const Key('thread-follower-remove')));
      await settle(tester);
      final next = _Fixture();
      next.api.routes['GET /channels/threads/followers'] = (_) =>
          _result('Replacement');
      final replacement = WorkspaceController(next.client)
        ..server = next.server;
      addTearDown(() async {
        replacement.dispose();
        await next.dispose();
      });
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(_view(replacement));
      await settle(tester);
      removed.complete({'removed': true, 'undoToken': 'fixture-undo'});
      await settle(tester);
      expect(find.text('Replacement'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      next.api.routes['GET /channels/threads/followers'] = (_) =>
          _result('Live replacement');
      next.client.followersChanged({'threadChannelId': 't1'});
      await settle(tester);
      expect(find.text('Live replacement'), findsOneWidget);
      old.client.followersChanged({'threadChannelId': 't1'});
      await settle(tester);
      expect(find.text('Live replacement'), findsOneWidget);
    },
  );

  testWidgets('open and reopened follower popovers reflect dedicated events', (
    tester,
  ) async {
    final f = _Fixture();
    final w = await _mount(tester, f);
    final trigger = find.byKey(const Key('thread-followers-header-trigger'));
    expect(find.text('Before'), findsOneWidget);
    f.api.routes['GET /channels/threads/followers'] = (_) =>
        _result('After', manage: false);
    f.client.followersChanged({'threadChannelId': 't1'});
    await settle(tester);
    expect(find.text('After'), findsOneWidget);
    expect(find.text('Before'), findsNothing);
    expect(find.byKey(const Key('thread-follower-remove')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    f.api.routes['GET /channels/threads/followers'] = (_) =>
        _result('While closed');
    f.client.followersChanged({'threadChannelId': 't1'});
    await settle(tester);
    expect(
      w.services.threadFollowers.roster('t1')!.agents.single.label,
      'While closed',
    );
    await tester.pumpWidget(_view(w));
    await settle(tester);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('While closed'), findsOneWidget);

    f.api.routes['GET /channels/threads/followers'] = (_) =>
        _result('Message refresh');
    f.client.incoming.add(RaftEvent('message:new', {'channelId': 't1'}));
    await settle(tester);
    expect(find.text('Message refresh'), findsOneWidget);

    f.api.routes['GET /channels/threads/followers'] = (_) => {'threads': []};
    f.client.followersChanged({'threadChannelId': 't1'});
    await settle(tester);
    expect(
      trigger,
      findsNothing,
      reason: 'removing the last follower hides the count',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
