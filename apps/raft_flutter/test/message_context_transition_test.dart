import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      w.ledger.switchServer('s1');
      w.ledger.ingest([
        row('old', 'c1', 1),
      ], expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = {'old'};
      final started = Completer<void>(),
          response = Completer<Map<String, dynamic>>();
      api.routes['GET /messages/context/requested'] = (_) {
        started.complete();
        return response.future;
      };
      final receipts = <(List<String>, bool, bool, bool, String?)>[];
      w.addListener(() {
        receipts.add((
          w.messages.map((r) => r.id).toList(),
          w.channelLoading,
          w.hasMore,
          w.hasNewer,
          w.highlightedMessageId,
        ));
        if (w.messages.any((r) => r.id == 'canonical')) {
          expect(w.channelLoading, false);
          expect(w.hasMore, true);
          expect(w.hasNewer, true);
          expect(w.highlightedMessageId, 'canonical');
          expect(w.threadSummaries.containsKey('canonical'), true);
        }
      });
      final request = w.jumpToMessage('c1', 'requested');
      await started.future;
      expect(w.pendingMessageContextChannelId, 'c1');
      expect(w.messages.map((r) => r.id), ['old']);
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
      expect(w.pendingMessageContextChannelId, isNull);
      expect(receipts.first.$1, ['old']);
      expect(receipts.last.$1, ['canonical']);
    },
  );

  test('cross-channel unknown context suppresses cached latest and accepts only its window', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    final next = RaftChannel({'id': 'c2', 'name': 'next', 'joined': true});
    w.channels.add(next);
    w.ledger.ingest([
      row('private-old', 'c1', 1),
      row('cached-tail', 'c2', 30),
    ], expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = {'private-old'};
    w.visibleIds['c2'] = {'cached-tail'};
    final started = Completer<void>(),
        response = Completer<Map<String, dynamic>>();
    api.routes['GET /messages/context/target'] = (_) {
      started.complete();
      return response.future;
    };
    final request = w.jumpToMessage('c2', 'target');
    await started.future;
    expect(w.channel!.id, 'c2');
    expect(w.messages, isEmpty);
    expect(w.channelLoading, true);
    response.complete({
      'messages': [row('target', 'c2', 10)],
      'hasNewer': true,
    });
    await request;
    expect(w.messages.map((r) => r.id), ['target']);
  });

  test('compatible accepted cached target skips context GET and retains pagination', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    api.routes['GET /messages/channel/c1'] = (_) => {
      'messages': [row('cached', 'c1', 1)],
    };
    api.routes['POST /channels/c1/read'] = (_) => {};
    await w.selectChannel(w.channel!);
    await w.jumpToMessage('c1', 'cached');
    expect(w.highlightedMessageId, 'cached');
    expect(w.channelLoading, false);
    expect(w.hasNewer, false);
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
    test('late context cannot accept after $invalidate', () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
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
      expect(w.ledger.messages('c1').where((m) => m['id'] == 'late'), isEmpty);
      expect(w.threadSummaries.containsKey('late'), false);
      if (invalidate == 'later-context') {
        expect(w.messages.map((r) => r.id), ['current']);
        expect(w.highlightedMessageId, 'current');
      }
    });
  }

  test(
    'missing context falls back to latest and clears requested focus',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      // Unregistered context route produces the fixture transport's actual 404.
      api.routes['GET /messages/channel/c1'] = (_) => {
        'messages': [row('latest', 'c1', 60)],
      };
      api.routes['POST /channels/c1/read'] = (_) => {};
      await w.jumpToMessage('c1', 'missing');
      expect(w.messages.map((r) => r.id), ['latest']);
      expect(w.highlightedMessageId, isNull);
      expect(w.channelLoading, false);
      expect(w.pendingMessageContextChannelId, isNull);
      expect(w.error, isNotNull);
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
    expect(w.ledger.messages('c1').where((r) => r['id'] == 'target'), isEmpty);
  });

  test(
    'late context error cannot overwrite a newer accepted context',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
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
      expect(w.messages.map((r) => r.id), ['current']);
      expect(api.calls.where((c) => c.path == '/messages/channel/c1'), isEmpty);
    },
  );

  test('canonical thread resolves parent and actual reply context', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    api.routes['GET /messages/context/requested'] = (_) => {
      'canonicalTarget': {
        'kind': 'thread',
        'threadParentMessageId': 'parent',
        'messageId': 'reply',
      },
    };
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [row('parent', 'c1', 1)],
      'hasNewer': true,
    };
    api.routes['GET /channels/c1/threads/parent'] = (_) => {
      'threadChannelId': 'thread-1',
    };
    api.routes['GET /messages/context/reply'] = (_) => {
      'messages': [row('reply', 'thread-1', 2)],
    };
    api.routes['POST /channels/thread-1/read'] = (_) => {};
    await w.jumpToMessage('c1', 'requested');
    expect(w.threadParent?.id, 'parent');
    expect(w.threadChannelId, 'thread-1');
    expect(w.replies.map((r) => r.id), ['reply']);
    expect(w.highlightedMessageId, 'reply');
    expect(w.threadLoading, false);
    expect(w.location.thread?.itemId, 'parent');
    expect(w.location.threadFocusedMessageId, 'reply');
  });

  test(
    'missing canonical parent does not publish its partial context',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      api.routes['GET /messages/context/requested'] = (_) => {
        'canonicalTarget': {
          'kind': 'thread',
          'threadParentMessageId': 'missing',
        },
      };
      api.routes['GET /messages/context/missing'] = (_) => {
        'messages': [row('unrelated', 'c1', 1)],
      };
      api.routes['GET /messages/channel/c1'] = (_) => {
        'messages': [row('latest', 'c1', 2)],
      };
      api.routes['POST /channels/c1/read'] = (_) => {};
      await w.jumpToMessage('c1', 'requested');
      expect(w.messages.map((r) => r.id), ['latest']);
      expect(
        w.ledger.messages('c1').where((r) => r['id'] == 'unrelated'),
        isEmpty,
      );
      expect(w.threadParent, isNull);
      expect(w.highlightedMessageId, isNull);
    },
  );

  test(
    'read admission follows visible preview URI and rejects cached hidden rows',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      w.ledger.ingest([
        row('visible', 'c1', 1),
      ], expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = {'visible'};
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
}
