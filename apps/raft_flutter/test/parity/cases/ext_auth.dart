// raft-flutter parity EXTENSION suite builders (tool/parity-ext): auth &
// onboarding surfaces. NOT official cases; ids
// `components.auth-ext.<platform>.<surface>.<theme>` mirror
// tool/parity-ext/build-auth-cases.py and host/AuthCases.tsx (dispatch on
// props.view).
//
// Data: tool/parity-ext/fixtures/auth-ext.json (fixtures['ext:auth-ext']);
// `routes` + `routeSets[props.routeSet]` answer the API for both providers
// (`$pending` never answers, `$status` fails with that status).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/account_onboarding.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/server_setup_gate.dart';

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

const _origin = 'http://localhost:13041';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:auth-ext'] as Map<String, dynamic>;

/// The fixture answer of `METHOD path` for this case, throwing the error a
/// `$status` rule stands for.
Object? _answer(ParityContext ctx, String method, String path) {
  final fx = _fx(ctx);
  final merged = {
    ...Map<String, dynamic>.from(fx['routes'] as Map),
    ...Map<String, dynamic>.from(
      ((fx['routeSets'] as Map?)?[ctx.props['routeSet']] as Map?) ?? const {},
    ),
  };
  final value = merged['$method $path'];
  if (value is Map && value[r'$pending'] == true) {
    return ScreenFixtureClient.pending;
  }
  if (value is Map && value[r'$status'] != null) {
    final body = Map<String, dynamic>.from(value[r'$body'] as Map? ?? const {});
    throw RaftApiException.response(
      '${body['error'] ?? 'fixture error'}',
      status: value[r'$status'] as int,
      body: body,
    );
  }
  return value ?? <String, dynamic>{};
}

ScreenFixtureClient _anonymous(ParityContext ctx, String origin) =>
    ScreenFixtureClient(
      (method, path, query) => _answer(ctx, method, path),
      origin: origin,
    );

Widget _auth(ParityContext ctx, String mode) => AuthView(
  origin: _origin,
  initialMode: mode,
  resetToken: mode == 'reset' ? 'parity-reset-token' : null,
  onLogin: (_, _, _) async {
    final answer = _answer(ctx, 'POST', '/auth/login');
    if (identical(answer, ScreenFixtureClient.pending)) {
      await Completer<void>().future;
    }
  },
  onRegister: (_, _, _, _) async {},
  onOAuth: (_, _, _, _) async {},
  anonymousClientFactory: (origin) => _anonymous(ctx, origin),
);

Widget _verify(ParityContext ctx) {
  final fx = _fx(ctx);
  return ScreenClientHost(
    create: () => ScreenFixtureClient(
      (method, path, query) => _answer(ctx, method, path),
      user: Map<String, dynamic>.from(fx['user'] as Map),
    ),
    builder: (context, client) => AccountOnboardingView(
      client: client,
      onComplete: () async {},
      onSignOut: () async {},
    ),
  );
}

/// ServerSetupGate over a fixture client whose `setup-projection` says setup
/// is complete with the survey or the handoff still owed (the gate then draws
/// the step, as the Web StepContainer does).
Widget _setupGate(ParityContext ctx, {required bool survey}) {
  final wire = ScreenWire(ctx.fixtureData);
  final serverId = wire.server()['id'] as String;
  final client = ScreenFixtureClient(
    (method, path, query) {
      if (path == '/servers/$serverId/setup-projection') {
        return {
          'phase': 'complete',
          'surface': 'complete',
          'currentStep': null,
          'blocksChat': false,
          'allowedExits': <String>[],
          'sideEffectState': {
            'transitions': 'enabled',
            'completion': 'enabled',
          },
          'gateReason': 'setup_complete',
          'postSetup': {'surveyPending': survey, 'handoffPending': !survey},
        };
      }
      if (path.endsWith('/setup-handoff')) {
        return _answer(ctx, method, '/servers/visual-server/setup-handoff');
      }
      if (method == 'PATCH' && path == '/auth/me') {
        return _answer(ctx, method, path);
      }
      return wire.common(method, path, query);
    },
    user: wire.me(),
    server: serverId,
  );
  final w = WorkspaceController(client);
  final server = RaftRecord(wire.server());
  w
    ..servers = [server]
    ..server = server;
  return ServerSetupGate(
    controller: w,
    onSwitchServer: () {},
    child: const SizedBox.shrink(),
  );
}

Widget _serverSelector(ParityContext ctx) {
  final fx = _fx(ctx);
  final servers = (fx['servers'] as Map)[ctx.props['servers']] as List;
  return GlobalServerSelector(
    servers: [
      for (final server in servers)
        RaftRecord(Map<String, dynamic>.from(server as Map)),
    ],
    user: RaftRecord(Map<String, dynamic>.from(fx['user'] as Map)),
    loading: false,
    onSelect: (_) async {},
    onCreate: (_, _) async {},
    onLogout: () async {},
    onRetry: () async {},
  );
}

/// The computer/runtime step: the dev preview fixtures of the Web source
/// (dev/serverSetupPreviewFixtures.ts) expressed as the server projection plus
/// the machine list, on a server whose slug is `launch` (both providers show
/// `raft-computer setup /launch`).
Widget _computerStep(ParityContext ctx) {
  final wire = ScreenWire(ctx.fixtureData);
  final serverId = wire.server()['id'] as String;
  final step = '${ctx.props['step']}';
  Map<String, dynamic> option(String id, bool available) => {
    'runtimeId': id,
    'capabilityStatus': available ? 'available' : 'not_installed',
    'admissionStatus': 'available_for_new',
    'current': false,
    'availableForNew': true,
    'canSelectInThisContext': available,
  };
  const ids = [
    'claude',
    'codex',
    'kimi-sdk',
    'copilot',
    'cursor',
    'opencode',
    'pi',
  ];
  Map<String, dynamic> machine(String status) => {
    'id': 'preview-computer',
    'name': "Wenyi's MacBook Pro",
    'status': status,
    'runtimes': status == 'online' && (step == 'ready')
        ? ['claude']
        : <String>[],
    'isComputer': true,
    'computerAttachedByCurrentUser': true,
    'hostname': 'wenyi-macbook-pro.local',
    'os': 'darwin arm64',
  };
  final ready = step == 'ready';
  final online = step == 'ready' || step == 'not-ready';
  final projection = <String, dynamic>{
    'phase': 'in_progress',
    'surface': 'computer_runtime',
    'currentStep': 'computer_runtime',
    'blocksChat': true,
    'allowedExits': ctx.props['reset'] == true ? ['reset'] : <String>[],
    'sideEffectState': {'transitions': 'enabled', 'completion': 'enabled'},
    'gateReason': null,
    'computerStatus': online ? 'online' : 'offline',
    'runtimeStatus': ready
        ? 'ready_recommended'
        : step == 'not-ready'
        ? 'not_ready'
        : 'unknown',
    'runtimeOptions': online
        ? [for (final id in ids) option(id, ready && id == 'claude')]
        : <Map<String, dynamic>>[],
    'hasConnectedComputer': step != 'not-connected' && step != 'connecting',
    'offlineComputers': step == 'offline-recovery-many'
        ? [
            {
              'id': 'm1',
              'name': "Wenyi's MacBook Pro",
              'lastHeartbeat': '2026-07-13T13:30:00.000Z',
            },
            {'id': 'm2', 'name': "Wenyi's Mac Studio", 'lastHeartbeat': null},
            {
              'id': 'm3',
              'name': 'office-linux',
              'lastHeartbeat': '2026-07-01T09:00:00.000Z',
            },
          ]
        : <Map<String, dynamic>>[],
  };
  final client = ScreenFixtureClient(
    (method, path, query) {
      if (path == '/servers/$serverId/setup-projection') return projection;
      if (path == '/servers/$serverId/machines') {
        return {
          'machines': step == 'not-connected' || step == 'offline-recovery-many'
              ? <Map<String, dynamic>>[]
              : [machine(online ? 'online' : 'offline')],
        };
      }
      return wire.common(method, path, query);
    },
    user: wire.me(),
    server: serverId,
    origin: 'https://api.raft.build',
  );
  final w = WorkspaceController(client);
  final server = RaftRecord({...wire.server(), 'slug': 'launch'});
  w
    ..servers = [server]
    ..server = server;
  // Relative "last seen" times read the fixture instant the React provider
  // freezes its clock at.
  final now = DateTime.fromMillisecondsSinceEpoch(
    (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
  );
  return ServerSetupGate(
    controller: w,
    onSwitchServer: () {},
    now: () => now,
    child: const SizedBox.shrink(),
  );
}

ParityCase _case(Widget Function(ParityContext) build, {String? note}) =>
    ParityCase(
      widgets: const ['raft_flutter:AuthView', 'raft_ui:RaftAuthPage'],
      notes: 'Extension suite (not official).${note == null ? '' : ' $note'}',
      settle: const Duration(milliseconds: 300),
      build: build,
    );

/// surface name -> builder; the platform lists are in [_platforms].
final Map<String, ParityCase> _surfaces = {
  for (final s in const [
    'login.default',
    'login.social',
    'login.invalid-email',
    'login.missing-password',
    'login.error',
    'login.filled',
    'login.signing',
    'social.buttons',
    'social.hover',
  ])
    s: _case((ctx) => _auth(ctx, 'login')),
  for (final s in const [
    'forgot.default',
    'forgot.filled',
    'forgot.sent',
    'forgot.error',
  ])
    s: _case((ctx) => _auth(ctx, 'forgot')),
  for (final s in const [
    'reset.default',
    'reset.filled',
    'reset.too-short',
    'reset.mismatch',
    'reset.error',
    'reset.success',
  ])
    s: _case((ctx) => _auth(ctx, 'reset')),
  for (final s in const [
    'server.choose',
    'server.create-more',
    'server.create-more-filled',
    'server.create-first',
    'server.create-first-filled',
  ])
    s: _case(_serverSelector),
  for (final s in const [
    'setup.survey',
    'setup.survey-selected',
    'setup.survey-other',
    'setup.survey-error',
  ])
    s: _case((ctx) => _setupGate(ctx, survey: true)),
  for (final s in const ['setup.handoff', 'setup.handoff-starting'])
    s: _case((ctx) => _setupGate(ctx, survey: false)),
  for (final s in const [
    'setup.computer-not-connected',
    'setup.computer-connecting',
    'setup.computer-ready',
    'setup.computer-not-ready',
    'setup.computer-offline-recovery',
    'setup.computer-offline-recovery-many',
  ])
    s: _case(_computerStep),
  for (final s in const [
    'verify.default',
    'verify.manual',
    'verify.manual-filled',
    'verify.resent',
    'verify.resend-error',
    'verify.error',
  ])
    s: _case(_verify),
};

/// Surfaces a platform does not run (see build-auth-cases.py `platforms`).
const _platforms = {
  'desktop': <String>{'server.create-first', 'server.create-first-filled'},
  'mobile': <String>{},
};

/// Every extension auth case, keyed by id (3 themes each).
final Map<String, ParityCase> extAuthCases = {
  for (final platform in _platforms.keys)
    for (final MapEntry(key: name, value: parityCase) in _surfaces.entries)
      if (!_platforms[platform]!.contains(name))
        for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
          'components.auth-ext.$platform.$name.$theme': parityCase,
};
