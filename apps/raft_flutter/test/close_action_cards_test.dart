import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_action_card.dart';

import 'action_card_form_test.dart' show field, form;
import 'action_card_spec_test.dart' show copy, message, metadata, node, spec;
import 'close_dialogs_test.dart' show anyX;
import 'message_presentation_test.dart' show fixture, host;
import 'support/close_registry_action_cards.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/close_support.dart' show frames;

void main() {
  final confirm = {
    ...spec(action: {'kind': 'execute', 'confirm': 'review'}),
    'confirms': {
      'review': {
        'title': copy('Review permissions'),
        'confirmLabel': copy('Allow'),
        'spec': {
          'root': 'root',
          'elements': {
            'root': node('Text', {'text': 'Grants permission.'}),
          },
        },
      },
    },
  };
  final definitions =
      <String, ({String title, String button, Map<String, Object> metadata})>{
        'action-card-confirm': (
          title: 'Review permissions',
          button: 'Approve change',
          metadata: metadata(confirm),
        ),
        'action-card-form': (
          title: 'Review the change',
          button: 'Approve change',
          metadata: metadata(
            form({
              'fields': [field('TextInput', 'notes', 'Notes')],
            }),
          ),
        ),
        'action-card-install': (
          title: 'Install App',
          button: 'Approve change',
          metadata: metadata(
            spec(),
            type: 'integration:install_marketplace_app',
          ),
        ),
        'action-card-feedback': (
          title: 'Submit feedback',
          button: 'Approve change',
          metadata: metadata(
            spec(action: {'kind': 'open', 'intent': 'feedback_form'}),
            type: 'feedback:submit',
          ),
        ),
        'action-card-mcp-default': (
          title: 'Make Team notes the default for all agents?',
          button: 'Grant access to Agent',
          metadata: metadata(
            spec(),
            extra: {
              'action': {
                'type': 'integration:connect_mcp',
                'mcpServerId': 'app',
                'agentId': 'agent',
              },
            },
          ),
        ),
        'action-card-send-create-agent': (
          title: 'Send requeste a card to create Scribe?',
          button: 'Send',
          metadata: metadata(
            spec(),
            state: 'executed',
            type: 'seats:add',
            extra: {
              'requesterUserId': 'requester',
              'seatOutcome': {
                'kind': 'ready',
                'purpose': 'agent:create',
                'name': 'Scribe',
              },
            },
          ),
        ),
      };

  registerCloseTests(actionCardSurfaces, {
    for (final entry in definitions.entries)
      entry.key: (tester, size) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final (workspace, transport) = (await tester.runAsync(
          () => fixture('owner'),
        ))!;
        addTearDown(workspace.dispose);
        transport.routes['POST /actions/m1/event'] = (_) => {};
        transport
            .routes['GET /mcp/servers/app/connection-authorization'] = (_) => {
          'canSetServerDefault': true,
          'candidates': [
            {'connectionId': 'notes', 'name': 'Team notes', 'status': 'ready'},
          ],
        };
        transport.routes['GET /mcp/apps/app/default/impact'] = (_) => {
          'currentDefaultConnectionId': null,
          'agentsChangingNow': 2,
        };
        await tester.pumpWidget(
          host(
            MessageActionCard(
              controller: workspace,
              message: message(entry.value.metadata),
            ),
          ),
        );
        await frames(tester, 20);
        if (entry.key == 'action-card-send-create-agent') {
          await tester.tap(
            find.byKey(const ValueKey('action-card-toggle-details')),
          );
          await frames(tester, 8);
        }
        await tester.tap(find.text(entry.value.button).hitTestable().first);
        await frames(tester, 20);
        return SurfaceProbe(
          isOpen: () => find.text(entry.value.title).evaluate().isNotEmpty,
          x: anyX,
          scrim: const Offset(6, 6),
          dragHandle: find.byKey(const ValueKey('raft-sheet-handle')),
        );
      },
  });
}
