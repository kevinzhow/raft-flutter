import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('phone Home aligns conversation and Saved leading slots', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const conversation = ValueKey('conversation-glyph');
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                RaftNavItem(
                  label: 'General',
                  leading: const SizedBox.square(
                    key: conversation,
                    dimension: 16,
                  ),
                  conversationKind: RaftConversationNavKind.channel,
                  onTap: () {},
                ),
                RaftNavItem(
                  label: 'Saved',
                  glyph: RaftGlyph.bookmark,
                  role: RaftNavItemRole.saved,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(conversation)).dx, 21.5);
    expect(tester.getTopLeft(find.byType(RaftIcon)).dx, 20);
  });

  testWidgets('new section shows the first step on phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => RaftButton(
              label: 'New section',
              onPressed: () => showRaftSidebarSectionDialog(
                context,
                title: 'Section name',
                submitLabel: 'Create',
                stepLabel: 'Step 1 of 2',
                onSubmit: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('New section'));
    await tester.pumpAndSettle();
    final step = find.text('Step 1 of 2');
    expect(step, findsOneWidget);
    expect(RaftFormFrame.maybeOf(tester.element(step)), RaftSurfaceForm.dialog);
  });

  testWidgets('loading reserves the pinned hint and withholds the counts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    const hint = 'Drag channels or DMs here to pin';
    const dmHeader = ValueKey('dm-header');
    Future<void> show(bool loading) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                RaftChatSidebarGroup(
                  kind: RaftChatSidebarGroupKind.pinned,
                  label: 'Pinned',
                  count: 0,
                  expanded: true,
                  hideEmpty: false,
                  loading: loading,
                  emptyLabel: hint,
                  onExpandedChanged: (_) {},
                  children: const [],
                ),
                RaftChatSidebarGroup(
                  headerKey: dmHeader,
                  kind: RaftChatSidebarGroupKind.directMessages,
                  label: 'Direct messages',
                  count: 0,
                  expanded: true,
                  hideEmpty: false,
                  loading: loading,
                  onExpandedChanged: (_) {},
                  children: const [],
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      await show(true);
      expect(find.bySemanticsLabel(hint), findsNothing);
      expect(find.text('0'), findsNothing);
      final heldPosition = tester.getTopLeft(find.byKey(dmHeader));
      await show(false);
      expect(find.bySemanticsLabel(hint), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2));
      expect(tester.getTopLeft(find.byKey(dmHeader)), heldPosition);
    } finally {
      semantics.dispose();
    }
  });
}
