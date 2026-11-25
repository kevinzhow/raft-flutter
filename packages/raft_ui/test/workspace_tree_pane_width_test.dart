import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The workspace tree + file preview split is the whole Agent page on one
/// host and a 300-600 px profile column on another, so the `md:` cut has to
/// be measured on the view's own box. Reading the window put a 160-600 px
/// tree column and the file pane inside a 360 px profile panel.
void main() {
  final tree = find.byKey(const Key('split-pane-start'));
  final previewBox = find.byKey(const Key('preview-box'));

  Future<bool?> mount(WidgetTester t, {required double pane}) async {
    bool? alone;
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1280, 900);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: pane,
                child: RaftWorkspaceTreeView(
                  path: '~/.slock/agents/a1/',
                  nodes: const [],
                  preview: (context, shownAlone) {
                    alone = shownAlone;
                    return const SizedBox.expand(key: Key('preview-box'));
                  },
                ),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    return alone;
  }

  testWidgets('a pane narrower than the md cut shows the open file alone', (
    t,
  ) async {
    final alone = await mount(t, pane: 360);
    expect(tree, findsNothing);
    expect(t.getSize(previewBox).width, 360);
    // The host has to add the way back: the tree is not on screen.
    expect(alone, isTrue);
  });

  testWidgets('a pane at the md cut keeps the tree beside the file', (t) async {
    final alone = await mount(t, pane: 800);
    expect(t.getSize(tree).width, 256);
    expect(t.getRect(previewBox).left, 256);
    expect(t.getSize(previewBox).width, 800 - 256);
    expect(alone, isFalse);
  });
}
