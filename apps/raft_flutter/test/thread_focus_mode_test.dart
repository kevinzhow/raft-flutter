import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/thread_actions.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'mounted_message_navigation_test.dart'
    show pageFixture, mountPage, pageFrames;

// Web v1.21.12 thread focus mode (uiStore.threadMaximized): the thread's
// overflow menu hides the channel column beside a side thread and brings it
// back. It is presentation only: the location, the history and the open
// thread are untouched, and a window that cannot show the side thread keeps
// the flag without applying it.
void main() {
  Future<(WorkspaceController, dynamic)> openThread(
    WidgetTester tester,
    RaftFamily family, {
    double width = 1440,
  }) async {
    final (w, api) = await pageFixture(tester);
    w.messageDomain.ledger.ingest([
      row('main', 'c1', 1),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'main'};
    w.navigation.navigate(w.location.withQuery({'thread': 'c1:parent'}));
    api.routes['GET /channels/c1/threads/parent'] = (_) => {
      'threadChannelId': 't1',
    };
    api.routes['GET /messages/channel/t1'] = (_) => {
      'messages': [row('r1', 't1', 1)],
    };
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [row('parent', 'c1', 2)],
    };
    await tester.runAsync(
      () => w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        initialThreadChannelId: 't1',
        navigate: false,
      ),
    );
    await mountPage(tester, w, family, false, width: width);
    return (w, api);
  }

  /// Whether a read receipt for [id] would go out now (the one policy:
  /// foreground, presented, nothing newer).
  Future<bool> reads(
    WidgetTester tester,
    dynamic api,
    WorkspaceController w,
    String id,
  ) async {
    final before = api.calls
        .where((c) => c.path == '/channels/$id/read')
        .length;
    await tester.runAsync(() async {
      await w.markRead(id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    return api.calls.where((c) => c.path == '/channels/$id/read').length >
        before;
  }

  final main = find.byKey(const ValueKey('message-main'));
  final panel = find.byKey(const Key('workspace-thread-panel'));
  final focusItem = find.byKey(const Key('thread-focus-menu-item'));

  Future<void> menu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('thread-options')));
    await tester.pumpAndSettle();
  }

  Future<void> toggle(WidgetTester tester) async {
    await menu(tester);
    await tester.tap(focusItem);
    await tester.pumpAndSettle();
  }

  for (final family in [RaftFamily.brutal, RaftFamily.elegant]) {
    testWidgets(
      '[$family] Focus mode hides the channel, Standard mode brings it back',
      (tester) async {
        final (w, api) = await openThread(tester, family);
        final location = w.location,
            index = w.navigation.index,
            entries = w.navigation.entries.length;
        final side = tester.getRect(panel);
        expect(main, findsOneWidget);
        expect(await reads(tester, api, w, 'c1'), isTrue);

        await menu(tester);
        expect(focusItem, findsOneWidget);
        expect(tester.widget<RaftMenuItem>(focusItem).label, 'Focus mode');
        // First item, ahead of search.
        expect(
          tester.getTopLeft(focusItem).dy,
          lessThan(tester.getTopLeft(find.text('Search in thread')).dy),
        );
        await tester.tap(focusItem);
        await tester.pumpAndSettle();

        expect(main, findsNothing);
        expect(find.byType(RaftThreadHeader), findsOneWidget);
        expect(tester.getRect(panel).width, greaterThan(side.width * 2));
        // Layout only: nothing about what is open changed.
        expect(w.location, location);
        expect(w.navigation.index, index);
        expect(w.navigation.entries.length, entries);
        expect(w.threadIdentity?.parentMessageId, 'parent');
        // The hidden channel is not read, the thread still is.
        expect(await reads(tester, api, w, 'c1'), isFalse);
        await menu(tester);
        expect(tester.widget<RaftMenuItem>(focusItem).label, 'Standard mode');
        await tester.tap(focusItem);
        await tester.pumpAndSettle();
        expect(main, findsOneWidget);
        expect(tester.getRect(panel).width, side.width);
        expect(await reads(tester, api, w, 'c1'), isTrue);
        expect(w.location, location);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a window that folds the thread has no Focus mode item', (
    tester,
  ) async {
    final (w, api) = await openThread(tester, RaftFamily.elegant, width: 1279);
    tester.view.physicalSize = const Size(1279, 1400);
    await pageFrames(tester, () {}, count: 3);
    expect(panel, findsNothing);
    await menu(tester);
    expect(find.text('Search in thread'), findsOneWidget);
    expect(focusItem, findsNothing);
    expect(
      await reads(tester, api, w, 'c1'),
      isFalse,
      reason: 'the thread covers it',
    );
  });

  testWidgets(
    'focus survives a trip through a narrow window without moving the location',
    (tester) async {
      final (w, _) = await openThread(tester, RaftFamily.elegant);
      await toggle(tester);
      expect(main, findsNothing);
      final location = w.location,
          index = w.navigation.index,
          entries = w.navigation.entries.length;
      tester.view.physicalSize = const Size(1279, 1400);
      await pageFrames(tester, () {}, count: 3);
      expect(panel, findsNothing);
      expect(w.location, location);
      tester.view.physicalSize = const Size(1440, 900);
      await pageFrames(tester, () {}, count: 3);
      expect(panel, findsOneWidget);
      expect(main, findsNothing, reason: 'the flag outlives the narrow window');
      expect(w.location, location);
      expect(w.navigation.index, index);
      expect(w.navigation.entries.length, entries);
    },
  );

  testWidgets('opening a profile restores the channel for good', (
    tester,
  ) async {
    final (w, api) = await openThread(tester, RaftFamily.elegant);
    await toggle(tester);
    expect(main, findsNothing);
    w.openProfile(RaftProfileKind.human, 'bob');
    await tester.pumpAndSettle();
    expect(main, findsOneWidget);
    expect(await reads(tester, api, w, 'c1'), isTrue);
    w.closeProfile();
    await tester.pumpAndSettle();
    expect(
      main,
      findsOneWidget,
      reason: 'closing the profile does not re-hide it',
    );
    await menu(tester);
    expect(tester.widget<RaftMenuItem>(focusItem).label, 'Focus mode');
  });

  testWidgets('closing the thread ends focus mode', (tester) async {
    final (w, _) = await openThread(tester, RaftFamily.elegant);
    await toggle(tester);
    w.closeThread();
    await tester.pumpAndSettle();
    expect(main, findsOneWidget);
    expect(panel, findsNothing);
    // A new thread in the same channel starts in standard mode.
    await tester.runAsync(
      () => w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        initialThreadChannelId: 't1',
      ),
    );
    await tester.pumpAndSettle();
    expect(main, findsOneWidget);
  });

  testWidgets('the menu item needs the layout to offer focus mode', (
    tester,
  ) async {
    // ThreadActions on its own (a page, not the workspace's side slot).
    final client = RaftClient(
      origin: 'https://fixture.invalid',
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'u'});
    client.selectServer('s');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..messageDomain.state.threadParent = RaftMessage({
        'id': 'm',
        'channelId': 'c',
        'content': 'Parent',
      });
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    var toggled = 0;
    Widget host({VoidCallback? toggle, bool placed = true}) {
      final actions = ThreadActions(
        controller: w,
        parentMessageId: 'm',
        menuMode: true,
      );
      return MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: placed
              ? RaftThreadPlacement(
                  split: true,
                  focused: false,
                  toggleFocus: toggle,
                  child: actions,
                )
              : actions,
        ),
      );
    }

    Future<void> close() async {
      await tester.tap(find.byKey(const Key('thread-options')));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(host(placed: false));
    await menu(tester);
    expect(focusItem, findsNothing);
    await close();

    await tester.pumpWidget(host());
    await menu(tester);
    expect(focusItem, findsNothing, reason: 'the layout offers no toggle');
    await close();

    await tester.pumpWidget(host(toggle: () => toggled++));
    await menu(tester);
    expect(focusItem, findsOneWidget);
    await tester.tap(focusItem);
    await tester.pumpAndSettle();
    expect(toggled, 1);
  });
}
