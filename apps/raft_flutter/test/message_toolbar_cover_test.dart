import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/profile_side_panel.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'message_context_transition_test.dart' show row;
import 'mounted_message_navigation_test.dart' show pageFixture, pageFrames;
import 'support/app_services_fixture.dart';

// Web keeps the message hover toolbar inside its row's stacking context
// (MessageItem > MessageHoverToolbar), so a panel opened over the row covers
// it, and the row loses :hover. Flutter floats the strip in the route's
// overlay; a panel of the same route (the profile over the conversation or
// over the thread column) must still cover it: the pointer at the strip's
// place reaches the panel, and the strip goes away.
void main() {
  Future<WorkspaceController> mount(
    WidgetTester tester,
    Size size, {
    bool dark = false,
    TargetPlatform platform = TargetPlatform.linux,
  }) async {
    final (w, api) = await pageFixture(tester);
    w.messageDomain.ledger.ingest([
      {
        ...row('m1', 'c1', 1),
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
      },
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark).copyWith(platform: platform),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return w;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  /// Hovers the row, then rests the pointer on the strip's Save button (the
  /// strip then holds itself open); returns that button's centre.
  Future<(TestGesture, Offset)> restOnToolbar(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('message-m1'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final save = find.byKey(const ValueKey('message-save-m1'));
    expect(save.hitTestable(), findsOneWidget);
    final at = tester.getCenter(save);
    await mouse.moveTo(at);
    await tester.pump(const Duration(milliseconds: 100));
    expect(save.hitTestable(), findsOneWidget);
    return (mouse, at);
  }

  /// The render objects a pointer at [at] reaches, front first.
  List<RenderObject> hitPath(WidgetTester tester, Offset at) {
    final result = HitTestResult();
    tester.binding.hitTestInView(result, at, tester.view.viewId);
    return [
      for (final entry in result.path)
        if (entry.target is RenderObject) entry.target as RenderObject,
    ];
  }

  bool inside(WidgetTester tester, RenderObject target, Finder of) {
    if (of.evaluate().isEmpty) return false;
    final root = tester.renderObject(of);
    for (RenderObject? node = target; node != null; node = node.parent) {
      if (identical(node, root)) return true;
    }
    return false;
  }

  void expectCovered(WidgetTester tester, Offset at, Finder panel) {
    final path = hitPath(tester, at);
    expect(path, isNotEmpty);
    expect(
      inside(tester, path.first, panel),
      isTrue,
      reason: 'the pointer at the strip reaches ${path.first}, not the panel',
    );
    expect(
      path.any((o) => inside(tester, o, find.byType(RaftMessageToolbar))),
      isFalse,
      reason: 'the hover toolbar still takes hits above the panel',
    );
  }

  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('$mode: a profile opened over the conversation (folded '
        'desktop) covers the hover toolbar', (tester) async {
      final w = await mount(tester, const Size(900, 800), dark: dark);
      final (_, at) = await restOnToolbar(tester);
      w.openProfile(RaftProfileKind.human, 'bob');
      await pageFrames(tester, () {});
      final panel = find.byType(ProfileSidePanel);
      expect(panel, findsOneWidget);
      expect(tester.getRect(panel).contains(at), isTrue);
      expectCovered(tester, at, panel);
      expect(find.byType(RaftMessageToolbar), findsNothing);
      // Closing the panel under a resting pointer shows the strip again.
      w.closeProfile();
      await pageFrames(tester, () {});
      expect(
        find.byKey(const ValueKey('message-save-m1')).hitTestable(),
        findsOneWidget,
      );
      await finish(tester);
    });
  }

  testWidgets('a narrow desktop window (390x844, mouse): the profile page '
      'covers the hover toolbar', (tester) async {
    final w = await mount(tester, const Size(390, 844));
    final (_, at) = await restOnToolbar(tester);
    w.openProfile(RaftProfileKind.human, 'bob');
    await pageFrames(tester, () {});
    final panel = find.byType(ProfileSidePanel);
    expect(tester.getRect(panel).contains(at), isTrue);
    expectCovered(tester, at, panel);
    expect(find.byType(RaftMessageToolbar), findsNothing);
    await finish(tester);
  });

  for (final size in const [Size(856, 944), Size(944, 856)]) {
    testWidgets('an unfolded foldable ${size.width}x${size.height} (fingers) '
        'never floats a hover toolbar, before or after the profile opens', (
      tester,
    ) async {
      final w = await mount(tester, size, platform: TargetPlatform.android);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('message-m1'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RaftMessageToolbar), findsNothing);
      w.openProfile(RaftProfileKind.human, 'bob');
      await pageFrames(tester, () {});
      expect(find.byType(ProfileSidePanel), findsOneWidget);
      expect(find.byType(RaftMessageToolbar), findsNothing);
      await finish(tester);
    });
  }

  testWidgets('a profile beside the conversation (wide desktop) never has '
      'the hover toolbar over it', (tester) async {
    final w = await mount(tester, const Size(1440, 900));
    final (mouse, at) = await restOnToolbar(tester);
    w.openProfile(RaftProfileKind.human, 'bob');
    await pageFrames(tester, () {});
    final panel = find.byKey(const Key('workspace-profile-panel'));
    expect(panel, findsOneWidget);
    final strip = find.byType(RaftMessageToolbar);
    // The chat narrowed: wherever the strip is now, it is clear of the panel.
    if (strip.evaluate().isNotEmpty) {
      expect(tester.getRect(strip).overlaps(tester.getRect(panel)), isFalse);
    }
    if (tester.getRect(panel).contains(at)) {
      expectCovered(tester, at, panel);
    }
    // The pointer crossing onto the panel puts the strip away.
    await mouse.moveTo(tester.getCenter(panel));
    await tester.pump(const Duration(milliseconds: 100));
    expect(strip, findsNothing);
    await finish(tester);
  });

  for (final size in const [Size(1440, 900), Size(900, 800)]) {
    testWidgets('${size.width}: clicking the sender avatar opens the profile; '
        'the strip goes once the pointer is on the panel', (tester) async {
      final w = await mount(tester, size);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final avatar = find.byKey(const ValueKey('sender-avatar-m1'));
      await mouse.moveTo(tester.getCenter(avatar));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RaftMessageToolbar), findsOneWidget);
      final at = tester.getCenter(
        find.byKey(const ValueKey('message-save-m1')),
      );
      await mouse.down(tester.getCenter(avatar));
      await mouse.up();
      await pageFrames(tester, () {});
      expect(w.location.profile, isNotNull);
      final panel = find.byType(ProfileSidePanel);
      expect(panel, findsOneWidget);
      if (tester.getRect(panel).contains(at)) {
        expectCovered(tester, at, panel);
      }
      await mouse.moveTo(tester.getRect(panel).center);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RaftMessageToolbar), findsNothing);
      await finish(tester);
    });
  }

  testWidgets('a profile opened over the side thread covers the reply\'s '
      'hover toolbar', (tester) async {
    final (w, api) = await pageFixture(tester);
    w.messageDomain.ledger.ingest([
      {...row('m1', 'c1', 1), 'senderId': 'bob', 'senderType': 'user'},
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    w.messageDomain.threadSummaries = {
      'm1': {'replyCount': 1},
    };
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    api.routes['GET /channels/c1/threads/m1'] = (_) => {
      'threadChannelId': 't1',
    };
    api.routes['GET /messages/channel/t1'] = (_) => {
      'messages': [
        {...row('r1', 't1', 1), 'senderId': 'bob', 'senderType': 'user'},
      ],
    };
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('thread-replies-badge-m1')));
    await tester.runAsync(() async {
      for (var i = 0; i < 40 && w.messageDomain.state.threadLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await pageFrames(tester, () {});
    expect(find.byKey(const Key('workspace-thread-panel')), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('message-r1')).last),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final save = find.byKey(const ValueKey('message-save-r1'));
    expect(save.hitTestable(), findsOneWidget);
    final at = tester.getCenter(save);
    await mouse.moveTo(at);
    await tester.pump(const Duration(milliseconds: 100));
    w.openProfile(RaftProfileKind.human, 'bob');
    await pageFrames(tester, () {});
    // The thread folds into the conversation region. The profile takes the
    // space where the floating toolbar was.
    expect(find.byKey(const Key('workspace-profile-panel')), findsOneWidget);
    expect(find.byKey(const Key('workspace-thread-panel')), findsNothing);
    final panel = find.byType(ProfileSidePanel);
    expect(tester.getRect(panel).contains(at), isTrue);
    expectCovered(tester, at, panel);
    expect(find.byType(RaftMessageToolbar), findsNothing);
    await finish(tester);
  });

  testWidgets('a dialog opened over a showing toolbar covers it', (
    tester,
  ) async {
    await mount(tester, const Size(1440, 900));
    final (_, at) = await restOnToolbar(tester);
    showDialog<void>(
      context: tester.element(find.byType(WorkspaceView)),
      builder: (_) => const Center(
        child: SizedBox(
          key: Key('cover-dialog'),
          width: 600,
          height: 600,
          child: ColoredBox(color: Color(0xffffffff)),
        ),
      ),
    );
    await pageFrames(tester, () {});
    final barrier = find.byType(ModalBarrier).last;
    final path = hitPath(tester, at);
    expect(
      path.any((o) => inside(tester, o, find.byType(RaftMessageToolbar))),
      isFalse,
    );
    expect(
      inside(tester, path.first, barrier) ||
          inside(tester, path.first, find.byKey(const Key('cover-dialog'))),
      isTrue,
    );
    await finish(tester);
  });
}
