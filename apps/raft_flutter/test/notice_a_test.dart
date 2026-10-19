import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_flutter/features/incoming_share_picker.dart';
import 'package:raft_flutter/features/message_selection.dart';
import 'package:raft_flutter/features/pending_mention_actions.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_flutter/features/thread_actions.dart';
import 'package:raft_flutter/platform/incoming_share_staging.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show card, fixture, host;
import 'flutter_test_config.dart' show leakDebt;

/// Slice A of the transient-notice audit: every notice below must stop showing
/// when its cause ends (docs: lib/data/cause_notice.dart).

RaftClient _client() {
  final client = RaftClient(
    origin: 'https://fixture.invalid',
    sessionStore: MemorySessionStore(),
  )..user = RaftRecord({'id': 'u'});
  client.selectServer('s');
  return client;
}

Widget _app(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: child),
);

class _FailingFollow extends WorkspaceController {
  _FailingFollow(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async => {
    'threads': [],
  };
  @override
  Future<dynamic> command(String method, String path, {dynamic data}) =>
      Future<dynamic>.error(StateError('offline'));
}

void main() {
  // Leak debt (share flow): see docs/development.md, Leak tracking.
  leakDebt(const ['IncomingShareStaging', 'ValueNotifier<RaftTransferProgress?>']);
  testWidgets(
    'thread follow failure notice does not follow the widget to another thread',
    (t) async {
      final client = _client();
      final w = _FailingFollow(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'})
        ..messageDomain.state.threadParent = RaftMessage({
          'id': 'm1',
          'channelId': 'c',
          'content': 'one',
        });
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      Widget actions(String id) =>
          _app(ThreadActions(controller: w, parentMessageId: id));
      await t.pumpWidget(actions('m1'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('thread-follow-toggle')));
      await t.pumpAndSettle();
      expect(
        find.text('Thread notification settings could not be changed.'),
        findsOneWidget,
      );

      // Same State, another thread (the panel re-parents instead of rebuilding).
      w.messageDomain.state.threadParent = RaftMessage({
        'id': 'm2',
        'channelId': 'c',
        'content': 'two',
      });
      await t.pumpWidget(actions('m2'));
      await t.pumpAndSettle();
      expect(
        find.text('Thread notification settings could not be changed.'),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  test('selection limit notice ends when a row is deselected', () {
    final client = _client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's'})
      ..channel = RaftChannel({'id': 'c', 'name': 'c', 'type': 'channel'});
    final selection = _ManyMessages(w)..enter('m0');
    addTearDown(() async {
      selection.dispose();
      w.dispose();
      await client.dispose();
    });
    for (var i = 1; i < MessageSelection.limit; i++) {
      selection.toggle('m$i');
    }
    expect(selection.ids.length, MessageSelection.limit);
    selection.toggle('m39');
    expect(selection.error, 'Select up to 30 messages.');
    selection.toggle('m3');
    expect(selection.error, isNull);
  });

  testWidgets('forward failure banner ends when the destinations change', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final client = _client();
    final w = _FailingForward(client)
      ..server = RaftRecord({'id': 's'})
      ..channels = [
        for (final (id, name) in [
          ('src', 'general'),
          ('a', 'alpha'),
          ('b', 'beta'),
        ])
          RaftChannel({
            'id': id,
            'name': name,
            'type': 'channel',
            'joined': true,
            'createdAt': '2026-06-20T00:00:00.000Z',
          }),
      ];
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    await t.pumpWidget(
      _app(
        ForwardComposerPage(
          controller: w,
          desktop: true,
          messages: [
            RaftMessage({
              'id': 'm1',
              'messageType': 'chat',
              'channelId': 'src',
              'content': 'hello',
              'senderName': 'artin',
              'senderType': 'user',
              'createdAt': '2026-06-22T02:10:00.000Z',
            }),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    String? shown() => t
        .widget<RaftForwardDesktopDialog>(find.byType(RaftForwardDesktopDialog))
        .error;
    await t.tap(find.byKey(const ValueKey('forward-target-a')));
    await t.pump();
    await t.tap(find.byKey(const Key('forward-send')));
    await t.pumpAndSettle();
    expect(shown(), isNotNull);
    // Another destination: the banner described the previous selection.
    await t.tap(find.byKey(const ValueKey('forward-target-b')));
    await t.pump();
    expect(shown(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  group('incoming share picker notices', () {
    Future<_ShareClient> open(
      WidgetTester t, {
      List<Map<String, dynamic>>? servers,
      bool serversDown = false,
    }) async {
      final client = _ShareClient()
        ..serverRows =
            servers ??
            [
              {'id': 's0', 'name': 'Server 0', 'role': 'owner'},
            ]
        ..serversDown = serversDown;
      await t.pumpWidget(
        _app(
          IncomingSharePicker(
            client: client,
            staging: IncomingShareStaging(
              const IncomingShare(token: 't', text: 'hello', files: []),
            ),
            servers: [for (final s in client.serverRows) RaftRecord(s)],
            valid: () => true,
            onContinue: (server, target) async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await client.dispose();
      });
      return client;
    }

    Future<void> refresh(WidgetTester t, _ShareClient c) async {
      c.bus.add(const RaftEvent('channel:updated', null));
      await t.pumpAndSettle();
    }

    const loadFailed = 'Conversations could not be loaded.';

    testWidgets('a failed refresh notice ends when the next refresh works', (
      t,
    ) async {
      final c = await open(t);
      expect(find.text('general'), findsOneWidget);
      c.channelsDown = true;
      await refresh(t, c);
      expect(find.byKey(const Key('incoming-share-notice')), findsOneWidget);
      expect(find.text(loadFailed), findsOneWidget);
      c.channelsDown = false;
      await refresh(t, c);
      expect(find.byKey(const Key('incoming-share-notice')), findsNothing);
      expect(find.text('general'), findsOneWidget);
    });

    testWidgets(
      'a lost selection notice ends when another destination is picked',
      (t) async {
        final c = await open(t);
        await t.tap(find.text('general'));
        await t.pumpAndSettle();
        expect(find.text('Add shared content'), findsOneWidget);
        // The directory no longer offers the chosen destination.
        c.hidden = {'c1'};
        await refresh(t, c);
        expect(
          find.text('The selected destination is no longer available.'),
          findsOneWidget,
        );
        await t.tap(find.text('lobby'));
        await t.pumpAndSettle();
        expect(find.text('Add shared content'), findsOneWidget);
        await t.tap(find.byTooltip('Back to destinations'));
        await t.pumpAndSettle();
        expect(
          find.text('The selected destination is no longer available.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a load error ends when the account turns out to have no server',
      (t) async {
        final c = await open(t, servers: [], serversDown: true);
        expect(find.text(loadFailed), findsOneWidget);
        c
          ..serversDown = false
          ..serverRows = [];
        c.bus.add(const RaftEvent('server:member-removed', null));
        await t.pumpAndSettle();
        expect(find.text(loadFailed), findsNothing);
        expect(find.text('No destinations available.'), findsOneWidget);
      },
    );
  });

  group('public server view notices', () {
    Widget view(
      _PublicClient client, {
      String slug = 'raft-design',
      PublicServerAccount? account,
    }) => _app(
      PublicServerView(
        client: client,
        slug: slug,
        account: account,
        onSignIn: () {},
        onRegister: () {},
        onUnavailable: () {},
      ),
    );

    void wide(WidgetTester t) {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Map<String, dynamic> msg(String id, {String? thread}) => {
      'id': id,
      'senderType': 'user',
      'sender': {'displayName': 'Wenyi', 'avatarUrl': null},
      'messageType': 'chat',
      'content': 'text $id',
      'createdAt': '2026-06-18T09:12:00.000Z',
      'threadId': thread,
      'replyCount': 0,
    };

    Map<String, _Route> routes(String slug) {
      final base = '/public/servers/$slug';
      return {
        'GET $base': (_, _) => {
          'server': {'id': slug, 'name': slug, 'slug': slug},
          'channels': [
            {'id': 'c1', 'name': 'general'},
          ],
          'canJoinAsGuest': true,
        },
        'GET $base/channels/c1/messages': (_, _) => {
          'messages': [msg('m1')],
        },
        'POST $base/join-as-guest': (_, _) => throw RaftApiException(
          'Failed to join this public server',
          status: 500,
        ),
      };
    }

    testWidgets('the sign-in prompt ends once the visitor is signed in', (
      t,
    ) async {
      wide(t);
      final client = _PublicClient(routes('raft-design'));
      await t.pumpWidget(view(client));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('rail-workspace')));
      await t.pumpAndSettle();
      const notice = ValueKey('public-server-selection-notice');
      expect(find.byKey(notice), findsOneWidget);
      client.user = RaftRecord({'id': 'u1'});
      await t.pumpWidget(
        view(
          client,
          account: PublicServerAccount(servers: const [], onSelect: (_) {}),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(notice), findsNothing);
    });

    testWidgets(
      'a join failure does not follow the visitor to another server',
      (t) async {
        wide(t);
        final client = _PublicClient(
          {...routes('raft-design'), ...routes('other')},
          user: {'id': 'u1'},
        );
        final account = PublicServerAccount(
          servers: const [],
          onSelect: (_) {},
        );
        await t.pumpWidget(view(client, account: account));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('public-join-guest')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('public-join-confirm')));
        await t.pumpAndSettle();
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        const error = ValueKey('public-server-join-error');
        expect(find.byKey(error), findsOneWidget);
        await t.pumpWidget(view(client, slug: 'other', account: account));
        await t.pumpAndSettle();
        expect(find.byKey(error), findsNothing);
      },
    );
  });

  testWidgets('action card failure ends when the card moves on', (t) async {
    final (w, _) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    // No route for the execute call: it fails.
    await t.pumpWidget(
      host(
        MessageActionCard(
          controller: w,
          message: card('integration:approve_agent_login'),
        ),
      ),
    );
    await t.tap(find.text('Approve Login').last);
    await t.pumpAndSettle();
    String? shown() =>
        t.widget<RaftActionCard>(find.byType(RaftActionCard)).error;
    expect(shown(), isNotNull);
    // Someone else executed it: the failure no longer describes this card.
    await t.pumpWidget(
      host(
        MessageActionCard(
          controller: w,
          message: card('integration:approve_agent_login', state: 'executed'),
        ),
      ),
    );
    await t.pump();
    expect(shown(), isNull);
  });

  testWidgets('selection copy failure ends with the selection', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(900, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final (w, a) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      for (final (id, seq) in [('parent', 1), ('later', 2)])
        {
          'id': id,
          'channelId': 'c1',
          'seq': seq,
          'senderId': 'alice',
          'senderType': 'user',
          'senderName': 'Alice',
          'content': 'Row $id',
          'messageType': 'chat',
        },
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'parent', 'later'};
    a.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    a.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    a.routes['GET /agents'] = (_) => [];
    a.routes['GET /servers/s1/members'] = (_) => [];
    a.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
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
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await t.pumpAndSettle();
    Future<void> select() async {
      final rect = t.getRect(find.byKey(const ValueKey('message-parent')));
      await t.longPressAt(Offset(rect.left + 2, rect.center.dy));
      await t.pumpAndSettle();
      await t.tap(find.text('Select Message'));
      await t.pumpAndSettle();
    }

    String? shown() =>
        t.widget<RaftSelectionToolbar>(find.byType(RaftSelectionToolbar)).error;
    await select();
    expect(shown(), isNull);
    t
        .widget<RaftSelectionToolbar>(find.byType(RaftSelectionToolbar))
        .onCopyMarkdown!();
    await t.pumpAndSettle();
    expect(shown(), 'Could not copy the selected messages.');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(RaftSelectionToolbar), findsNothing);
    await select();
    expect(shown(), isNull);
  });

  group('pending mention action notice', () {
    const stale =
        'That target is already in the channel, so no action is needed.';

    Map<String, dynamic> row(String id, String handle) => {
      'resolutionId': id,
      'targetType': 'user',
      'targetHandle': handle,
      'availableActions': ['add', 'notify'],
    };

    Future<_MentionWorkspace> mount(WidgetTester t) async {
      final client = _client();
      final w = _MentionWorkspace(client)
        ..channel = RaftChannel({'id': 'c1', 'name': 'one', 'type': 'channel'})
        ..pendingMentionActions['c1'] = [row('r1', 'ann'), row('r2', 'bob')]
        ..pendingMentionActions['c2'] = [row('r9', 'cy')];
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      await t.pumpWidget(_app(PendingMentionActions(controller: w)));
      await t.tap(find.text('Notify').first);
      await t.pump();
      await t.pump();
      expect(find.text(stale), findsOneWidget);
      return w;
    }

    testWidgets('ends with the composer scope that raised it', (t) async {
      final w = await mount(t);
      w.channel = RaftChannel({'id': 'c2', 'name': 'two', 'type': 'channel'});
      w.notifyListeners();
      await t.pump();
      expect(find.text(stale), findsNothing);
      // Coming back must not resurrect it.
      w.channel = RaftChannel({'id': 'c1', 'name': 'one', 'type': 'channel'});
      w.notifyListeners();
      await t.pump();
      expect(find.text(stale), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('ends when the next send replaces the pending rows', (t) async {
      final w = await mount(t);
      w.pendingMentionActions['c1'] = [row('r5', 'eve')];
      w.notifyListeners();
      await t.pump();
      expect(find.text(stale), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('ends when the user dismisses a row', (t) async {
      final w = await mount(t);
      await t.tap(find.text('Ignore').last);
      await t.pump();
      expect(find.text(stale), findsNothing);
      expect(w.pendingMentionActions['c1']!.length, 1);
      await t.pumpWidget(const SizedBox());
    });
  });
}

class _MentionWorkspace extends WorkspaceController {
  _MentionWorkspace(super.client);
  @override
  Future<Map<String, Map<String, dynamic>>> executeMentionActionResults(
    String action,
    List<String> resolutionIds,
  ) async => {
    for (final id in resolutionIds)
      id: {
        'resolutionId': id,
        'status': 'stale',
        'reason': 'target_already_member',
      },
  };
}

class _ManyMessages extends MessageSelection {
  _ManyMessages(super.w) : super(thread: false);
  @override
  List<SelectedMessageRow> get available => [
    for (var i = 0; i < 40; i++)
      SelectedMessageRow(
        RaftMessage({'id': 'm$i', 'channelId': 'c', 'seq': i, 'content': '$i'}),
      ),
  ];
}

class _FailingForward extends WorkspaceController {
  _FailingForward(super.client);
  @override
  Future<dynamic> command(String method, String path, {dynamic data}) =>
      Future<dynamic>.error(StateError('offline'));
}

class _ShareClient extends RaftClient {
  _ShareClient()
    : super(origin: 'https://example.test', sessionStore: MemorySessionStore());
  final bus = StreamController<RaftEvent>.broadcast();
  List<Map<String, dynamic>> serverRows = [];
  bool serversDown = false, channelsDown = false;
  Set<String> hidden = {};
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  Future<List<RaftRecord>> servers() async {
    if (serversDown) throw StateError('offline');
    return [for (final s in serverRows) RaftRecord(s)];
  }

  @override
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (channelsDown) throw StateError('offline');
    if (path == '/channels') {
      return [
        for (final (id, name, joined) in [
          ('c1', 'general', true),
          ('c2', 'lobby', true),
        ])
          if (!hidden.contains(id))
            {'id': id, 'name': name, 'type': 'channel', 'joined': joined},
      ];
    }
    return [];
  }

  @override
  Future<void> dispose() async {
    await bus.close();
    await super.dispose();
  }
}

typedef _Route = FutureOr<Object?> Function(
  Map<String, dynamic>? query,
  dynamic data,
);

class _PublicClient extends RaftClient {
  _PublicClient(this.routes, {Map<String, dynamic>? user})
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    if (user != null) this.user = RaftRecord(user);
  }
  final Map<String, _Route> routes;
  @override
  void connect() {}
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    final route = routes['$method $path'];
    if (route == null) throw RaftApiException('Not found', status: 404);
    return route(query, data);
  }
}
