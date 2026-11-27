import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_permalink.dart';

void main() {
  test('quotedMessagePermalink reads desktop links outside Markdown code', () {
    const path = '/s/design/channel/abcdefab?msg=abcdef00';
    const desktop = 'raft://$path';
    final found = extractFirstQuotedPermalink(
      '~~~~\nhttps://app.raft.build$path\n~~~~\n$desktop',
      hostname: 'app.raft.build',
      serverSlug: 'design',
    );
    expect(found?.rawUrl, 'https://app.raft.build$path');
    expect(found?.parsed, parseRaftPermalink(desktop));
    expect(
      extractFirstQuotedPermalink(
        '~~~~\nhttps://app.raft.build$path\n~~~~',
        serverSlug: 'design',
      ),
      isNull,
    );
  });
}
