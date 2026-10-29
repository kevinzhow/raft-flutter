import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web ComputerCommandGuide / AddMachineDialog v1.21.23: the connect-only
/// command behind "Already have Raft Computer on this machine?", and the
/// still-waiting hint after 45 seconds.
Widget _guide({String platform = 'mac-linux', String? installAndSetup}) =>
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RaftComputerCommandGuide(
            platform: platform,
            onPlatform: (_) {},
            commands: ('install-cmd', 'setup-cmd'),
            installAndSetup: installAndSetup,
          ),
        ),
      ),
    );

Finder _command(String command) => find.byWidgetPredicate(
  (w) => w is RaftCopyableCode && w.command == command,
);

final _toggle = find.byKey(
  const ValueKey('computer-command-already-installed'),
);
final _connectOnly = find.byKey(
  const ValueKey('computer-command-connect-only'),
);

void main() {
  group('already-installed disclosure', () {
    testWidgets('offered under the one paste, closed until asked', (t) async {
      await t.pumpWidget(_guide(installAndSetup: 'one-paste-cmd'));
      expect(_toggle, findsOneWidget);
      expect(
        find.text('Already have Raft Computer on this machine?'),
        findsOneWidget,
      );
      expect(_connectOnly, findsNothing);
      expect(_command('setup-cmd'), findsNothing);
    });

    testWidgets('opens to the setup command alone and closes again', (t) async {
      await t.pumpWidget(_guide(installAndSetup: 'one-paste-cmd'));
      await t.tap(_toggle);
      await t.pump();
      expect(_connectOnly, findsOneWidget);
      expect(
        find.text(
          'Skip the install and only connect it to this server. If raft-computer is not found, run it as ~/.local/bin/raft-computer.',
        ),
        findsOneWidget,
      );
      expect(_command('setup-cmd'), findsOneWidget);
      expect(_command('install-cmd'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RaftCopyableCode && w.copyLabel == 'Copy 2. setup command',
        ),
        findsOneWidget,
      );
      await t.tap(_toggle);
      await t.pump();
      expect(_connectOnly, findsNothing);
    });

    testWidgets('not offered without the one paste or on Windows', (t) async {
      await t.pumpWidget(_guide());
      expect(_toggle, findsNothing);
      await t.pumpWidget(
        _guide(platform: 'windows', installAndSetup: 'one-paste-cmd'),
      );
      expect(_toggle, findsNothing);
    });
  });

  group('still-waiting hint', () {
    Future<void> openWaiting(WidgetTester t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftAddComputerDialog(
              commandsFor: (_) => ('install-cmd', 'setup-cmd'),
              installAndSetupFor: (_) => 'one-paste-cmd',
              register: () async {},
              cancel: () async {},
              done: (_) async {},
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('add-computer-next')));
      await t.pump();
      await t.pump();
    }

    final hint = find.byKey(const ValueKey('add-computer-still-waiting'));

    testWidgets('appears after 45 seconds of waiting, not before', (t) async {
      await openWaiting(t);
      expect(
        find.byKey(const ValueKey('add-computer-waiting')),
        findsOneWidget,
      );
      await t.pump(
        raftAddComputerWaitingHintDelay - const Duration(seconds: 1),
      );
      expect(hint, findsNothing);
      await t.pump(const Duration(seconds: 1));
      expect(hint, findsOneWidget);
      expect(
        find.textContaining('Still waiting? Check the terminal'),
        findsOneWidget,
      );
      // The hint names the control it points at.
      expect(_toggle, findsOneWidget);
    });

    testWidgets('leaving the dialog cancels the timer', (t) async {
      await openWaiting(t);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(raftAddComputerWaitingHintDelay * 2);
    });
  });
}
