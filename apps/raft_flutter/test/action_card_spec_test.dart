import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture, host;

Map<String, Object> copy(String text) => {
  'key': 'actionCard.fixture',
  'text': {'en': text},
};

Map<String, Object> node(String type, Map<String, Object> props) => {
  'type': type,
  'props': props,
};

Map<String, Object> tree({
  Map<String, Object> action = const {'kind': 'execute'},
}) => {
  'root': 'root',
  'elements': {
    'root': {
      ...node('Stack', {'direction': 'column'}),
      'children': ['description', 'actions'],
    },
    'description': node('Text', {'text': 'The pending change'}),
    'actions': {
      ...node('Stack', {'direction': 'row', 'role': 'actions'}),
      'children': ['submit'],
    },
    'submit': node('Button', {
      'label': copy('Approve change'),
      'action': action,
    }),
  },
};

Map<String, Object> spec({
  Map<String, Object>? action,
  Map<String, Object>? forms,
}) => {
  'catalog': 'action-card.v1',
  'title': copy('Approval requested'),
  'spec': tree(action: action ?? const {'kind': 'execute'}),
  'forms': ?forms,
  'result': {
    'root': 'result',
    'elements': {
      'result': node('Text', {'text': 'The change was approved'}),
    },
  },
};

Map<String, Object> metadata(
  Map<String, Object> card, {
  String state = 'prepared',
  String type = 'server:promote_member',
  Map<String, Object> extra = const {},
}) => {
  'kind': 'action-card',
  'sourceServerId': 's1',
  'state': state,
  'confirmationVersion': 7,
  'action': {'type': type},
  'presentation': {'card': card},
  ...extra,
};

RaftMessage message(Map<String, Object> data) => RaftMessage({
  'id': 'm1',
  'channelId': 'c1',
  'content': 'Action',
  'actionMetadata': data,
});

void main() {
  testWidgets('approval executes once and the result can be reopened', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('owner'),
    ))!;
    addTearDown(workspace.dispose);
    final card = spec();
    final completed = metadata(
      card,
      state: 'executed',
      extra: {'executedByUserName': 'Alice'},
    );
    transport.routes['POST /actions/m1/execute'] = (_) => {
      'messageId': 'm1',
      'metadata': completed,
    };
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(metadata(card)),
        ),
      ),
    );
    expect(find.text('Approval requested'), findsOneWidget);
    expect(find.text('The pending change'), findsOneWidget);
    await tester.tap(find.text('Approve change'));
    await tester.pumpAndSettle();
    final call = transport.calls.singleWhere(
      (request) => request.path == '/actions/m1/execute',
    );
    expect(call.data, {
      'expectedState': 'prepared',
      'expectedConfirmationVersion': 7,
    });
    expect(find.text('Approve change'), findsNothing);
    expect(find.text('The pending change'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('action-card-toggle-details')));
    await tester.pumpAndSettle();
    expect(find.text('The change was approved'), findsWidgets);
    expect(find.text('The pending change'), findsOneWidget);
    expect(find.text('Approve change'), findsNothing);
  });

  testWidgets('an expired card can show its details without actions', (
    tester,
  ) async {
    final (workspace, _) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(
            metadata(spec(), extra: {'expiresAt': '2000-01-01T00:00:00Z'}),
          ),
        ),
      ),
    );
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Approve change'), findsNothing);
    expect(find.text('The pending change'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('action-card-toggle-details')));
    await tester.pumpAndSettle();
    expect(find.text('The pending change'), findsOneWidget);
    expect(find.text('Approve change'), findsNothing);
  });

  testWidgets('an unknown execute key offers browser fallback', (tester) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('owner'),
    ))!;
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      host(
        MessageActionCard(
          controller: workspace,
          message: message(
            metadata(
              spec(action: {'kind': 'execute', 'newVerification': true}),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Open in browser'), findsOneWidget);
    expect(find.text('Approve change'), findsNothing);
    expect(
      transport.calls.where((request) => request.path.startsWith('/actions/')),
      isEmpty,
    );
  });

  for (final (size, platform) in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('details work at $size on $platform', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (workspace, _) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(workspace.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(
            body: MessageActionCard(
              controller: workspace,
              message: message(metadata(spec(), state: 'expired')),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('action-card-toggle-details')),
      );
      await tester.pumpAndSettle();
      expect(find.text('The pending change'), findsOneWidget);
      expect(find.text('Approve change'), findsNothing);
    });
  }
}
