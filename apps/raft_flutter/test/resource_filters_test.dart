import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_filters.dart';

void main() {
  test(
    'filter-only Search uses mounted params and requires a meaningful filter',
    () {
      final f = ResourceFilters();
      expect(f.search(''), isNull);
      f.searchSort = 'recent';
      expect(f.search(' '), isNull);
      f.channelId = 'channel';
      expect(f.search(''), {
        'q': '',
        'limit': 20,
        'offset': 0,
        'channelId': 'channel',
      });
      f.scopes.addAll(['mentioned', 'humans']);
      f.sender = const ResourceSender('alice', 'user', 'Alice');
      expect(f.search('  hello ', offset: 20), {
        'q': 'hello',
        'limit': 20,
        'offset': 20,
        'sort': 'recent',
        'channelId': 'channel',
        'senderId': 'alice',
        'senderType': 'user',
        'mentionTarget': 'self',
      });
    },
  );
  test('human/agent scope unions and sender conflicts match source', () {
    final f = ResourceFilters()..scopes.add('humans');
    f.selectSender(const ResourceSender('agent', 'agent', 'Agent'));
    expect(f.scopes, isEmpty);
    expect(f.search('')!['senderId'], 'agent');
    expect(f.search('')!.containsKey('senderType'), false);
    f.toggleScope('humans');
    expect(f.sender, isNull);
    expect(f.senderType, 'user');
    f.toggleScope('agents');
    expect(f.senderType, isNull);
  });
  test('date windows use local midnight and calendar day subtraction before UTC encoding', () {
    final now = DateTime(2026, 10, 8, 12, 30, 15, 123);
    final f = ResourceFilters()..timeRange = 'today';
    final params = f.search('', now: now)!;
    expect(DateTime.parse(params['after']), DateTime(2026, 10, 8).toUtc());
    expect(DateTime.parse(params['before']), now.toUtc());
    f.timeRange = '7d';
    expect(
      DateTime.parse(f.search('', now: now)!['after']),
      DateTime(2026, 10, 1, 12, 30, 15, 123).toUtc(),
    );
  });
  test('Saved and Activity send channel/query/direction with no invented grouping parameter', () {
    final f = ResourceFilters()
      ..channelId = 'c'
      ..direction = 'asc'
      ..groupByChannel = true;
    expect(f.list(' text ', offset: 20, limit: 20), {
      'limit': 20,
      'offset': 20,
      'sort': 'asc',
      'q': 'text',
      'channelId': 'c',
    });
    expect(f.list('', filter: 'unread')['filter'], 'unread');
    expect(f.list('').containsKey('groupBy'), false);
  });
  test('thread done uses exact storage frontier; invalid new frontiers fail closed', () {
    final row = {
      'kind': 'thread',
      'threadChannelId': 't',
      'parentMessageId': 'p',
      'latestActivitySeq': '999',
      'doneFrontierSeq': '12',
    };
    expect(activityMutation(row, 'done')!.path, '/channels/threads/done');
    expect(activityMutation(row, 'done')!.data, {
      'threadChannelId': 't',
      'throughActivitySeq': '12',
      'frontierSpace': 'storage',
    });
    expect(activityMutation({...row, 'doneFrontierSeq': null}, 'done'), isNull);
    expect(activityMutation({...row, 'doneFrontierSeq': '0'}, 'done'), isNull);
    final legacy = Map<String, dynamic>.from(row)..remove('doneFrontierSeq');
    expect(activityMutation(legacy, 'done')!.data, {'threadChannelId': 't'});
  });
  test('follow uses parent message; thread restore and channel done remain separate', () {
    final thread = {
      'kind': 'thread',
      'threadChannelId': 't',
      'parentMessageId': 'p',
    };
    expect(activityMutation(thread, 'follow')!.data, {'parentMessageId': 'p'});
    expect(activityMutation(thread, 'unfollow')!.data, {
      'threadChannelId': 't',
    });
    expect(
      activityMutation(thread, 'undone')!.path,
      '/channels/threads/undone',
    );
    expect(
      activityMutation({'kind': 'channel', 'channelId': 'c'}, 'done')!.path,
      '/channels/inbox/done',
    );
    expect(
      activityMutation({'kind': 'mention_action', 'channelId': 'c'}, 'done'),
      isNull,
    );
  });
}
