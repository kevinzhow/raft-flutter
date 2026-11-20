import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/im_bridges_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';
import 'slack_bridge_contract_test.dart' show bridgeFixture;

class _RecoveryClient extends ScreenFixtureClient {
  _RecoveryClient(super.route)
    : super(user: const {'id': 'person'}, server: 'workspace');

  final mutations = <(String, Object?)>[];

  @override
  Future<dynamic> post(String path, {dynamic data}) {
    if (path.startsWith('/slack-bridge/')) mutations.add((path, data));
    return super.post(path, data: data);
  }
}

void main() {
  testWidgets(
    'negotiates delivery diagnostics and retries the selected delivery',
    (tester) async {
      const path = '/slack-bridge/provisioning';
      final reads = <Map<String, dynamic>?>[];
      var retried = false;
      var replayed = false;
      Map<String, dynamic> snapshot() => bridgeFixture()
        ..['snapshot']['stage'] = 'health'
        ..['snapshot']['rawHealth']['outboundDeliveries'] = [
          {
            'raftChannelId': 'r1',
            'bindingId': 'b1',
            'bindingEpoch': 7,
            'deliveryId': 'delivery-1',
            'providerAttempts': 2,
            'state': 'outcome_unknown',
            'retryRequested': retried,
          },
        ]
        ..['snapshot']['rawHealth']['inboundIsolated'] = [
          if (!replayed)
            {
              'raftChannelId': 'r1',
              'bindingId': 'b1',
              'bindingEpoch': 7,
              'eventId': 'event-1',
              'reason': 'actor_identity_pending',
              'firstFailureAt': null,
              'heldAt': null,
            },
        ];
      final client = _RecoveryClient((method, route, query) {
        if (route == '/feature-flags/evaluate') {
          return {
            'evaluations': [
              {'key': 'slack_bridge_v0', 'enabled': true},
            ],
          };
        }
        if (route == '$path/retry-delivery') {
          retried = true;
          return snapshot();
        }
        if (route == '$path/replay-inbound') {
          replayed = true;
          return snapshot();
        }
        if (route == path) {
          reads.add(query);
          return snapshot();
        }
        return const <Object>[];
      });
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({
          'id': 'workspace',
          'name': 'Fixture',
          'role': 'owner',
        });
      addTearDown(workspace.dispose);
      addTearDown(client.dispose);
      tester.view.physicalSize = const Size(856, 944);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.android),
          home: Scaffold(body: IMBridgesView(controller: workspace)),
        ),
      );
      await tester.pumpAndSettle();

      expect(reads.single, containsPair('deliveryHealth', '1'));
      expect(reads.single, containsPair('inboundRecovery', '1'));
      final retry = find.widgetWithText(RaftButton, 'Retry stalled message');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(client.mutations.single.$1, '$path/retry-delivery');
      expect(client.mutations.single.$2, {
        'bindingId': 'b1',
        'bindingEpoch': 7,
        'deliveryId': 'delivery-1',
        'expectedProviderAttempts': 2,
        'duplicateRiskAcknowledged': true,
      });
      expect(reads, hasLength(1));
      expect(retry, findsNothing);
      expect(find.text('Retry requested'), findsOneWidget);

      final replay = find.text('Retry message');
      await tester.ensureVisible(replay);
      await tester.tap(replay);
      await tester.pumpAndSettle();
      expect(client.mutations.last.$1, '$path/replay-inbound');
      expect(client.mutations.last.$2, {
        'bindingId': 'b1',
        'bindingEpoch': 7,
        'eventId': 'event-1',
      });
      expect(reads, hasLength(1));
      expect(find.text('Messages need attention'), findsNothing);
    },
  );
}
