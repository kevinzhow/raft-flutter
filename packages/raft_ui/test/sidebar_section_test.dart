// Raft source geometry is covered
// by framework_navigation_contract_test and framework_sidebar_phone_contract_test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'noninteractive heading has no invented disclosure and custom emoji is separate',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: RaftSidebarSectionHeader(
                label: 'Workspace',
                expanded: true,
                onExpandedChanged: null,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(RaftControl), findsNothing);
      expect(find.byType(AnimatedRotation), findsNothing);
      expect(find.text('Workspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
