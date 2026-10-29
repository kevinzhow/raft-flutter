import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_filters.dart';
import 'package:raft_flutter/features/sender_avatar_projection.dart';
import 'package:raft_flutter/features/task_selection_filter.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final combobox in [false, true]) {
    testWidgets(
      combobox
          ? 'combobox ignores Task identity-only metadata'
          : 'frozen picker retains its original caption/avatar branch',
      (tester) async {
        MenuController? menu;
        final toggles = <String>[];
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: combobox
                  ? raftTheme()
                  : raftTheme(pack: packForThemeId(elegantThemePackId)),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: TaskSelectionFilter(
                    field: combobox ? 'Channel' : 'Assignee',
                    combobox: combobox,
                    options: const {'user:self': 'Assigned to Me'},
                    selection: const {},
                    selfIdentity: const ResourceSender(
                      'self',
                      'user',
                      'Viewer',
                    ),
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
          if (combobox) {
            expect(find.byType(RaftComboboxPanel), findsOneWidget);
            await tester.tap(find.text('Assigned to Me'));
            await tester.pumpAndSettle();
            expect(toggles, ['user:self']);
          } else {
            final row = tester.widget<RaftMenuItem>(
              find.byKey(const ValueKey('task-filter-Assignee-user:self')),
            );
            expect(row.italic, isFalse);
            expect(row.leading, isA<RaftSelectionPopoverAvatarSlot>());
            expect(
              (row.leading as RaftSelectionPopoverAvatarSlot).name,
              'Assigned to Me',
            );
          }
        } finally {
          menu?.close();
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );
  }
}
