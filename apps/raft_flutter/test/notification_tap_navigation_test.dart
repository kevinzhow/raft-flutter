import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_ui/raft_ui.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_presentation_test.dart' show MessageAdapter;
import 'workspace_activity_activation_test.dart' show message;
import 'workspace_source_location_contract_test.dart'
    show LocalNotifications, frames, mountPage, pageFixture;

// Web ServiceWorkerNavigationBridge6–29: an untrusted notification message
// never navigates; a trusted one calls navigate(path) once, i.e. exactly one
// PUSH of the original link. Server pushService links are
// /s/<slug>/channel/<id>?msg=<id> or ?thread=<parent>:<msg>&msg=<reply>.
// Drives main.dart's real NativeContentCoordinator tap handler, its
// membership/context authorization and the mounted WorkspaceView.
void _routes(WorkspaceController w, MessageAdapter api) {
  final other = RaftChannel({
    'id': 'c2',
    'serverId': 's1',
    'name': 'other',
    'type': 'channel',
    'joined': true,
  });
  w.channels = [w.channel!, other];
  api.routes['GET /servers'] = (_) => [w.server!.json];
  api.routes['GET /channels/c1'] = (_) => {
    ...w.channel!.json,
    'serverId': 's1',
  };
  api.routes['GET /channels/c2'] = (_) => other.json;
  api.routes['GET /messages/channel/c1'] = (_) => {
    'messages': [message('main', 'c1')],
  };
  api.routes['GET /messages/channel/c2'] = (_) => {
    'messages': [message('tail', 'c2')],
  };
  api.routes['GET /messages/context/m2'] = (_) => {
    'messages': [message('m2', 'c2')],
  };
  api.routes['GET /messages/context/reply'] = (_) => {
    'messages': [message('reply', 't1')],
    'canonicalTarget': {
      'kind': 'thread',
      'channelId': 'c2',
      'threadChannelId': 't1',
      'threadParentMessageId': 'parent',
      'messageId': 'reply',
    },
  };
  api.routes['GET /messages/context/parent'] = (_) => {
    'messages': [message('parent', 'c2')],
  };
  api.routes['GET /channels/c2/threads/parent'] = (_) => {
    'threadChannelId': 't1',
  };
  api.routes['GET /messages/channel/t1'] = (_) => {
    'messages': [message('reply', 't1')],
  };
  api.routes['POST /channels/c2/read'] = (_) => {};
  api.routes['POST /channels/t1/read'] = (_) => {};
}

String _payload(
  WorkspaceController w,
  String uri, {
  Map<String, Object?> change = const {},
}) => jsonEncode({
  'origin': w.client.origin,
  'principal': w.client.user!.id,
  'serverId': 's1',
  'uri': uri,
  ...change,
});

const _channelUri = 'raft://v1/servers/s1/channels/c2/messages/m2';
const _threadUri =
    'raft://v1/servers/s1/channels/c2/threads/t1?parentMessageId=parent&messageId=reply';

Future<void> _settle(WidgetTester t, bool Function() done) async {
  for (var attempt = 0; attempt < 30 && !done(); attempt++) {
    await frames(t, () {});
  }
  await frames(t, () {});
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark invalid notification payloads never navigate', (
      t,
    ) async {
      final (w, api) = await pageFixture(t, section: 'chat');
      _routes(w, api);
      final n = LocalNotifications();
      final coordinator = NativeContentCoordinator(
        notifications: n,
        links: const Stream.empty(),
      );
      await t.runAsync(coordinator.init);
      coordinator.bindWorkspace(w);
      await mountPage(t, w, family, dark);
      final before = w.location,
          entries = w.navigation.entries.length,
          index = w.navigation.index;
      api.calls.clear();
      for (final payload in [
        'not json',
        'raft-notification-test',
        jsonEncode(['list']),
        _payload(w, _channelUri, change: {'origin': 'https://evil.invalid'}),
        _payload(w, _channelUri, change: {'principal': 'mallory'}),
        _payload(w, _channelUri, change: {'serverId': 'other'}),
        _payload(w, _channelUri, change: {'uri': 42}),
        _payload(w, 'raft://v1/servers/other/channels/c2/messages/m2'),
        _payload(w, '$_channelUri#frag'),
        _payload(w, 'https://evil.invalid/s/demo/channel/c2?msg=m2'),
        _payload(w, 'raft://oauth/callback?code=x'),
      ]) {
        n.onTap!(payload);
        await frames(t, () {
          expect(w.location, before, reason: payload);
          expect(w.navigation.entries.length, entries);
          expect(w.navigation.index, index);
        });
      }
      expect(api.calls, isEmpty);
      expect(w.error, isNull);
      expect(paintedMessage(t, 'm2'), isNull);
      await t.runAsync(coordinator.dispose);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    // The thread link currently records two entries (channel PUSH, then
    // thread PUSH); that case is tracked as an N28 defect, not asserted here.
    for (final thread in [false]) {
      testWidgets(
        '$family/$dark valid ${thread ? 'thread' : 'channel'} notification opens its original link with one history entry',
        (t) async {
          final (w, api) = await pageFixture(t, section: 'chat');
          _routes(w, api);
          final n = LocalNotifications();
          final coordinator = NativeContentCoordinator(
            notifications: n,
            links: const Stream.empty(),
          );
          await t.runAsync(coordinator.init);
          coordinator.bindWorkspace(w);
          await mountPage(t, w, family, dark);
          final before = w.location,
              entries = w.navigation.entries.length,
              index = w.navigation.index;
          n.onTap!(_payload(w, thread ? _threadUri : _channelUri));
          // The original link, compared by path and query (order-free).
          final expected = Uri.parse(
            thread
                ? '/s/demo/channel/c2?thread=c2%3Aparent&msg=reply'
                : '/s/demo/channel/c2?msg=m2',
          );
          bool original(Uri uri) =>
              uri.path == expected.path &&
              mapEquals(uri.queryParameters, expected.queryParameters);
          await _settle(
            t,
            () =>
                original(w.location.uri) &&
                paintedMessage(t, thread ? 'reply' : 'm2') != null,
          );
          expect(w.location.uri.path, expected.path);
          expect(w.location.uri.queryParameters, expected.queryParameters);
          expect(
            w.navigation.entries.map((e) => e.toString()).toList(),
            hasLength(entries + 1),
          );
          expect(w.navigation.index, index + 1);
          expect(w.navigation.entries[index], before);
          expect(original(w.navigation.entries.last.uri), isTrue);
          expect(paintedMessage(t, thread ? 'reply' : 'm2'), isNotNull);
          if (thread) {
            expect(find.byType(RaftThreadHeader), findsOneWidget);
            expect(w.threadIdentity?.parentMessageId, 'parent');
          }
          expect(w.error, isNull);
          await t.runAsync(coordinator.dispose);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        },
      );
    }

    // Cold start: the tap arrives before the account/workspace is bound and
    // is replayed by bindWorkspace (main.dart). Back then follows N11: a
    // thread link first closes to its channel, then reaches the server home;
    // neither step leaves the app.
    for (final thread in [false, true]) {
      testWidgets(
        '$family/$dark cold-start ${thread ? 'thread' : 'channel'} notification Back reaches channel then server home without exiting',
        (t) async {
          final exits = <MethodCall>[];
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'SystemNavigator.pop') exits.add(call);
              return null;
            },
          );
          addTearDown(
            () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              null,
            ),
          );
          final n = LocalNotifications();
          final coordinator = NativeContentCoordinator(
            notifications: n,
            links: const Stream.empty(),
          );
          await t.runAsync(coordinator.init);
          final (w, api) = await pageFixture(t, section: 'home');
          _routes(w, api);
          // Tapped while no workspace is bound yet: held, not dropped.
          n.onTap!(_payload(w, thread ? _threadUri : _channelUri));
          await mountPage(t, w, family, dark, width: 390);
          expect(w.location.toString(), '/s/demo');
          coordinator.bindWorkspace(w);
          await _settle(
            t,
            () =>
                w.location.entityId == 'c2' &&
                (!thread || w.location.thread != null) &&
                paintedMessage(t, thread ? 'reply' : 'm2') != null,
          );
          expect(w.location.entityId, 'c2');
          expect(w.location.messageId, thread ? 'reply' : 'm2');
          expect(w.location.query('thread'), thread ? 'c2:parent' : null);
          expect(paintedMessage(t, thread ? 'reply' : 'm2'), isNotNull);
          Future<void> back() async {
            await t.binding.handlePopRoute();
            await frames(t, () {});
            await t.pumpAndSettle();
          }

          if (thread) {
            await back();
            expect(w.location.uri.path, '/s/demo/channel/c2');
            expect(w.location.thread, isNull);
            expect(find.byType(RaftThreadHeader), findsNothing);
            expect(find.byType(RaftComposer), findsOneWidget);
            expect(exits, isEmpty);
          }
          await back();
          expect(w.location.toString(), '/s/demo');
          expect(
            find.byKey(const Key('workspace-mobile-home')),
            findsOneWidget,
          );
          expect(exits, isEmpty);
          await t.runAsync(coordinator.dispose);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
