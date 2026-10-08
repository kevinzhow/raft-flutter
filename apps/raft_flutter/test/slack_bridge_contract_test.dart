import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/slack_bridge_contract.dart';

Map<String, dynamic> bridgeFixture() => {
  'protocolVersion': 1,
  'oauthAuthority': null,
  'snapshot': {
    'stage': 'channels',
    'workspaceName': 'Fixture Slack',
    'raftChannels': [
      {'id': 'r1', 'name': 'general'},
      {'id': 'r2', 'name': 'other'},
    ],
    'slackChannels': [
      {
        'id': 's1',
        'name': 'general',
        'isMember': true,
        'privacyClass': 'public',
      },
      {'id': 's2', 'name': 'other', 'isMember': false},
    ],
    'channelPairs': [
      {'raftChannelId': 'r1', 'slackChannelId': 's1', 'bindingEpoch': 7},
    ],
    'preflight': null,
    'rawHealth': {
      'install': {
        'state': 'active',
        'epochs': {
          'grant': '2',
          'connection': '4',
          'scope': '3',
          'credential': '5',
        },
      },
      'credential': {'state': 'active'},
      'bindings': [
        {
          'id': 'b1',
          'state': 'active',
          'bindingEpoch': 7,
          'stateReason': null,
          'recoveryAction': 'none',
        },
      ],
      'audiences': [
        {'bindingId': 'b1', 'status': 'matched'},
      ],
      'lastVerifiedAt': '2026-10-08T00:00:00Z',
      'failingSurface': null,
    },
  },
};
Map<String, dynamic> clone(Map<String, dynamic> v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;
void main() {
  test('preflight cannot succeed from a summary or duplicate checks', () {
    final v = bridgeFixture();
    for (final checks in [
      <dynamic>[],
      [
        {'id': 'oauth', 'state': 'passed'},
        {'id': 'oauth', 'state': 'passed'},
      ],
    ]) {
      v['snapshot']['preflight'] = {'state': 'passed', 'checks': checks};
      expect(() => SlackBridgeProjection.parse(v), throwsFormatException);
    }
    v['snapshot']['preflight'] = {
      'state': 'passed',
      'checks': [
        for (final id in ['oauth', 'endpoint', 'scope', 'audience'])
          {'id': id, 'state': 'passed'},
      ],
    };
    expect(SlackBridgeProjection.parse(v).preflightPassed, isTrue);
    v['snapshot']['preflight']['state'] = 'failed';
    expect(SlackBridgeProjection.parse(v).preflightPassed, isFalse);
  });
  test(
    'unknown contracts, overlapping pairs and missing authority fail closed',
    () {
      final v = bridgeFixture();
      final newer = clone(v)..['protocolVersion'] = 2;
      expect(() => SlackBridgeProjection.parse(newer), throwsFormatException);
      final duplicate = clone(v);
      duplicate['snapshot']['channelPairs'].add({
        'raftChannelId': 'r1',
        'slackChannelId': 's2',
        'bindingEpoch': 8,
      });
      expect(
        () => SlackBridgeProjection.parse(duplicate),
        throwsFormatException,
      );
      final oauth = clone(v);
      oauth['snapshot']['stage'] = 'oauth';
      expect(() => SlackBridgeProjection.parse(oauth), throwsFormatException);
      final unknown = clone(v);
      unknown['snapshot']['rawHealth']['healthy'] = true;
      expect(() => SlackBridgeProjection.parse(unknown), throwsFormatException);
    },
  );
  test('health requires durable verification and matched audience with ordered degradation', () {
    final v = bridgeFixture();
    expect(SlackBridgeProjection.parse(v).healthReason, 'healthy');
    v['snapshot']['rawHealth']['lastVerifiedAt'] = null;
    expect(
      SlackBridgeProjection.parse(v).healthReason,
      'verification_required',
    );
    v['snapshot']['rawHealth']['audiences'] = [];
    expect(SlackBridgeProjection.parse(v).healthReason, 'audience_unverified');
    v['snapshot']['rawHealth']['bindings'].add({
      'id': 'b2',
      'state': 'quarantined',
      'bindingEpoch': 8,
      'stateReason': 'paused',
      'recoveryAction': 'review_and_resume_binding',
    });
    v['snapshot']['rawHealth']['bindings'][0]['state'] = 'paused';
    expect(SlackBridgeProjection.parse(v).healthReason, 'binding_quarantined');
    v['snapshot']['rawHealth']['credential']['state'] = 'revoked';
    expect(SlackBridgeProjection.parse(v).healthReason, 'credential_revoked');
    v['snapshot']['rawHealth']['install']['state'] = 'pending';
    expect(SlackBridgeProjection.parse(v).healthReason, 'oauth_pending');
  });
  test('unsafe connection epochs cannot authorize disconnect', () {
    final v = bridgeFixture();
    expect(SlackBridgeProjection.parse(v).connectionEpoch, 4);
    for (final raw in ['0', '-2', '1.5', 'NaN', '9007199254740992']) {
      v['snapshot']['rawHealth']['install']['epochs']['connection'] = raw;
      expect(SlackBridgeProjection.parse(v).connectionEpoch, isNull);
    }
  });
  test('OAuth authorization rejects insecure or incomplete handoff', () {
    expect(
      () => SlackBridgeProjection.oauthUrl({
        'authorizationUrl': 'http://slack.invalid/auth',
        'expiresAt': '2026-10-08T00:00:00Z',
      }),
      throwsFormatException,
    );
    expect(
      () => SlackBridgeProjection.oauthUrl({
        'authorizationUrl': 'https://slack.invalid/auth',
        'expiresAt': 'tomorrow',
      }),
      throwsFormatException,
    );
  });
}
