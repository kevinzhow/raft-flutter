import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/private_app_invite.dart';

import 'private_app_invite_root_test.dart' show privateInvite;

void main() {
  test(
    'invite links are exact and bound to the active coordinator frontend',
    () {
      const origin = 'https://api.raft.build';
      for (final url in [
        '/integration-invites/abc_123-xyz',
        'https://app.raft.build/integration-invites/abc_123-xyz',
        'https://app.slock.ai/integration-invites/abc_123-xyz',
        'raft://v1/integration-invites/abc_123-xyz',
      ]) {
        final link = PrivateAppInviteLink.parse(Uri.parse(url), origin)!;
        expect(link.token, 'abc_123-xyz');
        expect(link.location.path, '/integration-invites/abc_123-xyz');
        expect(link.identity, isNot(contains('abc_123-xyz')));
      }
      for (final url in [
        'https://attacker.invalid/integration-invites/abc',
        '//app.raft.build/integration-invites/abc',
        'https://user@app.raft.build/integration-invites/abc',
        'https://app.raft.build:444/integration-invites/abc',
        '/integration-invites/abc?serverId=foreign',
        '/integration-invites/abc#fragment',
        '/integration-invites/abc/more',
        '/integration-invites/abc%2Fother',
        'raft://foreign/integration-invites/abc',
        '/integration-invites/',
      ]) {
        expect(
          PrivateAppInviteLink.parse(Uri.parse(url), origin),
          isNull,
          reason: url,
        );
      }
      expect(
        PrivateAppInviteLink.parse(
          Uri.parse('https://app.raft.build/integration-invites/abc'),
          'https://selfhost.example.invalid',
        ),
        isNull,
      );
    },
  );

  test(
    'self-hosted invite keeps its exact frontend and never replaces API origin',
    () {
      final link = PrivateAppInviteLink.parse(
        Uri.parse('https://selfhost.example.invalid/integration-invites/abc'),
        'https://selfhost.example.invalid',
      );
      expect(link?.location.toString(), '/integration-invites/abc');
    },
  );

  test('invite choices and declared scopes preserve the server response', () {
    final data = PrivateAppInvite.parse(privateInvite());
    expect(data.servers.single.id, 'b');
    expect(data.servers.single.installed, isFalse);
    expect(data.scopes, ['openid', 'profile']);
    final defaultScopes = privateInvite();
    (defaultScopes['client'] as Map)['allowedScopes'] = [];
    expect(PrivateAppInvite.parse(defaultScopes).scopes, [
      'openid',
      'profile',
      'identity',
    ]);
  });

  test('malformed or non-manager install choices fail closed', () {
    final cases = <Map<String, Object?>>[
      privateInvite()..['client'] = {},
      privateInvite()
        ..['manageableServers'] = [
          {'id': 'b', 'name': 'Beta', 'slug': 'beta', 'role': 'member'},
        ],
      privateInvite()..['manageableServers'] = 'not-a-list',
      privateInvite()..['link'] = null,
    ];
    final badScope = privateInvite();
    (badScope['client'] as Map)['allowedScopes'] = ['openid', 42];
    cases.add(badScope);
    final badDescription = privateInvite();
    (badDescription['client'] as Map)['description'] = 42;
    cases.add(badDescription);
    final invalidDate = privateInvite();
    (invalidDate['link'] as Map)['expiresAt'] = 'not-a-date';
    cases.add(invalidDate);
    final invalidInstalled = privateInvite();
    ((invalidInstalled['manageableServers'] as List).single
            as Map)['installedAt'] =
        '';
    cases.add(invalidInstalled);
    final duplicateServer = privateInvite();
    (duplicateServer['manageableServers'] as List).add(
      (duplicateServer['manageableServers'] as List).single,
    );
    cases.add(duplicateServer);
    for (final value in cases) {
      expect(() => PrivateAppInvite.parse(value), throwsFormatException);
    }
  });
}
