import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('Find in a task names the task in the input', (tester) async {
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftThreadSearchBar(
            task: true,
            controller: input,
            focusNode: focus,
            countLabel: '',
            canStep: false,
            onChanged: (_) {},
            onStep: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );
    expect(find.text('Search this task'), findsOneWidget);
  });
}
