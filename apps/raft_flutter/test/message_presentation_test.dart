import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';
import 'package:raft_flutter/features/private_route_guard.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageAdapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    return ResponseBody.fromString(
      jsonEncode(
        route == null ? {'error': 'Unexpected endpoint'} : await route(o),
      ),
      route == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(WorkspaceController, MessageAdapter)> fixture(String role) async {
  final a = MessageAdapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': role});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  return (w, a);
}

RaftMessage card(
  String type, {
  String state = 'prepared',
  String source = 's1',
}) => RaftMessage({
  'id': 'm1',
  'channelId': 'c1',
  'content': 'Action',
  'actionMetadata': {
    'kind': 'action-card',
    'sourceServerId': source,
    'state': state,
    'confirmationVersion': 7,
    'action': {
      'type': type,
      'name': 'suggested',
      'initialHumans': ['u1'],
      'initialAgents': ['a1'],
    },
  },
});
Widget host(Widget child, {PrivateRouteGuard? guard}) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  navigatorObservers: [?guard],
  home: Scaffold(body: child),
);
void main() {
  test('ambiguous directory names and bare DM handles require an explicit identity type', () async {
    final (w, a) = await fixture('owner');
    a.routes['GET /agents'] = (_) => [
      {'id': 'agent-same', 'name': 'same'},
    ];
    a.routes['GET /servers/s1/members'] = (_) => [
      {'userId': 'user-same', 'name': 'same'},
    ];
    final directory = MessageReferenceDirectory(w);
    // Complete both fresh directory reads without using any native fixture.
    for (var i = 0; i < 20 && directory.references.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      directory.references.map((r) => r.text),
      unorderedEquals(['@same~agent', '@same~human']),
    );
    w.dms = [
      RaftChannel({
        'id': 'dm-agent',
        'type': 'dm',
        'peerType': 'agent',
        'peerId': 'agent-same',
        'peerName': 'same',
      }),
      RaftChannel({
        'id': 'dm-user',
        'type': 'dm',
        'peerType': 'user',
        'peerId': 'user-same',
        'peerName': 'same',
      }),
    ];
    final presentation = MessagePresentation(
      controller: w,
      message: RaftMessage({
        'id': 'm',
        'content': 'dm:@same dm:@same~agent dm:@same~human',
      }),
      onExternalLink: (_) {},
      directoryReferences: directory.references,
    );
    expect(
      presentation.references.map((r) => r.text),
      isNot(contains('dm:@same')),
    );
    expect(
      presentation.references
          .singleWhere((r) => r.text == 'dm:@same~agent')
          .href,
      'raft-ref://channel/dm-agent',
    );
    expect(
      presentation.references
          .singleWhere((r) => r.text == 'dm:@same~human')
          .href,
      'raft-ref://channel/dm-user',
    );
    directory.dispose();
    w.dispose();
  });

  testWidgets(
    'inline action submits exact state/version and shows canonical server result',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['POST /actions/m1/execute'] = (_) => {
        'messageId': 'm1',
        'metadata': {
          'kind': 'action-card',
          'sourceServerId': 's1',
          'state': 'executed',
          'confirmationVersion': 7,
          'executedByUserName': 'Alice',
          'action': {'type': 'integration:approve_agent_login'},
        },
      };
      await tester.pumpWidget(
        host(
          MessageActionCard(
            controller: w,
            message: card('integration:approve_agent_login'),
          ),
        ),
      );
      await tester.tap(find.text('Approve agent login').last);
      await tester.pumpAndSettle();
      final request = a.calls.singleWhere(
        (r) => r.path == '/actions/m1/execute',
      );
      expect(request.data, {
        'expectedState': 'prepared',
        'expectedConfirmationVersion': 7,
      });
      expect(find.text('Committed by Alice'), findsOneWidget);
      expect(find.text('Approve agent login'), findsOneWidget);
    },
  );
  testWidgets(
    'guest and cross-workspace cards retain disabled explanation, no mutation',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => fixture('guest')))!;
      addTearDown(w.dispose);
      await tester.pumpWidget(
        host(
          MessageActionCard(
            controller: w,
            message: card('integration:register_app'),
          ),
        ),
      );
      expect(find.text('Guests cannot confirm actions.'), findsOneWidget);
      expect(
        tester.widget<RaftButton>(find.byType(RaftButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(
        host(
          MessageActionCard(
            controller: w,
            message: card('integration:register_app', source: 'other'),
          ),
        ),
      );
      expect(
        find.text('Switch to the target workspace to use this action.'),
        findsOneWidget,
      );
      expect(a.calls.where((r) => r.path.startsWith('/actions/')), isEmpty);
    },
  );
  testWidgets(
    'channel draft is editable and only effective member IDs mark execution',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['POST /actions/m1/event'] = (_) => {};
      a.routes['GET /servers/s1/members'] = (_) => {
        'members': [
          {'userId': 'u1', 'name': 'Human'},
        ],
      };
      a.routes['GET /agents'] = (_) => {
        'agents': [
          {'id': 'a1', 'name': 'Agent'},
        ],
      };
      a.routes['POST /channels'] = (_) => {'id': 'created', 'name': 'edited'};
      a.routes['POST /actions/m1/mark-executed'] = (_) => {
        'messageId': 'm1',
        'metadata': {
          'kind': 'action-card',
          'sourceServerId': 's1',
          'state': 'executed',
          'action': {'type': 'channel:create'},
        },
      };
      a.routes['GET /channels'] = (_) => {
        'channels': [
          {'id': 'c1', 'joined': true},
        ],
      };
      a.routes['GET /channels/dm'] = (_) => {'channels': []};
      await tester.pumpWidget(
        host(MessageActionCard(controller: w, message: card('channel:create'))),
      );
      await tester.tap(find.text('Create channel').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('field-name')),
        'edited',
      );
      await tester.tap(find.byKey(const ValueKey('action-member-agent-a1')));
      await tester.pump();
      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      final create = a.calls.singleWhere(
        (r) => r.method == 'POST' && r.path == '/channels',
      );
      expect(create.data['name'], 'edited');
      expect(create.data['userIds'], ['u1']);
      expect(create.data['agentIds'], isEmpty);
      expect(create.data['actionCardMessageId'], 'm1');
      expect(create.data['actionCardConfirmationVersion'], 7);
      final mark = a.calls.singleWhere(
        (r) => r.path == '/actions/m1/mark-executed',
      );
      expect(mark.data['result'], {
        'kind': 'channel',
        'id': 'created',
        'name': 'edited',
      });
      expect(
        a.calls.where(
          (r) =>
              r.data is Map &&
              (r.data as Map)['eventType'] == 'action_card.execute_success',
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'authority revocation removes a busy private overlay despite PopScope',
    (tester) async {
      final guard = PrivateRouteGuard();
      guard.scopeChanged('owner');
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const PopScope(
                  canPop: false,
                  child: AlertDialog(content: Text('Private editor')),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
          guard: guard,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Private editor'), findsOneWidget);
      guard.scopeChanged('owner');
      await tester.pump();
      expect(find.text('Private editor'), findsOneWidget);
      guard.scopeChanged('guest');
      await tester.pumpAndSettle();
      expect(find.text('Private editor'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    },
  );
  testWidgets(
    'same-frame authority removal and delayed form completion preserve Home',
    (tester) async {
      final guard = PrivateRouteGuard();
      guard.scopeChanged('owner');
      final pending = Completer<void>(), formKey = GlobalKey();
      bool? mountedAtRemoval;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => RaftFormDialog(
                  key: formKey,
                  title: 'Private editor',
                  fields: const [],
                  onSubmit: (_) async => pending.future,
                ),
              ),
              child: const Text('Home'),
            ),
          ),
          guard: guard,
        ),
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      guard.scopeChanged('guest');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mountedAtRemoval = formKey.currentState?.mounted;
        pending.complete();
      });
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        mountedAtRemoval,
        isTrue,
        reason: 'the old route state is still mounted when the same-frame submission completes',
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Private editor'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a completed older form cannot pop a newer route in the same authority',
    (tester) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (formContext) => RaftFormDialog(
                  title: 'Older form',
                  fields: const [],
                  onSubmit: (_) async {
                    unawaited(
                      showDialog(
                        context: formContext,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Newer route'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close newer'),
                            ),
                          ],
                        ),
                      ),
                    );
                    await pending.future;
                  },
                ),
              ),
              child: const Text('Home'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Newer route'), findsOneWidget);
      pending.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Newer route'), findsOneWidget);
      await tester.tap(find.text('Close newer'));
      await tester.pumpAndSettle();
      expect(find.text('Older form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'workspace overlays survive loaded grants and archive, close only on capability loss',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.section = 'settings';
      final guard = PrivateRouteGuard();
      await tester.pumpWidget(
        host(
          Column(
            children: [
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) =>
                        const AlertDialog(title: Text('Channel controls')),
                  ),
                  child: const Text('Open controls'),
                ),
              ),
              Expanded(
                child: WorkspaceView(
                  controller: w,
                  appearance: const RaftAppearance(),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                ),
              ),
            ],
          ),
          guard: guard,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open controls'));
      await tester.pumpAndSettle();
      void update(Map<String, dynamic> values) {
        w.channel = RaftChannel({...w.channel!.json, ...values});
        w.channels = [w.channel!];
        w.setError(null);
      }

      update({
        'channelCapabilities': {
          'editChannelMetadata': true,
          'archiveChannels': false,
        },
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Channel controls'),
        findsOneWidget,
        reason: 'initial loading supplies permissions, not a revocation',
      );
      update({
        'channelCapabilities': {
          'editChannelMetadata': true,
          'archiveChannels': true,
        },
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Channel controls'),
        findsOneWidget,
        reason: 'newly granted capability retains current form',
      );
      update({'archivedAt': '2026-10-07T00:00:00Z'});
      await tester.pumpAndSettle();
      expect(
        find.text('Channel controls'),
        findsOneWidget,
        reason: 'archive preserves channel history and metadata visibility',
      );
      update({'archivedAt': null});
      await tester.pumpAndSettle();
      expect(find.text('Channel controls'), findsOneWidget);
      update({
        'channelCapabilities': {
          'editChannelMetadata': false,
          'archiveChannels': true,
        },
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Channel controls'),
        findsNothing,
        reason: 'explicit permission removal closes private controls',
      );
      expect(find.text('Open controls'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
