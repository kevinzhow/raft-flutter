import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart'
    show MessageContextLoadError;
import 'package:raft_flutter/features/chat_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'message_presentation_test.dart' show fixture;

Map<String, dynamic> row(String id, String channel, int seq) => {
  'id': id,
  'channelId': channel,
  'seq': '$seq',
  'senderId': 'alice',
  'content': 'Message $id',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'same-channel pending context retains old window; acceptance is atomic',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.ledger.ingest([
        row('old', 'c1', 1),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {'old'};
      final started = Completer<void>(),
          response = Completer<Map<String, dynamic>>();
      api.routes['GET /messages/context/requested'] = (_) {
        started.complete();
        return response.future;
      };
      final receipts = <(List<String>, bool, bool, bool, String?)>[];
      w.addListener(() {
        receipts.add((
          w.messageDomain.messages.map((r) => r.id).toList(),
          w.messageDomain.state.channelLoading,
          w.messageDomain.state.hasMore,
          w.messageDomain.state.hasNewer,
          w.messageDomain.state.highlightedMessageId,
        ));
        if (w.messageDomain.messages.any((r) => r.id == 'canonical')) {
          expect(w.messageDomain.state.channelLoading, false);
          expect(w.messageDomain.state.hasMore, true);
          expect(w.messageDomain.state.hasNewer, true);
          expect(w.messageDomain.state.highlightedMessageId, 'canonical');
          expect(
            w.messageDomain.threadSummaries.containsKey('canonical'),
            true,
          );
        }
      });
      final request = w.jumpToMessage('c1', 'requested');
      await started.future;
      expect(w.messageDomain.pendingMessageContextChannelId, 'c1');
      expect(w.messageDomain.messages.map((r) => r.id), ['old']);
      response.complete({
        'messages': [row('canonical', 'c1', 20)],
        'targetMessageId': 'canonical',
        'hasOlder': true,
        'hasNewer': true,
        'threadSummariesByParentMessageId': {
          'canonical': {'replyCount': 2},
        },
      });
      await request;
      expect(w.messageDomain.pendingMessageContextChannelId, isNull);
      expect(receipts.first.$1, ['old']);
      expect(receipts.last.$1, ['canonical']);
    },
  );

  test('cross-channel unknown context suppresses cached latest and accepts only its window', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    final next = RaftChannel({'id': 'c2', 'name': 'next', 'joined': true});
    w.channels.add(next);
    w.messageDomain.ledger.ingest([
      row('private-old', 'c1', 1),
      row('cached-tail', 'c2', 30),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'private-old'};
    w.messageDomain.visibleIds['c2'] = {'cached-tail'};
    final started = Completer<void>(),
        response = Completer<Map<String, dynamic>>();
    api.routes['GET /messages/context/target'] = (_) {
      started.complete();
      return response.future;
    };
    final request = w.jumpToMessage('c2', 'target');
    await started.future;
    expect(w.channel!.id, 'c2');
    expect(w.messageDomain.messages, isEmpty);
    expect(w.messageDomain.state.channelLoading, true);
    response.complete({
      'messages': [row('target', 'c2', 10)],
      'hasNewer': true,
    });
    await request;
    expect(w.messageDomain.messages.map((r) => r.id), ['target']);
  });

  test('compatible accepted cached target skips context GET and retains pagination', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    api.routes['GET /messages/channel/c1'] = (_) => {
      'messages': [row('cached', 'c1', 1)],
    };
    api.routes['POST /channels/c1/read'] = (_) => {};
    await w.selectChannel(w.channel!);
    await w.jumpToMessage('c1', 'cached');
    expect(w.messageDomain.state.highlightedMessageId, 'cached');
    expect(w.messageDomain.state.channelLoading, false);
    expect(w.messageDomain.state.hasNewer, false);
    expect(
      api.calls.where((c) => c.path == '/messages/context/cached'),
      isEmpty,
    );
  });

  for (final invalidate in [
    'later-context',
    'channel-revoked',
    'server-revoked',
    'principal',
  ]) {
    test('[L04] late context cannot accept after $invalidate', () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      final started = Completer<void>(),
          response = Completer<Map<String, dynamic>>();
      api.routes['GET /messages/context/late'] = (_) {
        started.complete();
        return response.future;
      };
      final request = w.jumpToMessage('c1', 'late');
      await started.future;
      switch (invalidate) {
        case 'later-context':
          api.routes['GET /messages/context/current'] = (_) => {
            'messages': [row('current', 'c1', 40)],
            'hasNewer': true,
          };
          await w.jumpToMessage('c1', 'current');
        case 'channel-revoked':
          api.routes['GET /channels'] = (_) => [];
          api.routes['GET /channels/dm'] = (_) => [];
          await w.refreshChannels();
        case 'server-revoked':
          w.revokeServer('s1');
        case 'principal':
          w.client.user = RaftRecord({'id': 'another-user'});
      }
      response.complete({
        'messages': [row('late', 'c1', 2)],
        'hasNewer': true,
      });
      await request;
      expect(
        w.messageDomain.ledger.messages('c1').where((m) => m['id'] == 'late'),
        isEmpty,
      );
      expect(w.messageDomain.threadSummaries.containsKey('late'), false);
      if (invalidate == 'later-context') {
        expect(w.messageDomain.messages.map((r) => r.id), ['current']);
        expect(w.messageDomain.state.highlightedMessageId, 'current');
      }
    });
  }

  test(
    'missing context falls back to latest and clears requested focus',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      // Unregistered context route produces the fixture transport's actual 404.
      api.routes['GET /messages/channel/c1'] = (_) => {
        'messages': [row('latest', 'c1', 60)],
      };
      api.routes['POST /channels/c1/read'] = (_) => {};
      await w.jumpToMessage('c1', 'missing');
      expect(w.messageDomain.messages.map((r) => r.id), ['latest']);
      expect(w.messageDomain.state.highlightedMessageId, isNull);
      expect(w.messageDomain.state.channelLoading, false);
      expect(w.messageDomain.pendingMessageContextChannelId, isNull);
      expect(
        w.messageDomain.contextLoadError,
        MessageContextLoadError.notFound,
      );
    },
  );

  test('preview jump keeps outer URI and rejects later navigation', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.setSection('activity');
    final preview = w.location.withQuery({
      'open': 'channel:c1',
      'msg': 'target',
    });
    w.navigation.navigate(preview);
    final started = Completer<void>(),
        response = Completer<Map<String, dynamic>>();
    api.routes['GET /messages/context/target'] = (_) {
      started.complete();
      return response.future;
    };
    final jump = w.jumpToMessage('c1', 'target', navigate: false);
    await started.future;
    expect(w.location.toString(), preview.toString());
    w.setSection('search');
    response.complete({
      'messages': [row('target', 'c1', 1)],
    });
    await jump;
    expect(w.location.route, RaftRoute.search);
    expect(
      w.messageDomain.ledger.messages('c1').where((r) => r['id'] == 'target'),
      isEmpty,
    );
  });

  test(
    'late context error cannot overwrite a newer accepted context',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      final started = Completer<void>(),
          response = Completer<Map<String, dynamic>>();
      api.routes['GET /messages/context/late'] = (_) {
        started.complete();
        return response.future;
      };
      final jump = w.jumpToMessage('c1', 'late');
      await started.future;
      api.routes['GET /messages/context/current'] = (_) => {
        'messages': [row('current', 'c1', 2)],
        'hasNewer': true,
      };
      await w.jumpToMessage('c1', 'current');
      response.completeError(
        const RaftApiException('late missing', status: 404),
      );
      await jump;
      expect(w.error, isNull);
      expect(w.messageDomain.messages.map((r) => r.id), ['current']);
      expect(api.calls.where((c) => c.path == '/messages/channel/c1'), isEmpty);
    },
  );

  for (final outcome in ['accept', 'late', 'failure']) {
    test(
      'canonical thread outer tail $outcome retains old rows and reply focus',
      () async {
        final (w, api) = await fixture('member');
        addTearDown(w.dispose);
        w.messageDomain.ledger.switchServer('s1');
        w.messageDomain.ledger.ingest([
          row('old', 'c1', 1),
        ], expectedGeneration: w.messageDomain.ledger.generation);
        w.messageDomain.visibleIds['c1'] = {'old'};
        api.routes['GET /messages/context/requested'] = (_) => {
          'canonicalTarget': {
            'kind': 'thread',
            'channelId': 'c1',
            'threadParentMessageId': 'parent',
            'messageId': 'reply',
          },
        };
        api.routes['GET /messages/context/parent'] = (_) => {
          'messages': [row('parent', 'c1', 10)],
          'hasNewer': true,
        };
        api.routes['GET /channels/c1/threads/parent'] = (_) => {
          'threadChannelId': 'thread-1',
        };
        api.routes['GET /messages/context/reply'] = (_) => {
          'messages': [row('reply', 'thread-1', 2)],
        };
        api.routes['POST /channels/thread-1/read'] = (_) => {};
        api.routes['POST /channels/c1/read'] = (_) => {};
        final started = Completer<void>(),
            response = Completer<Map<String, dynamic>>();
        api.routes['GET /messages/channel/c1'] = (_) {
          started.complete();
          return response.future;
        };
        final jump = w.jumpToMessage('c1', 'requested');
        await started.future;
        expect(w.messageDomain.state.threadParent?.id, 'parent');
        expect(w.threadChannelId, 'thread-1');
        expect(w.replies.map((r) => r.id), ['reply']);
        expect(w.messageDomain.messages.map((r) => r.id), ['old']);
        expect(
          w.messageDomain.ledger
              .messages('c1')
              .where((r) => r['id'] == 'parent'),
          isEmpty,
        );
        expect(w.messageDomain.state.highlightedMessageId, 'reply');
        expect(w.messageDomain.state.channelLoading, true);
        expect(w.messageDomain.state.threadLoading, false);
        expect(w.location.thread?.itemId, 'parent');
        expect(w.location.threadFocusedMessageId, 'reply');
        if (outcome == 'late') {
          api.routes['GET /messages/context/newer'] = (_) => {
            'messages': [row('newer', 'c1', 60)],
            'hasNewer': true,
          };
          await w.jumpToMessage('c1', 'newer');
        }
        if (outcome == 'failure') {
          response.completeError(
            const RaftApiException('tail unavailable', status: 503),
          );
        } else {
          response.complete({
            'messages': [row('tail', 'c1', 50)],
          });
        }
        await jump;
        if (outcome == 'late') {
          expect(w.messageDomain.messages.map((r) => r.id), ['newer']);
          expect(w.messageDomain.state.highlightedMessageId, 'newer');
          expect(
            w.messageDomain.ledger
                .messages('c1')
                .where((r) => r['id'] == 'tail'),
            isEmpty,
          );
          expect(w.messageDomain.state.threadParent, isNull);
        } else {
          expect(w.messageDomain.messages.map((r) => r.id), [
            outcome == 'accept' ? 'tail' : 'old',
          ]);
          expect(w.messageDomain.state.highlightedMessageId, 'reply');
          expect(w.messageDomain.state.threadParent?.id, 'parent');
          expect(w.threadChannelId, 'thread-1');
          expect(w.messageDomain.state.channelLoading, false);
          expect(w.error, outcome == 'failure' ? isNotNull : isNull);
        }
      },
    );
  }

  test(
    'missing canonical parent does not publish its partial context',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      api.routes['GET /messages/context/requested'] = (_) => {
        'canonicalTarget': {
          'kind': 'thread',
          'threadParentMessageId': 'missing',
          'messageId': 'reply',
        },
      };
      api.routes['GET /channels/c1/threads/missing'] = (_) => {
        'threadChannelId': 'thread-1',
      };
      api.routes['GET /messages/context/reply'] = (_) => {
        'messages': [row('reply', 'thread-1', 1)],
      };
      api.routes['GET /messages/context/missing'] = (_) => {
        'messages': [row('unrelated', 'c1', 1)],
      };
      api.routes['GET /messages/channel/c1'] = (_) => {
        'messages': [row('latest', 'c1', 2)],
      };
      api.routes['POST /channels/c1/read'] = (_) => {};
      await w.jumpToMessage('c1', 'requested');
      expect(w.messageDomain.messages.map((r) => r.id), ['latest']);
      expect(
        w.messageDomain.ledger
            .messages('c1')
            .where((r) => r['id'] == 'unrelated'),
        isEmpty,
      );
      expect(w.messageDomain.state.threadParent, isNull);
      expect(w.messageDomain.state.highlightedMessageId, 'reply');
      expect(w.threadIdentity?.parentMessageId, 'missing');
      expect(w.replies.map((r) => r.id), ['reply']);
    },
  );

  test(
    'read admission follows visible preview URI and rejects cached hidden rows',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.ledger.ingest([
        row('visible', 'c1', 1),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {'visible'};
      api.routes['POST /channels/c1/read'] = (_) => {};
      w.setSection('activity');
      await w.markRead('c1');
      expect(api.calls.where((c) => c.path == '/channels/c1/read'), isEmpty);
      w.navigation.navigate(w.location.withQuery({'open': 'channel:c1'}));
      await w.markRead('c1');
      expect(api.calls.where((c) => c.path == '/channels/c1/read').length, 1);
      w.setConversationPresentation(Object(), main: false, thread: false);
      await w.markRead('c1');
      expect(api.calls.where((c) => c.path == '/channels/c1/read').length, 1);
      w.setForeground(false);
      await w.markRead('c1');
      expect(api.calls.where((c) => c.path == '/channels/c1/read').length, 1);
    },
  );

  test(
    'first section bind has one entry; repeated active taps still push',
    () async {
      final (w, _) = await fixture('member');
      addTearDown(w.dispose);
      w.setSection('activity');
      expect(w.navigation.entries.length, 1);
      expect(w.location.route, RaftRoute.activity);
      w.setSection('activity');
      expect(w.navigation.entries.length, 2);
    },
  );
  for (final invalidation in [
    'Back',
    'new-route',
    'parent-revoked',
    'server-revoked',
    'principal',
    'capability',
  ]) {
    test('[N09] late parent never accepts after $invalidation', () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      final started = Completer<void>(),
          response = Completer<Map<String, dynamic>>();
      api.routes['GET /channels/c1/threads/parent'] = (_) => {
        'threadChannelId': 'thread-1',
      };
      api.routes['GET /messages/channel/thread-1'] = (_) => {
        'messages': [row('reply', 'thread-1', 2)],
      };
      api.routes['GET /messages/context/parent'] = (_) {
        started.complete();
        return response.future;
      };
      await w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
      );
      await started.future;
      expect(w.threadIdentity?.parentMessageId, 'parent');
      expect(w.messageDomain.threadParentLoading, true);
      expect(w.presentedThreadParent, isNull);
      switch (invalidation) {
        case 'Back':
          w.navigation.back();
        case 'new-route':
          w.setSection('activity');
        case 'parent-revoked':
          api.routes['GET /channels'] = (_) => [];
          api.routes['GET /channels/dm'] = (_) => [];
          await w.refreshChannels();
        case 'server-revoked':
          w.revokeServer('s1');
        case 'principal':
          w.client.user = RaftRecord({'id': 'another-user'});
        case 'capability':
          w.channel = RaftChannel({
            ...w.channel!.json,
            'channelCapabilities': {'viewChannel': false},
          });
      }
      response.complete({
        'messages': [row('parent', 'c1', 1)],
      });
      await Future<void>.delayed(Duration.zero);
      expect(w.presentedThreadParent, isNull);
      expect(w.threadIdentity, isNull);
      expect(
        w.messageDomain.ledger.messages('c1').where((r) => r['id'] == 'parent'),
        isEmpty,
      );
    });
  }

  test(
    '[N07a] close removes only its thread query and retires pending identity',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      api.routes['GET /channels/c1/threads/parent'] = (_) => {
        'threadChannelId': 'thread-1',
      };
      api.routes['GET /messages/channel/thread-1'] = (_) => {'messages': []};
      api.routes['GET /messages/context/parent'] = (_) => {
        'messages': [row('parent', 'c1', 1)],
      };
      w.navigation.navigate(
        w.location.withQuery({
          'profile': 'human:alice',
          'task': 'c1:task',
          'msg': 'outer',
        }),
      );
      await w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        focusedMessageId: 'reply',
      );
      final count = w.navigation.entries.length;
      w.closeThread();
      expect(w.location.thread, isNull);
      expect(w.location.uri.queryParameters['profile'], 'human:alice');
      expect(w.location.uri.queryParameters['task'], 'c1:task');
      expect(w.location.uri.queryParameters['msg'], 'reply');
      expect(w.navigation.entries.length, count);
      expect(w.threadIdentity, isNull);
      expect(w.messageDomain.state.threadParent, isNull);
    },
  );

  test(
    'syntactic open outside Search and Activity cannot ACK cached main',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.ledger.ingest([
        row('cached', 'c1', 1),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {'cached'};
      api.routes['POST /channels/c1/read'] = (_) => {};
      for (final section in ['tasks', 'settings', 'members']) {
        w.setSection(section);
        w.navigation.navigate(w.location.withQuery({'open': 'channel:c1'}));
        await w.markRead('c1');
      }
      expect(api.calls.where((c) => c.path == '/channels/c1/read'), isEmpty);
    },
  );

  testWidgets(
    'a phone jump keeps the old row until the context window is accepted',
    (t) async {
      final f = RootFixture();
      final context = Completer<Map<String, dynamic>>();
      f.holds['GET /messages/context/target'] = context;
      await f.mount(
        t,
        'elegant-light',
        390,
        uri: Uri(path: '/s/alpha/channel/ca'),
      );
      expect(find.text('Accepted a'), findsOneWidget);
      expect(find.byType(MobileChatDirectRead), findsWidgets);
      final before = t.getRect(find.text('Accepted a'));
      var blanked = false;
      f.onFrame = () {
        if (find.text('Accepted a').evaluate().isEmpty &&
            find.text('Jumped target').evaluate().isEmpty) {
          blanked = true;
        }
      };
      var finished = false;
      final jumping = f
          .workspace(t)
          .jumpToMessage('ca', 'target', navigate: false);
      jumping.whenComplete(() => finished = true);
      await f.flush(t);
      expect(find.text('Accepted a'), findsOneWidget);
      final during = t.getRect(find.text('Accepted a'));
      expect((during.top - before.top).abs(), lessThan(1));
      expect(finished, isFalse);
      context.complete({
        'messages': [
          {
            'id': 'target',
            'channelId': 'ca',
            'seq': '9',
            'senderId': 'alice',
            'senderName': 'Alice',
            'content': 'Jumped target',
            'createdAt': '2026-10-10T00:02:00Z',
          },
        ],
        'targetMessageId': 'target',
        'hasOlder': false,
        'hasNewer': false,
      });
      for (var i = 0; i < 8 && !finished; i++) {
        await f.flush(t);
      }
      expect(finished, isTrue);
      expect(blanked, isFalse);
      expect(find.text('Jumped target'), findsOneWidget);
      expect(find.text('Accepted a'), findsNothing);
      await f.close(t);
    },
  );
}
