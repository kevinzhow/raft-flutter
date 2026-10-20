import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_ui/raft_ui.dart';

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
  final calls = <String>[];
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
    calls.add('$method $path');
    final route = routes['$method $path'];
    if (route == null) throw RaftApiException('Not found', status: 404);
    return route(query, data);
  }
}

Map<String, dynamic> _message(
  String id,
  String who,
  String content, {
  String? thread,
  int replies = 0,
  String type = 'user',
}) => {
  'id': id,
  'senderType': type,
  'sender': {'displayName': who, 'avatarUrl': null, 'description': null},
  'messageType': 'chat',
  'content': content,
  'createdAt': '2026-06-18T09:12:00.000Z',
  'threadId': thread,
  'replyCount': replies,
};

const _server = {
  'id': 's',
  'name': 'Raft Design',
  'slug': 'raft-design',
  'avatarUrl': null,
};
const _base = '/public/servers/raft-design';

Map<String, _Route> _routes({
  bool joinable = true,
  List<Map<String, dynamic>>? channels,
}) => {
  'GET $_base': (_, _) => {
    'server': _server,
    'channels':
        channels ??
        [
          {'id': 'c1', 'name': 'general', 'description': 'Announcements'},
          {'id': 'c2', 'name': 'help', 'description': null},
        ],
    'canJoinAsGuest': joinable,
  },
  'GET $_base/channels/c1/messages': (_, _) => {
    'messages': [
      _message('m1', 'Wenyi', 'Welcome to the community'),
      _message(
        'm2',
        'Artin',
        'Feedback on the rail?',
        thread: 't1',
        replies: 2,
      ),
    ],
  },
  'GET $_base/channels/c2/messages': (_, _) => {
    'messages': [_message('m9', 'Jun', 'Ask anything here')],
  },
  'GET $_base/threads/t1/messages': (_, _) => {
    'messages': [_message('r1', 'Jun', 'Looks good to me')],
  },
  'POST $_base/join-as-guest': (_, _) => {'ok': true},
};

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: child),
);

Future<void> _mount(
  WidgetTester t,
  _PublicClient client, {
  VoidCallback? onSignIn,
  VoidCallback? onRegister,
  VoidCallback? onUnavailable,
  PublicServerAccount? account,
  Future<void> Function()? onJoined,
  String? channel,
  Size size = const Size(1280, 800),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    _host(
      PublicServerView(
        client: client,
        slug: 'raft-design',
        initialChannelId: channel,
        account: account,
        onJoined: onJoined,
        onSignIn: onSignIn ?? () {},
        onRegister: onRegister ?? () {},
        onUnavailable: onUnavailable ?? () {},
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  _loadOlderTests();
  testWidgets(
    'signed out: channels, the first channel messages and the join banner',
    (t) async {
      final client = _PublicClient(_routes());
      var signIn = 0, register = 0;
      await _mount(
        t,
        client,
        onSignIn: () => signIn++,
        onRegister: () => register++,
      );
      expect(find.text('Public channels'.toUpperCase()), findsOneWidget);
      expect(find.text('general'), findsWidgets);
      expect(find.text('Welcome to the community'), findsOneWidget);
      expect(
        find.text('Sign in to join Raft Design and be part of the discussion.'),
        findsOneWidget,
      );
      expect(
        client.calls,
        containsAll(['GET $_base', 'GET $_base/channels/c1/messages']),
      );
      await t.tap(find.text('Sign in'));
      await t.tap(find.text('Create account'));
      expect(signIn, 1);
      expect(register, 1);
    },
  );

  testWidgets('a view-only server swaps the primary action', (t) async {
    await _mount(t, _PublicClient(_routes(joinable: false)));
    expect(
      find.text(
        'Raft Design is view only. Create a Raft account to build a server of your own.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'selecting a channel loads its messages and a linked channel opens first',
    (t) async {
      final client = _PublicClient(_routes());
      await _mount(t, client, channel: 'c2');
      expect(find.text('Ask anything here'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('public-channel-c1')));
      await t.pumpAndSettle();
      expect(find.text('Welcome to the community'), findsOneWidget);
      expect(find.text('Ask anything here'), findsNothing);
    },
  );

  testWidgets('a #channel mention chips and opens that public channel', (
    t,
  ) async {
    final routes = _routes();
    routes['GET $_base/channels/c1/messages'] = (_, _) => {
      'messages': [_message('m1', 'Wenyi', '#help')],
    };
    await _mount(t, _PublicClient(routes));
    final chip = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('#help'),
    );
    expect(chip, findsWidgets);
    // The chip is the first word of the paragraph; its centre is blank.
    await t.tapAt(t.getTopLeft(chip.first) + const Offset(12, 10));
    await t.pumpAndSettle();
    expect(find.text('Ask anything here'), findsOneWidget);
  });

  testWidgets(
    'an unknown linked channel falls back to the first public channel',
    (t) async {
      await _mount(t, _PublicClient(_routes()), channel: 'private-1');
      expect(find.text('Welcome to the community'), findsOneWidget);
    },
  );

  testWidgets('a 404 readback reports the server as unavailable', (t) async {
    var unavailable = 0;
    final client = _PublicClient({
      'GET $_base': (_, _) => throw RaftApiException('Not found', status: 404),
    });
    await _mount(t, client, onUnavailable: () => unavailable++);
    expect(unavailable, 1);
  });

  testWidgets(
    'a failed message load shows the error and keeps the channel list',
    (t) async {
      final routes = _routes();
      routes['GET $_base/channels/c1/messages'] = (_, _) =>
          throw RaftApiException('Failed to load public messages', status: 500);
      await _mount(t, _PublicClient(routes));
      expect(find.text('Failed to load public messages'), findsOneWidget);
      expect(find.byKey(const ValueKey('public-channel-c2')), findsOneWidget);
    },
  );

  testWidgets('a channel that stopped being public explains it', (t) async {
    final routes = _routes();
    routes['GET $_base/channels/c1/messages'] = (_, _) =>
        throw RaftApiException('Gone', status: 404);
    await _mount(t, _PublicClient(routes));
    expect(
      find.text('This server or channel is no longer public.'),
      findsOneWidget,
    );
  });

  testWidgets('a server without public channels shows the empty state', (
    t,
  ) async {
    await _mount(t, _PublicClient(_routes(channels: [])));
    expect(
      find.text('This server has no public channels right now.'),
      findsOneWidget,
    );
  });

  testWidgets('a thread opens read only beside the channel and closes', (
    t,
  ) async {
    final client = _PublicClient(_routes());
    await _mount(t, client);
    await t.tap(find.byKey(const ValueKey('public-thread-open-m2')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('public-server-thread-panel')),
      findsOneWidget,
    );
    expect(find.text('Looks good to me'), findsOneWidget);
    // Web ThreadPanel: "Thread" then the channel context, with a gap between.
    expect(
      find.textContaining('Thread — #', findRichText: true),
      findsOneWidget,
    );
    expect(client.calls, contains('GET $_base/threads/t1/messages'));
    await t.tap(find.byKey(const ValueKey('thread-close')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('public-server-thread-panel')),
      findsNothing,
    );
  });

  testWidgets('the rail logo explains that signing in is needed', (t) async {
    await _mount(t, _PublicClient(_routes()));
    await t.tap(find.byKey(const Key('rail-workspace')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('public-server-selection-notice')),
      findsOneWidget,
    );
  });

  testWidgets('settings shows About with the version', (t) async {
    await _mount(t, _PublicClient(_routes()));
    await t.tap(find.byKey(const ValueKey('public-rail-settings')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('public-server-settings-surface')),
      findsOneWidget,
    );
    expect(find.text('Documentation'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('rail-chat')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('public-server-settings-surface')),
      findsNothing,
    );
  });

  group('signed in nonmember', () {
    PublicServerAccount account() =>
        PublicServerAccount(servers: const [], onSelect: (_) {});
    final user = {'id': 'u1'};

    testWidgets('Join as Guest asks for confirmation, joins and hands over', (
      t,
    ) async {
      final client = _PublicClient(_routes(), user: user);
      var joined = 0;
      await _mount(
        t,
        client,
        account: account(),
        onJoined: () async => joined++,
      );
      expect(find.text('Sign in'), findsNothing);
      await t.tap(find.byKey(const ValueKey('public-join-guest')));
      await t.pumpAndSettle();
      expect(find.text('JOIN THIS SERVER?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('public-join-confirm')));
      await t.pumpAndSettle();
      expect(client.calls, contains('POST $_base/join-as-guest'));
      expect(joined, 1);
      expect(find.text('JOIN THIS SERVER?'), findsNothing);
    });

    testWidgets('cancelling the confirm joins nothing', (t) async {
      final client = _PublicClient(_routes(), user: user);
      await _mount(t, client, account: account());
      await t.tap(find.byKey(const ValueKey('public-join-guest')));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(client.calls, isNot(contains('POST $_base/join-as-guest')));
    });

    testWidgets('a failed join keeps the dialog open with the error', (
      t,
    ) async {
      final routes = _routes();
      routes['POST $_base/join-as-guest'] = (_, _) => throw RaftApiException(
        'Failed to join this public server',
        status: 500,
      );
      await _mount(t, _PublicClient(routes, user: user), account: account());
      await t.tap(find.byKey(const ValueKey('public-join-guest')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('public-join-confirm')));
      await t.pumpAndSettle();
      expect(find.text('Failed to join this public server'), findsWidgets);
      expect(find.text('JOIN THIS SERVER?'), findsOneWidget);
    });

    testWidgets(
      'a refresh failure after joining never reads as a failed join',
      (t) async {
        await _mount(
          t,
          _PublicClient(_routes(), user: user),
          account: account(),
          onJoined: () async => throw StateError('server list unavailable'),
        );
        await t.tap(find.byKey(const ValueKey('public-join-guest')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('public-join-confirm')));
        await t.pumpAndSettle();
        expect(
          find.text('You joined this server. Refresh the page to open it.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a required agreement is shown and agreeing joins with its id',
      (t) async {
        final routes = _routes();
        Object? sent;
        var first = true;
        routes['POST $_base/join-as-guest'] = (_, data) {
          sent = data;
          if (first) {
            first = false;
            throw RaftApiException.response(
              'agreement_required',
              status: 409,
              body: {
                'error': 'agreement_required',
                'agreement': {
                  'id': 'ag1',
                  'title': 'Community agreement',
                  'version': 3,
                  'bodyMarkdown': '1. Be kind',
                },
              },
            );
          }
          return {'ok': true};
        };
        var joined = 0;
        await _mount(
          t,
          _PublicClient(routes, user: user),
          account: account(),
          onJoined: () async => joined++,
        );
        await t.tap(find.byKey(const ValueKey('public-join-guest')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('public-join-confirm')));
        await t.pumpAndSettle();
        expect(find.text('Community agreement'), findsOneWidget);
        expect(find.text('Version 3'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('community-agreement-agree')));
        await t.pumpAndSettle();
        expect(sent, {'agreementId': 'ag1'});
        expect(joined, 1);
        expect(find.text('Community agreement'), findsNothing);
      },
    );
  });
}

void _loadOlderTests() {
  List<Map<String, dynamic>> page(int first, int count) => [
    for (var i = first; i < first + count; i++)
      _message('m$i', 'Wenyi', 'Row $i'),
  ];

  // Web v1.21.12 has no "Load older messages" button: MessageTimeline's top
  // sentinel loads the older page when the history is scrolled to its start.
  final queries = <Map<String, dynamic>?>[];
  int olderRequests() =>
      queries.where((q) => q?['beforeMessageId'] != null).length;

  Future<void> mountWith(
    WidgetTester t,
    List<Map<String, dynamic>> latest,
    List<Map<String, dynamic>> older, {
    double height = 800,
  }) async {
    queries.clear();
    final routes = _routes()
      ..['GET $_base/channels/c1/messages'] = (query, _) {
        queries.add(query);
        return {'messages': query?['beforeMessageId'] == null ? latest : older};
      };
    final client = _PublicClient(routes);
    addTearDown(client.dispose);
    await _mount(t, client, size: Size(1280, height));
  }

  ScrollPosition timeline(WidgetTester t) => t
      .state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('public-server-message-timeline')),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  testWidgets('the view opens on the latest rows and asks for nothing older', (
    t,
  ) async {
    await mountWith(t, page(100, 50), page(50, 20));
    expect(
      timeline(t).pixels,
      0,
      reason: 'a reversed view rests on the latest',
    );
    expect(timeline(t).extentAfter, greaterThan(200));
    expect(olderRequests(), 0);
    expect(find.text('Load older messages'), findsNothing);
    expect(find.text('Row 50', skipOffstage: false), findsNothing);
  });

  testWidgets('reaching the top loads the older page above, once', (t) async {
    await mountWith(t, page(100, 50), page(50, 20));
    final before = timeline(t);
    before.jumpTo(before.maxScrollExtent);
    await t.pumpAndSettle();
    expect(olderRequests(), 1);
    expect(find.text('Row 50', skipOffstage: false), findsOneWidget);
    // The 20 rows came back short of a page: nothing more is asked.
    timeline(t).jumpTo(timeline(t).maxScrollExtent);
    await t.pumpAndSettle();
    expect(olderRequests(), 1);
  });

  testWidgets('an older page that comes back empty ends the loading', (
    t,
  ) async {
    await mountWith(t, page(100, 50), const []);
    timeline(t).jumpTo(timeline(t).maxScrollExtent);
    await t.pumpAndSettle();
    timeline(t).jumpTo(timeline(t).maxScrollExtent);
    await t.pumpAndSettle();
    expect(olderRequests(), 1);
    expect(find.text('Row 100', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a first page that does not fill the panel keeps loading', (
    t,
  ) async {
    await mountWith(t, page(100, 50), page(50, 20), height: 20000);
    await t.pumpAndSettle();
    expect(olderRequests(), 1, reason: 'no scrolling needed to reach the top');
    expect(find.text('Row 50', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a short history sits at the bottom and never asks for more', (
    t,
  ) async {
    await mountWith(t, page(100, 12), const [], height: 20000);
    await t.pumpAndSettle();
    expect(olderRequests(), 0);
    final last = t.getRect(find.text('Row 111'));
    final panel = t.getRect(
      find.byKey(const ValueKey('public-server-message-timeline')),
    );
    expect(
      panel.bottom - last.bottom,
      lessThan(60),
      reason: 'sparseAnchor=bottom',
    );
  });
}
