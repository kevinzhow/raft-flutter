import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// A combobox whose list loads after the form opened rewrites its text to the
/// chosen name. That is the app's doing, not the member's: it must not rebuild
/// the unsaved-changes guard while the tree builds, nor count as an edit.
void main() {
  testWidgets('the label arriving with the list is not an unsaved change', (
    tester,
  ) async {
    Widget form(List<RaftComboboxItem> items) => MaterialApp(
      theme: raftTheme(RaftFamily.brutal),
      home: Scaffold(
        body: RaftUnsavedGuard(
          child: RaftAgentCombobox(
            label: 'Model',
            items: items,
            value: 'gpt-6',
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(form(const []));
    await tester.pumpAndSettle();
    expect(find.text('gpt-6'), findsOneWidget);
    await tester.pumpWidget(
      form(const [RaftComboboxItem('gpt-6', 'GPT 6 Sol')]),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('GPT 6 Sol'), findsOneWidget);
    final pop = tester.widget<PopScope>(
      find.byWidgetPredicate((w) => w is PopScope).first,
    );
    expect(pop.canPop, isTrue);
  });
}
