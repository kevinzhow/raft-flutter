import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;

/// Server-level data (agents, members, Saved total, live activity) belongs to
/// the server identity, not the open channel: switching or joining channels
/// keeps every already-painted row identical frame by frame.
class _EventClient extends RaftClient {
  _EventClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
}

const _cindy = <String, dynamic>{
  'id': 'cindy',
  'name': 'cindy',
  'displayName': 'Cindy',
  'avatarUrl': 'pixel:cat',
  'description': 'Designs the visual system',
  'status': 'active',
  'runtime': 'codex',
  'model': 'gpt-5-codex',
};

int _reads(MessageAdapter a, String path) =>
    a.calls.where((c) => c.method == 'GET' && c.path == path).length;

Future<(WorkspaceController, MessageAdapter, _EventClient)> _fixture(
  WidgetTester t,
) async {
  SharedPreferences.setMockInitialValues({});
  final a = MessageAdapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice', 'name': 'alice'},
  };
  a.routes['GET /agents'] = (_) => [_cindy];
  a.routes['GET /servers/s1/members'] = (_) => [
    {'userId': 'alice', 'name': 'alice', 'role': 'owner'},
    {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob', 'role': 'member'},
  ];
  a.routes['GET /servers/s1/machines'] = (_) => {'machines': []};
  a.routes['GET /channels/c1/members'] = (_) => {
    'humans': [
      {'id': 'alice', 'name': 'alice'},
    ],
    'agents': [_cindy],
  };
  a.routes['GET /channels/c2/members'] = (_) => {
    'humans': [
      {'id': 'alice', 'name': 'alice'},
      {'id': 'bob', 'name': 'bob'},
    ],
    'agents': [],
  };
  a.routes['GET /channels/saved'] = (_) => {'globalTotal': 7};
  a.routes['GET /channels/inbox'] = (_) => {'items': []};
  a.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  a.routes['GET /product-feedback/tickets'] = (_) => {'unread_total': 0};
  a.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  a.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  final client = (await t.runAsync(() async {
    final client = _EventClient(a);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    return client;
  }))!;
  final w = WorkspaceController(client);
  addTearDown(w.dispose);
  final c1 = RaftChannel({'id': 'c1', 'name': 'design', 'joined': true});
  final c2 = RaftChannel({'id': 'c2', 'name': 'release', 'joined': true});
  w.channel = c1;
  w.channels = [c1, c2];
  w.loading = false;
  w.ledger.switchServer('s1');
  w.server = RaftRecord({
    'id': 's1',
    'slug': 'demo',
    'name': 'Alpha',
    'role': 'owner',
  });
  return (w, a, client);
}

/// Lets fake-zone pipelines and the real transport both progress.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 10));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await t.pump();
}

/// Pumps frames (letting real I/O land in between) and checks every one.
Future<void> _everyFrame(WidgetTester t, void Function(int) check) async {
  check(-1);
  for (var frame = 0; frame < 10; frame++) {
    await t.pump(const Duration(milliseconds: 16));
    check(frame);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
}

void main() {
  testWidgets(
    'channel switch and join keep the pinned agent, Saved badge and live activity bar identical every frame',
    (t) async {
      final (w, a, client) = await _fixture(t);
      w.section = 'chat';
      w.sidebarOrder = {
        'pinned': [
          {'kind': 'agent', 'id': 'cindy'},
        ],
      };
      t.view.physicalSize = const Size(1440, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: WorkspaceView(
            controller: w,
            appearance: const RaftAppearance(light: RaftFamily.elegant),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      );
      await _settle(t);
      await _settle(t);
      client.stream.add(
        const RaftEvent('agent:activity', {
          'agentId': 'cindy',
          'serverId': 's1',
          'activity': 'working',
          'detail': 'Drafting tokens',
        }),
      );
      await t.pump();

      final pinned = find.byKey(const ValueKey('sidebar-agent:cindy'));
      final bar = find.byKey(const Key('live-agent-activity-bar'));
      final saved = find.byWidgetPredicate(
        (widget) =>
            widget is RaftNavItem && widget.role == RaftNavItemRole.saved,
      );
      List<Object?> facts() => [
        pinned.evaluate().length,
        if (pinned.evaluate().isNotEmpty) t.getRect(pinned),
        bar.evaluate().length,
        find.textContaining('Drafting tokens').evaluate().length,
        t.widget<RaftNavItem>(saved).count,
      ];
      final before = facts();
      expect(before, [1, isA<Rect>(), 1, 1, 7]);
      final agentReads = _reads(a, '/agents');

      // Channel switch: nothing server-level clears or reflows.
      w.channel = w.channels[1];
      w.notifyListeners();
      await _everyFrame(t, (frame) {
        expect(facts(), before, reason: 'switch frame $frame');
      });

      // Joining/creating a channel changes the channel projection only. The
      // Saved total revalidates in place: it is never blank in between.
      a.routes['GET /channels/saved'] = (_) => {'globalTotal': 8};
      w.channels = [
        ...w.channels,
        RaftChannel({'id': 'c3', 'name': 'new', 'joined': true}),
      ];
      w.notifyListeners();
      await _everyFrame(t, (frame) {
        final now = facts();
        expect(now.take(4), before.take(4), reason: 'join frame $frame');
        expect(now.last, anyOf(7, 8), reason: 'join frame $frame');
      });
      await _settle(t);
      expect(facts().last, 8);
      expect(_reads(a, '/agents'), agentReads);

      // A server-level identity change still clears.
      w.server = RaftRecord({
        'id': 's1',
        'slug': 'demo',
        'name': 'Alpha',
        'role': 'guest',
      });
      w.notifyListeners();
      await t.pump();
      expect(pinned, findsNothing);
      expect(bar, findsNothing);
      await _settle(t);

      await t.pumpWidget(const SizedBox());
      await _settle(t);
      await t.runAsync(client.stream.close);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'the @ popup lists people at its first frame and keeps them across a channel switch',
    (t) async {
      final (w, a, client) = await _fixture(t);
      // The workspace preloads the shared directory at server selection.
      w.entityDirectory.ensureAuthors();
      await _settle(t);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await _settle(t);
      final agentReads = _reads(a, '/agents'),
          memberReads = _reads(a, '/servers/s1/members');

      Finder row(String type, String id) =>
          find.byKey(ValueKey('composer-suggestion-$type-$id'));
      Future<void> type(String text) async {
        await t.enterText(find.byType(EditableText).last, text);
        // First frame after the trigger: no I/O in between.
        await t.pump();
      }

      await type('@');
      expect(row('agent', 'cindy'), findsOneWidget);
      expect(row('user', 'bob'), findsOneWidget);
      final cindy = t.getRect(row('agent', 'cindy'));
      final bob = t.getRect(row('user', 'bob'));
      // c1 roster: cindy in channel (group 0), bob not (group 1).
      expect(cindy.top, lessThan(bob.top));
      await _everyFrame(t, (frame) {
        expect(t.getRect(row('agent', 'cindy')), cindy, reason: '$frame');
        expect(t.getRect(row('user', 'bob')), bob, reason: '$frame');
      });

      await type('');
      w.channel = w.channels[1];
      w.notifyListeners();
      await _settle(t);
      await type('@');
      expect(row('agent', 'cindy'), findsOneWidget);
      expect(row('user', 'bob'), findsOneWidget);
      final switched = [
        t.getRect(row('agent', 'cindy')),
        t.getRect(row('user', 'bob')),
      ];
      // c2 roster: bob is in channel, cindy is not.
      expect(switched[1].top, lessThan(switched[0].top));
      await _everyFrame(t, (frame) {
        expect(
          [t.getRect(row('agent', 'cindy')), t.getRect(row('user', 'bob'))],
          switched,
          reason: '$frame',
        );
      });

      // Revisiting c1 shows its cached roster at once.
      await type('');
      w.channel = w.channels[0];
      w.notifyListeners();
      await t.pump();
      await type('@');
      expect(
        t.getRect(row('agent', 'cindy')).top,
        lessThan(t.getRect(row('user', 'bob')).top),
      );
      expect(_reads(a, '/agents'), agentReads);
      expect(_reads(a, '/servers/s1/members'), memberReads);

      await t.pumpWidget(const SizedBox());
      await t.runAsync(client.stream.close);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'an @mention opens its dialog at once from the shared directory',
    (t) async {
      final (w, a, client) = await _fixture(t);
      w.entityDirectory.ensureAuthors();
      await _settle(t);
      final presentation = MessagePresentation(
        controller: w,
        message: RaftMessage({
          'id': 'm1',
          'channelId': 'c1',
          'content': 'ping @bob',
          'sourceServerId': 's1',
        }),
        onExternalLink: (_) {},
      );
      late BuildContext context;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final calls = a.calls.length;
      unawaited(presentation.open(context, 'raft-ref://mention/user/bob'));
      await t.pump();
      await t.pump();
      expect(find.widgetWithText(AlertDialog, 'Bob'), findsOneWidget);
      expect(find.text('member'), findsOneWidget);
      Navigator.of(context).pop();
      await t.pumpAndSettle();

      unawaited(presentation.open(context, 'raft-ref://mention/agent/cindy'));
      await t.pump();
      await t.pump();
      expect(find.widgetWithText(AlertDialog, 'Cindy'), findsOneWidget);
      expect(find.text('Designs the visual system'), findsOneWidget);
      expect(a.calls.length, calls, reason: 'no per-tap directory fetch');

      // A server-level identity change closes the projection.
      w.server = RaftRecord({'id': 's1', 'slug': 'demo', 'role': 'guest'});
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await t.pumpWidget(const SizedBox());
      await t.runAsync(client.stream.close);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'the account feedback inbox survives channel switches and thread opens',
    (t) async {
      final (w, a, client) = await _fixture(t);
      a.routes['GET /product-feedback/tickets'] = (_) => {
        'tickets': [
          {
            'id': '0b0c4c1e-8d4b-4f55-9a3e-2b6a8f3f9b11',
            'kind': 'bug',
            'status': 'open',
            'message': 'Sidebar flickers',
            'created_at': 1,
            'updated_at': 2,
            'unread': false,
            'unread_count': 0,
            'attachment_count': 0,
            'comment_count': 0,
          },
        ],
        'next_cursor': null,
        'unread_total': 0,
      };
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: SourceFeedbackView(controller: w)),
        ),
      );
      await _settle(t);
      final row = find.textContaining('Sidebar flickers');
      expect(row, findsWidgets);
      final reads = _reads(a, '/product-feedback/tickets');
      for (var i = 0; i < 3; i++) {
        w.channel = w.channels[i.isEven ? 1 : 0];
        w.channelGeneration++;
        w.threadGeneration++;
        w.notifyListeners();
        await _everyFrame(t, (frame) {
          expect(row, findsWidgets, reason: 'switch $i frame $frame');
        });
      }
      expect(_reads(a, '/product-feedback/tickets'), reads);

      await t.pumpWidget(const SizedBox());
      await _settle(t);
      await t.runAsync(client.stream.close);
      expect(t.takeException(), isNull);
    },
  );
}
