import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/external_agent_fixture.dart';

void main() {
  for (final (size, platform) in const [
    (Size(390, 844), TargetPlatform.android),
    (Size(856, 944), TargetPlatform.android),
    (Size(944, 856), TargetPlatform.android),
    (Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets(
      'connected external setup uses profile insets on $size $platform',
      (tester) async {
        final client = ExternalClient()..status = {'setupState': 'connected'};
        await pumpExternal(
          tester,
          client: client,
          size: size,
          platform: platform,
        );

        final description = tester.getTopLeft(find.text('Description')).dx;
        final status = tester.getRect(key('external-agent-status-offline'));
        final credentials = tester.getRect(key('external-agent-credentials'));
        expect(tester.getTopLeft(find.text('External setup')).dx, description);
        expect(status.left, description);
        expect(credentials.left, description);
        expect(status.right, credentials.right);
        expect(status.right, lessThan(size.width));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('connected phone profile shows a 96 dp collapsed prompt', (
    tester,
  ) async {
    final client = ExternalClient()..status = {'setupState': 'connected'};
    await pumpExternal(
      tester,
      client: client,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );

    await tester.tap(key('external-agent-how-it-connects'));
    await tester.pumpAndSettle();

    final prompt = key('external-agent-prompt');
    final text = find.textContaining('raft agent login');
    final frame = find.descendant(
      of: prompt,
      matching: find.ancestor(
        of: text,
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration is BoxDecoration,
        ),
      ),
    );
    final toggle = key('external-agent-prompt-toggle');
    expect(tester.getSize(frame).height, 96);
    expect(
      tester.getRect(text).bottom,
      lessThanOrEqualTo(tester.getRect(frame).bottom - 9),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, greaterThan(96));

    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 96);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Chinese profiles label the credential section', (tester) async {
    await pumpExternal(tester, locale: const Locale('zh'));

    expect(find.text('凭据'), findsOneWidget);
    expect(find.text('Credentials'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final machineId in [null, '']) {
    testWidgets('unassigned external agent ($machineId) skips skills', (
      tester,
    ) async {
      final agent = {...externalAgentRow, 'machineId': machineId};
      final client = ExternalClient(row: agent)..failSkills = true;
      await pumpExternal(tester, agent: agent, client: client);

      expect(client.count('GET /agents/ext-1/skills'), 0);
      expect(find.text('Failed to load skills'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'an external agent with a Computer can retry a failed skills read',
    (tester) async {
      final agent = {...externalAgentRow, 'machineId': 'computer-1'};
      final client = ExternalClient(row: agent)..failSkills = true;
      await pumpExternal(tester, agent: agent, client: client);

      expect(find.text('Failed to load skills'), findsOneWidget);
      client.failSkills = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(client.count('GET /agents/ext-1/skills'), 2);
      expect(find.text('Failed to load skills'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
