// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the Public server page (inventory rows
// 1.19 / 1.20). NOT official cases; ids `components.public-server.<platform>.<surface>.<theme>` mirror
// tool/parity-ext/build-public-server.py and host/PublicServerCases.tsx.
//
// Data: tool/parity-ext/fixtures/public-server.json (fixtures['ext:public-server']); `routeSets[props.routeSet]`
// answers the API (`$pending` never answers, `$status` fails with that status), like the Web host's page.route.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/public_server_settings.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_ui/raft_ui.dart' show RaftAppearance;

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:public-server'] as Map<String, dynamic>;

/// The fixture answer of `METHOD path` for this case, throwing the error a `$status` rule stands for.
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

Widget _page(ParityContext ctx) {
  // The page remembers servers and pages across visits (instant revisit). One
  // process captures many cases, so every case starts from a cold page: the
  // loading and error cases must not render an earlier case's data.
  PublicServerMemory.clear();
  // The React provider pins its clock to the fixture instant; its locale
  // formats times 24-hour.
  final now = DateTime.fromMillisecondsSinceEpoch(
    (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
  );
  sourceTimeNow = () => now;
  addTearDown(() => sourceTimeNow = DateTime.now);
  final fx = _fx(ctx);
  final authenticated = ctx.props['authenticated'] == 'true';
  final user = Map<String, dynamic>.from(fx['user'] as Map);
  final servers = [
    for (final s in (fx['servers'] as Map)['two'] as List)
      RaftRecord(Map<String, dynamic>.from(s as Map)),
  ];
  final client = ScreenFixtureClient(
    (method, path, query) => _answer(ctx, method, path),
    user: authenticated ? {...user, 'emailVerified': true} : null,
  );
  // The signed-in visitor's workspace: no current server (a non-member).
  final controller = WorkspaceController(client);
  addTearDown(controller.dispose);
  final page = PublicServerView(
    client: client,
    slug: fx['slug'] as String,
    account: authenticated
        ? PublicServerAccount(
            servers: servers,
            onSelect: (_) {},
            settings: PublicSettingsAccount(
              controller: controller,
              appearance: RaftAppearance(
                mode: ctx.dark ? ThemeMode.dark : ThemeMode.light,
                light: ctx.family,
              ),
              onAppearance: (_) {},
            ),
          )
        : null,
    appVersion: '1.17.5',
    onSignIn: () {},
    onRegister: () {},
    onUnavailable: () {},
    onJoined: () async {},
  );
  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: page,
    ),
  );
}

ParityCase _case({String? note}) => ParityCase(
  widgets: const [
    'raft_flutter:PublicServerView',
    'raft_ui:RaftPublicServerLayout',
  ],
  notes: 'Extension suite (not official).${note == null ? '' : ' $note'}',
  settle: const Duration(milliseconds: 600),
  build: _page,
);

/// surface name -> builder; the platform lists are in [_platforms].
final Map<String, ParityCase> _surfaces = {
  for (final s in const [
    'page.default',
    'page.view-only',
    'page.empty-channels',
    'page.empty-messages',
    'page.loading',
    'page.messages-error',
    'page.thread',
    'page.settings-about',
    'page.settings-account',
    'page.join-ready',
    'page.join-confirm',
    'page.join-error',
    'page.join-agreement',
  ])
    s: _case(),
};

/// Surfaces a platform does not run (see build-public-server.py `platforms`).
const _platforms = {
  'desktop': <String>{},
  'mobile': <String>{'page.settings-about', 'page.settings-account'},
};

const _themes = ['brutal', 'elegant', 'elegant-dark'];

/// Every extension public-server case, keyed by id (3 themes each).
final Map<String, ParityCase> extPublicServerCases = {
  for (final platform in _platforms.keys)
    for (final MapEntry(key: name, value: parityCase) in _surfaces.entries)
      if (!_platforms[platform]!.contains(name))
        for (final theme in _themes)
          'components.public-server.$platform.$name.$theme': parityCase,
};
