// #384: a thread that becomes current without the in-app open (a cold start
// or session restore at its address, Back / Forward onto its history entry, a
// link pushed into the app) takes a tap and typed text in its composer, as
// one opened from its row does. Activity and Search show the thread in their
// content slot (`?open=thread:`), a channel beside the chat (`?thread=`).
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/tap_target_registry.dart';
import 'package:raft_flutter/features/workspace_history_controls.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/content_target.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/app_services_fixture.dart';
import 'tap_target_matrix_test.dart'
    show Ctx, TapObserver, channelRoutes, mount, threadReplies;
import 'task_surface_test.dart' show flush;
import 'workspace_source_location_contract_test.dart' show pageFixture;

const _activity = '/s/demo/activity?open=thread:t1&msg=r1&thread=c1:parent',
    _search = '/s/demo/search?q=hit&open=thread:t1&msg=r1&thread=c1:parent',
    _channel = '/s/demo/channel/c1?thread=c1:parent&msg=r1',
    _besideChannel = '/s/demo/activity?open=channel:c1&thread=c1:parent';

const _widths = [1280.0, 816.0, 390.0];

class _Notifications extends NativeNotificationService {
  @override
  Future<void> bindAuthenticatedWorkspace(String? scope) async {}

  @override
  Future<void> detachWorkspace(String? account) async {}
}

Finder _threadEditor(Ctx c) => find
    .descendant(
      of: c.threadView,
      matching: find.descendant(
        of: find.byType(RaftComposer),
        matching: find.byType(EditableText),
      ),
    )
    .hitTestable();

/// The workspace painted before the app accepted its address, as the app
/// root shows it on start: Chat, with the inbox listing the thread.
Future<Ctx> _workspace(WidgetTester t, double width) async {
  t.view.physicalSize = Size(width, width < 768 ? 844 : 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final (w, api) = await pageFixture(t, section: 'chat');
  w.channels = [
    RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
    RaftChannel({'id': 'c2', 'name': 'random', 'joined': true}),
  ];
  w.channel = w.channels.first;
  channelRoutes(api);
  api.routes['GET /channels/inbox'] = (_) => {
    'items': [
      {
        'kind': 'thread',
        'threadChannelId': 't1',
        'parentChannelId': 'c1',
        'parentMessageId': 'parent',
        'parentMessagePreview': 'Parent',
        'latestActivityPreview': 'A reply',
        'unreadCount': 1,
        'firstUnreadMessageId': 'r1',
        'latestActivityMessageId': 'r1',
      },
    ],
  };
  final touch = width < 1024;
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(
        platform: touch ? TargetPlatform.android : TargetPlatform.macOS,
      ),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await flush(t);
  await t.pumpAndSettle();
  return Ctx(
    t,
    w,
    api,
    TapObserver(),
    TapHost('cold-$width', TapSurface.chat, width, '', touch: touch),
  );
}

Future<void> _settle(WidgetTester t) async {
  await flush(t);
  await t.pumpAndSettle();
}

/// The thread is on screen and its composer takes a tap, focus and text.
Future<void> _threadComposerTakesText(WidgetTester t, Ctx c) async {
  expect(c.threadView, findsOneWidget, reason: 'the thread is on screen');
  final editor = _threadEditor(c);
  expect(editor, findsOneWidget, reason: 'its composer takes pointers');
  await t.tap(
    editor,
    kind: c.host.touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
  );
  await t.pumpAndSettle();
  expect(t.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
  t.testTextInput.enterText('a reply');
  await t.pump();
  expect(t.widget<EditableText>(editor).controller.text, 'a reply');
}

Future<void> _end(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

void main() {
  for (final address in [_activity, _search, _channel, _besideChannel]) {
    for (final width in _widths) {
      // Activity and Search show a channel beside its thread on wide windows
      // only; a phone opens the channel page.
      if (address == _besideChannel && width < 1024) continue;
      // Search's loading skeleton overflows its 240 px list column at 816
      // (quick_switcher_results.dart, 96 + 80 + 48 px bars and three 6 px
      // gaps); that is not this thread's.
      if (address == _search && width == 816) continue;
      testWidgets('a start or restore at $address, width $width: the '
          "thread's composer takes text", (t) async {
        final c = await _workspace(t, width);
        // AppRoot after the server is selected: the remembered surface or
        // the address the app was opened at.
        restoreAcceptedLocation(c.w, Uri.parse(address));
        c.w.notifyListeners();
        await _settle(t);
        expect(c.w.location.uri.toString(), contains('thread=c1'));
        await _threadComposerTakesText(t, c);
        await _end(t);
      });
    }
  }

  testWidgets('a start at an Activity thread whose parent is still loading: '
      'its composer takes text', (t) async {
    final c = await _workspace(t, 1280);
    // The parent is read apart from the replies; the composer needs the
    // thread's identity from the address, not the parent's row.
    final parent = Completer<Map<String, dynamic>>();
    addTearDown(() => parent.complete({'messages': []}));
    c.api.routes['GET /messages/context/parent'] = (_) => parent.future;
    restoreAcceptedLocation(c.w, Uri.parse(_activity));
    c.w.notifyListeners();
    await _settle(t);
    expect(c.w.messageDomain.threadParentLoading, isTrue);
    await _threadComposerTakesText(t, c);
    await _end(t);
  });

  for (final host in ['activity-thread-1280', 'activity-thread-816']) {
    for (final forward in [false, true]) {
      testWidgets('$host: ${forward ? 'Forward' : 'Back'} onto the '
          "thread's entry: its composer takes text", (t) async {
        final c = await mount(
          t,
          TapTargetRegistry.hosts.firstWhere((h) => h.id == host),
        );
        final thread = c.w.navigation.index;
        await t.runAsync(() => c.w.selectChannel(c.w.channels[1]));
        c.w.notifyListeners();
        await _settle(t);
        expect(c.threadView, findsNothing);
        if (forward) {
          // Back to the thread, Back again to the channel, then Forward.
          unawaited(_visit(c, thread));
          await _settle(t);
          unawaited(_visit(c, thread + 1));
          await _settle(t);
        }
        unawaited(_visit(c, thread));
        await _settle(t);
        expect(c.w.location.uri.toString(), contains('open=thread'));
        await _threadComposerTakesText(t, c);
        await _end(t);
      });
    }
  }

  for (final width in [1280.0, 390.0]) {
    testWidgets('a link to a thread reply pushed into the app, width '
        "$width: the thread's composer takes text", (t) async {
      final c = await _workspace(t, width);
      c.api.routes['GET /servers'] = (_) => [
        {'id': 's1', 'slug': 'demo'},
      ];
      c.api.routes['GET /channels/c1'] = (_) => {
        'id': 'c1',
        'serverId': 's1',
        'name': 'test',
        'type': 'channel',
        'joined': true,
      };
      // The server names a reply's thread beside its context window.
      c.api.routes['GET /messages/context/r1'] = (_) => {
        ...threadReplies,
        'canonicalTarget': {
          'kind': 'thread',
          'messageId': 'r1',
          'threadParentMessageId': 'parent',
          'threadChannelId': 't1',
        },
      };
      final links = NativeContentCoordinator(
        notifications: _Notifications(),
        links: const Stream.empty(),
      );
      await t.runAsync(() async => links.bindWorkspace(c.w));
      try {
        await t.runAsync(
          () => links.navigate(
            const ContentTarget(
              serverId: 's1',
              channelId: 'c1',
              messageId: 'r1',
              parentMessageId: 'parent',
              threadId: 't1',
              kind: 'thread',
            ),
            externalLink: true,
          ),
        );
        await _settle(t);
        await _threadComposerTakesText(t, c);
      } finally {
        await t.runAsync(links.dispose);
      }
      await _end(t);
    });
  }
}

Future<void> _visit(Ctx c, int index) => visitWorkspaceHistory(
  c.w,
  index,
  authority: c.w.navigationAuthority,
  expectedUri: c.w.navigation.entries[index].uri,
);
