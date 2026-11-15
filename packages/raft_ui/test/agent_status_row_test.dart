// Web AgentStatusBadge (v1.24.0): the status chip row and its quiet actions,
// and the runtime error banner's variants (AgentRuntimeErrorNotice).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget host(
  Widget child, {
  bool dark = false,
  double width = 360,
  bool touch = false,
}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: RaftInteractionScope(
    interaction: touch
        ? RaftInteraction.touchMode
        : RaftInteraction.pointerMode,
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    for (final tone in RaftAgentStatusTone.values) {
      testWidgets(
        'chip ${tone.name} ${dark ? 'dark' : 'light'} draws without error',
        (tester) async {
          await tester.pumpWidget(
            host(
              dark: dark,
              RaftAgentStatusRow(
                text: 'Sign-in needed for Codex CLI',
                tone: tone,
                light: RaftAgentStatusLight.error,
              ),
            ),
          );
          expect(find.text('Sign-in needed for Codex CLI'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Retry and Change model are links; Retry says Restarting while it runs',
    (tester) async {
      var retries = 0, models = 0;
      Widget row({required bool retrying}) => host(
        RaftAgentStatusRow(
          text: 'Error',
          tone: RaftAgentStatusTone.warning,
          light: RaftAgentStatusLight.error,
          onRetry: () => retries++,
          retrying: retrying,
          onChangeModel: () => models++,
        ),
      );
      await tester.pumpWidget(row(retrying: false));
      await tester.tap(find.byKey(const ValueKey('agent-status-retry')));
      await tester.tap(find.byKey(const ValueKey('agent-status-change-model')));
      expect((retries, models), (1, 1));
      await tester.pumpWidget(row(retrying: true));
      expect(find.text('Restarting…'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agent-status-retry')));
      expect(retries, 1);
    },
  );

  testWidgets('a chip with onOpenChip is a button, without it is not', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      host(
        RaftAgentStatusRow(
          text: 'Computer offline',
          tone: RaftAgentStatusTone.muted,
          light: RaftAgentStatusLight.offline,
          onOpenChip: () => opens++,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('agent-status-chip')));
    expect(opens, 1);
    await tester.pumpWidget(
      host(
        const RaftAgentStatusRow(
          text: 'Computer offline',
          tone: RaftAgentStatusTone.muted,
          light: RaftAgentStatusLight.offline,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a wrapping chip holds a sentence on a phone width without overflow',
    (tester) async {
      const sentence =
          'Computer access revoked: move the agent to another computer (re-attaching adds a new one)';
      await tester.pumpWidget(
        host(
          width: 320,
          touch: true,
          const RaftAgentStatusRow(
            text: sentence,
            tone: RaftAgentStatusTone.warning,
            light: RaftAgentStatusLight.error,
            wrap: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // More than one line: taller than the one-line 22px chip.
      expect(
        tester.getSize(find.byKey(const ValueKey('agent-status-chip'))).height,
        greaterThan(22),
      );
    },
  );

  testWidgets('the detail hint truncates beside the chip', (tester) async {
    await tester.pumpWidget(
      host(
        width: 300,
        RaftAgentStatusRow(
          text: 'Messages delivered, runtime not responding',
          tone: RaftAgentStatusTone.success,
          light: RaftAgentStatusLight.online,
          detail: '3 deliveries written since the runtime last responded (episode 2, last via stdin_idle_delivery)',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('agent-status-detail')), findsOneWidget);
  });

  group('RaftRuntimeErrorBanner variants', () {
    testWidgets('headline with a two-line detail and the actions', (
      tester,
    ) async {
      var copies = 0, logs = 0;
      await tester.pumpWidget(
        host(
          width: 480,
          RaftRuntimeErrorBanner(
            message: 'The model provider usage limit has been reached.',
            detail: '429 Too Many Requests ' * 12,
            onCopy: () => copies++,
            onViewLogs: () => logs++,
          ),
        ),
      );
      final detail = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(const ValueKey('runtime-error-detail')),
          matching: find.byType(RichText),
        ),
      );
      expect(detail.maxLines, 2);
      await tester.tap(find.byKey(const ValueKey('runtime-error-copy')));
      await tester.tap(find.byKey(const ValueKey('runtime-error-view-logs')));
      expect((copies, logs), (1, 1));
    });

    testWidgets('billing: title, body, one ghost action', (tester) async {
      var settings = 0;
      await tester.pumpWidget(
        host(
          width: 480,
          RaftRuntimeErrorBanner(
            message: 'Model service balance too low',
            billingBody: "Alpha can't reply right now.",
            onOpenModelSettings: () => settings++,
            onCopy: () {},
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('agent-billing-banner')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-billing-banner-model-settings')),
      );
      expect(settings, 1);
      expect(
        find.byKey(const ValueKey('runtime-error-view-logs')),
        findsNothing,
      );
    });

    testWidgets('billing without an action shows who can fix it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          width: 480,
          const RaftRuntimeErrorBanner(
            message: 'Model service balance too low',
            billingBody: "Alpha can't reply right now.",
            billingNote: 'Ask a server admin to fix this.',
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('agent-billing-banner-ask-admin')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-billing-banner-model-settings')),
        findsNothing,
      );
    });
  });
}
