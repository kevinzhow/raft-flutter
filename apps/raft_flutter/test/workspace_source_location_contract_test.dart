import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/page_layout.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/content_target.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_presentation_test.dart' show MessageAdapter;
import 'workspace_activity_activation_test.dart'
    show channelRow, threadRow, message;

// Mounted Source 26f77ef contract ports. Every case uses the actual WorkspaceView,
// its ResourceView/headers and local held transport. Model-only ports remain in
// source_navigation_contract_test.dart. No native/browser-history claim follows.
class LocalClient extends RaftClient {
  LocalClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  // This contract exercises real REST/navigation, not a live Socket transport.
  @override
  void connect() {}
}

class LocalNotifications extends NativeNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
}

Future<(WorkspaceController, MessageAdapter)> pageFixture(
  WidgetTester tester, {
  String section = 'activity',
  String serverSlug = 'demo',
}) async {
  SharedPreferences.setMockInitialValues({});
  final api = MessageAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final w = (await tester.runAsync(() async {
    final client = LocalClient(api);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    return WorkspaceController(client);
  }))!;
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  addTearDown(w.dispose);
  w.loading = false;
  w.ledger.switchServer('s1');
  w.server = RaftRecord({
    'id': 's1',
    'slug': serverSlug,
    'name': 'Alpha',
    'role': 'owner',
  });
  w.section = section;
  api.routes['GET /channels/inbox'] = (_) => {'items': []};
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  api.routes['GET /messages/search'] = (_) => {'results': [], 'hasMore': false};
  api.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  api.routes['POST /channels/c1/read'] = (_) => {};
  api.routes['POST /channels/t1/read'] = (_) => {};
  return (w, api);
}

Future<void> mountPage(
  WidgetTester tester,
  WorkspaceController w,
  RaftFamily family,
  bool dark, {
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: WorkspaceView(
        controller: w,
        appearance: RaftAppearance(light: family),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> frames(WidgetTester tester, void Function() check) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    check();
  }
}

Future<void> waitForPainted(WidgetTester tester, String id) async {
  for (
    var attempt = 0;
    attempt < 20 && paintedMessage(tester, id) == null;
    attempt++
  ) {
    await frames(tester, () {});
  }
  expect(paintedMessage(tester, id), isNotNull);
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    // useAppNavigate.ts:446–464: routeKind is a separate permalink identity.
    // Two accepted-record scenarios deliberately share the same ID. Each actual
    // Activity row publishes its own route kind and preserves slug/msg encoding.
    for (final dm in [false, true]) {
      testWidgets(
        '[N01] $family/$dark actual ${dm ? 'DM' : 'channel'} with shared ID preserves route and focus',
        (tester) async {
          final (w, api) = await pageFixture(tester, serverSlug: 'team space');
          const id = 'same:conversation', focus = 'target:one';
          final accepted = RaftChannel({
            'id': id,
            'name': dm ? 'Actual peer' : 'Actual channel',
            'type': dm ? 'dm' : 'channel',
            'joined': true,
            if (dm) 'peerDisplayName': 'Actual peer',
          });
          w.channel = accepted;
          w.channels = dm ? [] : [accepted];
          w.dms = dm ? [accepted] : [];
          final response = Completer<Map<String, dynamic>>();
          addTearDown(() {
            if (!response.isCompleted) response.complete({'messages': []});
          });
          api.routes['GET /channels/inbox'] = (_) => {
            'items': [
              {
                ...channelRow,
                'kind': dm ? 'dm' : 'channel',
                'channelId': id,
                'channelName': accepted.name,
                'firstMentionMessageId': null,
                'firstUnreadMessageId': focus,
                'lastMessageId': focus,
              },
            ],
          };
          api.routes['GET /messages/context/$focus'] = (_) => response.future;
          api.routes['POST /channels/$id/read'] = (_) => {};
          await mountPage(tester, w, family, dark, width: 390);
          final before = w.navigation.entries.length;
          await tester.tap(
            find.byKey(ValueKey('activity-${dm ? 'dm' : 'channel'}-$id')),
          );
          await frames(tester, () {
            expect(w.location.route, dm ? RaftRoute.dm : RaftRoute.channel);
            expect(w.location.entityId, id);
            expect(w.location.serverSlug, 'team space');
            expect(w.location.messageId, focus);
            expect(
              w.location.toString(),
              contains('/${dm ? 'dm' : 'channel'}/same:conversation'),
            );
            expect(w.location.toString(), contains('msg=target%3Aone'));
            expect(w.location.toString(), isNot(contains('%253A')));
            expect(find.byKey(const Key('mobile-detail-back')), findsOneWidget);
            if (dm) {
              expect(find.byType(RaftChannelHeader), findsNothing);
              expect(
                tester
                    .widget<RaftPageHeader>(
                      find.byKey(const Key('workspace-mobile-detail-header')),
                    )
                    .title,
                accepted.name,
              );
            } else {
              final header = tester.widget<RaftChannelHeader>(
                find.byType(RaftChannelHeader),
              );
              expect(header.name, accepted.name);
              expect(header.kind, 'channel');
            }
          });
          expect(w.navigation.entries.length, before + 1);
          expect(
            api.calls
                .where((r) => r.path == '/messages/context/$focus')
                .single
                .queryParameters['channelId'],
            id,
          );
          await tester.runAsync(() async {
            response.complete({
              'messages': [
                {...message(focus, id), 'content': 'Actual $focus'},
              ],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await frames(tester, () {});
          expect(paintedMessage(tester, focus), isNotNull);
          expect(w.highlightedMessageId, focus);
          await tester.tap(find.byKey(const Key('mobile-detail-back')));
          await tester.pump();
          expect(w.location.route, RaftRoute.activity);
          expect(w.location.serverSlug, 'team space');
          await frames(tester, () {});
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    // main.dart binds this coordinator to the same WorkspaceController. This
    // drives its real bounded URI parser, membership/context authorization and
    // jump handler while the actual page is mounted; no OS plugin is simulated.
    for (final dm in [false, true]) {
      testWidgets(
        '[N01] $family/$dark bounded native ${dm ? 'DM' : 'channel'} link with shared ID retains typed route and message',
        (tester) async {
          final (w, api) = await pageFixture(tester);
          const id = 'shared-id', focus = 'target-1';
          final accepted = RaftChannel({
            'id': id,
            'serverId': 's1',
            'name': dm ? 'Native peer' : 'Native channel',
            'type': dm ? 'dm' : 'channel',
            'joined': true,
          });
          w.channel = accepted;
          w.channels = dm ? [] : [accepted];
          w.dms = dm ? [accepted] : [];
          api.routes['GET /servers'] = (_) => [w.server!.json];
          api.routes['GET /channels/$id'] = (_) => accepted.json;
          api.routes['GET /messages/context/$focus'] = (_) => {
            'messages': [message(focus, id)],
          };
          api.routes['POST /channels/$id/read'] = (_) => {};
          final coordinator = NativeContentCoordinator(
            notifications: LocalNotifications(),
          );
          coordinator.bindWorkspace(w);
          addTearDown(coordinator.dispose);
          await mountPage(tester, w, family, dark, width: 390);
          final uri = Uri.parse(
            'https://example.invalid/s/demo/${dm ? 'dm' : 'channel'}/$id?msg=$focus',
          );
          final target = ContentTarget.parse(
            uri,
            origin: Uri.parse(w.client.origin),
          );
          expect(target?.kind, dm ? 'dm' : 'channel');
          coordinator.receiveLink(uri);
          await frames(tester, () {});
          expect(
            w.location.toString(),
            '/s/demo/${dm ? 'dm' : 'channel'}/$id?msg=$focus',
          );
          expect(w.location.route, dm ? RaftRoute.dm : RaftRoute.channel);
          expect(w.location.entityId, id);
          expect(w.location.serverSlug, 'demo');
          expect(w.location.messageId, focus);
          for (
            var attempt = 0;
            attempt < 20 && paintedMessage(tester, focus) == null;
            attempt++
          ) {
            await frames(tester, () {});
          }
          expect(paintedMessage(tester, focus), isNotNull);
          expect(api.calls.where((r) => r.path == '/servers'), hasLength(1));
          expect(
            api.calls.where((r) => r.path == '/channels/$id'),
            hasLength(1),
          );
          expect(
            api.calls
                .where((r) => r.path == '/messages/context/$focus')
                .every((r) => r.queryParameters['channelId'] == id),
            isTrue,
          );
          await tester.runAsync(coordinator.dispose);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    // The new typed callback must also retain Source's ordinary channel/DM
    // branch (MessageSearchPage1318–1333), search input and replace history.
    for (final dm in [false, true]) {
      testWidgets(
        '[N01] $family/$dark actual Search ${dm ? 'DM' : 'channel'} result keeps ordinary typed content and query',
        (tester) async {
          final (w, api) = await pageFixture(tester, section: 'search');
          const id = 'shared-id', focus = 'target-1';
          final accepted = RaftChannel({
            'id': id,
            'name': dm ? 'Search peer' : 'Search channel',
            'type': dm ? 'dm' : 'channel',
            'joined': true,
          });
          w.channel = accepted;
          w.channels = dm ? [] : [accepted];
          w.dms = dm ? [accepted] : [];
          final context = Completer<Map<String, dynamic>>();
          addTearDown(() {
            if (!context.isCompleted) context.complete({'messages': []});
          });
          api.routes['GET /messages/search'] = (_) => {
            'results': [
              {
                ...message(focus, id),
                'channelName': accepted.name,
                'channelType': accepted.type,
                'content': 'Actual ordinary result',
              },
            ],
            'hasMore': false,
          };
          api.routes['GET /messages/context/$focus'] = (_) => context.future;
          api.routes['POST /channels/$id/read'] = (_) => {};
          await mountPage(tester, w, family, dark);
          await tester.enterText(find.byType(TextField).first, 'Actual');
          await tester.pump(const Duration(milliseconds: 210));
          await frames(tester, () {});
          final before = w.navigation.entries.length,
              index = w.navigation.index;
          await tester.tap(find.byType(RaftSearchResultSurface).first);
          await frames(tester, () {
            expect(w.location.route, RaftRoute.search);
            expect(
              w.location.content?.kind,
              dm ? RaftContentKind.dm : RaftContentKind.channel,
            );
            expect(w.location.content?.id, id);
            expect(w.location.messageId, focus);
            expect(w.threadIdentity, isNull);
            expect(find.byType(RaftThreadHeader), findsNothing);
            expect(
              tester
                  .widget<TextField>(find.byType(TextField).first)
                  .controller!
                  .text,
              'Actual',
            );
          });
          expect(w.navigation.entries.length, before);
          expect(w.navigation.index, index);
          expect(
            api.calls
                .where((r) => r.path == '/messages/context/$focus')
                .single
                .queryParameters['channelId'],
            id,
          );
          await tester.runAsync(() async {
            context.complete({
              'messages': [message(focus, id)],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await waitForPainted(tester, focus);
          expect(w.highlightedMessageId, focus);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    // Actual mounted entry contracts: ThreadsInbox1111–1147 and
    // MessageSearchPage1281–1315 seed the thread from its typed result DTO.
    // Parent metadata, thread resolution and reply context are independent.
    for (final activity in [false, true]) {
      testWidgets(
        '[N02a] $family/$dark actual ${activity ? 'Activity' : 'Search'} click separates thread, parent and focused reply',
        (tester) async {
          final (w, api) = await pageFixture(
            tester,
            section: activity ? 'activity' : 'search',
          );
          final parent = Completer<Map<String, dynamic>>(),
              reply = Completer<Map<String, dynamic>>(),
              resolution = Completer<Map<String, dynamic>>();
          addTearDown(() {
            if (!parent.isCompleted) parent.complete({'messages': []});
            if (!reply.isCompleted) reply.complete({'messages': []});
            if (!resolution.isCompleted) {
              resolution.complete({'threadChannelId': 't1'});
            }
          });
          api.routes['GET /messages/context/parent'] = (_) => parent.future;
          api.routes['GET /messages/context/reply'] = (_) => reply.future;
          api.routes['GET /channels/c1/threads/parent'] = (_) =>
              resolution.future;
          api.routes['GET /channels/inbox'] = (_) => {
            'items': [
              {...threadRow, 'threadChannelId': 't1'},
            ],
          };
          api.routes['GET /messages/search'] = (_) => {
            'results': [
              {
                ...message('reply', 't1'),
                'channelType': 'thread',
                'parentChannelId': 'c1',
                'parentMessageId': 'parent',
                'parentChannelName': 'test',
                'content': 'Actual thread search result',
              },
            ],
            'hasMore': false,
          };
          await mountPage(tester, w, family, dark);
          if (activity) {
            await tester.tap(find.byKey(const ValueKey('activity-thread-t1')));
            await tester.pump(const Duration(milliseconds: 220));
          } else {
            await tester.enterText(find.byType(TextField).first, 'Actual');
            await tester.pump(const Duration(milliseconds: 210));
            await frames(tester, () {});
            await tester.tap(find.byType(RaftSearchResultSurface).first);
          }
          await frames(tester, () {
            expect(find.byType(ResourceView), findsOneWidget);
            expect(find.byType(RaftThreadHeader), findsOneWidget);
            expect(w.location.content?.id, 't1');
            expect(w.threadIdentity?.parentChannelId, 'c1');
            expect(w.threadIdentity?.parentMessageId, 'parent');
            expect(w.threadIdentity?.focusedMessageId, 'reply');
            expect(w.threadChannelId, 't1');
            expect(w.channel?.id, 'c1');
            if (!activity) {
              expect(
                tester
                    .widget<TextField>(find.byType(TextField).first)
                    .controller!
                    .text,
                'Actual',
              );
            }
            expect(w.presentedThreadParent, isNull);
            expect(w.threadParentLoading, isTrue);
            expect(
              find.byKey(const Key('workspace-channel-header')),
              findsNothing,
            );
          });
          // Typed Source hits carry a verified thread channel hint: its held
          // resolution endpoint must never be contacted.
          expect(
            api.calls.where((r) => r.path == '/channels/c1/threads/parent'),
            isEmpty,
          );
          expect(
            api.calls
                .where((r) => r.path == '/messages/context/parent')
                .single
                .queryParameters['channelId'],
            'c1',
          );
          expect(
            api.calls
                .where((r) => r.path == '/messages/context/reply')
                .single
                .queryParameters['channelId'],
            't1',
          );
          await tester.runAsync(() async {
            reply.complete({
              'messages': [message('reply', 't1')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await frames(tester, () {});
          expect(paintedMessage(tester, 'reply'), isNotNull);
          expect(w.presentedThreadParent, isNull);
          await tester.runAsync(() async {
            parent.complete({
              'messages': [message('parent', 'c1')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pumpAndSettle();
          expect(w.presentedThreadParent?.id, 'parent');
          expect(w.replies.map((r) => r.id), ['reply']);
          expect(w.messages.any((r) => r.id == 'parent'), isFalse);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    // MessageSearchPage1319–1331 closes the old thread when selecting a real
    // parent-channel hit. The parent focus belongs to the channel surface only.
    testWidgets(
      '[N02b] $family/$dark actual Search parent click never requests or highlights parent as a reply',
      (tester) async {
        final (w, api) = await pageFixture(tester, section: 'search');
        final heldReply = Completer<Map<String, dynamic>>();
        addTearDown(() {
          if (!heldReply.isCompleted) heldReply.complete({'messages': []});
        });
        api.routes['GET /messages/context/parent'] = (_) => {
          'messages': [message('parent', 'c1')],
        };
        api.routes['GET /messages/context/reply'] = (_) => heldReply.future;
        api.routes['GET /messages/search'] = (_) => {
          'results': [
            {
              ...message('reply', 't1'),
              'channelType': 'thread',
              'parentChannelId': 'c1',
              'parentMessageId': 'parent',
              'parentChannelName': 'test',
            },
            {
              ...message('parent', 'c1'),
              'channelType': 'channel',
              'channelName': 'test',
            },
          ],
          'hasMore': false,
        };
        await mountPage(tester, w, family, dark);
        await tester.enterText(find.byType(TextField).first, 'Accepted');
        await tester.pump(const Duration(milliseconds: 210));
        await frames(tester, () {});
        await tester.tap(find.byType(RaftSearchResultSurface).first);
        await frames(tester, () {});
        expect(find.byType(RaftThreadHeader), findsOneWidget);
        expect(w.threadIdentity?.parentMessageId, 'parent');
        await tester.tap(find.byType(RaftSearchResultSurface).last);
        await frames(tester, () {
          expect(w.location.content?.kind, RaftContentKind.channel);
          expect(w.location.content?.id, 'c1');
          expect(w.location.messageId, 'parent');
          expect(w.threadIdentity, isNull);
          expect(find.byType(RaftThreadHeader), findsNothing);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is RaftPageHeader && widget.title == 'test',
            ),
            findsOneWidget,
          );
        });
        await waitForPainted(tester, 'parent');
        expect(w.highlightedMessageId, 'parent');
        expect(
          api.calls.where(
            (r) =>
                r.path == '/messages/context/parent' &&
                r.queryParameters['channelId'] == 't1',
          ),
          isEmpty,
        );
        heldReply.complete({
          'messages': [message('reply', 't1')],
        });
        await frames(tester, () {});
        expect(w.threadIdentity, isNull);
        expect(paintedMessage(tester, 'reply'), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    // A genuine Activity parent-message open already owns msg=parent. Tapping
    // the real replies badge opens a side thread without a reply focus, as in
    // rightPanelUrlSync283–310; the accepted parent cannot become a reply target.
    testWidgets(
      '[N02b] $family/$dark actual Activity parent then replies badge retains parent focus outside reply window',
      (tester) async {
        final (w, api) = await pageFixture(tester);
        final resolution = Completer<Map<String, dynamic>>(),
            replies = Completer<Map<String, dynamic>>();
        addTearDown(() {
          if (!resolution.isCompleted) {
            resolution.complete({'threadChannelId': 't1'});
          }
          if (!replies.isCompleted) replies.complete({'messages': []});
        });
        api.routes['GET /channels/inbox'] = (_) => {
          'items': [
            {
              ...channelRow,
              'firstMentionMessageId': null,
              'firstUnreadMessageId': 'parent',
              'lastMessageId': 'parent',
            },
          ],
        };
        api.routes['GET /messages/context/parent'] = (_) => {
          'messages': [message('parent', 'c1')],
          'threadSummariesByParentMessageId': {
            'parent': {
              'threadChannelId': 't1',
              'replyCount': 1,
              'unreadCount': 0,
            },
          },
        };
        api.routes['GET /channels/c1/threads/parent'] = (_) =>
            resolution.future;
        api.routes['GET /messages/channel/t1'] = (_) => replies.future;
        await mountPage(tester, w, family, dark, width: 390);
        await tester.tap(find.byKey(const ValueKey('activity-channel-c1')));
        await frames(tester, () {});
        expect(w.location.messageId, 'parent');
        await waitForPainted(tester, 'parent');
        await tester.tap(
          find.byKey(const ValueKey('thread-replies-badge-parent')),
        );
        await frames(tester, () {
          expect(find.byType(RaftThreadHeader), findsOneWidget);
          expect(w.threadIdentity?.parentChannelId, 'c1');
          expect(w.threadIdentity?.parentMessageId, 'parent');
          expect(w.threadIdentity?.focusedMessageId, isNull);
          expect(w.location.messageId, 'parent');
          expect(w.highlightedMessageId, isNot('parent'));
          expect(w.threadResolutionLoading, isTrue);
        });
        await tester.runAsync(() async {
          resolution.complete({'threadChannelId': 't1'});
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await frames(tester, () {});
        expect(
          api.calls.where((r) => r.path == '/messages/channel/t1'),
          hasLength(1),
        );
        expect(
          api.calls.where(
            (r) =>
                r.path == '/messages/context/parent' &&
                r.queryParameters['channelId'] == 't1',
          ),
          isEmpty,
        );
        await tester.runAsync(() async {
          replies.complete({
            'messages': [message('reply', 't1')],
          });
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await frames(tester, () {});
        expect(paintedMessage(tester, 'reply'), isNotNull);
        expect(w.replies.map((row) => row.id), ['reply']);
        expect(w.highlightedMessageId, isNot('parent'));
        expect(w.location.messageId, 'parent');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    // searchContentStore.ts:63–79. Query changes are applied while a real master
    // page is mounted, with a retained channel window that must remain hidden.
    for (final activity in [false, true]) {
      testWidgets(
        '[N03] $family/$dark actual ${activity ? 'Activity' : 'Search'} ignores malformed and missing content parameters',
        (tester) async {
          final (w, api) = await pageFixture(
            tester,
            section: activity ? 'activity' : 'search',
          );
          w.ledger.ingest([
            {
              ...message('hidden', 'c1'),
              'content': 'Hidden accepted channel message',
            },
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1'] = {'hidden'};
          await mountPage(tester, w, family, dark);
          for (final open in ['wrong:x', ':x', 'channel:', 'channel', null]) {
            w.navigation.navigate(
              w.location.withQuery({'open': open, 'msg': 'must-not-open'}),
              kind: RaftNavigationKind.replace,
            );
            w.notifyListeners();
            await frames(tester, () {
              expect(w.location.content, isNull, reason: 'invalid open=$open');
              expect(find.byType(ResourceView), findsOneWidget);
              expect(find.byType(RaftThreadHeader), findsNothing);
              expect(find.byType(RaftChannelHeader), findsNothing);
              expect(find.byType(RaftChatView), findsNothing);
              expect(paintedMessage(tester, 'hidden'), isNull);
              expect(w.threadIdentity, isNull);
            });
          }
          expect(
            api.calls.where(
              (r) =>
                  r.path.startsWith('/messages/context/') ||
                  r.path == '/channels/x',
            ),
            isEmpty,
          );
          await frames(tester, () {});
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    // mobileBackNavigation.behavior.test.tsx:544–563. A real server-selection
    // authority reset clears the foreign observed history; mounted Back applies
    // the current server's cold semantic parent, never the retired server.
    testWidgets(
      '[N13] $family/$dark actual server switch then cold mobile Back stays inside the new server',
      (tester) async {
        final (w, api) = await pageFixture(tester, section: 'home');
        final alpha = w.server!,
            bravo = RaftRecord({
              'id': 's2',
              'slug': 'bravo',
              'name': 'Bravo',
              'role': 'owner',
            });
        w.servers = [alpha, bravo];
        w.navigation.navigate(RaftLocation.parse('/s/demo/channel/c1'));
        w.navigation.navigate(
          RaftLocation.parse('/s/demo'),
          kind: RaftNavigationKind.replace,
        );
        final oldHistory = w.navigation.entries
            .map((e) => e.toString())
            .toList();
        expect(oldHistory.any((p) => p.startsWith('/s/demo')), isTrue);
        api.routes['GET /channels'] = (r) =>
            r.queryParameters['dm'] == true || r.queryParameters['dm'] == 'true'
            ? []
            : [
                {
                  'id': 'general',
                  'name': 'Bravo general',
                  'joined': true,
                  'serverId': 's2',
                },
              ];
        api.routes['GET /channels/dm'] = (_) => [];
        api.routes['GET /channels/unread'] = (_) => {'channels': {}};
        api.routes['GET /servers/s2/sidebar-order'] = (_) => {
          'pinned': [],
          'customSections': [],
          'sectionPlacements': [],
        };
        api.routes['GET /servers/s2/setup-projection'] = (_) => {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
        await mountPage(tester, w, family, dark, width: 390);
        await tester.tap(find.byKey(const Key('mobile-server-selector')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bravo'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(w.server?.id, 's2');
        expect(w.client.serverId, 's2');
        expect(w.channel?.id, 'general');
        expect(
          w.navigation.entries.every((e) => e.serverSlug == 'bravo'),
          isTrue,
        );
        w.navigation.navigate(
          RaftLocation.parse('/s/bravo/channel/general?thread=general:parent'),
          kind: RaftNavigationKind.replace,
        );
        w.notifyListeners();
        await tester.pump();
        expect(find.byType(RaftThreadHeader), findsOneWidget);
        expect(find.byKey(const Key('mobile-detail-back')), findsOneWidget);
        await tester.tap(find.byKey(const Key('mobile-detail-back')));
        await tester.pump();
        expect(w.location.toString(), '/s/bravo/channel/general');
        expect(w.server?.id, 's2');
        expect(find.byType(RaftChannelHeader), findsOneWidget);
        expect(find.byType(RaftThreadHeader), findsNothing);
        expect(
          tester.widget<RaftChannelHeader>(find.byType(RaftChannelHeader)).name,
          'Bravo general',
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(w.location.toString(), '/s/bravo');
        expect(
          find.byKey(const Key('workspace-mobile-navigation')),
          findsOneWidget,
        );
        expect(
          w.navigation.entries.every((e) => e.serverSlug == 'bravo'),
          isTrue,
        );
        await frames(tester, () {});
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
