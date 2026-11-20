import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_ui/raft_ui.dart';

import 'action_card_form_test.dart' show field, form, option;
import 'action_card_spec_test.dart' show copy, message, metadata, node, spec;
import 'message_presentation_test.dart' show fixture, host;

void main() {
  for (final viewport in [
    (Size(856, 944), TargetPlatform.android),
    (Size(944, 856), TargetPlatform.android),
    (Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets(
      'inline confirm uses one prompt and one button at ${viewport.$1}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport.$1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (workspace, transport) = (await tester.runAsync(
          () => fixture('owner'),
        ))!;
        addTearDown(workspace.dispose);
        final card = form({
          'placement': 'inline',
          'fields': [
            field('Choice', 'choice', 'Ready for staging?', {
              'required': true,
              'options': [option('yes', 'Deploy to staging')],
            }),
          ],
        });
        final tree = card['spec']! as Map<String, Object>;
        final nodes = tree['elements']! as Map<String, Object>;
        (nodes['root']! as Map<String, Object>)['children'] = [
          'q_choice',
          'actions',
        ];
        nodes.remove('description');
        nodes['q_choice'] = node('Field', {
          'label': {
            'key': 'actionCard.spec.field.question',
            'text': {'en': 'Question'},
          },
          'value': 'Ready for staging?',
        });
        await tester.pumpWidget(
          host(
            Theme(
              data: ThemeData(platform: viewport.$2),
              child: MessageActionCard(
                controller: workspace,
                message: message(metadata(card, type: 'question:ask')),
              ),
            ),
          ),
        );
        expect(
          find.textContaining('Ready for staging?', findRichText: true),
          findsOneWidget,
        );
        final confirm = find.widgetWithText(RaftButton, 'Deploy to staging');
        expect(confirm, findsOneWidget);
        await tester.tap(confirm);
        await tester.pump();
        expect(find.text('Submitted'), findsOneWidget);
        expect(find.text('·'), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Submitted'), findsNothing);
        expect(
          transport.calls.where((call) => call.path.endsWith('/execute')),
          isEmpty,
        );
      },
    );
  }

  testWidgets('an inline question keeps option help and focuses Other on tap', (
    tester,
  ) async {
    final (workspace, _) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(workspace.dispose);
    final card = form({
      'placement': 'inline',
      'fields': [
        field('Choice', 'choice', 'Which day?', {
          'required': true,
          'options': [
            {
              ...option('tue', 'Tuesday'),
              'description': copy('After morning QA'),
            },
            option('thu', 'Thursday'),
          ],
          'other': {'label': copy('Other…'), 'maxLength': 100},
        }),
      ],
    });
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(metadata(card, type: 'question:ask')),
        ),
      ),
    );
    expect(find.text('After morning QA'), findsOneWidget);
    await tester.tap(find.text('Other…'));
    await tester.pumpAndSettle();
    final input = tester.widget<EditableText>(find.byType(EditableText));
    expect(input.focusNode.hasFocus, isTrue);
    expect(find.text('Write your answer'), findsOneWidget);
    expect(find.text('Submitted'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an external runner is described as an agent on no Computer', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('owner'),
    ))!;
    addTearDown(workspace.dispose);
    workspace.server = RaftRecord({'id': 's1', 'role': 'owner', 'plan': 'pro'});
    transport.routes.addAll({
      'GET /agents': (_) => [
        {
          'id': 'agent',
          'name': 'Scout',
          'executionMode': 'external',
          'machineId': 'runner',
          'creatorId': 'alice',
          'creatorType': 'user',
        },
      ],
      'GET /servers/s1/machines': (_) => {
        'machines': [
          {'id': 'runner', 'name': 'External runner', 'isComputer': false},
        ],
      },
      'POST /actions/m1/event': (_) => {},
    });
    await tester.runAsync(
      () => Future.wait([
        workspace.entityDirectory.refresh(WorkspaceEntityKind.agents),
        workspace.entityDirectory.refresh(WorkspaceEntityKind.computers),
      ]),
    );
    final card = spec(action: {'kind': 'open', 'intent': 'migrate_agent'});
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(
            metadata(
              card,
              extra: {
                'action': {'type': 'agent:migrate', 'agentId': 'agent'},
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Approve change'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('there is nothing to bring over'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Migrating moves the workspace files'),
      findsNothing,
    );
    expect(
      transport.calls.where((call) => call.path.endsWith('/migrate')),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('action card permission scopes show recognized descriptions', (
    tester,
  ) async {
    final (workspace, _) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(workspace.dispose);
    final card = spec();
    final tree = card['spec']! as Map<String, Object>;
    final nodes = tree['elements']! as Map<String, Object>;
    nodes['description'] = node('ScopeList', {
      'scopes': ['openid', 'example:extension'],
    });
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(metadata(card)),
        ),
      ),
    );
    expect(find.text('Permissions (2)'), findsOneWidget);
    expect(find.textContaining('stable identity token'), findsOneWidget);
    expect(
      find.text('Raft has no description for this scope.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
