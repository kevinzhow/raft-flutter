import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web ComputerCommandGuide: with an install-and-setup command, mac/Linux
/// shows that one paste (no step labels, "Copy Computer CLI command");
/// otherwise the two steps.
Widget _guide({
  String platform = 'mac-linux',
  String? installAndSetup,
  (String, String)? commands = ('install-cmd', 'setup-cmd'),
}) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(
    body: SingleChildScrollView(
      child: RaftComputerCommandGuide(
        platform: platform,
        onPlatform: (_) {},
        commands: commands,
        installAndSetup: installAndSetup,
      ),
    ),
  ),
);

Finder _command(String command) => find.byWidgetPredicate(
  (w) => w is RaftCopyableCode && w.command == command,
);

void main() {
  testWidgets('one paste replaces the two steps', (tester) async {
    await tester.pumpWidget(_guide(installAndSetup: 'one-paste-cmd'));
    expect(_command('one-paste-cmd'), findsOneWidget);
    expect(_command('install-cmd'), findsNothing);
    expect(_command('setup-cmd'), findsNothing);
    expect(find.text('1. Install'), findsNothing);
    expect(find.text('2. Setup'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RaftCopyableCode && w.copyLabel == 'Copy Computer CLI command',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without it the two steps stay', (tester) async {
    await tester.pumpWidget(_guide());
    expect(_command('install-cmd'), findsOneWidget);
    expect(_command('setup-cmd'), findsOneWidget);
    expect(find.text('1. Install'), findsOneWidget);
    expect(find.text('2. Setup'), findsOneWidget);
  });

  testWidgets('Windows never uses the one paste', (tester) async {
    await tester.pumpWidget(
      _guide(platform: 'windows', installAndSetup: 'one-paste-cmd'),
    );
    expect(_command('one-paste-cmd'), findsNothing);
    expect(_command('install-cmd'), findsOneWidget);
  });
}
