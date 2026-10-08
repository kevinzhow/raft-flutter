import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/sidebar_sort_menu.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final revoke in [false, true]) {
    testWidgets(
      revoke
          ? 'same controller role revocation removes open sort without selection'
          : 'anchored sort marks current mode and closes before mutation',
      (tester) async {
        final client = RaftClient(
          origin: 'https://fixture.invalid',
          sessionStore: MemorySessionStore(),
        )..user = RaftRecord({'id': 'alice'});
        final w = WorkspaceController(client)
          ..server = RaftRecord({'id': 's', 'role': 'owner'});
        final anchor = GlobalKey();
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(
              body: Builder(
                builder: (context) => Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      key: anchor,
                      width: 24,
                      height: 24,
                      child: TextButton(
                        onPressed: () async {
                          selected = await showSidebarSortMenu(
                            context,
                            w,
                            anchor,
                            'recent',
                          );
                        },
                        child: const Text('Sort'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Sort'));
        await tester.pumpAndSettle();
        final menu = find.byKey(const Key('sidebar-sort-popover'));
        expect(menu, findsOneWidget);
        expect(tester.getRect(menu).width, 136);
        expect(
          tester.getRect(menu).right,
          tester.getRect(find.byKey(anchor)).right,
        );
        final recent = tester.widget<RaftMenuItem>(
          find.byKey(const Key('sidebar-sort-recent')),
        );
        expect(recent.selected, isTrue);
        expect(recent.kind, RaftMenuKind.selectionPopover);
        if (revoke) {
          w.server = RaftRecord({'id': 's', 'role': 'member'});
          w.setSection('home');
        } else {
          await tester.tap(find.byKey(const Key('sidebar-sort-az')));
        }
        await tester.pumpAndSettle();
        expect(selected, revoke ? isNull : 'az');
        expect(menu, findsNothing);
        await tester.pumpWidget(const SizedBox());
        w.dispose();
      },
    );
  }
}
