import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final enabled in [true, false]) {
    testWidgets('billing input isolates its text field role ($enabled)', (
      t,
    ) async {
      t.view.physicalSize = const Size(1200, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final handle = t.ensureSemantics();
      final seats = TextEditingController(text: '12');
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                RaftPlanBillingSection(
                  planName: 'Pro',
                  planDescription: 'Current plan description',
                  included: const [
                    'Everything in Free',
                    'Unlimited history',
                    'Higher limits',
                    'Joint channels',
                    'More features',
                  ],
                  compare: RaftBillingAction(
                    label: 'Compare plans',
                    onPressed: () {},
                  ),
                  manage: RaftBillingManagePlan(
                    title: 'Manage seats',
                    checkout: false,
                    prompt: 'Choose seats',
                    seatLabel: 'Seats to buy',
                    seatController: seats,
                    seatEnabled: enabled,
                    help: 'Seats help',
                    summaryTitle: 'Summary',
                    summaryRows: const [],
                    interval: const RaftBillingInterval(
                      title: 'How often to bill?',
                      annual: true,
                      monthlyLabel: 'Monthly',
                      yearlyLabel: 'Yearly',
                      saveLabel: 'SAVE 12%',
                      label: 'Billing interval',
                    ),
                    actions: const [
                      RaftBillingAction(
                        label: 'Upgrade to Pro',
                        tooltip: 'Only owners can change billing',
                      ),
                    ],
                  ),
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
      final plan = nodes.where(
        (node) =>
            node.getSemanticsData().label.contains('Current plan description'),
      );
      expect(plan, isNotEmpty);
      for (final node in plan) {
        expect(
          node.getSemanticsData().flagsCollection.isTextField,
          isFalse,
          reason:
              'A sibling billing field must not turn the plan card into a text field.',
        );
      }
      expect(
        nodes.any(
          (node) =>
              node.getSemanticsData().label == 'Seats to buy' &&
              node.getSemanticsData().flagsCollection.isTextField,
        ),
        isTrue,
      );
      expect(find.bySemanticsLabel('Compare plans'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      handle.dispose();
      seats.dispose();
    });
  }
}
