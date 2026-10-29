import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  // The selected mode is local state; a permission change while the dialog is
  // open removes the Full Reset option. build() looked the mode up with
  // firstWhere and no orElse, so it threw a StateError every frame.
  testWidgets('losing the selected reset option falls back to restart', (
    t,
  ) async {
    Widget app({required bool canFullReset}) => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RaftResetAgentDialog(
            agentName: 'Cindy',
            canFullReset: canFullReset,
            onConfirm: (mode) async {},
          ),
        ),
      ),
    );
    await t.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(app(canFullReset: true));
    await t.tap(find.byKey(const ValueKey('agent-reset-option-full')));
    await t.pump();
    expect(t.takeException(), isNull);

    await t.pumpWidget(app(canFullReset: false));
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('agent-reset-option-full')), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-reset-option-restart')),
      findsOneWidget,
    );
  });
}
