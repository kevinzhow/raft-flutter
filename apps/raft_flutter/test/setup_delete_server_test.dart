import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/server_setup_gate.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web SetupSessionFooter: the server's owner can delete the server from the
/// blocking setup surface (Settings is covered by it), with the same
/// type-the-slug confirmation as the Settings danger zone.
class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final requests = <String>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/setup-projection') {
      return {
        'phase': 'in_progress',
        'surface': 'computer_runtime',
        'blocksChat': true,
        'allowedExits': <String>[],
        'sideEffectState': {'transitions': 'enabled', 'completion': 'enabled'},
      };
    }
    if (path == '/servers/s/machines') return {'machines': <dynamic>[]};
    return <dynamic>[];
  }

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
    if (method == 'GET') return get(path, query: query);
    requests.add('$method $path');
    return <String, dynamic>{};
  }

  @override
  Stream<RaftEvent> get events => stream.stream;
}

/// The setup step animates (spinners); a few frames are enough.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late _Client c;
  late WorkspaceController w;

  Future<void> host(WidgetTester t, {required String role}) async {
    c = _Client()..user = RaftRecord({'id': 'me'});
    c.selectServer('s');
    w = WorkspaceController(c)
      ..server = RaftRecord({
        'id': 's',
        'slug': 'raft',
        'name': 'Raft HQ',
        'role': role,
      });
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
      await c.dispose();
    });
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(900, 1200);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: ServerSetupGate(
            controller: w,
            onSwitchServer: () {},
            child: const Center(child: Text('Conversation')),
          ),
        ),
      ),
    );
    await _settle(t);
  }

  final link = find.byKey(const ValueKey('setup-delete-server'));

  testWidgets('the owner sees Delete this server beside Switch server', (
    t,
  ) async {
    await host(t, role: 'owner');
    expect(find.text('Switch server'), findsOneWidget);
    expect(find.text('Delete this server'), findsOneWidget);
    expect(link, findsOneWidget);
  });

  testWidgets('an admin does not', (t) async {
    await host(t, role: 'admin');
    expect(find.text('Switch server'), findsOneWidget);
    expect(find.text('Delete this server'), findsNothing);
  });

  testWidgets('it asks for the slug before deleting', (t) async {
    await host(t, role: 'owner');
    await t.tap(link);
    await _settle(t);
    expect(find.text('Delete Server'), findsWidgets);
    final confirm = find.byKey(const Key('server-delete-confirm-button'));
    expect(t.widget<RaftSettingsRecipeButton>(confirm).onPressed, isNull);
    await t.enterText(
      find.byKey(const Key('server-delete-slug-input')),
      'nope',
    );
    await t.pump();
    expect(t.widget<RaftSettingsRecipeButton>(confirm).onPressed, isNull);
    await t.enterText(
      find.byKey(const Key('server-delete-slug-input')),
      'raft',
    );
    await t.pump();
    expect(t.widget<RaftSettingsRecipeButton>(confirm).onPressed, isNotNull);
    expect(c.requests, isEmpty);
    await t.tap(confirm);
    await _settle(t);
    expect(c.requests, contains('DELETE /servers/s'));
  });

  testWidgets('cancelling deletes nothing', (t) async {
    await host(t, role: 'owner');
    await t.tap(link);
    await _settle(t);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    expect(c.requests, isEmpty);
    expect(link, findsOneWidget);
  });

  testWidgets('Chinese copy comes from the Web catalog', (t) async {
    await host(t, role: 'owner');
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: ServerSetupGate(
            controller: w,
            onSwitchServer: () {},
            child: const Center(child: Text('Conversation')),
          ),
        ),
      ),
    );
    await _settle(t);
    expect(find.text('删除这个服务器'), findsOneWidget);
  });
}
