import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'native inset and empty drag region isolate controls/$direction',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(1280, 800);
        addTearDown(t.view.reset);
        var drags = 0, doubles = 0, searches = 0, workspaces = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: RaftWorkspaceTopBar(
                    leadingInset: 88,
                    onDragStart: () => drags++,
                    onDoubleTap: () => doubles++,
                    onSearch: () => searches++,
                    workspace: Align(
                      alignment: Alignment.centerLeft,
                      child: RaftIconButton(
                        key: const Key('workspace'),
                        glyph: RaftGlyph.globe,
                        tooltip: 'Workspace',
                        onPressed: () => workspaces++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final search = find.byKey(const Key('topbar-search'));
        expect(t.getRect(search).center.dx, 640);
        expect(t.getRect(find.byKey(const Key('workspace'))).left, 96);
        await t.tap(search);
        await t.tap(find.byKey(const Key('workspace')));
        expect(searches, 1);
        expect(workspaces, 1);
        expect(drags, 0);
        expect(doubles, 0);
        // Clear background space in the right side, away from any controls.
        await t.dragFrom(const Offset(1120, 24), const Offset(80, 0));
        expect(drags, 1);
        await t.tapAt(const Offset(1120, 24));
        await t.pump(const Duration(milliseconds: 80));
        await t.tapAt(const Offset(1120, 24));
        await t.pump(const Duration(milliseconds: 400));
        expect(doubles, 1);
        expect(searches, 1);
        expect(workspaces, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }
}
