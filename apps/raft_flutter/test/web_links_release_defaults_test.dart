import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_flutter/features/workspace_browser.dart';
import 'package:raft_flutter/platform/content_links.dart';
import 'package:raft_ui/raft_ui.dart';

/// A release build passes no RAFT_FRONTEND_ORIGIN / RAFT_ORIGIN define to the
/// Dart compiler for link construction (`flutter test` passes none either), so
/// these tests exercise exactly what the shipped app does. The API origin does
/// not serve the Web client: every browser-facing link of the official server
/// must use the Web app origin.
const _api = 'https://api.raft.build', _web = 'https://app.raft.build';

class _Client extends RaftClient {
  _Client(this.routes)
    : super(origin: _api, sessionStore: MemorySessionStore()) {
    user = RaftRecord({'id': 'u-owner', 'name': 'owner'});
    selectServer('s1');
  }
  final Map<String, Object? Function(dynamic)> routes;

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
    if (route == null) {
      throw RaftApiException('Not found: $method $path', status: 404);
    }
    return route(data);
  }
}

void main() {
  test('the test run carries no frontend define (release defaults)', () {
    expect(const String.fromEnvironment('RAFT_FRONTEND_ORIGIN'), isEmpty);
    expect(const String.fromEnvironment('RAFT_ORIGIN'), isEmpty);
  });

  test('the official API maps to the Web app, other servers do not move', () {
    expect(ContentLinks.originFor(_api).toString(), _web);
    expect(ContentLinks.originFor('$_api/').toString(), _web);
    expect(
      ContentLinks.originFor('https://api.slock.ai').toString(),
      'https://app.slock.ai',
    );
    // Self-hosted / local servers keep the coordinator as their own origin.
    for (final other in [
      'https://raft.example.org',
      'http://localhost:13041',
      'https://api.raft.build.evil.example',
      'http://api.raft.build',
    ]) {
      expect(ContentLinks.originFor(other).origin, Uri.parse(other).origin);
    }
  });

  test(
    'an explicit frontend bound to this API wins, an unbound one does not',
    () {
      expect(
        ContentLinks.originFor(
          _api,
          frontend: 'https://web.example.com',
          api: _api,
        ).toString(),
        'https://web.example.com',
      );
      for (final (frontend, api) in [
        ('https://web.example.com', 'https://other.example.com'),
        ('https://user:pw@web.example.com', _api),
        ('https://web.example.com/path', _api),
        ('http://web.example.com', _api),
        ('', _api),
      ]) {
        expect(
          ContentLinks.originFor(_api, frontend: frontend, api: api).toString(),
          _web,
          reason: '$frontend bound to $api',
        );
      }
    },
  );

  test(
    'message, invite and billing links for the official server are Web links',
    () {
      final origin = ContentLinks.originFor(_api);
      expect(
        ContentLinks.messageUrl(
          origin: origin,
          slug: 'myoland',
          channelId: 'c1',
          messageId: 'm1',
          parentMessageId: 'p1',
        ).toString(),
        '$_web/s/myoland/channel/c1?msg=m1&thread=c1%3Ap1',
      );
      expect('${origin.origin}/join/tok', '$_web/join/tok');
      expect(
        origin.replace(path: '/s/myoland/settings/billing').toString(),
        '$_web/s/myoland/settings/billing',
      );
    },
  );

  test(
    'the official workspace opens in the Web app, others need a binding',
    () {
      expect(workspaceBrowserOrigin(_api).toString(), _web);
      expect(workspaceBrowserOrigin('http://localhost:13041'), isNull);
      expect(workspaceBrowserOrigin('https://raft.example.org'), isNull);
      expect(
        workspaceBrowserOrigin(
          'https://raft.example.org',
          frontend: 'https://web.example.org',
          api: 'https://raft.example.org',
        ).toString(),
        'https://web.example.org',
      );
    },
  );

  testWidgets('Make this server public shows the Web app page, not the API', (
    t,
  ) async {
    final current = {
      'publiclyVisible': true,
      'publicGuestJoinEnabled': false,
      'slug': 'myoland',
      'exposedChannels': [
        {'name': 'general', 'description': 'Everything'},
      ],
    };
    final client = _Client({
      'POST /feature-flags/evaluate': (_) => {
        'evaluations': [
          {'key': 'public_server_v0', 'enabled': true},
          {'key': 'server_guest_v0', 'enabled': true},
        ],
      },
      'GET /servers/s1/public-visibility': (_) => current,
    });
    final server = RaftRecord({
      'id': 's1',
      'name': 'Myoland',
      'slug': 'myoland',
      'role': 'owner',
    });
    final w = WorkspaceController(client)
      ..server = server
      ..servers = [server];
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    t.view.physicalSize = const Size(1000, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: ServerSettingsView(controller: w)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('$_web/s/myoland'), findsOneWidget);
    expect(find.textContaining('$_api/s/'), findsNothing);
  });

  test('Web links are never built from the bare API origin', () {
    // Every lib file that puts a Web path after an origin must go through
    // ContentLinks (or take an already-resolved Web origin as a parameter).
    final web = RegExp(r"""/join/\$|/integration-invites/|/download'|/s/\$""");
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync().where(
        (line) => !line.trimLeft().startsWith('//'),
      );
      if (!lines.any(web.hasMatch)) continue;
      // app_root.dart builds in-app router locations (Uri(path: '/s/..')), not
      // browser URLs; app_update.dart builds GitHub release asset URLs.
      final text = lines.join('\n');
      if (!text.contains('ContentLinks') &&
          !text.contains('webOrigin') &&
          !file.path.endsWith('app_root.dart') &&
          !file.path.endsWith('app_update.dart')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
