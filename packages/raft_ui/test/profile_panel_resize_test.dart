import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  final panel = find.byKey(const Key('workspace-profile-panel'));
  final handle = find.byKey(const Key('profile-resize-handle'));

  Future<void> mount(
    WidgetTester t, {
    double width = 1500,
    bool profile = true,
    bool thread = false,
    double profileWidth = 380,
    ValueChanged<double>? onWidth,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 800);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftAdaptiveWorkspace(
            sidebar: const Text('Sidebar'),
            rail: const Text('Rail'),
            content: const Center(child: Text('Conversation')),
            thread: thread ? const Text('Thread') : null,
            profile: profile ? const Text('Profile') : null,
            profileWidth: profileWidth,
            onProfileWidthChanged: onWidth,
            mobileNavigation: const Text('Mobile navigation'),
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('the profile panel is 380 wide until dragged, 300 to 600 once '
      'dragged, and reports the width when the drag ends', (t) async {
    final reported = <double>[];
    await mount(t, onWidth: reported.add);
    expect(t.getSize(panel).width, 380);
    expect(handle, findsOneWidget);
    // The handle straddles the panel's left edge.
    expect(t.getCenter(handle).dx, closeTo(t.getTopLeft(panel).dx, 0.5));

    final drag = await t.startGesture(t.getCenter(handle));
    await drag.moveBy(const Offset(-60, 0));
    await t.pump();
    expect(t.getSize(panel).width, 440);
    await drag.moveBy(const Offset(-40, 0));
    await t.pump();
    expect(t.getSize(panel).width, 480);
    // Nothing is stored while the drag goes on.
    expect(reported, isEmpty);
    await drag.up();
    await t.pump();
    expect(reported, [480]);

    // The bounds hold at both ends.
    final wide = await t.startGesture(t.getCenter(handle));
    await wide.moveBy(const Offset(-400, 0));
    await t.pump();
    expect(t.getSize(panel).width, 600);
    await wide.moveBy(const Offset(900, 0));
    await t.pump();
    expect(t.getSize(panel).width, 300);
    await wide.up();
    await t.pump();
    expect(reported.last, 300);
  });

  testWidgets('a saved width is the starting width, kept inside the bounds', (
    t,
  ) async {
    await mount(t, profileWidth: 520);
    expect(t.getSize(panel).width, 520);
    await mount(t, profileWidth: 900);
    expect(t.getSize(panel).width, 600);
    await mount(t, profileWidth: 120);
    expect(t.getSize(panel).width, 300);
  });

  testWidgets('arrow keys step a focused handle and report each step', (
    t,
  ) async {
    final reported = <double>[];
    await mount(t, onWidth: reported.add);
    Focus.of(
      t.element(
        find.descendant(of: handle, matching: find.byType(GestureDetector)),
      ),
    ).requestFocus();
    await t.pump();
    // The panel grows toward the left edge of the window.
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pump();
    expect(t.getSize(panel).width, 396);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(t.getSize(panel).width, 364);
    expect(reported, [396, 380, 364]);
  });

  testWidgets('beside a thread the profile handle sits on the profile edge; '
      'folded or absent panels have none', (t) async {
    await mount(t, thread: true);
    expect(handle, findsOneWidget);
    expect(find.byKey(const Key('thread-resize-handle')), findsOneWidget);
    expect(t.getCenter(handle).dx, closeTo(t.getTopLeft(panel).dx, 0.5));

    await mount(t, profile: false);
    expect(handle, findsNothing);

    // A narrow window shows the profile over the whole workspace (folded).
    await mount(t, width: 700);
    expect(handle, findsNothing);
  });

  testWidgets('a profile too wide for three columns covers the thread instead '
      'of squeezing the conversation', (t) async {
    await mount(t, thread: true, profileWidth: 380);
    final beside = find.byKey(const Key('workspace-thread-panel'));
    expect(beside, findsOneWidget);
    expect(panel, findsOneWidget);
    await mount(t, thread: true, profileWidth: 600);
    // Three columns no longer leave the conversation 320: the profile covers
    // the thread (Web's ProfilePanel overlay) and its handle is not shown.
    expect(panel, findsNothing);
    expect(handle, findsNothing);
  });
}
