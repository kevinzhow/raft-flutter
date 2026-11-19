import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/thread_search.dart';
import 'package:raft_flutter/data/thread_visit.dart';
import 'package:raft_flutter/features/thread_actions.dart';
import 'package:raft_flutter/features/thread_outline_scope.dart';
import 'package:raft_flutter/features/thread_outline_viewport.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_registry_thread_outline.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';
import 'support/thread_outline_fixture.dart';

void main() {
  OpenSurface open({
    required bool rail,
    bool keyboard = false,
    ValueChanged<String>? onJump,
  }) => (t, size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final client = RaftClient(
      origin: 'https://fixture.invalid',
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'u'});
    client.selectServer('s');
    final w = ThreadOutlineTestWorkspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    w.messageDomain.state.threadIdentity = const WorkspaceThreadIdentity(
      parentChannelId: 'channel',
      parentMessageId: 'parent',
    );
    w.threadChannelId = 'replies';
    w.messageDomain.state.threadVisit = ThreadVisit.request(
      w.messageDomain,
      'channel',
    );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    });
    if (rail) await threadOutlineFor(w)!.load();

    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: closePlatform(size)),
        home: Scaffold(
          body: rail
              ? ThreadOutlineViewport(
                  controller: w,
                  onJump: onJump ?? (_) {},
                  child: const SizedBox.expand(),
                )
              : Align(
                  alignment: Alignment.topRight,
                  child: ThreadActions(
                    controller: w,
                    parentMessageId: 'parent',
                    menuMode: true,
                  ),
                ),
        ),
      ),
    );
    await frames(t, 20);
    TestGesture? pointer;
    if (keyboard) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
    } else if (rail) {
      pointer = await t.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: const Offset(1, 1));
      await pointer.moveTo(
        t.getCenter(
          find.byKey(const ValueKey('thread-outline-tick-old-reply')),
        ),
      );
    } else {
      await t.tap(find.byKey(const Key('thread-options')));
      await frames(t, 20);
      await t.tap(find.byKey(const Key('thread-timeline-menu-item')));
    }
    await frames(t, 20);
    await pointer?.removePointer();
    final touch = closePlatform(size) == TargetPlatform.android;
    final surface = find.byKey(
      ValueKey(
        rail
            ? 'thread-outline-rail-card'
            : touch
            ? 'thread-timeline-sheet'
            : 'thread-timeline-popover',
      ),
    );
    return SurfaceProbe(
      isOpen: () => surface.evaluate().isNotEmpty,
      x: touch ? find.byType(RaftSheetClose) : null,
      dragHandle: touch ? find.byType(RaftSheetHandle) : null,
      scrim: const Offset(4, 4),
    );
  };

  registerCloseTests(threadOutlineSurfaces, {
    'thread-outline-list': open(rail: false),
    'thread-outline-rail': open(rail: true),
  });

  testWidgets('the preview replaces the rail at the same height', (t) async {
    await open(rail: true)(t, const Size(1200, 800));
    final old = t.getRect(
      find.byKey(const Key('thread-outline-tick-old-reply')),
    );
    final latest = t.getRect(
      find.byKey(const Key('thread-outline-tick-reply-4')),
    );
    final card = t.getRect(find.byKey(const Key('thread-outline-rail-card')));
    expect(card.center.dy, closeTo((old.top + latest.bottom) / 2, 1));
    expect(card.right, closeTo(old.right, 1));
  });

  testWidgets('one Tab stop opens the rail and arrows choose a reply', (
    t,
  ) async {
    final jumps = <String>[];
    final probe = await open(rail: true, keyboard: true, onJump: jumps.add)(
      t,
      const Size(1200, 800),
    );
    expect(probe.isOpen(), isTrue);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await frames(t, 8);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(jumps, ['reply-3']);

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(t, 20);
    expect(probe.isOpen(), isFalse);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Thread outline rail',
    );
  });
}
