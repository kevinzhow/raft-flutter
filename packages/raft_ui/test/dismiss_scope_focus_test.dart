import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// A dismiss scope takes the initial focus when it mounts, unless its route is
// already covered: a shell that is rebuilt behind another route (the window
// crossing the phone / desktop breakpoint behind the expanded composer editor)
// must not pull the focus out of the route in front of it.

Widget _home(ValueNotifier<bool> shell) => MaterialApp(
  home: Scaffold(
    body: ValueListenableBuilder<bool>(
      valueListenable: shell,
      builder: (context, mounted, _) => mounted
          ? const RaftDismissScope(child: SizedBox(key: Key('shell')))
          : const SizedBox(),
    ),
  ),
);

void main() {
  testWidgets('takes the focus when its route is the top one', (tester) async {
    final shell = ValueNotifier(true);
    addTearDown(shell.dispose);
    await tester.pumpWidget(_home(shell));
    await tester.pump();
    final primary = FocusManager.instance.primaryFocus;
    expect(primary, isA<FocusScopeNode>());
    expect(primary!.debugLabel, 'RaftDismissScope');
  });

  testWidgets('mounted under a covered route, leaves the focus alone', (
    tester,
  ) async {
    final shell = ValueNotifier(false);
    final field = FocusNode();
    addTearDown(shell.dispose);
    addTearDown(field.dispose);
    await tester.pumpWidget(_home(shell));
    unawaited(
      Navigator.of(tester.element(find.byType(Scaffold))).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: TextField(focusNode: field)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    field.requestFocus();
    await tester.pump();
    expect(field.hasPrimaryFocus, isTrue);

    // The page behind mounts a dismiss scope, as a rebuilt shell would.
    shell.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell'), skipOffstage: false), findsOneWidget);
    expect(field.hasPrimaryFocus, isTrue, reason: 'not stolen');
  });
}
