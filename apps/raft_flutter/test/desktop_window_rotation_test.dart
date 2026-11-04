import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/desktop_windows.dart';

import 'app_global_server_selector_test.dart' show RootCache;
import 'desktop_window_broker_test.dart' show Peer, NoWrites, owner, beta;

class DelayedProfilePeer extends Peer {
  DelayedProfilePeer(super.broker, super.id);
  @override
  Future<void> publish(SharedSessionSnapshot? snapshot) async {}
}

void main() {
  test('a profile update during an old-token held 401 cannot be mistaken for credential rotation', () async {
    final (primary, api) = await owner();
    final entered = Completer<void>(), release = Completer<void>();
    var refreshes = 0;
    api.routes['POST /auth/refresh'] = (_) {
      refreshes++;
      return {'accessToken': 'second', 'refreshToken': 'refresh-second'};
    };
    api.routes['GET /probe'] = (request) async {
      if (request.headers['Authorization'] == 'Bearer first') {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        throw DioException(
          requestOptions: request,
          response: Response<dynamic>(
            requestOptions: request,
            statusCode: 401,
            data: {'error': 'old fixture token'},
          ),
        );
      }
      return {'ok': true};
    };
    late DelayedProfilePeer peer;
    final broker = DesktopSessionBroker(
      createWindow: (id, s, b) async => peer = DelayedProfilePeer(b, id),
      focusPrimary: () async {},
    );
    broker.bind(primary, null, cache: RootCache());
    await broker.openServer(beta);
    final child = RaftClient(
      origin: primary.origin,
      sessionStore: NoWrites(),
      sharedSessionAuthority: peer,
      transport: Dio()..httpClientAdapter = api,
      recoveryBackoff: const [],
    );
    expect(await child.restore(cachedFirst: true), isTrue);
    await child.sessionValidated;
    final held = child.get('/probe');
    await entered.future;
    api.routes['GET /auth/me'] = (_) => {
      'id': 'human',
      'name': 'Updated profile',
    };
    await primary.reloadUser();
    await Future<void>.delayed(Duration.zero);
    release.complete();
    try {
      expect(await held, {'ok': true});
      expect(refreshes, 1);
      expect(child.sessionForSharing!.accessToken, 'second');
      expect(child.user!.string('name'), 'Updated profile');
    } finally {
      await child.dispose();
      await broker.dispose();
      await peer.stream.close();
      await primary.dispose();
    }
  });
}
