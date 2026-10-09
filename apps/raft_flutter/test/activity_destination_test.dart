import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/activity_destination.dart';
import 'package:raft_flutter/data/raft_location.dart';

void main() {
  final thread = <String, dynamic>{
    'kind': 'thread',
    'parentChannelId': 'c',
    'parentMessageId': 'p',
    'threadChannelId': 't',
    'unreadCount': 2,
    'firstMentionMessageId': 'mention',
    'firstUnreadMessageId': 'unread',
    'latestActivityMessageId': 'latest',
  };
  final channel = <String, dynamic>{
    'kind': 'channel',
    'channelId': 'c',
    'unreadCount': 2,
    'firstMentionMessageId': 'mention',
    'firstUnreadMessageId': 'unread',
    'lastMessageId': 'last',
  };
  test('N24 thread-single policy uses unread reply, no parent/channel detour identity', () {
    final target = ActivityDestination.fromRow(thread, canonical: false)!;
    expect(target.messageId, 'unread');
    expect(target.threadChannelId, 't');
    expect(target.parentMessageId, 'p');
    expect(
      ActivityDestination.fromRow({
        ...thread,
        'unreadCount': 0,
      }, canonical: false)!.messageId,
      'latest',
    );
  });
  test(
    'N24 double thread prefers mention and encodes one canonical DM URI',
    () {
      final target = ActivityDestination.fromRow({
        ...thread,
        'parentChannelType': 'dm',
      }, canonical: true)!;
      final location = target.canonicalLocation('raft');
      expect(location.route, RaftRoute.dm);
      expect(location.entityId, 'c');
      expect(location.thread?.itemId, 'p');
      expect(location.messageId, 'mention');
      expect(location.content, isNull);
    },
  );
  test('N24 channel-single desktop ignores firstMention; mobile uses it', () {
    expect(
      ActivityDestination.fromRow(channel, canonical: false)!.messageId,
      'unread',
    );
    expect(
      ActivityDestination.fromRow({
        ...channel,
        'unreadCount': 0,
      }, canonical: false)!.messageId,
      'last',
    );
    expect(
      ActivityDestination.fromRow(
        channel,
        canonical: false,
        mobile: true,
      )!.messageId,
      'mention',
    );
  });
  test('N24 double channel uses firstUnread even for read row', () {
    expect(
      ActivityDestination.fromRow({
        ...channel,
        'unreadCount': 0,
      }, canonical: true)!.messageId,
      'unread',
    );
    expect(
      ActivityDestination.fromRow({
        ...channel,
        'kind': 'dm',
      }, canonical: true)!.canonicalLocation('raft').route,
      RaftRoute.dm,
    );
  });
  test('N24 mention_action canonical DM and single channel remain distinct Source branches', () {
    final row = {
      'kind': 'mention_action',
      'channelId': 'd',
      'channelType': 'dm',
      'messageId': 'mention',
    };
    expect(ActivityDestination.fromRow(row, canonical: true)!.dm, isTrue);
    expect(ActivityDestination.fromRow(row, canonical: false)!.dm, isFalse);
    expect(
      ActivityDestination.fromRow(row, canonical: false)!.messageId,
      'mention',
    );
  });
  test(
    'N24 malformed identities cannot fabricate thread/channel navigation',
    () {
      for (final field in [
        'parentChannelId',
        'parentMessageId',
        'threadChannelId',
      ]) {
        expect(
          ActivityDestination.fromRow({...thread, field: ''}, canonical: false),
          isNull,
        );
      }
      expect(
        ActivityDestination.fromRow({
          'kind': 'unknown',
          'channelId': 'c',
        }, canonical: true),
        isNull,
      );
      expect(
        ActivityDestination.fromRow({
          ...channel,
          'channelId': '',
        }, canonical: true),
        isNull,
      );
    },
  );
}
