import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _card({required bool recovering, bool online = false}) => Center(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: RaftSetupComputerCard(
      computerName: "Wenyi's MacBook Pro",
      computerOnline: online,
      waiting: false,
      runtimeReady: false,
      runtimeNames: const [],
      runtimeAnswered: online,
      recommendedRuntimes: const [
        RaftSetupRuntime(
          id: 'claude',
          displayName: 'Claude Code',
          abbreviation: 'CC',
          detected: false,
          recommended: true,
        ),
      ],
      supportedRuntimes: const [],
      offlineComputers: const [
        RaftSetupOfflineComputer("Wenyi's MacBook Pro", lastSeen: '3 days ago'),
      ],
      recovering: recovering,
      legacyDaemon: false,
      guidePlatform: 'mac-linux',
      onGuidePlatform: (_) {},
      guideCommands: (
        'curl -fsSL https://cdn.raft.build/install.sh | sh',
        'raft-computer setup /launch',
      ),
      serverSlug: 'launch',
      canReset: true,
      loading: false,
    ),
  ),
);

Widget _survey() {
  final other = TextEditingController();
  addTearDown(other.dispose);
  return _surveyCard(other);
}

Widget _surveyCard(TextEditingController other) => Center(
  child: SingleChildScrollView(
    child: RaftSetupSurveyCard(
      roles: const {'design': 'Designer', 'founder': 'Founder'},
      sources: const {'search': 'Search', 'other': 'Other'},
      role: 'design',
      source: 'other',
      otherController: other,
      saving: false,
    ),
  ),
);

Widget _handoff() => Center(
  child: SingleChildScrollView(child: RaftSetupHandoffCard(starting: false)),
);

void main() {
  // The gate's card in a host narrower than the viewport (a pane, the test
  // surface of entity_directory_surfaces_test: 800x600 viewport, 320 host).
  for (final (name, builder) in <(String, Widget Function())>[
    ('computer connect', () => _card(recovering: false)),
    ('computer recovery', () => _card(recovering: true, online: false)),
    ('survey', _survey),
    ('handoff', _handoff),
  ]) {
    testWidgets('setup $name in a 320px host of an 800x600 viewport '
        'does not overflow', (t) async {
      t.view.physicalSize = const Size(800, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(body: SizedBox(width: 320, child: builder())),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
    });
  }

  for (final (name, size, dpr) in const [
    ('800x600', Size(800, 600), 1.0),
    ('390x844', Size(390, 844), 3.0),
    ('700x500', Size(700, 500), 1.0),
  ]) {
    for (final recovering in [false, true]) {
      testWidgets('setup computer step $name recovering=$recovering '
          'does not overflow', (t) async {
        t.view.physicalSize = size * dpr;
        t.view.devicePixelRatio = dpr;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: _card(recovering: recovering, online: !recovering),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 100));
        expect(t.takeException(), isNull);
      });
    }
  }
}
