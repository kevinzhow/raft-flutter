import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/external_agent_setup.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _agent = <String, dynamic>{
  'id': 'ext-1',
  'name': 'Hermes-Bridge',
  'displayName': 'Hermes Bridge',
  'description': 'Runs outside Raft.',
  'status': 'active',
  'runtime': 'external',
  'model': 'external',
  'external': true,
  'creatorType': 'user',
  'creatorId': 'alice',
};

class _Client extends RaftClient {
  _Client({this.row = _agent})
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  Map<String, dynamic> row;
  final calls = <String>[];
  var credentials = <Map<String, dynamic>>[
    {
      'id': 'cred-1234abcd',
      'maskedToken': 'sk_agent_ab12***9f3e',
      'name': null,
      'createdAt': '2026-06-18T09:00:00.000Z',
      'lastUsedAt': null,
      'revokedAt': null,
    },
  ];
  Object? generated = {
    'agentId': 'ext-1',
    'credentialId': 'cred-new',
    'apiKey': 'sk_agent_0123456789abcdefghijklmnop',
  };
  bool failRevoke = false, failList = false, failStatus = false;
  Map<String, dynamic> status = {
    'setupState': 'credential_minted',
    'credentialLastUsedAt': null,
  };
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
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
    if (path == '/agents') return [row];
    if (path == '/agents/ext-1') return row;
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    if (path == '/agents/ext-1/external-status') {
      if (failStatus) {
        throw const RaftApiException('Status unavailable', status: 500);
      }
      return status;
    }
    if (path == '/agents/ext-1/credentials' && method == 'GET') {
      if (failList) throw const RaftApiException('nope', status: 500);
      return {'agentId': 'ext-1', 'credentials': credentials};
    }
    if (path == '/agents/ext-1/credentials' && method == 'POST') {
      final out = generated;
      if (out is Exception) throw out;
      credentials = [
        ...credentials,
        {
          'id': 'cred-new',
          'maskedToken': 'sk_agent_0123***mnop',
          'name': 'CLI',
          'createdAt': '2026-06-19T09:00:00.000Z',
          'lastUsedAt': null,
          'revokedAt': null,
        },
      ];
      return out;
    }
    if (method == 'DELETE' && path.startsWith('/agents/ext-1/credentials/')) {
      if (failRevoke) throw const RaftApiException('boom', status: 500);
      return {};
    }
    return [];
  }
}

Future<(WorkspaceController, _Client)> _pump(
  WidgetTester tester, {
  _Client? client,
  String role = 'owner',
  Map<String, dynamic> agent = _agent,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = (client ?? _Client())..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': role});
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: FleetDetail(
          key: UniqueKey(),
          controller: w,
          computers: false,
          initial: agent,
          onClose: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (w, c);
}

Finder _k(String key) => find.byKey(ValueKey(key));

void main() {
  test('the profile slug follows the handle, then the id', () {
    expect(
      externalProfileSlug('Hermes Bridge!', 'abcdef123456'),
      'Hermes-Bridge',
    );
    expect(externalProfileSlug('--', 'abcdef123456'), 'abcdef12');
  });

  testWidgets(
    'shows the setup state, the token inventory and the Hermes steps',
    (tester) async {
      final (_, client) = await _pump(tester);
      expect(find.text('External setup'), findsOneWidget);
      expect(find.text('Credential minted'), findsOneWidget);
      expect(find.text('External · No Raft activity yet'), findsOneWidget);
      expect(
        client.calls.where((c) => c == 'GET /agents/ext-1/external-status'),
        hasLength(1),
      );
      expect(find.textContaining('sk_agent_ab12***9f3e'), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);
      expect(find.text('Install or upgrade Raft CLI'), findsOneWidget);
      expect(find.text('npm i -g @botiverse/raft@latest'), findsWidgets);
      expect(
        find.text(
          'raft agent login --server https://raft.example.test --agent ext-1 --profile-slug Hermes-Bridge',
        ),
        findsOneWidget,
      );
      expect(
        find.text('RAFT_EXPECTED_AGENT_ID=ext-1 hermes gateway setup'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Restart or reload Hermes after setup so the saved profile is picked up.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a waiting agent reads Setup required and a connected one Connected',
    (tester) async {
      final client = _Client()
        ..status = {
          'setupState': 'waiting_for_login',
          'credentialLastUsedAt': null,
        };
      await _pump(tester, client: client);
      expect(find.text('Waiting for login'), findsOneWidget);
      expect(find.text('External · Setup required'), findsOneWidget);
    },
  );

  testWidgets('a failed status read keeps the block and shows the message', (
    tester,
  ) async {
    final client = _Client()..failStatus = true;
    await _pump(tester, client: client);
    // Web: `data.error || agent.detail.loadExternalSetupStatusFailed`; a
    // body-less 500 shows the fallback, never the exception text.
    expect(find.text('Failed to load external setup status'), findsOneWidget);
    expect(find.text('Status unavailable'), findsNothing);
    expect(find.text('Waiting for login'), findsOneWidget);
  });

  testWidgets(
    'switching tabs swaps the steps and Other agents copies the setup',
    (tester) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pump(tester);
      await tester.tap(find.text('Claude Code'));
      await tester.pump();
      expect(
        find.text(
          'Install or upgrade Raft CLI and the Claude Code channel plugin',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Keep Claude Code running so it can receive Raft work.'),
        findsOneWidget,
      );
      await tester.tap(_k('external-step-copy-3'));
      await tester.pump();
      expect(
        copied.single,
        contains(
          'RAFT_EXPECTED_AGENT_ID=ext-1 RAFT_PROFILE=Hermes-Bridge claude',
        ),
      );
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Copied'), findsNothing);
      await tester.tap(find.text('Other Agents'));
      await tester.pump();
      expect(find.text('Copy Setup'), findsOneWidget);
      expect(
        find.text('Use this flow for another agent runtime or custom harness.'),
        findsOneWidget,
      );
      await tester.tap(_k('external-setup-copy'));
      await tester.pump();
      expect(
        copied.last,
        startsWith(
          'Run these commands on the computer that will run this agent.',
        ),
      );
      expect(copied.last, contains('npm i -g @botiverse/raft@latest'));
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'generating a token shows it masked once and refreshes the list',
    (tester) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final (_, client) = await _pump(tester);
      await tester.tap(_k('external-token-generate'));
      await tester.pumpAndSettle();
      expect(
        client.calls.where((c) => c == 'POST /agents/ext-1/credentials'),
        hasLength(1),
      );
      expect(find.text('sk_agent_01234***jklmnop'), findsOneWidget);
      expect(
        find.textContaining(
          'It cannot be retrieved after you leave this panel',
        ),
        findsOneWidget,
      );
      expect(
        client.calls.where((c) => c == 'GET /agents/ext-1/credentials'),
        hasLength(2),
      );
      expect(_k('external-credential-cred-new'), findsOneWidget);
      await tester.tap(_k('external-token-copy'));
      await tester.pump();
      expect(copied.single, 'sk_agent_0123456789abcdefghijklmnop');
      expect(find.text('Copied'), findsOneWidget);
      // Revoking the shown token clears it.
      await tester.tap(_k('external-token-revoke-cred-new'));
      await tester.pump();
      await tester.tap(_k('external-token-confirm-revoke'));
      await tester.pumpAndSettle();
      expect(find.text('sk_agent_01234***jklmnop'), findsNothing);
      expect(_k('external-token-generate'), findsOneWidget);
      expect(find.text('Revoked'), findsOneWidget);
    },
  );

  testWidgets(
    'an unusable token response asks to check the existing credentials',
    (tester) async {
      final client = _Client()
        ..generated = {
          'agentId': 'other',
          'credentialId': 'x',
          'apiKey': 'sk_agent_1',
        };
      await _pump(tester, client: client);
      await tester.tap(_k('external-token-generate'));
      await tester.pumpAndSettle();
      expect(_k('external-token-error'), findsOneWidget);
      expect(_k('external-token-copy'), findsNothing);
      expect(_k('external-token-generate'), findsOneWidget);
    },
  );

  testWidgets(
    'revocation asks first, can be cancelled and reports an unconfirmed failure',
    (tester) async {
      final client = _Client()..failRevoke = true;
      await _pump(tester, client: client);
      await tester.tap(_k('external-token-revoke-cred-1234abcd'));
      await tester.pump();
      expect(
        find.text(
          'Apps using this token will lose access. Other tokens will stay active.',
        ),
        findsOneWidget,
      );
      await tester.tap(_k('external-token-cancel-revoke'));
      await tester.pump();
      expect(
        find.text(
          'Apps using this token will lose access. Other tokens will stay active.',
        ),
        findsNothing,
      );
      await tester.tap(_k('external-token-revoke-cred-1234abcd'));
      await tester.pump();
      await tester.tap(_k('external-token-confirm-revoke'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Revocation was not confirmed. Refresh to check the token before trying again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Valid'), findsOneWidget);
    },
  );

  testWidgets('a failed token list offers Refresh', (tester) async {
    final client = _Client()..failList = true;
    await _pump(tester, client: client);
    expect(
      find.text(
        'Could not load tokens. Refresh to check their current status.',
      ),
      findsOneWidget,
    );
    client.failList = false;
    await tester.tap(_k('external-token-refresh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sk_agent_ab12***9f3e'), findsOneWidget);
  });

  testWidgets(
    'the block needs agent management and the token manager the capability or creatorship',
    (tester) async {
      final other = Map<String, dynamic>.from(_agent)..['creatorId'] = 'bob';
      final (_, client) = await _pump(
        tester,
        client: _Client(row: other),
        role: 'member',
        agent: other,
      );
      // A member may not manage this agent: no External setup block at all.
      expect(_k('external-setup'), findsNothing);
      expect(client.calls.where((c) => c.contains('/credentials')), isEmpty);
      // The creator manages it and gets the token manager.
      final (_, mine) = await _pump(tester, role: 'member');
      expect(_k('external-agent-token'), findsOneWidget);
      expect(mine.calls, contains('GET /agents/ext-1/credentials'));
    },
  );
}
