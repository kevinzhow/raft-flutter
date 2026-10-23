import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  final handle = find.byKey(const Key('split-pane-resize-handle'));
  Future<void> mount(
    WidgetTester t, {
    double width = 1000,
    double treeWidth = 256,
    ValueChanged<double>? onWidth,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 700);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftWorkspaceTreeView(
            path: '~/.slock/agents/a1/',
            nodes: const [],
            treeWidth: treeWidth,
            onTreeWidthChanged: onWidth,
          ),
        ),
      ),
    );
    await t.pump();
  }

  double treeColumnWidth(WidgetTester t) =>
      t.getSize(find.byKey(const Key('split-pane-start'))).width;

  testWidgets('the file tree is 256 wide until dragged, 160 to 600 once '
      'dragged, and reports the width when the drag ends', (t) async {
    final reported = <double>[];
    await mount(t, onWidth: reported.add);
    expect(treeColumnWidth(t), 256);
    // The handle straddles the tree's right edge.
    expect(t.getCenter(handle).dx, closeTo(256, 0.5));

    final drag = await t.startGesture(t.getCenter(handle));
    await drag.moveBy(const Offset(50, 0));
    await t.pump();
    expect(treeColumnWidth(t), 306);
    expect(reported, isEmpty);
    await drag.up();
    await t.pump();
    expect(reported, [306]);

    final wide = await t.startGesture(t.getCenter(handle));
    await wide.moveBy(const Offset(900, 0));
    await t.pump();
    expect(treeColumnWidth(t), 600);
    await wide.moveBy(const Offset(-1200, 0));
    await t.pump();
    expect(treeColumnWidth(t), 160);
    await wide.up();
    await t.pump();
    expect(reported.last, 160);
  });

  testWidgets('a saved width starts the tree, kept inside the bounds', (
    t,
  ) async {
    await mount(t, treeWidth: 400);
    expect(treeColumnWidth(t), 400);
    await mount(t, treeWidth: 50);
    expect(treeColumnWidth(t), 160);
  });

  testWidgets('a phone-width panel has no split and no handle', (t) async {
    await mount(t, width: 500);
    expect(handle, findsNothing);
    expect(find.byKey(const Key('split-pane-start')), findsNothing);
  });
}
