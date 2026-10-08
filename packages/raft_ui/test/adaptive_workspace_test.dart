import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Widget shell({Widget? thread, void Function(double, double)? onWidths}) =>
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftAdaptiveWorkspace(
            sidebar: const Text('Sidebar'),
            rail: const Text('Rail'),
            content: const Center(child: Text('Conversation')),
            thread: thread,
            mobileNavigation: const Text('Mobile navigation'),
            onPanelWidthsChanged: onWidths,
          ),
        ),
      );
  Future<void> viewport(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('sidebar pointer and keyboard resizing respects Web bounds', (
    tester,
  ) async {
    await viewport(tester, 1400);
    final widths = <double>[];
    await tester.pumpWidget(shell(onWidths: (left, _) => widths.add(left)));
    final handle = find.byKey(const Key('sidebar-resize-handle'));
    await tester.drag(handle, const Offset(60, 0));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('workspace-sidebar-panel'))).width,
      300,
    );
    await tester.drag(handle, const Offset(500, 0));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('workspace-sidebar-panel'))).width,
      320,
    );
    final gesture = find.descendant(
      of: handle,
      matching: find.byType(GestureDetector),
    );
    Focus.of(tester.element(gesture)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('workspace-sidebar-panel'))).width,
      304,
    );
    await tester.drag(handle, const Offset(-1000, 0));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('workspace-sidebar-panel'))).width,
      180,
    );
    expect(widths, containsAll([300, 320, 304, 180]));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'side thread becomes one panel in narrow windows without overflow',
    (tester) async {
      await viewport(tester, 1400);
      await tester.pumpWidget(
        shell(thread: const Center(child: Text('Thread conversation'))),
      );
      expect(find.text('Conversation'), findsOneWidget);
      expect(find.byKey(const Key('workspace-thread-panel')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('workspace-thread-panel'))).width,
        400,
      );
      tester.view.physicalSize = const Size(1000, 700);
      await tester.pumpAndSettle();
      expect(find.text('Conversation'), findsNothing);
      expect(find.text('Thread conversation'), findsOneWidget);
      expect(find.text('Sidebar'), findsOneWidget);
      tester.view.physicalSize = const Size(390, 700);
      await tester.pumpAndSettle();
      expect(find.text('Sidebar'), findsNothing);
      expect(find.text('Thread conversation'), findsOneWidget);
      expect(find.text('Mobile navigation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('thread drag preserves at least 320 pixels for conversation', (
    tester,
  ) async {
    await viewport(tester, 1200);
    await tester.pumpWidget(shell(thread: const Text('Thread')));
    await tester.drag(
      find.byKey(const Key('thread-resize-handle')),
      const Offset(-900, 0),
    );
    await tester.pump();
    final thread = tester
        .getSize(find.byKey(const Key('workspace-thread-panel')))
        .width;
    expect(thread, 560);
    expect(1200 - 64 - 240 - 16 - thread, greaterThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'workspace rail announces selected destinations and unread counts',
    (tester) async {
      final semantics = tester.ensureSemantics();

      String selected = 'chat';
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: SizedBox(
              width: 64,
              child: RaftWorkspaceRail(
                destinations: const [
                  RaftRailDestination(
                    id: 'chat',
                    label: 'Chat',
                    icon: Icons.chat,
                  ),
                  RaftRailDestination(
                    id: 'activity',
                    label: 'Activity',
                    icon: Icons.inbox,
                    unread: 12,
                  ),
                ],
                selected: selected,
                onSelected: (value) => selected = value,
                workspaceName: '日本語',
                onWorkspace: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('rail-activity')));
      expect(selected, 'activity');
      expect(find.byTooltip('Activity'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('rail-activity'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('rail-activity'))).toString(),
        contains('12'),
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
