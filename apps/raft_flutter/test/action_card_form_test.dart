import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_action_card.dart';

import 'action_card_spec_test.dart' show copy, message, metadata, spec;
import 'message_presentation_test.dart' show fixture, host;

Map<String, Object> field(
  String type,
  String name,
  String label, [
  Map<String, Object> props = const {},
]) => {'type': type, 'name': name, 'label': copy(label), ...props};

Map<String, Object> option(String value, String label) => {
  'value': value,
  'label': copy(label),
};

Map<String, Object> form(Map<String, Object> fields) => spec(
  action: {'kind': 'open_form', 'form': 'answer'},
  forms: {
    'answer': {
      'title': copy('Review the change'),
      'submitLabel': copy('Send answer'),
      ...fields,
    },
  },
);

void main() {
  testWidgets('a server field issue can be edited and resubmitted', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('owner'),
    ))!;
    addTearDown(workspace.dispose);
    final card = form({
      'fields': [field('TextInput', 'reason', 'Your reason')],
    });
    var attempts = 0;
    transport.routes['POST /actions/m1/execute'] = (request) {
      if (++attempts == 1) {
        throw DioException.badResponse(
          statusCode: 422,
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 422,
            data: {
              'error': 'Invalid form',
              'errorCode': 'FORM_INVALID',
              'issues': [
                {
                  'field': 'reason',
                  'code': 'conflict',
                  'message': copy('This reason is already in use.'),
                },
              ],
            },
          ),
        );
      }
      return {'messageId': 'm1', 'metadata': metadata(card, state: 'executed')};
    };
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(metadata(card, type: 'agent:approve_call')),
        ),
      ),
    );
    await tester.tap(find.text('Approve change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Old reason');
    await tester.tap(find.text('Send answer'));
    await tester.pumpAndSettle();
    expect(find.text('This reason is already in use.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'New reason');
    await tester.pump();
    expect(find.text('This reason is already in use.'), findsNothing);
    await tester.tap(find.text('Send answer'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('a lone choice stages the answer and flushes when hidden', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('owner'),
    ))!;
    addTearDown(workspace.dispose);
    final card = form({
      'placement': 'inline',
      'fields': [
        field('Choice', 'options', 'Choose a plan', {
          'required': true,
          'options': [option('one', 'Plan one'), option('two', 'Plan two')],
        }),
      ],
    });
    transport.routes['POST /actions/m1/execute'] = (_) => {
      'messageId': 'm1',
      'metadata': metadata(card, state: 'executed', type: 'question:ask'),
    };
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(metadata(card, type: 'question:ask')),
        ),
      ),
    );
    expect(find.text('Approve change'), findsNothing);
    await tester.tap(find.text('Plan one'));
    await tester.pump();
    expect(find.text('Undo'), findsOneWidget);
    expect(
      transport.calls.where((call) => call.path.endsWith('/execute')),
      isEmpty,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(
      transport.calls.where((call) => call.path.endsWith('/execute')),
      hasLength(1),
    );
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets(
    'a form changes its submit label with a Select and sends both pages',
    (tester) async {
      final (workspace, transport) = (await tester.runAsync(
        () => fixture('owner'),
      ))!;
      addTearDown(workspace.dispose);
      final card = form({
        'fields': [
          field('TextInput', 'reason', 'Your reason', {
            'maxLength': 80,
            'required': true,
          }),
          field('Select', 'decision', 'Decision', {
            'required': true,
            'options': [
              option('approve', 'Approve it'),
              option('deny', 'Deny it'),
            ],
          }),
        ],
        'steps': [
          {
            'title': copy('Explain'),
            'fields': ['reason'],
          },
          {
            'title': copy('Decide'),
            'fields': ['decision'],
          },
        ],
        'submitLabels': {
          'field': 'decision',
          'labels': {'deny': copy('Deny this call')},
        },
      });
      transport.routes['POST /actions/m1/execute'] = (_) => {
        'messageId': 'm1',
        'metadata': metadata(card, state: 'executed'),
      };
      await tester.pumpWidget(
        host(
          MessageActionCard(
            controller: workspace,
            message: message(metadata(card, type: 'agent:approve_call')),
          ),
        ),
      );
      await tester.tap(find.text('Approve change'));
      await tester.pumpAndSettle();
      expect(find.text('Explain'), findsOneWidget);
      expect(find.text('Decision'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Explain'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Wrong target');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Decide'), findsOneWidget);
      await tester.tap(find.text('Select...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deny it'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 550));
      await tester.tap(find.text('Deny this call'));
      await tester.pumpAndSettle();
      expect(
        transport.calls
            .singleWhere((call) => call.path.endsWith('/execute'))
            .data,
        {
          'expectedState': 'prepared',
          'expectedConfirmationVersion': 7,
          'form': {
            'id': 'answer',
            'values': {'reason': 'Wrong target', 'decision': 'deny'},
          },
        },
      );
      expect(find.text('Review the change'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    },
  );

  testWidgets('an inline choice can be undone before any request', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('owner'),
    ))!;
    addTearDown(workspace.dispose);
    final card = form({
      'placement': 'inline',
      'fields': [
        field('Choice', 'options', 'Choose a plan', {
          'required': true,
          'multiple': true,
          'options': [option('one', 'Plan one'), option('two', 'Plan two')],
        }),
      ],
    });
    transport.routes['POST /actions/m1/execute'] = (_) => {
      'messageId': 'm1',
      'metadata': metadata(card, type: 'question:ask', state: 'executed'),
    };
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(metadata(card, type: 'question:ask')),
        ),
      ),
    );
    expect(
      find.textContaining('Choose a plan', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Plan two'));
    await tester.pump();
    await tester.tap(find.text('Approve change'));
    await tester.pump();
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(seconds: 2));
    expect(
      transport.calls.where((call) => call.path.endsWith('/execute')),
      isEmpty,
    );
    await tester.tap(find.text('Approve change'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      transport.calls
          .singleWhere((call) => call.path.endsWith('/execute'))
          .data,
      {
        'expectedState': 'prepared',
        'expectedConfirmationVersion': 7,
        'form': {
          'id': 'answer',
          'values': {
            'options': {
              'selected': ['two'],
            },
          },
        },
      },
    );
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });
}
