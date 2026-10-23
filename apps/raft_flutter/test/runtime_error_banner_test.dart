import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';

import 'support/agent_panel_fixture.dart';

const _typedAuth = {
  'message': 'invalid api key',
  'errorClass': 'AuthError',
  'errorReason': 'auth_failed',
  'fingerprint': 'fp-1',
};

void main() {
  String? clipboard;
  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  const banner = ValueKey('runtime-error-banner');

  testWidgets('a healthy agent has no banner', (tester) async {
    await pumpAgentPanel(tester);
    expect(find.byKey(banner), findsNothing);
  });

  testWidgets('a known typed error shows its catalog message under the head', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: {...agentPanelAgent, 'lastRuntimeError': _typedAuth},
    );
    expect(find.byKey(banner), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(banner),
        matching: find.text('Runtime authentication failed.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unclassified error keeps its text', (tester) async {
    await pumpAgentPanel(
      tester,
      agent: {
        ...agentPanelAgent,
        'lastRuntimeError': {'message': 'disk full'},
      },
    );
    expect(
      find.descendant(
        of: find.byKey(banner),
        matching: find.textContaining('disk full'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Copy info copies the diagnostic text with the raw error', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: {...agentPanelAgent, 'lastRuntimeError': _typedAuth},
      liveActivity: {'activity': 'error', 'detail': 'invalid api key'},
    );
    await tester.tap(find.byKey(const ValueKey('runtime-error-copy')));
    await tester.pump();
    expect(
      clipboard,
      startsWith('Raft Diagnostic Info\nerrorMessage: invalid api key\n'),
    );
    expect(
      clipboard,
      contains('class=AuthError reason=auth_failed fingerprint=fp-1'),
    );
    // The button confirms with "Copied" for a moment, then goes back.
    expect(find.byTooltip('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byTooltip('Copy info'), findsOneWidget);
  });

  testWidgets('View logs jumps to the Activity tab and then goes away', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: {...agentPanelAgent, 'lastRuntimeError': _typedAuth},
    );
    expect(
      find.byKey(const ValueKey('runtime-error-view-logs')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('runtime-error-view-logs')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('runtime-error-view-logs')), findsNothing);
    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets(
    'without access to private surfaces: a generic line, no actions',
    (tester) async {
      await pumpAgentPanel(
        tester,
        agent: {...agentPanelAgent, 'lastRuntimeError': _typedAuth},
        canManage: false,
        canViewPrivate: false,
      );
      expect(
        find.descendant(
          of: find.byKey(banner),
          matching: find.text('Agent encountered an error'),
        ),
        findsOneWidget,
      );
      expect(find.text('Runtime authentication failed.'), findsNothing);
      expect(find.byKey(const ValueKey('runtime-error-copy')), findsNothing);
      expect(
        find.byKey(const ValueKey('runtime-error-view-logs')),
        findsNothing,
      );
    },
  );

  testWidgets('the Activity tab itself shows no View logs link', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: {...agentPanelAgent, 'lastRuntimeError': _typedAuth},
      tab: AgentDetailTab.activity,
    );
    expect(find.byKey(banner), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-error-copy')), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-error-view-logs')), findsNothing);
  });
}
