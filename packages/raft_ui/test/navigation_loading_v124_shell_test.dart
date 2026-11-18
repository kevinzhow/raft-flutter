import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (width, height, platform, header, rail, topBar) in [
    (1440.0, 900.0, TargetPlatform.linux, 44.0, 49.0, 44.0),
    (1024.0, 600.0, TargetPlatform.linux, 40.0, 49.0, 44.0),
    (856.0, 944.0, TargetPlatform.android, 56.0, 57.0, 48.0),
    (944.0, 856.0, TargetPlatform.android, 56.0, 57.0, 48.0),
  ]) {
    testWidgets(
      '$width×$height $platform separates column and top bar density',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, height);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            home: Scaffold(
              body: Column(
                children: [
                  RaftWorkspaceTopBar(
                    workspace: const Text('Workspace'),
                    onSearch: () {},
                  ),
                  const RaftPanelHeaderBar(title: 'Panel'),
                ],
              ),
            ),
          ),
        );
        final panel = find.byType(RaftPanelHeaderBar);
        final tokens = RaftTokens.of(tester.element(panel));
        expect(tester.getSize(panel).height, header);
        expect(RaftLayoutMetrics.railWidth(tokens, height), rail);
        expect(
          RaftRailRecipe(tokens, viewportHeight: height).itemSize,
          platform == TargetPlatform.linux ? 36 : 40,
        );
        expect(tester.getSize(find.byType(RaftWorkspaceTopBar)).height, topBar);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'desktop sticker tabs and their mounted strip share control height',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.linux),
          home: Scaffold(
            body: Column(
              children: [
                RaftTabsList<String>(
                  tabs: const [RaftTabItem(value: 'one', label: 'One')],
                  value: 'one',
                  onChanged: (_) {},
                ),
                RaftConversationTabs(
                  tabs: const [
                    RaftConversationTab(
                      id: RaftConversationTabId.chat,
                      label: 'Chat',
                    ),
                    RaftConversationTab(
                      id: RaftConversationTabId.tasks,
                      label: 'Tasks',
                    ),
                  ],
                  value: RaftConversationTabId.chat,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      final tabs = find.byType(RaftTabButton);
      expect(tester.getSize(tabs.first).height, 34);
      expect(tester.getSize(tabs.last).height, 34);
      expect(tester.getSize(find.byType(RaftConversationTabs)).height, 44);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('keyboard focus paints the full 2px column separator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 240,
              child: RaftPanelResizeHandle(
                label: 'Resize',
                value: 240,
                seamLine: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final handle = find.byType(RaftPanelResizeHandle);
    final ink = RaftTokens.of(tester.element(handle)).ink;
    final rule = find.descendant(
      of: handle,
      matching: find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == ink,
      ),
    );
    expect(rule, findsOneWidget);
    expect(tester.getSize(rule), const Size(2, 240));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (width, platform, row) in [
    (390.0, TargetPlatform.android, 44.0),
    (390.0, TargetPlatform.linux, 44.0),
    (856.0, TargetPlatform.android, 38.0),
    (944.0, TargetPlatform.android, 38.0),
    (1440.0, TargetPlatform.linux, 34.0),
  ]) {
    testWidgets('$width $platform loading rows reserve their row rhythm', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 944);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                child: RaftChatSidebarLoadingRows(rows: 3),
              ),
            ),
          ),
        ),
      );
      final bars = find.byWidgetPredicate(
        (widget) => widget is RaftSkeleton && widget.width == 128,
      );
      expect(
        tester.getSize(find.byType(RaftChatSidebarLoadingRows)).height,
        row * 3 + 4,
      );
      expect(bars, findsNWidgets(3));
      expect(
        tester.getCenter(bars.at(1)).dy - tester.getCenter(bars.first).dy,
        row + 2,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final dark in [false, true]) {
    testWidgets('PanelHeader can omit the last folded seam, dark=$dark', (
      tester,
    ) async {
      const key = Key('panel-head');
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: const RaftPanelHeaderBar(
              key: key,
              title: 'Details',
              bottomBorder: Border(),
            ),
          ),
        ),
      );
      final frame = find.descendant(
        of: find.byKey(key),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration is BoxDecoration,
        ),
      );
      final decoration =
          tester.widget<Container>(frame.first).decoration! as BoxDecoration;
      expect(decoration.border, const Border());
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
