// A saved session for a self-hosted server on a private address cannot connect
// while Android withholds local network access (the system lets those
// connections time out: the workspace sat on "Loading..." forever). Startup now
// says so and offers the permission; allowing it restores the session.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/session_recovery_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/local_network_access.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

class _Blocked extends LocalNetworkAccess {
  _Blocked();
  bool granted = false;
  int requests = 0;
  @override
  Future<void> gateRestore(RaftClient client) async {
    if (!granted) {
      throw const SessionRestoreException(
        SessionRestoreFailureKind.localNetwork,
      );
    }
  }

  @override
  Future<bool> allow() async {
    requests++;
    return granted = true;
  }
}

void main() {
  testWidgets(
    'blocked local network: recovery screen without any request, Allow restores the session',
    (t) async {
      final f = RootFixture();
      final network = f.network = _Blocked();
      await f.mount(t, 'elegant-light', 390);
      expect(find.byType(SessionRecoveryView), findsOneWidget);
      expect(find.text('Local network access is off'), findsOneWidget);
      expect(
        f.adapter.calls.where((c) => c.path == '/auth/me'),
        isEmpty,
        reason: 'nothing is sent to a server the system would time out on',
      );
      expect(
        (await f.sessions.read('https://fixture.invalid'))?.refreshToken,
        'fixture-only',
        reason: 'the saved sign-in is kept',
      );

      await t.tap(find.text('Allow local network access'));
      await f.flush(t);
      expect(network.requests, 1);
      expect(find.byType(SessionRecoveryView), findsNothing);
      expect(
        find.byType(GlobalServerSelector).evaluate().isNotEmpty ||
            find.byType(WorkspaceView).evaluate().isNotEmpty,
        isTrue,
      );
      await f.close(t);
    },
  );
}
