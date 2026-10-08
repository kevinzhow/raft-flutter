import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/content_target.dart';

void main() {
  final origin = Uri.parse('https://raft.example');
  ContentTarget? parse(String value) =>
      ContentTarget.parse(Uri.parse(value), origin: origin);
  test('source Web channel, DM and parent thread permalink shapes', () {
    expect(
      parse('https://raft.example/s/team/channel/c?msg=m')!.messageId,
      'm',
    );
    expect(parse('https://raft.example/s/team/dm/d')!.kind, 'dm');
    final thread = parse(
      'https://raft.example/s/team/channel/c?msg=r&thread=c:p',
    )!;
    expect(thread.parentMessageId, 'p');
    expect(thread.kind, 'thread');
  });
  test('exact native notification channel, DM and thread URIs', () {
    expect(parse('raft://v1/servers/s/channels/c/messages/m')!.messageId, 'm');
    expect(parse('raft://v1/servers/s/dms/c/messages/m')!.kind, 'dm');
    final thread = parse(
      'raft://v1/servers/s/channels/c/threads/t?parentMessageId=p&messageId=r',
    )!;
    expect(thread.threadId, 't');
    expect(
      thread.nativeUri('s').toString(),
      'raft://v1/servers/s/channels/c/threads/t?parentMessageId=p&messageId=r',
    );
  });
  test('reject origin changes, OAuth, credentials, malformed scope and duplicated parameters', () {
    for (final value in [
      'https://other.example/s/team/channel/c?msg=m',
      'http://raft.example/s/team/channel/c?msg=m',
      'https://raft.example:8443/s/team/channel/c?msg=m',
      'https://alice:secret@raft.example/s/team/channel/c?msg=m',
      'https://raft.example/s/team/channel/c?msg=m&msg=n',
      'https://raft.example/s/team/channel/c?msg=m&thread=other:p',
      'https://raft.example/s/team/channel/c?token=secret',
      'https://raft.example/s/team/channel/c#secret',
      'raft://oauth/callback?code=secret',
      'raft://v1:42/servers/s/channels/c/messages/m',
      'raft://v1/servers/s/channels/c/threads/t?parentMessageId=p',
      'raft://v1/servers/s/channels/c/messages/%2Fescape',
    ]) {
      expect(parse(value), isNull, reason: value);
    }
  });
  test('notification thread identity is complete and consistent', () {
    final p = {
      'serverId': 's',
      'channelId': 't',
      'messageId': 'r',
      'kind': 'thread',
      'threadId': 't',
      'parentChannelId': 'c',
      'parentMessageId': 'p',
    };
    expect(ContentTarget.fromNotification(p)!.channelId, 'c');
    expect(ContentTarget.fromNotification({...p, 'threadId': 'wrong'}), isNull);
    expect(
      ContentTarget.fromNotification({...p, 'parentMessageId': null}),
      isNull,
    );
  });
}
