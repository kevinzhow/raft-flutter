import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'action_card_spec_test.dart' show message, metadata, spec;
import 'message_presentation_test.dart' show fixture, host;

void main() {
  for (final (source, note) in [
    (
      null,
      'This agent is not on any computer, so there is nothing to bring over. It moves to the computer you choose and starts a fresh session there the next time it gets a message.',
    ),
    (
      'source',
      "This agent's Computer lost its access to the server, so its files can't be brought over. It moves to the computer you choose and starts a fresh session there the next time it gets a message.",
    ),
  ]) {
    final state = source == null ? 'no Computer' : 'access revoked';
    for (final fromCard in [false, true]) {
      final entry = fromCard ? 'the action card' : 'Agent settings';
      testWidgets('$entry places a BYOC agent with $state on a Computer', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1000, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, transport) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.server = RaftRecord({
          'id': 's1',
          'slug': 'fixture',
          'role': 'owner',
          'plan': 'free',
        });
        var agent = <String, dynamic>{
          'id': 'a1',
          'name': 'Fixture agent',
          'creatorType': 'user',
          'creatorId': 'alice',
          'executionMode': 'byoc',
          'runtime': 'codex',
          'model': 'fixture-model',
          'status': 'active',
          'machineId': source,
          if (source != null) 'blockedReason': 'computer_access_revoked',
        };
        final card = spec(action: {'kind': 'open', 'intent': 'migrate_agent'});
        final action = {
          'type': 'agent:migrate',
          'agentId': 'a1',
          'suggestedComputer': 'offline',
        };
        transport.routes.addAll({
          'GET /agents': (_) => [agent],
          'GET /agents/a1': (_) => agent,
          'GET /agents/a1/migration': (_) => {'migration': null},
          'GET /agents/a1/skills': (_) => {'global': [], 'workspace': []},
          'GET /servers/s1/machines': (_) => {
            'machines': [
              if (source != null)
                {
                  'id': source,
                  'name': 'Former Computer',
                  'status': 'online',
                  'isComputer': true,
                },
              {
                'id': 'offline',
                'name': 'Offline Computer',
                'status': 'offline',
                'isComputer': true,
              },
              {
                'id': 'target',
                'name': 'Target Computer',
                'status': 'online',
                'isComputer': true,
              },
            ],
          },
          'GET /billing/subscription': (_) => {'plan': 'free'},
          'POST /feature-flags/evaluate': (_) => {
            'evaluations': [
              {'key': 'antiproton_hosted_runtime', 'enabled': true},
              {'key': 'agent_migration_hosted_v0', 'enabled': true},
            ],
          },
          'GET /agent-runtime-providers/antiproton': (_) => {
            'kind': 'antiproton',
            'available': true,
          },
          'POST /agents/a1/migrate': (_) {
            agent = {...agent, 'machineId': 'target'}..remove('blockedReason');
            return {
              'outcome': 'placed_without_source',
              'migrationRef': null,
              'targetMachineId': 'target',
            };
          },
          'POST /actions/m1/event': (_) => {},
          'POST /actions/m1/mark-executed': (_) => {
            'messageId': 'm1',
            'metadata': metadata(
              card,
              state: 'executed',
              extra: {'action': action},
            ),
          },
        });
        await tester.runAsync(w.entityDirectory.preload);
        await tester.pumpWidget(
          host(
            fromCard
                ? MessageActionCard(
                    controller: w,
                    message: message(metadata(card, extra: {'action': action})),
                  )
                : FleetDetail(
                    controller: w,
                    computers: false,
                    initial: agent,
                    clock: () => DateTime.utc(2026, 11, 19),
                  ),
          ),
        );
        await tester.pumpAndSettle();

        final move = fromCard
            ? find.text('Approve change')
            : find.byWidgetPredicate(
                (widget) =>
                    widget is RaftButton &&
                    const {
                      'Move Agent',
                      'Move to Another Computer',
                    }.contains(widget.label),
              );
        expect(move, findsOneWidget);
        await tester.ensureVisible(move);
        await tester.tap(move);
        await tester.pumpAndSettle();

        final dialog = find.byType(RaftFormDialog);
        expect(find.text(note), findsOneWidget);
        expect(find.textContaining('Your agent will stop'), findsNothing);
        expect(
          find.textContaining('Migrating moves the workspace files'),
          findsNothing,
        );
        expect(find.textContaining('Upgrade to Pro'), findsNothing);
        expect(
          find.byKey(const ValueKey('agent-migration-pro-badge')),
          findsNothing,
        );
        expect(
          transport.calls.where(
            (call) => call.path.startsWith('/agent-runtime-providers/'),
          ),
          isEmpty,
        );
        final picker = find.descendant(
          of: dialog,
          matching: find.byKey(const ValueKey('migration-target-computer')),
        );
        expect(
          find.descendant(of: picker, matching: find.text('Target Computer')),
          findsOneWidget,
        );
        final formerComputer = find.text('Former Computer').evaluate().length;
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(find.text('Cloud'), findsNothing);
        expect(find.text('Former Computer'), findsNWidgets(formerComputer));
        expect(find.text('Offline Computer'), findsOneWidget);
        await tester.tap(find.text('Target Computer').last);
        await tester.pumpAndSettle();

        final submit = find.descendant(
          of: dialog,
          matching: find.widgetWithText(RaftButton, 'Move'),
        );
        expect(tester.widget<RaftButton>(submit).onPressed, isNotNull);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        final request = transport.calls.singleWhere(
          (call) => call.method == 'POST' && call.path == '/agents/a1/migrate',
        );
        expect(request.data, {'targetComputer': 'target'});
        if (fromCard) {
          final mark = transport.calls.singleWhere(
            (call) => call.path == '/actions/m1/mark-executed',
          );
          expect(mark.data, {
            'result': {
              'kind': 'agent-migration',
              'agentId': 'a1',
              'targetMachineId': 'target',
            },
            'expectedConfirmationVersion': 7,
          });
          expect(find.text('Done'), findsOneWidget);
        } else {
          expect(w.entityDirectory.agent('a1')?['machineId'], 'target');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
