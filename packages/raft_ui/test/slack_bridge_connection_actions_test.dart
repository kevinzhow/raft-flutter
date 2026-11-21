import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('Slack identifies the connected workspace before reauthorizing', (
    tester,
  ) async {
    var reauthorizations = 0;
    const notice =
        'This server is connected to Fixture Slack. Select the same workspace when updating Slack authorization.';
    const reauthorize = ValueKey('slack-bridge-reauthorize');
    const disconnect = ValueKey('slack-bridge-disconnect');

    Future<void> mount({required bool canReauthorize}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RaftSlackWizardView(
                stage: RaftSlackStage.health,
                workspaceName: 'Fixture Slack',
                canManage: canReauthorize,
                canDisconnect: canReauthorize,
                busy: false,
                onReauthorize: canReauthorize ? () => reauthorizations++ : null,
              ),
            ),
          ),
        ),
      );
    }

    await mount(canReauthorize: true);
    final copy = find.text(notice);
    final action = find.byKey(reauthorize);
    expect(copy, findsOneWidget);
    expect(
      tester.getBottomLeft(copy).dy,
      lessThan(tester.getTopLeft(action).dy),
    );
    expect(
      tester.widget<RaftSettingsRecipeButton>(action).variant,
      RaftButtonRecipeVariant.outline,
    );
    expect(
      tester.widget<RaftSettingsRecipeButton>(find.byKey(disconnect)).variant,
      RaftButtonRecipeVariant.warning,
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    expect(reauthorizations, 1);

    await mount(canReauthorize: false);
    expect(copy, findsNothing);
    expect(action, findsNothing);
  });
}
