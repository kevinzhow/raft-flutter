import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/thread_actions.dart';
import 'package:raft_ui/raft_ui.dart';

import 'thread_overlay_history_test.dart'
    show frames, openThreadFromBadge, overlayFixture, taskRow;

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final initial = Completer<dynamic>();
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) =>
      initial.future;
}

void main() {
  testWidgets('desktop pointer-open first ArrowDown selects Search', (
    tester,
  ) async {
    final fixture = await overlayFixture(
      tester,
      width: 1280,
      task: taskRow('task-parent'),
    );
    await openThreadFromBadge(tester, fixture);
    final route = fixture.w.location;
    final trigger = find.byKey(const Key('thread-options'));
    final menu = find.byType(RaftMenuPanel);

    String? focusedCommand() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<RaftMenuItem>()
        ?.label;

    try {
      await tester.tap(trigger, kind: PointerDeviceKind.mouse);
      await frames(tester);
      expect(menu, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await frames(tester);
      expect(focusedCommand(), 'Search in thread');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await frames(tester);
      expect(menu, findsNothing);
      final input = find.byKey(const Key('thread-search-input'));
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      expect(fixture.w.location, route);
      await tester.tap(find.byKey(const Key('thread-search-close')));
      await frames(tester);

      await tester.tap(trigger, kind: PointerDeviceKind.mouse);
      await frames(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await frames(tester);
      expect(focusedCommand(), 'Follow thread');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester);
      expect(menu, findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await frames(tester);
      expect(focusedCommand(), 'Search in thread');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester);
      expect(menu, findsNothing);
      expect(fixture.w.location, route);
    } finally {
      if (menu.evaluate().isNotEmpty) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await frames(tester);
      }
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
    }
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final revoke in [false, true]) {
    testWidgets(
      'cold thread menu receives the store first membership; revoked=$revoke',
      (t) async {
        final client = RaftClient(
          origin: 'https://fixture.invalid',
          sessionStore: MemorySessionStore(),
        )..user = RaftRecord({'id': 'u'});
        // The shared followed-threads store is scoped to the selected server.
        client.selectServer('s');
        final parent = RaftMessage({
          'id': 'm',
          'channelId': 'c',
          'content': 'Thread parent',
        });
        final w = _Workspace(client)
          ..server = RaftRecord({'id': 's', 'role': 'owner'})
          ..messageDomain.state.threadParent = parent;
        addTearDown(() async {
          w.dispose();
          await client.dispose();
        });
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: ThreadActions(
                controller: w,
                parentMessageId: parent.id,
                menuMode: true,
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const Key('thread-options')));
        await t.pumpAndSettle();
        final entry = find.byKey(const Key('thread-follow-menu-item'));
        expect(t.widget<RaftMenuItem>(entry).onPressed, isNull);
        if (revoke) {
          client.user = RaftRecord({'id': 'next'});
          w.notifyListeners();
          await t.pump();
          expect(entry, findsNothing);
        }
        w.initial.complete({'threads': []});
        await t.pumpAndSettle();
        if (revoke) {
          expect(entry, findsNothing);
        } else {
          expect(t.widget<RaftMenuItem>(entry).onPressed, isNotNull);
          expect(t.widget<RaftMenuItem>(entry).label, 'Follow thread');
          expect(t.widget<RaftMenuItem>(entry).glyph, RaftGlyph.followThread);
          await t.tap(find.byKey(const Key('thread-options')));
          await t.pumpAndSettle();
          expect(entry, findsNothing);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
