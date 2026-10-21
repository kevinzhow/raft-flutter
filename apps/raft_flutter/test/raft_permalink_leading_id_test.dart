import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_permalink.dart';

void main() {
  const channel = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  const id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const base = 'https://app.raft.build/s/acme/channel/$channel';

  test('CJK text glued to the msg id resolves to the leading id only', () {
    final link = parseRaftPermalink('$base?msg=$id这条你是不是没收到');
    expect(link?.messageId, id);
    final thread = parseRaftPermalink(
      '$base?thread=$channel:$id这条&msg=aaaaaaaa也行',
    );
    expect(thread?.threadParentMessageId, id);
    expect(thread?.messageId, 'aaaaaaaa');
  });

  test('non-id msg or thread parent is rejected, not truncated', () {
    expect(parseRaftPermalink('$base?msg=${id}abc'), isNull);
    expect(parseRaftPermalink('$base?msg=not-an-id'), isNull);
    expect(parseRaftPermalink('$base?msg='), isNull);
    expect(parseRaftPermalink('$base?thread=$channel:zzz'), isNull);
    expect(parseRaftPermalink('$base?msg=aaaaaaaaa'), isNull);
  });

  test('the quoted extractor keeps the glued link and parses the id', () {
    final found = extractFirstQuotedPermalink(
      '$base?msg=$id这条你是不是没收到',
      hostname: 'app.raft.build',
      serverSlug: 'acme',
    );
    expect(found?.parsed.messageId, id);
  });
}
