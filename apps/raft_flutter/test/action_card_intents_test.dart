import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_flutter/platform/web_billing.dart';

import 'action_card_spec_test.dart' show message, metadata, spec;
import 'message_presentation_test.dart' show fixture, host;

void main() {
  testWidgets(
    'install recovers from a failed read and verifies before retrying execution',
    (tester) async {
      final (workspace, transport) = (await tester.runAsync(
        () => fixture('owner'),
      ))!;
      addTearDown(workspace.dispose);
      final card = spec();
      final action = {
        'type': 'integration:install_marketplace_app',
        'clientId': 'app',
        'clientKey': 'notes',
        'clientNameSha256': sha256.convert(utf8.encode('Notes')).toString(),
        'agentName': 'Scout',
        'installScopes': ['openid', 'profile', 'identity'],
        'installGroups': <String>[],
      };
      var reads = 0, writes = 0;
      transport.routes['GET /integrations/marketplace'] = (_) {
        if (++reads == 1) throw StateError('Fixture listing failure');
        return [
          {
            'id': 'app',
            'clientId': 'notes',
            'name': 'Notes',
            'appType': 'third_party_global',
            'humanMarketplaceVisible': true,
            'publishStatus': 'published',
          },
        ];
      };
      transport.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [],
      };
      transport.routes['POST /auth/second-factor/step-up'] = (_) => {};
      transport.routes['POST /actions/m1/execute'] = (request) {
        if (++writes == 1) {
          throw DioException.badResponse(
            statusCode: 403,
            requestOptions: request,
            response: Response(
              requestOptions: request,
              statusCode: 403,
              data: {
                'error': 'Confirm it is you first.',
                'code': 'second_factor_step_up_required',
                'methods': ['totp'],
              },
            ),
          );
        }
        return {
          'messageId': 'm1',
          'metadata': metadata(
            card,
            state: 'executed',
            extra: {'action': action},
          ),
        };
      };
      await tester.pumpWidget(
        host(
          MessageActionCard(
            controller: workspace,
            message: message(metadata(card, extra: {'action': action})),
          ),
        ),
      );
      await tester.tap(find.text('Approve change'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Install'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsNothing);
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      expect(find.text("Verify it's you"), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.pump();
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      final mutations = transport.calls
          .where((call) => call.path.endsWith('/execute'))
          .toList();
      expect(reads, 2);
      expect(mutations, hasLength(2));
      expect(mutations.first.data, mutations.last.data);
      expect(find.text('Install App'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    },
  );

  testWidgets('a paid action opens Web billing without executing', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('owner'),
    ))!;
    addTearDown(workspace.dispose);
    workspace.server = RaftRecord({
      'id': 's1',
      'role': 'owner',
      'slug': 'fixture',
    });
    final launched = <Uri>[];
    final original = webBillingLauncher;
    addTearDown(() => webBillingLauncher = original);
    webBillingLauncher = (address) async {
      launched.add(address);
      return true;
    };
    final card = spec(action: {'kind': 'open', 'intent': 'add_seats'});
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(metadata(card, type: 'seats:add')),
        ),
      ),
    );
    await tester.tap(find.text('Approve change'));
    await tester.pumpAndSettle();
    expect(launched.single.path, '/s/fixture/settings/billing');
    expect(
      transport.calls.where((call) => call.path.startsWith('/actions/')),
      isEmpty,
    );
  });

  testWidgets('the MCP grant follows the default and stores no connection ID', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('owner'),
    ))!;
    addTearDown(workspace.dispose);
    final card = spec();
    final action = {
      'type': 'integration:connect_mcp',
      'mcpServerId': 'app',
      'agentId': 'agent',
    };
    transport.routes['GET /mcp/servers/app/connection-authorization'] = (_) => {
      'app': {'name': 'Fixture notes', 'authKind': 'oauth'},
      'canSetServerDefault': true,
      'candidates': [
        {
          'connectionId': 'con',
          'name': 'Team notes',
          'status': 'ready',
          'isServerDefault': true,
        },
      ],
    };
    transport.routes['PUT /mcp/agents/agent/assignments/app'] = (_) => {};
    transport.routes['POST /actions/m1/event'] = (_) => {};
    transport.routes['POST /actions/m1/mark-executed'] = (_) => {
      'messageId': 'm1',
      'metadata': metadata(card, state: 'executed', extra: {'action': action}),
    };
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(metadata(card, extra: {'action': action})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Team notes'), findsOneWidget);
    await tester.tap(find.text('Grant access to Agent'));
    await tester.pumpAndSettle();
    expect(
      transport.calls
          .singleWhere((call) => call.path.contains('/assignments/'))
          .data,
      {'connectionId': null, 'enabled': true},
    );
    expect(
      transport.calls
          .singleWhere((call) => call.path.endsWith('/mark-executed'))
          .data,
      {
        'result': {
          'kind': 'mcp-connection',
          'mcpServerId': 'app',
          'agentId': 'agent',
        },
        'expectedConfirmationVersion': 7,
      },
    );
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Grant access to Agent'), findsNothing);
  });

  testWidgets('feedback sends the edited draft and applies its card receipt', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('owner'),
    ))!;
    addTearDown(workspace.dispose);
    final card = spec(action: {'kind': 'open', 'intent': 'feedback_form'});
    final action = {
      'type': 'feedback:submit',
      'feedbackType': 'idea',
      'message': 'Original draft',
    };
    transport.routes['POST /actions/m1/event'] = (_) => {};
    transport.routes['POST /product-feedback'] = (_) => {
      'action_card': {
        'message_id': 'm1',
        'metadata': metadata(
          card,
          state: 'executed',
          extra: {'action': action},
        ),
      },
    };
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(metadata(card, extra: {'action': action})),
        ),
      ),
    );
    await tester.tap(find.text('Approve change'));
    await tester.pumpAndSettle();
    expect(find.text('Original draft'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Edited feedback');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    final form =
        transport.calls
                .singleWhere((call) => call.path == '/product-feedback')
                .data
            as FormData;
    final payload = Map<String, String>.fromEntries(form.fields);
    expect(payload['message'], 'Edited feedback');
    expect(payload['action_card_message_id'], 'm1');
    expect(payload['expected_confirmation_version'], '7');
    expect(find.text('Done'), findsOneWidget);
  });
}
