import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/desktop_windows.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'desktop_server_windows_test.dart' show WindowsFixture;
import 'desktop_window_broker_test.dart' show Peer;

class StartupWindow extends WindowsFixture {
  bool resolved = false;
  @override
  bool get isChild => true;
  @override
  String get navigationNamespace => 'fixture-child';
  @override
  String? get startupServerId => resolved ? null : 's2';
  @override
  void bind(
    RaftClient? client,
    String? serverId, {
    Future<void> Function()? onLogout,
    WorkspaceCache? cache,
    Future<bool> Function()? prepareClose,
    void Function()? cancelClose,
  }) {
    if (serverId != null) resolved = true;
  }
}

void main() {
  testWidgets(
    'real app root opens the native target by stable id after its slug changes and keeps child navigation off disk',
    (t) async {
      final f = RootFixture();
      f.overrides['GET /servers'] = (_) => [
        {'id': 's1', 'name': 'Alpha', 'slug': 'alpha', 'role': 'owner'},
        {
          'id': 's2',
          'name': 'Renamed Beta',
          'slug': 'renamed-beta',
          'role': 'owner',
        },
      ];
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri(path: '/s/old-beta'),
        desktopWindows: StartupWindow(),
      );
      expect(f.workspace(t).server!.id, 's2');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.contains('.window.fixture-child')),
        isEmpty,
      );
      await f.close(t);
    },
  );

  testWidgets(
    'child logout waits for the primary Root revocation POST before disposing its client',
    (t) async {
      final gate = Completer<dynamic>(), reached = Completer<void>();
      final f = RootFixture();
      f.overrides['POST /auth/logout'] = (_) {
        if (!reached.isCompleted) reached.complete();
        return gate.future;
      };
      late Peer peer;
      final broker = DesktopSessionBroker(
        createWindow: (id, server, broker) async {
          peer = Peer(broker, id);
          return peer;
        },
        focusPrimary: () async {},
      );
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri(path: '/s/alpha'),
        desktopWindows: broker,
      );
      await t.runAsync(() => broker.openServer(RaftRecord({'id': 'b'})));
      final primary = f.client;
      late Future<void> ending;
      await t.runAsync(() async {
        ending = broker.end(peer.id, SessionEndReason.userRequested);
      });
      await f.flush(t);
      try {
        expect(reached.isCompleted, isTrue);
        expect(
          primary.disposalCount,
          0,
          reason: 'Root must keep the primary transport alive until the logout request settles',
        );
      } finally {
        gate.complete({'ok': true});
        await t.runAsync(() => ending);
        await f.close(t);
        await broker.dispose();
        await peer.stream.close();
      }
      expect(primary.disposalCount, 1);
    },
  );
}
