import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget host(Widget child) => MaterialApp(
  theme: raftTheme(dark: false),
  home: Scaffold(
    body: Center(child: SizedBox(width: 360, child: child)),
  ),
);

void main() {
  testWidgets('public channel keeps its mark while members are working', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        RaftChannelHeader(
          name: 'general',
          publicPage: true,
          workingAgents: const [
            RaftWorkingAgent(
              id: 'worker',
              name: 'Worker',
              text: 'Editing',
              avatar: RaftAvatarContent(
                name: 'Worker',
                kind: RaftAvatarContentKind.agent,
                pixelKey: 'cat',
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(const ValueKey('public-channel-mark')), findsOneWidget);
    expect(find.byKey(const Key('channel-header-subtitle')), findsOneWidget);
    expect(find.textContaining('1 agent working'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('provider badge survives an active agent and subsequent idle', (
    t,
  ) async {
    final activity = ValueNotifier<String?>('Editing');
    addTearDown(activity.dispose);
    await t.pumpWidget(
      host(
        RaftNavItem(
          label: 'Worker',
          leading: const Icon(Icons.person),
          providerBadge: 'Slack',
          activityText: activity,
          onTap: () {},
        ),
      ),
    );
    expect(find.text('Slack'), findsOneWidget);
    expect(find.byKey(const Key('nav-item-activity')), findsOneWidget);
    activity.value = null;
    await t.pump();
    expect(find.text('Slack'), findsOneWidget);
    expect(find.byKey(const Key('nav-item-activity')), findsNothing);
    expect(t.takeException(), isNull);
  });
}
