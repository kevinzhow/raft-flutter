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
  testWidgets('healthy Slack skips the space for absent recovery notices', (
    tester,
  ) async {
    final snapshot = bridgeFixture()..['snapshot']['stage'] = 'health';
    final bridge = snapshot['snapshot'] as Map<String, dynamic>;
    final workspaceName = bridge['workspaceName']! as String;
    final client = _RecoveryClient((method, path, _) {
      if (path == '/feature-flags/evaluate') {
        return {
          'evaluations': [
            {'key': 'slack_bridge_v0', 'enabled': true},
          ],
        };
      }
      if (path == '/slack-bridge/provisioning') return snapshot;
      return const <Object?>[];
    });
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 'workspace', 'role': 'owner'});
    addTearDown(client.dispose);
    addTearDown(workspace.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(body: IMBridgesView(controller: workspace)),
      ),
    );
    await tester.pumpAndSettle();

    final badge = find.widgetWithText(RaftBadge, workspaceName);
    final verification = find.widgetWithText(RaftCssText, 'Verification');
    expect(
      tester.getTopLeft(verification).dy - tester.getBottomLeft(badge).dy,
      RaftSpace.x4,
    );
  });

  testWidgets(
    'a narrow provisioning error uses the Settings gutter and warning',
    (tester) async {
      final client = _RecoveryClient((method, path, _) {
        if (path == '/feature-flags/evaluate') {
          return {
            'evaluations': [
              {'key': 'slack_bridge_v0', 'enabled': true},
            ],
          };
        }
        if (path == '/slack-bridge/provisioning') {
          throw const RaftApiException('Service unavailable', status: 503);
        }
        return const <Object?>[];
      });
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({'id': 'workspace', 'role': 'owner'});
      addTearDown(client.dispose);
      addTearDown(workspace.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.linux),
          home: Scaffold(body: IMBridgesView(controller: workspace)),
        ),
      );
      await tester.pumpAndSettle();

      final warning = find.byType(RaftBanner);
      expect(warning, findsOneWidget);
      expect(tester.widget<RaftBanner>(warning).glyph, RaftGlyph.alertTriangle);
      expect(tester.getTopLeft(warning).dx, 16);
      expect(find.byKey(const ValueKey('slack-bridge-wizard')), findsNothing);
    },
  );

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
      final recovery = find.widgetWithText(
        RaftBanner,
        'Outgoing messages are waiting for recovery.',
      );
      final banner = tester.widget<RaftBanner>(recovery);
      expect(banner.size, RaftBannerRecipeSize.sm);
      expect(banner.glyph, RaftGlyph.triangleAlert);
      final held = find.widgetWithText(RaftBanner, 'Messages need attention');
      expect(
        tester.getTopLeft(held).dy - tester.getBottomLeft(recovery).dy,
        RaftSpace.x4,
      );
      final inboundExplanation = find.descendant(
        of: held,
        matching: find.textContaining('These messages are saved safely'),
      );
      final inboundAction = find.widgetWithText(RaftButton, 'Retry message');
      final inboundRow = find.ancestor(
        of: inboundAction,
        matching: find.byType(Wrap),
      );
      expect(
        tester.getTopLeft(inboundRow.first).dy -
            tester.getBottomLeft(inboundExplanation).dy,
        RaftSpace.x3,
      );
      final retry = find.widgetWithText(RaftButton, 'Retry stalled message');
      final channel = find.descendant(
        of: recovery,
        matching: find.text('#general'),
      );
      expect(
        tester.getBottomLeft(channel).dy,
        lessThan(tester.getTopLeft(retry).dy),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('slack-bridge-health')),
          matching: retry,
        ),
        findsOneWidget,
      );
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
