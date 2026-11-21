import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('the workspace drag origin stays visible at forty percent', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    final menu = RaftMenuController();
    addTearDown(menu.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Column(
            children: [
              RaftWorkspaceTopBar(
                workspace: RaftServerSwitcher(
                  controller: menu,
                  workspaceName: 'A',
                  label: 'Switch Server',
                  topBar: true,
                  rows: [
                    for (final id in ['a', 'b', 'c'])
                      RaftServerMenuRow(
                        id: id,
                        name: id.toUpperCase(),
                        slug: id,
                        current: id == 'a',
                        onSelected: () {},
                      ),
                  ],
                  actions: const [],
                  onReorder: (_, _) {},
                ),
                onSearch: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final avatar = find.byKey(const ValueKey('topbar-workspace-b'));
    final pointer = await tester.startGesture(
      tester.getCenter(avatar),
      kind: PointerDeviceKind.mouse,
    );
    try {
      await pointer.moveBy(const Offset(0, 7));
      await tester.pump();
      expect(
        find.ancestor(
          of: avatar,
          matching: find.byWidgetPredicate(
            (widget) => widget is Opacity && widget.opacity == .4,
          ),
        ),
        findsOneWidget,
      );
    } finally {
      await pointer.cancel();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
