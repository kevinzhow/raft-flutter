import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_filters.dart';
import 'package:raft_flutter/features/sender_avatar_projection.dart';
import 'package:raft_flutter/features/task_selection_filter.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('combobox ignores Task identity-only metadata', (tester) async {
    MenuController? menu;
    final toggles = <String>[];
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TaskSelectionFilter(
                field: 'Channel',
                combobox: true,
                options: const {'user:self': 'Assigned to Me'},
                selection: const {},
                selfIdentity: const ResourceSender('self', 'user', 'Viewer'),
                identityAvatars: const {
                  'user:self': SenderAvatarProjection(
                    identity: 'user:self',
                    kind: 'human',
                    uploadedUrl: 'https://task-fixture.invalid/api/avatars/users/abcd.webp',
                  ),
                },
                valid: () => true,
                onToggle: toggles.add,
                onClear: () {},
                onController: (value, live) => menu = live ? value : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      menu!.open();
      await tester.pumpAndSettle();
      expect(find.byType(RaftSelectionPopover), findsNothing);
      expect(find.byType(RaftAvatarContent), findsNothing);
      expect(find.byType(RaftComboboxPanel), findsOneWidget);
      await tester.tap(find.text('Assigned to Me'));
      await tester.pumpAndSettle();
      expect(toggles, ['user:self']);
    } finally {
      menu?.close();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
