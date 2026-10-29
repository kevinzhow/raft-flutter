import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('feedback editor keeps its field role out of sibling copy', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final controller = TextEditingController();
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ListView(
            children: [
              Column(
                children: [
                  const Text('Share feedback about Raft'),
                  RaftFeedbackComposer(
                    controller: controller,
                    label: 'Feedback message',
                    actions: const [],
                    newFeedback: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final nodes = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(
      t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
    );
    final headings = nodes.where(
      (n) => n.getSemanticsData().label.contains('Share feedback about Raft'),
    );
    expect(headings, isNotEmpty);
    for (final node in headings) {
      expect(node.getSemanticsData().flagsCollection.isTextField, isFalse);
    }
    expect(
      nodes.any(
        (n) =>
            n.getSemanticsData().label == 'Feedback message' &&
            n.getSemanticsData().flagsCollection.isTextField,
      ),
      isTrue,
    );
    await t.pumpWidget(const SizedBox());
    handle.dispose();
    controller.dispose();
  });
}
