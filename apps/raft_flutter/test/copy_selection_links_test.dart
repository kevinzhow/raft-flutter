import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/copy_selection_links.dart';
import 'package:raft_flutter/features/message_selection.dart';

import 'message_export_test.dart' show messages;
import 'message_presentation_test.dart' show fixture;

void main() {
  test('main links use one ordered clipboard commit; parent does not include hidden reply', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    w.ledger.ingest(messages(), expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = {'parent', 'later'};
    a.routes['GET /servers'] = (_) => [
      {'id': 's1', 'slug': 'public-workspace'},
    ];
    a.routes['GET /channels/c1'] = (_) => {'id': 'c1', 'serverId': 's1'};
    for (final id in ['parent', 'later']) {
      a.routes['GET /messages/context/$id'] = (_) => {
        'messages': [
          {'id': id},
        ],
      };
    }
    final selection = MessageSelection(w, thread: false)
      ..enter('parent')
      ..toggle('later');
    addTearDown(selection.dispose);
    final writes = <String>[];
    expect(
      await copySelectedMessageLinks(
        w,
        selection,
        () => true,
        write: (v) async => writes.add(v),
      ),
      isTrue,
    );
    expect(writes, [
      'https://example.invalid/s/public-workspace/channel/c1?msg=parent\nhttps://example.invalid/s/public-workspace/channel/c1?msg=later',
    ]);
    expect(a.calls.where((o) => o.path.contains('context/')).length, 2);
  });
  test('thread root and reply use canonical parent route and fresh context validation', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    w.ledger.ingest(messages(), expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = {'parent', 'later'};
    w.visibleIds['t1'] = {'reply'};
    w.threadParent = w.messages.first;
    w.threadChannelId = 't1';
    a.routes['GET /servers'] = (_) => [
      {'id': 's1', 'slug': 'public-workspace'},
    ];
    a.routes['GET /channels/c1'] = (_) => {'id': 'c1', 'serverId': 's1'};
    a.routes['GET /messages/context/parent'] = (_) => {
      'messages': [
        {'id': 'parent'},
      ],
    };
    a.routes['GET /messages/context/reply'] = (_) => {
      'messages': [],
      'canonicalTarget': {
        'kind': 'thread',
        'messageId': 'reply',
        'threadParentMessageId': 'parent',
        'threadChannelId': 't1',
      },
    };
    final selection = MessageSelection(w, thread: true)
      ..enter('parent')
      ..selectAll();
    addTearDown(selection.dispose);
    final writes = <String>[];
    expect(
      await copySelectedMessageLinks(
        w,
        selection,
        () => true,
        write: (v) async => writes.add(v),
      ),
      isTrue,
    );
    final lines = writes.single.split('\n').map(Uri.parse).toList();
    expect(lines.first.queryParameters, {'msg': 'parent'});
    expect(lines.last.queryParameters, {'msg': 'reply', 'thread': 'c1:parent'});
    expect(
      a.calls
          .where((o) => o.path == '/messages/context/reply')
          .single
          .queryParameters['channelId'],
      'c1',
    );
  });
  for (final revoke in ['exit', 'role', 'selection', 'content']) {
    test(
      'pending canonical context cannot commit after $revoke changes',
      () async {
        final (w, a) = await fixture('owner');
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.ledger.ingest(messages(), expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'parent', 'later'};
        a.routes['GET /servers'] = (_) => [
          {'id': 's1', 'slug': 'public-workspace'},
        ];
        a.routes['GET /channels/c1'] = (_) => {'id': 'c1', 'serverId': 's1'};
        final requested = Completer<void>(), response = Completer<dynamic>();
        a.routes['GET /messages/context/parent'] = (_) {
          requested.complete();
          return response.future;
        };
        final selection = MessageSelection(w, thread: false)..enter('parent');
        addTearDown(selection.dispose);
        final writes = <String>[];
        final pending = copySelectedMessageLinks(
          w,
          selection,
          () => true,
          write: (v) async => writes.add(v),
        );
        final caught = pending.then<Object>((v) => v, onError: (Object e) => e);
        await requested.future;
        switch (revoke) {
          case 'exit':
            selection.exit();
          case 'role':
            w.server = RaftRecord({'id': 's1', 'role': 'guest'});
            w.setError(null);
          case 'selection':
            selection.toggle('later');
          case 'content':
            w.ledger.ingest([
              {...messages().first, 'content': 'Replacement'},
            ], expectedGeneration: w.ledger.generation);
        }
        response.complete({
          'messages': [
            {'id': 'parent'},
          ],
        });
        expect(await caught, isNot(true));
        expect(writes, isEmpty);
      },
    );
  }
  test('second target rejection does not leak a partial link batch', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    w.ledger.ingest(messages(), expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = {'parent', 'later'};
    a.routes['GET /servers'] = (_) => [
      {'id': 's1', 'slug': 'public-workspace'},
    ];
    a.routes['GET /channels/c1'] = (_) => {'id': 'c1', 'serverId': 's1'};
    a.routes['GET /messages/context/parent'] = (_) => {
      'messages': [
        {'id': 'parent'},
      ],
    };
    a.routes['GET /messages/context/later'] = (_) => {'messages': []};
    final selection = MessageSelection(w, thread: false)
      ..enter('parent')
      ..toggle('later');
    addTearDown(selection.dispose);
    final writes = <String>[];
    await expectLater(
      copySelectedMessageLinks(
        w,
        selection,
        () => true,
        write: (v) async => writes.add(v),
      ),
      throwsA(isA<RaftApiException>()),
    );
    expect(writes, isEmpty);
  });
}
