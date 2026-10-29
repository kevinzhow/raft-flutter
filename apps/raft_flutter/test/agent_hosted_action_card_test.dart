// Web useActionCardDetail `agent:create`: an action card that suggests a cloud
// agent shows where it runs ("Runs on: Cloud agent, model {model}").
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_action_card.dart';

import 'message_presentation_test.dart' show fixture, host;

RaftMessage _card(Map<String, dynamic> action) => RaftMessage({
  'id': 'm1',
  'channelId': 'c1',
  'content': 'Action',
  'actionMetadata': {
    'kind': 'action-card',
    'sourceServerId': 's1',
    'state': 'prepared',
    'confirmationVersion': 7,
    'action': {'type': 'agent:create', 'name': 'helper', ...action},
  },
});

void main() {
  Future<void> show(WidgetTester t, Map<String, dynamic> action) async {
    final (w, _) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    await t.pumpWidget(
      host(MessageActionCard(controller: w, message: _card(action))),
    );
  }

  testWidgets('a cloud card with a model names it', (t) async {
    await show(t, {'hosting': 'antiproton', 'model': 'deepseek-flash'});
    expect(
      find.text(
        'Runs on: Cloud agent, model deepseek-flash',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('a cloud card without a model says Cloud agent', (t) async {
    await show(t, {'hosting': 'antiproton'});
    expect(
      find.text('Runs on: Cloud agent', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a card for a computer shows no hosting line', (t) async {
    await show(t, {'suggestedComputer': 'abcdef123456'});
    expect(find.textContaining('Runs on:', findRichText: true), findsNothing);
    expect(
      find.textContaining('Suggested computer:', findRichText: true),
      findsOneWidget,
    );
  });
}
