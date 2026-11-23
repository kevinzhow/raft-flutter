import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An external agent the signed-in person (`alice`) created.
const externalAgentRow = <String, dynamic>{
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
  'creator': {
    'id': 'alice',
    'type': 'human',
    'name': 'alice',
    'displayName': 'Alice',
  },
};

/// A server that answers the external agent's setup routes and records every
/// request that is not a read.
class ExternalClient extends RaftClient {
  ExternalClient({this.row = externalAgentRow})
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  Map<String, dynamic> row;
  final calls = <String>[];
  final bodies = <(String, dynamic)>[];
  List<Map<String, dynamic>> credentials = [
    {
      'id': 'cred-1234abcd',
      'name': null,
      'createdAt': '2026-06-18T09:00:00.000Z',
      'lastUsedAt': null,
      'revokedAt': null,
    },
    {
      'id': 'cred-old',
      'name': 'Old laptop',
      'createdAt': '2026-05-01T09:00:00.000Z',
      'lastUsedAt': null,
      'revokedAt': '2026-05-02T09:00:00.000Z',
    },
  ];
  Object? generated = {
    'agentId': 'ext-1',
    'credentialId': 'cred-new',
    'apiKey': 'sk_agent_0123456789abcdefghijklmnop',
  };
  bool failRevoke = false,
      failList = false,
      failStatus = false,
      failSkills = false,
      failMethod = false,
      failCreate = false,
      failAgentCreate = false,
      failDelete = false;
  Map<String, dynamic> status = {
    'setupState': 'credential_minted',
    'credentialLastUsedAt': null,
  };
  int statusReads = 0;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}

  int count(String call) => calls.where((c) => c == call).length;

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
    if (method != 'GET') bodies.add(('$method $path', data));
    if (path == '/agents' && method == 'POST') {
      if (failAgentCreate) {
        throw RaftApiException.response(
          'Name taken',
          status: 409,
          body: {'error': 'Name taken'},
        );
      }
      return {'id': 'ext-1', 'name': (data as Map)['name']};
    }
    if (path == '/agents/ext-1' && method == 'DELETE') {
      if (failDelete) throw const RaftApiException('boom', status: 500);
      return {};
    }
    if (path == '/agents') return [row];
    if (path == '/agents/ext-1') return row;
    if (path.endsWith('/skills')) {
      if (failSkills) {
        throw RaftApiException.response(
          'Agent has no connected machine',
          status: 409,
          body: {
            'error': 'Agent has no connected machine',
            'code': 'machine_offline',
          },
        );
      }
      return {'global': [], 'workspace': []};
    }
    if (path == '/agents/ext-1/external-status') {
      statusReads++;
      if (failStatus) {
        throw const RaftApiException('Status unavailable', status: 500);
      }
      return Map<String, dynamic>.from(status);
    }
    if (path == '/agents/ext-1/credentials' && method == 'GET') {
      if (failList) throw const RaftApiException('nope', status: 500);
      return {'agentId': 'ext-1', 'credentials': credentials};
    }
    if (path == '/agents/ext-1/credentials' && method == 'POST') {
      if (failCreate) throw const RaftApiException('boom', status: 500);
      final out = generated;
      if (out is Exception) throw out;
      final replaces = data is Map ? data['replacesCredentialId'] : null;
      credentials = [
        for (final c in credentials)
          c['id'] == replaces
              ? {...c, 'revokedAt': '2026-06-19T09:00:00.000Z'}
              : c,
        {
          'id': 'cred-new',
          'name': 'Created on this page',
          'createdAt': '2026-06-19T09:00:00.000Z',
          'lastUsedAt': null,
          'revokedAt': null,
        },
      ];
      return out;
    }
    if (method == 'DELETE' && path.startsWith('/agents/ext-1/credentials/')) {
      if (failRevoke) throw const RaftApiException('boom', status: 500);
      final id = path.split('/').last;
      credentials = [
        for (final c in credentials)
          c['id'] == id ? {...c, 'revokedAt': '2026-06-19T09:00:00.000Z'} : c,
      ];
      return {};
    }
    if (method == 'PUT' && path == '/agents/ext-1/external-setup-method') {
      if (failMethod) throw const RaftApiException('boom', status: 500);
      status = {...status, 'externalSetupMethod': (data as Map)['method']};
      return {};
    }
    return [];
  }
}

/// Mounts the agent's detail panel (the External setup block is part of it).
Future<(WorkspaceController, ExternalClient)> pumpExternal(
  WidgetTester tester, {
  ExternalClient? client,
  String role = 'owner',
  Map<String, dynamic> agent = externalAgentRow,
  Size size = const Size(900, 3200),
  TargetPlatform platform = TargetPlatform.linux,
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = (client ?? ExternalClient())..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': role});
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
  if (settle) await tester.pumpAndSettle();
  return (w, c);
}

/// What the clipboard was given, in order.
List<String> captureClipboard() {
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
  return copied;
}

Finder key(String value) => find.byKey(ValueKey(value));
