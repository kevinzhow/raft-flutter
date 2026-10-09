import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';

void main() {
  WorkspaceNavigation fixture(String path) =>
      WorkspaceNavigation()..bind('alice/s/owner', RaftLocation.parse(path));
  bool consume(
    WorkspaceNavigation n, {
    String thread = 't',
    String parentChannel = 'c',
    String parent = 'p',
    String focus = 'r',
    int? revision,
  }) => n.consumeThreadFocus(
    threadChannelId: thread,
    parentChannelId: parentChannel,
    parentMessageId: parent,
    expectedMessageId: focus,
    expectedRevision: revision ?? n.revision,
  );

  for (final route in ['activity', 'search']) {
    test(
      '[N24 focus-expiry] $route consumes only owned msg without retiring independent metadata',
      () {
        final n = fixture(
          '/s/demo/$route?open=thread:t&thread=c:p&msg=r&task=c:q&profile=human:h&keep=encoded%20value',
        );
        final before = n.location.uri.queryParameters,
            revision = n.revision,
            index = n.index,
            entries = n.entries.length;
        expect(consume(n), isTrue);
        expect(n.location.messageId, isNull);
        expect(n.location.uri.queryParameters, {...before}..remove('msg'));
        expect(n.revision, revision);
        expect(n.index, index);
        expect(n.entries.length, entries);
        expect(n.entries[n.index].toString(), n.location.toString());
        expect(consume(n), isFalse);
      },
    );
  }
  for (final mismatch in ['thread', 'channel', 'parent', 'focus']) {
    test('[N24 focus-expiry] rejects stale $mismatch ownership', () {
      final n = fixture('/s/demo/activity?open=thread:t&thread=c:p&msg=r');
      final before = n.location.toString(), revision = n.revision;
      expect(
        consume(
          n,
          thread: mismatch == 'thread' ? 'other' : 't',
          parentChannel: mismatch == 'channel' ? 'other' : 'c',
          parent: mismatch == 'parent' ? 'other' : 'p',
          focus: mismatch == 'focus' ? 'other' : 'r',
        ),
        isFalse,
      );
      expect(n.location.toString(), before);
      expect(n.revision, revision);
    });
  }
  test('[N24 focus-expiry] canonical side thread does not consume URI msg', () {
    final n = fixture('/s/demo/channel/c?thread=c:p&msg=r');
    final before = n.location.toString();
    expect(consume(n), isFalse);
    expect(n.location.toString(), before);
  });
  test(
    '[N24 focus-expiry] channel preview cannot consume thread-owned focus',
    () {
      final n = fixture('/s/demo/activity?open=channel:c&thread=c:p&msg=r');
      expect(consume(n), isFalse);
      expect(n.location.messageId, 'r');
    },
  );
  test(
    '[N24 focus-expiry] Back/new route fences survive same-identity reentry',
    () {
      final n = fixture('/s/demo');
      final thread = RaftLocation.parse(
        '/s/demo/activity?open=thread:t&thread=c:p&msg=r',
      );
      n.navigate(thread);
      final oldRevision = n.revision;
      n.back();
      n.navigate(thread);
      expect(consume(n, revision: oldRevision), isFalse);
      expect(n.location.messageId, 'r');
      expect(consume(n), isTrue);
      final consumedRevision = n.revision;
      n.navigate(RaftLocation.parse('/s/demo/saved'));
      expect(n.revision, greaterThan(consumedRevision));
      expect(consume(n, revision: consumedRevision), isFalse);
    },
  );
  test(
    '[N24 focus-expiry] principal rebind rejects identical old URI ownership',
    () {
      final n = fixture('/s/demo/activity?open=thread:t&thread=c:p&msg=r');
      final oldRevision = n.revision;
      n.bind('bob/s/member', n.location);
      expect(consume(n, revision: oldRevision), isFalse);
      expect(n.location.messageId, 'r');
    },
  );
}
