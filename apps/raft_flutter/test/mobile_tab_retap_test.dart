@Tags(['slow'])
library;

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/tab_root_retap.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/server_tab.dart';

// Web v1.24 `retapTabRoot` / `useTabRootScroll`: tapping the selected bottom
// bar tab scrolls its root to the top, smoothly, and does nothing else. At the
// top only Search adds a step: it focuses its field.
const tabBar = Key('workspace-mobile-navigation');

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

extension on WidgetTester {
  /// Frames until the scroller leaves [from] (the tab bar hands a tap over
  /// after its press feedback), at most 300ms.
  Future<void> pumpUntil(ScrollableState scroller, double from) async {
    for (var i = 0; i < 6 && scroller.position.pixels == from; i++) {
      await pump(const Duration(milliseconds: 50));
    }
  }
}

RootFixture fixture() {
  final f = RootFixture();
  f.overrides['GET /channels'] = (_) => [
    for (var i = 0; i < 40; i++)
      {
        'id': 'c$i',
        'name': 'room-$i',
        'type': 'channel',
        'serverId': 'a',
        'joined': true,
        'latestSeq': '1',
      },
  ];
  f.overrides['GET /tasks/server'] = (_) => {
    'tasks': [
      for (var n = 1; n <= 40; n++)
        {
          'id': 'task-$n',
          'taskNumber': n,
          'title': 'Retap task $n',
          'channelId': 'c0',
          'channelName': 'room-0',
          'messageId': 'm$n',
          'status': 'todo',
          'createdByType': 'user',
          'createdById': 'alice',
          'createdByName': 'Alice',
        },
    ],
    'next_cursor': null,
  };
  return f;
}

Future<void> mount(
  RootFixture f,
  WidgetTester t, {
  Size size = const Size(390, 844),
}) async {
  await f.mount(t, 'light', size.width, uri: Uri.parse('/s/alpha'));
  t.view.physicalSize = size;
  await f.flush(t);
}

ScrollableState scrollerIn(WidgetTester t, Finder root) =>
    t.state<ScrollableState>(
      find
          .descendant(of: root, matching: find.byType(Scrollable))
          .evaluate()
          .map((e) => find.byWidget(e.widget))
          .firstWhere((f) {
            final s = t.state<ScrollableState>(f);
            return s.axisDirection == AxisDirection.down;
          }),
    );

Finder get homeList => find.byKey(const Key('workspace-sidebar'));

Future<void> tapTab(RootFixture f, WidgetTester t, String id) async {
  await t.tap(find.byKey(Key('mobile-tab-$id')));
  await f.flush(t);
  await settle(t);
}

void main() {
  testWidgets('Home scrolled: re-tap scrolls to the top and nothing else', (
    t,
  ) async {
    final f = fixture();
    await mount(f, t);
    final w = f.workspace(t);
    final index = w.navigation.index;
    final scroller = scrollerIn(t, homeList);
    scroller.position.jumpTo(600);
    await t.pump();
    expect(scroller.position.pixels, 600);
    final where = w.location.toString();
    await t.tap(find.byKey(const Key('mobile-tab-home')));
    await t.pumpUntil(scroller, 600);
    // Smooth: on its way, not there yet.
    expect(scroller.position.pixels, inExclusiveRange(0, 600));
    await settle(t);
    expect(scroller.position.pixels, 0);
    expect(w.location.toString(), where);
    expect(w.navigation.index, index);
    await f.close(t);
  });

  testWidgets('Home at the top: re-tap does nothing', (t) async {
    final f = fixture();
    await mount(f, t);
    final w = f.workspace(t);
    final scroller = scrollerIn(t, homeList);
    final index = w.navigation.index;
    await t.tap(find.byKey(const Key('mobile-tab-home')));
    await settle(t);
    expect(scroller.position.pixels, 0);
    expect(w.location.toString(), '/s/alpha');
    expect(w.navigation.index, index);
    expect(find.byKey(tabBar), findsOneWidget);
    await f.close(t);
  });

  testWidgets('Tasks scrolled: re-tap scrolls to the top and stays', (t) async {
    final f = fixture();
    await mount(f, t);
    final w = f.workspace(t);
    await tapTab(f, t, 'tasks');
    final where = w.location.toString();
    final index = w.navigation.index;
    expect(where, '/s/alpha/tasks');
    final scroller = scrollerIn(t, find.byType(ResourceView));
    expect(scroller.position.maxScrollExtent, greaterThan(300));
    scroller.position.jumpTo(300);
    await t.pump();
    await t.tap(find.byKey(const Key('mobile-tab-tasks')));
    await t.pumpUntil(scroller, 300);
    expect(scroller.position.pixels, inExclusiveRange(0, 300));
    await settle(t);
    expect(scroller.position.pixels, 0);
    expect(w.location.toString(), where);
    expect(w.navigation.index, index);
    await f.close(t);
  });

  bool fieldFocused(WidgetTester t) => t
      .widgetList<EditableText>(find.byType(EditableText))
      .any((e) => e.focusNode.hasFocus);

  testWidgets('Search at the top: re-tap focuses the field', (t) async {
    final f = fixture();
    await mount(f, t);
    await tapTab(f, t, 'search');
    expect(fieldFocused(t), isFalse);
    await t.tap(find.byKey(const Key('mobile-tab-search')));
    await settle(t);
    expect(fieldFocused(t), isTrue);
    await f.close(t);
  });

  testWidgets('Search scrolled: re-tap scrolls first, then focuses', (t) async {
    final f = fixture();
    f.overrides['GET /messages/search'] = (_) => {
      'results': [
        for (var n = 0; n < 40; n++)
          {
            'id': 'hit-$n',
            'channelId': 'c0',
            'channelName': 'room-0',
            'channelType': 'channel',
            'seq': '$n',
            'senderId': 'alice',
            'senderName': 'Alice',
            'senderType': 'user',
            'content': 'Needle $n',
            'snippet': 'Needle $n',
            'createdAt': '2026-10-10T00:00:00Z',
          },
      ],
      'hasMore': false,
    };
    await mount(f, t);
    await tapTab(f, t, 'search');
    await t.enterText(find.byType(EditableText).first, 'Needle');
    await settle(t, 1500);
    final scroller = scrollerIn(t, find.byType(ResourceView));
    expect(scroller.position.maxScrollExtent, greaterThan(300));
    scroller.position.jumpTo(300);
    await t.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    expect(fieldFocused(t), isFalse);
    await t.tap(find.byKey(const Key('mobile-tab-search')));
    await t.pumpUntil(scroller, 300);
    expect(scroller.position.pixels, inExclusiveRange(0, 300));
    expect(fieldFocused(t), isFalse);
    await settle(t);
    expect(scroller.position.pixels, 0);
    expect(fieldFocused(t), isFalse);
    await t.tap(find.byKey(const Key('mobile-tab-search')));
    await settle(t);
    expect(fieldFocused(t), isTrue);
    await f.close(t);
  });

  testWidgets('switching tabs and back keeps the Home position', (t) async {
    final f = fixture();
    await mount(f, t);
    final scroller = scrollerIn(t, homeList);
    scroller.position.jumpTo(500);
    await t.pump();
    await tapTab(f, t, 'tasks');
    await tapTab(f, t, 'home');
    expect(scrollerIn(t, homeList).position.pixels, 500);
    await f.close(t);
  });

  testWidgets('a pushed page registers nothing', (t) async {
    final f = fixture();
    await mount(f, t);
    expect(TabRootRetap.registered, contains('chat'));
    await openServerPage(t, 'settings', flush: f.flush);
    expect(find.byKey(tabBar), findsNothing);
    expect(TabRootRetap.retap('settings'), isFalse);
    await f.close(t);
    expect(TabRootRetap.registered, isEmpty);
  });

  for (final size in const [Size(856, 944), Size(944, 856)]) {
    testWidgets('an unfolded ${size.width.toInt()}x${size.height.toInt()} '
        'Android registers no tab root', (t) async {
      final f = fixture();
      await mount(f, t, size: size);
      expect(find.byKey(tabBar), findsNothing);
      expect(TabRootRetap.registered, isEmpty);
      expect(TabRootRetap.retap('chat'), isFalse);
      expect(t.takeException(), isNull);
      await f.close(t);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('a narrow Linux window re-taps Home by mouse', (t) async {
    final f = fixture();
    await mount(f, t);
    final scroller = scrollerIn(t, homeList);
    scroller.position.jumpTo(600);
    await t.pump();
    final mouse = await t.startGesture(
      t.getCenter(find.byKey(const Key('mobile-tab-home'))),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.up();
    await settle(t);
    expect(scroller.position.pixels, 0);
    await f.close(t);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
