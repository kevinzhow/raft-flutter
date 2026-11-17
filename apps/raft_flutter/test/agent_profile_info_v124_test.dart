import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart' show loadParityFonts;
import 'support/agent_panel_fixture.dart';

/// The profile Info and Runtime config lists and the header Direct Message
/// button as Web v1.24 draws them: `features/agent/InfoRow.tsx` (a raft-ui
/// `DescriptionList direction="horizontal"` row), `AgentProfileInfo.tsx:640-790`
/// (Info) and `:815-880` (Runtime config), `AgentProfileOverflowMenu.tsx`
/// (Direct Message is its own header button at every width).
void main() {
  setUpAll(loadParityFonts);

  TextStyle styleOf(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).text.style!;

  Future<RaftTokens> hostList(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    late RaftTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              tokens = RaftTokens.of(context);
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 390,
                  child: RaftInfoList(
                    children: [
                      const RaftInfoRow(label: 'Role', child: Text('Member')),
                      const RaftInfoRow(
                        label: 'Computer version',
                        child: Text('v0.0.48'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tokens;
  }

  group('RaftInfoList', () {
    testWidgets('Raft look: one term column as wide as the widest term', (
      tester,
    ) async {
      final t = await hostList(tester);
      final role = styleOf(tester, 'Role');
      expect(role.fontWeight, FontWeight.w500);
      expect(role.color, t.ui.foregroundHint);
      // Both values start at the same x: the widest term plus the 16px gap.
      final longTerm = tester.getSize(find.text('Computer version')).width;
      final x = tester.getTopLeft(find.text('Member')).dx;
      expect(tester.getTopLeft(find.text('v0.0.48')).dx, x);
      expect(x, closeTo(longTerm + 16, 1));
      expect(styleOf(tester, 'Member').color, t.ui.foreground);
    });
  });

  group('profile Info rows', () {
    testWidgets('role is plain text, the Computer status is Online with a '
        'pixel, the version row is Computer version', (tester) async {
      await pumpAgentPanel(
        tester,
        agent: {...agentPanelAgent, 'serverRole': 'member'},
        machines: const [
          {
            'id': 'm1',
            'name': 'Studio Mac',
            'status': 'online',
            'isComputer': false,
            'daemonVersion': '0.65.0',
          },
        ],
      );
      await tester.ensureVisible(find.text('Computer status'));
      // Web AgentProfileInfo.tsx:658: the role is a plain span, no badge.
      expect(
        find.descendant(
          of: find.byType(RaftInfoRow),
          matching: find.byType(RaftBadge),
        ),
        findsNothing,
      );
      expect(find.text('Member'), findsOneWidget);
      // :718-726: a Status pixel and "Online" (not "Connected").
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
      expect(find.byType(RaftStatus), findsWidgets);
      // :728: "Computer version", the version only, for a legacy daemon too.
      expect(find.text('Computer version'), findsOneWidget);
      expect(find.text('v0.65.0'), findsOneWidget);
      expect(find.textContaining('legacy'), findsNothing);
      // :730 / :737 / :693: Computer and Created values are in the mono face.
      final t = RaftTokens.of(tester.element(find.text('Computer status')));
      expect(styleOf(tester, 'v0.65.0').fontFamily, t.monoFont);
      expect(styleOf(tester, 'Studio Mac').fontFamily, t.monoFont);
    });

    testWidgets('an offline Computer reads Offline and a dash', (tester) async {
      await pumpAgentPanel(
        tester,
        machines: const [
          {
            'id': 'm1',
            'name': 'Studio Mac',
            'status': 'offline',
            'isComputer': true,
            'computerVersion': '0.0.48',
          },
        ],
      );
      await tester.ensureVisible(find.text('Computer status'));
      expect(find.text('Offline'), findsWidgets);
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('header Direct Message', () {
    for (final (name, size, platform) in [
      ('fold folded', const Size(856, 944), TargetPlatform.android),
      ('fold unfolded', const Size(944, 856), TargetPlatform.android),
      ('narrow desktop', const Size(390, 844), TargetPlatform.linux),
    ]) {
      testWidgets('is its own button beside the overflow, $name', (
        tester,
      ) async {
        var messaged = 0;
        await pumpAgentPanel(
          tester,
          size: size,
          platform: platform,
          actions: AgentDetailActions(onMessage: () => messaged++),
        );
        final button = find.byKey(const Key('agent-profile-message'));
        expect(button, findsOneWidget);
        await tester.tap(button);
        await tester.pump();
        expect(messaged, 1);
        // AgentProfileOverflowMenu.tsx:225: no Direct message item in the menu.
        final overflow = find.byKey(
          const Key('agent-profile-overflow-trigger'),
        );
        if (overflow.evaluate().isNotEmpty) {
          await tester.tap(overflow);
          await tester.pumpAndSettle();
          expect(find.text('Direct message'), findsNothing);
        }
      });
    }
  });
}
