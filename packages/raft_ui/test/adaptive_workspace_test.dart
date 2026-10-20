import 'package:flutter/gestures.dart';
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

  testWidgets(
    'floating mobile bars keep full content and do not intercept side gaps',
    (tester) async {
      await viewport(tester, 390);
      var bodyTaps = 0;
      var navTaps = 0;
      final body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => bodyTaps++,
        child: const SizedBox.expand(key: ValueKey('floating-body')),
      );
      Widget layout(bool floating) => MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftAdaptiveWorkspace(
            content: body,
            sidebar: const SizedBox(),
            rail: const SizedBox(),
            mobileNavigationFloating: floating,
            mobileNavigation: Align(
              heightFactor: 1,
              child: GestureDetector(
                onTap: () => navTaps++,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 208,
                  height: 52,
                  key: ValueKey('floating-bar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(layout(true));
      expect(
        tester.getSize(find.byKey(const ValueKey('floating-body'))),
        const Size(390, 700),
      );
      await tester.tapAt(const Offset(10, 680));
      expect(bodyTaps, 1);
      expect(navTaps, 0);
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('floating-bar'))),
      );
      expect(bodyTaps, 1);
      expect(navTaps, 1);
      await tester.pumpWidget(layout(false));
      expect(
        tester.getSize(find.byKey(const ValueKey('floating-body'))),
        const Size(390, 648),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resize handles paint nothing on hover or drag, like Web', (
    tester,
  ) async {
    await viewport(tester, 1440);
    await tester.pumpWidget(shell(thread: const Text('Thread')));
    for (final key in ['sidebar-resize-handle', 'thread-resize-handle']) {
      final handle = find.byKey(Key(key));
      Iterable<Color?> painted() => tester
          .widgetList<Container>(
            find.descendant(of: handle, matching: find.byType(Container)),
          )
          .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color)
          .where((c) => c != null && c.a > 0);
      expect(painted(), isEmpty, reason: '$key idle');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(handle));
      await tester.pump();
      expect(painted(), isEmpty, reason: '$key hover');
      await mouse.down(tester.getCenter(handle));
      await mouse.moveBy(const Offset(-24, 0));
      await tester.pump();
      expect(painted(), isEmpty, reason: '$key drag');
      await mouse.up();
      await mouse.removePointer();
      await tester.pump();
    }
  });

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
      tester.view.physicalSize = const Size(960, 700);
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
    // Elegant's source rail is 56 px; Brutal's is 64 px. Measure the
    // rendered regions so the conversation bound is independent of that recipe.
    final rail = tester.getSize(find.text('Rail')).width;
    final sidebar = tester
        .getSize(find.byKey(const Key('workspace-sidebar-panel')))
        .width;
    final sidebarHandle = tester
        .getSize(find.byKey(const Key('sidebar-resize-handle')))
        .width;
    final threadHandle = tester
        .getSize(find.byKey(const Key('thread-resize-handle')))
        .width;
    expect(rail, 56);
    expect(thread, 1200 - rail - sidebar - 320);
    expect(sidebarHandle, 8);
    expect(threadHandle, 8);
    final main = tester.getRect(find.widgetWithText(Center, 'Conversation'));
    expect(main.left, rail + sidebar);
    expect(
      tester.getCenter(find.byKey(const Key('sidebar-resize-handle'))).dx,
      main.left,
    );
    expect(
      tester.getCenter(find.byKey(const Key('thread-resize-handle'))).dx,
      main.right,
    );
    expect(
      tester.getSize(find.widgetWithText(Center, 'Conversation')).width,
      greaterThanOrEqualTo(320),
    );
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

  group('thread focus mode', () {
    final presented = <(bool, bool)>[];
    RaftThreadPlacement? placementNow(WidgetTester tester) =>
        RaftThreadPlacement.maybeOf(
          tester.element(find.byKey(const ValueKey('thread'))),
        );
    Widget focusShell({
      String? scope = 'c1',
      bool thread = true,
      bool profile = false,
      Widget content = const Center(
        key: ValueKey('conversation'),
        child: Text('Conversation'),
      ),
    }) => MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: RaftAdaptiveWorkspace(
          sidebar: const SizedBox.expand(),
          rail: const SizedBox.expand(),
          content: content,
          thread: thread
              ? const Center(key: ValueKey('thread'), child: Text('Thread'))
              : null,
          profile: profile ? const Text('Profile') : null,
          focusScope: scope,
          onPresentationChanged: (main, thread) =>
              presented.add((main, thread)),
        ),
      ),
    );

    Future<void> size(WidgetTester tester, Size value) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = value;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> toggle(WidgetTester tester) async {
      placementNow(tester)!.toggleFocus!();
      await tester.pump();
    }

    testWidgets('hides the conversation and gives the thread the row', (
      tester,
    ) async {
      await size(tester, const Size(1440, 900));
      presented.clear();
      await tester.pumpWidget(focusShell());
      final side = tester.getRect(
        find.byKey(const Key('workspace-thread-panel')),
      );
      expect(find.text('Conversation'), findsOneWidget);
      expect(placementNow(tester)?.split, isTrue);
      expect(placementNow(tester)?.focused, isFalse);
      expect(presented.last, (true, true));

      presented.clear();
      await toggle(tester);
      final focused = tester.getRect(
        find.byKey(const Key('workspace-thread-panel')),
      );
      expect(find.text('Conversation'), findsNothing);
      expect(focused.width, greaterThan(side.width * 2));
      expect(focused.right, side.right);
      expect(placementNow(tester)?.focused, isTrue);
      // The conversation is not presented, so nothing reads it meanwhile.
      expect(presented.last, (false, true));
      // The thread has no drag handle when it has the whole row.
      expect(find.byKey(const Key('thread-resize-handle')), findsNothing);

      presented.clear();
      await toggle(tester);
      expect(find.text('Conversation'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('workspace-thread-panel'))).width,
        side.width,
      );
      expect(presented.last, (true, true));
      expect(find.byKey(const Key('thread-resize-handle')), findsOneWidget);
    });

    testWidgets('keeps the conversation mounted while hidden', (tester) async {
      await size(tester, const Size(1440, 900));
      await tester.pumpWidget(focusShell(content: const _Counter()));
      await tester.tap(find.byType(_Counter));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);
      await toggle(tester);
      expect(find.text('count 1', skipOffstage: false), findsOneWidget);
      expect(find.text('count 1'), findsNothing);
      await toggle(tester);
      expect(find.text('count 1'), findsOneWidget);
    });

    testWidgets('no scope, no choice: a page thread or another route', (
      tester,
    ) async {
      await size(tester, const Size(1440, 900));
      await tester.pumpWidget(focusShell(scope: null));
      expect(placementNow(tester)?.split, isTrue);
      expect(placementNow(tester)?.toggleFocus, isNull);
    });

    testWidgets('a window too narrow for the side thread offers nothing', (
      tester,
    ) async {
      await size(tester, const Size(900, 700));
      await tester.pumpWidget(focusShell());
      // Folded: the thread covers the conversation exactly as without focus.
      expect(placementNow(tester)?.split, isFalse);
      expect(placementNow(tester)?.focused, isFalse);
      expect(placementNow(tester)?.toggleFocus, isNull);
      expect(find.byKey(const Key('workspace-thread-panel')), findsNothing);
    });

    testWidgets('resizing across the side-thread cut follows the width', (
      tester,
    ) async {
      await size(tester, const Size(1440, 900));
      await tester.pumpWidget(focusShell());
      await toggle(tester);
      expect(find.text('Conversation'), findsNothing);
      tester.view.physicalSize = const Size(900, 700);
      await tester.pump();
      expect(placementNow(tester)?.focused, isFalse);
      expect(placementNow(tester)?.split, isFalse);
      expect(find.byKey(const ValueKey('thread')), findsOneWidget);
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pump();
      expect(placementNow(tester)?.focused, isTrue);
      expect(find.text('Conversation'), findsNothing);
    });

    testWidgets('a profile panel ends focus mode for good', (tester) async {
      await size(tester, const Size(1440, 900));
      await tester.pumpWidget(focusShell());
      await toggle(tester);
      expect(find.text('Conversation'), findsNothing);
      await tester.pumpWidget(focusShell(profile: true));
      expect(placementNow(tester)?.focused, isFalse);
      expect(placementNow(tester)?.toggleFocus, isNull);
      expect(find.text('Conversation'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      // Closing the profile does not hide the conversation again.
      await tester.pumpWidget(focusShell());
      expect(placementNow(tester)?.focused, isFalse);
      expect(find.text('Conversation'), findsOneWidget);
    });

    testWidgets('closing the thread or changing its conversation ends it', (
      tester,
    ) async {
      await size(tester, const Size(1440, 900));
      await tester.pumpWidget(focusShell());
      await toggle(tester);
      await tester.pumpWidget(focusShell(thread: false));
      expect(find.text('Conversation'), findsOneWidget);
      await tester.pumpWidget(focusShell());
      expect(placementNow(tester)?.focused, isFalse);

      await toggle(tester);
      expect(placementNow(tester)?.focused, isTrue);
      await tester.pumpWidget(focusShell(scope: 'c2'));
      expect(placementNow(tester)?.focused, isFalse);
      expect(find.text('Conversation'), findsOneWidget);

      await toggle(tester);
      await tester.pumpWidget(focusShell(scope: null));
      await tester.pumpWidget(focusShell(scope: 'c2'));
      expect(placementNow(tester)?.focused, isFalse);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => count++),
    child: Center(child: Text('count $count')),
  );
}
